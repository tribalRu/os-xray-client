#!/usr/local/bin/python3
"""
    Read /var/log/xray/access.log, parse the last lines and emit them as
    structured JSON for the plugin's Access Log tab.

    Access lines look like:
        2026/11/08 15:16:17.454272 from 127.0.0.1:54626 accepted tcp:127.0.0.1:10085 [api-in -> api]
        2026/11/08 15:16:11.589264 from tcp:192.168.1.10:33868 accepted tcp:185.201.2.39:443 [tun-in -> node_9bcd...]
    Xray can also append "email: <mail>" for authenticated inbound sessions and
    a reason string for rejected connections.

    Output: {"status": "ok", "enabled": true, "rows": [...]}.
    "enabled" is false when the access log file does not exist yet
    (access log disabled).
"""
import sys
import re
import json
import datetime

try:
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 300
except ValueError:
    limit = 300
limit = max(10, min(limit, 2000))

_LINE = re.compile(
    r'^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d+)\s+'
    r'from (\S+)\s+(accepted|rejected)\s+(\S+)\s*'
    r'(?:\[(.*?)\])?\s*(.*)$'
)
_EMAIL = re.compile(r'email:\s*(\S+)')


def parse_line(raw):
    match = _LINE.match(raw)
    if not match:
        return None
    year, month, day, hour, minute, second, frac, src, status, target, detour, extra = match.groups()
    frac = (frac + '000000')[:6]
    extra = (extra or '').strip()
    email_match = _EMAIL.search(extra)
    if email_match:
        email = email_match.group(1)
        note = (extra[:email_match.start()] + extra[email_match.end():]).strip()
    else:
        email = ''
        note = extra
    ts = datetime.datetime(int(year), int(month), int(day),
                           int(hour), int(minute), int(second), int(frac))
    detour = (detour or '').strip()
    inbound = outbound = ''
    if ' -> ' in detour:
        inbound, outbound = (part.strip() for part in detour.split(' -> ', 1))
    return {
        'ts': ts.isoformat(timespec='milliseconds'),
        'ts_unix': ts.timestamp(),
        'from': src,
        'status': status,
        'to': target,
        'detour': detour,
        'inbound': inbound,
        'outbound': outbound,
        'email': email,
        'note': note,
        'raw': raw,
    }


def tail(path, n):
    with open(path, 'rb') as handle:
        handle.seek(0, 2)
        size = handle.tell()
        block = min(size, n * 512)
        handle.seek(max(0, size - block))
        data = handle.read(block).decode('utf-8', errors='replace')
        lines = data.splitlines()
        if size > block:
            # drop the first (partial) line
            lines = lines[1:]
        return lines[-n:]


path = '/var/log/xray/access.log'
result = {'status': 'ok', 'enabled': False, 'rows': []}
try:
    with open(path, 'r', errors='replace') as handle:
        result['enabled'] = True
except OSError:
    print(json.dumps(result))
    sys.exit(0)

for raw in tail(path, limit):
    parsed = parse_line(raw.strip())
    if parsed:
        result['rows'].append(parsed)
    else:
        result['rows'].append({'ts': '', 'from': '', 'status': '', 'to': '',
                               'detour': '', 'inbound': '', 'outbound': '',
                               'email': '', 'note': raw.strip(), 'raw': raw.strip()})

result['rows'].reverse()  # newest first
print(json.dumps(result))
