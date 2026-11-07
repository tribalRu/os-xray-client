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


class _FakeFile:
    def __init__(self, content):
        self.content = content

    def read(self):
        return self.content

    def close(self):
        pass


if __name__ == '__main__':
    unittest.main()
