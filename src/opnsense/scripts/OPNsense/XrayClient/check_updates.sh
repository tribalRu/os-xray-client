#!/bin/sh
#
# os-xray-client: check GitHub for newer Xray-core releases and a newer
# os-xray-client plugin. Prints a single JSON object on stdout.
# Network failures are reported in-band (never a non-zero exit code).

exec /usr/local/bin/python3 - << 'EOF'
import json
import re
import subprocess
import time
import urllib.request

CORE_API = 'https://api.github.com/repos/XTLS/Xray-core/releases/latest'
CORE_RELEASES = 'https://github.com/XTLS/Xray-core/releases'
PLUGIN_XML = ('https://raw.githubusercontent.com/tribalRu/os-xray-client/'
              'main/src/opnsense/mvc/app/models/OPNsense/XrayClient/XrayClient.xml')
PLUGIN_PAGE = 'https://github.com/tribalRu/os-xray-client'
TIMEOUT = 8
UA = 'os-xray-client/version-check'


def fetch(url, timeout=TIMEOUT):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode('utf-8', 'replace')
    except Exception:
        return ''


def ver_tuple(text):
    parts = []
    for piece in (text or '').split('.'):
        match = re.match(r'\d+', piece)
        parts.append(int(match.group(0)) if match else 0)
    return tuple(parts)


def cmp_ver(current, latest):
    a, b = ver_tuple(current), ver_tuple(latest)
    size = max(len(a), len(b))
    a += (0,) * (size - len(a))
    b += (0,) * (size - len(b))
    if b > a:
        return 1
    if b < a:
        return -1
    return 0


def xray_current():
    try:
        out = subprocess.check_output(['/usr/local/bin/xray', 'version'],
                                      stderr=subprocess.DEVNULL,
                                      timeout=5).decode('utf-8', 'replace')
    except Exception:
        return ''
    match = re.search(r'Xray\s+([0-9][0-9A-Za-z.\-]*)', out)
    return match.group(1) if match else ''


def plugin_current():
    try:
        with open('/usr/local/opnsense/scripts/OPNsense/XrayClient/PLUGIN_VERSION',
                  'r', encoding='utf-8', errors='ignore') as handle:
            raw = handle.read().strip()
    except Exception:
        raw = ''
    match = re.search(r'\d+\.\d+\.\d+', raw)
    return match.group(0) if match else raw


core_latest = ''
core_url = CORE_RELEASES
body = fetch(CORE_API)
try:
    tag = (json.loads(body) or {}).get('tag_name') or ''
    core_latest = str(tag).lstrip('vV').strip()
    if core_latest:
        core_url = CORE_RELEASES + '/tag/v' + core_latest
except Exception:
    core_latest = ''

plugin_latest = ''
xml = fetch(PLUGIN_XML)
match = re.search(r'<version>\s*([^<\s]+)\s*</version>', xml or '')
if match:
    plugin_latest = match.group(1).strip()

cur_core = xray_current()
cur_plugin = plugin_current()

result = {
    'status': 'ok',
    'checkedAt': time.strftime('%Y-%m-%d %H:%M'),
    'core': {
        'current': cur_core or 'not installed',
        'latest': core_latest or None,
        'updateAvailable': bool(core_latest) and cmp_ver(cur_core, core_latest) > 0,
        'releaseUrl': core_url,
    },
    'plugin': {
        'current': cur_plugin or 'unknown',
        'latest': plugin_latest or None,
        'updateAvailable': bool(plugin_latest) and cmp_ver(cur_plugin, plugin_latest) > 0,
        'releaseUrl': PLUGIN_PAGE,
    },
}
if not core_latest and not plugin_latest:
    result['message'] = 'GitHub unreachable; update check skipped.'

print(json.dumps(result))
EOF
