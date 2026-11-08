#!/bin/sh
#
# os-xray-client: restart the running service after the plugin files (and
# the config template) have been replaced by an update, so the process in
# memory actually runs the new code and the config rendered by the new
# template.
#
# Called by install.sh after `configctl template reload`, i.e. once configd
# is back up. Never starts a service the administrator has stopped and never
# replaces a working process with a config that Xray itself rejects: in both
# cases the current process is left untouched.

RC_SCRIPT="${XRAY_RC_SCRIPT:-/usr/local/etc/rc.d/os-xray-client}"
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"
XRAY_CONFIG="${XRAY_CONFIG:-/usr/local/etc/xray/config.json}"
PYTHON="${XRAY_PYTHON:-/usr/local/bin/python3}"

if [ ! -x "${RC_SCRIPT}" ]; then
    echo "Xray Client rc script not found; nothing to restart."
    exit 0
fi

if [ ! -x "${XRAY_BIN}" ]; then
    echo "Xray binary not installed; nothing to restart."
    exit 0
fi

# Respect the GUI "Enable Xray Client" toggle: a disabled plugin must not be
# brought back up by an update.
GUI_ENABLED=$("${PYTHON}" - << 'EOF' 2>/dev/null || echo ""
import xml.etree.ElementTree as ET
try:
    root = ET.parse("/conf/config.xml").getroot()
    val = root.findtext(".//OPNsense/XrayClient/general/enabled")
    print("1" if (val or "").strip() == "1" else "0")
except Exception:
    print("")
EOF
)

if [ "${GUI_ENABLED}" = "0" ]; then
    echo "Xray Client is disabled in the GUI; leaving the service stopped."
    exit 0
fi

# A stopped service stays stopped: the update is not a reason to start it.
if ! "${RC_SCRIPT}" status >/dev/null 2>&1; then
    echo "Xray Client is not running; leaving the service stopped."
    exit 0
fi

if [ ! -f "${XRAY_CONFIG}" ]; then
    echo "WARNING: ${XRAY_CONFIG} is missing; service NOT restarted."
    exit 0
fi

# If the new template produced a config Xray rejects, keep the old process
# alive (it still holds the previously working config) instead of stopping
# the service and failing to start it.
if ! "${XRAY_BIN}" run -test -c "${XRAY_CONFIG}" >/dev/null 2>&1; then
    echo "WARNING: regenerated ${XRAY_CONFIG} failed 'xray run -test'; service NOT restarted. See the configd log for the template error."
    exit 0
fi

echo "Restarting Xray Client with the updated plugin..."
if "${RC_SCRIPT}" restart >/dev/null 2>&1; then
    if "${RC_SCRIPT}" status >/dev/null 2>&1; then
        echo "Xray Client restarted with the updated plugin."
    else
        echo "WARNING: restart reported success but the service is not running; see /var/log/xray/error.log."
    fi
else
    echo "WARNING: Xray Client restart failed; see /var/log/xray/error.log."
fi

exit 0
