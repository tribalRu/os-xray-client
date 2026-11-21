const fs=require('fs');const {JSDOM}=require('jsdom');const assert=require('assert');
const s=fs.readFileSync(__dirname + '/../../src/opnsense/mvc/app/views/OPNsense/XrayClient/index.volt','utf8');
const a=s.indexOf('        function escHtml(v)');const b=s.indexOf('        function nodeTransportInfo');
const c=s.indexOf('        // Condition summary parts of a rule row');const d=s.indexOf('        $("#grid-rules").UIBootgrid({');
const f0=s.indexOf('                    "rulematch": function (column, row) {');const f1=s.indexOf('                    // Flags a sequence number shared');
const dom=new JSDOM('<table id="grid-rules"></table>',{runScripts:'outside-only'});const w=dom.window;
w.eval(fs.readFileSync('node_modules/jquery/dist/jquery.js','utf8'));
w.eval(s.slice(a,b)+s.slice(c,d)+'\nwindow.F={'+s.slice(f0,f1).replace(/,\s*$/,'')+'};');
const $=w.jQuery;
let rows=[];$.fn.bootgrid=function(cmd){if(cmd==='getCurrentRows')return rows;};
const R=(seq,o)=>Object.assign({uuid:'u'+seq,sequence:String(seq),enabled:'1',description:'r'+seq},o);
const txt=(r)=>w.F.rulematch({},r).replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').trim();
rows=[R(10,{domain:'a.ru,b.ru',port:'443'}),R(20,{}),R(30,{domain:'x'}),R(40,{})];
assert.strictEqual(txt(rows[0]),'domains: 2 · port: 443');
assert(!w.F.rulematch({},rows[0]).includes('exclamation'));          // above the catch-all
assert(!w.F.rulematch({},rows[1]).includes('exclamation'));          // the catch-all itself
assert(w.F.rulematch({},rows[2]).includes('exclamation')&&w.F.rulematch({},rows[2]).includes('rule 20 (r20)'));
assert(w.F.rulematch({},rows[3]).includes('exclamation'));           // a second catch-all is also never reached
// a disabled catch-all hides nothing, a disabled rule needs no warning
rows[1].enabled='0';assert(!w.F.rulematch({},rows[2]).includes('exclamation'));
rows[1].enabled='1';rows[2].enabled='0';assert(!w.F.rulematch({},rows[2]).includes('exclamation'));
// same sequence number: order unknown, no claim
rows=[R(20,{}),R(20,{domain:'x'})];rows[1].uuid='other';assert(!w.F.rulematch({},rows[1]).includes('exclamation'));
// description is escaped
rows=[R(5,{description:'<img>'}),R(6,{domain:'x'})];assert(!w.F.rulematch({},rows[1]).includes('<img>'));
// grid API missing: plain summary
$.fn.bootgrid=function(){throw new Error('no grid');};assert.strictEqual(txt(R(6,{domain:'x'})),'domains: 1');
console.log('rules grid OK');
