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
use OPNsense\XrayClient\XrayClient;

/**
 * Re-run the http_listen migration for existing 2.7.0-2.7.4 deployments.
 *
 * M2_7_0 set the model directly in code, but runMigrations() only runs a
 * migration class when the configuration model version predates the model
 * version, so it fired exactly once (on the 2.6.1 -> 2.7.0 upgrade) and
 * never again. This migration re-applies the same copy one upgrade later.
 */
class M2_7_5 extends BaseModelMigration
{
    public function run($model)
    {
        if (!$model instanceof XrayClient) {
            return;
        }

        $http = $model->getNodeByReference('general.http_listen');
        $socks = $model->getNodeByReference('general.socks_listen');

        if ($http === null or $socks === null) {
            parent::run($model);
            return;
        }

        if (trim((string)$http->getValue()) === '') {
            $target = trim((string)$socks->getValue());
            $http->setValue($target === '' ? '127.0.0.1' : $target);
        }

        parent::run($model);
    }
}
