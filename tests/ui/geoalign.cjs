const fs=require('fs');const assert=require('assert');const {JSDOM}=require('jsdom');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('            function alignFieldLabel(fieldSel) {');
const b=s.indexOf('            [\'#DialogNode\'',a);
const code=s.slice(a,b);
const w=new JSDOM(`<table><tr><td id="n"><div id="nm">Name</div></td><td id="c"><div id="box"></div><select id="rule.domain" style="display:none"></select></td></tr></table>`,{runScripts:'outside-only'}).window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval(`var FIELDS=[['domain','site','GeoSite']];`+code);
w.eval(`
 $.fn.offset=function(){return {top: this.attr('id')==='box'?8:0};};
 $.fn.outerHeight=function(){return this.attr('id')==='box'?40:(this.attr('id')==='nm'?20:0);};
 $.expr.pseudos.visible=function(e){return e.tagName!=='SELECT';};
 alignGeoLabels();`);
const pad=w.eval("$('#n').css('padding-top')");
assert.strictEqual(pad,'17px'); // 8 + (min(40,38)-20)/2
assert.strictEqual(w.eval("$('#n')[0].style.getPropertyPriority('vertical-align')"),'important');assert.strictEqual(w.eval("$('#n')[0].style.getPropertyValue('vertical-align')"),'top');
w.eval("$.fn.outerHeight=function(){return this.attr('id')==='box'?120:(this.attr('id')==='nm'?20:0);}; alignGeoLabels();");
assert.strictEqual(w.eval("$('#n').css('padding-top')"),'17px'); // 8 + (38-20)/2: tall box, name stays at the top
console.log('geoalign OK');
// DNS server dialog: the same helper, other field ids
const w2=new JSDOM(`<table><tr><td id="n"><div id="nm">Domains</div></td><td id="c"><div id="box"></div><select id="server.domains" multiple style="display:none"></select></td></tr></table>`,{runScripts:'outside-only'}).window;
w2.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w2.eval(code+`
 $.fn.offset=function(){return {top: this.attr('id')==='box'?8:0};};
 $.fn.outerHeight=function(){return this.attr('id')==='box'?40:(this.attr('id')==='nm'?20:0);};
 $.expr.pseudos.visible=function(e){return e.tagName!=='SELECT';};
 alignAllLabels('body');`);
assert.strictEqual(w2.eval("$('#n').css('padding-top')"),'17px');
console.log('dns align OK');
