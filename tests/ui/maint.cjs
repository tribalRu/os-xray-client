const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('        (function placeMaintenanceButtons() {');const b=s.indexOf('        function toggleGeoDataCustomUI');
const row=(id)=>`<tr><td>l</td><td><select id="xrayclient.maintenance.${id}"></select></td><td><span class="help-block"></span></td></tr>`;
const html=`<form id="frm_maintenance"><table>${['core_branch','geodata_preset','custom_geoip_url','plugin_branch'].map(row).join('')}</table></form>
<button id="btn_update_core"></button><button id="btn_update_geodata"></button><button id="btn_update_plugin"></button>`;
const dom=new JSDOM(html,{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval(s.slice(a,s.indexOf('        function toggleGeoDataCustomUI')));const $=w.$;
[['btn_update_core','core_branch'],['btn_update_geodata','geodata_preset'],['btn_update_plugin','plugin_branch']].forEach(([b,f])=>{
  const $tr=$('[id="xrayclient.maintenance.'+f+'"]').closest('tr');
  assert.strictEqual($tr.children('td').eq(1).children('#'+b).length,1,b);
  assert($tr.children('td').eq(1).hasClass('maint_btn_cell'));
});
assert.strictEqual($('#frm_maintenance tr').length,4);
// validation text moved from the third cell into the field cell
$('#frm_maintenance tr').each((i,tr)=>{assert.strictEqual($(tr).children('td').eq(2).children('.help-block').length,0);assert.strictEqual($(tr).children('td').eq(1).children('.help-block').length,1);});
// built later. Dropdown containers differ: core/geodata are wrapped twice,
// the plugin picker is a direct child of the cell.
['core_branch','geodata_preset'].forEach(f=>{
  $('[id="xrayclient.maintenance.'+f+'"]').wrap('<div class="outer"><div class="dropdown bootstrap-select" style="width:395px"></div></div>');
});
$('[id="xrayclient.maintenance.plugin_branch"]').after('<div class="dropdown bootstrap-select"><select id="plugin_branch_picker"></select></div><div id="plugin_branch_note">warn</div>');
w.eval('settleMaintenanceButtons()');
const order=(td)=>Array.from(td.children()).map(e=>e.id||e.className||e.tagName.toLowerCase());
['core_branch','geodata_preset'].forEach(f=>{
  const $td=$('[id="xrayclient.maintenance.'+f+'"]').closest('td');const n=order($td);
  const i=n.findIndex(x=>x.split(' ').includes('outer'));
  assert(/^btn_update/.test(n[i+1]),n.join(','));
  assert($td.children('.outer').hasClass('maint_anchor'));
  assert($td.find('.bootstrap-select').hasClass('maint_fixed'));
});
{const $td=$('#plugin_branch_picker').closest('td');const n=order($td);
 const i=n.findIndex(x=>x.split(' ').includes('bootstrap-select'));
 assert(/^btn_update_plugin/.test(n[i+1])&&n[i+2]==='plugin_branch_note',n.join(','));
 assert(!$td.find('.bootstrap-select').hasClass('maint_fixed'));}
console.log('maintenance buttons OK');
