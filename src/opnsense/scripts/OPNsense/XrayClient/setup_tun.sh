#!/bin/sh
#
# os-xray-client: TUN interface reconciliation (Xray >= 26 creates the TUN
# itself on FreeBSD via tun(4); the plugin must NOT pre-create it).
#
# What this script does:
#   up   - remove a STALE ${tun_iface} left behind by the old (<= 1.0.1)
#          plugin version or by an unclean Xray crash. Xray recreates the
#          interface itself when it starts, so existence here means stale.
#   down - best-effort removal of any leftover ${tun_iface} after stop.
#
# It never creates, configures or re-routes anything. The inbound lives in
# the generated /usr/local/etc/xray/config.json ("tun-in"), configured via
# General -> Enable Native TUN Inbound / TUN Interface Name / TUN Tunnel
# Subnet / TUN MTU in the GUI.

ACTION="$1"
CONFIG_XML="/conf/config.xml"

TUN_IFACE="tun_xray0"
ENABLE_TUN="1"

# Parse tun_iface / enable_tun from config.xml via python3 (always present
# on OPNsense); xmllint only as fallback.
if [ -f "${CONFIG_XML}" ] && [ -x "/usr/local/bin/python3" ]; then
    PARSED=$(/usr/local/bin/python3 - "${CONFIG_XML}" << 'EOF' 2>/dev/null
import sys
import xml.etree.ElementTree as ET

cfg = sys.argv[1]
try:
    root = ET.parse(cfg).getroot()
except Exception:
    sys.exit(0)

def val(path):
    el = root.findtext(path)
    return (el.strip() if el is not None else "")

print(val(".//OPNsense/XrayClient/general/tun_iface"))
print(val(".//OPNsense/XrayClient/general/enable_tun"))
EOF
    )
    if [ -n "${PARSED}" ]; then
        P_IFACE=$(printf '%s\n' "${PARSED}" | sed -n '1p')
        P_ENABLE=$(printf '%s\n' "${PARSED}" | sed -n '2p')
        [ -n "${P_IFACE}" ] && TUN_IFACE="${P_IFACE}"
        [ -n "${P_ENABLE}" ] && ENABLE_TUN="${P_ENABLE}"
    fi
elif [ -f "${CONFIG_XML}" ] && command -v xmllint >/dev/null 2>&1; then
    VAL_IFACE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_iface)" "${CONFIG_XML}" 2>/dev/null)
    VAL_ENABLE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/enable_tun)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${VAL_IFACE}" ] && TUN_IFACE="${VAL_IFACE}"
    [ -n "${VAL_ENABLE}" ] && ENABLE_TUN="${VAL_ENABLE}"
fi

case "${ACTION}" in
    up)
        if [ "${ENABLE_TUN}" != "1" ]; then
            echo "TUN inbound is disabled in GUI settings; nothing to reconcile."
            exit 0
        fi
        ;;
    down)
        ;;
    "")
        echo "Usage: $0 up|down" >&2
        exit 2
        ;;
    *)
        echo "Unknown action: ${ACTION}" >&2
        exit 2
        ;;
esac

# Interface name sanity (FreeBSD ifname limit is 16 chars incl. NUL).
case "${TUN_IFACE}" in
    ''|*[!A-Za-z0-9_]*)
        echo "ERROR: invalid tun_iface '${TUN_IFACE}' (allowed: a-z A-Z 0-9 _, max 15 chars)." >&2
        exit 1
        ;;
esac
if [ "${#TUN_IFACE}" -gt 15 ]; then
    echo "ERROR: tun_iface '${TUN_IFACE}' too long (max 15 chars)." >&2
    exit 1
fi

if ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
    echo "Removing stale interface ${TUN_IFACE} (Xray will re-create it on start)."
    ifconfig "${TUN_IFACE}" destroy || {
        echo "ERROR: failed to destroy stale interface ${TUN_IFACE}." >&2
        exit 1
    }
else
    echo "No stale ${TUN_IFACE} interface found."
fi

exit 0
