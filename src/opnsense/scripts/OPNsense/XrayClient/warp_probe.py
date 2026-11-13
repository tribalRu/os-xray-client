#!/usr/local/bin/python3
"""Find Cloudflare WARP endpoints that work from this router.

A candidate counts as working only after a real end-to-end test: a temporary
Xray instance (127.0.0.1 only, no TUN) with the credentials of the WARP node
and the candidate as its endpoint fetches Cloudflare's /cdn-cgi/trace and
must be answered with warp=on (or plus) from an address different from the
router's own. A candidate that passes this quick probe is then confirmed:
three more trace requests and a small download through the same instance.
Only candidates that pass everything are "verified"; the others are
"unstable" or dropped, so a single lucky answer is never trusted.

Commands (all print JSON):
  start REQUEST_FILE   read the request (it holds keys; the file is deleted
                       at once), start the search in the background
  status               state of the running or last search
  cancel               stop the running search

Request: {"mode": "wg"|"masque_h2"|"masque_h3", "credentials": {...},
          "zero_trust": false, "want": 5, "max_attempts": 80,
          "endpoints": [{"host": "...", "port": 443}],   # re-check only
          "ignore_cache": false,
          "sources": ["https://..."],      # external lists (WireGuard only)
          "any_address": false}            # probe non-Cloudflare entries too
"""
import ipaddress
import json
import os
import random
import re
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED

XRAY_BIN = os.environ.get('XRAY_BIN', '/usr/local/bin/xray')
RUN_DIR = os.environ.get('WARP_PROBE_DIR', '/tmp/xray_warp_probe')
CACHE_FILE = os.environ.get('WARP_PROBE_CACHE', '/usr/local/etc/xray/warp_probe_cache.json')
TRACE_URL = os.environ.get('WARP_PROBE_TRACE_URL', 'http://www.cloudflare.com/cdn-cgi/trace')
DOWNLOAD_URL = os.environ.get('WARP_PROBE_DOWNLOAD_URL', 'https://speed.cloudflare.com/__down?bytes=300000')
DOWNLOAD_MIN = 200000
BAD_TTL = 6 * 3600
GOOD_KEEP = 20
CONCURRENCY = 4
# MASQUE sessions are tied to the device identity: parallel tunnels of one
# account seem to push each other out, so MASQUE candidates run one by one.
MASQUE_CONCURRENCY = 1
PROBE_TIMEOUT = 5
CONFIRM_REQUESTS = 3
MAX_ATTEMPTS_LIMIT = 300
SNI = 'consumer-masque.cloudflareclient.com'

# Ranges and ports of the community list of WARP endpoints (any address of a
# range with any port of the list is expected to answer).
WG_RANGES = ['162.159.192', '162.159.195', '8.6.112', '8.34.70', '8.34.146', '8.35.211',
             '8.39.125', '8.39.204', '8.39.214', '8.47.69', '188.114.96', '188.114.97',
             '188.114.98', '188.114.99']
WG_PORTS = [500, 854, 859, 864, 878, 880, 890, 891, 894, 903, 908, 928, 934, 939, 942, 943,
            945, 946, 955, 968, 987, 988, 1002, 1010, 1014, 1018, 1070, 1074, 1180, 1387,
            1701, 1843, 2371, 2408, 2506, 3138, 3476, 3581, 3854, 4177, 4198, 4233, 4500,
            5279, 5956, 7103, 7152, 7156, 7281, 7559, 8319, 8742, 8854, 8886]
