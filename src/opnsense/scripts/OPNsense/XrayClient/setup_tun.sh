#!/bin/sh
ACTION="$1"
CONFIG_XML="/conf/config.xml"

# Считываем параметры TUN из формы OPNsense
ENABLE_TUN=$(xmllint --xpath "string(//OPNsense/XrayClient/general/enable_tun)" "${CONFIG_XML}" 2>/dev/null)
TUN_IFACE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_iface)" "${CONFIG_XML}" 2>/dev/null)
TUN_ADDR=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_address)" "${CONFIG_XML}" 2>/dev/null)

[ -z "${TUN_IFACE}" ] && TUN_IFACE="tun_xray0"
[ -z "${TUN_ADDR}" ] && TUN_ADDR="10.255.0.1/30"

# Вычисляем локальный IP (например, 10.255.0.1)
LOCAL_IP=$(echo "${TUN_ADDR}" | cut -d'/' -f1)
# Удаленная точка назначения (peer) для /30 подсети — следующий IP (.2)
PEER_IP="10.255.0.2"

if [ "${ACTION}" = "up" ]; then
    if [ "${ENABLE_TUN}" != "1" ]; then
        exit 0
    fi

    # Создаем интерфейс, если он еще не существует
    if ! ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        NEW_TUN=$(ifconfig tun create)
        ifconfig "${NEW_TUN}" name "${TUN_IFACE}"
    fi

    # Поднимаем интерфейс точки-к-точке
    ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" "${PEER_IP}" netmask 255.255.255.252 up

    # Прописываем статический маршрут до удаленной стороны туннеля
    route add "${PEER_IP}" -interface "${TUN_IFACE}" 2>/dev/null || true

elif [ "${ACTION}" = "down" ]; then
    if ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        ifconfig "${TUN_IFACE}" destroy
    fi
fi

exit 0