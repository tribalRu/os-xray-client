#!/usr/local/bin/python3
"""Fetch the public key of a Cloudflare WARP MASQUE edge certificate.

Usage: warp_edge_key.py ADDRESS PORT SNI

Does what the Project X WARP guide does by hand:
    openssl s_client -connect ADDRESS:PORT -servername SNI -alpn h2 -tls1_3
    | openssl x509 -noout -pubkey

and prints {"status": "ok", "public_key": "<base64 SubjectPublicKeyInfo>"}.
The edge certificate is a fixed self-signed one, so it is not verified here:
the point is to learn its key, which Xray then pins. Errors are reported
in-band as {"status": "error", "message": "..."}.
"""
import ipaddress
import json
import re
import subprocess
import sys

TIMEOUT = 12
HOST_RE = re.compile(r'^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$')
CERT_RE = re.compile(r'-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----', re.S)
KEY_RE = re.compile(r'-----BEGIN PUBLIC KEY-----\s*(.+?)\s*-----END PUBLIC KEY-----', re.S)


def fail(message):
    print(json.dumps({'status': 'error', 'message': message}))
    sys.exit(0)


def check_args(address, port, sni):
    """Return (connect_target, sni) or raise ValueError."""
    try:
        ip = ipaddress.ip_address(address.strip('[]'))
    except ValueError:
        raise ValueError('the endpoint address must be an IPv4 or IPv6 address')
    if not port.isdigit() or not 1 <= int(port) <= 65535:
        raise ValueError('the port must be between 1 and 65535')
    if not HOST_RE.match(sni):
        raise ValueError('the SNI is not a valid host name')
    host = '[%s]' % ip if ip.version == 6 else str(ip)
    return '%s:%d' % (host, int(port)), sni


def extract_public_key(s_client_output, run):
    """Return the base64 SubjectPublicKeyInfo of the first certificate."""
    cert = CERT_RE.search(s_client_output)
    if not cert:
        raise ValueError('no certificate in the TLS handshake (is the endpoint reachable on this port?)')
    proc = run(['openssl', 'x509', '-noout', '-pubkey'], cert.group(0))
    match = KEY_RE.search(proc)
    if not match:
        raise ValueError('could not read the public key from the certificate')
    return ''.join(match.group(1).split())


def _run(cmd, stdin_text):
    proc = subprocess.run(cmd, input=stdin_text, capture_output=True, text=True,
                          timeout=TIMEOUT)
    return proc.stdout


def main(argv):
    if len(argv) != 4:
        fail('usage: warp_edge_key.py ADDRESS PORT SNI')
    try:
        target, sni = check_args(argv[1], argv[2], argv[3])
    except ValueError as exc:
        fail(str(exc))
    try:
        out = _run(['openssl', 's_client', '-connect', target, '-servername', sni,
                    '-alpn', 'h2', '-tls1_3'], '')
        key = extract_public_key(out, _run)
    except subprocess.TimeoutExpired:
        fail('timed out after %d seconds: the endpoint is blocked or unreachable' % TIMEOUT)
    except FileNotFoundError:
        fail('the openssl command is not available')
    except ValueError as exc:
        fail(str(exc))
    print(json.dumps({'status': 'ok', 'public_key': key}))


if __name__ == '__main__':
    main(sys.argv)
