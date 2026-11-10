'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
test('canonical worker: exact internals, pure reads, paid targeted reports, weekly completion, deep replay and failures',t=>{
 const dataDir=fs.mkdtempSync(path.join(os.tmpdir(),'oval-knowledge-worker-')),options={dataDir,seed:12345,now:1794178800000};let bridge=createBridge(options),id=0;
 t.after(()=>{bridge.close();fs.rmSync(dataDir,{recursive:true,force:true});});
 const request=(command,payload={})=>bridge.handle({id:++id,command,payload}),good=(command,payload)=>{const r=request(command,payload);assert.equal(r.ok,true,r.error);return r.model;};
 const file=path.join(dataDir,'PrototypeGodot','donnees.json'),bytes=()=>fs.readFileSync(file),state=()=>JSON.parse(JSON.parse(bytes()).store['bdt-v1']);
 const find=(m,pid)=>{let result=null;function visit(x){if(!x||typeof x!=='object')return;if(x.id===pid&&x.knowledge)result=x;for(const y of Object.values(x))if(y&&typeof y==='object')visit(y);}visit(m);return result;};
 let model=good('new_career',{club:0,mode:'common'}),raw=state();assert.equal(raw.playerKnowledge,undefined);assert.equal(model.squad[0].potential,null);assert.equal(model.squad[0].potentialRange.max-model.squad[0].potentialRange.min,4);
 const foreign=raw.clubs[29].players[0],target=foreign.id;assert.ok(Number.isFinite(foreign.rating));assert.ok(Number.isFinite(foreign.dev.potential));
 const source=model.market[0];assert.equal(source.rating,null);assert.equal(source.ratingRange,null);assert.deepEqual(source.attributesV2,{});assert.deepEqual(source.positionRatings,{});
 const unchanged=bytes();good('snapshot');good('export');assert.deepEqual(bytes(),unchanged);assert.equal(JSON.parse(good('export').meta.exportText).state.clubs[29].players[0].dev.potential,foreign.dev.potential);
 const context={season:model.meta.season,week:model.meta.week,club:0};const beforeBad=bytes();assert.equal(request('observe_player',{playerId:target,confirmed:false,context}).ok,false);assert.deepEqual(bytes(),beforeBad);
 const cash=model.finance.cash;model=good('observe_player',{playerId:target,confirmed:true,context});assert.equal(model.finance.cash,cash-5000);assert.equal(state().playerKnowledge.jobs[0].remaining,2);assert.equal(state().playerKnowledge.records.length,0);
 const rejected=bytes();assert.equal(request('observe_player',{playerId:target,confirmed:true,context}).ok,false);assert.deepEqual(bytes(),rejected);
 function week(){model=good('auto_lineup');model=good('begin_match');model=good('delegate');assert.equal(model.live.finished,true);model=good('finish_round');return model;}
 week();assert.equal(state().playerKnowledge.jobs[0].remaining,1);assert.ok(state().playerKnowledge.records.flat().some(r=>r[0]!==target),'real played opponent observed');assert.equal(state().playerKnowledge.records.flat().some(r=>r[0]===target),false);
 week();let record=state().playerKnowledge.records.flat().find(r=>r[0]===target);assert.ok(record);assert.equal(record[1],'observed');assert.equal(record[8]-record[7],8);assert.equal(record[10]-record[9],10);const first=find(model,target);assert.ok(first);assert.equal(first.rating,null);assert.equal(first.ratingRange.max-first.ratingRange.min,8);fs.mkdirSync('/tmp/oval-knowledge-models',{recursive:true});fs.writeFileSync('/tmp/oval-knowledge-models/first.json',JSON.stringify(model));
 const reportsBefore=state().playerKnowledge.records;const snap=bytes();good('snapshot');good('export');assert.deepEqual(bytes(),snap);assert.deepEqual(state().playerKnowledge.records,reportsBefore);
 // A second paid, distinct report deepens the same player, under contract.
 model=good('observe_player',{playerId:target,confirmed:true,context:{season:model.meta.season,week:model.meta.week,club:0}});week();week();record=state().playerKnowledge.records.flat().find(r=>r[0]===target);assert.equal(record[1],'deep');assert.equal(record[8]-record[7],4);assert.equal(record[10]-record[9],4);const deep=find(model,target);assert.equal(deep.rating,null);assert.equal(deep.ratingRange.max-deep.ratingRange.min,4);fs.writeFileSync('/tmp/oval-knowledge-models/deep.json',JSON.stringify(model));
 const replay=bytes();bridge.close();bridge=createBridge(options);model=good('snapshot');assert.deepEqual(bytes(),replay);assert.deepEqual(state().playerKnowledge.records.flat().find(r=>r[0]===target),record);
 // Corrupted manifest is refused before checkpoint creation or persistent RNG.
 const document=JSON.parse(good('export').meta.exportText);document.state.playerKnowledge.records[0][0][8]++;{let h=2166136261;const text=JSON.stringify(document.state);for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);document.checksum=(h>>>0).toString(16).padStart(8,'0');}const pristine=bytes();const refused=request('import',{text:JSON.stringify(document)});assert.equal(refused.ok,false);assert.match(refused.error,/Connaissance des joueurs/);assert.deepEqual(bytes(),pristine);
 const rename=fs.renameSync,stable=bytes(),money=model.finance.cash;
 fs.renameSync=function(from,to){if(to===file&&String(from).includes('donnees.tmp-'))throw Error('test disk full');return rename.apply(this,arguments);};
 let denied;try{denied=request('observe_player',{playerId:state().clubs[28].players[0].id,confirmed:true,context:{season:model.meta.season,week:model.meta.week,club:0}});}finally{fs.renameSync=rename;}
 assert.equal(denied.ok,false);assert.match(denied.error,/Écriture de sauvegarde impossible/);assert.deepEqual(bytes(),stable);assert.equal(denied.model.finance.cash,money);
 console.log('weekly target completed twice; source',target,'profile',dataDir);
});
