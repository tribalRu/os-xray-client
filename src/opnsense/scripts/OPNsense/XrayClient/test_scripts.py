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

    def test_masque_over_http2_is_probed_over_tcp(self):
        _, res = self.hc.check_node(
            {'uuid': 'u', 'address': '127.0.0.1', 'port': '1', 'protocol': 'masque', 'alpn': 'h2,h3'})
        self.assertEqual(res['status'], 'offline')
        _, res = self.hc.check_node(
            {'uuid': 'u', 'address': '127.0.0.1', 'port': '1', 'protocol': 'masque', 'alpn': 'h3'})
        self.assertEqual(res['status'], 'n/a')

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
    SCRIPT_DIR, '..', '..', '..', 'service', 'templates',
    'OPNsense', 'XrayClient', 'config.json.j2'))

TEST_NODE = {
    '@uuid': '11111111-2222-3333-4444-555555555555',
    'enabled': '1',
    'name': 'test node',
    'protocol': 'freedom',
    'address': '',
    'port': '0',
}

# A VLESS outbound matching everything Xray requires for XDRIVE: TLS, an
# encrypted VLESS user, no flow, and Mux.Cool enabled with concurrency >= 0.
XDRIVE_NODE = dict(TEST_NODE, **{
    '@uuid': 'dddddddd-0000-0000-0000-000000000001',
    'name': 'xdrive node',
    'protocol': 'vless',
    'address': '142.250.1.1',
    'port': '443',
    'user_uuid': '11111111-2222-3333-4444-555555555555',
    'flow': 'none',
    'encryption': 'mlkem768x25519plus.native.0rtt.clientkey',
    'security': 'tls',
    'sni': 'www.google.com',
    'fingerprint': 'hellochrome_155',
    'network': 'xdrive',
    'mux_enabled': '1',
    'mux_concurrency': '128',
    'xdrive_service': 'google-drive',
    'xdrive_remote_folder': 'folder-id',
    'xdrive_google_client_id': 'client-id',
    'xdrive_google_client_secret': 'client-secret',
    'xdrive_google_refresh_token': 'refresh-token',
})

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

TEST_DNS_SERVER = {
    'enabled': '1',
    'address': 'https://1.1.1.1/dns-query',
    'port': '',
    'domains': '',
    'expected_ips': '',
    'unexpected_ips': '',
    'skip_fallback': '0',
}

