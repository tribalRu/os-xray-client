#!/usr/local/bin/python3
"""Register a Cloudflare WARP device for MASQUE and print the node fields.

Does what `usque register` does (https://github.com/Diniboy1123/usque, MIT):

  1. generate a P-256 key pair locally (openssl);
  2. POST  <api>/reg        - create the device (the API wants a WireGuard
                              key here; a random one is sent and not kept);
  3. PATCH <api>/reg/<id>   - enroll the P-256 public key for MASQUE
                              (key_type secp256r1, tunnel_type masque);
  4. read the device addresses, the edge public key and the endpoint from
     the answer.

Prints {"status": "ok", ...} with the private key (base64 DER), the edge
public key (base64 SubjectPublicKeyInfo), the device addresses and the
endpoint, or {"status": "error", "message": "..."}. Python standard library
plus the openssl command only.

The API version and client headers can be overridden in
/usr/local/etc/xray/warp.json (masque_api_base, masque_client_version,
masque_user_agent), for the day Cloudflare retires the built-in ones.
"""
import base64
import datetime
import json
import os
import re
import socket
import subprocess
import sys
import urllib.error
import urllib.request

socket.setdefaulttimeout(12)

WARP_CONFIG_FILE = '/usr/local/etc/xray/warp.json'
_DEFAULTS = {
    'masque_api_base': 'https://api.cloudflareclient.com/v0a4471',
    'masque_client_version': 'a-6.35-4471',
    'masque_user_agent': 'WARP for Android',
}
FALLBACK_ENDPOINT = '162.159.198.2'
PEM_LINE = re.compile(r'-----[^-]+-----')


class WarpError(Exception):
    pass


def load_config(path=WARP_CONFIG_FILE):
    cfg = dict(_DEFAULTS)
    try:
        with open(path, 'r') as fh:
            user = json.load(fh)
        if isinstance(user, dict):
            for key in _DEFAULTS:
                if isinstance(user.get(key), str) and user[key]:
                    cfg[key] = user[key]
    except FileNotFoundError:
        pass
    except (OSError, ValueError) as exc:
        sys.stderr.write('warp_masque.py: cannot use %s: %s\n' % (path, exc))
    return cfg


def pem_body(text):
    """Bare base64 of a PEM block (or of text without header lines)."""
    return ''.join(PEM_LINE.sub('', text or '').split())


def generate_p256_keys():
    """Return (private_b64, public_b64): DER, base64, no PEM lines."""
    try:
        priv = subprocess.run(['openssl', 'ecparam', '-name', 'prime256v1', '-genkey', '-noout'],
                              capture_output=True, text=True, timeout=15, check=True).stdout
        pub = subprocess.run(['openssl', 'ec', '-pubout'], input=priv,
                             capture_output=True, text=True, timeout=15, check=True).stdout
    except FileNotFoundError:
        raise WarpError('the openssl command is not available')
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        raise WarpError('could not generate the P-256 key: %s' % exc)
    private_b64, public_b64 = pem_body(priv), pem_body(pub)
    if not private_b64 or not public_b64:
        raise WarpError('openssl returned no key')
    return private_b64, public_b64


def api_call(cfg, method, path, body, token=None):
    headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'User-Agent': cfg['masque_user_agent'],
        'CF-Client-Version': cfg['masque_client_version'],
    }
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(cfg['masque_api_base'].rstrip('/') + path,
                                 data=json.dumps(body).encode('utf-8'),
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as exc:
        try:
            detail = exc.read().decode('utf-8')[:300]
        except OSError:
            detail = ''
        raise WarpError('Cloudflare answered HTTP %d%s' % (exc.code, (': ' + detail) if detail else ''))
    except (urllib.error.URLError, OSError, ValueError) as exc:
        raise WarpError('Cloudflare API unreachable: %s' % exc)
    if not isinstance(data, dict):
        raise WarpError('unexpected answer from the Cloudflare API')
    return data


def unwrap(data):
    """The API answers either {"result": {...}} or the object itself."""
    inner = data.get('result')
    return inner if isinstance(inner, dict) else data


def register(cfg):
    """Create the device; returns (device_id, token)."""
    now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    body = {
        'key': base64.b64encode(os.urandom(32)).decode('ascii'),
        'key_type': 'curve25519',
        'tunnel_type': 'wireguard',
        'fcm_token': '',
        'install_id': '',
        'locale': 'en_US',
        'model': 'PC',
        'os_version': '',
        'serial_number': os.urandom(8).hex(),
        'tos': now,
    }
    data = unwrap(api_call(cfg, 'POST', '/reg', body))
    device_id, token = data.get('id'), data.get('token')
    if not device_id or not token:
        raise WarpError('the registration answer has no device id or token')
    return str(device_id), str(token)


def enroll(cfg, device_id, token, public_b64):
    """Enroll the MASQUE key; returns the device config of the answer."""
    body = {'key': public_b64, 'key_type': 'secp256r1', 'tunnel_type': 'masque'}
    data = api_call(cfg, 'PATCH', '/reg/' + device_id, body, token)
    if data.get('success') is False:
        raise WarpError('Cloudflare refused the MASQUE key: %s' % json.dumps(data.get('errors'))[:200])
    config = unwrap(data).get('config')
    if not isinstance(config, dict):
        raise WarpError('the enrollment answer has no device config')
    return config


def extract(config):
    """Edge public key, device addresses and endpoint from the device config."""
    peers = config.get('peers')
    peer = peers[0] if isinstance(peers, list) and peers and isinstance(peers[0], dict) else {}
    edge_key = pem_body(peer.get('public_key'))
    if not edge_key:
        raise WarpError('the answer has no edge public key')
    iface = config.get('interface') if isinstance(config.get('interface'), dict) else {}
    addrs = iface.get('addresses') if isinstance(iface.get('addresses'), dict) else {}
    addresses = []
    if addrs.get('v4'):
        addresses.append(str(addrs['v4']) + '/32')
    if addrs.get('v6'):
        addresses.append(str(addrs['v6']) + '/128')
    if not addresses:
        raise WarpError('the answer has no device addresses')
    endpoint = peer.get('endpoint') if isinstance(peer.get('endpoint'), dict) else {}
    host = re.sub(r':\d+$', '', str(endpoint.get('v4') or '')) or FALLBACK_ENDPOINT
    return edge_key, addresses, host


def build_result(cfg=None):
    cfg = cfg or load_config()
    private_b64, public_b64 = generate_p256_keys()
    device_id, token = register(cfg)
    config = enroll(cfg, device_id, token, public_b64)
    edge_key, addresses, host = extract(config)
    return {
        'status': 'ok',
        'private_key': private_b64,
        'edge_public_key': edge_key,
        'addresses': addresses,
        'endpoint': host,
        'port': 443,
        'sni': 'consumer-masque.cloudflareclient.com',
    }


def main():
    try:
        print(json.dumps(build_result()))
    except WarpError as exc:
        print(json.dumps({'status': 'error', 'message': str(exc)}))


if __name__ == '__main__':
    main()
