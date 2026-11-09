"""
    OPNsense log format handler for Xray-core log lines.

    Xray writes "YYYY/MM/DD HH:MM:SS.microsecond [level] tag: line", which the
    built-in syslog handlers do not recognize. Without this handler every
    line is shown unfiltered: nothing is dropped, but the severity filter and
    the history filter (valid_from) cannot work either. Install into
    /usr/local/opnsense/scripts/syslog/logformats/xraylog.py (install.sh does
    this; uninstall.sh removes it).

    The handler is written defensively: an unparsable line is left for the
    next handler (and ends up visible with severity=None/timestamp=None, as
    with any unknown format), so a log line Xray did not format itself can
    never crash the reader.
"""
import re
import html
import datetime
from . import NewBaseLogFormat

_XRAY_RE = re.compile(
    r'^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d+)\s+'
    r'\[(Fatal|Fatal error|Panic|Error|Warning|Info|Debug)\]\s+(.*)$',
    re.IGNORECASE,
)

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
        return _XRAY_RE.match(line) is not None

    def set_line(self, line):
        super().set_line(line)
        match = _XRAY_RE.match(line)
        if match is None:
            self._rest = ''
            self._severity = None
            self._ts = None
            return
        year, month, day, hour, minute, second, frac, level, rest = match.groups()
        micro = (frac + '000000')[:6]
        self._ts = datetime.datetime(
            int(year), int(month), int(day),
            int(hour), int(minute), int(second), int(micro),
        )
        self._severity = _SEVERITY.get(level.lower())
        # Xray messages look like "core: Xray 26.10.31 started" or
        # "app/router: ...". The access log uses "[ip:port sid] accepted ...".
        rest = rest.strip()
        if rest.startswith('['):
            end = rest.find(']')
            self._process = rest[1:end].strip() if end != -1 else rest[:64]
        else:
            head, sep, _ = rest.partition(':')
            self._process = head.strip() if sep else rest.split(' ', 1)[0][:64]
        # The default bootgrid formatter inserts cell HTML unsanitized, so
        # escape everything Xray wrote (a client-controlled SNI/URL in the
        # access log could otherwise inject markup into the admin's browser).
        self._rest = html.escape(rest, quote=False)

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
