const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('// ---- WARP endpoint search');const b=s.indexOf('        // Capture phase: runs before the bootgrid');
const html='<div id="DialogNode"><table><tbody>'+
 '<tr class="proto_wg"><td><input id="node.wg_endpoint"><input id="node.wg_secret_key"><input id="node.wg_public_key"><input id="node.wg_address"><input id="node.wg_mtu"></td></tr>'+
 '<tr id="masque_warp_tools" class="masque_warp"><td><input id="node.masque_warp_private_key"><input id="node.masque_warp_public_key"><input id="node.masque_warp_address"><input id="node.address"><input id="node.port"></td></tr>'+
 '</tbody></table><select id="node.alpn" multiple><option>h2</option><option>h3</option></select></div>';
const dom=new JSDOM(html,{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval('window.calls=[];jQuery.ajax=function(o){window.calls.push(o);};'+s.slice(a,b)+';window.rowsFn=warpProbeRows;window.ageFn=warpAgeText;window.sourcesFn=warpSourcesText;');
const $=w.jQuery;
// pure helpers
assert.strictEqual(w.ageFn(1000,1030),'just now');assert.strictEqual(w.ageFn(1000,1000+600),'10 min ago');assert.strictEqual(w.ageFn(1000,1000+7200),'2 h ago');
const st={mode:'wg',cached:{wg:[{host:'8.6.112.1',port:500,status:'verified',ms:90,ts:1},{host:'8.6.112.2',port:500,status:'verified',ms:40,ts:1}]},
 results:[{host:'8.6.112.1',port:500,status:'unstable',ms:70},{host:'8.6.112.3',port:500,status:'verified',ms:60}]};
const rows=w.rowsFn(st,'wg');
assert.strictEqual(JSON.stringify(rows.map(r=>r.host+':'+r.status)),JSON.stringify(['8.6.112.2:verified','8.6.112.3:verified','8.6.112.1:unstable']));
assert.strictEqual(rows[0].cached,true);assert.strictEqual(rows[1].cached,false);
assert.strictEqual(w.rowsFn(st,'masque_h2').length,0);
// panels exist, WG panel copies the visibility class
const wg=$('#warp_probe_wg');assert(wg.length===1&&wg.closest('tr').hasClass('proto_wg'));
assert($('#warp_probe_masque').length===1&&$('#warp_probe_masque').closest('tr').hasClass('masque_warp'));
// missing credentials: no request
wg.find('.wp-start').trigger('click');
assert(w.calls.length===0&&wg.find('.wp-status').text().includes('Client Private Key'));
$('#node\\.wg_secret_key').val('S');$('#node\\.wg_public_key').val('P');$('#node\\.wg_address').val('172.16.0.2/32,2606::2/128');
wg.find('.wp-start').trigger('click');
assert.strictEqual(w.calls[0].url,'/api/xrayclient/service/warpProbeStart');
assert.strictEqual(w.calls[0].data.mode,'wg');assert.strictEqual(w.calls[0].data.credentials.wg_address,'172.16.0.2/32,2606::2/128');assert.strictEqual(w.calls[0].data.want,'5');
assert(!w.calls[0].data.endpoints);
assert(!w.calls[0].data.use_sources);assert(wg.find('.wp-src').length===1&&wg.find('.wp-any').length===1);assert($('#warp_probe_masque').find('.wp-src').length===1&&$('#warp_probe_masque').find('.wp-wide').length===1&&wg.find('.wp-wide').length===0);
assert(wg.find('.wp-start').prop('disabled')&&$('#DialogWarpProbe_wg .wp-cancel').css('display')!=='none'&&$('#DialogWarpProbe_wg').css('display')!=='none');
w.calls[0].success({status:'ok'});
// re-check one row
w.calls.length=0;
$('#warp_probe_wg').data('rows');
// status poll: invoke the status callback through the interval-less path
w.calls.length=0;
$('#DialogNode').trigger('shown.bs.modal');
const stCall=w.calls.find(c=>c.url.endsWith('warpProbeStatus'));
stCall.success({status:'done',mode:'wg',attempts:12,verified:2,max_attempts:80,results:[{host:'8.6.112.3',port:500,status:'verified',ms:60,kbps:2500,checks:'4/4',cc:'FI',city:'Helsinki',colo:'HEL',ts:Math.floor(Date.now()/1000)}],cached:{}});
const trs=$('#DialogWarpProbe_wg .wp-table tbody tr');assert.strictEqual(trs.length,1);assert(trs.text().includes('8.6.112.3:500')&&trs.text().includes('2.5 Mbit/s'));
assert.strictEqual($('#DialogWarpProbe_wg .wp-bar').css('width'),'100%');assert($('#DialogWarpProbe_wg .wp-bar').hasClass('progress-bar-success'));
{const f=trs.find('td').first().find('span').first();assert.strictEqual(f.text(),String.fromCodePoint(0x1F1EB,0x1F1EE));assert(f.attr('title').includes('Helsinki')&&f.attr('title').includes('Finland')&&f.attr('title').includes('HEL'));}
// Use fills the endpoint
trs.find('button:contains(Use)').trigger('click');
assert.strictEqual($('#node\\.wg_endpoint').val(),'8.6.112.3:500');assert($('#DialogWarpProbe_wg').css('display')==='none');assert(wg.find('.wp-show').css('display')!=='none');
// Re-check sends the endpoint list
w.calls.length=0;trs.find('button:contains(Re-check)').trigger('click');
const rc=w.calls.find(c=>c.url.endsWith('warpProbeStart'));assert.strictEqual(rc.data.endpoints[0].host,'8.6.112.3');
// MASQUE: use sets address, port, alpn and the edge key
const mq=$('#warp_probe_masque');
mq.find('input[value=masque_h2]').prop('checked',true);
w.calls.length=0;
$('#node\\.masque_warp_private_key').val('K'.repeat(50));$('#node\\.masque_warp_address').val('172.16.0.2/32');
$('#DialogNode').append('<input id="node.fm_tcp_type" value="fragment"><input id="node.finalmask" value="">');mq.find('.wp-src').prop('checked',true);mq.find('.wp-wide').prop('checked',true);mq.find('.wp-start').trigger('click');assert.strictEqual(w.calls[0].data.mode,'masque_h2');assert.strictEqual(w.calls[0].data.use_sources,'1');assert.strictEqual(w.calls[0].data.wide,'1');assert.strictEqual(w.calls[0].data.fm.fm_tcp_type,'fragment');
w.calls.length=0;$('#DialogNode').trigger('shown.bs.modal');
w.calls.filter(c=>c.url.endsWith('warpProbeStatus')).forEach(c=>c.success({status:'done',mode:'masque_h2',attempts:3,verified:1,results:[{host:'162.159.198.2',port:443,status:'verified',ms:80,kbps:900,checks:'4/4',edge_key:'EDGEKEY',ts:1}],cached:{}}));
$('#DialogWarpProbe_masque tbody button:contains(Use)').trigger('click');
assert.strictEqual($('#node\\.address').val(),'162.159.198.2');assert.strictEqual($('#node\\.port').val(),'443');assert.strictEqual($('#node\\.masque_warp_public_key').val(),'EDGEKEY');
assert.strictEqual(JSON.stringify($('#node\\.alpn').val()),JSON.stringify(['h2']));
assert.strictEqual(w.sourcesFn([{status:'ok',count:25000,accepted:24990,skipped:10}]),'External lists: 24990 of 25000 endpoints used, 10 outside Cloudflare ranges skipped.');assert(w.sourcesFn([{status:'error',message:'down'}]).includes('could not load (down)'));assert.strictEqual(w.sourcesFn([]),'');
console.log('warp probe ui OK');process.exit(0);
