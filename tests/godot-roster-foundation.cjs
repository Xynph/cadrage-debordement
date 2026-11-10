'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {assertLegacyProfessionals}=require('./helpers/assert-legacy-professionals.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_ROSTER_TEST_ROOT||require('node:os').tmpdir(),'cd-roster-'));
const b=createBridge({dataDir:path.join(root,'main-'+process.pid),seed:827381,now:1700000000000});let serial=0;
const call=(command,payload={})=>b.handle({id:++serial,command,payload});
const good=(command,payload={})=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const state=()=>JSON.parse(good('export').meta.exportText).state;
const sourceRosters=clubs=>clubs.map(club=>{
 const players=club.players.filter(p=>!p.id.startsWith('depth-'));
 const generated=club.players.filter(p=>p.id.startsWith('depth-'));
 assert.equal(generated.length,Math.max(0,40-players.length));
 assert.ok(generated.every(p=>!p.rosterProfile));
 return {...club,players};
});
try{
 const model=good('new_career',{mode:'common',club:6});
 assert.equal(model.meta.rosterFoundation?.version,2,'new common careers expose roster foundation version');
 const data=require('../dist/rugby-roster-foundation.js'),base=require('../dist/rugby-common-rosters.js');
 const runtime=fs.readFileSync(path.join(__dirname,'../dist/rugby-roster-foundation.js'),'utf8');assert.ok(!runtime.includes('https://')&&!runtime.includes('Tuicuvu')&&!runtime.includes('Fourcade'),'anonymous runtime provenance');
 const s=state(),players=sourceRosters(s.clubs).flatMap(c=>c.players);assert.equal(players.length,1592);assert.equal(Object.keys(data.players).length,1592);assert.equal(Object.keys(s.commonDatabase).length,2);
 assert.equal(players.find(p=>p.id==='lnr:184').pos,'Pilier gauche');assert.equal(players.find(p=>p.id==='lnr:657').pos,'Talonneur');
 assert.equal(players.find(p=>p.id==='lnr:13516').rosterProfile.position.basis,'estimated','conflicting Traini evidence stays quarantined');
 const sourcePlayers=new Map(base.clubs.flatMap(c=>c.players).map(p=>[p.id,p]));
 let verified=0;for(const p of players){
  const source=sourcePlayers.get(p.id),profile=data.players[p.id];
  assert.deepEqual(p.rosterProfile,profile);assert.equal(p.potential,source.potential);assert.deepEqual(p.hiddenTraitsV2,source.hiddenTraitsV2);
  if(p.age<23){
   for(const k of ['rating','skills','attributesV2'])assert.deepEqual(p[k],source[k],p.id+' '+k);
   assert.equal(p.dev.potential,source.dev.potential);
  }
  assert.equal(p.salary,source.salary);assert.equal(p.contractEnd,profile.contract.endSeason);assert.equal(profile.wage.basis,'estimated');if(!Object.hasOwn(require('../data/roster-foundation/verified.json').statuses,p.id))assert.equal(profile.status.basis,'estimated');if(p.fam<=1)assert.deepEqual(profile.position.qualifications,[p.pos]);if(profile.contract.basis==='official')verified++;
 }
 assert.equal(verified,86);assert.equal(players.find(p=>p.id==='lnr:12339').rosterProfile.status.basis,'official');assert.equal(players.find(p=>p.id==='lnr:12339').rosterProfile.status.professionalFromSeason,3);assert.equal(players.find(p=>p.id==='lnr:429').contractEnd,2);
 const initial=good('export').meta.exportText;good('import',{text:initial});assert.equal(good('export').meta.exportText,initial);
 const reject=mutate=>{const d=JSON.parse(initial);mutate(d.state);const before=good('export').meta.exportText;const result=call('import',{text:JSON.stringify(d)});assert.equal(result.ok,false);assert.doesNotMatch(result.error,/modifié ou endommagé/,'metadata validation is reached before checksum');assert.equal(good('export').meta.exportText,before);};
 reject(x=>x.rosterFoundation.version=99);reject(x=>x.rosterFoundation.version=1);reject(x=>x.clubs[6].players[0].rosterProfile.version=1);reject(x=>delete x.rosterFoundation);reject(x=>delete x.clubs[6].players[0].rosterProfile);reject(x=>x.clubs[6].players[0].rosterProfile.contract.endYear=2040);reject(x=>x.clubs[6].players[0].rosterProfile.position.qualifications.push('Talonneur'));reject(x=>x.commonDatabase.extra=true);reject(x=>x.rosterFoundation.extra=true);reject(x=>x.clubs[6].players[0].rosterProfile.status.value='veteran');reject(x=>x.clubs[6].players[0].rosterProfile.contract.sources=['unknown']);reject(x=>x.development.academy[0].rosterProfile=x.clubs[6].players[0].rosterProfile);
 // A legacy common save imports with reserve depth and preserves source profiles/contracts.
 const h=require('./france-harness.cjs').context();h.run('CDFranceCareer.start(6,{database:CDCommonRosters.marker,playersForClub:id=>JSON.parse(JSON.stringify(CDCommonRosters.clubs[id].players))})');
 const legacyText=h.run('JSON.stringify(createSaveDocument())'),legacy=JSON.parse(legacyText);
 good('import',{text:legacyText});assert.equal(state().rosterFoundation,undefined);assertLegacyProfessionals(state(),legacy.state);
 good('import',{text:initial});const model2=good('snapshot');assert.equal(model2.squad.find(p=>p.id==='lnr:657').rosterProfile.position.basis,'official');
 // A real renewal changes the mutable contract, preserving its initial official reference.
 good('new_career',{mode:'common',club:3});const beforeRenew=state().clubs[3].players.find(p=>p.id==='lnr:429'),offer=good('snapshot').squad.find(p=>p.id==='lnr:429');
 const renewed=good('extend_contract',{playerId:offer.id,confirmed:true,salary:100000,years:offer.renewal.minYears});assert.equal(renewed.meta.negotiation.status,'signed');
 const afterRenew=state().clubs[3].players.find(p=>p.id===offer.id);assert.ok(afterRenew.contractEnd>beforeRenew.contractEnd);assert.deepEqual(afterRenew.rosterProfile,beforeRenew.rosterProfile);assert.equal(good('snapshot').squad.find(p=>p.id===offer.id).rosterProfile.contract.endYear,2028);
 // Failed real disk write restores both state and deterministic RNG before retry.
 const current=state(),disk=path.join(renewed.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(disk);fs.renameSync(disk,disk+'.held');fs.mkdirSync(disk);
 try{assert.equal(call('train',{mode:'intense'}).ok,false);assert.deepEqual(state(),current);}finally{fs.rmdirSync(disk);fs.renameSync(disk+'.held',disk);}assert.deepEqual(fs.readFileSync(disk),bytes);
 const controlDir=path.join(root,'control-'+process.pid,'PrototypeGodot');fs.mkdirSync(controlDir,{recursive:true});fs.writeFileSync(path.join(controlDir,'donnees.json'),bytes);const control=createBridge({dataDir:controlDir,seed:827381,now:1700000000000});
 try{good('train',{mode:'intense'});assert.equal(control.handle({id:2,command:'train',payload:{mode:'intense'}}).ok,true);assert.ok(JSON.stringify(state())===JSON.stringify(JSON.parse(control.handle({id:3,command:'export'}).model.meta.exportText).state),'disk retry restores RNG as well as state');}finally{control.close();fs.rmSync(path.join(root,'control-'+process.pid),{recursive:true,force:true});}
 // Full season, expiry/free agents, AI roster churn and next season keep initial references valid.
 const long=require('./france-harness.cjs').context();long.run('const CDCommonCareer=('+require('../native/engine/common-rosters.cjs').toString()+')();CDCommonCareer.start(18)');
 // The existing sale path moves the same profile by ID and retains the initial source.
 long.run('const sold=club().players.find(p=>p.id==="lnr:235"),buyer=S.clubs.find(c=>c.id!==S.club&&c.players.length<42);if(!buyer)throw Error("buyer");S.economy.offers.push({id:"lot1-sale",playerId:sold.id,buyer:buyer.id,fee:20000,expires:S.economy.week});acceptSale("lot1-sale");validateCareer(S);');
 assert.ok(!long.state().clubs[18].players.some(p=>p.id==='lnr:235'));assert.deepEqual(long.state().clubs.flatMap(c=>c.players).find(p=>p.id==='lnr:235').rosterProfile,data.players['lnr:235']);
 const measure=x=>({bytes:Buffer.byteLength(JSON.stringify(x)),nodes:(function count(v){return 1+(Array.isArray(v)?v.reduce((n,x)=>n+count(x),0):v&&typeof v==='object'?Object.values(v).reduce((n,x)=>n+count(x),0):0)})(x)}),measures={initial:measure(long.state())};
 for(let week=0;week<34;week++)long.run('finishRound();validateCareer(S)');assert.equal(long.state().phase,'ended');measures.endSeason=measure(long.state());
 long.run('advanceSeason();validateCareer(S);pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");');assert.equal(long.state().season,2);measures.nextSeason=measure(long.state());
 for(const p of [...long.state().clubs.flatMap(c=>c.players),...long.state().economy.freeAgents])if(p.rosterProfile)assert.deepEqual(p.rosterProfile,data.players[p.id]);
 const builder=require('../scripts/build-roster-foundation.cjs');assert.deepEqual(builder.build(),builder.build());assert.equal(builder.endSeason(2027),1);assert.equal(builder.endSeason(2028),2);assert.throws(()=>builder.endSeason(2026));
 console.log(JSON.stringify({passed:true,players:players.length,verifiedContracts:verified,measures,bytes:Buffer.byteLength(initial),checks:['coverage','positions','youth 36/11 parity','wage parity','conservative qualifications','strict provenance imports','legacy common preserves provenance','renewal preserves initial reference','sale preserves initial reference','disk and RNG rollback','34 weeks and next season','deterministic compilation']}));
}finally{b.close();fs.rmSync(root,{recursive:true,force:true});}
