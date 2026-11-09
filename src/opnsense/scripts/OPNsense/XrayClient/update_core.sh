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
        ASSET_SUFFIX="freebsd-64.zip"
        ;;
    aarch64|arm64)
        ASSET_SUFFIX="freebsd-arm64-v8a.zip"
        ;;
    *)
        echo "ERROR: Unsupported architecture $(uname -m)."
        exit 1
        ;;
esac

# The paths and the release API URL can be overridden for testing.
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"
ASSET_DIR="${XRAY_ASSET_DIR:-/usr/local/share/xray}"
RC_SCRIPT="${XRAY_RC_SCRIPT:-/usr/local/etc/rc.d/os-xray-client}"
PYTHON="${XRAY_PYTHON:-/usr/local/bin/python3}"

TMP_DIR=$(mktemp -d /tmp/xray_core_update.XXXXXX) || {
    echo "ERROR: Could not create a temporary directory."
    exit 1
}
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM
mkdir -p "${ASSET_DIR}"

echo "=== Fetching Xray-core release info from GitHub (Channel: ${BRANCH}, Asset: *${ASSET_SUFFIX}) ==="

# Prints "<tag>|<zip url>|<dgst url>" for the release asset ending in the
# wanted suffix and its .dgst checksum file.
RELEASE_INFO=$("${PYTHON}" - "${BRANCH}" "${ASSET_SUFFIX}" << 'EOF'
import sys
import json
import os
import urllib.request

branch = sys.argv[1]
suffix = sys.argv[2].lower()
default_api = ('https://api.github.com/repos/XTLS/Xray-core/releases/latest'
               if branch == 'stable'
               else 'https://api.github.com/repos/XTLS/Xray-core/releases')
api_url = os.environ.get('XRAY_RELEASE_API', default_api)

req = urllib.request.Request(api_url, headers={'User-Agent': 'OPNsense-XrayClient-Updater'})
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode('utf-8'))
except Exception as e:
    sys.stderr.write(f"Error querying GitHub API: {e}\n")
    sys.exit(1)

release = data if isinstance(data, dict) else (data[0] if data else {})
tag = release.get('tag_name', 'unknown')
urls = {a.get('name', '').lower(): a.get('browser_download_url', '')
        for a in release.get('assets', [])}

zip_name = next((n for n in urls if n.endswith(suffix)), None)
if not zip_name:
    sys.stderr.write(f"Error: no asset ending in {suffix} found in release {tag}\n")
    sys.exit(1)
dgst_url = urls.get(zip_name + '.dgst', '')
if not dgst_url:
    sys.stderr.write(f"Error: release {tag} has no {zip_name}.dgst checksum file; refusing to install unverified binary\n")
    sys.exit(1)
print(f"{tag}|{urls[zip_name]}|{dgst_url}")
EOF
)

if [ -z "${RELEASE_INFO}" ]; then
    echo "ERROR: Could not resolve download URL for *${ASSET_SUFFIX}* from GitHub."
    exit 1
fi

TAG=$(echo "${RELEASE_INFO}" | cut -d'|' -f1)
URL=$(echo "${RELEASE_INFO}" | cut -d'|' -f2)
DGST_URL=$(echo "${RELEASE_INFO}" | cut -d'|' -f3)

echo "Found version: ${TAG}"
echo "Downloading: ${URL}"

# BSD fetch gives up on some hosts/CA bundles; fall back to curl, the same
# way update_plugin.sh and update_geodata.sh do.
download() {
    if fetch -q -o "$2" "$1" && [ -s "$2" ]; then
        return 0
    fi
    echo "fetch failed; trying curl..." >&2
    curl -fsSL --retry 3 -o "$2" "$1" && [ -s "$2" ]
}

if ! download "${URL}" "${TMP_DIR}/xray.zip"; then
    echo "ERROR: Failed to download Xray archive."
    exit 1
fi
if ! download "${DGST_URL}" "${TMP_DIR}/xray.zip.dgst"; then
    echo "ERROR: Failed to download the checksum file."
    exit 1
fi

echo "Verifying SHA-256 checksum..."
if ! "${PYTHON}" - "${TMP_DIR}/xray.zip" "${TMP_DIR}/xray.zip.dgst" << 'EOF'
import hashlib
import re
import sys

