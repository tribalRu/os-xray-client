#!/bin/sh
ACTION="$1"
CONFIG_XML="/conf/config.xml"

# Default values (used when config.xml is unreadable or fields are empty).
TUN_IFACE="tun_xray0"
TUN_ADDR="10.255.0.1/30"
ENABLE_TUN="1"

# Parse settings from /conf/config.xml via Python (always present on OPNsense).
# xmllint is not guaranteed on minimal installs; use it only as fallback.
PARSED=""
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
print(val(".//OPNsense/XrayClient/general/tun_address"))
print(val(".//OPNsense/XrayClient/general/enable_tun"))
EOF
    )
    if [ -n "${PARSED}" ]; then
        PARSE_IFACE=$(printf '%s\n' "${PARSED}" | sed -n '1p')
        PARSE_ADDR=$(printf '%s\n' "${PARSED}" | sed -n '2p')
        PARSE_ENABLE=$(printf '%s\n' "${PARSED}" | sed -n '3p')
        [ -n "${PARSE_IFACE}" ] && TUN_IFACE="${PARSE_IFACE}"
        [ -n "${PARSE_ADDR}" ] && TUN_ADDR="${PARSE_ADDR}"
        [ -n "${PARSE_ENABLE}" ] && ENABLE_TUN="${PARSE_ENABLE}"
    fi
elif [ -f "${CONFIG_XML}" ] && command -v xmllint >/dev/null 2>&1; then
    VAL_IFACE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_iface)" "${CONFIG_XML}" 2>/dev/null)
    VAL_ADDR=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_address)" "${CONFIG_XML}" 2>/dev/null)
    VAL_ENABLE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/enable_tun)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${VAL_IFACE}" ] && TUN_IFACE="${VAL_IFACE}"
    [ -n "${VAL_ADDR}" ] && TUN_ADDR="${VAL_ADDR}"
    [ -n "${VAL_ENABLE}" ] && ENABLE_TUN="${VAL_ENABLE}"
fi

case "${ACTION}" in
    up)
        if [ "${ENABLE_TUN}" != "1" ]; then
            echo "TUN inbound is disabled in GUI settings; skipping TUN setup."
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

# Validate tun_address (must be IPv4/CIDR). Fall back is an error: abort
# with a message instead of silently using defaults and breaking routing.
LOCAL_IP=$(printf '%s' "${TUN_ADDR}" | cut -d'/' -f1)
CIDR=$(printf '%s' "${TUN_ADDR}" | cut -d'/' -f2)
[ -z "${CIDR}" ] && CIDR="30"

case "${CIDR}" in
    ''|*[!0-9]*)
        echo "ERROR: Invalid tun_address CIDR in '${TUN_ADDR}' (expected e.g. 10.255.0.1/30)." >&2
        exit 1
        ;;
esac
if [ "${CIDR}" -lt 1 ] || [ "${CIDR}" -gt 32 ]; then
    echo "ERROR: CIDR out of range (1..32) in '${TUN_ADDR}'." >&2
    exit 1
fi
case "${LOCAL_IP}" in
    *.*.*.*) ;;
    *)
        echo "ERROR: Invalid tun_address IP in '${TUN_ADDR}'." >&2
        exit 1
        ;;
esac
# Octet range check (0..255) without regex: each octet must be numeric.
O1=$(printf '%s' "${LOCAL_IP}" | cut -d. -f1)
O2=$(printf '%s' "${LOCAL_IP}" | cut -d. -f2)
O3=$(printf '%s' "${LOCAL_IP}" | cut -d. -f3)
O4=$(printf '%s' "${LOCAL_IP}" | cut -d. -f4)
for O in "${O1}" "${O2}" "${O3}" "${O4}"; do
    case "${O}" in
        ''|*[!0-9]*)
            echo "ERROR: Invalid octet '${O}' in '${TUN_ADDR}'." >&2
            exit 1
            ;;
    esac
    if [ "${O}" -gt 255 ]; then
        echo "ERROR: Octet out of range '${O}' in '${TUN_ADDR}'." >&2
        exit 1
    fi
done

ip_to_int() {
    echo $(( (O1 << 24) + (O2 << 16) + (O3 << 8) + O4 ))
}

int_to_ip() {
    num=$1
    echo "$(( (num >> 24) & 255 )).$(( (num >> 16) & 255 )).$(( (num >> 8) & 255 )).$(( num & 255 ))"
}

if [ "${CIDR}" -eq 32 ]; then
    NETMASK_INT=4294967295
elif [ "${CIDR}" -eq 0 ]; then
    NETMASK_INT=0
else
    NETMASK_INT=$(( 0xFFFFFFFF ^ ((1 << (32 - CIDR)) - 1) ))
fi
NETMASK_IP=$(int_to_ip "${NETMASK_INT}")
LOCAL_INT=$(ip_to_int)

# Peer for point-to-point /30 (first usable = network+1, second = network+2).
# If LOCAL is usable host 1, peer is host 2 and vice versa. Otherwise peer
# defaults to the next address (previous behaviour for exotic /30 setups).
PEER_IP=""
if [ "${CIDR}" -eq 30 ]; then
    NETWORK_INT=$(( LOCAL_INT & NETMASK_INT ))
    if [ "${LOCAL_INT}" -eq $((NETWORK_INT + 1)) ]; then
        PEER_INT=$((NETWORK_INT + 2))
    elif [ "${LOCAL_INT}" -eq $((NETWORK_INT + 2)) ]; then
        PEER_INT=$((NETWORK_INT + 1))
    else
        PEER_INT=$((LOCAL_INT + 1))
    fi
    PEER_IP=$(int_to_ip "${PEER_INT}")
fi

if [ "${ACTION}" = "up" ]; then
    if ! ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        NEW_TUN=$(ifconfig tun create) || {
            echo "ERROR: failed to create tun device." >&2
            exit 1
        }
        ifconfig "${NEW_TUN}" name "${TUN_IFACE}" || {
            echo "ERROR: failed to rename ${NEW_TUN} to ${TUN_IFACE}." >&2
            exit 1
        }
    fi
    if [ "${CIDR}" -eq 30 ] && [ -n "${PEER_IP}" ]; then
        ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" "${PEER_IP}" netmask 255.255.255.252 up || {
            echo "ERROR: failed to configure ${TUN_IFACE} ${LOCAL_IP} ptp ${PEER_IP}." >&2
            exit 1
        }
        route delete -host "${PEER_IP}" >/dev/null 2>&1 || true
        route add -host "${PEER_IP}" -iface "${TUN_IFACE}" || {
            echo "ERROR: failed to add host route for ${PEER_IP} via ${TUN_IFACE}." >&2
            exit 1
        }
    else
        ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" netmask "${NETMASK_IP}" up || {
            echo "ERROR: failed to configure ${TUN_IFACE} ${LOCAL_IP}/${CIDR}." >&2
            exit 1
        }
    fi
elif [ "${ACTION}" = "down" ]; then
    # Remove the host route added in the /30 up branch (best effort).
    if [ -n "${PEER_IP}" ]; then
        route delete -host "${PEER_IP}" >/dev/null 2>&1 || true
    fi
    if ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        ifconfig "${TUN_IFACE}" destroy >/dev/null 2>&1 || true
    fi
fi

exit 0
