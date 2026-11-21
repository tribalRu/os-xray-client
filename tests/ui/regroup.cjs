const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const cut=(a,b)=>s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));
const place=cut('        (function placeJsonSections() {','        function toggleConfigModeUI()');
const mount=cut('        function mountNativeAdvancedToggle','        // Collapsible sections use the native');
const adv=cut('        (function injectGeneralAdvancedToggle() {','        // --- WARP auto-config generation');
const row=(id)=>`<tr><td><b>${id}</b></td><td><input id="xrayclient.general.${id}"></td></tr>`;
const form=(id,ids)=>`<form id="${id}"><table><tbody><tr><td><span><a id="show_all_help_${id}"></a></span></td></tr>${ids.map(row).join('')}</tbody></table></form>`;
const ta=(id)=>`<div class="form-group"><textarea id="xrayclient.general.${id}"></textarea><span class="help-block">h</span></div>`;
const html=`<div id="tab_general">${form('frm_general',['enable_tun','access_log'])}</div>
<div id="tab_dns">${form('frm_general_dns',['dns_enabled','dns_use_system_hosts'])}</div>
<div id="tab_balancers">${form('frm_general_obs',['observatory_type','observatory_concurrency','observatory_interval'])}</div>
<div id="tab_routing_policy">${form('frm_general_route',['routing_domain_strategy','enable_sniffing','sniffing_route_only'])}</div>
<div id="json_sections_container">${['dns_json','balancers_json','observatory_json','dns_hosts_json'].map(ta).join('')}</div>`;
const dom=new JSDOM(html,{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval(mount+'\n'+place+'\n'+adv);
const $=w.$;
const where=(id)=>$('[id="xrayclient.general.'+id+'"]').closest('form').attr('id');
assert.strictEqual(where('dns_json'),'frm_general_dns');
assert.strictEqual(where('dns_hosts_json'),'frm_general_dns');
assert.strictEqual(where('observatory_json'),'frm_general_obs');
assert.strictEqual(where('balancers_json'),'frm_general_obs');
// order inside the observatory form: observatory json, then balancers json
const ids=Array.from($('#frm_general_obs textarea')).map(e=>e.id);
assert.deepStrictEqual(ids,['xrayclient.general.observatory_json','xrayclient.general.balancers_json']);
assert.strictEqual($('#json_sections_container').length,0);
// advanced switch: three toggles, shared state
const tabs=['#tab_general','#tab_dns','#tab_balancers','#tab_routing_policy'];
tabs.forEach(t=>assert(!$(t).hasClass('optional-hidden')===false,'hidden by default '+t));
const links=$('a:has(i.fa-toggle-off)');assert.strictEqual(links.length,4);
links.eq(3).trigger('click');
tabs.forEach(t=>assert(!$(t).hasClass('optional-hidden'),'shown after toggle '+t));
assert.strictEqual($('i.fa-toggle-on').length,4);
$('a:has(i.fa-toggle-on)').eq(2).trigger('click');
tabs.forEach(t=>assert($(t).hasClass('optional-hidden')));
assert.strictEqual($('i.fa-toggle-off').length,4);
console.log('regroup OK');
