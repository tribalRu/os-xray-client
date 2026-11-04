#!/bin/sh

XRAY_BIN="/usr/local/bin/xray"
GEOIP_FILE="/usr/local/share/xray/geoip.dat"
PLUGIN_VER_FILE="/usr/local/opnsense/scripts/OPNsense/XrayClient/PLUGIN_VERSION"

if [ -x "${XRAY_BIN}" ]; then
    CORE_VER=$("${XRAY_BIN}" version 2>/dev/null | head -n 1 | awk '{print $1, $2}')
    [ -z "${CORE_VER}" ] && CORE_VER="Installed (Unknown Version)"
else
    CORE_VER="Not Installed"
fi

if [ -f "${GEOIP_FILE}" ]; then
    GEODATA_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "${GEOIP_FILE}" 2>/dev/null)
else
    GEODATA_DATE="Not Installed"
fi

if [ -f "${PLUGIN_VER_FILE}" ]; then
    PLUGIN_VER=$(cat "${PLUGIN_VER_FILE}" | tr -d '\n\r')
else
    PLUGIN_VER="1.0.0"
fi

printf '{"core_version": "%s", "geodata_date": "%s", "plugin_version": "%s"}\n' \
    "${CORE_VER}" "${GEODATA_DATE}" "${PLUGIN_VER}"
