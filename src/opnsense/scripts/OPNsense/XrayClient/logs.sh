#!/bin/sh

ACTION="$1"
LOG_TYPE="$2"
LINES="$3"

LOG_DIR="/var/log/xray"
[ -z "${LINES}" ] && LINES=200

if [ "${ACTION}" = "clear" ]; then
    : > "${LOG_DIR}/access.log" 2>/dev/null
    : > "${LOG_DIR}/error.log" 2>/dev/null
    echo "Logs cleared."
    exit 0
fi

if [ "${LOG_TYPE}" = "access" ]; then
    TARGET_LOG="${LOG_DIR}/access.log"
else
    TARGET_LOG="${LOG_DIR}/error.log"
fi

if [ -f "${TARGET_LOG}" ]; then
    tail -n "${LINES}" "${TARGET_LOG}"
else
    echo "Log file ${TARGET_LOG} does not exist yet."
fi