TEST_DNS_RU = {
    'enabled': '1',
    'address': 'https://dns.yandex.ru/dns-query',
    'port': '443',
    'domains': 'geosite:ru, domain:ya.ru',
    'expected_ips': 'geoip:ru',
    'unexpected_ips': '',
    'skip_fallback': '1',
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
        value = list(self._resolve(path) or [])
        if sort_key:
            # Like the real helper: sort by the given field (stable).
            conv = int if order == 'int' else str
            value.sort(key=lambda item: conv(item.get(sort_key, 0)))
        return value


def render_config(general_overrides=None, nodes=None, rules=None,
                  balancers=None, dns_servers=None, chains=None):
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
        'tun_ipv6_address': '',
        'tun_auto_outbounds_interface': '',
        'enable_sniffing': '1',
        'sniffing_dest_override': 'http,tls,quic',
        'sniffing_route_only': '1',
        'sniffing_domains_excluded': '',
        'enable_socks': '1',
        'socks_listen': '127.0.0.1',
        'socks_port': '10808',
        'socks_auth': 'noauth',
        'socks_username': '',
        'socks_password': '',
        'enable_http': '0',
        'http_port': '10809',
        'http_listen': '',
        'http_auth': 'noauth',
        'http_username': '',
        'http_password': '',
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
        'dns_enabled': '0',
        'dns_query_strategy': 'useIp',
        'dns_disable_cache': '0',
        'dns_disable_fallback': '0',
        'dns_disable_fallback_if_match': '0',
        'dns_enable_parallel_query': '0',
        'dns_use_system_hosts': '0',
        'dns_hosts_json': '',
        'routing_domain_strategy': 'IPIfNonMatch',
    }
    general.update(general_overrides or {})
    data = {'OPNsense': {'XrayClient': {
        'general': general,
        'nodes': {'node': nodes or []},
        'rules': {'rule': rules or []},
        'balancers': {'balancer': balancers or []},
        'chains': {'chain': chains or []},
        'dns': {'server': dns_servers or []},
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

    def test_tun_ipv6_gateway_is_emitted(self):
        cfg = render_config({'tun_ipv6_address': 'fd00::1/64'})
        tun = [i for i in cfg['inbounds'] if i['tag'] == 'tun-in'][0]
        self.assertEqual(tun['settings']['gateway'],
                         ['10.255.0.1/30', 'fd00::1/64'])

    def test_tun_auto_outbounds_interface(self):
        cfg = render_config({'tun_auto_outbounds_interface': 'auto'})
        tun = [i for i in cfg['inbounds'] if i['tag'] == 'tun-in'][0]
        self.assertEqual(tun['settings']['autoOutboundsInterface'], 'auto')
        cfg = render_config({'tun_auto_outbounds_interface': 'vmx1'})
        tun = [i for i in cfg['inbounds'] if i['tag'] == 'tun-in'][0]
        self.assertEqual(tun['settings']['autoOutboundsInterface'], 'vmx1')
        # Default: not emitted (xray binds via the default FIB).
        cfg = render_config()
        tun = [i for i in cfg['inbounds'] if i['tag'] == 'tun-in'][0]
        self.assertNotIn('autoOutboundsInterface', tun['settings'])

    def test_socks_defaults_sniffing(self):
        cfg = render_config()
        socks = [i for i in cfg['inbounds'] if i['tag'] == 'socks-in'][0]
        self.assertEqual(socks['settings']['auth'], 'noauth')
        self.assertNotIn('users', socks['settings'])
        self.assertEqual(socks['sniffing']['destOverride'], ['http', 'tls', 'quic'])
        self.assertEqual(socks['sniffing']['routeOnly'], True)

    def test_socks_password_auth(self):
        cfg = render_config({'socks_auth': 'password',
                             'socks_username': 'alice',
                             'socks_password': 'hunter2'})
        socks = [i for i in cfg['inbounds'] if i['tag'] == 'socks-in'][0]
        self.assertEqual(socks['settings']['auth'], 'password')
        self.assertEqual(socks['settings']['users'],
                         [{'user': 'alice', 'pass': 'hunter2'}])

    def test_http_inbound_disabled_by_default(self):
        cfg = render_config()
        tags = [i['tag'] for i in cfg['inbounds']]
        self.assertNotIn('http-in', tags)

    def test_http_inbound_listen_and_no_auth(self):
        cfg = render_config({'enable_http': '1'})
        http = [i for i in cfg['inbounds'] if i['tag'] == 'http-in'][0]
        self.assertEqual(http['listen'], '127.0.0.1')
        self.assertNotIn('users', http['settings'])

    def test_http_inbound_own_listen_and_auth(self):
        cfg = render_config({'enable_http': '1',
                             'http_listen': '192.168.1.199',
                             'http_auth': 'password',
                             'http_username': 'bob',
                             'http_password': 's3cret!'})
        http = [i for i in cfg['inbounds'] if i['tag'] == 'http-in'][0]
        self.assertEqual(http['listen'], '192.168.1.199')
        self.assertEqual(http['settings']['users'],
                         [{'user': 'bob', 'pass': 's3cret!'}])

    def test_http_listen_falls_back_to_socks_listen(self):
        cfg = render_config({'enable_http': '1',
                             'http_listen': '',
                             'socks_listen': '10.0.0.1'})
        http = [i for i in cfg['inbounds'] if i['tag'] == 'http-in'][0]
        self.assertEqual(http['listen'], '10.0.0.1')

    def test_sniffing_dest_override_and_exclusions(self):
        cfg = render_config({'sniffing_dest_override': 'http,tls',
                             'sniffing_domains_excluded':
                                 'geosite:category-ads-all, domain:my.local',
                             'sniffing_route_only': '0'})
        for inbound in cfg['inbounds']:
            if inbound['tag'] in ('tun-in', 'socks-in'):
                self.assertEqual(inbound['sniffing']['destOverride'], ['http', 'tls'])
                self.assertEqual(inbound['sniffing']['routeOnly'], False)
                self.assertEqual(inbound['sniffing']['domainsExcluded'],
                                 ['geosite:category-ads-all', 'domain:my.local'])

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

    def test_dns_disabled_keeps_raw_json(self):
        raw = '{"servers": ["https://9.9.9.9/dns-query"]}'
        cfg = render_config({'dns_json': raw}, dns_servers=[TEST_DNS_SERVER])
        self.assertEqual(cfg['dns'], {'servers': ['https://9.9.9.9/dns-query']})

    def test_dns_generated_from_model(self):
        cfg = render_config({'dns_enabled': '1'}, dns_servers=[TEST_DNS_SERVER])
        self.assertEqual(cfg['dns']['servers'], [{
            'address': 'https://1.1.1.1/dns-query',
            'skipFallback': False,
        }])
        self.assertEqual(cfg['dns']['hosts'], {})
        self.assertEqual(cfg['dns']['queryStrategy'], 'useIp')

    def test_dns_tag_emitted_when_set(self):
        cfg = render_config({'dns_enabled': '1', 'dns_tag': ' speede-dns '},
                            dns_servers=[TEST_DNS_SERVER])
        self.assertEqual(cfg['dns']['tag'], 'speede-dns')
        self.assertEqual(cfg['dns']['servers'][0]['address'],
                         'https://1.1.1.1/dns-query')

    def test_dns_tag_omitted_when_empty(self):
        cfg = render_config({'dns_enabled': '1', 'dns_tag': ''},
                            dns_servers=[TEST_DNS_SERVER])
        self.assertNotIn('tag', cfg['dns'])

    def test_dns_tag_with_hosts_only(self):
        cfg = render_config({'dns_enabled': '1', 'dns_tag': 'dns-out',
                             'dns_hosts_json': '{"a.example": "192.0.2.1"}'})
        self.assertEqual(cfg['dns']['tag'], 'dns-out')
        self.assertEqual(cfg['dns']['servers'], [])

    def test_dns_server_full_fields(self):
        cfg = render_config({'dns_enabled': '1'}, dns_servers=[TEST_DNS_RU])
        server = cfg['dns']['servers'][0]
        self.assertEqual(server['address'],
                         'https://dns.yandex.ru/dns-query')
        self.assertEqual(server['port'], 443)
        self.assertEqual(server['skipFallback'], True)
        self.assertEqual(server['domains'], ['geosite:ru', 'domain:ya.ru'])
        self.assertEqual(server['expectedIPs'], ['geoip:ru'])

    def test_dns_disabled_server_is_omitted(self):
        disabled = dict(TEST_DNS_SERVER, enabled='0')
        cfg = render_config({'dns_enabled': '1'},
                            dns_servers=[disabled, TEST_DNS_RU])
        self.assertEqual([s['address'] for s in cfg['dns']['servers']],
                         [TEST_DNS_RU['address']])

    def test_dns_hosts_only_config(self):
        hosts = '{"example.com": "192.0.2.10"}'
        cfg = render_config({'dns_enabled': '1', 'dns_hosts_json': hosts})
        self.assertEqual(cfg['dns']['servers'], [])
        self.assertEqual(cfg['dns']['hosts'], {'example.com': '192.0.2.10'})

    def test_dns_hosts_with_servers_and_list_values(self):
        hosts = '{"a.example": "192.0.2.1", "*.lan": ["192.0.2.2", "192.0.2.3"]}'
        cfg = render_config({'dns_enabled': '1', 'dns_hosts_json': hosts},
                            dns_servers=[TEST_DNS_SERVER])
        self.assertEqual(cfg['dns']['hosts']['*.lan'], ['192.0.2.2', '192.0.2.3'])
        self.assertEqual(cfg['dns']['servers'][0]['address'], 'https://1.1.1.1/dns-query')

    def test_dns_form_wins_over_raw_json(self):
        raw = '{"servers": ["https://9.9.9.9/dns-query"]}'
        cfg = render_config({'dns_enabled': '1', 'dns_json': raw},
                            dns_servers=[TEST_DNS_SERVER])
        self.assertEqual(cfg['dns']['servers'][0]['address'],
                         'https://1.1.1.1/dns-query')

    def test_dns_enabled_without_content_falls_back_to_raw(self):
        raw = '{"servers": ["https://9.9.9.9/dns-query"]}'
        cfg = render_config({'dns_enabled': '1', 'dns_json': raw})
        self.assertEqual(cfg['dns'], {'servers': ['https://9.9.9.9/dns-query']})

    def test_dns_query_strategy_and_flags(self):
        cfg = render_config({
            'dns_enabled': '1',
            'dns_query_strategy': 'useIp4',
            'dns_disable_cache': '1',
            'dns_disable_fallback': '1',
            'dns_disable_fallback_if_match': '1',
            'dns_enable_parallel_query': '1',
        }, dns_servers=[TEST_DNS_SERVER])
        self.assertEqual(cfg['dns']['queryStrategy'], 'useIp4')
        self.assertEqual(cfg['dns']['disableCache'], True)
        self.assertEqual(cfg['dns']['disableFallback'], True)
        self.assertEqual(cfg['dns']['disableFallbackIfMatch'], True)
        self.assertEqual(cfg['dns']['enableParallelQuery'], True)
        self.assertEqual(cfg['dns']['useSystemHosts'], False)

    def test_default_action_is_configurable(self):
        cfg = render_config()
        self.assertEqual(cfg['routing']['rules'][-1], {'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'direct'})
        cfg = render_config({'default_action': 'block'})
        self.assertEqual(cfg['routing']['rules'][-1]['outboundTag'], 'block')
        node = 'node_' + TEST_NODE['@uuid']
        cfg = render_config({'default_action': node}, nodes=[TEST_NODE])
        self.assertEqual(cfg['routing']['rules'][-1]['outboundTag'], node)
        cfg = render_config({'default_action': 'auto'}, balancers=[TEST_BALANCER])
        self.assertEqual(cfg['routing']['rules'][-1]['balancerTag'], 'auto')
        self.assertNotIn('outboundTag', cfg['routing']['rules'][-1])

    def test_pinned_rules_come_first(self):
        a = dict(TEST_RULE, sequence='10', domain='geosite:a', pinned='0')
        b = dict(TEST_RULE, sequence='20', domain='geosite:b', pinned='1')
        c = dict(TEST_RULE, sequence='5', domain='geosite:c')  # no field: not pinned
        d = dict(TEST_RULE, sequence='30', domain='geosite:d', pinned='1')
        cfg = render_config(rules=[a, b, c, d])
        doms = [r['domain'][0] for r in cfg['routing']['rules'][1:-1]]
        self.assertEqual(doms, ['geosite:b', 'geosite:d', 'geosite:c', 'geosite:a'])
        self.assertEqual(cfg['routing']['rules'][0]['inboundTag'], ['api-in'])

    def test_pin_to_end_rules_come_last(self):
        a = dict(TEST_RULE, sequence='10', domain='geosite:a')
        e = dict(TEST_RULE, sequence='5', domain='geosite:e', pin_end='1')
        t = dict(TEST_RULE, sequence='50', domain='geosite:t', pinned='1')
        both = dict(TEST_RULE, sequence='60', domain='geosite:x', pinned='1', pin_end='1')
        cfg = render_config(rules=[e, a, t, both])
        doms = [r['domain'][0] for r in cfg['routing']['rules'][1:-1]]
        self.assertEqual(doms, ['geosite:t', 'geosite:x', 'geosite:a', 'geosite:e'])

    def test_rule_conditions_are_omitted_when_empty(self):
        cfg = render_config(rules=[TEST_RULE])
        rule = cfg['routing']['rules'][1]
        for key in ('inboundTag', 'source', 'sourcePort', 'user', 'ruleTag'):
            self.assertNotIn(key, rule)

    def test_rule_conditions_are_emitted(self):
        rule = dict(TEST_RULE,
                    inbound_tag='tun-in, socks-in',
                    source='192.168.0.0/16, geoip:private',
                    source_port='53,1000-2000',
                    user='alice, bob',
                    rule_tag='home-rules')
        cfg = render_config(rules=[rule])
        out = cfg['routing']['rules'][1]
        self.assertEqual(out['inboundTag'], ['tun-in', 'socks-in'])
        self.assertEqual(out['source'], ['192.168.0.0/16', 'geoip:private'])
        self.assertEqual(out['sourcePort'], '53,1000-2000')
        self.assertEqual(out['user'], ['alice', 'bob'])
        self.assertEqual(out['ruleTag'], 'home-rules')

    def test_routing_domain_strategy_from_general(self):
        self.assertEqual(render_config()['routing']['domainStrategy'],
                         'IPIfNonMatch')
        cfg = render_config({'routing_domain_strategy': 'AsIs'})
        self.assertEqual(cfg['routing']['domainStrategy'], 'AsIs')
        cfg = render_config({'routing_domain_strategy': 'IPOnDemand'})
        self.assertEqual(cfg['routing']['domainStrategy'], 'IPOnDemand')


    def test_balancer_generated_from_model(self):
        cfg = render_config({'observatory_type': 'burst'},
                            balancers=[TEST_BALANCER])
        self.assertEqual(cfg['routing']['balancers'], [{
            'tag': 'auto',
            'selector': ['node_'],
            'strategy': {'type': 'leastPing'},
            'fallbackTag': 'direct',
        }])

    def test_inbound_password_with_quotes_and_backslash(self):
        pw = 'p"a\\ss\'w'
        cfg = render_config({'socks_auth': 'password', 'socks_username': 'u',
                             'socks_password': pw})
        socks = [i for i in cfg['inbounds'] if i['tag'] == 'socks-in'][0]
        self.assertEqual(socks['settings']['users'][0]['pass'], pw)

    def _dialer(self, value, first_enabled='1'):
        first = dict(TEST_NODE, name='DE VPS', enabled=first_enabled)
        chained = dict(XDRIVE_NODE, sockopt_dialer_proxy=value)
        cfg = render_config(nodes=[first, chained])
        out = [o for o in cfg['outbounds'] if o['tag'] == 'node_' + XDRIVE_NODE['@uuid']][0]
        return out['streamSettings']['sockopt']['dialerProxy']

    def _chain_cfg(self, **chain_over):
        a = dict(XDRIVE_NODE, **{'@uuid': 'aaaaaaaa-0000-0000-0000-00000000000a', 'name': 'A'})
        b = dict(XDRIVE_NODE, **{'@uuid': 'bbbbbbbb-0000-0000-0000-00000000000b', 'name': 'B'})
        c = dict(XDRIVE_NODE, **{'@uuid': 'cccccccc-0000-0000-0000-00000000000c', 'name': 'C'})
        chain = {'@uuid': 'chain0001', 'enabled': '1', 'name': 'AB', 'hop1': a['@uuid'],
                 'hop2': b['@uuid'], 'hop3': '', 'hop4': '', 'hop5': ''}
        chain.update(chain_over)
        return render_config(nodes=[a, b, c], chains=[chain])

    @staticmethod
    def _by_tag(cfg):
        return {o['tag']: o for o in cfg['outbounds']}

    def test_chain_two_hops(self):
        out = self._by_tag(self._chain_cfg())
        exit_hop = out['chain_chain0001']
        self.assertEqual(exit_hop['streamSettings']['sockopt']['dialerProxy'], 'chain_chain0001_1')
        self.assertNotIn('sockopt', out['chain_chain0001_1']['streamSettings'])
        # The original nodes are untouched.
        self.assertIn('node_aaaaaaaa-0000-0000-0000-00000000000a', out)

    def test_chain_three_hops_link_in_order(self):
        out = self._by_tag(self._chain_cfg(hop3='cccccccc-0000-0000-0000-00000000000c'))
        self.assertEqual(out['chain_chain0001_2']['streamSettings']['sockopt']['dialerProxy'], 'chain_chain0001_1')
        self.assertEqual(out['chain_chain0001']['streamSettings']['sockopt']['dialerProxy'], 'chain_chain0001_2')

    def test_chain_with_missing_node_is_skipped(self):
        out = self._by_tag(self._chain_cfg(hop2='dddddddd-0000-0000-0000-00000000000d'))
        self.assertFalse([t for t in out if t.startswith('chain_')])

    def test_disabled_chain_is_skipped(self):
        out = self._by_tag(self._chain_cfg(enabled='0'))
        self.assertFalse([t for t in out if t.startswith('chain_')])

    def test_rule_can_target_chain(self):
        rule = {'@uuid': 'r1', 'enabled': '1', 'sequence': '1', 'description': 'x',
                'domain': 'example.com', 'outbound_tag': 'chain_chain0001', 'network_proto': 'tcp_udp'}
        a = dict(XDRIVE_NODE, **{'@uuid': 'a', 'name': 'A'})
        b = dict(XDRIVE_NODE, **{'@uuid': 'b', 'name': 'B'})
        chain = {'@uuid': 'chain0001', 'enabled': '1', 'name': 'AB', 'hop1': 'a', 'hop2': 'b'}
        cfg = render_config(nodes=[a, b], chains=[chain], rules=[rule])
        targets = [r.get('outboundTag') for r in cfg['routing']['rules']]
        self.assertIn('chain_chain0001', targets)

    def test_dialer_proxy_accepts_node_name(self):
        self.assertEqual(self._dialer('DE VPS'), 'node_' + TEST_NODE['@uuid'])

    def test_dialer_proxy_raw_tag_passes_through(self):
        self.assertEqual(self._dialer('node_abc'), 'node_abc')

    def test_dialer_proxy_name_of_disabled_node_is_not_resolved(self):
        self.assertEqual(self._dialer('DE VPS', first_enabled='0'), 'DE VPS')

    def test_tls_use_system_ca_only_when_enabled(self):
        node = dict(XDRIVE_NODE)
        stream = render_config(nodes=[node])['outbounds'][0]['streamSettings']
        self.assertNotIn('useSystemCA', stream['tlsSettings'])
        node['tls_use_system_ca'] = '1'
        stream = render_config(nodes=[node])['outbounds'][0]['streamSettings']
        self.assertIs(stream['tlsSettings']['useSystemCA'], True)

    def test_balancer_selector_skips_non_proxy_nodes(self):
        vless = dict(TEST_NODE, **{'@uuid': 'aaaaaaaa-0000-0000-0000-000000000001',
                                   'protocol': 'vless', 'address': 'a.example', 'port': '443'})
        wg = dict(TEST_NODE, **{'@uuid': 'aaaaaaaa-0000-0000-0000-000000000002',
                                'protocol': 'wireguard'})
        hole = dict(TEST_NODE, **{'@uuid': 'aaaaaaaa-0000-0000-0000-000000000003',
                                  'protocol': 'blackhole'})
        cfg = render_config({'observatory_type': 'burst'},
                            nodes=[vless, wg, hole, TEST_NODE],
                            balancers=[TEST_BALANCER])
        expected = ['node_aaaaaaaa-0000-0000-0000-000000000001',
                    'node_aaaaaaaa-0000-0000-0000-000000000002']
        self.assertEqual(cfg['routing']['balancers'][0]['selector'], expected)
        self.assertEqual(cfg['burstObservatory']['subjectSelector'], expected)

    def test_balancer_selector_with_only_non_proxy_nodes_fails_closed(self):
        # Xray rejects an empty selector list, so a prefix that matches only
        # freedom/blackhole nodes becomes "__none__": it matches no outbound,
        # so the balancer selects nothing instead of rotating traffic into
        # freedom (a leak) or a blackhole (a silent outage).
        hole = dict(TEST_NODE, **{'@uuid': 'cccccccc-0000-0000-0000-000000000001',
                                  'protocol': 'blackhole'})
        cfg = render_config({'observatory_type': 'burst'},
                            nodes=[TEST_NODE, hole],
                            balancers=[TEST_BALANCER])
        self.assertEqual(cfg['routing']['balancers'][0]['selector'],
                         ['__none__'])
        self.assertEqual(cfg['burstObservatory']['subjectSelector'],
                         ['__none__'])

    def test_balancer_selector_passes_other_prefixes_through(self):
        vless = dict(TEST_NODE, **{'@uuid': 'bbbbbbbb-0000-0000-0000-000000000001',
                                   'protocol': 'vless'})
        bal = dict(TEST_BALANCER, selector='node_,custom_')
        cfg = render_config(nodes=[vless], balancers=[bal])
        self.assertEqual(cfg['routing']['balancers'][0]['selector'],
                         ['node_bbbbbbbb-0000-0000-0000-000000000001', 'custom_'])

    def test_balancer_without_observatory_omits_fallback_tag(self):
        # Xray fails "not all dependencies are resolved" when a balancer
        # carries fallbackTag but no observatory is configured. The template
        # omits fallbackTag in that case (the balancer still functions).
        cfg = render_config(balancers=[TEST_BALANCER])
        self.assertEqual(cfg['routing']['balancers'], [{
            'tag': 'auto',
            'selector': ['node_'],
            'strategy': {'type': 'leastPing'},
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

    def test_xdrive_google_drive(self):
        cfg = render_config(nodes=[XDRIVE_NODE])
        stream = cfg['outbounds'][0]['streamSettings']
        self.assertEqual(stream['network'], 'xdrive')
        self.assertEqual(stream['security'], 'tls')
        self.assertEqual(stream['tlsSettings']['fingerprint'], 'hellochrome_155')
        self.assertEqual(stream['xdriveSettings'], {
            'service': 'google-drive',
            'remoteFolder': 'folder-id',
            'secrets': ['client-id', 'client-secret', 'refresh-token'],
        })
        # XDRIVE must be paired with mux; the VLESS user keeps the encryption.
        self.assertEqual(cfg['outbounds'][0]['mux'],
                         {'enabled': True, 'concurrency': 128})
        self.assertEqual(cfg['outbounds'][0]['settings']['vnext'][0]['users'][0]['encryption'],
                         'mlkem768x25519plus.native.0rtt.clientkey')

    def test_xdrive_h3_alpn_is_exact(self):
        cfg = render_config(nodes=[dict(XDRIVE_NODE, alpn=['h3'])])
        stream = cfg['outbounds'][0]['streamSettings']
        self.assertEqual(stream['tlsSettings']['alpn'], ['h3'])

    def test_xdrive_s3_without_session_token(self):
        node = dict(XDRIVE_NODE, **{
            'xdrive_service': 's3',
            'xdrive_remote_folder': 'prefix',
            'xdrive_s3_endpoint': 'https://minio.example.com:9000',
            'xdrive_s3_region': '',
            'xdrive_s3_bucket': 'bucket',
            'xdrive_s3_access_key': 'access-key',
            'xdrive_s3_secret_key': 'secret-key',
            'xdrive_s3_session_token': '',
            'xdrive_s3_path_style': '1',
        })
        settings = render_config(nodes=[node])['outbounds'][0]['streamSettings']['xdriveSettings']
        self.assertEqual(settings['secrets'], ['access-key', 'secret-key'])
        self.assertEqual(settings['s3'], {
            'endpoint': 'https://minio.example.com:9000',
            'region': '',
            'bucket': 'bucket',
            'pathStyle': True,
        })

    def test_xdrive_s3_with_session_token_and_virtual_host_style(self):
        node = dict(XDRIVE_NODE, **{
            'xdrive_service': 's3',
            'xdrive_remote_folder': 'prefix',
            'xdrive_s3_endpoint': 'https://s3.eu-central-1.amazonaws.com',
            'xdrive_s3_region': 'eu-central-1',
            'xdrive_s3_bucket': 'bucket',
            'xdrive_s3_access_key': 'access-key',
            'xdrive_s3_secret_key': 'secret-key',
            'xdrive_s3_session_token': 'session-token',
            'xdrive_s3_path_style': '0',
        })
        settings = render_config(nodes=[node])['outbounds'][0]['streamSettings']['xdriveSettings']
        self.assertEqual(settings['secrets'],
                         ['access-key', 'secret-key', 'session-token'])
        self.assertFalse(settings['s3']['pathStyle'])

    def test_xdrive_template_with_extra(self):
        node = dict(XDRIVE_NODE, **{
            'xdrive_service': 'template',
            'xdrive_remote_folder': 'prefix',
            'xdrive_template_secrets': '["t0", "t1"]',
            'xdrive_template': '{"auth": {"type": "basic"}, "put": {"method": "PUT"}}',
            'xdrive_extra': '{"concurrency": 16, "xmux": {"maxConnections": 4}}',
        })
        settings = render_config(nodes=[node])['outbounds'][0]['streamSettings']['xdriveSettings']
        self.assertEqual(settings['secrets'], ['t0', 't1'])
        self.assertEqual(settings['template'],
                         {'auth': {'type': 'basic'}, 'put': {'method': 'PUT'}})
        self.assertEqual(settings['concurrency'], 16)
        self.assertEqual(settings['xmux'], {'maxConnections': 4})

    def test_xdrive_local_has_no_storage_objects(self):
        node = dict(XDRIVE_NODE, **{
            'xdrive_service': 'local',
            'xdrive_remote_folder': '/var/db/xdrive',
        })
        settings = render_config(nodes=[node])['outbounds'][0]['streamSettings']['xdriveSettings']
        self.assertEqual(settings, {
            'service': 'local',
            'remoteFolder': '/var/db/xdrive',
        })

    def test_xdrive_template_without_secrets_is_an_empty_array(self):
        node = dict(XDRIVE_NODE, **{
            'xdrive_service': 'template',
            'xdrive_remote_folder': 'prefix',
            'xdrive_template': '{"auth": {"type": "none"}}',
        })
        settings = render_config(nodes=[node])['outbounds'][0]['streamSettings']['xdriveSettings']
        self.assertEqual(settings['secrets'], [])


class _FakeFile:
    def __init__(self, content):
        self.content = content

    def read(self):
        return self.content

    def close(self):
        pass


def _pkt(text):
    raw = text.encode()
    return ('%04x' % (len(raw) + 4)).encode() + raw


class TestPluginBranches(unittest.TestCase):
    def setUp(self):
        import plugin_branches
        self.pb = plugin_branches

    def test_parse_refs_keeps_only_branches(self):
        data = (
            _pkt('# service=git-upload-pack\n') + b'0000'
            + _pkt('a' * 40 + ' HEAD\0multi_ack symref=HEAD:refs/heads/main\n')
            + _pkt('b' * 40 + ' refs/heads/main\n')
            + _pkt('c' * 40 + ' refs/heads/ui-rules\n')
            + _pkt('d' * 40 + ' refs/tags/v1.0\n')
            + b'0000'
        )
        self.assertEqual(self.pb.parse_refs(data), ['main', 'ui-rules'])

    def test_parse_refs_survives_garbage(self):
        self.assertEqual(self.pb.parse_refs(b''), [])
        self.assertEqual(self.pb.parse_refs(b'zzzz<html>'), [])
        self.assertEqual(self.pb.parse_refs(b'00ffshort'), [])

    def test_order_puts_main_first_and_drops_unsafe_names(self):
        names = ['zeta', 'Alpha', 'main', 'feature/x', 'bad name', 'bad;rm', 'alpha2', 'main']
        self.assertEqual(self.pb.order(names), ['main', 'Alpha', 'alpha2', 'zeta'])

    def test_order_without_default_branch(self):
        self.assertEqual(self.pb.order(['b', 'a']), ['a', 'b'])

    def test_unreachable_github_is_reported_in_band(self):
        import io
        import contextlib
        with patch.object(self.pb, '_get', side_effect=OSError('blocked')):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                self.pb.main()
        out = json.loads(buf.getvalue())
        self.assertEqual(out['status'], 'error')
        self.assertEqual(out['branches'], [])

    def test_falls_back_to_rest_api(self):
        api = json.dumps([{'name': 'main'}, {'name': 'ui-rules'}]).encode()

        def fake_get(url):
            if 'info/refs' in url:
                raise OSError('blocked')
            return api
        with patch.object(self.pb, '_get', side_effect=fake_get):
            self.assertEqual(self.pb.list_branches(), ['main', 'ui-rules'])


class TestConfigShellTest(unittest.TestCase):
    """test_config.sh with a fake xray binary."""

    def run_script(self, banner, rc, config):
        import json
        import shutil
        import stat
        import subprocess
        import sys
        import tempfile
        script = os.path.join(SCRIPT_DIR, 'test_config.sh')
        with tempfile.TemporaryDirectory() as tmp:
            fake = os.path.join(tmp, 'xray')
            with open(fake, 'w') as fh:
                fh.write('#!/bin/sh\necho "%s"\necho "Failed to start: something"\nexit %d\n' % (banner, rc))
            os.chmod(fake, os.stat(fake).st_mode | stat.S_IEXEC)
            cfg = os.path.join(tmp, 'config.json')
            with open(cfg, 'w') as fh:
                json.dump(config, fh)
            env = dict(os.environ, XRAY_BIN=fake, XRAY_CONFIG=cfg, XRAY_PYTHON=sys.executable)
            out = subprocess.run(['sh', script], env=env, capture_output=True, text=True).stdout
            return json.loads(out)

    XDRIVE_CFG = {'outbounds': [{'streamSettings': {'network': 'xdrive'}}]}
    PLAIN_CFG = {'outbounds': [{'streamSettings': {'network': 'tcp'}}]}

    def test_ok(self):
        res = self.run_script('Xray 26.11.9 (go1.26)', 0, self.PLAIN_CFG)
        self.assertEqual(res, {'status': 'ok'})

    def test_old_core_with_xdrive_gets_a_clear_message(self):
        res = self.run_script('Xray 26.10.29 (go1.26)', 1, self.XDRIVE_CFG)
        self.assertEqual(res['status'], 'error')
        self.assertIn('26.11.9 or newer', res['message'])
        self.assertIn('26.10.29', res['message'])
        self.assertIn('something', res['message'])

    def test_new_core_error_is_passed_through(self):
        res = self.run_script('Xray 26.11.9 (go1.26)', 1, self.XDRIVE_CFG)
        self.assertNotIn('26.11.9 or newer', res['message'])
        self.assertIn('something', res['message'])

    def test_old_core_without_xdrive_is_passed_through(self):
        res = self.run_script('Xray 26.10.29 (go1.26)', 1, self.PLAIN_CFG)
        self.assertNotIn('XDRIVE', res['message'])


class TestWarpMasque(unittest.TestCase):
    """warp_masque.py against a local stand-in for the Cloudflare API."""

    def setUp(self):
        import base64
        import subprocess
        import tempfile
        import threading
        from http.server import BaseHTTPRequestHandler, HTTPServer
        import warp_masque
        self.wm, self.seen = warp_masque, {}
        seen = self.seen

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def _send(self, code, obj):
                raw = json.dumps(obj).encode()
                self.send_response(code)
                self.send_header('Content-Length', str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def _body(self):
                return json.loads(self.rfile.read(int(self.headers['Content-Length'])))

            def do_POST(self):
                seen['post'] = (self.path, self._body())
                self._send(200, {'result': {'id': 'dev-1', 'token': 'tok-1'}})

            def do_PATCH(self):
                seen['patch'] = (self.path, self._body(), self.headers.get('Authorization'))
                self._send(200, {'success': True, 'result': {'config': {
                    'peers': [{'public_key': '-----BEGIN PUBLIC KEY-----\nMFkwEwYH\nKoZIzj0C\n-----END PUBLIC KEY-----\n',
                               'endpoint': {'v4': '162.159.198.2:0'}}],
                    'interface': {'addresses': {'v4': '172.16.0.2', 'v6': '2606:4700:110:8a36::2'}}}}})

        self.server = HTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.cfg = dict(warp_masque._DEFAULTS,
                        masque_api_base='http://127.0.0.1:%d/v0a4471' % self.server.server_port,
                        # never reach the real fallback host from a test
                        masque_api_base_fallback='')
        self.base64, self.subprocess, self.tempfile = base64, subprocess, tempfile

    def tearDown(self):
        self.server.shutdown()

    def test_registration_and_enrollment(self):
        res = self.wm.build_result(self.cfg)
        self.assertEqual(res['status'], 'ok')
        self.assertEqual(res['edge_public_key'], 'MFkwEwYHKoZIzj0C')
        self.assertEqual(res['addresses'], ['172.16.0.2/32', '2606:4700:110:8a36::2/128'])
        self.assertEqual(res['endpoint'], '162.159.198.2')
        self.assertEqual(self.seen['post'][0], '/v0a4471/reg')
        path, body, auth = self.seen['patch']
        self.assertEqual(path, '/v0a4471/reg/dev-1')
        self.assertEqual((body['key_type'], body['tunnel_type']), ('secp256r1', 'masque'))
        self.assertEqual(auth, 'Bearer tok-1')

    def test_enrolled_key_belongs_to_returned_private_key(self):
        res = self.wm.build_result(self.cfg)
        path = self.tempfile.mktemp()
        with open(path, 'wb') as fh:
            fh.write(self.base64.b64decode(res['private_key']))
        try:
            pub = self.subprocess.run(['openssl', 'ec', '-inform', 'DER', '-in', path, '-pubout', '-outform', 'DER'],
                                      capture_output=True, check=True).stdout
        finally:
            os.unlink(path)
        self.assertEqual(self.base64.b64encode(pub).decode(), self.seen['patch'][1]['key'])

    def test_unreachable_api_is_reported(self):
        cfg = dict(self.cfg, masque_api_base='http://127.0.0.1:1/x')
        with self.assertRaises(self.wm.WarpError):
            self.wm.build_result(cfg)

    def test_unreachable_main_api_falls_back(self):
        cfg = dict(self.cfg, masque_api_base='http://127.0.0.1:1/x',
                   masque_api_base_fallback=self.cfg['masque_api_base'])
        res = self.wm.build_result(cfg)
        self.assertEqual(res['status'], 'ok')
        self.assertEqual(self.seen['patch'][0], '/v0a4471/reg/dev-1')

    def test_http_error_does_not_fall_back(self):
        calls = []

        def refuse(cfg):
            calls.append(cfg['masque_api_base'])
            raise self.wm.WarpError('Cloudflare answered HTTP 403')
        original, self.wm.register = self.wm.register, refuse
        try:
            with self.assertRaises(self.wm.WarpError):
                self.wm.build_result(dict(self.cfg, masque_api_base_fallback='http://127.0.0.1:2/y'))
        finally:
            self.wm.register = original
        self.assertEqual(len(calls), 1)

    def test_answer_without_addresses_is_an_error(self):
        with self.assertRaises(self.wm.WarpError):
            self.wm.extract({'peers': [{'public_key': 'AAAA'}], 'interface': {}})


class TestModelMasks(unittest.TestCase):
    """A Mask is used as a PHP regex; an unescaped delimiter inside it breaks
    the pattern and makes every value fail validation."""

    def test_masks_have_no_unescaped_delimiter(self):
        import re
        import xml.etree.ElementTree as ET
        model = os.path.join(SCRIPT_DIR, '..', '..', '..', 'mvc', 'app', 'models',
                             'OPNsense', 'XrayClient', 'XrayClient.xml')
        broken = []
        for el in ET.parse(model).getroot().iter('Mask'):
            mask = (el.text or '').strip()
            self.assertTrue(mask.startswith('/'), mask)
            body = mask[1:mask.rindex('/')]
            if re.search(r'(?<!\\)/', body):
                broken.append(mask)
        self.assertEqual(broken, [])


class TestWarpProbe(unittest.TestCase):
    """warp_probe.py: candidates, test config, search logic and the whole
    pipeline against a fake xray."""

    CRED_WG = {'wg_secret_key': 'S' * 43 + '=', 'wg_public_key': 'P' * 43 + '=', 'wg_address': ['172.16.0.2/32']}
    CRED_MQ = {'masque_warp_private_key': 'K' * 60, 'masque_warp_address': ['172.16.0.2/32'],
               'masque_warp_public_key': 'E' * 90}

    def setUp(self):
        import tempfile
        import warp_probe
        self.wp = warp_probe
        warp_probe.fetch_colos = lambda: {}      # no network in tests
        self.tmp = tempfile.mkdtemp()
        self.cache = warp_probe.Cache(os.path.join(self.tmp, 'cache.json'))

    def take(self, mode, n, **kw):
        import itertools
        import random
        return list(itertools.islice(self.wp.generate_candidates(mode, rng=random.Random(1), **kw), n))

    def test_documented_defaults_come_first_then_all_ranges(self):
        got = self.take('wg', 40)
        self.assertEqual(got[0], ('162.159.192.1', 2408))
        prefixes = {h.rsplit('.', 1)[0] for h, _ in got[:15]}
        self.assertEqual(prefixes, set(self.wp.WG_RANGES))
        self.assertEqual(len(set(got)), len(got))
        self.assertTrue(all(p in self.wp.WG_PORTS for _, p in got))

    def test_masque_candidates_and_zero_trust(self):
        got = self.take('masque_h2', 60)
        self.assertEqual(got[0], ('162.159.198.2', 443))
        self.assertTrue(all(h.startswith(('162.159.198.', '162.159.199.')) for h, _ in got))
        self.assertTrue(all(p in self.wp.MASQUE_PORTS for _, p in got))
        self.assertFalse(any(h.startswith('162.159.197.') for h, _ in self.take('masque_h3', 200)))
        zt = self.take('masque_h3', 300, zero_trust=True)
        self.assertTrue(any(h.startswith('162.159.197.') and 1 <= int(h.split('.')[-1]) <= 10 for h, _ in zt))

    def test_skip_list_is_honoured(self):
        skip = {self.wp.candidate_key('wg', '162.159.192.1', 2408)}
        self.assertNotIn(('162.159.192.1', 2408), self.take('wg', 50, skip=skip))

    def test_wireguard_config_never_uses_a_kernel_tun(self):
        cfg = self.wp.build_xray_config('wg', '8.6.112.5', 2408, self.CRED_WG, 12345)
        out = cfg['outbounds'][0]
        self.assertTrue(out['settings']['noKernelTun'])
        self.assertEqual(out['settings']['peers'][0]['endpoint'], '8.6.112.5:2408')
        self.assertEqual(cfg['inbounds'][0]['listen'], '127.0.0.1')

    def test_masque_config_alpn_follows_the_mode(self):
        for mode, alpn in (('masque_h2', ['h2']), ('masque_h3', ['h3'])):
            out = self.wp.build_xray_config(mode, '162.159.198.2', 443, self.CRED_MQ, 1)['outbounds'][0]
            self.assertEqual(out['streamSettings']['tlsSettings']['alpn'], alpn)
            self.assertEqual(out['settings'], {'address': '162.159.198.2', 'port': 443})
            self.assertEqual(out['streamSettings']['masqueSettings']['warp']['publicKey'], 'E' * 90)

    def take6(self, mode, n, skip=()):
        import itertools
        import random
        return list(itertools.islice(self.wp.generate_candidates_v6(mode, random.Random(1), skip), n))

    def test_ipv6_candidates_come_from_the_known_pools(self):
        import ipaddress
        got = self.take6('wg', 60)
        pools = [ipaddress.ip_network('2606:4700:d0::/48'), ipaddress.ip_network('2606:4700:d1::/48')]
        self.assertTrue(all(any(ipaddress.ip_address(h) in n for n in pools) for h, _ in got))
        self.assertTrue(all(p in self.wp.WG_PORTS for _, p in got))
        self.assertTrue(all(ipaddress.ip_address(h).packed[6:8] == b'\0\0' for h, _ in got))  # fourth hextet is 0
        got = self.take6('masque_h2', 60)
        pools = [ipaddress.ip_network('2606:4700:103::/48'), ipaddress.ip_network('2606:4700:104::/48')]
        self.assertTrue(all(any(ipaddress.ip_address(h) in n for n in pools) for h, _ in got))
        self.assertTrue(all(p in self.wp.MASQUE_PORTS for _, p in got))

    def test_ipv6_masque_h3_is_the_four_fixed_addresses_and_ends(self):
        got = self.take6('masque_h3', 1000)
        self.assertEqual({h for h, _ in got}, set(self.wp.MASQUE_V6_FIXED))
        self.assertEqual(len(got), len(self.wp.MASQUE_V6_FIXED) * len(self.wp.MASQUE_PORTS))
        skip = {self.wp.candidate_key('masque_h3', '2606:4700:103::1', 443)}
        self.assertNotIn(('2606:4700:103::1', 443), self.take6('masque_h3', 1000, skip))

    def test_ipv6_endpoints_are_bracketed_in_the_probe_config(self):
        cfg = self.wp.build_xray_config('wg', '2606:4700:d0::1:2:3:4', 2408, self.CRED_WG, 1)
        self.assertEqual(cfg['outbounds'][0]['settings']['peers'][0]['endpoint'], '[2606:4700:d0::1:2:3:4]:2408')
        out = self.wp.build_xray_config('masque_h3', '2606:4700:103::1', 443, self.CRED_MQ, 1)['outbounds'][0]
        self.assertEqual(out['settings']['address'], '2606:4700:103::1')
        self.assertNotIn('targetStrategy', out)
        out = self.wp.build_xray_config('masque_h3', '162.159.198.2', 443, self.CRED_MQ, 1)['outbounds'][0]
        self.assertEqual(out['targetStrategy'], 'UseIPv4')

    def test_ipv6_search_needs_a_route_and_uses_ipv6_candidates(self):
        import random
        probe = self.fake_probe(set())
        req = {'mode': 'wg', 'credentials': self.CRED_WG, 'want': 2, 'max_attempts': 20, 'ipv6': True}
        no_route = self.wp.Search(req, os.path.join(self.tmp, 'v6a.json'), self.cache, probe=probe,
                                  rng=random.Random(2), ipv6_check=lambda: False)
        with self.assertRaises(ValueError):
            no_route.run(None)
        self.assertEqual(probe.calls, [])
        search = self.wp.Search(req, os.path.join(self.tmp, 'v6b.json'), self.cache, probe=probe,
                                rng=random.Random(2), ipv6_check=lambda: True)
        st = search.run(None)
        self.assertGreaterEqual(st['verified'], 2)
        self.assertTrue(all(':' in h for h, _ in probe.calls))

    def test_recheck_accepts_ipv6_endpoints(self):
        base = {'mode': 'wg', 'credentials': self.CRED_WG}
        self.wp.validate_request(dict(base, endpoints=[{'host': '2606:4700:d0::1', 'port': 2408}]))
        with self.assertRaises(ValueError):
            self.wp.validate_request(dict(base, endpoints=[{'host': 'example.com', 'port': 2408}]))
    def test_targets_are_parsed_and_checked(self):
        import ipaddress
        e = self.wp.parse_targets(['188.114.98.0/30, 162.159.192.5:2408', '[2606:4700:d0::1]:500'])
        self.assertEqual([(str(n), p) for n, p in e],
                         [('188.114.98.0/30', None), ('162.159.192.5/32', 2408), ('2606:4700:d0::1/128', 500)])
        for bad in ('example.com', '188.114.96.0/19', '10.0.0.1', '1.1.1.1', '188.114.98.0/30:2408', '162.159.192.5:99999'):
            with self.assertRaises(ValueError, msg=bad):
                self.wp.parse_targets([bad])
        self.assertEqual(len(self.wp.parse_targets(['93.184.216.34'], any_address=True)), 1)
        with self.assertRaises(ValueError):
            self.wp.parse_targets([])
        with self.assertRaises(ValueError):
            self.wp.parse_targets(['188.114.98.%d' % i for i in range(60)])

    def test_target_candidates_pinned_first_then_common_ports(self):
        import itertools
        import random
        e = self.wp.parse_targets(['188.114.98.0/31', '162.159.192.5:2408'])
        got = list(itertools.islice(self.wp.generate_targets('wg', e, random.Random(1)), 12))
        self.assertEqual(got[0], ('162.159.192.5', 2408))
        self.assertEqual({h for h, p in got[1:3]}, {'188.114.98.0', '188.114.98.1'})
        self.assertEqual(got[1][1], 2408)
        everything = list(self.wp.generate_targets('wg', e, random.Random(1)))
        self.assertEqual(len(everything), len(set(everything)))
        self.assertEqual(len(everything), 1 + 2 * len(self.wp.WG_PORTS))
        skip = {self.wp.candidate_key('wg', '162.159.192.5', 2408)}
        self.assertNotIn(('162.159.192.5', 2408), self.wp.generate_targets('wg', e, random.Random(1), skip))

    def test_search_with_targets_tries_only_those_hosts(self):
        probe = self.fake_probe(set())
        st = self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 2, 'max_attempts': 30,
                              'targets': ['188.114.98.0/29']}, probe, 'tg')
        self.assertGreaterEqual(st['verified'], 2)
        self.assertTrue(all(h.startswith('188.114.98.') for h, _ in probe.calls))
        with self.assertRaises(ValueError):
            self.wp.validate_request({'mode': 'wg', 'credentials': self.CRED_WG, 'targets': ['10.1.1.1']})

    def test_trace_must_be_warp_and_not_the_router_itself(self):
        tr = self.wp.parse_trace('ip=104.28.1.1\nwarp=on\nloc=NL\n')
        self.assertTrue(self.wp.trace_is_warp(tr))
        self.assertTrue(self.wp.trace_is_warp(tr, '93.1.1.1'))
        self.assertFalse(self.wp.trace_is_warp(tr, '104.28.1.1'))
        self.assertFalse(self.wp.trace_is_warp(self.wp.parse_trace('ip=1.1.1.1\nwarp=off\n')))

    def fake_probe(self, good):
        calls = []

        def probe(mode, host, port, cred, own_ip):
            calls.append((host, port))
            ok = (host, port) in good or len(calls) % 3 == 0
            return {'host': host, 'port': port, 'status': 'verified' if ok else 'failed', 'ms': 50 + len(calls),
                    'kbps': 1000, 'checks': '4/4'}
        probe.calls = calls
        return probe

    def run_search(self, req, probe, tag='s'):
        import random
        state = os.path.join(self.tmp, tag + '.json')
        cancel = os.path.join(self.tmp, tag + '.cancel')
        search = self.wp.Search(req, state, self.cache, probe=probe, rng=random.Random(2), cancel_path=cancel)
        return search.run(None)

    def test_search_stops_when_enough_endpoints_are_verified(self):
        probe = self.fake_probe(set())
        st = self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 3, 'max_attempts': 80}, probe)
        self.assertEqual(st['status'], 'done')
        self.assertGreaterEqual(st['verified'], 3)
        self.assertLess(st['attempts'], 20)
        self.assertEqual([r['status'] for r in st['results']], ['verified'] * len(st['results']))

    def sni_probe(self, works_with):
        calls = []

        def probe(mode, host, port, cred, own_ip, sni=None, finalmask=None):
            calls.append((host, sni))
            ok = sni == works_with
            res = {'host': host, 'port': port, 'status': 'verified' if ok else 'failed', 'ms': 40, 'kbps': 900,
                   'checks': '4/4'}
            if sni:
                res['sni'] = sni
            return res
        probe.calls = calls
        return probe

    def test_sni_search_finds_a_name_that_works_and_keeps_using_it(self):
        probe = self.sni_probe('www.google.com')
        st = self.run_search({'mode': 'masque_h3', 'credentials': self.CRED_MQ, 'want': 2, 'max_attempts': 20,
                              'sni_search': True}, probe, 'sni1')
        self.assertEqual(st['sni'], 'www.google.com')
        self.assertEqual(st['verified'], 2)
        self.assertTrue(all(r['sni'] == 'www.google.com' for r in st['results']))
        # after the name is found the default one is not tried any more
        later = [c for c in probe.calls[4:] if c[1] is None]
        self.assertEqual(later, [])

    def test_sni_search_is_off_by_default_and_never_for_wireguard(self):
        probe = self.sni_probe('www.cloudflare.com')
        st = self.run_search({'mode': 'masque_h3', 'credentials': self.CRED_MQ, 'want': 1, 'max_attempts': 5}, probe, 'sni2')
        self.assertEqual(st['verified'], 0)
        self.assertTrue(all(c[1] is None for c in probe.calls))
        self.assertNotIn('sni', st)

    def test_sni_search_tries_only_a_few_candidates(self):
        probe = self.sni_probe('no-such-name')
        st = self.run_search({'mode': 'masque_h3', 'credentials': self.CRED_MQ, 'want': 1, 'max_attempts': 10,
                              'sni_search': True}, probe, 'sni3')
        alt_calls = [c for c in probe.calls if c[1] is not None]
        self.assertEqual(len(alt_calls), self.wp.SNI_TRIAL_CANDIDATES * len(self.wp.SNI_FALLBACKS))
        self.assertNotIn('sni', st)

    def fm_probe(self, works_with):
        calls = []

        def probe(mode, host, port, cred, own_ip, sni=None, finalmask=None):
            calls.append((host, sni, finalmask))
            ok = bool(finalmask) and finalmask.get('fm_tcp_fragment_lengths') == works_with
            return {'host': host, 'port': port, 'status': 'verified' if ok else 'failed', 'ms': 40, 'kbps': 900,
                    'checks': '4/4'}
        probe.calls = calls
        return probe

    def test_fm_search_finds_a_preset_and_keeps_using_it(self):
        probe = self.fm_probe('10-30')
        st = self.run_search({'mode': 'masque_h2', 'credentials': self.CRED_MQ, 'want': 2, 'max_attempts': 20,
                              'fm_search': True, 'finalmask': {'fm_udp_type': 'none', 'finalmask': '{"tcp": []}'}},
                             probe, 'fm1')
        self.assertEqual(st['fm'], 'fragment 10-30 / 5-10')
        self.assertEqual(st['verified'], 2)
        self.assertTrue(all(r['fm'] == 'fragment 10-30 / 5-10' for r in st['results']))
        self.assertEqual(st['results'][0]['fm_values']['fm_tcp_fragment_delays'], '5-10')
        self.assertNotIn('name', st['results'][0]['fm_values'])
        # the raw JSON of the node must not override the preset, other rows stay
        used = [c[2] for c in probe.calls if c[2] and c[2].get('fm_tcp_type') == 'fragment']
        self.assertTrue(used)
        self.assertTrue(all('finalmask' not in fm and fm['fm_udp_type'] == 'none' for fm in used))
        # once found, the unmasked probe is not tried again
        self.assertEqual([c for c in probe.calls[len(self.wp.FM_PRESETS) + 1:] if c[2].get('fm_tcp_type') != 'fragment'], [])

    def test_fm_search_is_for_http2_only_and_off_by_default(self):
        probe = self.fm_probe('100-200')
        st = self.run_search({'mode': 'masque_h3', 'credentials': self.CRED_MQ, 'want': 1, 'max_attempts': 5,
                              'fm_search': True}, probe, 'fm2')
        self.assertEqual(st['verified'], 0)
        self.assertTrue(all(c[2] is None for c in probe.calls))
        st = self.run_search({'mode': 'masque_h2', 'credentials': self.CRED_MQ, 'want': 1, 'max_attempts': 5},
                             self.fm_probe('100-200'), 'fm3')
        self.assertEqual(st['verified'], 0)
        self.assertNotIn('fm', st)

    def test_fm_search_tries_only_a_few_candidates(self):
        probe = self.fm_probe('none')
        st = self.run_search({'mode': 'masque_h2', 'credentials': self.CRED_MQ, 'want': 1, 'max_attempts': 10,
                              'fm_search': True}, probe, 'fm4')
        masked = [c for c in probe.calls if c[2]]
        self.assertEqual(len(masked), self.wp.FM_TRIAL_CANDIDATES * len(self.wp.FM_PRESETS))
        self.assertNotIn('fm', st)

    def test_fm_presets_become_a_tcp_fragment_mask(self):
        for preset in self.wp.FM_PRESETS:
            fm = {k: v for k, v in preset.items() if k != 'name'}
            mask = self.wp.build_finalmask(fm, 'tcp')
            self.assertEqual(mask['tcp'][0]['type'], 'fragment')
            st = mask['tcp'][0]['settings']
            self.assertEqual(st['packets'], preset['fm_tcp_fragment_packets'])
            self.assertEqual(','.join(st['lengths']), preset['fm_tcp_fragment_lengths'])
            self.assertEqual(','.join(st['delays']), preset['fm_tcp_fragment_delays'])

    def test_recheck_uses_the_sni_that_worked(self):
        probe = self.sni_probe('www.cloudflare.com')
        st = self.run_search({'mode': 'masque_h3', 'credentials': self.CRED_MQ,
                              'endpoints': [{'host': '162.159.198.2', 'port': 443, 'sni': 'www.cloudflare.com'}]},
                             probe, 'sni4')
        self.assertEqual(st['verified'], 1)
        self.assertEqual(probe.calls, [('162.159.198.2', 'www.cloudflare.com')])

    def test_validate_rejects_a_bad_sni_in_a_recheck(self):
        req = {'mode': 'masque_h3', 'credentials': self.CRED_MQ,
               'endpoints': [{'host': '162.159.198.2', 'port': 443, 'sni': 'a b;c'}]}
        with self.assertRaises(ValueError):
            self.wp.validate_request(req)

    def test_other_sni_keeps_certificate_verification(self):
        calls = []

        class Inst:
            port = 1
            def __init__(self, cfg):
                calls.append(cfg)
            def close(self):
                pass
            def wait_ready(self):
                return False
        orig = self.wp.XrayInstance
        self.wp.XrayInstance = Inst
        try:
            self.wp.probe_endpoint('masque_h3', '162.159.198.2', 443,
                                   {'masque_warp_private_key': 'k' * 44, 'masque_warp_address': '172.16.0.2/32'},
                                   None, sni='www.cloudflare.com')
        finally:
            self.wp.XrayInstance = orig
        tls = calls[0]['outbounds'][0]['streamSettings']['tlsSettings']
        self.assertEqual(tls['serverName'], 'www.cloudflare.com')
        self.assertEqual(tls['verifyPeerCertByName'], 'consumer-masque.cloudflareclient.com')

    def probe_instance(self, answers, mode='masque_h3', exclude=(), only=()):
        from unittest.mock import patch
        wp = self.wp

        class Inst:
            port = 1

            def wait_ready(self):
                return True

        calls = []

        def http(url, port, timeout):
            calls.append(url)
            a = answers(url, len(calls))
            if isinstance(a, Exception):
                raise a
            return a

        with patch.object(wp, 'http_get', http), patch.object(wp, 'LATE_CHECK_DELAY', 0.01):
            return wp._probe_instance(Inst(), mode, {'host': '162.159.198.2', 'port': 443}, '93.1.1.1', exclude, only), calls

    def test_excluded_node_stops_the_probe_at_the_first_answer(self):
        trace = b'ip=104.28.1.1\nwarp=on\ncolo=DME\n'
        res, calls = self.probe_instance(lambda url, n: (trace, 0.2), exclude=('DME',))
        self.assertEqual((res['status'], res['reason'], res['colo']), ('failed', 'node DME excluded', 'DME'))
        self.assertTrue(res['excluded'])
        self.assertEqual(len(calls), 1)  # no confirmation requests were spent
        res, calls = self.probe_instance(lambda url, n: (trace, 0.2) if 'trace' in url else (b'x' * 300000, 1.0),
                                         exclude=('FRA',))
        self.assertEqual(res['status'], 'verified')

    def test_exit_country_is_taken_from_the_trace(self):
        trace = b'ip=104.28.1.1\nwarp=on\ncolo=FRA\nloc=RU\n'
        res, _ = self.probe_instance(lambda url, n: (trace, 0.2) if 'trace' in url else (b'x' * 300000, 1.0))
        self.assertEqual((res['colo'], res['loc']), ('FRA', 'RU'))
        res, _ = self.probe_instance(lambda url, n: (b'ip=104.28.1.1\nwarp=on\ncolo=FRA\nloc=<x>\n', 0.2)
                                     if 'trace' in url else (b'x' * 300000, 1.0))
        self.assertNotIn('loc', res)

    def test_connection_cut_after_the_first_answer_is_marked_torn(self):
        def answers(url, n):
            if n == 1:
                return b'ip=104.28.1.1\nwarp=on\ncolo=FRA\n', 0.2
            return OSError('timed out')
        res, _ = self.probe_instance(answers)
        self.assertEqual(res['status'], 'unstable')
        self.assertTrue(res['torn'])
        good, _ = self.probe_instance(lambda url, n: (b'ip=104.28.1.1\nwarp=on\n', 0.2) if 'trace' in url
                                      else (b'x' * 300000, 1.0))
        self.assertEqual(good['status'], 'verified')
        self.assertNotIn('torn', good)

    def test_validate_rejects_bad_node_codes(self):
        with self.assertRaises(ValueError):
            self.wp.validate_request({'mode': 'masque_h3', 'credentials': self.CRED_MQ, 'exclude_colos': ['dme;']})

    def test_tunnel_cut_shortly_after_a_good_result_is_not_verified(self):
        seen = {'late': 0}

        def answers(url, n):
            if 'trace' in url and n > 5:  # the request after the confirmation round
                seen['late'] += 1
                return OSError('timed out')
            return (b'ip=104.28.1.1\nwarp=on\n', 0.2) if 'trace' in url else (b'x' * 300000, 1.0)
        res, calls = self.probe_instance(answers)
        self.assertEqual(res['status'], 'unstable')
        self.assertTrue(res['checks'].startswith('4/4, cut after'))
        self.assertTrue(res['torn'])
        self.assertEqual(seen['late'], 1)

    def test_node_filter_resolution(self):
        r = self.wp.resolve_node_filter
        colos = {'HEL': ['FI', 'Helsinki'], 'ARN': ['SE', 'Stockholm'], 'DME': ['RU', 'Moscow'], 'SVO': ['RU', 'Moscow']}
        self.assertEqual(r(colos), ((), ()))
        self.assertEqual(r(colos, countries_skip=('RU',)), (('DME', 'SVO'), ()))
        self.assertEqual(r(colos, exclude=('HEL',), countries_skip=('RU',)), (('DME', 'HEL', 'SVO'), ()))
        self.assertEqual(r(colos, countries_only=('FI', 'SE')), ((), ('ARN', 'HEL')))
        self.assertEqual(r(colos, only=('HEL',), countries_only=('SE',)), ((), ('ARN', 'HEL')))
        self.assertEqual(r(colos, only=('HEL', 'DME'), exclude=('DME',)), (('DME',), ('HEL',)))
        with self.assertRaises(ValueError):
            r(colos, countries_only=('ZZ',))
        with self.assertRaises(ValueError):
            r(colos, only=('DME',), exclude=('DME',))

    def test_search_with_impossible_country_filter_fails_early(self):
        with self.assertRaises(ValueError):
            self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 1, 'max_attempts': 5,
                             'include_countries': ['ZZ']}, self.fake_probe(set()), 'cc')

    def test_validate_request_checks_the_new_filters(self):
        base = {'mode': 'wg', 'credentials': self.CRED_WG}
        self.wp.validate_request(dict(base, include_colos=['HEL'], include_countries=['FI'], exclude_countries=['RU']))
        for key, bad in (('include_colos', ['hel1']), ('include_countries', ['FIN']), ('exclude_countries', 'RU')):
            with self.assertRaises(ValueError):
                self.wp.validate_request(dict(base, **{key: bad}))

    def test_only_filter_stops_the_probe_at_the_first_answer(self):
        trace = b'ip=104.28.1.1\nwarp=on\ncolo=FRA\nloc=DE\n'
        res, calls = self.probe_instance(lambda url, n: (trace, 0.2), only=('HEL',))
        self.assertEqual((res['status'], res['reason']), ('failed', 'node FRA excluded'))
        self.assertEqual(len(calls), 1)
        res, _ = self.probe_instance(lambda url, n: (trace, 0.2) if 'trace' in url else (b'x' * 300000, 1.0),
                                     only=('FRA', 'HEL'))
        self.assertEqual(res['status'], 'verified')

    def test_search_drops_and_counts_excluded_nodes(self):
        def probe(mode, host, port, cred, own_ip, exclude=()):
            return {'host': host, 'port': port, 'status': 'verified', 'ms': 30, 'kbps': 900, 'checks': '4/4',
                    'colo': 'DME' if port % 2 else 'FRA'}
        st = self.run_search({'mode': 'masque_h3', 'credentials': self.CRED_MQ, 'want': 2, 'max_attempts': 40,
                              'exclude_colos': ['DME']}, probe, 'ex1')
        self.assertEqual(st['verified'], 2)
        self.assertTrue(all(r['colo'] == 'FRA' for r in st['results']))
        self.assertGreater(st['excluded']['DME'], 0)

    def test_search_respects_the_attempt_limit(self):
        def never(mode, host, port, cred, own_ip):
            return {'host': host, 'port': port, 'status': 'failed'}
        st = self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 5, 'max_attempts': 12}, never)
        self.assertEqual((st['attempts'], st['verified']), (12, 0))
        self.assertEqual(st['results'], [])
        self.assertEqual(len(self.cache.bad_keys()), 12)

    def test_failed_endpoints_are_skipped_by_the_next_search(self):
        def never(mode, host, port, cred, own_ip):
            return {'host': host, 'port': port, 'status': 'failed'}
        first = self.fake_probe(set())
        self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 1, 'max_attempts': 10}, never, 'a')
        tried = set(self.cache.bad_keys())
        again = self.fake_probe(set())
        self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 1, 'max_attempts': 10}, again, 'b')
        keys = {self.wp.candidate_key('wg', h, p) for h, p in again.calls}
        self.assertEqual(keys & tried, set())

    def test_cancel_flag_stops_the_search(self):
        open(os.path.join(self.tmp, 'c.cancel'), 'w').close()
        st = self.run_search({'mode': 'wg', 'credentials': self.CRED_WG, 'want': 5, 'max_attempts': 50},
                             self.fake_probe(set()), 'c')
        self.assertEqual(st['status'], 'cancelled')
        self.assertEqual(st['attempts'], 0)

    def test_recheck_lists_failures_and_drops_them_from_the_good_list(self):
        self.cache.remember_good('wg', [{'host': '8.6.112.1', 'port': 500, 'status': 'verified', 'ms': 80},
                                         {'host': '8.6.112.2', 'port': 500, 'status': 'verified', 'ms': 90}])
        probe = self.fake_probe({('8.6.112.1', 500)})
        probe.calls.append(('x', 0))
        probe.calls.append(('y', 0))   # so that the stand-in's every-third rule stays off for the two calls
        req = {'mode': 'wg', 'credentials': self.CRED_WG, 'endpoints': [
            {'host': '8.6.112.1', 'port': 500}, {'host': '8.6.112.2', 'port': 500}]}
        st = self.run_search(req, probe, 'r')
        by = {r['host']: r['status'] for r in st['results']}
        self.assertEqual(by['8.6.112.1'], 'verified')
        self.assertEqual(by['8.6.112.2'], 'failed')
        self.assertEqual([r['host'] for r in self.cache.good('wg')], ['8.6.112.1'])

    def test_request_validation(self):
        ok = {'mode': 'wg', 'credentials': self.CRED_WG}
        self.assertEqual(self.wp.validate_request(ok), ok)
        for bad in ({'mode': 'x', 'credentials': {}}, {'mode': 'wg', 'credentials': {}},
                    {'mode': 'masque_h3', 'credentials': {'masque_warp_private_key': 'k'}},
                    {'mode': 'wg', 'credentials': self.CRED_WG, 'endpoints': [{'host': 'a;b', 'port': 1}]}):
            with self.assertRaises(ValueError):
                self.wp.validate_request(bad)

    def test_full_pipeline_with_a_fake_xray(self):
        import subprocess
        import textwrap
        fake = os.path.join(self.tmp, 'fakexray.py')
        with open(fake, 'w') as fh:
            fh.write(textwrap.dedent('''\
                #!/usr/bin/env python3
                import json, sys
                from http.server import BaseHTTPRequestHandler, HTTPServer
                cfg = json.load(open(sys.argv[sys.argv.index("-c") + 1]))
                good = cfg["outbounds"][0]["settings"]["peers"][0]["endpoint"] == "8.6.112.9:500"
                class H(BaseHTTPRequestHandler):
                    def log_message(self, *a): pass
                    def do_GET(self):
                        if not good:
                            self.send_response(502); self.end_headers(); return
                        body = b"ip=104.1.1.1\\nwarp=on\\n" if "trace" in self.path else b"x" * 300000
                        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers()
                        self.wfile.write(body)
                HTTPServer(("127.0.0.1", cfg["inbounds"][0]["port"]), H).serve_forever()
                '''))
        os.chmod(fake, 0o755)
        wp = self.wp
        old = (wp.XRAY_BIN, wp.TRACE_URL, wp.DOWNLOAD_URL, wp.CONFIRM_REQUESTS)
        wp.XRAY_BIN, wp.TRACE_URL, wp.DOWNLOAD_URL = fake, 'http://t.example/cdn-cgi/trace', 'http://t.example/dl'
        try:
            good = wp.probe_endpoint('wg', '8.6.112.9', 500, self.CRED_WG, '93.1.1.1')
            bad = wp.probe_endpoint('wg', '8.6.112.8', 500, self.CRED_WG, '93.1.1.1')
            leak = wp.probe_endpoint('wg', '8.6.112.9', 500, self.CRED_WG, '104.1.1.1')
        finally:
            wp.XRAY_BIN, wp.TRACE_URL, wp.DOWNLOAD_URL, wp.CONFIRM_REQUESTS = old
        self.assertEqual((good['status'], good['checks']), ('verified', '4/4'))
        self.assertGreater(good['kbps'], 0)
        self.assertEqual(bad['status'], 'failed')
        self.assertEqual(leak['status'], 'failed')


