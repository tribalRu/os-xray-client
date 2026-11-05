#!/usr/local/bin/python3

import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'
XRAY_BIN = '/usr/local/bin/xray'


def main():
    if not os.path.exists(XRAY_BIN):
        print(json.dumps({'status': 'error', 'message': 'Xray binary not found', 'stats': {}}))
        return

    stats_port = '10085'
    first_active_uuid = None
    all_uuids = []

    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()
        port_el = root.findtext('.//OPNsense/XrayClient/general/stats_port')
        if port_el:
            stats_port = port_el.strip()

        for node_el in root.findall('.//OPNsense/XrayClient/nodes/node'):
            uuid = node_el.attrib.get('uuid', '')
            enabled = (node_el.findtext('enabled') or '0').strip()
            if uuid:
                all_uuids.append(uuid)
                if enabled == '1' and first_active_uuid is None:
                    first_active_uuid = uuid
    except Exception as e:
        print(f"stats.py: config parse error: {e}", file=sys.stderr)

    node_stats = {u: {'uplink': 0, 'downlink': 0} for u in all_uuids}

    try:
        cmd = [XRAY_BIN, 'api', 'statsquery', f'--server=127.0.0.1:{stats_port}']
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        if proc.returncode == 0 and proc.stdout.strip():
            raw = json.loads(proc.stdout)
            for item in raw.get('stat', []):
                name = item.get('name', '')
                val = int(item.get('value', 0))
                parts = name.split('>>>')
                if len(parts) == 4 and parts[0] == 'outbound' and parts[2] == 'traffic':
                    tag = parts[1]
                    direction = parts[3]
                    target_uuid = None
                    if tag == 'proxy' and first_active_uuid:
                        target_uuid = first_active_uuid
                    elif tag.startswith('node_'):
                        target_uuid = tag.replace('node_', '', 1)

                    if target_uuid and target_uuid in node_stats and direction in ('uplink', 'downlink'):
                        node_stats[target_uuid][direction] = val
        else:
            # Zero counters are still returned so the grid renders, but
            # the status now says why instead of silently claiming "ok".
            err = (proc.stderr or proc.stdout or 'statsquery failed').strip().splitlines()
            print(f"stats.py: {err[0] if err else 'statsquery failed'}", file=sys.stderr)
            print(json.dumps({'status': 'error', 'message': err[0] if err else 'statsquery failed', 'stats': node_stats}))
            return
    except Exception as e:
        print(f"stats.py: {e}", file=sys.stderr)
        print(json.dumps({'status': 'error', 'message': str(e), 'stats': node_stats}))
        return

    print(json.dumps({'status': 'ok', 'stats': node_stats}))


if __name__ == '__main__':
    main()
