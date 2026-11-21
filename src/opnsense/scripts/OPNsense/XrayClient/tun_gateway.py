#!/usr/local/bin/python3
"""Compare the TUN subnet from the plugin settings with the gateway that
System -> Gateways holds for the TUN interface.

Xray keeps the first address of "TUN Tunnel Subnet" (10.255.0.1 for
10.255.0.1/30) for itself, and the OPNsense gateway must point exactly at it.
After the subnet is changed the old gateway keeps working in the UI but no
longer matches, and policy rules that use it silently stop working.

Output: one JSON object
  {"status": "ok" | "mismatch" | "no_interface" | "no_gateway" | "disabled" | "unknown",
   "interface": "opt3", "descr": "XRAY", "expected": "10.255.0.1",
   "gateways": [{"name": "XRAY_GW", "address": "10.255.0.1", "ok": true}]}
Only "mismatch" is a problem; the other states are normal setups.
"""

import json
import sys

sys.path.insert(0, '/usr/local/opnsense/scripts/OPNsense/XrayClient')


def gateway_items(root):
    """Gateways live in OPNsense/Gateways (26.x) or in the legacy <gateways>."""
    items = root.findall('.//OPNsense/Gateways/gateway_item')
    if not items:
        items = root.findall('.//gateways/gateway_item')
    return items


def check(root, tun_iface, tun_address, enabled=True):
    expected = (tun_address or '').split('/')[0].strip()
    result = {'status': 'unknown', 'interface': '', 'descr': '', 'expected': expected, 'gateways': []}
    if not enabled:
        result['status'] = 'disabled'
        return result
    interfaces = root.find('interfaces')
    ident = ''
    if interfaces is not None:
        for el in interfaces:
            if (el.findtext('if') or '').strip() == tun_iface:
                ident = el.tag
                result['descr'] = (el.findtext('descr') or '').strip()
                break
    if not ident:
        result['status'] = 'no_interface'
        return result
    result['interface'] = ident
    for item in gateway_items(root):
        if (item.findtext('interface') or '').strip() != ident:
            continue
        if (item.findtext('disabled') or '0').strip() == '1':
            continue
        address = (item.findtext('gateway') or '').strip()
        if not address or ':' in address:
            continue
        result['gateways'].append({
            'name': (item.findtext('name') or '').strip(),
            'address': address,
            'ok': address == expected,
        })
    if not result['gateways']:
        result['status'] = 'no_gateway'
    elif any(g['ok'] for g in result['gateways']):
        result['status'] = 'ok'
    else:
        result['status'] = 'mismatch'
    return result


def main():
    try:
        import _lib
        result = check(
            _lib._load_root(),
            _lib.get_general_value('tun_iface') or 'tun_xray0',
            _lib.get_general_value('tun_address') or '10.255.0.1/30',
            _lib.get_general_value('enable_tun') == '1',
        )
    except Exception as exc:
        result = {'status': 'unknown', 'error': str(exc), 'gateways': []}
    print(json.dumps(result))


if __name__ == '__main__':
    main()
