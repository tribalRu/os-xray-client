#!/bin/sh

REPO_URL="$1"
BRANCH="$2"

[ -z "${BRANCH}" ] && BRANCH="main"
REPO_CLEAN=$(echo "${REPO_URL}" | sed 's/\.git$//' | sed 's/\/$//')
ARCHIVE_URL="${REPO_CLEAN}/archive/refs/heads/${BRANCH}.tar.gz"

TMP_DIR="/tmp/os_xray_plugin_update"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

echo "=== Updating os-xray-client from ${ARCHIVE_URL} ==="

if ! fetch -q -o "${TMP_DIR}/plugin.tar.gz" "${ARCHIVE_URL}"; then
    echo "ERROR: Failed to download repository archive from GitHub. Check URL and branch name."
    rm -rf "${TMP_DIR}"
    exit 1
fi

tar -xzf "${TMP_DIR}/plugin.tar.gz" -C "${TMP_DIR}"
EXTRACTED_DIR=$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "${EXTRACTED_DIR}" ] || [ ! -f "${EXTRACTED_DIR}/install.sh" ]; then
    echo "ERROR: install.sh not found in the downloaded repository archive."
    rm -rf "${TMP_DIR}"
    exit 1
fi

echo "Running installer..."
sh "${EXTRACTED_DIR}/install.sh"

rm -rf "${TMP_DIR}"
echo "=== Plugin successfully updated from GitHub! ==="
exit 0
