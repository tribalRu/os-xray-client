#!/usr/bin/env python3
"""
Simple unit tests for XrayClient Python scripts.
Run with: python3 test_scripts.py
"""

import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)


class TestLibUtils(unittest.TestCase):

    def test_iter_nodes_empty(self):
        """iter_nodes() should return nothing when config is missing."""
        with patch('_lib.ET.parse') as mock_parse:
            mock_parse.side_effect = Exception('not found')
            from _lib import iter_nodes
            nodes = list(iter_nodes())
            self.assertEqual(nodes, [])

    def test_all_nodes_with_tags(self):
        """all_nodes_with_tags() assigns node_<uuid> to every enabled node."""
        with patch('_lib.iter_nodes') as mock_iter:
            mock_iter.return_value = [
                {'uuid': 'aaa', 'enabled': '1', 'address': 'a.example.com', 'port': '443'},
                {'uuid': 'bbb', 'enabled': '1', 'address': 'b.example.com', 'port': '443'},
                {'uuid': 'ccc', 'enabled': '0', 'address': 'c.example.com', 'port': '443'},
            ]
            from _lib import all_nodes_with_tags
            result = all_nodes_with_tags()
            self.assertEqual(result, {'aaa': 'node_aaa', 'bbb': 'node_bbb'})


class TestWarpConfig(unittest.TestCase):

    def test_defaults_loaded(self):
        """Built-in defaults should load when warp.json is absent."""
        with patch('builtins.open', side_effect=FileNotFoundError()):
            import warp
            self.assertEqual(warp.WARP_API_VERSION, 'v0a884')
            self.assertIn('v0a884', warp.WARP_REGISTRATION_URLS[0])

    def test_user_override(self):
        """warp.json should override built-in defaults."""
        override = {
            'api_version': 'v0a9999',
            'registration_urls': ['https://example.com/reg'],
            'fallback_public_key': 'TEST',
            'fallback_endpoint': 'test.example.com:2408',
        }
        with patch('builtins.open', return_value=MagicMock(
            __enter__=lambda s, *a: _FakeFile(json.dumps(override)),
            __exit__=lambda s, *a: None
        )):
            import importlib
            import warp
            importlib.reload(warp)
            self.assertEqual(warp.WARP_API_VERSION, 'v0a9999')
            self.assertEqual(warp.WARP_FALLBACK_ENDPOINT, 'test.example.com:2408')


class TestHealthcheck(unittest.TestCase):

    def setUp(self):
        import tempfile
        import healthcheck
        self.hc = healthcheck
        self.tmp = tempfile.mkdtemp()
        self.hc.CACHE_FILE = os.path.join(self.tmp, 'latency.json')

    def test_udp_protocols_are_not_probed(self):
        for proto in ('wireguard', 'hysteria', 'masque', 'freedom'):
            _, res = self.hc.check_node(
                {'uuid': 'u', 'address': 'x.example.com', 'port': '443', 'protocol': proto})
            self.assertEqual(res, {'status': 'n/a', 'ms': 0})

    def test_unreachable_tcp_node_is_offline(self):
        _, res = self.hc.check_node(
            {'uuid': 'u', 'address': '127.0.0.1', 'port': '1', 'protocol': 'vless'})
        self.assertEqual(res['status'], 'offline')

    def test_cache_hit_and_invalidation(self):
        nodes = [{'uuid': 'a', 'address': 'h', 'port': '443', 'protocol': 'vless'}]
        key = self.hc._nodes_key(nodes)
        self.hc._write_cache(key, {'a': {'status': 'online', 'ms': 12}})
        self.assertEqual(self.hc._read_cache(key), {'a': {'status': 'online', 'ms': 12}})
        # Different node set -> different key -> cache miss.
        other = self.hc._nodes_key([{'uuid': 'a', 'address': 'h2', 'port': '443', 'protocol': 'vless'}])
        self.assertIsNone(self.hc._read_cache(other))
        # Expired entry -> cache miss.
        with patch('healthcheck.time.time', return_value=1e12):
            self.assertIsNone(self.hc._read_cache(key))


