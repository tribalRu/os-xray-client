#!/bin/sh
ACTION="$1"
CONFIG_XML="/conf/config.xml"

TUN_IFACE="tun_xray0"
TUN_ADDR="10.255.0.1/30"

if [ -f "${CONFIG_XML}" ]; then
    VAL_IFACE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_iface)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${VAL_IFACE}" ] && TUN_IFACE="${VAL_IFACE}"
    
    VAL_ADDR=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_address)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${VAL_ADDR}" ] && TUN_ADDR="${VAL_ADDR}"
fi

LOCAL_IP=$(echo "${TUN_ADDR}" | cut -d'/' -f1)
PEER_IP="10.255.0.2"

if [ "${ACTION}" = "up" ]; then
    if ! ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        NEW_TUN=$(ifconfig tun create)
        ifconfig "${NEW_TUN}" name "${TUN_IFACE}"
    fi

    # Назначаем IP и поднимаем интерфейс в режиме point-to-point
    ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" "${PEER_IP}" netmask 255.255.255.252 up
    
    # Добавляем прямой хостовый маршрут на peer
    route add -inet "${PEER_IP}" -iface "${TUN_IFACE}" 2>/dev/null || true

elif [ "${ACTION}" = "down" ]; then
    if ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        ifconfig "${TUN_IFACE}" destroy
    fi
fi

exit 0