WG_PRIORITY_PORTS = [2408, 500, 4500, 1701]
MASQUE_RANGES = ['162.159.198', '162.159.199']
MASQUE_PORTS = [443, 500, 1701, 4500, 4443, 8443, 8095]
# Experimental: other WARP ranges (consumer ranges of community scanners and the
# WireGuard list), tried with the MASQUE ports only when asked for.
MASQUE_WIDE_RANGES = ['162.159.192', '162.159.195'] + WG_RANGES[2:]
# Zero Trust only (the account of the node must be a Zero Trust one).
ZT_WG = ('162.159.193', range(1, 11))
ZT_MASQUE = ('162.159.197', range(1, 11))
# Documented defaults: tried first, but they are ordinary candidates.
DOCUMENTED = {
    'wg': [('162.159.192.1', 2408)],
    'masque_h2': [('162.159.198.2', 443), ('162.159.199.2', 443)],
    'masque_h3': [('162.159.198.2', 443), ('162.159.199.2', 443)],
}
MODES = ('wg', 'masque_h2', 'masque_h3')

# External lists: only Cloudflare addresses are probed unless allowed otherwise
# (a probe sends a WireGuard / TLS handshake carrying the device identity).
CF_NETS = [ipaddress.ip_network(n) for n in (
    '173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22', '141.101.64.0/18',
    '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20', '197.234.240.0/22', '198.41.128.0/17',
    '162.158.0.0/15', '104.16.0.0/13', '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22',
    # WARP ranges of the community list that are not in the published list
    '8.6.112.0/24', '8.34.70.0/24', '8.34.146.0/24', '8.35.211.0/24', '8.39.125.0/24',
    '8.39.204.0/24', '8.39.214.0/24', '8.47.69.0/24')]
SOURCE_TTL = 24 * 3600
SOURCE_MAX_BYTES = 2 * 1024 * 1024
SOURCE_MAX_ENTRIES = 60000
MAX_SOURCES = 10
IP_RE = re.compile(r'^\d{1,3}(\.\d{1,3}){3}$')


# ---------------------------------------------------------------- candidates

def candidate_key(mode, host, port):
    return '%s|%s:%d' % ('wg' if mode == 'wg' else 'masque_' + mode[-2:], host, port)


def generate_candidates(mode, zero_trust=False, rng=None, skip=(), extra=(), wide=False):
    """Endless generator of (host, port): documented defaults first, then a
    round robin over the ranges with random addresses and ports, so that a
    blocked range does not eat the whole budget."""
    rng = rng or random.Random()
    skip = set(skip)
    seen = set()

    def fresh(host, port):
        key = (host, port)
        if key in seen or candidate_key(mode, host, port) in skip:
            return False
        seen.add(key)
        return True

    for host, port in DOCUMENTED[mode]:
        if fresh(host, port):
            yield host, port
    # entries of external lists: tested by others already, so they go before
    # the blind sampling
    for host, port in extra:
        if fresh(host, port):
            yield host, port
    prefixes = WG_RANGES if mode == 'wg' else MASQUE_RANGES + (MASQUE_WIDE_RANGES if wide else [])
    ranges = [(prefix, range(0, 256)) for prefix in prefixes]
    ports = WG_PORTS if mode == 'wg' else MASQUE_PORTS
    if zero_trust:
        prefix, octets = ZT_WG if mode == 'wg' else ZT_MASQUE
        ranges.append((prefix, octets))
    priority = list(WG_PRIORITY_PORTS if mode == 'wg' else MASQUE_PORTS)
    total = sum(len(o) for _, o in ranges) * len(ports) + len(seen)
    misses = 0
    round_no = 0
    while len(seen) < total and misses < 5000:
        for prefix, octets in ranges:
            octet = rng.choice(list(octets))
            port = priority[round_no % len(priority)] if round_no < len(priority) * 2 else rng.choice(ports)
            host = '%s.%d' % (prefix, octet)
            if fresh(host, port):
                misses = 0
                yield host, port
            else:
                misses += 1
        round_no += 1


# ----------------------------------------------------- external endpoint lists

def valid_endpoint(ip, port):
    try:
        addr = ipaddress.ip_address(str(ip).strip())
        port = int(port)
    except (ValueError, TypeError):
        return None
    if addr.version != 4 or not 0 < port < 65536 or not addr.is_global:
        return None
    return str(addr), port


