#!/usr/local/bin/php
<?php

/*
 * Writes /var/run/xrayclient-outbounds.json:
 *     {"node_<uuid>": "<node name>", ...}
 *
 * Consumed by the unified OPNsense log viewer through the plugin's xraylog
 * format handler, which rewrites raw outbound tags into human-readable node
 * names in the Process column. Reads /conf/config.xml directly (only tagged
 * outbound nodes are of interest), no framework needed. Runs as root.
 *
 * Called by install.sh and ServiceController::reconfigureAction() (after any
 * successful Apply), so the file always matches the applied configuration.
 * Safe to run standalone.
 */

$out = array();
$xml = @simplexml_load_file('/conf/config.xml');
if ($xml !== false) {
    foreach ($xml->xpath('//xrayclient/nodes/node') as $node) {
        $uuid = (string)$node['uuid'];
        if ($uuid === '') {
            continue;
        }
        $name = trim((string)$node->name);
        if ($name === '') {
            $name = substr($uuid, 0, 8);
        }
        $out['node_' . $uuid] = $name;
    }
}
@file_put_contents('/var/run/xrayclient-outbounds.json', json_encode($out));
