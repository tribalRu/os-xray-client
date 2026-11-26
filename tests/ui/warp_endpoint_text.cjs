const fs = require('fs'); const assert = require('assert');
const s = fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt', 'utf8');
const a = s.indexOf('        function warpEndpointText(host, port) {');
const b = s.indexOf('        // Flag emoji of a two letter country code');
assert(a > 0 && b > a);
const warpEndpointText = new Function(s.slice(a, b) + '; return warpEndpointText;')();
assert.strictEqual(warpEndpointText('8.6.112.5', 2408), '8.6.112.5:2408');
assert.strictEqual(warpEndpointText('2606:4700:d0::1', 2408), '[2606:4700:d0::1]:2408');
// the request and the "Use" button handle the family
assert(/data\.ipv6 = \$wrap\.find\('\.wp-v6'\)/.test(s));
assert(/\$\('#node\\\\\.wg_endpoint'\)\.val\(warpEndpointText\(r\.host, r\.port\)\)/.test(s));
console.log('warp endpoint text OK');
