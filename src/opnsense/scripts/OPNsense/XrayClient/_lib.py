#!/usr/local/bin/python3
"""Shared utilities for XrayClient Python scripts."""

import xml.etree.ElementTree as ET

CONFIG_PATH = '/conf/config.xml'


def get_general_value(path):
    """Read a value from /OPNsense/XrayClient/general/<path>."""
    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()
        el = root.findtext('.//OPNsense/XrayClient/general/' + path)
        return el.strip() if el else ''
    except Exception:
        return ''


def iter_nodes():
    """Yield dicts with uuid/address/port/enabled for all nodes."""
    try:
        tree = ET.parse(CONFIG_PATH)
        root = tree.getroot()
    except Exception:
        return

    for node_el in root.findall('.//OPNsense/XrayClient/nodes/node'):
        uuid = node_el.attrib.get('uuid', '')
        enabled = (node_el.findtext('enabled') or '0').strip()
        address = (node_el.findtext('address') or '').strip()
        port = (node_el.findtext('port') or '443').strip()
        if uuid:
            yield {
                'uuid': uuid,
                'enabled': enabled,
                'address': address,
                'port': port,
            }


def active_nodes():
    """Yield dicts for nodes with enabled == '1'."""
    return [n for n in iter_nodes() if n['enabled'] == '1']


def all_nodes_with_tags():
    """Return dict tag->uuid mapping (matching config.json.j2 outbounds)."""
    result = {}
    active_idx = 0
    for node in iter_nodes():
        if node['enabled'] != '1':
            continue
        tag = 'proxy' if active_idx == 0 else 'node_' + node['uuid']
        result[node['uuid']] = tag
        active_idx += 1
    return result
