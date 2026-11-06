<?php

namespace OPNsense\XrayClient\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'xrayclient';
    protected static $internalModelClass = 'OPNsense\XrayClient\XrayClient';

    // --- Outbound Nodes CRUD ---
    public function searchNodeAction()
    {
        return $this->searchBase('nodes.node', ['enabled', 'name', 'protocol', 'address', 'port', 'security', 'network']);
    }

    public function getNodeAction($uuid = null)
    {
        return $this->getBase('node', 'nodes.node', $uuid);
    }

    public function addNodeAction()
    {
        return $this->addBase('node', 'nodes.node');
    }

    public function setNodeAction($uuid)
    {
        return $this->setBase('node', 'nodes.node', $uuid);
    }

    public function delNodeAction($uuid)
    {
        return $this->delBase('nodes.node', $uuid);
    }

    public function toggleNodeAction($uuid, $enabled = null)
    {
        return $this->toggleBase('nodes.node', $uuid, $enabled);
    }

    // --- Routing Rules CRUD ---
    public function searchRuleAction()
    {
        return $this->searchBase(
            'rules.rule',
            ['enabled', 'sequence', 'description', 'domain', 'ip', 'port', 'outbound_tag'],
            'sequence'
        );
    }

    public function getRuleAction($uuid = null)
    {
        return $this->getBase('rule', 'rules.rule', $uuid);
    }

    public function addRuleAction()
    {
        return $this->addBase('rule', 'rules.rule');
    }

    public function setRuleAction($uuid)
    {
        return $this->setBase('rule', 'rules.rule', $uuid);
    }

    public function delRuleAction($uuid)
    {
        return $this->delBase('rules.rule', $uuid);
    }

    public function toggleRuleAction($uuid, $enabled = null)
    {
        return $this->toggleBase('rules.rule', $uuid, $enabled);
    }

    // --- Seed Default RU Bypass Rules ---
    public function seedDefaultRulesAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error', 'message' => 'POST required'];
        }

        $mdl = $this->getModel();
        $defaults = [
            [
                'enabled' => '1',
                'sequence' => '10',
                'description' => 'Bypass Local & Private Subnets (LAN)',
                'domain' => '',
                'ip' => 'geoip:private',
                'port' => '',
                'network_proto' => 'tcp_udp',
                'protocol' => '',
                'outbound_tag' => 'direct'
            ],
            [
                'enabled' => '1',
                'sequence' => '20',
                'description' => 'Bypass Russian Domains (.ru, .рф, geosite:ru)',
                'domain' => 'geosite:ru,domain:ru,domain:xn--p1ai',
                'ip' => '',
                'port' => '',
                'network_proto' => 'tcp_udp',
                'protocol' => '',
                'outbound_tag' => 'direct'
            ],
            [
                'enabled' => '1',
                'sequence' => '30',
                'description' => 'Bypass Russian IP Ranges (geoip:ru)',
                'domain' => '',
                'ip' => 'geoip:ru',
                'port' => '',
                'network_proto' => 'tcp_udp',
                'protocol' => '',
                'outbound_tag' => 'direct'
            ],
            [
                'enabled' => '1',
                'sequence' => '90',
                'description' => 'Block Ads (geosite:category-ads-all)',
                'domain' => 'geosite:category-ads-all',
                'ip' => '',
                'port' => '',
                'network_proto' => 'tcp_udp',
                'protocol' => '',
                'outbound_tag' => 'block'
            ]
        ];

        // Collect existing descriptions to avoid duplicates on repeated clicks.
        $existing = [];
        foreach ($mdl->rules->rule->iterateItems() as $rule) {
            $desc = (string)$rule->description;
            if ($desc !== '') {
                $existing[$desc] = true;
            }
        }

        $added = 0;
        $skipped = 0;
        foreach ($defaults as $ruleData) {
            if (isset($existing[$ruleData['description']])) {
                $skipped++;
                continue;
            }
            $node = $mdl->rules->rule->add();
            if ($node === null) {
                return ['status' => 'error', 'message' => 'Failed to create routing rule'];
            }
            $node->setNodes($ruleData);
            $added++;
        }

        if ($added === 0) {
            return ['status' => 'ok', 'message' => 'Default routing rules already exist'];
        }

        try {
            $mdl->serializeToConfig();
        } catch (\OPNsense\Base\ValidationException $e) {
            return [
                'status' => 'error',
                'message' => 'Validation failed: ' . preg_replace('/\s+/', ' ', trim($e->getMessage()))
            ];
        }
        Config::getInstance()->save();

        return ['status' => 'ok', 'message' => "Default routing rules added ({$added} new, {$skipped} skipped)"];
    }
}
