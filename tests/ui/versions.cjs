const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('        (function placeVersionsCard() {');const b=s.indexOf('        // Each update button sits in the row');
const c=s.indexOf('        function renderUpdateRow(prefix, info) {');const d=s.indexOf('        var updatesInFlight = false;');
const m0=s.indexOf('<div id="maint_versions_wrap"');const m1=s.indexOf("        {{ partial(\"layout_partials/base_form\", ['fields': maintenanceForm");
const card=s.slice(m0,m1);
const html=card+'<form id="frm_maintenance"><table><tbody><tr><td><span></span></td><td><a id="show_all_help_frm_maintenance"></a></td><td></td></tr><tr><td>Field</td><td>x</td><td></td></tr></tbody></table></form>';
const dom=new JSDOM(html,{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval(s.slice(a,b)+s.slice(c,d));const $=w.$;
// the card sits directly under the help row, inside the form; the old wrapper is gone
const rows=Array.from($('#frm_maintenance tr'));
assert.strictEqual($(rows[0]).find('[id^=show_all_help]').length,1);
assert.strictEqual($(rows[1]).find('#maint_versions').length,1);
assert.strictEqual($('#maint_versions_wrap').length,0);
// one card with the three installed values and both update rows
['lbl_core_version','lbl_plugin_version','lbl_geodata_date','upd_core_latest','upd_plugin_latest','btn_check_updates','lbl_updates_status'].forEach(id=>assert.strictEqual($('#'+id).length,1,id));
assert.strictEqual($('[id^="upd_"][id$="_current"]').length,0);
assert.strictEqual($('#updates_details').length,0);
w.renderUpdateRow('core',{current:'26.11.9',latest:'26.12.0',updateAvailable:true,releaseUrl:'https://x/r'});
assert.strictEqual($('#upd_core_latest').text(),'26.12.0');assert($('#upd_core_badge').text().includes('update available'));assert.strictEqual($('#upd_core_link').attr('href'),'https://x/r');
w.renderUpdateRow('plugin',{current:'2.27.8',latest:'',updateAvailable:false});
assert.strictEqual($('#upd_plugin_latest').text(),'unreachable');assert($('#upd_plugin_badge').text().includes('offline'));assert.strictEqual($('#upd_plugin_link').css('display'),'none');
// the form's column-width rules must not reach the rows of the card's own table
const css=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const m=css.match(/#frm_maintenance tr:not\(\.maint_ver_row\) > td:nth-child\(2\) \{\s*width: 78% !important;/);assert(m);
assert.strictEqual($('.maint_ver_table tr').length,$('.maint_ver_table tr.maint_ver_row').length);
console.log('versions card OK');
