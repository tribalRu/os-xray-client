const fs=require('fs');const assert=require('assert');const {JSDOM}=require('jsdom');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('            function placeBrowseButtons() {');
const b=s.indexOf("            FIELDS.forEach(function (f) {\n                var $sel",a);
const code=s.slice(a,b);
const html=`<div id="DialogRule"><table><tr><td>L</td><td><select id="rule.domain" multiple></select>
<div class="x"><a href="#"><i></i> Clear All</a> <a href="#">Copy</a> <a href="#">Text</a></div>
<button class="geodata_open" data-field="domain" data-kind="site">B</button></td></tr></table></div>`;
const w=new JSDOM(html,{runScripts:'outside-only'}).window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval("var FIELDS=[['domain','site','GeoSite']];"+code+";placeBrowseButtons();");
const $=w.$;
const btn=$('.geodata_open');
assert.strictEqual(btn.parent()[0],$('.x')[0],'inside the links row');
assert.strictEqual(btn.prev()[0],$('.x a').last()[0],'right after Text');
assert.strictEqual(btn.css('float'),'right');
console.log('geobtn OK');