class TestWarpSources(unittest.TestCase):
    """External endpoint lists: parsing, filtering, caching, ordering."""

    SAMPLE = ('[{"ip": "8.6.112.0", "ports": [939, 945, 987]}, {"ip": "8.6.112.1", "ports": [500]}, '
              '{"ip": "93.184.216.34", "ports": [2408]}, {"ip": "10.0.0.1", "ports": [500]}]')

    def setUp(self):
        import tempfile
        import warp_probe
        self.wp = warp_probe
        warp_probe.fetch_colos = lambda: {}      # no network in tests
        self.tmp = tempfile.mkdtemp()
        self.cache = warp_probe.Cache(os.path.join(self.tmp, 'cache.json'))

    def test_parse_collector_json(self):
        got = self.wp.parse_endpoint_list(self.SAMPLE)
        self.assertEqual(got[:4], [('8.6.112.0', 939), ('8.6.112.0', 945), ('8.6.112.0', 987), ('8.6.112.1', 500)])
        self.assertIn(('93.184.216.34', 2408), got)
        self.assertNotIn(('10.0.0.1', 500), got)          # private address is never valid

    def test_parse_other_shapes(self):
        wp = self.wp
        self.assertEqual(wp.parse_endpoint_list('{"8.34.70.3": [500, 4500]}'), [('8.34.70.3', 500), ('8.34.70.3', 4500)])
        self.assertEqual(wp.parse_endpoint_list('["162.159.192.1:2408", "bad", "162.159.192.1:2408"]'),
                         [('162.159.192.1', 2408)])
        self.assertEqual(wp.parse_endpoint_list('8.6.112.4:500\n188.114.97.2:1701 # note\n'),
                         [('8.6.112.4', 500), ('188.114.97.2', 1701)])
        self.assertEqual(wp.parse_endpoint_list('| 8.35.211.9 | 500, 939 |'), [('8.35.211.9', 500), ('8.35.211.9', 939)])
        self.assertEqual(wp.parse_endpoint_list('<html>nothing</html>'), [])
        self.assertEqual(wp.parse_endpoint_list('[{"ip": "8.6.112.0", "ports": [0, 70000, "x"]}]'), [])

    def test_large_list_is_not_truncated_early(self):
        import json
        rows = [{'ip': '8.6.112.%d' % i, 'ports': [500 + n for n in range(1, 60)]} for i in range(256)]
        self.assertEqual(len(self.wp.parse_endpoint_list(json.dumps(rows))), 256 * 59)

    def test_cloudflare_filter_and_report(self):
        entries, report = self.wp.load_sources(['https://a.example/x.json'], self.cache, fetch=lambda u: self.SAMPLE)
        self.assertNotIn(('93.184.216.34', 2408), entries)
        self.assertIn(('8.6.112.0', 939), entries)
        self.assertEqual((report[0]['status'], report[0]['count'], report[0]['skipped']), ('ok', 5, 1))
        self.assertEqual(report[0]['accepted'], 4)
        entries, report = self.wp.load_sources(['https://a.example/x.json'], self.cache, any_address=True,
                                               fetch=lambda u: self.SAMPLE)
        self.assertIn(('93.184.216.34', 2408), entries)
        self.assertEqual(report[0]['skipped'], 0)

    def test_cache_stale_and_error(self):
        calls = []

        def ok(url):
            calls.append(url)
            return self.SAMPLE

        def down(url):
            raise OSError('network is down')

        url = 'https://a.example/x.json'
        self.wp.load_sources([url], self.cache, fetch=ok, now=1000)
        _, rep = self.wp.load_sources([url], self.cache, fetch=ok, now=2000)
        self.assertEqual((rep[0]['status'], len(calls)), ('cached', 1))
        entries, rep = self.wp.load_sources([url], self.cache, fetch=down, now=1000 + self.wp.SOURCE_TTL + 1)
        self.assertEqual(rep[0]['status'], 'stale')
        self.assertIn(('8.6.112.0', 939), entries)
        entries, rep = self.wp.load_sources(['https://b.example/y'], self.cache, fetch=down)
        self.assertEqual((entries, rep[0]['status']), ([], 'error'))

    def test_only_https_sources(self):
        with self.assertRaises(ValueError):
            self.wp.fetch_source('http://a.example/x.json')
        with self.assertRaises(ValueError):
            self.wp.fetch_source('file:///etc/passwd')

    def test_extra_entries_come_after_documented_before_random(self):
        import itertools
        import random
        extra = [('8.6.112.0', 939), ('8.6.112.0', 939), ('8.6.112.1', 500)]
        got = list(itertools.islice(self.wp.generate_candidates('wg', rng=random.Random(1), extra=extra), 30))
        n = len(self.wp.DOCUMENTED['wg'])
        self.assertEqual(got[n:n + 2], [('8.6.112.0', 939), ('8.6.112.1', 500)])
        self.assertEqual(len(set(got)), len(got))


    def test_masque_uses_hosts_of_lists_on_default_port(self):
        import random
        seen = []

        def probe(mode, host, port, cred, own_ip):
            seen.append((host, port))
            return {'host': host, 'port': port, 'status': 'failed'}

        req = {'mode': 'masque_h2', 'credentials': {}, 'max_attempts': 4, 'want': 5, 'sources': ['https://a.example/x'],
               'ignore_cache': True}
        search = self.wp.Search(req, os.path.join(self.tmp, 's.json'), self.cache, probe=probe,
                                rng=random.Random(3), fetch=lambda u: self.SAMPLE)
        search.run()
        self.assertEqual(search.state['sources'][0]['status'], 'ok')
        # two documented defaults first, then list hosts on 443 only (8.6.112.0 and .1)
        self.assertEqual(sorted(seen[2:4]), [('8.6.112.0', 443), ('8.6.112.1', 443)])
        self.assertEqual(self.wp.masque_hosts([('1.1.1.1', 500), ('1.1.1.1', 939)]), [('1.1.1.1', 443)])

    def test_wide_ranges_only_when_asked(self):
        import itertools
        import random
        plain = list(itertools.islice(self.wp.generate_candidates('masque_h3', rng=random.Random(1)), 300))
        wide = list(itertools.islice(self.wp.generate_candidates('masque_h3', rng=random.Random(1), wide=True), 300))
        self.assertFalse(any(not h.startswith(('162.159.198.', '162.159.199.')) for h, _ in plain))
        self.assertTrue(any(h.startswith('162.159.192.') for h, _ in wide))
        self.assertTrue(all(p in self.wp.MASQUE_PORTS for _, p in wide))
        self.assertEqual(self.wp.generate_candidates.__defaults__[-1], False)

    def test_read_log_hides_keys_and_keeps_tail(self):
        path = os.path.join(self.tmp, 'x.log')
        with open(path, 'w') as fh:
            fh.write('\n'.join(['line %d' % i for i in range(30)] + ['secret ' + 'K' * 60, '']))
        got = self.wp.read_log(path, {'masque_warp_private_key': 'K' * 60}, lines=5)
        self.assertEqual(got, ['line 26', 'line 27', 'line 28', 'line 29'])
        self.assertEqual(self.wp.read_log(os.path.join(self.tmp, 'none'), {}), [])
        mq = {'masque_warp_private_key': 'K' * 60, 'masque_warp_address': ['172.16.0.2/32'], 'masque_warp_public_key': 'E' * 90}
        wg = {'wg_secret_key': 'S' * 43 + '=', 'wg_public_key': 'P' * 43 + '=', 'wg_address': ['172.16.0.2/32']}
        cfg = self.wp.build_xray_config('masque_h3', '162.159.198.2', 443, mq, 1, '/tmp/l')
        self.assertEqual(cfg['log'], {'loglevel': 'debug', 'error': '/tmp/l'})
        self.assertEqual(self.wp.build_xray_config('wg', '8.6.112.5', 500, wg, 1)['log'], {'loglevel': 'none'})

    def test_masque_confirm_and_stalled_flows(self):
        from unittest.mock import patch
        wp = self.wp

        class Inst:
            port = 1

        def good(url, port, timeout):
            if 'trace' in url:
                return b'ip=104.28.1.1\nwarp=on\n', 0.2
            return b'x' * 300000, 1.0

        def stalled(url, port, timeout):
            raise OSError('timed out')

        with patch.object(wp, 'http_get', good):
            ok, times, kbps = wp._masque_confirm(Inst(), '93.1.1.1', [0.2])
        self.assertEqual((ok, len(times)), (4, 4))
        self.assertGreater(kbps, 0)
        with patch.object(wp, 'http_get', stalled):
            ok, times, kbps = wp._masque_confirm(Inst(), '93.1.1.1', [0.2])
        self.assertEqual((ok, times, kbps), (1, [0.2], None))

    def test_finalmask_of_the_node_in_probe_config(self):
        wp = self.wp
        mq = {'masque_warp_private_key': 'K' * 60, 'masque_warp_address': ['172.16.0.2/32'], 'masque_warp_public_key': 'E' * 90}
        fm = {'fm_tcp_type': 'fragment', 'fm_tcp_fragment_packets': 'tlshello', 'fm_tcp_fragment_lengths': '100-200',
              'fm_tcp_fragment_delays': '10-20', 'fm_udp_type': 'salamander', 'fm_udp_salamander_password': 'pw',
              'finalmask': ''}
        tcp = wp.build_xray_config('masque_h2', '162.159.198.2', 443, mq, 1, None, fm)['outbounds'][0]['streamSettings']
        self.assertEqual(tcp['finalmask'], {'tcp': [{'type': 'fragment', 'settings': {
            'packets': 'tlshello', 'lengths': ['100-200'], 'delays': ['10-20']}}]})
        udp = wp.build_xray_config('masque_h3', '162.159.198.2', 443, mq, 1, None, fm)['outbounds'][0]['streamSettings']
        self.assertEqual(udp['finalmask'], {'udp': [{'type': 'salamander', 'settings': {'password': 'pw'}}]})
        raw = dict(fm, finalmask='{"tcp": [{"type": "fragment", "settings": {"packets": "1-3"}}]}')
        self.assertEqual(wp.build_finalmask(raw, 'tcp')['tcp'][0]['settings'], {'packets': '1-3'})
        self.assertIsNone(wp.build_finalmask(dict(fm, finalmask='{broken'), 'tcp'))
        self.assertIsNone(wp.build_finalmask({'fm_tcp_type': 'none'}, 'tcp'))
        self.assertNotIn('finalmask', wp.build_xray_config('masque_h2', '1.1.1.1', 443, mq, 1)['outbounds'][0]['streamSettings'])
        self.assertEqual(wp.build_xray_config('masque_h2', '1.1.1.1', 443, mq, 1)['outbounds'][0]['targetStrategy'], 'UseIPv4')
        self.assertNotIn('finalmask', wp.build_xray_config('wg', '1.1.1.1', 500, {'wg_secret_key': 'S', 'wg_public_key': 'P'}, 1, None, fm)['outbounds'][0].get('streamSettings', {}))
        ok = {'mode': 'masque_h2', 'credentials': {'masque_warp_private_key': 'K', 'masque_warp_address': 'a'}, 'finalmask': fm}
        wp.validate_request(ok)
        for bad in ({'bad key': 'x'}, {'fm_x': 5}, {'fm_x': 'y' * 5000}):
            with self.assertRaises(ValueError):
                wp.validate_request(dict(ok, finalmask=bad))

    def test_colo_countries_cached_with_fallback(self):
        wp = self.wp
        calls = []

        def fetch():
            calls.append(1)
            return {'KJA': ['RU', 'Krasnoyarsk']}

        got = wp.load_colos(self.cache, fetch, now=1000)
        self.assertEqual(got, {'KJA': ['RU', 'Krasnoyarsk']})
        wp.load_colos(self.cache, fetch, now=2000)
        self.assertEqual(len(calls), 1)                 # cached
        def down():
            raise OSError('offline')
        late = 1000 + wp.COLOS_TTL + 1
        got = wp.load_colos(self.cache, down, now=late)
        self.assertEqual(got['KJA'], ['RU', 'Krasnoyarsk'])     # stale copy kept
        self.assertEqual(got['HEL'], ['FI', 'Helsinki'])        # plus the built-in table
        empty = wp.Cache(os.path.join(self.tmp, 'other.json'))
        self.assertEqual(wp.load_colos(empty, down)['DME'][0], 'RU')

    def test_results_carry_country_of_the_data_center(self):
        import random
        wp = self.wp

        def probe(mode, host, port, cred, own_ip):
            return {'host': host, 'port': port, 'status': 'verified', 'ms': 50, 'kbps': 900, 'checks': '4/4',
                    'colo': 'HEL' if port == 500 else 'ZZZ'}

        req = {'mode': 'wg', 'credentials': {}, 'max_attempts': 2, 'want': 5, 'ignore_cache': True,
               'endpoints': [{'host': '8.6.112.1', 'port': 500}, {'host': '8.6.112.2', 'port': 501}]}
        search = wp.Search(req, os.path.join(self.tmp, 's.json'), self.cache, probe=probe, rng=random.Random(1),
                           colo_fetch=lambda: {'HEL': ['FI', 'Helsinki']})
        search.run()
        by = {r['port']: r for r in search.state['results']}
        self.assertEqual((by[500]['cc'], by[500]['city']), ('FI', 'Helsinki'))
        self.assertNotIn('cc', by[501])