zip_path, dgst_path = sys.argv[1], sys.argv[2]
expected = None
with open(dgst_path, 'r', encoding='utf-8', errors='ignore') as fh:
    for line in fh:
        m = re.match(r'\s*SHA2?-?256\s*=\s*([0-9a-fA-F]{64})\s*$', line)
        if m:
            expected = m.group(1).lower()
            break
if not expected:
    sys.stderr.write("no SHA2-256 entry found in the .dgst file\n")
    sys.exit(1)
h = hashlib.sha256()
with open(zip_path, 'rb') as fh:
    for chunk in iter(lambda: fh.read(1 << 20), b''):
        h.update(chunk)
if h.hexdigest() != expected:
    sys.stderr.write(f"checksum mismatch: expected {expected}, got {h.hexdigest()}\n")
    sys.exit(1)
EOF
then
    echo "ERROR: SHA-256 verification of the Xray archive failed; nothing was installed."
    exit 1
fi

echo "Extracting archive..."
mkdir -p "${TMP_DIR}/out"
if command -v unzip >/dev/null 2>&1; then
    if ! unzip -oq "${TMP_DIR}/xray.zip" -d "${TMP_DIR}/out"; then
        echo "ERROR: Failed to unzip archive."
        exit 1
    fi
else
    echo "unzip not found, extracting with Python..."
    if ! "${PYTHON}" - "${TMP_DIR}/xray.zip" "${TMP_DIR}/out" << 'EOF'
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
        exit 1
    fi
fi

if [ ! -f "${TMP_DIR}/out/xray" ]; then
    echo "ERROR: xray binary not found in archive."
    exit 1
fi

# Prove the new binary runs on this host BEFORE touching the installed one.
chmod 0755 "${TMP_DIR}/out/xray"
if ! "${TMP_DIR}/out/xray" version >/dev/null 2>&1; then
    echo "ERROR: The downloaded Xray binary does not run on this host (wrong arch or corrupted download). Installed version left untouched."
    exit 1
fi

# GeoData is only seeded here when missing; use the GeoData update to refresh it.
if [ ! -f "${ASSET_DIR}/geoip.dat" ] && [ -f "${TMP_DIR}/out/geoip.dat" ]; then
    install -m 0644 "${TMP_DIR}/out/geoip.dat" "${ASSET_DIR}/geoip.dat"
fi
if [ ! -f "${ASSET_DIR}/geosite.dat" ] && [ -f "${TMP_DIR}/out/geosite.dat" ]; then
    install -m 0644 "${TMP_DIR}/out/geosite.dat" "${ASSET_DIR}/geosite.dat"
fi

WAS_RUNNING=0
if "${RC_SCRIPT}" status >/dev/null 2>&1; then
    WAS_RUNNING=1
    echo "Stopping running Xray service..."
    "${RC_SCRIPT}" stop
fi

# Keep the previous binary so a bad update can be rolled back.
BACKUP="${XRAY_BIN}.previous"
HAD_OLD=0
if [ -f "${XRAY_BIN}" ]; then
    cp -p "${XRAY_BIN}" "${BACKUP}" && HAD_OLD=1
fi

# Install under a temporary name, then rename: the swap itself is atomic.
if ! install -m 0755 "${TMP_DIR}/out/xray" "${XRAY_BIN}.new" || ! mv -f "${XRAY_BIN}.new" "${XRAY_BIN}"; then
    echo "ERROR: Failed to install the new Xray binary."
    rm -f "${XRAY_BIN}.new"
    if [ "${WAS_RUNNING}" -eq 1 ]; then
        "${RC_SCRIPT}" start >/dev/null 2>&1 || true
    fi
    exit 1
fi

if [ "${WAS_RUNNING}" -eq 1 ]; then
    echo "Starting Xray service..."
    "${RC_SCRIPT}" start
    sleep 2
    if ! "${RC_SCRIPT}" status >/dev/null 2>&1; then
        echo "ERROR: Xray did not start with the new binary."
        if [ "${HAD_OLD}" -eq 1 ]; then
            echo "Rolling back to the previous Xray binary..."
            mv -f "${BACKUP}" "${XRAY_BIN}"
            "${RC_SCRIPT}" start >/dev/null 2>&1 || true
        fi
        exit 1
    fi
fi

echo "=== Successfully updated Xray-core to ${TAG}! ==="
exit 0
