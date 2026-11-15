#!/usr/local/bin/python3
"""Browse the categories inside geosite.dat / geoip.dat.

Usage:
  geodata.py tags    <site|ip>
  geodata.py entries <site|ip> <TAG> [query] [offset] [limit]

Prints one JSON object. The .dat files are protobuf messages (v2fly
"routercommon"); only the few fields needed are decoded by hand so no
protobuf package is required:

  GeoSiteList { repeated GeoSite entry = 1 }
  GeoSite     { string country_code = 1; repeated Domain domain = 2 }
  Domain      { Type type = 1 (0 plain, 1 regex, 2 domain, 3 full);
                string value = 2; repeated Attribute attribute = 3 }
  Attribute   { string key = 1 }
  GeoIPList   { repeated GeoIP entry = 1 }
  GeoIP       { string country_code = 1; repeated CIDR cidr = 2 }
  CIDR        { bytes ip = 1; uint32 prefix = 2 }
"""
import ipaddress
import json
import os
import re
import sys

ASSET_DIR = os.environ.get('XRAY_ASSET_DIR', '/usr/local/share/xray')
FILES = {'site': 'geosite.dat', 'ip': 'geoip.dat'}
TAG_RE = re.compile(r'^[A-Za-z0-9@!._-]{1,128}$')
QUERY_RE = re.compile(r'^[A-Za-z0-9@!._:/*-]{0,128}$')
DOMAIN_TYPES = {0: 'keyword', 1: 'regexp', 2: 'domain', 3: 'full'}
MAX_LIMIT = 500


class DatError(Exception):
    pass


def _varint(buf, pos):
    result = 0
    shift = 0
    while True:
        if pos >= len(buf):
            raise DatError('truncated data')
        byte = buf[pos]
        pos += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, pos
        shift += 7
        if shift > 70:
            raise DatError('bad varint')


def fields(buf, start=0, end=None):
    """Yield (field_number, wire_type, value) of one message.

    Length-delimited values are returned as (begin, end) offsets, not
    copied, so counting entries of a large list stays cheap.
    """
    pos = start
    end = len(buf) if end is None else end
    while pos < end:
        key, pos = _varint(buf, pos)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, pos = _varint(buf, pos)
            yield number, wire, value
        elif wire == 2:
            length, pos = _varint(buf, pos)
            if pos + length > end:
                raise DatError('truncated field')
            yield number, wire, (pos, pos + length)
            pos += length
        elif wire == 1:
            pos += 8
        elif wire == 5:
            pos += 4
        else:
            raise DatError('unsupported wire type %d' % wire)


def _load(kind):
    if kind not in FILES:
        raise DatError('kind must be site or ip')
    path = os.path.join(ASSET_DIR, FILES[kind])
    try:
        with open(path, 'rb') as handle:
            return handle.read()
    except OSError:
        raise DatError('%s not found - update GeoData in Maintenance first' % FILES[kind])


def _entry_code(buf, begin, end):
    for number, wire, value in fields(buf, begin, end):
        if number == 1 and wire == 2:
            return buf[value[0]:value[1]].decode('utf-8', 'replace')
    return ''


def list_tags(kind):
    buf = _load(kind)
    tags = []
    for number, wire, (begin, end) in (f for f in fields(buf) if f[0] == 1 and f[1] == 2):
        code = ''
        count = 0
        for n, w, v in fields(buf, begin, end):
            if n == 1 and w == 2:
                code = buf[v[0]:v[1]].decode('utf-8', 'replace')
            elif n == 2 and w == 2:
                count += 1
        tags.append({'tag': code.lower(), 'count': count})
    tags.sort(key=lambda t: t['tag'])
    return {'status': 'ok', 'kind': kind, 'tags': tags}


def _site_entry(buf, begin, end):
    kind = 2
    value = ''
    attrs = []
    for n, w, v in fields(buf, begin, end):
        if n == 1 and w == 0:
            kind = v
        elif n == 2 and w == 2:
            value = buf[v[0]:v[1]].decode('utf-8', 'replace')
        elif n == 3 and w == 2:
            for an, aw, av in fields(buf, v[0], v[1]):
                if an == 1 and aw == 2:
                    attrs.append(buf[av[0]:av[1]].decode('utf-8', 'replace'))
    return {'type': DOMAIN_TYPES.get(kind, 'domain'), 'value': value, 'attrs': attrs}


def _ip_entry(buf, begin, end):
    raw = b''
    prefix = 0
    for n, w, v in fields(buf, begin, end):
        if n == 1 and w == 2:
            raw = buf[v[0]:v[1]]
        elif n == 2 and w == 0:
            prefix = v
    try:
        addr = ipaddress.ip_address(raw)
    except ValueError:
        return {'type': 'cidr', 'value': raw.hex(), 'attrs': []}
    return {'type': 'cidr', 'value': '%s/%d' % (addr, prefix), 'attrs': []}


def list_entries(kind, tag, query='', offset=0, limit=100):
    buf = _load(kind)
    wanted = tag.lower().split('@')[0]
    query = query.lower()
    limit = max(1, min(int(limit), MAX_LIMIT))
    offset = max(0, int(offset))
    decode = _site_entry if kind == 'site' else _ip_entry
    for number, wire, (begin, end) in (f for f in fields(buf) if f[0] == 1 and f[1] == 2):
        if _entry_code(buf, begin, end).lower() != wanted:
            continue
        rows = []
        total = 0
        for n, w, v in fields(buf, begin, end):
            if n != 2 or w != 2:
                continue
            row = decode(buf, v[0], v[1])
            if query and query not in row['value'].lower() and query not in ' '.join(row['attrs']).lower():
                continue
            if total >= offset and len(rows) < limit:
                rows.append(row)
            total += 1
        return {'status': 'ok', 'kind': kind, 'tag': wanted, 'total': total,
                'offset': offset, 'rows': rows}
    return {'status': 'error', 'message': 'tag %s not found in %s' % (wanted, FILES[kind])}


def main(argv):
    try:
        if len(argv) >= 3 and argv[1] == 'tags':
            result = list_tags(argv[2])
        elif len(argv) >= 4 and argv[1] == 'entries':
            if not TAG_RE.match(argv[3]):
                raise DatError('invalid tag')
            query = argv[4] if len(argv) > 4 and argv[4] != '-' else ''
            if not QUERY_RE.match(query):
                raise DatError('invalid search text')
            offset = argv[5] if len(argv) > 5 else 0
            limit = argv[6] if len(argv) > 6 else 100
            result = list_entries(argv[2], argv[3], query, offset, limit)
        else:
            raise DatError('usage: geodata.py tags <site|ip> | entries <site|ip> <tag> [q] [offset] [limit]')
    except (DatError, ValueError) as exc:
        result = {'status': 'error', 'message': str(exc)}
    print(json.dumps(result))


if __name__ == '__main__':
    main(sys.argv)
