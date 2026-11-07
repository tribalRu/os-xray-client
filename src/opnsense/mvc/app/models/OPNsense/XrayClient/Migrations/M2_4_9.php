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
 *    AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 *    ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 *    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *    SOFTWARE.
 */

namespace OPNsense\XrayClient\Migrations;

use OPNsense\Base\BaseModelMigration;
use OPNsense\Core\Config;
use OPNsense\XrayClient\XrayClient;

/**
 * Drop the "proxy" outbound alias.
 *
 * Historically the first enabled node was emitted in config.json with the
 * "proxy" tag and the rest as "node_<uuid>". 2.4.9 simplifies tagging to a
 * single scheme: every enabled node is emitted as "node_<uuid>", so stored
 * rules pointing at "proxy" would silently stop matching and fail model
 * validation on the next save.
 *
 * Safety net: rewrite any stored rule with outbound_tag = "proxy" to
 * node_<uuid-of-first-enabled-node>, or "direct" when no node is enabled.
 */
class M2_4_9 extends BaseModelMigration
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

        // Find the first ENABLED node (order of appearance in config.xml),
        // mirroring what the template sees.
        $firstEnabled = null;
        foreach ($config->OPNsense->XrayClient->nodes->node as $node) {
            if ((string)($node->enabled ?? '0') === '1') {
                $firstEnabled = (string)$node['uuid'];
                break;
            }
        }

        $target = ($firstEnabled !== null && $firstEnabled !== '')
            ? 'node_' . $firstEnabled
            : 'direct';

        if (isset($config->OPNsense->XrayClient->rules->rule)) {
            foreach ($config->OPNsense->XrayClient->rules->rule as $rule) {
                $tag = isset($rule->outbound_tag) ? (string)$rule->outbound_tag : '';
                if ($tag === 'proxy') {
                    $rule->outbound_tag = $target;
                }
            }
        }
    }

    // Model is saved by 'run_migrations.php' afterwards.
}
