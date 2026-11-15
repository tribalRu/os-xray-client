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
        // wg_endpoint and alpn are not columns: the grid shows the WireGuard
        // endpoint instead of the (unused) address, and tells HTTP/2 from
        // HTTP/3 for MASQUE.
        return $this->searchBase('nodes.node', [
            'enabled', 'name', 'protocol', 'address', 'port', 'security', 'network', 'wg_endpoint', 'alpn'
        ]);
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
        $result = $this->searchBase(
            'rules.rule',
            [
                'enabled', 'pinned', 'pin_end', 'sequence', 'description', 'domain', 'ip', 'port', 'network_proto', 'protocol',
                'inbound_tag', 'source', 'source_port', 'user', 'rule_tag', 'outbound_tag'
            ],
            'sequence'
        );
        // Pinned-to-top rules are evaluated first, pinned-to-end last: list them so (stable, so the
        // sequence order is kept inside each group).
        if (isset($result['rows']) && is_array($result['rows'])) {
            $groups = [0 => [], 1 => [], 2 => []];
            foreach ($result['rows'] as $row) {
                if ((string)($row['pinned'] ?? '0') === '1') {
                    $groups[0][] = $row;
                } elseif ((string)($row['pin_end'] ?? '0') === '1') {
                    $groups[2][] = $row;
                } else {
                    $groups[1][] = $row;
                }
            }
            $result['rows'] = array_merge($groups[0], $groups[1], $groups[2]);
        }
        return $result;
    }

    public function getRuleAction($uuid = null)
    {
        $result = $this->getBase('rule', 'rules.rule', $uuid);
        if (empty($uuid) && isset($result['rule'])) {
            // A new rule goes to the end of the list instead of colliding with
            // the default sequence of an existing one.
            $max = 0;
            foreach ($this->getModel()->rules->rule->iterateItems() as $rule) {
                $max = max($max, (int)((string)$rule->sequence));
            }
            $result['rule']['sequence'] = (string)min(9999, $max + 10);
        }
        return $result;
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
            $rules[$key] = [$rule, (int)((string)$rule->sequence), (string)$rule->pinned === '1' ? 0 : ((string)$rule->pin_end === '1' ? 2 : 1)];
        }
        if (!isset($rules[$uuid])) {
            return ['status' => 'error', 'message' => 'Rule not found'];
        }

        // Effective order: pinned-to-top, regular, pinned-to-end; then by sequence (stable: PHP
        // sorts are stable, ties keep config order).
        uasort($rules, function ($a, $b) {
            return [$a[2], $a[1]] <=> [$b[2], $b[1]];
        });
        $order = array_keys($rules);
        $idx = array_search($uuid, $order, true);
        $swapWith = ($direction === 'up') ? $idx - 1 : $idx + 1;
        if ($swapWith < 0 || $swapWith >= count($order)) {
            return ['status' => 'ok', 'message' => 'Already at the edge'];
        }
        if ($rules[$order[$swapWith]][2] !== $rules[$uuid][2]) {
            // Pinned and regular rules form separate groups.
            return ['status' => 'ok', 'message' => 'Already at the edge of the group'];
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
