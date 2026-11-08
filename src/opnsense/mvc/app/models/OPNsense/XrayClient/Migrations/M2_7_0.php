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
 * http_listen defaults to socks_listen.
 *
 * Until 2.7.0 the local HTTP proxy inbound shared its listen address with
 * the SOCKS inbound (the general socks_listen value). 2.7.0 splits them:
 * the HTTP proxy now has its own http_listen field, and an existing
 * deployment must keep serving on the same address. Copy the stored
 * socks_listen into an empty http_listen so nothing changes for users who
 * never set it.
 */
class M2_7_0 extends BaseModelMigration
{
    public function run($model)
    {
        if (!$model instanceof XrayClient) {
            return;
        }

        $config = Config::getInstance()->object();

        if (!isset($config->OPNsense->XrayClient->general)) {
            return;
        }

        $general = $config->OPNsense->XrayClient->general;
        $http = isset($general->http_listen) ? trim((string)$general->http_listen) : '';
        $socks = isset($general->socks_listen) ? trim((string)$general->socks_listen) : '127.0.0.1';

        if ($http === '') {
            $general->http_listen = $socks;
        }
    }

    // Model is saved by 'run_migrations.php' afterwards.
}