def _pb_varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _pb_len(field, payload):
    return _pb_varint(field << 3 | 2) + _pb_varint(len(payload)) + payload


def _pb_int(field, value):
    return _pb_varint(field << 3) + _pb_varint(value)


class TestGeodata(unittest.TestCase):
    """geodata.py reads geosite.dat / geoip.dat without a protobuf package."""

    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        dom = lambda t, v, attrs=(): (  # noqa: E731
            _pb_int(1, t) + _pb_len(2, v.encode()) +
            b''.join(_pb_len(3, _pb_len(1, a.encode())) for a in attrs))
        site = _pb_len(1, _pb_len(1, b'RU-BLOCKED') +
                       _pb_len(2, dom(2, 'rutracker.org')) +
                       _pb_len(2, dom(3, 'www.example.ru', ['ads'])) +
                       _pb_len(2, dom(0, 'tor'))) + \
            _pb_len(1, _pb_len(1, b'CATEGORY-ADS-ALL') + _pb_len(2, dom(2, 'ads.example')))
        cidr = lambda ip, pre: _pb_len(2, _pb_len(1, ip) + _pb_int(2, pre))  # noqa: E731
        geoip = _pb_len(1, _pb_len(1, b'PRIVATE') +
                        cidr(bytes([10, 0, 0, 0]), 8) + cidr(bytes([192, 168, 0, 0]), 16)) + \
            _pb_len(1, _pb_len(1, b'RU'))
        with open(os.path.join(self.tmp.name, 'geosite.dat'), 'wb') as f:
            f.write(site)
        with open(os.path.join(self.tmp.name, 'geoip.dat'), 'wb') as f:
            f.write(geoip)
        import geodata
        self.geodata = geodata
        patcher = patch.object(geodata, 'ASSET_DIR', self.tmp.name)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_tags_with_counts(self):
        res = self.geodata.list_tags('site')
        self.assertEqual(res['tags'], [{'tag': 'category-ads-all', 'count': 1},
                                       {'tag': 'ru-blocked', 'count': 3}])
        ip = self.geodata.list_tags('ip')
        self.assertEqual(ip['tags'], [{'tag': 'private', 'count': 2}, {'tag': 'ru', 'count': 0}])

    def test_site_entries_types_attrs_and_paging(self):
        res = self.geodata.list_entries('site', 'ru-blocked')
        self.assertEqual(res['total'], 3)
        self.assertEqual([(r['type'], r['value']) for r in res['rows']],
                         [('domain', 'rutracker.org'), ('full', 'www.example.ru'), ('keyword', 'tor')])
        self.assertEqual(res['rows'][1]['attrs'], ['ads'])
        res = self.geodata.list_entries('site', 'RU-BLOCKED@ads', offset=1, limit=1)
        self.assertEqual(res['total'], 3)
        self.assertEqual(len(res['rows']), 1)
        self.assertEqual(res['rows'][0]['value'], 'www.example.ru')

    def test_search_filters_and_counts(self):
        res = self.geodata.list_entries('site', 'ru-blocked', query='RU')
        self.assertEqual(res['total'], 2)

    def test_ip_entries(self):
        res = self.geodata.list_entries('ip', 'private')
        self.assertEqual([r['value'] for r in res['rows']], ['10.0.0.0/8', '192.168.0.0/16'])

    def test_unknown_tag_and_missing_file(self):
        self.assertEqual(self.geodata.list_entries('site', 'nope')['status'], 'error')
        os.remove(os.path.join(self.tmp.name, 'geoip.dat'))
        with self.assertRaises(self.geodata.DatError):
            self.geodata.list_tags('ip')

    def test_main_rejects_bad_input(self):
        import io
        from contextlib import redirect_stdout
        for argv in (['g', 'entries', 'site', 'a;b'], ['g', 'entries', 'site', 'ok', 'a b'],
                     ['g', 'tags', 'dns'], ['g']):
            buf = io.StringIO()
            with redirect_stdout(buf):
                self.geodata.main(argv)
            self.assertEqual(json.loads(buf.getvalue())['status'], 'error', argv)

    def test_truncated_data_is_an_error_not_a_crash(self):
        with open(os.path.join(self.tmp.name, 'geosite.dat'), 'wb') as f:
            f.write(b'\x0a\xff\x01abc')
        with self.assertRaises(self.geodata.DatError):
            self.geodata.list_tags('site')


