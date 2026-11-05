<?php

namespace OPNsense\XrayClient\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'xrayclient';
    protected static $internalModelClass = 'OPNsense\XrayClient\XrayClient';

    public function searchNodeAction()
    {
        return $this->searchBase('nodes.node', ['enabled', 'name', 'protocol', 'address', 'port', 'security', 'network']);
    }

    public function getNodeAction($uuid = null)
    {
        if ($uuid != null) {
            return $this->getBase('node', 'nodes.node', $uuid);
        }
        return ['node' => []];
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
        if ($uuid != null) {
            return $this->getBase('rule', 'rules.rule', $uuid);
        }
        return ['rule' => []];
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

        foreach ($defaults as $ruleData) {
            $node = $mdl->rules->rule->Add();
            $node->setNodes($ruleData);
        }

        $mdl->serializeToConfig();
        Config::getInstance()->save();

        return ['status' => 'ok', 'message' => 'Default routing rules added'];
    }
}