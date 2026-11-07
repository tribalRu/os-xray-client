#!/bin/sh

echo "=== Uninstalling os-xray-client plugin ==="

if [ -x "/usr/local/etc/rc.d/os-xray-client" ]; then
    /usr/local/etc/rc.d/os-xray-client stop 2>/dev/null || true
fi

if [ -x "/usr/local/opnsense/scripts/OPNsense/XrayClient/setup_tun.sh" ]; then
    /usr/local/opnsense/scripts/OPNsense/XrayClient/setup_tun.sh down 2>/dev/null || true
fi

rm -f /usr/local/etc/inc/plugins.inc.d/xrayclient.inc
rm -f /usr/local/etc/rc.d/os-xray-client
rm -f /usr/local/opnsense/service/conf/actions.d/actions_xrayclient.conf
rm -rf /usr/local/opnsense/mvc/app/controllers/OPNsense/XrayClient
rm -rf /usr/local/opnsense/mvc/app/models/OPNsense/XrayClient
rm -rf /usr/local/opnsense/mvc/app/views/OPNsense/XrayClient
rm -rf /usr/local/opnsense/scripts/OPNsense/XrayClient
rm -rf /usr/local/opnsense/service/templates/OPNsense/XrayClient
rm -f /usr/local/opnsense/www/js/widgets/XrayClient.js
rm -f /usr/local/opnsense/www/js/widgets/Metadata/XrayClient.xml
rm -f /var/run/xrayclient.pid
rm -f /var/lib/php/tmp/opnsense_menu_cache.xml /tmp/opnsense_menu_cache.xml
rm -f /var/lib/php/tmp/opnsense_acl_cache.json /tmp/opnsense_acl_cache.json
rm -rf /var/lib/php/cache/* 2>/dev/null || true
rm -rf /var/tmp/volt /tmp/volt* 2>/dev/null || true

if command -v service >/dev/null 2>&1; then
    service configd restart 2>/dev/null || true
fi

echo "=== os-xray-client removed! ==="
echo "Note: Xray binary, GeoData and /usr/local/etc/xray/config.json are kept"
echo "for a future reinstall. Remove them manually if you want a clean box."
