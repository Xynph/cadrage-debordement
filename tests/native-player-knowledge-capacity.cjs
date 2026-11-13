'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const Module=require('node:module');const {factory}=require('../native/engine/player-knowledge.cjs');
// Diagnostic local : le vrai worker, avec un accès d'inspection ajouté en mémoire seulement (comme native-club-support-effects).
const source=path.resolve(__dirname,'../native/engine/worker.cjs'),originalWorker=fs.readFileSync(source,'utf8'),needle='return {handle,close};';assert.equal(originalWorker.split(needle).length,2);
const instrumented=new Module(source,module);instrumented.filename=source;instrumented.paths=Module._nodeModulePaths(path.dirname(source));instrumented._compile(originalWorker.replace(needle,'return {handle,close,inspect:run};'),source);
const {createBridge}=instrumented.exports;
function sign(doc){let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
test('32 000 strictly valid knowledge records export and resume inside a dedicated finite node budget',t=>{
 // Monde : la carrière vient du vrai worker (116 clubs) ; les 32 000 rapports sont injectés dans son export signé.
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'oval-knowledge-capacity-')),source=createBridge({dataDir:path.join(root,'source'),seed:8721,now:1700000000000});let bridge;
 t.after(()=>{bridge?.close();fs.rmSync(root,{recursive:true,force:true});});
 const good=(b,command,payload={})=>{const r=b.handle({id:Math.floor(Math.random()*1e9),command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 good(source,'new_career',{mode:'world-champ',club:0});const career=JSON.parse(good(source,'export').meta.exportText);source.close();
 const k=factory();
 const rows=Array.from({length:32000},(_,i)=>['observed-'+i,'deep',1,0,['club:0:1:0','target:observation-'+i],70,80,68,72,78,82]);
 const manifest={version:1,records:Array.from({length:16},(_,i)=>rows.slice(i*2000,(i+1)*2000))};
 const withKnowledge=structuredClone(career);withKnowledge.state.playerKnowledge=manifest;assert.equal(k.validate(withKnowledge.state),true);
 assert.ok(JSON.stringify(withKnowledge).length<24*1024*1024,'La sauvegarde Monde avec 32 000 rapports reste sous la limite d’import');
 const data=path.join(root,'PrototypeGodot');fs.mkdirSync(data);const file=path.join(data,'donnees.json'),envelope={protocol:1,seed:1234,clock:1700000000000,store:{'bdt-v1':JSON.stringify(withKnowledge.state)}};fs.writeFileSync(file,JSON.stringify(envelope));const original=fs.readFileSync(file);
 bridge=createBridge({dataDir:root,seed:1,now:1700000000000});const loaded=bridge.handle({id:1,command:'snapshot'});assert.equal(loaded.ok,true,loaded.error);assert.equal(loaded.model.meta.recoveryRequired,false,loaded.model.meta.profileError);assert.equal(loaded.model.meta.hasCareer,true);assert.deepEqual(fs.readFileSync(file),original,'La reprise ne réécrit pas le profil');
 const exported=bridge.handle({id:2,command:'export'});assert.equal(exported.ok,true,exported.error);assert.equal(JSON.parse(exported.model.meta.exportText).state.playerKnowledge.records.flat().length,32000);
 // Un enregistrement corrompu est refusé à l'écriture de la sauvegarde (état de la VM du worker).
 bridge.inspect('S.playerKnowledge.records[0][0][8]++');assert.throws(()=>bridge.inspect('createSaveDocument()'),/Connaissance des joueurs/);
 // The allowance does not enlarge the rest of the career's existing budget (Monde : 2 600 000 nœuds, édition v5).
 // Remplissage par des notes de carnet valides (le Monde refuse une clé inconnue avant de compter les nœuds) :
 // 1500 notes de 2000 points dépassent à elles seules le budget général une fois les rapports retirés.
 const notebook=loaded.model.clubLife.coachNotebook,targets=career.state.clubs.flatMap(c=>c.players).slice(0,1500);
 bridge.inspect('delete S.playerKnowledge;S.coachNotebook='+JSON.stringify({version:1,entries:targets.map(p=>({target:p.id,textCodes:Array(2000).fill(65),...notebook.context}))}));assert.throws(()=>bridge.inspect('createSaveDocument()'),/trop complexe/);
});