class TestStats(unittest.TestCase):

    def test_tag_mapping_matches_template(self):
        """Every enabled node is node_<uuid>; disabled nodes and other outbounds are ignored."""
        import stats
        nodes = [
            {'uuid': 'aaa', 'enabled': '1', 'address': 'a', 'port': '443', 'protocol': 'vless'},
            {'uuid': 'bbb', 'enabled': '1', 'address': 'b', 'port': '443', 'protocol': 'vless'},
            {'uuid': 'ccc', 'enabled': '0', 'address': 'c', 'port': '443', 'protocol': 'vless'},
        ]
        raw = {'stat': [
            {'name': 'outbound>>>node_aaa>>>traffic>>>downlink', 'value': '100'},
            {'name': 'outbound>>>node_aaa>>>traffic>>>uplink', 'value': '10'},
            {'name': 'outbound>>>node_bbb>>>traffic>>>downlink', 'value': '5'},
            {'name': 'outbound>>>node_ccc>>>traffic>>>downlink', 'value': '77'},
            {'name': 'outbound>>>proxy>>>traffic>>>downlink', 'value': '555'},
            {'name': 'outbound>>>direct>>>traffic>>>downlink', 'value': '999'},
        ]}
        proc = MagicMock(returncode=0, stdout=json.dumps(raw), stderr='')
        out = []
        with patch('stats.os.path.exists', return_value=True), \
                patch('stats.iter_nodes', return_value=nodes), \
                patch('_lib.iter_nodes', return_value=nodes), \
                patch('stats.get_general_value', return_value='10085'), \
                patch('stats.subprocess.run', return_value=proc), \
                patch('builtins.print', side_effect=lambda *a, **k: out.append(a[0])):
            stats.main()
        data = json.loads(out[-1])
        self.assertEqual(data['status'], 'ok')
        self.assertEqual(data['stats']['aaa'], {'uplink': 10, 'downlink': 100})
        self.assertEqual(data['stats']['bbb'], {'uplink': 0, 'downlink': 5})
        self.assertEqual(data['stats']['ccc'], {'uplink': 0, 'downlink': 0})


class TestWarpReserved(unittest.TestCase):

    def test_reserved_from_client_id(self):
        import base64
        import warp
        cid = base64.b64encode(bytes([12, 34, 56])).decode()
        self.assertEqual(warp.reserved_from_client_id(cid), '12,34,56')
        # Unpadded input must work too.
        self.assertEqual(warp.reserved_from_client_id(cid.rstrip('=')), '12,34,56')

    def test_reserved_invalid_client_id(self):
        import warp
        for bad in ('', None, '!!!', 'QQ=='):
            self.assertEqual(warp.reserved_from_client_id(bad), '')

    def test_extract_uses_client_id_not_random(self):
        import base64
        import warp
        reg = {'config': {'client_id': base64.b64encode(bytes([1, 2, 3])).decode(),
                          'peers': [], 'interface': {}}}
        for _ in range(5):
            self.assertEqual(warp.extract_warp_fields(reg, 'priv', 'pub')['wg_reserved'], '1,2,3')


class TestWarpMain(unittest.TestCase):

    def test_registration_failure_is_an_error(self):
        import warp
        out = []
        with patch('warp.generate_wg_keypair', return_value=('priv', 'pub')), \
                patch('warp.warp_register', return_value=None), \
                patch('builtins.print', side_effect=lambda *a, **k: out.append(a[0])):
            warp.main()
        data = json.loads(out[-1])
        self.assertEqual(data['status'], 'error')
        self.assertNotIn('wg_secret_key', data)


JINJA2_AVAILABLE = True
try:
    import jinja2
except ImportError:  # pragma: no cover - dev machines without Jinja2
    JINJA2_AVAILABLE = False

TEMPLATE_PATH = os.path.normpath(os.path.join(
    SCRIPT_DIR, '..', '..', '..', '..', 'service', 'templates',
    'OPNsense', 'XrayClient', 'config.json.j2'))

TEST_NODE = {
    '@uuid': '11111111-2222-3333-4444-555555555555',
    'enabled': '1',
    'name': 'test node',
    'protocol': 'freedom',
    'address': '',
    'port': '0',
}

TEST_RULE = {
    'enabled': '1',
    'domain': 'geosite:ru',
    'ip': '',
    'port': '',
    'protocol': '',
    'network_proto': 'tcp_udp',
    'outbound_tag': 'node_' + TEST_NODE['@uuid'],
}

TEST_BALANCER = {
    'enabled': '1',
    'tag': 'auto',
    'selector': 'node_',
    'strategy': 'leastPing',
    'fallback_tag': 'direct',
}


