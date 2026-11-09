#!/usr/local/bin/php
<?php

/*
 * Writes /var/run/xrayclient-outbounds.json:
 *     {"node_<uuid>": "<node name>", ...}
 *
 * Consumed by the unified OPNsense log viewer through the plugin's xraylog
 * format handler, which rewrites raw outbound tags to human-readable node
 * names in the Process column. Reads /conf/config.xml directly (only tagged
 * outbound nodes are of interest). The path match is case-insensitive: the
 * OPNsense config.xml root element case is not guaranteed (mounts in models
 * read e.g. //OPNsense/unboundplus), so a fixed-case xpath yields nothing.
 *
 * Called by install.sh and ServiceController::reconfigureAction() (after any
 * Apply), so the file always matches the applied configuration.
 * Safe to run standalone.
 */

$root = '/conf/config.xml';
$out = array();

$xml = @simplexml_load_file($root);
if ($xml !== false) {
    $needle = '/translate(local-name(), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")';
    $path = '//*[' . $needle . '="xrayclient"]/*[' . $needle . '="nodes"]/*[' . $needle . '="node"]';
    foreach ($xml->xpath($path) as $node) {
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
