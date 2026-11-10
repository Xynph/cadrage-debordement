'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {context}=require('./france-harness.cjs'),{factory}=require('../native/engine/player-knowledge.cjs'),{createBridge}=require('../native/engine/worker.cjs');
test('32 000 strictly valid knowledge records export and resume inside a dedicated finite node budget',t=>{
 const h=context(8721),k=factory();h.ctx.nativeKnowledgeValidate=k.validate;h.run('start(0)');
 const rows=Array.from({length:32000},(_,i)=>['observed-'+i,'deep',1,0,['club:0:1:0','target:observation-'+i],70,80,68,72,78,82]);h.ctx.nativeKnowledgeManifest={version:1,records:Array.from({length:16},(_,i)=>rows.slice(i*2000,(i+1)*2000))};h.run('S.playerKnowledge=nativeKnowledgeManifest');
 assert.equal(k.validate(h.state()),true);const doc=JSON.parse(h.run('JSON.stringify(createSaveDocument())'));assert.ok(JSON.stringify(doc).length<8*1024*1024);
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'oval-knowledge-capacity-')),data=path.join(root,'PrototypeGodot');fs.mkdirSync(data);const file=path.join(data,'donnees.json'),envelope={protocol:1,seed:1234,clock:1700000000000,store:{'bdt-v1':JSON.stringify(doc.state)}};fs.writeFileSync(file,JSON.stringify(envelope));const original=fs.readFileSync(file);let bridge;
 t.after(()=>{bridge?.close();fs.rmSync(root,{recursive:true,force:true});});bridge=createBridge({dataDir:root,seed:1,now:1700000000000});const loaded=bridge.handle({id:1,command:'snapshot'});assert.equal(loaded.ok,true,loaded.error);assert.equal(loaded.model.meta.recoveryRequired,false,loaded.model.meta.profileError);assert.equal(loaded.model.meta.hasCareer,true);assert.deepEqual(fs.readFileSync(file),original);
 const exported=bridge.handle({id:2,command:'export'});assert.equal(exported.ok,true,exported.error);assert.equal(JSON.parse(exported.model.meta.exportText).state.playerKnowledge.records.flat().length,32000);
 h.run('S.playerKnowledge.records[0][0][8]++');assert.throws(()=>h.run('createSaveDocument()'),/Connaissance des joueurs/);
 // The allowance does not enlarge the rest of the career's existing budget.
 h.run('delete S.playerKnowledge;S.unrelated=Array.from({length:1200},()=>Array(200).fill(0))');assert.throws(()=>h.run('createSaveDocument()'),/trop complexe/);
});
