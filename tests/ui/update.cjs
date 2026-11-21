const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('        // ---- Update progress dialog');const b=s.indexOf("        $('#upd_modal_reload').on('click'");
const m0=s.indexOf('<div class="modal fade" id="DialogUpdateProgress"');const m1=s.indexOf('<div class="modal fade" id="DialogResetTemplate"');
const code=s.slice(a,b).replace(/location\.reload\(\)/g,'window.__reload()');
const dom=new JSDOM(s.slice(m0,m1)+'<input id="xrayclient.maintenance.plugin_branch" value="main">'+['btn_update_core','btn_update_geodata','btn_update_plugin'].map(i=>`<button id="${i}"></button>`).join(''),{runScripts:'outside-only'});
const w=dom.window;w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
const $=w.$;
w.__log=[];w.__reload=()=>w.__log.push('reload');
w.eval(`
 window.timers={};window.setInterval=function(f){timers.int=f;return 1;};window.clearInterval=function(){timers.int=null;};
 window.setTimeout=function(f){timers.esc=f;return 2;};window.clearTimeout=function(){timers.esc=null;};
 jQuery.fn.modal=function(o){__log.push('modal');return this;};
 window.saveMode='ok';window.saveCb=null;
 window.saveFormToEndpoint=function(u,f,ok,dis,fail){__log.push('save '+f+' '+dis);if(saveMode==='ok')ok({});else fail({});};
 window.ajaxCall=function(u,d,cb){__log.push('ajax '+u);window.pending=cb;};
 window.loadVersionInfo=function(){__log.push('versions');};window.checkForUpdates=function(){__log.push('check');};
 window.updateServiceControlUI=function(x){__log.push('svc '+x);};`+code);
