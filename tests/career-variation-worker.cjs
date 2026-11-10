'use strict';
const assert=require('node:assert/strict'),test=require('node:test');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const {createBridge}=require('../native/engine/worker.cjs');
const variation=require('../native/engine/career-variation.cjs')();
const fingerprint=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');

function fixture(t,seed=427){
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'oval-variation-worker-'));
 let bridge=createBridge({dataDir:directory,seed,now:1794310000000}),serial=0;
 t.after(()=>{bridge?.close();bridge=null;fs.rmSync(directory,{recursive:true,force:true});});
 const send=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const go=(command,payload)=>{const result=send(command,payload);assert.equal(result.ok,true,command+': '+result.error);return result.model;};
 return {go,send,restart(){bridge?.close();bridge=null;bridge=createBridge({dataDir:directory,seed:999,now:1});},
  document(){return JSON.parse(go('export').meta.exportText);},close(){bridge?.close();bridge=null;},
  file(){return path.join(directory,'PrototypeGodot','donnees.json');}};
}
function populations(state){return [...state.clubs.map(c=>c.players),state.development.academy,state.economy.freeAgents,state.market,
 ...(state.aiRoster?.academies??[]).map(c=>c.players),...(state.nativeAcademy?.centers??[]).flatMap(c=>c.players?[c.players]:[])];}
function stats(players){return players.map(p=>({id:p.id,pos:p.pos,fam:p.fam,rating:p.rating,skillBase:p.skillBase,skills:p.skills,
 attributesV2:p.attributesV2,nativeAttributesV1:p.nativeAttributesV1,potential:p.potential,cap:p.dev.potential,seasonStart:p.dev.seasonStart})).sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);}
function sourceStats(state){return stats(state.clubs.flatMap(club=>club.players).filter(p=>p.id.startsWith('lnr:')||p.id.startsWith('world:')));}
function encoded(document,change){const doc=structuredClone(document);change(doc.state);const text=JSON.stringify(doc.state);let h=2166136261;for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}

test('all database players get the same seed/ID variation regardless of the managed club, and another seed differs',t=>{
 const first=fixture(t);const a=first.go('new_career',{mode:'common',club:0});
 assert.deepEqual(a.meta.careerVariation,{version:1,seed:427,varyCurrent:true});
 const stateA=sourceStats(first.document().state);assert.ok(stateA.length>1000);first.close();
 const second=fixture(t);const b=second.go('new_career',{mode:'common',club:29});
 assert.deepEqual(b.meta.careerVariation,a.meta.careerVariation);
 assert.deepEqual(sourceStats(second.document().state),stateA);second.close();
 const identical=fixture(t);identical.go('new_career',{mode:'common',club:0});
 assert.equal(fingerprint(sourceStats(identical.document().state)),fingerprint(stateA));identical.close();
 const third=fixture(t,428);third.go('new_career',{mode:'common',club:0});
 assert.notEqual(fingerprint(sourceStats(third.document().state)),fingerprint(stateA));third.close();
});

test('checkbox off changes potential without changing the seed or competition RNG; reads, exports and restart never reroll',t=>{
 const off=fixture(t,731);
 off.go('new_career',{mode:'common',club:0,varyCurrent:false});
 const a=off.document(),seedOff=JSON.parse(fs.readFileSync(off.file(),'utf8')).seed;off.close();
 const on=fixture(t,731);on.go('new_career',{mode:'common',club:0,varyCurrent:true});
 const b=on.document(),seedOn=JSON.parse(fs.readFileSync(on.file(),'utf8')).seed;on.close();off.restart();
 assert.equal(a.state.careerVariation.varyCurrent,false);
 const rawYoung=new Map(require('../dist/rugby-common-rosters.js').clubs.flatMap(c=>c.players).filter(p=>p.age<23).map(p=>[p.id,p]));
 const ids=new Map(b.state.clubs.flatMap(c=>c.players).map(p=>[p.id,p]));
 let changed=0;
 for(const p of a.state.clubs.flatMap(c=>c.players)){
  const other=ids.get(p.id),source=rawYoung.get(p.id);
  if(source)for(const key of ['rating','skillBase','skills','attributesV2'])assert.deepEqual(p[key],source[key],'current off preserves '+p.id+' '+key);
  if(source)assert.equal(p.potential,variation.sourcePotential(source.potential,p.id,a.state.careerVariation));
  assert.equal(p.potential,other.potential,'one canonical potential draw');
  if(p.rating!==other.rating||fingerprint(p.skills)!==fingerprint(other.skills))changed++;
  assert.deepEqual(p.rosterProfile,other.rosterProfile);
  assert.deepEqual(p.hiddenTraitsV2,other.hiddenTraitsV2);
 }
 assert.ok(changed>100);
 assert.equal(seedOff,seedOn);
 const before=fs.readFileSync(off.file()),statsBefore=fingerprint(populations(a.state));
 for(let i=0;i<3;i++)off.go('snapshot');
 assert.equal(fingerprint(populations(off.document().state)),statsBefore);
 assert.deepEqual(fs.readFileSync(off.file()),before);
 off.restart();
 assert.equal(fingerprint(populations(off.document().state)),statsBefore);
 off.go('import',{text:JSON.stringify(a)});
 assert.equal(fingerprint(populations(off.document().state)),statsBefore);
 assert.deepEqual(off.document().state.careerVariation,a.state.careerVariation);
});