def _from_json(node, out):
    """Collect (ip, port) pairs from the shapes lists are published in."""
    if isinstance(node, str):
        m = re.match(r'^\s*(\d{1,3}(?:\.\d{1,3}){3}):(\d{1,5})\s*$', node)
        if m:
            out.append((m.group(1), m.group(2)))
    elif isinstance(node, list):
        for item in node:
            _from_json(item, out)
    elif isinstance(node, dict):
        ip = node.get('ip') or node.get('address') or node.get('host')
        ports = node.get('ports', node.get('port'))
        if ip is not None and ports is not None:
            for port in (ports if isinstance(ports, list) else [ports]):
                out.append((ip, port))
        else:
            for key, value in node.items():          # {"8.6.112.0": [500, 939]}
                if isinstance(key, str) and IP_RE.match(key) and value is not None:
                    for port in (value if isinstance(value, list) else [value]):
                        out.append((key, port))
                else:
                    _from_json(value, out)


def parse_endpoint_list(text):
    """Tolerant parser: JSON in the usual shapes, or text with ip:port pairs
    and 'ip  500, 939, 8854' rows. Returns unique valid (ip, port) pairs."""
    raw = []
    try:
        _from_json(json.loads(text), raw)
    except ValueError:
        for line in text.splitlines():
            for ip, port in re.findall(r'(\d{1,3}(?:\.\d{1,3}){3}):(\d{1,5})', line):
                raw.append((ip, port))
            m = re.match(r'^[\s|*\-]*(\d{1,3}(?:\.\d{1,3}){3})\s*[|,;\t ]\s*([\d ,;|]+)$', line)
            if m and ':' not in line:
                for port in re.findall(r'\d{1,5}', m.group(2)):
                    raw.append((m.group(1), port))
    seen, out = set(), []
    for ip, port in raw:
        ep = valid_endpoint(ip, port)
        if ep and ep not in seen:
            seen.add(ep)
            out.append(ep)
        if len(out) >= SOURCE_MAX_ENTRIES:
            break
    return out


def masque_hosts(entries):
    """No list of MASQUE endpoints is published, so the addresses of the
    WireGuard lists are tried on the MASQUE default port (443); the probe
    decides whether anything answers there."""
    seen, out = set(), []
    for host, _ in entries:
        if host not in seen:
            seen.add(host)
            out.append((host, MASQUE_PORTS[0]))
    return out


def in_cloudflare(ip):
    addr = ipaddress.ip_address(ip)
    return any(addr in net for net in CF_NETS)


