#!/usr/local/bin/python3
"""Collect a support bundle for bug reports: versions, service state, TUN
interface, a summary of the settings, the generated config.json and the tail
of the error log. Secrets (keys, passwords, UUIDs, short ids, server
addresses) are masked before anything is printed.

Output: one JSON object {"text": "<plain text report>"}.
"""

import json
import os
import re
import subprocess
import sys

sys.path.insert(0, '/usr/local/opnsense/scripts/OPNsense/XrayClient')

XRAY_BIN = '/usr/local/bin/xray'
CONFIG_JSON = '/usr/local/etc/xray/config.json'
ERROR_LOG = '/var/log/xray/error.log'
PLUGIN_VER_FILE = '/usr/local/opnsense/scripts/OPNsense/XrayClient/PLUGIN_VERSION'
PIDFILE = '/var/run/xrayclient.pid'
LOG_LINES = 60

# JSON keys whose value is always a secret
SECRET_KEYS = {
    'id', 'password', 'pass', 'secret', 'secretkey', 'privatekey', 'publickey',
    'presharedkey', 'psk', 'shortid', 'shortids', 'token', 'auth', 'uuid',
    'user', 'seed', 'obfs-password', 'mldsa65seed', 'mldsa65verify',
    'pinnedpeercertsha256', 'key', 'cert', 'certificate',
}
# keys that identify the remote server; masked inside "outbounds" only so the
# DNS and routing sections stay readable
HOST_KEYS = {'address', 'endpoint', 'host', 'servername', 'serverip'}