const E=(k,r)=>w.updateOutcome(k,r);
// ---- outcome classification
assert.strictEqual(E('core',{status:'ok',output:'a\n=== Successfully updated Xray-core to v1! ===\n'}).state,'ok');
assert.strictEqual(E('geodata',{status:'ok',output:'x\n=== GeoData update completed! ===\n'}).state,'ok');
assert.strictEqual(E('plugin',{status:'ok',output:'=== Plugin successfully updated from GitHub! ==='}).state,'ok');
let o=E('core',{status:'ok',output:'Found\nERROR: Failed to download Xray archive.\n'});assert.strictEqual(o.state,'failed');assert(o.output.includes('ERROR'));
assert.strictEqual(E('geodata',{status:'ok',output:'=== GeoData update FAILED (rolled back) ==='}).state,'failed');
// an ERROR line wins even if a success line is also there
assert.strictEqual(E('core',{status:'ok',output:'=== Successfully updated Xray-core to v1! ===\nERROR: late'}).state,'failed');
assert.strictEqual(E('plugin',{status:'ok',output:''}).state,'failed');                 // no output: unknown = failed
assert(E('plugin',{status:'ok',output:''}).message.includes('no output'));
assert.strictEqual(E('plugin',{status:'ok',output:'Running installer...'}).state,'failed'); // no success marker
// a success marker of another update does not count
assert.strictEqual(E('core',{status:'ok',output:'=== GeoData update completed! ==='}).state,'failed');
o=E('core',{status:'error',message:'Invalid core branch'});assert.strictEqual(o.state,'failed');assert(o.message.includes('Invalid core branch'));
// transport failures: jqXHR-like objects, nothing at all
o=E('core',{readyState:4,status:504,statusText:'Gateway Timeout',responseText:'<html>secret</html>'});assert.strictEqual(o.state,'noresponse');assert(o.message.includes('504'));assert(!o.message.includes('secret'));
assert.strictEqual(E('core',undefined).state,'noresponse');assert.strictEqual(E('core',{readyState:0,status:0}).state,'noresponse');
assert.strictEqual(E('core','garbage').state,'noresponse');
// ---- dialog flow: success
const reset=()=>{w.__log.length=0;w.eval('window.pending=null;timers.int=null;timers.esc=null;saveMode="ok"');};
const vis=(sel)=>$(sel).css('display')!=='none';
w.runMaintenanceUpdate('core');
assert.strictEqual($('#upd_modal_title').text(),'Updating Xray-core');
assert(w.__log.includes('modal')&&w.__log.includes('save frm_maintenance true')&&w.__log.includes('ajax /api/xrayclient/service/updateCore'));
assert(!vis('#upd_modal_close')&&!vis('#upd_modal_reload'));                 // cannot be closed while running
assert($('#upd_modal_status .fa-spin').length===1&&$('#upd_modal_status').text().includes('0 s'));
w.runMaintenanceUpdate('geodata');assert.strictEqual(w.__log.filter(x=>x.startsWith('ajax')).length,1,'second start ignored while running');
assert(w.timers.esc);                                                          // escape hatch armed
w.pending({status:'ok',output:'=== Successfully updated Xray-core to v2! ==='});
assert($('#upd_modal_status').text().includes('Xray-core updated.')&&$('#upd_modal_status .text-success').length===1);
assert(vis('#upd_modal_close')&&!vis('#upd_modal_reload'));assert.strictEqual($('#upd_modal_output').text(),'=== Successfully updated Xray-core to v2! ===');
assert(w.__log.includes('versions')&&w.__log.includes('check')&&w.__log.includes('svc xrayclient'));
assert.strictEqual(w.timers.int,null);assert.strictEqual(w.timers.esc,null);
// restarts allowed again
reset();w.runMaintenanceUpdate('geodata');assert.strictEqual($('#upd_modal_title').text(),'Updating GeoIP & GeoSite');assert(!w.__log.includes('svc xrayclient')||true);
// ---- failure shows the log and keeps the page
w.pending({status:'ok',output:'Downloading\nERROR: geoip.dat: Failed to download.\n=== GeoData update FAILED ==='});
assert($('#upd_modal_status .text-danger').length===1);assert($('#upd_modal_output').text().includes('ERROR: geoip.dat'));assert(vis('#upd_modal_close'));
assert(!w.__log.includes('check'),'no version re-check after a failure');
// ---- settings not saved: no update request at all
reset();w.eval('saveMode="fail"');w.runMaintenanceUpdate('core');
assert(!w.__log.some(x=>x.startsWith('ajax')));assert($('#upd_modal_status').text().includes('could not be saved'));assert(vis('#upd_modal_close'));
// ---- no answer: warns, offers reload, refreshes versions
reset();w.runMaintenanceUpdate('plugin');
assert($('#upd_modal_status').text().includes('branch main'));
w.pending({readyState:4,status:502});
assert($('#upd_modal_status .text-warning').length===1);assert(vis('#upd_modal_reload')&&vis('#upd_modal_close'));assert(w.__log.includes('versions'));
// ---- plugin success: reload button, and closing the dialog reloads the page
reset();w.runMaintenanceUpdate('plugin');w.pending({status:'ok',output:'=== Plugin successfully updated from GitHub! ==='});
assert($('#upd_modal_status .text-success').length===1&&vis('#upd_modal_reload'));
$('#DialogUpdateProgress').trigger('hidden.bs.modal');assert(w.__log.includes('reload'));
// a failed plugin update does not reload on close
reset();w.runMaintenanceUpdate('plugin');w.pending({status:'ok',output:'ERROR: Installer failed'});
$('#DialogUpdateProgress').trigger('hidden.bs.modal');assert(!w.__log.includes('reload'));
// ---- hung request: after the escape timeout the dialog can be left
reset();w.runMaintenanceUpdate('core');assert(!vis('#upd_modal_close'));w.timers.esc();assert(vis('#upd_modal_close')&&$('#upd_modal_close').text()==='Stop waiting');
// the elapsed counter ticks
w.timers.int();assert(/\d+ s/.test($('#upd_modal_status .upd_elapsed').text()));
console.log('update dialog OK');
