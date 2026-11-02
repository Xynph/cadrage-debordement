import test from 'node:test';
import assert from 'node:assert/strict';
import {validateURL,optionForSeason,argsOf,capture} from './collector.mjs';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

test('accept only RugbyData HTTPS statistics competition pages',()=>{
 assert.equal(validateURL('https://www.rugbydata.fr/statistics/competition/1'),'https://www.rugbydata.fr/statistics/competition/1');
 assert.throws(()=>validateURL('http://rugbydata.fr/statistics/competition/1'));
 assert.throws(()=>validateURL('https://other.example/statistics/competition/1'));
 assert.throws(()=>validateURL('https://rugbydata.fr/players'));
});
test('reject when selected season absent or ambiguous',()=>{
 assert.equal(optionForSeason([{text:'2025/2026',value:'x'},{text:'2026/2027',value:'y'}],'2025-2026').value,'x');
 assert.throws(()=>optionForSeason([{text:'2026/2027',value:'y'}],'2025-2026'));
 assert.throws(()=>optionForSeason([{text:'2025/2026',value:'x'},{text:'2025-2026',value:'z'}],'2025-2026'));
});
test('bound collection limits and request delays',()=>{
 assert.equal(argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out','./raw']).limit,300);
 assert.throws(()=>argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out','./raw','--limit','5000']));
 assert.throws(()=>argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out','./raw','--delay','0']));
});

test('capture mock: rejects pre-selection responses and stores only selected-season JSON',async()=>{
 const out=await fs.mkdtemp(path.join(os.tmpdir(),'rugby-test-'));
 let callback,selected='';
 const response=data=>({ok:()=>true,headers:()=>({'content-type':'application/json'}),url:()=> 'https://www.rugbydata.fr/statistics/competition/1',json:async()=>data});
 const page={
   on:(_name,fn)=>{callback=fn},
   goto:async()=>{if(callback)callback(response({players:[{name:'BAD SEASON'}]}))},
   waitForTimeout:async()=>{},
   locator:where=>where==='select'?{
      count:async()=>1,
      nth:()=>({locator:()=>({evaluateAll:async()=>[{text:'2025/2026',value:'2025'}]}),selectOption:async v=>{selected=v;callback(response([{name:'Test Player',club:'Club A',matches:1}]))},inputValue:async()=>selected})
     }:where==='body'?{innerText:async()=>'Mock DOM'}:where==='table'?{evaluateAll:async()=>[]}:null,
   getByText:pattern=>/individuelles/.test(String(pattern))?{first:()=>({count:async()=>1,click:async()=>{}})}:{count:async()=>0}
 };
 const engine={chromium:{launch:async()=>({newPage:async()=>page,close:async()=>{}})}};
 try {
  const a=argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out',out]);
  const r=await capture(a,engine);
  assert.equal(r.JSONResponses,1);
  assert.equal(r.paginationComplete,true);
  const contents=JSON.parse(await fs.readFile(r.file,'utf8'));
  assert.equal(contents.responseScope,'after-season-selection');
  assert.equal(contents.json[0].data[0].name,'Test Player');
 } finally {await fs.rm(out,{recursive:true,force:true})}
});
