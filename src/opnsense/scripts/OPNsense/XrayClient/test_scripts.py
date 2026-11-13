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
        value = self._resolve(path)
        return list(value) if value else []


def render_config(general_overrides=None, nodes=None, rules=None,
                  balancers=None, dns_servers=None):
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
                        masque_api_base='http://127.0.0.1:%d/v0a4471' % self.server.server_port)
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



if __name__ == '__main__':
    unittest.main()
