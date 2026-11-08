#!/usr/local/bin/python3
"""Shared utilities for XrayClient Python scripts."""

import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'

_root_cache = None


def _load_root():
    """Parse /conf/config.xml once per process (it can be large)."""
    global _root_cache
    if _root_cache is None:
        _root_cache = ET.parse(CONFIG_PATH).getroot()
    return _root_cache


def get_general_value(path):
    """Read a value from /OPNsense/XrayClient/general/<path>."""
    try:
        el = _load_root().findtext('.//OPNsense/XrayClient/general/' + path)
        return el.strip() if el else ''
    except Exception:
        return ''


def iter_nodes():
    """Yield dicts with uuid/address/port/protocol/enabled for all nodes."""
    try:
        root = _load_root()
    except Exception:
        return

    for node_el in root.findall('.//OPNsense/XrayClient/nodes/node'):
        uuid = node_el.attrib.get('uuid', '')
        enabled = (node_el.findtext('enabled') or '0').strip()
        address = (node_el.findtext('address') or '').strip()
        port = (node_el.findtext('port') or '443').strip()
        protocol = (node_el.findtext('protocol') or '').strip()
        if uuid:
            yield {
                'uuid': uuid,
                'enabled': enabled,
                'address': address,
                'port': port,
                'protocol': protocol,
            }


def active_nodes():
    """Yield dicts for nodes with enabled == '1'."""
    return [n for n in iter_nodes() if n['enabled'] == '1']


def all_nodes_with_tags():
    """Return dict uuid->tag mapping (matching config.json.j2 outbounds)."""
    result = {}
    for node in iter_nodes():
        if node['enabled'] != '1':
            continue
        result[node['uuid']] = 'node_' + node['uuid']
    return result


def iter_balancers():
    """Yield dicts with uuid/tag/enabled for all balancers."""
    try:
        root = _load_root()
    except Exception:
        return

    for el in root.findall('.//OPNsense/XrayClient/balancers/balancer'):
        uuid = el.attrib.get('uuid', '')
        tag = (el.findtext('tag') or '').strip()
        if uuid:
            yield {
                'uuid': uuid,
                'tag': tag,
                'enabled': (el.findtext('enabled') or '0').strip(),
            }


def active_balancers():
    """Yield dicts for balancers with enabled == '1'."""
    return [b for b in iter_balancers() if b['enabled'] == '1']
