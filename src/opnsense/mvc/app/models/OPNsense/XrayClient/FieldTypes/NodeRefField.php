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

namespace OPNsense\XrayClient\FieldTypes;

use OPNsense\Base\FieldTypes\OptionField;
use OPNsense\Core\Config;

/**
 * Picks one enabled outbound node by its UUID; used for the hops of a chain.
 * The options come from the live configuration, like OutboundTagField.
 */
class NodeRefField extends OptionField
{
    public function setOptionValues($data)
    {
        $this->internalOptionList = $this->buildOptionList();
    }

    protected function actionPostLoadingEvent()
    {
        $this->internalOptionList = $this->buildOptionList();
        parent::actionPostLoadingEvent();
    }

    private function buildOptionList(): array
    {
        $list = [];
        try {
            $doc = Config::getInstance()->object();
            $nodes = $doc ? $doc->xpath('//OPNsense/XrayClient/nodes/node[enabled="1"]') : [];
        } catch (\Throwable $e) {
            $nodes = [];
        }
        foreach ($nodes as $node) {
            $uuid = (string)$node['uuid'];
            $name = trim((string)$node->name);
            $proto = trim((string)$node->protocol);
            $list[$uuid] = ($name !== '' ? $name : $uuid) . ' (' . ($proto !== '' ? $proto : 'node') . ')';
        }
        return $list;
    }

    protected function defaultValidationMessage()
    {
        return gettext('Select an enabled outbound node.');
    }
}
