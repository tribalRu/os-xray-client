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

    // --- DNS Servers CRUD ---
    public function searchDnsServerAction()
    {
        return $this->searchBase(
            'dns.server',
            ['enabled', 'address', 'port', 'domains', 'expected_ips', 'unexpected_ips', 'skip_fallback']
        );
    }

    public function getDnsServerAction($uuid = null)
    {
        return $this->getBase('server', 'dns.server', $uuid);
    }

    public function addDnsServerAction()
    {
        return $this->addBase('server', 'dns.server');
    }

    public function setDnsServerAction($uuid)
    {
        return $this->setBase('server', 'dns.server', $uuid);
    }

    public function delDnsServerAction($uuid)
    {
        return $this->delBase('dns.server', $uuid);
    }

    public function toggleDnsServerAction($uuid, $enabled = null)
    {
        return $this->toggleBase('dns.server', $uuid, $enabled);
    }

    // --- Load Balancers CRUD ---
    public function searchBalancerAction()
    {
        return $this->searchBase(
            'balancers.balancer',
            ['enabled', 'tag', 'selector', 'strategy', 'fallback_tag']
        );
    }

    public function getBalancerAction($uuid = null)
    {
        return $this->getBase('balancer', 'balancers.balancer', $uuid);
    }

    public function addBalancerAction()
    {
        return $this->addBase('balancer', 'balancers.balancer');
    }

    public function setBalancerAction($uuid)
    {
        return $this->setBase('balancer', 'balancers.balancer', $uuid);
    }

    public function delBalancerAction($uuid)
    {
        return $this->delBase('balancers.balancer', $uuid);
    }

    public function toggleBalancerAction($uuid, $enabled = null)
    {
        return $this->toggleBase('balancers.balancer', $uuid, $enabled);
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

    // --- Routing Rules: reorder (move one position up/down) ---
    public function moveRuleAction($uuid = null, $direction = null)
    {
        if (!$this->request->isPost()) {
            return ['status' => 'error', 'message' => 'POST required'];
        }
        if (!in_array($direction, ['up', 'down'], true)) {
            return ['status' => 'error', 'message' => 'Invalid direction (expected up|down)'];
        }

        $mdl = $this->getModel();
        $rules = [];
        foreach ($mdl->rules->rule->iterateItems() as $key => $rule) {
            $rules[$key] = [$rule, (int)((string)$rule->sequence)];
        }
        if (!isset($rules[$uuid])) {
            return ['status' => 'error', 'message' => 'Rule not found'];
        }

        // Sort by sequence (stable: PHP sorts are stable, ties keep config order).
        uasort($rules, function ($a, $b) {
            return $a[1] <=> $b[1];
        });
        $order = array_keys($rules);
        $idx = array_search($uuid, $order, true);
        $swapWith = ($direction === 'up') ? $idx - 1 : $idx + 1;
        if ($swapWith < 0 || $swapWith >= count($order)) {
            return ['status' => 'ok', 'message' => 'Already at the edge'];
        }
        [$order[$idx], $order[$swapWith]] = [$order[$swapWith], $order[$idx]];

        // Renumber everything sequentially so repeated moves keep the order stable.
        $sequence = 10;
        foreach ($order as $key) {
            $rules[$key][0]->sequence = $sequence;
            $sequence += 10;
        }

        try {
            $mdl->serializeToConfig();
            Config::getInstance()->save();
        } catch (\Throwable $e) {
            return [
                'status' => 'error',
                'message' => 'Validation failed: ' . preg_replace('/\s+/', ' ', $e->getMessage())
            ];
        }

        return ['status' => 'ok', 'message' => 'Rule order updated'];
    }
}
