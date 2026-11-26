const fs = require('fs'); const { JSDOM } = require('jsdom'); const assert = require('assert');
const s = fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt', 'utf8');
const a = s.indexOf('        function fillFragmentMask(data) {');
const b = s.indexOf('        function fillNodeDialog(data) {');
assert(a > 0 && b > a);
const dom = new JSDOM('<select id="node.fm_tcp_type"></select><select id="node.fm_tcp_fragment_packets"></select><input id="node.fm_tcp_fragment_max_split" value="9">', { runScripts: 'outside-only' });
const w = dom.window;
w.eval(fs.readFileSync(__dirname + '/node_modules/jquery/dist/jquery.js', 'utf8'));
const log = [];
w.eval('window.log = []; window.setSelectValue = function (el, v) { log.push(["select", el.attr("id"), v]); };' +
       'window.clearTokenizeField = function (sel) { log.push(["clear", sel]); };' +
       'window.fillTokenizeField = function (sel, v) { log.push(["fill", sel, v]); };');
w.eval(s.slice(a, b));
w.fillFragmentMask({ fm_tcp_type: 'fragment', fm_tcp_fragment_packets: 'tlshello', fm_tcp_fragment_lengths: '3-7,4-9', fm_tcp_fragment_delays: '30-40' });
const got = JSON.parse(JSON.stringify(w.log));
assert.deepStrictEqual(got.filter(x => x[0] === 'select').map(x => [x[1], x[2]]), [['node.fm_tcp_type', 'fragment'], ['node.fm_tcp_fragment_packets', 'tlshello']]);
assert.deepStrictEqual(got.filter(x => x[0] === 'fill').map(x => x[2]), ['3-7,4-9', '30-40']);
assert.strictEqual(got.filter(x => x[0] === 'clear').length, 2, 'old tags are dropped first');
assert.strictEqual(w.document.getElementById('node.fm_tcp_fragment_max_split').value, '');
// request, row and Use handle the preset
assert(/data\.fm_search = '1'/.test(s));
assert(/fillFragmentMask\(r\.fm_values\);\s*\$\('#node\\\\\.finalmask'\)\.val\(''\)/.test(s));
assert(/text\('FinalMask ' \+ r\.fm\)/.test(s));
console.log('fm preset OK');