UUID_RE = re.compile(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')
KV_RE = re.compile(r'(?i)\b(password|passwd|secret|token|privatekey|private_key|psk)(["\']?\s*[:=]\s*["\']?)([^\s"\',}]+)')
IPV4_RE = re.compile(r'\b(\d{1,3})\.(\d{1,3})\.\d{1,3}\.\d{1,3}\b')


def mask_value(value):
    text = str(value)
    if len(text) <= 4:
        return '***'
    return text[:2] + '***' + text[-1:]


def mask_json(obj, in_outbounds=False, parent_key=''):
    """Return a copy of a parsed config with secrets masked."""
    if isinstance(obj, dict):
        out = {}
        for key, value in obj.items():
            low = str(key).lower()
            if low in SECRET_KEYS:
                out[key] = mask_secret(value)
            elif in_outbounds and low in HOST_KEYS and isinstance(value, (str, int)):
                out[key] = mask_value(value)
            else:
                out[key] = mask_json(value, in_outbounds or low == 'outbounds', low)
        return out
    if isinstance(obj, list):
        return [mask_json(item, in_outbounds, parent_key) for item in obj]
    if isinstance(obj, str):
        return mask_text(obj)
    return obj


def mask_secret(value):
    if isinstance(value, list):
        return ['***' for _ in value]
    if isinstance(value, (dict,)):
        return '***'
    return '***' if value not in ('', None) else value


def mask_text(text, ips=False):
    """Mask UUIDs and key=value secrets in free text; with ips=True also the
    last two octets of IPv4 addresses (log lines carry client addresses)."""
    text = UUID_RE.sub('<uuid>', text)
    text = KV_RE.sub(lambda m: m.group(1) + m.group(2) + '***', text)
    if ips:
        text = IPV4_RE.sub(lambda m: '%s.%s.x.x' % (m.group(1), m.group(2)), text)
    return text


def run(cmd, timeout=5):
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return (proc.stdout + proc.stderr).strip()
    except Exception as exc:
        return 'unavailable: %s' % exc


def read_file(path, default=''):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as handle:
            return handle.read()
    except Exception:
        return default


def tail_lines(path, count):
    data = read_file(path)
    if not data:
        return ''
    return '\n'.join(data.splitlines()[-count:])


def section(title, body):
    return '=== %s ===\n%s\n' % (title, body.strip() if body.strip() else '(empty)')


def versions_section():
    plugin = read_file(PLUGIN_VER_FILE).strip() or 'unknown'
    core = 'not installed'
    if os.path.exists(XRAY_BIN):
        core = (run([XRAY_BIN, 'version']).splitlines() or ['unknown'])[0]
    lines = [
        'Plugin: %s' % plugin,
        'Xray core: %s' % core,
        'OPNsense: %s' % (run(['/usr/local/sbin/opnsense-version']) or 'unknown'),
        'System: %s' % run(['/usr/bin/uname', '-srm']),
    ]
    for name in ('geoip.dat', 'geosite.dat'):
        path = '/usr/local/share/xray/' + name
        try:
            size = os.path.getsize(path)
            mtime = run(['/usr/bin/stat', '-f', '%Sm', '-t', '%Y-%m-%d %H:%M', path])
            lines.append('%s: %d bytes, %s' % (name, size, mtime))
        except OSError:
            lines.append('%s: not installed' % name)
    return section('Versions', '\n'.join(lines))


def service_section():
    lines = ['rc status: %s' % run(['/usr/sbin/service', 'os-xray-client', 'status'])]
    pid = read_file(PIDFILE).strip()
    if pid.isdigit():
        lines.append('supervisor pid %s, running for: %s' % (
            pid, run(['/bin/ps', '-p', pid, '-o', 'etime=']) or 'not running'))
    children = run(['/bin/ps', '-axww', '-o', 'pid,etime,rss,command'])
    for line in children.splitlines():
        if 'usr/local/bin/xray' in line and 'run -c' in line:
            lines.append('process: ' + line.strip())
    return section('Service', '\n'.join(lines))


def tun_section(tun_name):
    if not tun_name:
        return section('TUN interface', 'native TUN is disabled')
    out = run(['/sbin/ifconfig', tun_name])
    stats = run(['/usr/bin/netstat', '-ibn', '-I', tun_name])
    return section('TUN interface %s' % tun_name, out + '\n\n' + stats)


def settings_section():
    try:
        from _lib import get_general_value, iter_nodes
    except Exception as exc:
        return section('Settings', 'unavailable: %s' % exc), ''
    keys = ['enabled', 'config_mode', 'expert_mode', 'loglevel', 'enable_tun', 'tun_iface', 'tun_address',
            'tun_mtu', 'tun_auto_outbounds_interface', 'enable_sniffing', 'sniffing_route_only',
            'enable_socks', 'socks_listen', 'socks_port', 'enable_http', 'http_listen', 'http_port',
            'stats_port', 'dns_enabled', 'dns_query_strategy', 'dns_tag', 'routing_domain_strategy',
            'default_action', 'observatory_type']
    lines = ['%s = %s' % (key, get_general_value(key) or '-') for key in keys]
    nodes = list(iter_nodes())
    lines.append('')
    lines.append('Nodes: %d (enabled: %d)' % (len(nodes), sum(1 for n in nodes if n['enabled'] == '1')))
    for node in nodes:
        lines.append('  - %s %s:%s %s' % (
            node['protocol'] or '?', mask_value(node['address']), '***', 'enabled' if node['enabled'] == '1' else 'disabled'))
    tun = get_general_value('tun_iface') or 'tun_xray0' if get_general_value('enable_tun') == '1' else ''
    return section('Settings (secrets omitted)', '\n'.join(lines)), tun


def config_section():
    raw = read_file(CONFIG_JSON)
    if not raw:
        return section('config.json (masked)', 'file not found: ' + CONFIG_JSON)
    try:
        cfg = json.loads(raw)
    except ValueError as exc:
        return section('config.json (masked)', 'not valid JSON: %s' % exc)
    masked = json.dumps(mask_json(cfg), indent=2, ensure_ascii=False)
    test = run([XRAY_BIN, 'run', '-test', '-c', CONFIG_JSON], timeout=15) if os.path.exists(XRAY_BIN) else 'xray not installed'
    test = '\n'.join(mask_text(line) for line in test.splitlines()[-8:])
    return section('config.json (masked)', masked) + '\n' + section('xray run -test', test)


def log_section():
    text = mask_text(tail_lines(ERROR_LOG, LOG_LINES), ips=True)
    return section('error.log (last %d lines, masked)' % LOG_LINES, text)


def build_report():
    settings, tun_name = settings_section()
    parts = [
        'os-xray-client debug info\n'
        'Secrets are masked, but read the text through before you post it publicly.\n',
        versions_section(),
        service_section(),
        settings,
        tun_section(tun_name),
        config_section(),
        log_section(),
    ]
    return '\n'.join(parts)


def main():
    try:
        print(json.dumps({'status': 'ok', 'text': build_report()}))
    except Exception as exc:
        print(json.dumps({'status': 'error', 'text': 'Could not build the report: %s' % exc}))


if __name__ == '__main__':
    main()
