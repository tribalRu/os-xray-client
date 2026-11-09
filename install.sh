#!/bin/sh

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC_DIR="${SCRIPT_DIR}/src"

echo "=== Installing os-xray-client plugin for OPNsense ==="

if [ ! -d "${SRC_DIR}" ]; then
    echo "ERROR: src/ directory not found in ${SCRIPT_DIR}"
    exit 1
fi

install -d -m 0755 /usr/local/etc/inc/plugins.inc.d
install -d -m 0755 /usr/local/etc/rc.d
install -d -m 0755 /usr/local/etc/xray
install -d -m 0755 /usr/local/share/xray
install -d -m 0755 /var/log/xray

cp -R "${SRC_DIR}/etc/"* /usr/local/etc/
cp -R "${SRC_DIR}/opnsense/"* /usr/local/opnsense/

# Register the Xray log line format in OPNsense's unified log viewer
# (Diagnostics → Logs), so /ui/diagnostics/logs/xray/{error,access} can
# filter by severity and history. Non-fatal on purpose: without this file
# the logs are still readable, just without severity parsing.
LOGFORMATS_DIR=/usr/local/opnsense/scripts/syslog/logformats
if [ -d "${LOGFORMATS_DIR}" ]; then
    cp "${SRC_DIR}/opnsense/scripts/OPNsense/XrayClient/logformats/xraylog.py" "${LOGFORMATS_DIR}/xraylog.py" \
        && chmod 0644 "${LOGFORMATS_DIR}/xraylog.py" \
        || echo "WARNING: could not install ${LOGFORMATS_DIR}/xraylog.py (log filter will show rows without severity)."
fi

# Developer-only unit tests are not needed on the firewall.
rm -f /usr/local/opnsense/scripts/OPNsense/XrayClient/test_scripts.py

chmod +x /usr/local/etc/rc.d/os-xray-client
chmod +x /usr/local/opnsense/scripts/OPNsense/XrayClient/*.sh
chmod +x /usr/local/opnsense/scripts/OPNsense/XrayClient/*.py

# The model version in XrayClient.xml is the plugin version (migrations are
# keyed on it too), so it is the single place to bump; the UI reads it back
# from PLUGIN_VERSION.
MODEL_XML="${SRC_DIR}/opnsense/mvc/app/models/OPNsense/XrayClient/XrayClient.xml"
PLUGIN_VER=$(sed -n 's|.*<version>[[:space:]]*\([0-9][0-9.]*\)[[:space:]]*</version>.*|\1|p' "${MODEL_XML}" 2>/dev/null | head -n 1)
echo "${PLUGIN_VER:-unknown}" > /usr/local/opnsense/scripts/OPNsense/XrayClient/PLUGIN_VERSION

echo "Running OPNsense MVC migrations..."
/usr/local/opnsense/mvc/script/run_migrations.php || {
    echo "ERROR: model migrations failed. Installation aborted."
    exit 1
}

echo "Clearing OPNsense UI, menu, ACL and compiled Volt cache..."
# Volt compiles .volt templates into $cacheDir (/var/lib/php/cache);
# menu/ACL XML caches live in /var/lib/php/tmp on OPNsense 26.
rm -f /var/lib/php/tmp/opnsense_menu_cache.xml /tmp/opnsense_menu_cache.xml
rm -f /var/lib/php/tmp/opnsense_acl_cache.json /tmp/opnsense_acl_cache.json
rm -rf /var/lib/php/cache/* 2>/dev/null || true
rm -rf /var/tmp/volt 2>/dev/null || true
rm -rf /tmp/volt* 2>/dev/null || true

# The in-memory Xray process still runs the code it was started with, and it
# may be using a config rendered by the previous template. Restart it once
# the new plugin files are in place and configd has re-rendered config.json.
# The helper keeps a stopped (or GUI-disabled) service stopped and refuses to
# restart into a config `xray run -test` rejects.
RESTART_HELPER="/usr/local/opnsense/scripts/OPNsense/XrayClient/restart_service.sh"

# Restarting configd kills the process tree of the configd action that runs
# the in-GUI plugin update (it started this script), which cut the response
# off mid-update. In that case (update_plugin.sh sets XRAY_FROM_CONFIGD=1)
# do the restart from a detached process once this script has finished.
if [ "${XRAY_FROM_CONFIGD}" = "1" ]; then
    echo "Scheduling configd restart, template reload and Xray Client restart..."
    /usr/sbin/daemon -f /bin/sh -c "sleep 3; service configd restart; sleep 2; configctl template reload OPNsense/XrayClient; sleep 1; ${RESTART_HELPER}"
else
    echo "Restarting configd service..."
    service configd restart
    configctl template reload OPNsense/XrayClient || echo "WARNING: template reload failed."
    "${RESTART_HELPER}"
fi

if [ ! -x "/usr/local/bin/xray" ]; then
    echo "Xray binary not found. Downloading latest stable Xray-core..."
    /usr/local/opnsense/scripts/OPNsense/XrayClient/update_core.sh stable || true
    /usr/local/opnsense/scripts/OPNsense/XrayClient/update_geodata.sh runetfreedom none none || true
fi

echo "=== Installation complete! ==="
