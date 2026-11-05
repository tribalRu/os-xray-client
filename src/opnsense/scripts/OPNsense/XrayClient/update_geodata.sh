#!/bin/sh

PRESET="$1"
CUSTOM_GEOIP="$2"
CUSTOM_GEOSITE="$3"

ASSET_DIR="/usr/local/share/xray"
TMP_DIR="/tmp/xray_geodata_update"

mkdir -p "${ASSET_DIR}" "${TMP_DIR}"
FAILED=0

case "${PRESET}" in
    official)
        GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
        GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        ;;
    runetfreedom)
        GEOIP_URL="https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat"
        GEOSITE_URL="https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat"
        ;;
    zaborona)
        # NOTE: Chocolate4U publishes Iran-specific rules, not RU rules.
        GEOIP_URL="https://github.com/Chocolate4U/Iran-v2ray-rules/releases/latest/download/geoip.dat"
        GEOSITE_URL="https://github.com/Chocolate4U/Iran-v2ray-rules/releases/latest/download/geosite.dat"
        ;;
    custom)
        GEOIP_URL="${CUSTOM_GEOIP}"
        GEOSITE_URL="${CUSTOM_GEOSITE}"
        ;;
    *)
        GEOIP_URL="https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat"
        GEOSITE_URL="https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat"
        ;;
esac

echo "=== Updating GeoIP & GeoSite Databases (Preset: ${PRESET}) ==="

if [ -n "${GEOIP_URL}" ] && [ "${GEOIP_URL}" != "none" ]; then
    echo "Downloading geoip.dat from: ${GEOIP_URL}"
    if fetch -q -o "${TMP_DIR}/geoip.dat" "${GEOIP_URL}" && [ -s "${TMP_DIR}/geoip.dat" ]; then
        install -m 0644 "${TMP_DIR}/geoip.dat" "${ASSET_DIR}/geoip.dat"
        echo "geoip.dat updated successfully."
    else
        echo "ERROR: Failed to download geoip.dat or file is empty."
        FAILED=1
    fi
else
    echo "geoip.dat: no URL configured, skipping."
fi

if [ -n "${GEOSITE_URL}" ] && [ "${GEOSITE_URL}" != "none" ]; then
    echo "Downloading geosite.dat from: ${GEOSITE_URL}"
    if fetch -q -o "${TMP_DIR}/geosite.dat" "${GEOSITE_URL}" && [ -s "${TMP_DIR}/geosite.dat" ]; then
        install -m 0644 "${TMP_DIR}/geosite.dat" "${ASSET_DIR}/geosite.dat"
        echo "geosite.dat updated successfully."
    else
        echo "ERROR: Failed to download geosite.dat or file is empty."
        FAILED=1
    fi
else
    echo "geosite.dat: no URL configured, skipping."
fi

rm -rf "${TMP_DIR}"

if [ "${FAILED}" -ne 0 ]; then
    echo "=== GeoData update FAILED ==="
    exit 1
fi

if /usr/local/etc/rc.d/os-xray-client status >/dev/null 2>&1; then
    echo "Restarting Xray service to reload GeoData..."
    /usr/local/etc/rc.d/os-xray-client restart
fi

echo "=== GeoData update completed! ==="
exit 0
