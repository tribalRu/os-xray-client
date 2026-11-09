#!/usr/local/bin/php
<?php

/*
 * Writes /var/run/xrayclient-outbounds.json:
 *     {"node_<uuid>": "<node name>", ...}
 *
 * Consumed by the unified OPNsense log viewer through the plugin's xraylog
 * format handler, which rewrites raw outbound tags to human-readable node
 * names in the Process column. Reads /conf/config.xml directly (only tagged
 * outbound nodes are of interest).
 *
 * The config.xml is parsed with regexes, not simplexml, on purpose: this
 * script survives any minimal PHP CLI install (no expat/simplexml required)
 * and does not depend on OPNsense's internal XML class paths. The XrayClient
 * section contains only flat nodes, so this is safe here.
 *
 * Called by install.sh and ServiceController::reconfigureAction() (after any
 * Apply), so the file always matches the applied configuration.
 * Safe to run standalone.
 */

$out = array();
$buf = @file_get_contents('/conf/config.xml');
if ($buf !== false && preg_match('#<XrayClient\b(.*?)</XrayClient>#s', $buf, $section)) {
    $xbuf = $section[1];
    if (preg_match_all('#<node\s+uuid="([0-9A-Fa-f-]{36})"\s*>(.*?)</node>#s', $xbuf, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $m) {
            $uuid = $m[1];
            $name = '';
            if (preg_match('#<name>(.*?)</name>#s', $m[2], $nm)) {
                $name = trim(html_entity_decode($nm[1], ENT_QUOTES | ENT_XML1, 'UTF-8'));
            }
            if ($name === '') {
                $name = substr($uuid, 0, 8);
            }
            $out['node_' . $uuid] = $name;
        }
    }
}
@file_put_contents('/var/run/xrayclient-outbounds.json', json_encode($out));