class _FakeHelpers:
    """Minimal stand-in for the OPNsense `helpers` template object."""

    def __init__(self, data):
        self._data = data

    def _resolve(self, path):
        node = self._data
        for part in path.split('.'):
            if not isinstance(node, dict) or part not in node:
                return None
            node = node[part]
        return node

    def empty(self, path):
        value = self._resolve(path)
        return value is None or value == [] or value == ''

    def toList(self, path, sort_key=None, order=None):
        value = self._resolve(path)
        return list(value) if value else []


def render_config(general_overrides=None, nodes=None, rules=None,
                  balancers=None):
    """Render config.json.j2 with sample data and return the parsed JSON."""
    general = {
        'config_mode': 'ui',
        'enabled': '1',
        'loglevel': 'warning',
        'access_log': '0',
        'enable_tun': '1',
        'tun_iface': 'tun_xray0',
        'tun_address': '10.255.0.1/30',
        'tun_mtu': '1500',
        'enable_sniffing': '1',
        'enable_socks': '1',
        'socks_listen': '127.0.0.1',
        'socks_port': '10808',
        'enable_http': '0',
        'http_port': '10809',
        'stats_port': '10085',
        'dns_json': '',
        'balancers_json': '',
        'observatory_json': '',
        'observatory_type': 'none',
        'observatory_selector': 'node_',
        'observatory_url': 'https://connectivitycheck.gstatic.com/generate_204',
        'observatory_interval': '1m',
        'observatory_sampling': '10',
        'observatory_timeout': '5s',
        'observatory_http_method': '',
        'observatory_concurrency': '0',
    }
    general.update(general_overrides or {})
    data = {'OPNsense': {'XrayClient': {
        'general': general,
        'nodes': {'node': nodes or []},
        'rules': {'rule': rules or []},
        'balancers': {'balancer': balancers or []},
    }}}
    with open(TEMPLATE_PATH, encoding='utf-8') as handle:
        source = handle.read()
    env = jinja2.Environment(extensions=['jinja2.ext.do'], autoescape=False)
    rendered = env.from_string(source).render(
        OPNsense=data['OPNsense'], helpers=_FakeHelpers(data))
    return json.loads(rendered)


