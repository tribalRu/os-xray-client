#!/usr/local/bin/python3
"""List the branches of the os-xray-client repository for the branch picker.

Prints {"status": "ok", "branches": [...], "default": "main"}. The list is
read through git's smart-HTTP ref advertisement on github.com, because
api.github.com is blocked on some networks while github.com itself works.
The REST API is only a fallback. Network failures are reported in-band.
"""
import json
import re
import urllib.request

REPO = 'tribalRu/os-xray-client'
REFS_URL = 'https://github.com/%s.git/info/refs?service=git-upload-pack' % REPO
API_URL = 'https://api.github.com/repos/%s/branches?per_page=100' % REPO
TIMEOUT = 8
UA = 'os-xray-client/branch-list'
# update_plugin.sh accepts exactly these names.
SAFE_NAME = re.compile(r'^[A-Za-z0-9_.-]{1,100}$')


def parse_refs(data):
    """Return branch names from a smart-HTTP info/refs response (bytes)."""
    names = []
    pos = 0
    while pos + 4 <= len(data):
        try:
            length = int(data[pos:pos + 4], 16)
        except ValueError:
            break
        if length == 0:
            pos += 4
            continue
        if length < 4 or pos + length > len(data):
            break
        line = data[pos + 4:pos + length].split(b'\0', 1)[0].decode('utf-8', 'replace').strip()
        pos += length
        match = re.match(r'^[0-9a-f]{40,64} refs/heads/(.+)$', line)
        if match:
            names.append(match.group(1))
    return names


def order(names, default='main'):
    """Safe names only, default first, the rest alphabetical, no duplicates."""
    seen = set(n for n in names if SAFE_NAME.match(n))
    rest = sorted(seen - {default}, key=str.lower)
    return ([default] if default in seen else []) + rest


def _get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read()


def list_branches():
    try:
        names = parse_refs(_get(REFS_URL))
        if names:
            return names
    except Exception:
        pass
    try:
        return [b.get('name', '') for b in json.loads(_get(API_URL).decode('utf-8', 'replace'))]
    except Exception:
        return []


def main():
    names = order(list_branches())
    if not names:
        print(json.dumps({'status': 'error', 'branches': [], 'default': 'main',
                          'message': 'GitHub unreachable; branch list unavailable.'}))
        return
    print(json.dumps({'status': 'ok', 'branches': names, 'default': 'main'}))


if __name__ == '__main__':
    main()
