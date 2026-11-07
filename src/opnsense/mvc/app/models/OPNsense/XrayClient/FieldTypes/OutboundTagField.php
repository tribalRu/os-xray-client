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
 * Outbound tag selector for routing rules.
 *
 * Every enabled node is offered as "node_<uuid>" — a tag that never
 * changes across add/remove/reorder, so a saved routing rule always
 * points at the same node. "direct" and "block" are the core's
 * built-in outbounds (optgroup "Standard"). No aliases are emitted:
 * one node, one tag.
 */
class OutboundTagField extends OptionField
{
    /**
     * Options are built from the live configuration in
     * actionPostLoadingEvent(); the XML carries no static list.
     */
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
        // "direct" and "block" are the outbounds the Xray core provides.
        $list = [
            'direct' => [
                'value' => gettext('direct — direct outbound, freedom (core)'),
                'optgroup' => gettext('Standard (core, built-in)'),
            ],
            'block' => [
                'value' => gettext('block — block all traffic, blackhole (core)'),
                'optgroup' => gettext('Standard (core, built-in)'),
            ],
        ];

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
            $label = ($name !== '' ? $name : $uuid) . ' (' . ($proto !== '' ? $proto : 'node') . ')';
            // One stable tag per node (mirrors config.json.j2).
            $list['node_' . $uuid] = [
                'value' => gettext($label),
                'optgroup' => gettext('Custom (from outbound nodes)'),
            ];
        }
        return $list;
    }

    /**
     * Validation message for unknown tags (e.g. rule saved before the node
     * that owned the tag was deleted).
     */
    protected function defaultValidationMessage()
    {
        return gettext('Select an existing outbound: direct, block or tag of an enabled node.');
    }
}
