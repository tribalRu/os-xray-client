#!/bin/sh

ACTION="$1"
LOG_TYPE="$2"
LINES="$3"

LOG_DIR="/var/log/xray"

# LINES must be a positive integer (ServiceController clamps too).
case "${LINES}" in
    ''|*[!0-9]*)
        LINES=200
        ;;
esac
if [ "${LINES}" -lt 1 ]; then LINES=200; fi
if [ "${LINES}" -gt 1000 ]; then LINES=1000; fi

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