class TestDebugInfo(unittest.TestCase):
    """The support bundle must never leak keys, UUIDs or server addresses."""

    @classmethod
    def setUpClass(cls):
        import debug_info
        cls.d = debug_info

    CONFIG = {
        'dns': {'servers': [{'address': '8.8.8.8'}], 'tag': 'dns-out'},
        'outbounds': [{
            'tag': 'node_1',
            'settings': {
                'address': 'secret-server.example.com', 'port': 443,
                'users': [{'id': '11111111-2222-3333-4444-555555555555', 'flow': 'xtls-rprx-vision'}],
                'secretKey': 'SECRETKEYVALUE', 'peers': [{'publicKey': 'PUBKEYVALUE', 'endpoint': '203.0.113.9:2408'}],
            },
            'streamSettings': {
                'security': 'reality',
                'realitySettings': {'publicKey': 'REALPUB', 'shortId': 'abcd1234', 'serverName': 'www.example.org',
                                    'password': 'hunter2'},
            },
        }],
        'routing': {'rules': [{'ip': ['8.8.4.4'], 'outboundTag': 'node_1'}]},
    }

    def test_secrets_are_masked_in_config(self):
        text = json.dumps(self.d.mask_json(self.CONFIG))
        for leaked in ('11111111-2222', 'SECRETKEYVALUE', 'PUBKEYVALUE', 'REALPUB', 'abcd1234',
                       'hunter2', 'secret-server.example.com', '203.0.113.9'):
            self.assertNotIn(leaked, text)

    def test_useful_structure_survives(self):
        masked = self.d.mask_json(self.CONFIG)
        self.assertEqual(masked['dns']['servers'][0]['address'], '8.8.8.8')
        self.assertEqual(masked['dns']['tag'], 'dns-out')
        self.assertEqual(masked['routing']['rules'][0]['ip'], ['8.8.4.4'])
        self.assertEqual(masked['outbounds'][0]['settings']['port'], 443)
        self.assertEqual(masked['outbounds'][0]['settings']['users'][0]['flow'], 'xtls-rprx-vision')
        self.assertEqual(masked['outbounds'][0]['streamSettings']['security'], 'reality')

    def test_mask_does_not_change_the_original(self):
        self.d.mask_json(self.CONFIG)
        self.assertEqual(self.CONFIG['outbounds'][0]['settings']['secretKey'], 'SECRETKEYVALUE')

    def test_log_lines_are_masked(self):
        line = 'from 203.0.113.55:4433 accepted user 11111111-2222-3333-4444-555555555555 password=hunter2'
        out = self.d.mask_text(line, ips=True)
        self.assertNotIn('11111111-2222', out)
        self.assertNotIn('hunter2', out)
        self.assertNotIn('113.55', out)
        self.assertIn('203.0.x.x', out)

    def test_ips_kept_in_free_text_by_default(self):
        self.assertIn('8.8.4.4', self.d.mask_text('dns 8.8.4.4 ok'))

    def test_report_is_built_without_a_router(self):
        # Every section must degrade to a message, never raise.
        report = self.d.build_report()
        for title in ('Versions', 'Service', 'Settings', 'config.json', 'error.log'):
            self.assertIn(title, report)