def fetch_source(url, timeout=15):
    """Download one list (https only, size capped); returns the text."""
    if not str(url).startswith('https://'):
        raise ValueError('only https:// sources are allowed')
    req = urllib.request.Request(url, headers={'User-Agent': 'os-xray-client'})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = resp.read(SOURCE_MAX_BYTES + 1)
    if len(data) > SOURCE_MAX_BYTES:
        raise ValueError('the list is larger than %d MB' % (SOURCE_MAX_BYTES // 1048576))
    return data.decode('utf-8', 'replace')


def load_sources(urls, cache, any_address=False, fetch=fetch_source, now=None):
    """Entries of all lists plus a report per list for the UI. A list that
    cannot be fetched falls back to its cached copy."""
    now = now or time.time()
    entries, report, seen = [], [], set()
    store = cache.data.setdefault('sources', {})
    for url in list(urls)[:MAX_SOURCES]:
        info = {'url': url}
        cached = store.get(url)
        if cached and now - cached.get('ts', 0) < SOURCE_TTL:
            pairs = [tuple(p) for p in cached['entries']]
            info['status'] = 'cached'
        else:
            try:
                pairs = parse_endpoint_list(fetch(url))
                store[url] = {'ts': now, 'entries': [list(p) for p in pairs]}
                info['status'] = 'ok'
            except (ValueError, OSError) as exc:
                if cached:
                    pairs = [tuple(p) for p in cached['entries']]
                    info.update(status='stale', message='could not refresh: %s' % str(exc)[:80])
                else:
                    report.append(dict(info, status='error', message=str(exc)[:120], count=0, accepted=0))
                    continue
        accepted = [p for p in pairs if any_address or in_cloudflare(p[0])]
        info.update(count=len(pairs), accepted=len(accepted), skipped=len(pairs) - len(accepted))
        report.append(info)
        for pair in accepted:
            if pair not in seen:
                seen.add(pair)
                entries.append(pair)
    return entries, report


# ------------------------------------------------------------- xray config

def build_xray_config(mode, host, port, cred, listen_port, logfile=None):
    """Temporary test config: one local HTTP inbound, one outbound."""
    if mode == 'wg':
        peer = {
            'endpoint': '%s:%d' % (host, port),
            'publicKey': cred['wg_public_key'],
            'keepAlive': 0,
            'allowedIPs': cred.get('wg_allowed_ips') or ['0.0.0.0/0', '::/0'],
        }
        if cred.get('wg_preshared_key'):
            peer['preSharedKey'] = cred['wg_preshared_key']
        outbound = {
            'protocol': 'wireguard',
            'tag': 'probe',
            'settings': {
                'secretKey': cred['wg_secret_key'],
                'address': cred.get('wg_address') or ['10.0.0.1'],
                'peers': [peer],
                # never create a kernel interface for a probe
                'noKernelTun': True,
                'mtu': int(cred.get('wg_mtu') or 1280),
                'reserved': cred.get('wg_reserved') or [0, 0, 0],
            },
        }
    else:
        tls = {'serverName': cred.get('sni') or SNI, 'fingerprint': cred.get('fingerprint') or 'chrome',
               'alpn': ['h2'] if mode == 'masque_h2' else ['h3']}
        warp = {'privateKey': cred['masque_warp_private_key'], 'address': cred['masque_warp_address']}
        key = cred.get('edge_key') or cred.get('masque_warp_public_key') or ''
        if key:
            warp['publicKey'] = key
        elif cred.get('tls_pinned_peer_cert_sha256'):
            tls['pinnedPeerCertSha256'] = cred['tls_pinned_peer_cert_sha256']
        elif cred.get('tls_verify_peer_cert_by_name'):
            tls['verifyPeerCertByName'] = cred['tls_verify_peer_cert_by_name']
        outbound = {
            'protocol': 'masque',
            'tag': 'probe',
            'settings': {'address': host, 'port': port},
            'streamSettings': {'method': 'masque', 'security': 'tls', 'tlsSettings': tls,
                               'masqueSettings': {'warp': warp}},
        }
    return {
        'log': {'loglevel': 'warning', 'error': logfile} if logfile else {'loglevel': 'none'},
        'inbounds': [{'tag': 'in', 'listen': '127.0.0.1', 'port': listen_port, 'protocol': 'http'}],
        'outbounds': [outbound],
        'routing': {'rules': [{'type': 'field', 'inboundTag': ['in'], 'outboundTag': 'probe'}]},
    }


def parse_trace(text):
    out = {}
    for line in (text or '').splitlines():
        if '=' in line:
            key, _, value = line.partition('=')
            out[key.strip()] = value.strip()
    return out


def trace_is_warp(trace, direct_ip=None):
    """warp=on/plus, and not the router's own address (a leak is not WARP)."""
    if trace.get('warp') not in ('on', 'plus'):
        return False
    return not (direct_ip and trace.get('ip') == direct_ip)


# ------------------------------------------------------------------- probes

def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def tls_prefilter(host, port, timeout=3):
    """HTTP/2 candidates: a TLS handshake is a cheap test before the full one.
    Returns the SubjectPublicKeyInfo base64 of the edge certificate or None."""
    try:
        out = subprocess.run(['openssl', 's_client', '-connect', '%s:%d' % (host, port), '-servername', SNI,
                              '-alpn', 'h2', '-tls1_3'], input='', capture_output=True, text=True,
                             timeout=timeout).stdout
        cert = re.search(r'-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----', out, re.S)
        if not cert:
            return None
        pub = subprocess.run(['openssl', 'x509', '-noout', '-pubkey'], input=cert.group(0),
                             capture_output=True, text=True, timeout=timeout).stdout
        match = re.search(r'-----BEGIN PUBLIC KEY-----\s*(.+?)\s*-----END PUBLIC KEY-----', pub, re.S)
        return ''.join(match.group(1).split()) if match else None
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None


def http_get(url, proxy_port, timeout):
    handler = urllib.request.ProxyHandler({'http': 'http://127.0.0.1:%d' % proxy_port,
                                           'https': 'http://127.0.0.1:%d' % proxy_port})
    opener = urllib.request.build_opener(handler)
    start = time.monotonic()
    with opener.open(urllib.request.Request(url, headers={'User-Agent': 'curl/8'}), timeout=timeout) as resp:
        body = resp.read(2000000)
    return body, time.monotonic() - start


def direct_ip():
    """The router's own public address as Cloudflare sees it (None if unknown)."""
    try:
        with urllib.request.urlopen(urllib.request.Request(TRACE_URL, headers={'User-Agent': 'curl/8'}),
                                    timeout=5) as resp:
            return parse_trace(resp.read(4000).decode('utf-8', 'replace')).get('ip')
    except Exception:
        return None


class XrayInstance:
    """A temporary Xray process with a local HTTP proxy."""

    def __init__(self, config):
        self.dir = tempfile.mkdtemp(prefix='xwp_')
        self.port = config['inbounds'][0]['port']
        path = os.path.join(self.dir, 'c.json')
        with open(path, 'w') as fh:
            json.dump(config, fh)
        os.chmod(path, 0o600)
        self.proc = subprocess.Popen([XRAY_BIN, 'run', '-c', path], stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL, start_new_session=True)

    def wait_ready(self, timeout=3):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if self.proc.poll() is not None:
                return False
            try:
                with socket.create_connection(('127.0.0.1', self.port), timeout=0.3):
                    return True
            except OSError:
                time.sleep(0.1)
        return False

    def close(self):
        try:
            os.killpg(self.proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            self.proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        subprocess.run(['rm', '-rf', self.dir], check=False)


def median(values):
    values = sorted(values)
    return values[len(values) // 2] if values else None


def probe_endpoint(mode, host, port, cred, own_ip, confirm_only=False):
    """Returns {'status': 'verified'|'unstable'|'failed', 'ms', 'kbps', 'checks', 'edge_key'?}."""
    cred = dict(cred)
    result = {'host': host, 'port': port}
    if mode == 'masque_h2':
        edge = tls_prefilter(host, port)
        if not edge:
            return dict(result, status='failed', reason='no TLS answer')
        cred['edge_key'] = edge
        result['edge_key'] = edge
    # MASQUE: keep Xray's own log, so that an endpoint that answers once and
    # then stalls can be explained (shown as the Log of that row)
    logfile = None
    if mode != 'wg':
        logfile = os.path.join(tempfile.gettempdir(), 'xwp_log_%d_%d' % (os.getpid(), threading.get_ident()))
        os.close(os.open(logfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600))
    inst = XrayInstance(build_xray_config(mode, host, port, cred, free_port(), logfile))
    try:
        res = _probe_instance(inst, mode, result, own_ip)
        if logfile and res['status'] != 'verified':
            res['log'] = read_log(logfile, cred)
        return res
    finally:
        inst.close()
        if logfile:
            try:
                os.unlink(logfile)
            except OSError:
                pass


def read_log(path, cred, lines=14):
    """Last lines of the Xray log of a probe, without anything key-like."""
    secrets = [v for k, v in cred.items() if 'key' in k and isinstance(v, str) and len(v) > 8]
    try:
        with open(path, errors='replace') as fh:
            rows = [r.rstrip()[:300] for r in fh.read().splitlines() if r.strip()]
    except OSError:
        return []
    return [r for r in rows[-lines:] if not any(s in r for s in secrets)]


def _probe_instance(inst, mode, result, own_ip):
    host, port = result['host'], result['port']
    try:
        if not inst.wait_ready():
            return dict(result, status='failed', reason='xray did not start')
        times, ok = [], 0
        # quick probe
        try:
            body, secs = http_get(TRACE_URL, inst.port, PROBE_TIMEOUT)
        except Exception:
            return dict(result, status='failed', reason='no answer')
        if not trace_is_warp(parse_trace(body.decode('utf-8', 'replace')), own_ip):
            return dict(result, status='failed', reason='not through WARP')
        times.append(secs)
        ok = 1
        # confirmation
        for _ in range(CONFIRM_REQUESTS):
            time.sleep(0.5 if mode == 'wg' else 0)
            try:
                body, secs = http_get(TRACE_URL, inst.port, PROBE_TIMEOUT)
                if trace_is_warp(parse_trace(body.decode('utf-8', 'replace')), own_ip):
                    ok += 1
                    times.append(secs)
            except Exception:
                pass
        kbps = None
        try:
            data, secs = http_get(DOWNLOAD_URL, inst.port, 10)
            if len(data) >= DOWNLOAD_MIN and secs > 0:
                kbps = int(len(data) * 8 / 1000 / secs)
        except Exception:
            pass
        total = 1 + CONFIRM_REQUESTS
        status = 'verified' if ok == total and kbps else 'unstable'
        return dict(result, status=status, ms=int(median(times) * 1000), kbps=kbps,
                    checks='%d/%d%s' % (ok, total, '' if kbps else ', no data'))
    except Exception as exc:  # keep the Log of the instance
        return dict(result, status='failed', reason=str(exc)[:80])


# -------------------------------------------------------------------- state

def _write_json(path, data, mode=0o644):
    tmp = path + '.tmp'
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, 'w') as fh:
        json.dump(data, fh)
    os.replace(tmp, path)


def _read_json(path, default):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


class Cache:
    def __init__(self, path=CACHE_FILE):
        self.path = path
        self.data = _read_json(path, {})
        self.data.setdefault('bad', {})
        self.data.setdefault('good', {})

    def bad_keys(self, now=None):
        now = now or time.time()
        return {k for k, ts in self.data['bad'].items() if now - ts < BAD_TTL}

    def mark_bad(self, key, now=None):
        self.data['bad'][key] = now or time.time()

    def good(self, mode):
        return self.data['good'].get(mode, [])

    def remember_good(self, mode, results, now=None):
        now = now or time.time()
        merged = {(r['host'], r['port']): dict(r, ts=now) for r in self.good(mode)}
        for r in results:
            if r.get('status') == 'verified':
                merged[(r['host'], r['port'])] = {k: v for k, v in r.items() if k != 'edge_key'}
                merged[(r['host'], r['port'])]['ts'] = now
            else:
                merged.pop((r['host'], r['port']), None)
        rows = sorted(merged.values(), key=lambda r: r.get('ms') or 1e9)[:GOOD_KEEP]
        self.data['good'][mode] = rows

    def save(self):
        # drop expired negative entries
        now = time.time()
        self.data['bad'] = {k: ts for k, ts in self.data['bad'].items() if now - ts < BAD_TTL}
        try:
            _write_json(self.path, self.data)
        except OSError:
            pass


class Search:
    """One search (or re-check) run; probe is injectable for tests."""

    def __init__(self, request, state_path, cache, probe=None, rng=None, cancel_path=None, fetch=None):
        self.fetch = fetch or fetch_source
        self.req = request
        self.mode = request['mode']
        self.state_path = state_path
        self.cancel_path = cancel_path
        self.cache = cache
        self.probe = probe or probe_endpoint
        self.rng = rng or random.Random()
        self.want = max(1, min(int(request.get('want') or 5), 20))
        self.max_attempts = max(1, min(int(request.get('max_attempts') or 80), MAX_ATTEMPTS_LIMIT))
        self.lock = threading.Lock()
        self.state = {'status': 'running', 'mode': self.mode, 'started': int(time.time()), 'attempts': 0,
                      'max_attempts': self.max_attempts, 'want': self.want, 'verified': 0, 'results': [],
                      'recheck': bool(request.get('endpoints'))}

    def cancelled(self):
        return bool(self.cancel_path and os.path.exists(self.cancel_path))

    def save_state(self):
        _write_json(self.state_path, self.state)

    def _one(self, host, port, own_ip):
        try:
            res = self.probe(self.mode, host, port, self.req['credentials'], own_ip)
        except Exception as exc:  # a broken probe must not kill the search
            res = {'host': host, 'port': port, 'status': 'failed', 'reason': str(exc)[:80]}
        with self.lock:
            self.state['attempts'] += 1
            key = candidate_key(self.mode, host, port)
            if res['status'] == 'failed':
                self.cache.mark_bad(key)
            res['ts'] = int(time.time())
            # a search lists only what answered; a re-check lists everything
            if res['status'] != 'failed' or self.state['recheck']:
                self.state['results'].append(res)
            if res['status'] == 'verified':
                self.state['verified'] += 1
            self.save_state()
        return res

    def run(self, own_ip=None):
        explicit = [(e['host'], int(e['port'])) for e in (self.req.get('endpoints') or [])]
        if explicit:
            candidates = iter(explicit)
            self.max_attempts = len(explicit)
            self.state['max_attempts'] = len(explicit)
        else:
            skip = set() if self.req.get('ignore_cache') else self.cache.bad_keys()
            extra = []
            if self.req.get('sources'):
                extra, self.state['sources'] = load_sources(self.req['sources'], self.cache,
                                                            bool(self.req.get('any_address')), self.fetch)
                if self.mode != 'wg':
                    extra = masque_hosts(extra)
                self.rng.shuffle(extra)
            candidates = generate_candidates(self.mode, bool(self.req.get('zero_trust')), self.rng, skip, extra,
                                             bool(self.req.get('wide')))
        self.save_state()
        pending, submitted = set(), 0
        workers = CONCURRENCY if self.mode == 'wg' else MASQUE_CONCURRENCY
        with ThreadPoolExecutor(max_workers=workers) as pool:
            while True:
                while (len(pending) < workers and submitted < self.max_attempts
                       and (explicit or self.state['verified'] < self.want) and not self.cancelled()):
                    try:
                        host, port = next(candidates)
                    except StopIteration:
                        break
                    submitted += 1
                    pending.add(pool.submit(self._one, host, port, own_ip))
                if not pending:
                    break
                done, pending = wait(pending, timeout=1, return_when=FIRST_COMPLETED)
        self.state['status'] = 'cancelled' if self.cancelled() else 'done'
        self.state['finished'] = int(time.time())
        self.state['results'].sort(key=lambda r: (r['status'] != 'verified', r.get('ms') or 1e9))
        self.cache.remember_good(self.mode, self.state['results'])
        self.cache.save()
        self.save_state()
        return self.state


# --------------------------------------------------------------------- CLI

def validate_request(req):
    if not isinstance(req, dict) or req.get('mode') not in MODES:
        raise ValueError('unknown mode')
    cred = req.get('credentials')
    if not isinstance(cred, dict):
        raise ValueError('credentials are missing')
    need = ['wg_secret_key', 'wg_public_key'] if req['mode'] == 'wg' else ['masque_warp_private_key', 'masque_warp_address']
    for name in need:
        if not cred.get(name):
            raise ValueError('%s is required' % name)
    sources = req.get('sources') or []
    if not isinstance(sources, list) or len(sources) > MAX_SOURCES or \
            any(not str(u).startswith('https://') or re.search(r'\s', str(u)) for u in sources):
        raise ValueError('invalid source list')
    for ep in req.get('endpoints') or []:
        if not IP_RE.match(str(ep.get('host', ''))) or not 0 < int(ep.get('port', 0)) < 65536:
            raise ValueError('invalid endpoint')
    return req


def _ensure_dir():
    os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
    os.chmod(RUN_DIR, 0o700)


def cmd_start(path):
    # The request file comes from the web UI (a temporary file with keys in it).
    if not (os.path.dirname(path) == tempfile.gettempdir() and os.path.basename(path).startswith('xwp')):
        return {'status': 'error', 'message': 'bad request file'}
    try:
        with open(path) as fh:
            req = validate_request(json.load(fh))
    except (OSError, ValueError, TypeError) as exc:
        return {'status': 'error', 'message': 'bad request: %s' % exc}
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass
    _ensure_dir()
    state = _read_json(os.path.join(RUN_DIR, 'state.json'), {})
    pid = _read_json(os.path.join(RUN_DIR, 'pid.json'), {}).get('pid')
    if state.get('status') == 'running' and pid and _alive(pid):
        return {'status': 'error', 'message': 'a search is already running'}
    cancel = os.path.join(RUN_DIR, 'cancel')
    if os.path.exists(cancel):
        os.unlink(cancel)
    req_path = os.path.join(RUN_DIR, 'request.json')
    _write_json(req_path, req, 0o600)
    _write_json(os.path.join(RUN_DIR, 'state.json'), {'status': 'running', 'mode': req['mode'], 'attempts': 0,
                                                      'verified': 0, 'results': [], 'starting': True})
    proc = subprocess.Popen([sys.executable, os.path.abspath(__file__), 'run'], start_new_session=True,
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    _write_json(os.path.join(RUN_DIR, 'pid.json'), {'pid': proc.pid})
    return {'status': 'ok'}


def _alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except (ProcessLookupError, ValueError):
        return False
    except PermissionError:
        return True


def cmd_run():
    req_path = os.path.join(RUN_DIR, 'request.json')
    req = _read_json(req_path, None)
    try:
        os.unlink(req_path)
    except OSError:
        pass
    state_path = os.path.join(RUN_DIR, 'state.json')
    if not req:
        return
    cache = Cache()
    try:
        search = Search(req, state_path, cache, cancel_path=os.path.join(RUN_DIR, 'cancel'))
        search.run(direct_ip())
    except Exception as exc:
        _write_json(state_path, {'status': 'error', 'message': str(exc)[:200], 'results': []})


def cmd_status():
    state = _read_json(os.path.join(RUN_DIR, 'state.json'), {'status': 'idle', 'results': []})
    pid = _read_json(os.path.join(RUN_DIR, 'pid.json'), {}).get('pid')
    if state.get('status') == 'running' and pid and not _alive(pid):
        state['status'] = 'error'
        state['message'] = 'the search process ended unexpectedly'
    cache = Cache()
    state['cached'] = {mode: cache.good(mode) for mode in MODES}
    return state


def cmd_cancel():
    _ensure_dir()
    open(os.path.join(RUN_DIR, 'cancel'), 'w').close()
    return {'status': 'ok'}


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ''
    if cmd == 'start' and len(argv) == 3:
        print(json.dumps(cmd_start(argv[2])))
    elif cmd == 'status':
        print(json.dumps(cmd_status()))
    elif cmd == 'cancel':
        print(json.dumps(cmd_cancel()))
    elif cmd == 'run':
        cmd_run()
    else:
        print(json.dumps({'status': 'error', 'message': 'usage: warp_probe.py start FILE | status | cancel'}))


if __name__ == '__main__':
    main(sys.argv)
