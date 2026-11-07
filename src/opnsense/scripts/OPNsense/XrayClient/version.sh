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
    [ -z "${GEODATA_DATE}" ] && GEODATA_DATE="Unknown"
else
    GEODATA_DATE="Not Installed"
fi

if [ -f "${PLUGIN_VER_FILE}" ]; then
    PLUGIN_VER=$(cat "${PLUGIN_VER_FILE}" | tr -d '\n\r')
    [ -z "${PLUGIN_VER}" ] && PLUGIN_VER="2.4.2"
else
    PLUGIN_VER="2.4.2"
fi

# Build JSON via Python so values are escaped correctly.
PLUGIN_VER="${PLUGIN_VER}" CORE_VER="${CORE_VER}" GEODATA_DATE="${GEODATA_DATE}" \
    /usr/local/bin/python3 -c 'import json,os; print(json.dumps({"core_version": os.environ.get("CORE_VER",""), "geodata_date": os.environ.get("GEODATA_DATE",""), "plugin_version": os.environ.get("PLUGIN_VER","")}))'