class TestServiceInfo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import service_info
        cls.si = service_info

    PS_HEAD = '  PID  PPID     ELAPSED COMMAND\n'

    def ps(self, *rows):
        return self.PS_HEAD + '\n'.join(rows) + '\n'

    def test_parse_etime_formats(self):
        p = self.si.parse_etime
        self.assertEqual(p('05:09'), 5 * 60 + 9)
        self.assertEqual(p('02:05:09'), 2 * 3600 + 5 * 60 + 9)
        self.assertEqual(p('3-02:05:09'), 3 * 86400 + 2 * 3600 + 5 * 60 + 9)
        self.assertIsNone(p('garbage'))
        self.assertIsNone(p(''))

    def test_human(self):
        h = self.si.human
        self.assertEqual(h(42), '42s')
        self.assertEqual(h(125), '2m')
        self.assertEqual(h(3 * 3600 + 5 * 60), '3h 5m')
        self.assertEqual(h(3 * 86400 + 4 * 3600), '3d 4h')

    def test_running_and_not_restarted(self):
        out = self.si.collect(self.ps(
            '  100     1  01:00:00 daemon: /usr/local/bin/xray[101] (daemon)',
            '  101   100  01:00:00 /usr/local/bin/xray run -c /usr/local/etc/xray/config.json'), 100)
        self.assertEqual(out['state'], 'running')
        self.assertEqual(out['uptime'], 3600)
        self.assertFalse(out['auto_restarted'])

    def test_young_child_means_automatic_restart(self):
        out = self.si.collect(self.ps(
            '  100     1  2-01:00:00 daemon: /usr/local/bin/xray[205] (daemon)',
            '  205   100     12:30 /usr/local/bin/xray run -c /usr/local/etc/xray/config.json'), 100)
        self.assertEqual(out['state'], 'running')
        self.assertTrue(out['auto_restarted'])
        self.assertEqual(out['uptime_text'], '12m')

    def test_small_difference_is_not_a_restart(self):
        out = self.si.collect(self.ps(
            '  100     1     01:00 daemon: /usr/local/bin/xray[101] (daemon)',
            '  101   100     00:55 /usr/local/bin/xray run -c /usr/local/etc/xray/config.json'), 100)
        self.assertFalse(out['auto_restarted'])

    def test_supervisor_without_child_is_restarting(self):
        out = self.si.collect(self.ps(
            '  100     1     05:00 daemon: /usr/local/bin/xray[] (daemon)'), 100)
        self.assertEqual(out['state'], 'restarting')

    def test_no_supervisor_means_stopped(self):
        self.assertEqual(self.si.collect(self.ps('  1     0  10:00 init'), 100)['state'], 'stopped')
        self.assertEqual(self.si.collect('', None)['state'], 'stopped')

    def test_foreign_child_is_ignored(self):
        out = self.si.collect(self.ps(
            '  100     1     05:00 daemon: /usr/local/bin/xray[] (daemon)',
            '  300   100     00:10 /bin/sh -c sleep 1'), 100)
        self.assertEqual(out['state'], 'restarting')


