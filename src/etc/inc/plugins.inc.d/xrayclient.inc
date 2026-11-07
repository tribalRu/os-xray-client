<?php

function xrayclient_enabled()
{
    global $config;
    return isset($config['OPNsense']['XrayClient']['general']['enabled']) &&
           (string)$config['OPNsense']['XrayClient']['general']['enabled'] === '1';
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