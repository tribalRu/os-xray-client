#!/usr/local/bin/python3

import json
import socket
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

CONFIG_PATH = '/conf/config.xml'
TIMEOUT = 2.5


def check_node(node_data):
    uuid = node_data['uuid']
    host = node_data['address']
    port = node_data['port']

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
    nodes_to_check = []
    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()
        for node_el in root.findall('.//OPNsense/XrayClient/nodes/node'):
            uuid = node_el.attrib.get('uuid', '')
            address = (node_el.findtext('address') or '').strip()
            port = (node_el.findtext('port') or '443').strip()
            if uuid:
                nodes_to_check.append({
                    'uuid': uuid,
                    'address': address,
                    'port': port
                })
    except Exception as e:
        print(json.dumps({'status': 'error', 'message': str(e), 'nodes': {}}))
        return

    results = {}
    if nodes_to_check:
        with ThreadPoolExecutor(max_workers=10) as executor:
            for uuid, res in executor.map(check_node, nodes_to_check):
                results[uuid] = res

    print(json.dumps({'status': 'ok', 'nodes': results}))


if __name__ == '__main__':
    main()