class TestPluginBackup(unittest.TestCase):
    """plugin_backup.sh in a throw-away root directory."""

    SCRIPT = os.path.join(SCRIPT_DIR, 'plugin_backup.sh')

    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = self.tmp.name
        self.env = dict(os.environ, XRAY_ROOT=self.root)
        for d in ('usr/local/opnsense/scripts/OPNsense/XrayClient', 'usr/local/opnsense/mvc/app/models/OPNsense/XrayClient',
                  'usr/local/etc/rc.d', 'conf', 'root'):
            os.makedirs(os.path.join(self.root, d))
        self.write('usr/local/opnsense/scripts/OPNsense/XrayClient/a.py', 'v1')
        self.write('usr/local/opnsense/mvc/app/models/OPNsense/XrayClient/M.xml', 'm1')
        self.write('usr/local/etc/rc.d/os-xray-client', 'rc1')
        self.write('conf/config.xml', 'cfg1')

    def write(self, rel, text):
        with open(os.path.join(self.root, rel), 'w') as handle:
            handle.write(text)

    def read(self, rel):
        with open(os.path.join(self.root, rel)) as handle:
            return handle.read()

    def run_script(self, *args):
        import subprocess
        return subprocess.run(['sh', self.SCRIPT] + list(args), capture_output=True, text=True, env=self.env)

    def backup(self):
        res = self.run_script('backup')
        self.assertEqual(res.returncode, 0, res.stderr)
        for line in res.stdout.splitlines():
            if line.startswith('BACKUP_DIR='):
                return line.split('=', 1)[1]
        self.fail('no BACKUP_DIR in: ' + res.stdout)

    def test_restore_brings_back_files_and_removes_new_ones(self):
        d = self.backup()
        self.write('usr/local/opnsense/scripts/OPNsense/XrayClient/a.py', 'v2')
        self.write('usr/local/opnsense/scripts/OPNsense/XrayClient/extra.py', 'new')
        self.assertEqual(self.run_script('restore', d).returncode, 0)
        self.assertEqual(self.read('usr/local/opnsense/scripts/OPNsense/XrayClient/a.py'), 'v1')
        self.assertFalse(os.path.exists(os.path.join(self.root, 'usr/local/opnsense/scripts/OPNsense/XrayClient/extra.py')))

    def test_config_xml_only_restored_on_request(self):
        d = self.backup()
        self.write('conf/config.xml', 'cfg2')
        self.run_script('restore', d)
        self.assertEqual(self.read('conf/config.xml'), 'cfg2')
        self.run_script('restore', d, 'config')
        self.assertEqual(self.read('conf/config.xml'), 'cfg1')

    def test_backup_is_private(self):
        d = self.backup()
        self.assertEqual(os.stat(d).st_mode & 0o777, 0o700)
        self.assertEqual(os.stat(os.path.join(d, 'config.xml')).st_mode & 0o777, 0o600)

    def test_fresh_install_has_nothing_to_back_up(self):
        import shutil
        for d in ('usr', 'conf'):
            shutil.rmtree(os.path.join(self.root, d))
        res = self.run_script('backup')
        self.assertEqual(res.returncode, 0)
        self.assertNotIn('BACKUP_DIR=', res.stdout)

    def test_only_the_newest_three_are_kept(self):
        base = os.path.join(self.root, 'root')
        for stamp in ('20260101-000001', '20260101-000002', '20260101-000003', '20260101-000004'):
            d = os.path.join(base, 'os-xray-client-backup-' + stamp)
            os.makedirs(d)
        self.backup()
        left = sorted(n for n in os.listdir(base) if n.startswith('os-xray-client-backup-'))
        self.assertEqual(len(left), 3)
        self.assertNotIn('os-xray-client-backup-20260101-000001', left)

    def test_restore_refuses_a_foreign_directory(self):
        res = self.run_script('restore', self.tmp.name)
        self.assertNotEqual(res.returncode, 0)
        self.assertEqual(self.read('usr/local/opnsense/scripts/OPNsense/XrayClient/a.py'), 'v1')

    def test_installer_wires_backup_and_rollback(self):
        inst = open(os.path.join(SCRIPT_DIR, '..', '..', '..', '..', '..', 'install.sh')).read()
        for needle in ('plugin_backup.sh', 'trap rollback_on_failure EXIT', 'MIGRATING=1', 'INSTALL_DONE=1'):
            self.assertIn(needle, inst)
        self.assertLess(inst.index('trap rollback_on_failure EXIT'), inst.index('cp -R "${SRC_DIR}/etc/"*'))


