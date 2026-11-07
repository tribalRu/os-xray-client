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


class _FakeFile:
    def __init__(self, content):
        self.content = content

    def read(self):
        return self.content

    def close(self):
        pass


if __name__ == '__main__':
    unittest.main()
