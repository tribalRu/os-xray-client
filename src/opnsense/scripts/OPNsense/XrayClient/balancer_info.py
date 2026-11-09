#!/usr/local/bin/python3
"""Query xray's RoutingService for the current selection of each balancer.

Runs `xray api bi --server=127.0.0.1:<stats_port> --json <tag>` for every
enabled balancer and prints {"status": "ok", "balancers": [...]}.
Requires "RoutingService" under config.api.services in config.json.
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, '/usr/local/opnsense/scripts/OPNsense/XrayClient')
from _lib import active_balancers, get_general_value

XRAY_BIN = '/usr/local/bin/xray'

# protojson prints camelCase names; older builds used the proto field name.
JSON_KEYS = ('principleTarget', 'principle_target')


def _collect_target(obj):
    if isinstance(obj, dict):
        lst = obj.get('tag')
        if isinstance(lst, list):
            return [t for t in lst if isinstance(t, str)]
        if isinstance(lst, str):
            return [lst]
    return []


def main():
    if not os.path.exists(XRAY_BIN):
        print(json.dumps({'status': 'error', 'message': 'Xray binary not found', 'balancers': []}))
        return

    stats_port = get_general_value('stats_port') or '10085'
    balancers_out = []

    for balancer in active_balancers():
        tag = balancer['tag']
        if not tag:
            continue
        try:
            cmd = [XRAY_BIN, 'api', 'bi', f'--server=127.0.0.1:{stats_port}', '--json', tag]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
            if proc.returncode != 0 or not proc.stdout.strip():
                err = (proc.stderr or proc.stdout or 'balancer info failed').strip().splitlines()
                balancers_out.append({
                    'tag': tag,
                    'status': 'error',
                    'message': err[0] if err else 'balancer info failed',
                })
                continue
            raw = json.loads(proc.stdout)
            balancer_block = raw.get('balancer', raw)
            pt = None
            for key in JSON_KEYS:
                pt = balancer_block.get(key)
                if pt is not None:
                    break
            selecting = _collect_target(pt) if pt else []
            override = balancer_block.get('override') or {}
            override_target = override.get('target') if isinstance(override, dict) else None
            balancers_out.append({
                'tag': tag,
                'status': 'ok',
                'selecting': selecting,
                'override': override_target,
            })
        except Exception as e:
            balancers_out.append({'tag': tag, 'status': 'error', 'message': str(e)})

    print(json.dumps({'status': 'ok', 'balancers': balancers_out}))


if __name__ == '__main__':
    main()