class TestTunGateway(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import tun_gateway
        cls.tg = tun_gateway

    XML = """<opnsense>
  <interfaces><lan><if>igb0</if></lan><opt3><if>tun_xray0</if><descr>XRAY</descr></opt3></interfaces>
  <OPNsense><Gateways>%s</Gateways></OPNsense>
</opnsense>"""

    def root(self, *gateways):
        import xml.etree.ElementTree as ET
        items = ''.join(
            '<gateway_item uuid="u%d"><name>%s</name><interface>%s</interface><gateway>%s</gateway>%s</gateway_item>'
            % (i, name, iface, addr, extra) for i, (name, iface, addr, extra) in enumerate(gateways))
        return ET.fromstring(self.XML % items)

    def test_matching_gateway_is_ok(self):
        r = self.tg.check(self.root(('XRAY_GW', 'opt3', '10.255.0.1', '')), 'tun_xray0', '10.255.0.1/30')
        self.assertEqual(r['status'], 'ok')
        self.assertEqual(r['interface'], 'opt3')
        self.assertTrue(r['gateways'][0]['ok'])

    def test_changed_subnet_is_a_mismatch(self):
        r = self.tg.check(self.root(('XRAY_GW', 'opt3', '10.255.0.1', '')), 'tun_xray0', '10.77.0.1/30')
        self.assertEqual(r['status'], 'mismatch')
        self.assertEqual(r['expected'], '10.77.0.1')
        self.assertFalse(r['gateways'][0]['ok'])

    def test_other_interfaces_and_disabled_gateways_are_ignored(self):
        r = self.tg.check(self.root(('WAN_GW', 'wan', '192.0.2.1', ''),
                                    ('OLD', 'opt3', '10.1.1.1', '<disabled>1</disabled>')),
                          'tun_xray0', '10.255.0.1/30')
        self.assertEqual(r['status'], 'no_gateway')

    def test_ipv6_gateway_is_ignored(self):
        r = self.tg.check(self.root(('GW6', 'opt3', 'fd00::1', '')), 'tun_xray0', '10.255.0.1/30')
        self.assertEqual(r['status'], 'no_gateway')

    def test_not_assigned_and_disabled(self):
        root = self.root()
        self.assertEqual(self.tg.check(root, 'tun_other0', '10.255.0.1/30')['status'], 'no_interface')
        self.assertEqual(self.tg.check(root, 'tun_xray0', '10.255.0.1/30', enabled=False)['status'], 'disabled')

    def test_legacy_gateways_section(self):
        import xml.etree.ElementTree as ET
        root = ET.fromstring('<opnsense><interfaces><opt1><if>tun_xray0</if></opt1></interfaces>'
                             '<gateways><gateway_item><name>G</name><interface>opt1</interface>'
                             '<gateway>10.255.0.1</gateway></gateway_item></gateways></opnsense>')
        self.assertEqual(self.tg.check(root, 'tun_xray0', '10.255.0.1/30')['status'], 'ok')


if __name__ == '__main__':
    unittest.main()
