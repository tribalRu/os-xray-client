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

TMP_DIR=$(mktemp -d /tmp/os_xray_plugin_update.XXXXXX) || {
    echo "ERROR: Could not create a temporary directory."
    exit 1
}
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

echo "=== Updating os-xray-client from ${ARCHIVE_URL} ==="

if ! fetch -q -o "${TMP_DIR}/plugin.tar.gz" "${ARCHIVE_URL}"; then
    echo "ERROR: Failed to download repository archive from GitHub. Check URL and branch name."
    exit 1
fi

# Refuse archives that contain absolute paths or '..' components before
# extracting anything.
if tar -tzf "${TMP_DIR}/plugin.tar.gz" | grep -qE '(^/|(^|/)\.\.(/|$))'; then
    echo "ERROR: Archive contains unsafe paths; aborting."
    exit 1
fi

mkdir -p "${TMP_DIR}/src"
tar -xzf "${TMP_DIR}/plugin.tar.gz" -C "${TMP_DIR}/src" || {
    echo "ERROR: Failed to extract repository archive."
    exit 1
}
EXTRACTED_DIR=$(find "${TMP_DIR}/src" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "${EXTRACTED_DIR}" ] || [ ! -f "${EXTRACTED_DIR}/install.sh" ]; then
    echo "ERROR: install.sh not found in the downloaded repository archive."
    exit 1
fi

echo "Running installer..."
sh "${EXTRACTED_DIR}/install.sh" || {
    echo "ERROR: Installer failed; the plugin may be partially updated."
    exit 1
}

echo "=== Plugin successfully updated from GitHub! ==="
exit 0
