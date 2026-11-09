#!/bin/sh

# The paths can be overridden for testing.
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"
XRAY_CONFIG="${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"
PYTHON="${XRAY_PYTHON:-/usr/local/bin/python3}"

if [ ! -x "${XRAY_BIN}" ]; then
    printf '{"status": "error", "message": "Xray binary not found"}\n'
    exit 0
fi

if [ ! -f "${XRAY_CONFIG}" ]; then
    printf '{"status": "error", "message": "Xray config not found"}\n'
    exit 0
fi

# Xray-core >= 1.7 supports `run -test` which validates the config and exits.
OUT=$("${XRAY_BIN}" run -test -c "${XRAY_CONFIG}" 2>&1)
RC=$?
if [ "${RC}" -eq 0 ]; then
    printf '{"status": "ok"}\n'
else
    # Keep the first few lines of Xray's output (line 1 is always just the
    # version banner); json.dumps handles quotes, tabs and other control
    # characters that the previous sed-based escaping missed.
    # An XDRIVE node on a core older than 26.11.9 fails with an opaque
    # "unknown network" style error, so say what is actually wrong.
    printf '%s' "${OUT}" | XRAY_CONFIG="${XRAY_CONFIG}" "${PYTHON}" -c '
import json, os, re, sys
text = " ".join(sys.stdin.read().split("\n")[:8]).strip()
m = re.search(r"\bXray\s+v?(\d+)\.(\d+)\.(\d+)", text)
version = tuple(int(x) for x in m.groups()) if m else None
uses_xdrive = False
try:
    with open(os.environ["XRAY_CONFIG"], encoding="utf-8") as fh:
        cfg = json.load(fh)
    uses_xdrive = any(
        (o.get("streamSettings") or {}).get("network") == "xdrive"
        for o in cfg.get("outbounds", []))
except Exception:
    pass
if uses_xdrive and version is not None and version < (26, 11, 9):
    text = ("An enabled node uses the XDRIVE transport, which needs Xray-core 26.11.9 "
            "or newer (installed: %d.%d.%d). Update the core and apply again. "
            "Xray said: %s" % (version + (text,)))
print(json.dumps({"status": "error", "message": text}))'
fi
exit 0
