#!/usr/local/bin/python3

import hashlib
import json
import os
import socket
import time
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, '/usr/local/opnsense/scripts/OPNsense/XrayClient')
from _lib import iter_nodes

TIMEOUT = 2.5

# Several browser tabs (plugin page, dashboard widget) can ask for latency at
# the same time; reuse a fresh result instead of probing every node again.
CACHE_FILE = '/var/run/xrayclient_latency.json'
CACHE_TTL = 30  # seconds

# A TCP connect probe says nothing about these: the first group talks UDP /
# QUIC only, the second has no remote endpoint at all. Report them as 'n/a'
# instead of a false 'offline'.
UDP_ONLY_PROTOCOLS = ('wireguard', 'hysteria', 'masque')
NO_REMOTE_PROTOCOLS = ('freedom', 'blackhole', 'dns', 'loopback')


def check_node(node_data):
    uuid = node_data['uuid']
    host = node_data['address']
    port = node_data['port']

    if node_data.get('protocol') in UDP_ONLY_PROTOCOLS + NO_REMOTE_PROTOCOLS:
        return uuid, {'status': 'n/a', 'ms': 0}

    if not host or not port:
        return uuid, {'status': 'offline', 'ms': 0}

    try:
        start = time.monotonic()
        with socket.create_connection((host, int(port)), timeout=TIMEOUT):
            elapsed_ms = int(round((time.monotonic() - start) * 1000))
            return uuid, {'status': 'online', 'ms': max(1, elapsed_ms)}
    except Exception:
        return uuid, {'status': 'offline', 'ms': 0}


def _nodes_key(nodes):
    raw = json.dumps(
        sorted((n['uuid'], n['address'], n['port'], n.get('protocol', '')) for n in nodes)
    )
    return hashlib.sha1(raw.encode('utf-8')).hexdigest()


def _read_cache(key):
    try:
        with open(CACHE_FILE, 'r') as fh:
            data = json.load(fh)
        if data.get('key') == key and 0 <= time.time() - data.get('ts', 0) < CACHE_TTL:
            return data.get('nodes')
    except Exception:
        pass
    return None


def _write_cache(key, results):
    tmp = CACHE_FILE + '.tmp'
    try:
        with open(tmp, 'w') as fh:
            json.dump({'key': key, 'ts': time.time(), 'nodes': results}, fh)
        os.replace(tmp, CACHE_FILE)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def main():
    nodes_to_check = [
        n for n in iter_nodes() if n['enabled'] == '1'
    ]

    key = _nodes_key(nodes_to_check)
    cached = _read_cache(key)
    if cached is not None:
        print(json.dumps({'status': 'ok', 'nodes': cached, 'cached': True}))
        return

    results = {}
    if nodes_to_check:
        with ThreadPoolExecutor(max_workers=10) as executor:
            for uuid, res in executor.map(check_node, nodes_to_check):
                results[uuid] = res

    _write_cache(key, results)
    print(json.dumps({'status': 'ok', 'nodes': results}))


if __name__ == '__main__':
    main()
