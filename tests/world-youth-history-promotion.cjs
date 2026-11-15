'use strict';
// Serialization fixture: a real adult World academy player has an age-15 row.
// This test does not claim to have played the earlier four seasons.
const assert=require('node:assert/strict');
const {engineContext}=require('./harness.cjs');
const h=engineContext();
try{
 h.start(0);
 assert.equal(h.run('S.worldMode.version'),5);
 assert.equal(h.run('S.clubs.length'),116);
 assert.equal(h.run('S.academyGroupPolicy'),3);
 h.run('var historyYouth=S.development.academy.find(p=>p.age>=18&&/^youth-\\d+-\\d+-\\d+$/.test(p.id));if(!historyYouth)throw Error("Adult World youth required");historyYouth.dev.history=[{season:1,age:15,start:historyYouth.dev.seasonStart,end:historyYouth.rating,minutes:0,appearances:0}];validateCareer(S);parseSaveDocument(JSON.stringify(createSaveDocument()));save()');
 h.command('save');
 const id=h.run('historyYouth.id'),age=h.run('historyYouth.age'),history=h.run('JSON.stringify(historyYouth.dev.history)'),professionals=h.run('club().players.length'),academy=h.run('S.development.academy.length');
 h.command('promote_academy',{playerId:id,confirmed:true});
 h.ctx.promotedHistoryId=id;
 assert.equal(h.run('club().players.length'),professionals+1);
 assert.equal(h.run('S.development.academy.length'),academy-1);
 assert.equal(h.run('S.development.academy.some(p=>p.id===promotedHistoryId)'),false);
 assert.equal(h.run('club().players.find(p=>p.id===promotedHistoryId).academy===true'),false);
 assert.equal(h.run('club().players.find(p=>p.id===promotedHistoryId).age'),age);
 assert.equal(h.run('JSON.stringify(club().players.find(p=>p.id===promotedHistoryId).dev.history)'),history);
 assert.equal(h.run('club().players.find(p=>p.id===promotedHistoryId).dev.history[0].age'),15);
 const point=h.checkpoint();
 {
  const parsed=h.run('parseSaveDocument(JSON.stringify(createSaveDocument())).state');
  const resumed=engineContext(parsed);
  try{assert.ok(resumed.run('JSON.stringify(S)')===point.text,'portable export and real native resume preserve the promoted World state');}
  finally{resumed.close();}
 }
 const before=h.run('JSON.stringify(S)'),seed=h.seed(),stored=h.store['bdt-v1'];
 function rejects(change,label){
  h.run('var invalidHistoryState=JSON.parse(JSON.stringify(S));var invalidHistoryYouth=invalidHistoryState.clubs[invalidHistoryState.club].players.find(p=>p.id===promotedHistoryId)');
  h.run(change);
  assert.throws(()=>h.run('validateCareer(invalidHistoryState)'),/incohérentes/,label);
  assert.ok(h.run('JSON.stringify(S)')===before,label+' preserves source World');
  assert.equal(h.seed(),seed,label+' preserves native RNG');
  assert.ok(h.store['bdt-v1']===stored,label+' preserves saved World');
  h.run('invalidHistoryState=null;invalidHistoryYouth=null;invalidHistorySenior=null');
 }
 rejects('invalidHistoryYouth.dev.history[0].age=14','youth history below 15 rejected');
 rejects('invalidHistoryYouth.age=15','current professional below 16 rejected');
 rejects('var invalidHistorySenior=invalidHistoryState.clubs[invalidHistoryState.club].players.find(p=>!/^youth-/.test(p.id)&&CDWorldCareer.sourcePlayer(invalidHistoryState,p.id)?.age>15);if(!invalidHistorySenior)throw Error("Ordinary World professional required");invalidHistorySenior.dev.history=[{season:1,age:16,start:invalidHistorySenior.dev.seasonStart,end:invalidHistorySenior.rating,minutes:0,appearances:0}];validateCareer(invalidHistoryState);invalidHistorySenior.dev.history[0].age=15','non-youth history below 16 rejected');
 h.run('validateCareer(S);parseSaveDocument(JSON.stringify(createSaveDocument()))');
 console.log(JSON.stringify({passed:true,fixture:'serialization only, real World adult youth and native promotion',checks:['age-15 youth history retained after promotion','portable export and native resume exact','age-14 youth history rejected','age-15 current professional rejected','age-15 non-youth history rejected','negative cases preserve S/storage/RNG']}));
}finally{h.close();}
