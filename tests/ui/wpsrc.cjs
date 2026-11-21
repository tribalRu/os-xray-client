const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('// ---- WARP endpoint search');const b=s.indexOf('        // Capture phase: runs before the bootgrid');
const html='<div id="DialogNode"><table><tbody>'+
 '<tr class="proto_wg"><td><input id="node.wg_endpoint"><input id="node.wg_secret_key"><input id="node.wg_public_key"><input id="node.wg_address"><input id="node.wg_mtu"></td></tr>'+
 '<tr id="masque_warp_tools" class="masque_warp"><td><input id="node.masque_warp_private_key"><input id="node.masque_warp_public_key"><input id="node.masque_warp_address"><input id="node.address"><input id="node.port"></td></tr>'+
 '</tbody></table><select id="node.alpn" multiple><option>h2</option><option>h3</option></select></div>';
const dom=new JSDOM(html,{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval('window.calls=[];window.ajaxCall=function(u,d,cb){window.calls.push({url:u,data:d,cb:cb});};jQuery.ajax=function(o){window.calls.push(o);};'+s.slice(a,b)+';window.rowsFn=warpProbeRows;window.ageFn=warpAgeText;window.sourcesFn=warpSourcesText;');
const $=w.jQuery;
const wg=$('#warp_probe_wg');
assert.strictEqual(wg.find('.wp-src-box').css('display'),'none');
assert.strictEqual(w.calls.length,0);
wg.find('.wp-src').prop('checked',true).trigger('change');
assert.notStrictEqual(wg.find('.wp-src-box').css('display'),'none');
const g=w.calls.find(c=>c.url==='/api/xrayclient/settings/get');assert(g);
g.cb({xrayclient:{maintenance:{warp_sources:'https://a.example/x.json'}}});
assert.strictEqual(wg.find('.wp-src-urls').val(),'https://a.example/x.json');
wg.find('.wp-src-urls').val('https://b.example/y.json\nhttps://c.example/z.txt').trigger('change');
const st=w.calls.filter(c=>c.url==='/api/xrayclient/settings/set').pop();
assert.strictEqual(st.data.xrayclient.maintenance.warp_sources,'https://b.example/y.json\nhttps://c.example/z.txt');
st.cb({result:'failed',validations:{'maintenance.warp_sources':'Only https:// URLs.'}});
assert(wg.find('.wp-src-msg').hasClass('text-danger')&&wg.find('.wp-src-msg').text().includes('https'));
st.cb({result:'saved'});
assert(wg.find('.wp-src-msg').hasClass('text-success'));
wg.find('.wp-src').prop('checked',false).trigger('change');
assert.strictEqual(wg.find('.wp-src-box').css('display'),'none');
// the second panel loads the list only once per panel, not per toggle
const n=w.calls.filter(c=>c.url==='/api/xrayclient/settings/get').length;
wg.find('.wp-src').prop('checked',true).trigger('change');
assert.strictEqual(w.calls.filter(c=>c.url==='/api/xrayclient/settings/get').length,n);
console.log('warp src box OK');
