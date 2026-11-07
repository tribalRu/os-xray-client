#!/bin/sh

XRAY_BIN="/usr/local/bin/xray"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

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
    # version banner) and flatten newlines so the JSON stays valid.
    ESC=$(printf '%s' "${OUT}" | head -n 8 | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"status": "error", "message": "%s"}\n' "${ESC}"
fi
exit 0
