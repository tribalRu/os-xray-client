#!/usr/local/bin/python3
"""Service state, uptime and automatic restarts of Xray.

Xray runs under daemon(8) with -r (respawn after 5 s). daemon's pid is in the
pidfile and Xray is its child. A restart through the GUI starts a new daemon,
so a child that is much younger than its daemon means Xray crashed and was
restarted automatically.

Output: {"state": "running|restarting|stopped", "uptime": <seconds>,
"uptime_text": "3d 4h", "auto_restarted": bool, "supervisor_uptime": <seconds>}
"""

import json
import os
import re
import subprocess

PIDFILE = '/var/run/xrayclient.pid'
XRAY_MARK = '/usr/local/bin/xray run -c'
# a child younger than its supervisor by more than this was respawned
RESTART_SLACK = 15

ETIME_RE = re.compile(r'^(?:(?:(\d+)-)?(\d+):)?(\d+):(\d+)$')


def parse_etime(text):
    """ps etime ([[dd-]hh:]mm:ss) -> seconds, None when it cannot be read."""
    match = ETIME_RE.match((text or '').strip())
    if not match:
        return None
    days, hours, minutes, seconds = (int(g) if g else 0 for g in match.groups())
    return ((days * 24 + hours) * 60 + minutes) * 60 + seconds


def human(seconds):
    if seconds is None:
        return ''
    days, rest = divmod(int(seconds), 86400)
    hours, rest = divmod(rest, 3600)
    minutes = rest // 60
    if days:
        return '%dd %dh' % (days, hours)
    if hours:
        return '%dh %dm' % (hours, minutes)
    if minutes:
        return '%dm' % minutes
    return '%ds' % int(seconds)


def read_ps():
    try:
        return subprocess.run(['/bin/ps', '-axww', '-o', 'pid,ppid,etime,command'],
                              capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return ''


def read_pid():
    try:
        with open(PIDFILE) as handle:
            value = handle.read().strip()
        return int(value) if value.isdigit() else None
    except OSError:
        return None


def collect(ps_output, supervisor_pid):
    """Pure function over the ps listing, so it can be tested without a router."""
    rows = {}
    for line in ps_output.splitlines()[1:]:
        parts = line.split(None, 3)
        if len(parts) == 4 and parts[0].isdigit() and parts[1].isdigit():
            rows[int(parts[0])] = (int(parts[1]), parse_etime(parts[2]), parts[3])

    sup = rows.get(supervisor_pid) if supervisor_pid else None
    if sup is None:
        return {'state': 'stopped', 'uptime': None, 'uptime_text': '', 'auto_restarted': False,
                'supervisor_uptime': None}

    child = None
    for pid, (ppid, etime, command) in rows.items():
        if ppid == supervisor_pid and XRAY_MARK in command:
            child = etime
            break
    if child is None:
        return {'state': 'restarting', 'uptime': None, 'uptime_text': '', 'auto_restarted': False,
                'supervisor_uptime': sup[1]}

    auto = sup[1] is not None and child is not None and sup[1] - child > RESTART_SLACK
    return {'state': 'running', 'uptime': child, 'uptime_text': human(child),
            'auto_restarted': bool(auto), 'supervisor_uptime': sup[1]}


def main():
    print(json.dumps(collect(read_ps(), read_pid())))


if __name__ == '__main__':
    main()
