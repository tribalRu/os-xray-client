#!/bin/sh

ACTION="$1"
CONFIG_XML="/conf/config.xml"

ENABLE_TUN=$(xmllint --xpath "string(//OPNsense/XrayClient/general/enable_tun)" "${CONFIG_XML}" 2>/dev/null)
TUN_IFACE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_iface)" "${CONFIG_XML}" 2>/dev/null)
TUN_ADDR=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_address)" "${CONFIG_XML}" 2>/dev/null)
TUN_MTU=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_mtu)" "${CONFIG_XML}" 2>/dev/null)

[ -z "${TUN_IFACE}" ] && TUN_IFACE="tun_xray0"
[ -z "${TUN_ADDR}" ] && TUN_ADDR="10.255.0.1/30"
[ -z "${TUN_MTU}" ] && TUN_MTU="1500"

if [ "${ACTION}" = "up" ]; then
    if [ "${ENABLE_TUN}" != "1" ]; then
        exit 0
    fi

    if ! ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        NEW_TUN=$(ifconfig tun create)
        ifconfig "${NEW_TUN}" name "${TUN_IFACE}"
    fi

    LOCAL_IP=$(echo "${TUN_ADDR}" | cut -d'/' -f1)
    BASE_NET=$(echo "${LOCAL_IP}" | cut -d'.' -f1-3)
    LAST_OCTET=$(echo "${LOCAL_IP}" | cut -d'.' -f4)
    PEER_OCTET=$((LAST_OCTET + 1))
    PEER_IP="${BASE_NET}.${PEER_OCTET}"

    ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" "${PEER_IP}" netmask 255.255.255.252 mtu "${TUN_MTU}" up
elif [ "${ACTION}" = "down" ]; then
    if ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        ifconfig "${TUN_IFACE}" destroy
    fi
fi

exit 0
