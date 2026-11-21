#!/bin/sh
#
# Backup and restore of the plugin's own files around an install or update.
#
#   plugin_backup.sh backup            copy the installed plugin files and
#                                      /conf/config.xml to /root/os-xray-client-backup-<time>/
#                                      and print BACKUP_DIR=<path>
#   plugin_backup.sh restore <dir> [config]
#                                      put the files back (and config.xml when
#                                      the word "config" is given)
#
# The last 3 backups are kept. XRAY_ROOT / XRAY_BACKUP_BASE exist for tests.

ROOT="${XRAY_ROOT:-}"
BASE="${XRAY_BACKUP_BASE:-${ROOT}/root}"
KEEP=3

# Paths below the root, without a leading slash (tar stores them relative)
PATHS="usr/local/opnsense/mvc/app/models/OPNsense/XrayClient
usr/local/opnsense/mvc/app/controllers/OPNsense/XrayClient
usr/local/opnsense/mvc/app/views/OPNsense/XrayClient
usr/local/opnsense/scripts/OPNsense/XrayClient
usr/local/opnsense/service/templates/OPNsense/XrayClient
usr/local/opnsense/service/conf/actions.d/actions_xrayclient.conf
usr/local/etc/rc.d/os-xray-client
usr/local/etc/inc/plugins.inc.d/xrayclient.inc"

action="$1"

case "${action}" in
backup)
    existing=""
    for p in ${PATHS}; do
        [ -e "${ROOT}/${p}" ] && existing="${existing} ${p}"
    done
    if [ -z "${existing}" ]; then
        echo "Fresh installation: nothing to back up."
        exit 0
    fi
    dir="${BASE}/os-xray-client-backup-$(date +%Y%m%d-%H%M%S)"
    umask 077
    mkdir -p "${dir}" || { echo "WARNING: cannot create ${dir}; continuing without a backup." >&2; exit 0; }
    # shellcheck disable=SC2086
    if ! tar -cpf "${dir}/plugin-files.tar" -C "${ROOT:-/}" ${existing}; then
        echo "WARNING: could not archive the plugin files; continuing without a backup." >&2
        rm -rf "${dir}"
        exit 0
    fi
    for p in ${existing}; do echo "${p}"; done > "${dir}/paths.txt"
    [ -f "${ROOT}/conf/config.xml" ] && cp -p "${ROOT}/conf/config.xml" "${dir}/config.xml" && chmod 600 "${dir}/config.xml"
    ver="${ROOT}/usr/local/opnsense/scripts/OPNsense/XrayClient/PLUGIN_VERSION"
    [ -f "${ver}" ] && cp -p "${ver}" "${dir}/PLUGIN_VERSION"
    # keep the newest $KEEP backups (BSD head has no negative counts)
    count=$(ls -1d "${BASE}"/os-xray-client-backup-* 2>/dev/null | wc -l | tr -d ' ')
    if [ "${count}" -gt "${KEEP}" ]; then
        for o in $(ls -1d "${BASE}"/os-xray-client-backup-* | sort | awk -v n="$((count - KEEP))" 'NR<=n'); do
            rm -rf "${o}"
        done
    fi
    echo "Backup of the current plugin files: ${dir}"
    echo "BACKUP_DIR=${dir}"
    ;;
restore)
    dir="$2"
    if [ -z "${dir}" ] || [ ! -f "${dir}/plugin-files.tar" ] || [ ! -f "${dir}/paths.txt" ]; then
        echo "ERROR: ${dir:-<no directory>} is not a plugin backup." >&2
        exit 1
    fi
    while read -r p; do
        [ -n "${p}" ] && rm -rf "${ROOT:?}/${p}"
    done < "${dir}/paths.txt"
    tar -xpf "${dir}/plugin-files.tar" -C "${ROOT:-/}" || { echo "ERROR: could not extract ${dir}/plugin-files.tar" >&2; exit 1; }
    if [ "$3" = "config" ] && [ -f "${dir}/config.xml" ]; then
        cp -p "${dir}/config.xml" "${ROOT}/conf/config.xml"
        echo "Restored /conf/config.xml from ${dir}."
    fi
    echo "Restored the plugin files from ${dir}."
    ;;
*)
    echo "usage: $0 backup | restore <dir> [config]" >&2
    exit 2
    ;;
esac
