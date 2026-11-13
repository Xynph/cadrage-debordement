'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const {createBridge}=require('../native/engine/worker.cjs'),{context}=require('./france-harness.cjs');
const professionalDepth=require('../native/engine/professional-depth.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-france-ai-sheet-'));let id=0;
const call=(b,command,payload={})=>b.handle({id:++id,command,payload});
const good=(b,c,p)=>{const r=call(b,c,p);assert.equal(r.ok,true,r.error);return r.model;};
function fixture(size){
 const h=context();
 h.run(`start(29,'france');S.training='repos';trainWeek();
  (${professionalDepth.toString()})().fill(S);
  var opponent=nextMatch().find(id=>id!==S.club);var c=S.clubs[opponent];
  var hookers=c.players.filter(p=>p.pos===POS[1]&&!p.injury);
  if(hookers.length<2)throw Error('Témoin de profondeur au talonnage incomplet');
  for(const hooker of hookers.slice(1))hooker.injury=2;`);
 if(size)h.run('while(c.players.length<'+size+'){var p=academyPlayer(c.id,9,S.season,900+c.players.length,true);p.academy=false;p.contractEnd=S.season+2;c.players.push(p)}');
 h.run('validateCareer(S)');return {h,text:h.run('JSON.stringify(createSaveDocument())'),opponent:h.run('opponent')};
}
for(const size of [40,42]){
 const f=fixture(size),b=createBridge({dataDir:path.join(root,'roster-'+size),seed:827381,now:1700000000000});
 try{good(b,'import',{text:f.text});const before=JSON.parse(good(b,'export').meta.exportText).state,model=good(b,'begin_match'),after=JSON.parse(good(b,'export').meta.exportText).state;
  assert.ok(model.live);const sh=after.live.sheets[after.live.pair.indexOf(f.opponent)];assert.equal(sh.nominated.length,23);assert.equal(sh.bench.filter(Boolean).length,8);
  const prior=before.clubs[f.opponent],next=after.clubs[f.opponent];assert.equal(prior.players.length,size);assert.equal(next.players.length,prior.players.length+1);const added=next.players.find(p=>!prior.players.some(x=>x.id===p.id));assert.equal(added.pos,'Talonneur');assert.equal(added.salary,2000);assert.equal(added.contractEnd,after.season+2);assert.equal(added.injury,0);assert.equal(added.academy,false);
  good(b,'save');good(b,'import',{text:good(b,'export').meta.exportText});
 }finally{b.close();}
}
{
 const f=fixture(100),b=createBridge({dataDir:path.join(root,'full'),seed:827381,now:1700000000000});
 try{good(b,'import',{text:f.text});const before=good(b,'export'),file=path.join(before.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file),state=JSON.parse(before.meta.exportText).state;const r=call(b,'begin_match');assert.equal(r.ok,false);assert.match(r.error,/Effectif IA.*100/);assert.deepEqual(JSON.parse(good(b,'export').meta.exportText).state,state);assert.deepEqual(fs.readFileSync(file),bytes);}finally{b.close();}
}
// Optional exact Windows reception profiles are read only; all commands use disposable copies.
for(const original of process.argv.slice(2)){
 const bytes=fs.readFileSync(original),profile=JSON.parse(bytes),dir=fs.mkdtempSync(path.join(root,'reception-')),target=path.join(dir,'PrototypeGodot');fs.mkdirSync(target);fs.writeFileSync(path.join(target,'donnees.json'),bytes);
 const b=createBridge({dataDir:dir,now:profile.clock});
 try{const prior=good(b,'snapshot');good(b,'begin_match');good(b,'delegate');const next=good(b,'finish_round');assert.equal(next.meta.week,prior.meta.week+1);good(b,'save');console.log(JSON.stringify({original,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),began:true,completedWeek:prior.meta.week,originalPreserved:bytes.equals(fs.readFileSync(original))}));assert.deepEqual(fs.readFileSync(original),bytes);}finally{b.close();}
}
console.log('Feuille IA France : blessures, promotion réelle, effectifs40/42, refus borné100 et rollback PASS');
