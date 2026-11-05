#!/bin/sh

BRANCH="$1"
[ -z "${BRANCH}" ] && BRANCH="stable"

case "${BRANCH}" in
    stable|latest) ;;
    *)
        echo "ERROR: Invalid branch '${BRANCH}' (expected stable or latest)."
        exit 1
        ;;
esac

# Pick the correct FreeBSD asset for this host.
case "$(uname -m)" in
    amd64|x86_64)
        ASSET_PATTERN="freebsd-64.zip"
        ;;
    aarch64|arm64)
        ASSET_PATTERN="freebsd-arm64-v8a.zip"
        ;;
    *)
        echo "ERROR: Unsupported architecture $(uname -m)."
        exit 1
        ;;
esac

TMP_DIR="/tmp/xray_core_update"
XRAY_BIN="/usr/local/bin/xray"
ASSET_DIR="/usr/local/share/xray"

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}" "${ASSET_DIR}"

echo "=== Fetching Xray-core release info from GitHub (Channel: ${BRANCH}, Asset: ${ASSET_PATTERN}) ==="

DOWNLOAD_URL=$(/usr/local/bin/python3 - "${BRANCH}" "${ASSET_PATTERN}" << 'EOF'
import sys
import json
import urllib.request

branch = sys.argv[1] if len(sys.argv) > 1 else 'stable'
pattern = sys.argv[2] if len(sys.argv) > 2 else 'freebsd-64.zip'
api_url = 'https://api.github.com/repos/XTLS/Xray-core/releases/latest' if branch == 'stable' else 'https://api.github.com/repos/XTLS/Xray-core/releases'

req = urllib.request.Request(api_url, headers={'User-Agent': 'OPNsense-XrayClient-Updater'})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        release = data if branch == 'stable' else data[0]
        tag = release.get('tag_name', 'unknown')
        for asset in release.get('assets', []):
            name = asset.get('name', '')
            if pattern.lower() in name.lower():
                print(f"{tag}|{asset.get('browser_download_url')}")
                sys.exit(0)
    sys.stderr.write(f"Error: asset *{pattern}* not found in release\n")
    sys.exit(1)
except Exception as e:
    sys.stderr.write(f"Error querying GitHub API: {e}\n")
    sys.exit(1)
EOF
)

if [ -z "${DOWNLOAD_URL}" ]; then
    echo "ERROR: Could not resolve download URL for *${ASSET_PATTERN}* from GitHub."
    rm -rf "${TMP_DIR}"
    exit 1
fi

TAG=$(echo "${DOWNLOAD_URL}" | cut -d'|' -f1)
URL=$(echo "${DOWNLOAD_URL}" | cut -d'|' -f2)

echo "Found version: ${TAG}"
echo "Downloading: ${URL}"

if ! fetch -q -o "${TMP_DIR}/xray.zip" "${URL}"; then
    echo "ERROR: Failed to download Xray archive."
    rm -rf "${TMP_DIR}"
    exit 1
fi

echo "Extracting archive..."
if command -v unzip >/dev/null 2>&1; then
    if ! unzip -oq "${TMP_DIR}/xray.zip" -d "${TMP_DIR}"; then
        echo "ERROR: Failed to unzip archive."
        rm -rf "${TMP_DIR}"
        exit 1
    fi
else
    echo "unzip not found, extracting with Python..."
    if ! /usr/local/bin/python3 - "${TMP_DIR}/xray.zip" "${TMP_DIR}" << 'EOF'
import sys
import zipfile

src, dst = sys.argv[1], sys.argv[2]
try:
    with zipfile.ZipFile(src) as z:
        z.extractall(dst)
except Exception as e:
    print(f"extract error: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    then
        echo "ERROR: Failed to extract archive."
        rm -rf "${TMP_DIR}"
        exit 1
    fi
fi

if [ ! -f "${TMP_DIR}/xray" ]; then
    echo "ERROR: xray binary not found in archive."
    rm -rf "${TMP_DIR}"
    exit 1
fi

WAS_RUNNING=0
if /usr/local/etc/rc.d/os-xray-client status >/dev/null 2>&1; then
    WAS_RUNNING=1
    echo "Stopping running Xray service..."
    /usr/local/etc/rc.d/os-xray-client stop
fi

install -m 0755 "${TMP_DIR}/xray" "${XRAY_BIN}"

if [ ! -f "${ASSET_DIR}/geoip.dat" ] && [ -f "${TMP_DIR}/geoip.dat" ]; then
    install -m 0644 "${TMP_DIR}/geoip.dat" "${ASSET_DIR}/geoip.dat"
fi
if [ ! -f "${ASSET_DIR}/geosite.dat" ] && [ -f "${TMP_DIR}/geosite.dat" ]; then
    install -m 0644 "${TMP_DIR}/geosite.dat" "${ASSET_DIR}/geosite.dat"
fi

# Verify the installed binary actually runs on this host.
if ! "${XRAY_BIN}" version >/dev/null 2>&1; then
    echo "ERROR: Installed Xray binary does not run on this host (wrong arch or corrupted download)."
    if [ "${WAS_RUNNING}" -eq 1 ]; then
        /usr/local/etc/rc.d/os-xray-client start >/dev/null 2>&1 || true
    fi
    rm -rf "${TMP_DIR}"
    exit 1
fi

if [ "${WAS_RUNNING}" -eq 1 ]; then
    echo "Starting Xray service..."
    /usr/local/etc/rc.d/os-xray-client start
fi

rm -rf "${TMP_DIR}"
echo "=== Successfully updated Xray-core to ${TAG}! ==="
exit 0
