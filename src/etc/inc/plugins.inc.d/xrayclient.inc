<?php

function xrayclient_enabled()
{
    global $config;
    return isset($config['OPNsense']['XrayClient']['general']['enabled']) &&
           (string)$config['OPNsense']['XrayClient']['general']['enabled'] === '1';
}

/**
 * OPNsense does not start the scripts in /usr/local/etc/rc.d on its own: a
 * plugin service comes up at boot only through a hook registered here.
 * "bootup" runs once the interfaces are configured; "local" when the whole
 * configuration is reloaded (the start is a no-op for a running service).
 */
function xrayclient_configure()
{
    return [
        'bootup' => ['xrayclient_configure_do'],
        'local' => ['xrayclient_configure_do'],
    ];
}

function xrayclient_configure_do($verbose = false)
{
    if (!xrayclient_enabled()) {
        return;
    }

    if ($verbose) {
        echo 'Starting Xray Client...';
        flush();
    }

    // fresh config.json first, then start in the background so that the
    // boot does not wait for Xray
    configd_run('template reload OPNsense/XrayClient');
    configd_run('xrayclient start', true);

    if ($verbose) {
        echo "done.\n";
    }
}

function xrayclient_services()
{
    $services = [];

    if (!xrayclient_enabled()) {
        return $services;
    }

    $services[] = [
        'description' => gettext('Xray Client (VLESS, VMess, Trojan, Shadowsocks, WireGuard, Hysteria 2, MASQUE, and more)'),
        'configd' => [
            'restart' => ['xrayclient restart'],
            'start' => ['xrayclient start'],
            'stop' => ['xrayclient stop'],
        ],
        'name' => 'xrayclient',
        'pidfile' => '/var/run/xrayclient.pid',
    ];

    return $services;
}