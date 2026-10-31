'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {collect,safeSlug}=require('../tools/data06-itsrugby-bulk.cjs');
test('no malformed club slug can request an arbitrary URL',()=>{assert.equal(safeSlug('clermont'),true);assert.equal(safeSlug('../private'),false);assert.equal(safeSlug('https://bad.example'),false)});
test('captures multiple full roster pages with manifest, preserves failures',async()=>{
 const out=fs.mkdtempSync(path.join(os.tmpdir(),'data06-'));
 try{
  const seen=[];
  const fake=async u=>{seen.push(u);if(u.includes('brive'))return {ok:false,status:500};return {ok:true,text:async()=>'<html><body><div id="effectif-list"><div class="fd-eff-row">'+ 'Player '.repeat(200)+'</div></div></body></html>'}};
  const r=await collect({slugs:['clermont','brive','toulouse'],out,fetchFn:fake,paceMs:0});
  assert.equal(seen.length,3);assert.equal(r.results.filter(x=>x.ok).length,2);
  assert.equal(r.results[1].error,'HTTP 500');assert.ok(fs.existsSync(path.join(out,'stade-toulousain.html')));
  assert.equal(JSON.parse(fs.readFileSync(path.join(out,'manifest.json'))).results.length,3);
 }finally{fs.rmSync(out,{recursive:true,force:true})}
});
test('rejects invalid HTML rather than accepting fake player data',async()=>{
 const out=fs.mkdtempSync(path.join(os.tmpdir(),'data06-'));
 try{const r=await collect({slugs:['clermont'],out,fetchFn:async()=>({ok:true,text:async()=>'<html>challenge</html>'})});assert.equal(r.results[0].ok,false)}
 finally{fs.rmSync(out,{recursive:true,force:true})}
});
