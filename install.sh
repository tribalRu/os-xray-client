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

chmod +x /usr/local/etc/rc.d/os-xray-client
chmod +x /usr/local/opnsense/scripts/OPNsense/XrayClient/*.sh
chmod +x /usr/local/opnsense/scripts/OPNsense/XrayClient/*.py

echo "2.1.1" > /usr/local/opnsense/scripts/OPNsense/XrayClient/PLUGIN_VERSION

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

echo "Restarting configd service..."
service configd restart
configctl template reload OPNsense/XrayClient || echo "WARNING: template reload failed."

if [ ! -x "/usr/local/bin/xray" ]; then
    echo "Xray binary not found. Downloading latest stable Xray-core..."
    /usr/local/opnsense/scripts/OPNsense/XrayClient/update_core.sh stable || true
    /usr/local/opnsense/scripts/OPNsense/XrayClient/update_geodata.sh runetfreedom none none || true
fi

echo "=== Installation complete! ==="
