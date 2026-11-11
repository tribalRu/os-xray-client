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

namespace OPNsense\XrayClient\Migrations;

use OPNsense\Base\BaseModelMigration;
use OPNsense\XrayClient\XrayClient;

/**
 * OPNsense only recognises TUN interfaces whose name starts with "tun_".
 * Configurations saved before the model enforced that keep a name such as
 * "xray0" or "tun0", which would fail validation on the next save, so give
 * them the prefix (truncated to the 15 characters an interface name allows).
 */
class M2_17_31 extends BaseModelMigration
{
    /**
     * @param string $name configured TUN interface name
     * @return string the name with the required prefix, or $name when it is
     *                empty or already valid
     */
    public static function prefixed($name)
    {
        $name = trim((string)$name);
        if ($name === '') {
            return $name;
        }
        if (strpos($name, 'tun_') === 0 && strlen($name) >= 5) {
            return $name;
        }
        $clean = preg_replace('/[^a-zA-Z0-9_]/', '_', $name);
        return substr('tun_' . $clean, 0, 15);
    }

    public function run($model)
    {
        if (!$model instanceof XrayClient) {
            return;
        }

        $iface = $model->getNodeByReference('general.tun_iface');
        if ($iface !== null) {
            $current = (string)$iface->getValue();
            $fixed = self::prefixed($current);
            if ($fixed !== $current) {
                $iface->setValue($fixed);
            }
        }

        parent::run($model);
    }
}
