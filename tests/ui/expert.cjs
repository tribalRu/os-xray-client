const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('        window.expertTabWanted');const b=s.indexOf('        var expertConfigLoaded');
const html=`<ul><li id="tab_expert_li"><a href="#tab_expert"></a></li><li class="active"><a href="#tab_general"></a></li></ul>
<input type="checkbox" id="xrayclient.general.expert_mode"><select id="xrayclient.general.config_mode"><option value="ui">ui</option><option value="raw">raw</option></select>`;
const dom=new JSDOM(html,{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval('jQuery.fn.tab=function(){window.shown=jQuery(this).attr("href");return this;};'+s.slice(a,b));
const $=w.$;
assert.strictEqual(w.expertTabWanted(),false);
w.toggleExpertTab(w.expertTabWanted());assert.strictEqual($('#tab_expert_li').css('display'),'none');
$('#xrayclient\\.general\\.expert_mode').prop('checked',true).trigger('change');
assert.notStrictEqual($('#tab_expert_li').css('display'),'none');
$('#xrayclient\\.general\\.expert_mode').prop('checked',false).trigger('change');
assert.strictEqual($('#tab_expert_li').css('display'),'none');
// raw mode keeps it
$('#xrayclient\\.general\\.config_mode').val('raw');assert.strictEqual(w.expertTabWanted(),true);
$('#xrayclient\\.general\\.expert_mode').trigger('change');assert.notStrictEqual($('#tab_expert_li').css('display'),'none');
// the container and the mode selector sit on the Expert tab in the template
assert(/<div id="tab_expert"[^>]*>\s*\{\{ partial\("layout_partials\/base_form", \['fields': expertForm, 'id': 'frm_general_expert'\]\) \}\}\s*<div id="raw_json_container"/.test(s));
assert(s.includes("$('#frm_general_expert').append($('#raw_json_container'));"));
console.log('expert tab OK');
