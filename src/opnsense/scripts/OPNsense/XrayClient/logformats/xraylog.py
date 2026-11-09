"""
    OPNsense log format handler for Xray-core log lines.

    Xray has three line shapes that all belong here:

    1. Error/system log: "YYYY/MM/DD HH:MM:SS.micro [level] tag: message"
       (for example, "[Warning] core: Xray 26.10.31 started" or
       "[app/router/burst]" style tags).
    2. Access log: "YYYY/MM/DD HH:MM:SS.micro from <src> accepted|rejected <dst>
       [<inboundTag> -> <outboundTag>]". No severity is logged here.
    3. DNS log (when DNS logging is enabled, it goes to the access log file):
       "<server> got answer: <domain> -> [ips]" or "cache HIT: ..." etc.

    Severity is only meaningful for the first kind, so access/DNS lines are
    reported as Informational (the OPNsense log page defaults to Warning for
    non-core scopes — switch the severity filter to Informational there once,
    the choice persists in browser storage). The access log detoured
    inbound -> outbound is surfaced as the Process column.

    An unparsable line is left for the next handler (and ends up visible with
    severity=None/timestamp=None, as with any unknown format), so a log line
    Xray did not format itself can never crash the reader.
"""
import re
import datetime
from . import NewBaseLogFormat

_XRAY_ERROR_RE = re.compile(
    r'^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d+)\s+'
    r'\[(Fatal|Fatal error|Panic|Error|Warning|Info|Debug)\]\s+(.*)$',
    re.IGNORECASE,
)

_XRAY_GENERIC_RE = re.compile(
    r'^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d+)\s+(.*)$'
)

_DETOUR_RE = re.compile(r'\[([^\[\]]+)\]\s*$')

_SEVERITY = {
    'fatal': 2,      # Critical
    'fatal error': 2,
    'panic': 2,
    'error': 3,      # Error
    'warning': 4,    # Warning
    'info': 6,       # Informational
    'debug': 7,      # Debug
}


class XrayLogFormat(NewBaseLogFormat):
    def __init__(self, filename):
        super(XrayLogFormat, self).__init__(filename)
        self._priority = 10

    @staticmethod
    def match(line):
        return (_XRAY_ERROR_RE.match(line) is not None
                or _XRAY_GENERIC_RE.match(line) is not None)

    def set_line(self, line):
        super().set_line(line)

        def parse_ts(year, month, day, hour, minute, second, frac):
            micro = (frac + '000000')[:6]
            return datetime.datetime(
                int(year), int(month), int(day),
                int(hour), int(minute), int(second), int(micro),
            )

        match = _XRAY_ERROR_RE.match(line)
        if match is not None:
            year, month, day, hour, minute, second, frac, level, rest = match.groups()
            self._ts = parse_ts(year, month, day, hour, minute, second, frac)
            self._severity = _SEVERITY.get(level.lower())
            rest = rest.strip()
            if rest.startswith('['):
                end = rest.find(']')
                self._process = rest[1:end].strip() if end != -1 else rest[:64]
            else:
                head, sep, _ = rest.partition(':')
                self._process = head.strip() if sep else rest.split(' ', 1)[0][:64]
            # The OPNsense bootgrid/tabulator cell renderer escapes raw
            # HTML itself (cf. the process_name column), so Xray's text is
            # inserted safely as-is. Escaping here too would double-encode.
            self._rest = rest
            return

        match = _XRAY_GENERIC_RE.match(line)
        if match is None:
            self._ts = None
            self._severity = None
            self._process = ''
            self._rest = ''
            return

        # Access (or DNS) log line: no level tag is written.
        year, month, day, hour, minute, second, frac, rest = match.groups()
        self._ts = parse_ts(year, month, day, hour, minute, second, frac)
        self._severity = 6  # Informational
        rest = rest.strip()
        lowered = rest.lower()
        detour = _DETOUR_RE.search(rest)
        if any(marker in lowered for marker in (' got answer:', 'cache hit:',
                                                'cache optimiste:')):
            self._process = 'dns'
        elif detour:
            self._process = detour.group(1).strip()[:64]
        else:
            self._process = 'access'
        # Raw text: the OPNsense cell renderer escapes HTML itself.
        self._rest = rest

    @property
    def timestamp(self):
        if self._ts is None:
            return None
        return self._ts.isoformat(timespec='milliseconds')

    @property
    def line(self):
        return self._rest

    @property
    def process_name(self):
        return getattr(self, '_process', '')

    @property
    def facility(self):
        # shown as column "facility" in the standard view (hidden by default)
        return 1

    @property
    def severity(self):
        return getattr(self, '_severity', None)
