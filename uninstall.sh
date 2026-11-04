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

rm -f /tmp/opnsense_menu_cache.xml
rm -f /tmp/opnsense_acl_cache.json
service configd restart

echo "=== os-xray-client removed cleanly! ==="
