<?php

/*
 *    Copyright (C) 2026 os-xray-client contributors
 *
 *    Redistribution and use in source and binary forms, with or without
 *    modification, are permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *    THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 *    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 *    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *    POSSIBILITY OF SUCH DAMAGES.
 */

namespace OPNsense\XrayClient\Migrations;

use OPNsense\Base\BaseModelMigration;
use OPNsense\Core\Config;
use OPNsense\XrayClient\XrayClient;

/**
 * Rename the outbound node credential field <uuid> to <user_uuid>.
 *
 * The unprefixed <uuid> element used to hold the Xray VLESS user id /
 * trojan password / shadowsocks password, but OPNsense ArrayFields store
 * their internal row identifier in a "uuid" attribute/key as well, which
 * shadowed the user field in API responses and emptied the node editor.
 * The internal row identifier is left untouched.
 */
class M1_0_2 extends BaseModelMigration
{
    public function run($model)
    {
        if (!$model instanceof XrayClient) {
            return;
        }

        $config = Config::getInstance()->object();
        if (!isset($config->OPNsense->XrayClient->nodes->node)) {
            return;
        }
        $nodes = $config->OPNsense->XrayClient->nodes->node;

        foreach ($nodes as $node) {
            $old = isset($node->uuid) ? (string)$node->uuid : null;
            $new = isset($node->user_uuid) ? (string)$node->user_uuid : null;

            if ($new !== null && $new !== '') {
                // user_uuid already populated: drop the legacy field if any.
                if (isset($node->uuid)) {
                    unset($node->uuid);
                }
                continue;
            }
            if ($old === null) {
                continue;
            }

            $node->addChild('user_uuid', $old);
            unset($node->uuid);
        }
    }

    // Model is saved by 'run_migrations.php'
}
