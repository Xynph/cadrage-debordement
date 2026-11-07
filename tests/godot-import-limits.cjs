'use strict';
// Exercise actual parser/persistence, including multibyte input and the exact
// 5 MiB byte boundary, independently of the native UI's file preflight.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-import-limit-'));
const bridge=createBridge({dataDir:dir,seed:827381,now:1700000000000});
let id=0,checks=0;
function call(command,payload={}){return bridge.handle({id:++id,command,payload});}
try{
 assert.equal(call('new_career',{club:0}).ok,true);
 const original=call('export').model.meta.exportText;
 // Before the fix this is under the parser's JS-character limit, and gets
 // rejected as invalid JSON instead of being refused at the byte boundary.
 const refused=call('import',{text:'é'.repeat(3*1024*1024)});
 assert.equal(refused.ok,false);assert.match(refused.error,/volumineux/);checks++;
 assert.equal(call('export').model.meta.exportText,original);checks++;
 const padded=original+' '.repeat(5*1024*1024-Buffer.byteLength(original));
 assert.equal(call('import',{text:padded}).ok,true,'Exact 5 MiB UTF-8 import remains admissible');checks++;
 const excess=call('import',{text:padded+' '});
 assert.equal(excess.ok,false);assert.match(excess.error,/volumineux/);checks++;
 const doc=JSON.parse(original);doc.note='é'.repeat(1000);
 assert.equal(call('import',{text:JSON.stringify(doc)}).ok,true,'Admissible Unicode document imports normally');checks++;
 assert.equal(call('export').model.meta.exportText,original);checks++;
 console.log(JSON.stringify({passed:true,checks,coverage:'UTF8 byte refusal, exact 5 MiB boundary, Unicode import, rollback'}));
}finally{bridge.close();fs.rmSync(dir,{recursive:true,force:true});}