test('strict metadata and source-potential binding reject edited saves while preserving the open career',t=>{
 const f=fixture(t);f.go('new_career',{mode:'common',club:0});const document=f.document(),before=fs.readFileSync(f.file());
 for(const mutate of [s=>s.careerVariation.version=2,s=>s.careerVariation.seed=-1,s=>s.careerVariation.seed=1.5,
  s=>s.careerVariation.varyCurrent='false',s=>s.careerVariation.extra=true,s=>s.careerVariation.seed++,
  s=>{const p=s.clubs.flatMap(c=>c.players).find(p=>p.id.startsWith('lnr:'));p.potential=p.potential===97?96:p.potential+1;}]){
  const result=f.send('import',{text:encoded(document,mutate)});assert.equal(result.ok,false,'tampered save rejected');
  assert.deepEqual(fs.readFileSync(f.file()),before);
 }
 for(const payload of [{varyCurrent:'false'},{varyPotential:false},{seed:4},{careerVariation:{version:1,seed:1,varyCurrent:true}}]){
  assert.equal(f.send('new_career',{mode:'common',club:0,...payload}).ok,false);
  assert.deepEqual(fs.readFileSync(f.file()),before);
 }
});

test('new careers across all supported native editions retain valid bounded populations and survive export/reload',t=>{
 for(const mode of ['fiction','france','world','world-pacific','world-japan','world-nationale','world-champ']){
  console.log('Validating career edition:',mode);
  const f=fixture(t,129);
  f.go('new_career',{mode,club:0});const doc=f.document();
  assert.deepEqual(doc.state.careerVariation,{version:1,seed:129,varyCurrent:true},mode);
  let count=0;
  for(const pool of populations(doc.state))for(const p of pool){
   count++;assert.ok(p.rating>=15&&p.rating<=99,mode+' current');
   assert.ok(p.dev.potential>=p.rating&&p.dev.potential<=99,mode+' potential');
   assert.ok(Object.values(p.skills).every(v=>Number.isFinite(v)&&v>=15&&v<=99));
   if(p.attributesV2)assert.ok(Object.values(p.attributesV2).every(v=>Number.isFinite(v)&&v>=20&&v<=97));
   if(p.potential!==undefined)assert.ok(p.potential>=20&&p.potential<=97);
  }
  assert.ok(count>500,mode+' initial populations');
  const original=fingerprint(populations(doc.state));f.restart();
  assert.equal(fingerprint(populations(f.document().state)),original,mode+' no reload reroll');
  f.close();
 }
});

test('a career without the optional manifest remains without it on import and restart',t=>{
 const f=fixture(t);f.go('new_career',{mode:'france',club:0});const doc=f.document();
 const legacy=encoded(doc,s=>{delete s.careerVariation;});
 f.go('import',{text:legacy});
 const before=f.document().state;assert.equal(before.careerVariation,undefined);
 f.restart();
 assert.equal(f.document().state.careerVariation,undefined);
 assert.deepEqual(populations(f.document().state),populations(before));
});

test('custom fictional careers share the manifest, optional current variation and reload guarantees',t=>{
 const document=require('../native/engine/competition-editor.cjs').generate({name:'Ligue variation',clubs:Array.from({length:14},(_,i)=>'Club '+(i+1)),doubleRound:true});
 const f=fixture(t,831);
 const model=f.go('new_career',{mode:'custom',club:0,document,confirmed:true,varyCurrent:false});
 assert.deepEqual(model.meta.careerVariation,{version:1,seed:831,varyCurrent:false});
 const created=f.document();assert.equal(created.state.customCompetition.name,'Ligue variation');
 const original=fingerprint(populations(created.state));f.restart();
 assert.equal(fingerprint(populations(f.document().state)),original);
});
