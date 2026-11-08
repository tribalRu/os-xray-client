#!/bin/sh

PRESET="$1"
CUSTOM_GEOIP="$2"
CUSTOM_GEOSITE="$3"

# Paths can be overridden for testing.
ASSET_DIR="${XRAY_ASSET_DIR:-/usr/local/share/xray}"
RC_SCRIPT="${XRAY_RC_SCRIPT:-/usr/local/etc/rc.d/os-xray-client}"

TMP_DIR=$(mktemp -d /tmp/xray_geodata_update.XXXXXX) || {
    echo "ERROR: Could not create a temporary directory."
    exit 1
}
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

mkdir -p "${ASSET_DIR}"
FAILED=0
CHANGED=0

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

# Download one list into TMP_DIR and install it, keeping the previous file as
# <name>.previous so a failed restart can be rolled back.
update_one() {
    name="$1"
    url="$2"

    if [ -z "${url}" ] || [ "${url}" = "none" ]; then
        echo "${name}: no URL configured, skipping."
        return 0
    fi
    case "${url}" in
        https://*) ;;
        *)
            echo "ERROR: ${name}: only https:// URLs are allowed, got '${url}'."
            return 1
            ;;
    esac

    echo "Downloading ${name} from: ${url}"
    if fetch -q -o "${TMP_DIR}/${name}" "${url}" && [ -s "${TMP_DIR}/${name}" ]; then
        :
    elif curl -fsSL --retry 3 -o "${TMP_DIR}/${name}" "${url}" && [ -s "${TMP_DIR}/${name}" ]; then
        echo "fetch failed; used curl for ${name}"
    else
        echo "ERROR: Failed to download ${name} or file is empty."
        return 1
    fi

    if [ -f "${ASSET_DIR}/${name}" ]; then
        cp -p "${ASSET_DIR}/${name}" "${ASSET_DIR}/${name}.previous"
    fi
    install -m 0644 "${TMP_DIR}/${name}" "${ASSET_DIR}/${name}.new" &&
        mv -f "${ASSET_DIR}/${name}.new" "${ASSET_DIR}/${name}" || {
        echo "ERROR: Failed to install ${name}."
        rm -f "${ASSET_DIR}/${name}.new"
        return 1
    }
    echo "${name} updated successfully."
    CHANGED=1
    return 0
}

update_one geoip.dat "${GEOIP_URL}" || FAILED=1
update_one geosite.dat "${GEOSITE_URL}" || FAILED=1

if [ "${FAILED}" -ne 0 ]; then
    echo "=== GeoData update FAILED ==="
    exit 1
fi

if [ "${CHANGED}" -eq 1 ] && "${RC_SCRIPT}" status >/dev/null 2>&1; then
    echo "Restarting Xray service to reload GeoData..."
    "${RC_SCRIPT}" restart
    sleep 2
    if ! "${RC_SCRIPT}" status >/dev/null 2>&1; then
        echo "ERROR: Xray did not restart with the new GeoData; restoring the previous files."
        for f in geoip.dat geosite.dat; do
            [ -f "${ASSET_DIR}/${f}.previous" ] && mv -f "${ASSET_DIR}/${f}.previous" "${ASSET_DIR}/${f}"
        done
        "${RC_SCRIPT}" start >/dev/null 2>&1 || true
        echo "=== GeoData update FAILED (rolled back) ==="
        exit 1
    fi
fi

echo "=== GeoData update completed! ==="
exit 0
