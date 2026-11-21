const fs = require('fs'); const { JSDOM } = require('jsdom'); const assert = require('assert');
const s = fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt', 'utf8');
const a = s.indexOf('        var tunGatewayState = null;');
const b = s.indexOf('        function renderUpdateRow(prefix, info) {');
assert(a > 0 && b > a);
const m0 = s.indexOf('<div class="modal fade" id="DialogTunSubnet"');
const m1 = s.indexOf('<div class="modal fade" id="DialogDebugInfo"');
const html = '<table><tbody><tr><td><input type="checkbox" id="xrayclient.general.enable_tun" checked></td></tr>' +
  '<tr><td><input id="xrayclient.general.tun_address" value="10.255.0.1/30"></td></tr></tbody></table>' + s.slice(m0, m1);
const dom = new JSDOM(html, { runScripts: 'outside-only' });
const w = dom.window;
w.eval(fs.readFileSync(__dirname + '/node_modules/jquery/dist/jquery.js', 'utf8'));
w.eval('$.fn.modal = function (a) { this.data("modal", a); return this; }; window.ajaxCall = function () {};');
w.eval(s.slice(a, b));
const $ = w.$;
const gw = [{ name: 'XRAY_GW', address: '10.255.0.1', ok: false }];

// banner only for a mismatch, and only while TUN is on
w.renderTunGateway({ status: 'ok', gateways: [] });
assert.strictEqual($('#tun_gw_warning_row').css('display'), 'none');
w.renderTunGateway({ status: 'mismatch', expected: '10.77.0.1', interface: 'opt3', descr: 'XRAY', gateways: gw });
assert.notStrictEqual($('#tun_gw_warning_row').css('display'), 'none');
assert(/XRAY_GW \(10\.255\.0\.1\)/.test($('.tun_gw_text').text()));
assert(/10\.77\.0\.1/.test($('.tun_gw_text').text()));
assert.strictEqual($('#tun_gw_warning_row').prev().find('#xrayclient\\.general\\.tun_address').length, 1);
$('[id="xrayclient.general.enable_tun"]').prop('checked', false).trigger('change');
assert.strictEqual($('#tun_gw_warning_row').css('display'), 'none');
$('[id="xrayclient.general.enable_tun"]').prop('checked', true).trigger('change');
assert.notStrictEqual($('#tun_gw_warning_row').css('display'), 'none');
w.renderTunGateway(null);
assert.strictEqual($('#tun_gw_warning_row').css('display'), 'none');

// the confirmation appears only when the saved subnet really changes
assert.strictEqual(w.tunSubnetChange(), null);          // nothing loaded yet
w.eval('tunSubnetSaved = "10.255.0.1/30";');
assert.strictEqual(w.tunSubnetChange(), null);          // unchanged
$('[id="xrayclient.general.tun_address"]').val(' 10.77.0.1/30 ');
assert.deepStrictEqual(JSON.parse(JSON.stringify(w.tunSubnetChange())), { from: '10.255.0.1/30', to: '10.77.0.1/30' });
$('[id="xrayclient.general.enable_tun"]').prop('checked', false);
assert.strictEqual(w.tunSubnetChange(), null);          // TUN off: no gateway to keep in sync
$('[id="xrayclient.general.enable_tun"]').prop('checked', true);

// dialog text and confirm button
w.renderTunGateway({ status: 'mismatch', expected: '10.77.0.1', gateways: gw });
let confirmed = 0;
w.showTunSubnetDialog(w.tunSubnetChange(), function () { confirmed++; });
assert.strictEqual($('#tun_subnet_from').text(), '10.255.0.1/30');
assert.strictEqual($('#tun_subnet_to').text(), '10.77.0.1/30');
assert.strictEqual($('#tun_subnet_gw').text(), '10.77.0.1');
assert.strictEqual($('#tun_subnet_gw2').text(), '10.77.0.1');
assert(/XRAY_GW \(10\.255\.0\.1\)/.test($('#tun_subnet_current').text()));
assert.strictEqual(confirmed, 0);
$('#btn_tun_subnet_confirm').trigger('click');
assert.strictEqual(confirmed, 1);
$('#btn_tun_subnet_confirm').trigger('click');          // handler is replaced, not stacked
w.showTunSubnetDialog(w.tunSubnetChange(), function () { confirmed += 10; });
$('#btn_tun_subnet_confirm').trigger('click');
assert.strictEqual(confirmed, 12);
console.log('tun subnet OK');
