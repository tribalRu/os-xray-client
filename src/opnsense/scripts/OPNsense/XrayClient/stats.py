#!/usr/local/bin/python3
import json
import os
import subprocess
import sys

sys.path.insert(0, '/usr/local/opnsense/scripts/OPNsense/XrayClient')
from _lib import all_nodes_with_tags, get_general_value, iter_nodes

XRAY_BIN = '/usr/local/bin/xray'


def main():
    if not os.path.exists(XRAY_BIN):
        print(json.dumps({'status': 'error', 'message': 'Xray binary not found', 'stats': {}}))
        return

    stats_port = get_general_value('stats_port') or '10085'

    # Outbound tags as rendered by config.json.j2: every enabled node is
    # emitted once as 'node_<uuid>'.
    tag_to_uuid = {tag: uuid for uuid, tag in all_nodes_with_tags().items()}
    node_stats = {n['uuid']: {'uplink': 0, 'downlink': 0} for n in iter_nodes()}

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
                    target_uuid = tag_to_uuid.get(parts[1])
                    direction = parts[3]
                    if target_uuid in node_stats and direction in ('uplink', 'downlink'):
                        node_stats[target_uuid][direction] = val
        else:
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
