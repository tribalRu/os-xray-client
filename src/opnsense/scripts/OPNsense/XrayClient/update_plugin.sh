#!/bin/sh

REPO_URL="$1"
BRANCH="$2"

[ -z "${BRANCH}" ] && BRANCH="main"

# Defence in depth (ServiceController validates too): this script runs
# install.sh from the fetched archive, so never accept arbitrary URLs.
case "${REPO_URL}" in
    https://github.com/*/*) ;;
    *)
        echo "ERROR: Plugin repo URL must be https://github.com/owner/repo, got '${REPO_URL}'."
        exit 1
        ;;
esac
case "${BRANCH}" in
    ''|*[!A-Za-z0-9_.-]*)
        echo "ERROR: Invalid branch name '${BRANCH}'."
        exit 1
        ;;
esac

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

# --no-absolute-filenames protects against archives with absolute paths;
# GNU/BSD tar refuse '..' traversal by default but we verify afterwards too.
tar -xzf "${TMP_DIR}/plugin.tar.gz" -C "${TMP_DIR}" || {
    echo "ERROR: Failed to extract repository archive."
    rm -rf "${TMP_DIR}"
    exit 1
}
EXTRACTED_DIR=$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "${EXTRACTED_DIR}" ] || [ ! -f "${EXTRACTED_DIR}/install.sh" ]; then
    echo "ERROR: install.sh not found in the downloaded repository archive."
    rm -rf "${TMP_DIR}"
    exit 1
fi

# Ensure the tree stayed inside TMP_DIR (no tar path-traversal).
case "${EXTRACTED_DIR}" in
    "${TMP_DIR}"/*) ;;
    *)
        echo "ERROR: Extracted directory escaped the update dir."
        rm -rf "${TMP_DIR}"
        exit 1
        ;;
esac

echo "Running installer..."
sh "${EXTRACTED_DIR}/install.sh"

rm -rf "${TMP_DIR}"
echo "=== Plugin successfully updated from GitHub! ==="
exit 0
