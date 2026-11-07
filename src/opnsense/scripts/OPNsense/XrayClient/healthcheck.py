#!/usr/local/bin/python3

import json
import socket
import time
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, '/usr/local/opnsense/scripts/OPNsense/XrayClient')
from _lib import iter_nodes

TIMEOUT = 2.5

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


def main():
    nodes_to_check = [
        n for n in iter_nodes() if n['enabled'] == '1'
    ]

    results = {}
    if nodes_to_check:
        with ThreadPoolExecutor(max_workers=10) as executor:
            for uuid, res in executor.map(check_node, nodes_to_check):
                results[uuid] = res

    print(json.dumps({'status': 'ok', 'nodes': results}))


if __name__ == '__main__':
    main()
