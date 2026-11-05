#!/bin/sh
ACTION="$1"
CONFIG_XML="/conf/config.xml"

# Значения по умолчанию на случай отсутствия конфига
TUN_IFACE="tun_xray0"
TUN_ADDR="10.255.0.1/30"

if [ -f "${CONFIG_XML}" ]; then
    VAL_IFACE=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_iface)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${VAL_IFACE}" ] && TUN_IFACE="${VAL_IFACE}"
    
    VAL_ADDR=$(xmllint --xpath "string(//OPNsense/XrayClient/general/tun_address)" "${CONFIG_XML}" 2>/dev/null)
    [ -n "${VAL_ADDR}" ] && TUN_ADDR="${VAL_ADDR}"
fi

# Парсим IP и маску из строки вида 10.255.0.1/30
LOCAL_IP=$(echo "${TUN_ADDR}" | cut -d'/' -f1)
CIDR=$(echo "${TUN_ADDR}" | cut -d'/' -f2)
[ -z "${CIDR}" ] && CIDR="30"

# Функция для конвертации IP в число (для расчёта peer-адреса)
ip_to_int() {
    local a b c d
    IFS=. read -r a b c d <<EOF
$1
EOF
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

# Функция для конвертации числа обратно в IP
int_to_ip() {
    local num=$1
    echo "$(( (num >> 24) & 255 )).$(( (num >> 16) & 255 )).$(( (num >> 8) & 255 )).$(( num & 255 ))"
}

LOCAL_INT=$(ip_to_int "${LOCAL_IP}")

if [ "${ACTION}" = "up" ]; then
    if ! ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        NEW_TUN=$(ifconfig tun create)
        ifconfig "${NEW_TUN}" name "${TUN_IFACE}"
    fi

    if [ "${CIDR}" = "30" ]; then
        # Для /30 подсети: если роутер .1, то peer обычно .2 (и наоборот)
        PEER_INT=$(( LOCAL_INT ^ 1 ))
        PEER_IP=$(int_to_ip "${PEER_INT}")
        
        ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" "${PEER_IP}" netmask 255.255.255.252 up
        route add "${PEER_IP}" -interface "${TUN_IFACE}" 2>/dev/null || true
    else
        # Для других масок поднимаем интерфейс с маской сети
        NETMASK=$(( 0xFFFFFFFF ^ ((1 << (32 - CIDR)) - 1) ))
        NETMASK_IP=$(int_to_ip "${NETMASK}")
        
        ifconfig "${TUN_IFACE}" inet "${LOCAL_IP}" netmask "${NETMASK_IP}" up
    fi

elif [ "${ACTION}" = "down" ]; then
    if ifconfig "${TUN_IFACE}" >/dev/null 2>&1; then
        ifconfig "${TUN_IFACE}" destroy
    fi
fi

exit 0