@unittest.skipUnless(JINJA2_AVAILABLE, 'jinja2 is needed to render config.json.j2')
class TestConfigTemplate(unittest.TestCase):

    def test_advanced_sections_are_inserted(self):
        cfg = render_config(
            {
                'dns_json': '{"servers": ["https://1.1.1.1/dns-query"]}',
                'balancers_json': ('[{"tag": "auto", "selector": ["node_"], '
                                   '"strategy": {"type": "leastPing"}}]'),
                'observatory_json': '{"burstObservatory": {"subjectSelector": ["node_"]}}',
            },
            nodes=[TEST_NODE],
            rules=[TEST_RULE],
        )
        self.assertEqual(cfg['dns'], {'servers': ['https://1.1.1.1/dns-query']})
        self.assertEqual(cfg['routing']['balancers'][0]['tag'], 'auto')
        self.assertEqual(cfg['burstObservatory'], {'subjectSelector': ['node_']})
        # The rest of the generated config must stay intact.
        self.assertEqual(cfg['outbounds'][0]['tag'], 'node_' + TEST_NODE['@uuid'])
        self.assertEqual(cfg['routing']['rules'][0]['inboundTag'], ['api-in'])
        self.assertEqual(cfg['routing']['rules'][1]['domain'], ['geosite:ru'])
        self.assertEqual(cfg['routing']['rules'][1]['outboundTag'],
                         'node_' + TEST_NODE['@uuid'])

    def test_sections_are_omitted_when_empty(self):
        cfg = render_config()
        for key in ('dns', 'observatory', 'burstObservatory'):
            self.assertNotIn(key, cfg)
        self.assertNotIn('balancers', cfg['routing'])

    def test_empty_json_objects_keep_the_config_valid(self):
        cfg = render_config({'dns_json': '{}', 'observatory_json': '{}'})
        self.assertEqual(cfg['dns'], {})
        self.assertNotIn('observatory', cfg)
        self.assertIn('routing', cfg)

    def test_multiline_sections(self):
        dns = '{\n  "servers": [\n    "1.1.1.1",\n    "8.8.8.8"\n  ]\n}'
        obs = '{\n  "observatory": {\n    "subjectSelector": ["node_"]\n  }\n}'
        cfg = render_config({'dns_json': dns, 'observatory_json': obs})
        self.assertEqual(cfg['dns']['servers'], ['1.1.1.1', '8.8.8.8'])
        self.assertEqual(cfg['observatory'], {'subjectSelector': ['node_']})

    def test_balancer_generated_from_model(self):
        cfg = render_config(balancers=[TEST_BALANCER])
        self.assertEqual(cfg['routing']['balancers'], [{
            'tag': 'auto',
            'selector': ['node_'],
            'strategy': {'type': 'leastPing'},
            'fallbackTag': 'direct',
        }])

    def test_disabled_balancer_is_omitted(self):
        disabled = dict(TEST_BALANCER, enabled='0')
        rule = dict(TEST_RULE, outbound_tag='auto')
        cfg = render_config(balancers=[disabled], rules=[rule])
        self.assertNotIn('balancers', cfg['routing'])
        # Without an enabled balancer the tag cannot become balancerTag.
        self.assertEqual(cfg['routing']['rules'][1]['outboundTag'], 'auto')
        self.assertNotIn('balancerTag', cfg['routing']['rules'][1])

    def test_rule_can_target_a_balancer(self):
        rule = dict(TEST_RULE, outbound_tag='auto')
        cfg = render_config(balancers=[TEST_BALANCER], rules=[rule])
        self.assertEqual(cfg['routing']['rules'][1]['balancerTag'], 'auto')
        self.assertNotIn('outboundTag', cfg['routing']['rules'][1])

    def test_rule_on_node_keeps_outbound_tag(self):
        cfg = render_config(balancers=[TEST_BALANCER], rules=[TEST_RULE])
        self.assertEqual(cfg['routing']['rules'][1]['outboundTag'],
                         'node_' + TEST_NODE['@uuid'])
        self.assertNotIn('balancerTag', cfg['routing']['rules'][1])

    def test_form_balancers_win_over_raw_json(self):
        raw = ('[{"tag": "raw", "selector": ["node_"], '
               '"strategy": {"type": "random"}}]')
        cfg = render_config({'balancers_json': raw}, balancers=[TEST_BALANCER])
        self.assertEqual([b['tag'] for b in cfg['routing']['balancers']],
                         ['auto'])

    def test_raw_balancers_are_used_without_table_rows(self):
        raw = ('[{"tag": "raw", "selector": ["node_"], '
               '"strategy": {"type": "random"}}]')
        cfg = render_config({'balancers_json': raw})
        self.assertEqual(cfg['routing']['balancers'][0]['tag'], 'raw')

    def test_burst_observatory_generated(self):
        cfg = render_config({
            'observatory_type': 'burst',
            'observatory_selector': 'node_, exit_',
            'observatory_url': 'https://example.com/generate_204',
            'observatory_interval': '30s',
            'observatory_sampling': '5',
            'observatory_timeout': '2s',
            'observatory_http_method': 'GET',
        })
        self.assertEqual(cfg['burstObservatory'], {
            'subjectSelector': ['node_', 'exit_'],
            'pingConfig': {
                'destination': 'https://example.com/generate_204',
                'interval': '30s',
                'sampling': 5,
                'timeout': '2s',
                'httpMethod': 'GET',
            },
        })
        self.assertNotIn('observatory', cfg)

    def test_empty_observatory_selector_falls_back_to_node_prefix(self):
        cfg = render_config({'observatory_type': 'burst',
                             'observatory_selector': ''})
        self.assertEqual(cfg['burstObservatory']['subjectSelector'],
                         ['node_'])

    def test_background_observatory_generated(self):
        cfg = render_config({
            'observatory_type': 'background',
            'observatory_url': 'https://example.com/generate_204',
            'observatory_interval': '10s',
            'observatory_concurrency': '1',
        })
        self.assertEqual(cfg['observatory'], {
            'subjectSelector': ['node_'],
            'probeURL': 'https://example.com/generate_204',
            'probeInterval': '10s',
            'enableConcurrency': True,
        })

    def test_form_observatory_wins_over_raw_json(self):
        raw = '{"burstObservatory": {"subjectSelector": ["raw_"]}}'
        cfg = render_config({'observatory_type': 'burst',
                             'observatory_json': raw})
        self.assertEqual(cfg['burstObservatory']['subjectSelector'], ['node_'])

    def test_observatory_none_keeps_raw_json(self):
        raw = '{"burstObservatory": {"subjectSelector": ["raw_"]}}'
        cfg = render_config({'observatory_json': raw})
        self.assertEqual(cfg['burstObservatory'], {'subjectSelector': ['raw_']})


class _FakeFile:
    def __init__(self, content):
        self.content = content

    def read(self):
        return self.content

    def close(self):
        pass


if __name__ == '__main__':
    unittest.main()
