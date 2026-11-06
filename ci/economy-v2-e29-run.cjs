'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const E24=require('./economy-v2-obligations-run.cjs'),N=require('../tests/career-resilience/native.cjs');
const Store=require('./economy-v2-durable-store.cjs'),I=require('./economy-v2-e29-integrity.cjs');
const E1=require('../dist/economy-v2-core.js');
function run(profile,seed){
 const native=E24.run(profile,seed);
 assert.equal(native.series.length,15);
 assert.equal(native.counts.rounds,435);assert.equal(native.counts.imports,3);
 const g=N.fresh(({reference:0,modeste:13,alternatif:6})[profile],seed);
 const before=N.data(g,'createSaveDocument()'),beforeState=JSON.stringify(before.state);
 const cash=native.series.flatMap(s=>s.clubs.map(c=>c.cash));
 const tension=native.series.map((s,i)=>{
  const prior=i?native.series[i-1]:null;
  return {season:s.season,pressure:s.clubs.filter(c=>c.cash<c.planning29Weeks).length,
   recoveries:prior?s.clubs.filter(c=>{
    const old=prior.clubs.find(p=>p.id===c.id);
    return old&&old.cash<old.planning29Weeks&&c.cash>=c.planning29Weeks;
   }).length:0,declines:prior?s.clubs.filter(c=>{
    const old=prior.clubs.find(p=>p.id===c.id);return old&&c.cash<old.cash;
   }).length:0};
 });
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-e29-campaign-')),file=path.join(dir,'ledger.json'),anchorPath=path.join(dir,'trusted-anchor.json');
 let fixture;
 try{
  const authority=I.fixtureAuthority(anchorPath,Buffer.alloc(32,92));
  Store.initialize(file,['sandbox']);I.bootstrap(file,authority);
  const prior=fs.readFileSync(file,'utf8');
  I.transact(file,authority,s=>({...s,ledger:E1.income(s.ledger,{clubId:'sandbox',eventId:'fixture-income',period:'2028-03',amount:100})}));
  const accepted=I.verifiedRead(file,authority);
  assert.equal(accepted.state.ledger.balances.sandbox.cash,100);
  fs.writeFileSync(file,prior);
  assert.throws(()=>I.verifiedRead(file,authority),/Rollback, unanchored/);
  fixture={validRevision:accepted.revision,restoredSnapshotRejected:true,authorityIndependentFixture:true};
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
 const after=N.data(g,'createSaveDocument()');
 assert.equal(JSON.stringify(after.state),beforeState);
 assert.equal(after.checksum,before.checksum);
 assert.equal(native.counts.unmeasuredLiabilities,14*15);
 return {schema:1,stage:'E2.9',profile,seed,source:'observed-native-game-and-isolated-anchor-fixture',
  seasons:15,rounds:native.counts.rounds,rollovers:native.counts.rollovers,
  imports:native.counts.imports,cashMovements:native.counts.cashMovements,
  legacySaveUnchanged:true,saveChecksum:before.checksum,
  historicalLiabilitiesUnknown:native.counts.unmeasuredLiabilities,
  nativePayablesCreated:0,anchorFixture:fixture,
  playableObservation:{
   minClubCash:Math.min(...cash),maxClubCash:Math.max(...cash),
   proxy:'Observed cash below illustrative 29-week wages: planning pressure, NEVER proven payable, debt, or bankruptcy',
   totalPressureObservations:tension.reduce((n,s)=>n+s.pressure,0),
   observedRecoveryTransitions:tension.reduce((n,s)=>n+s.recoveries,0),
   clubsCashDecliningVsPriorYear:tension.reduce((n,s)=>n+s.declines,0),
   seasonalSeries:tension,
   enforcedNewPenalties:0,changesToNativeGameplay:0
  }};
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e29-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,'e29-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E29 PASS '+JSON.stringify({profile,seed,seasons:r.seasons,rounds:r.rounds,imports:r.imports,
  cashMovements:r.cashMovements,saveParity:r.legacySaveUnchanged,rollbackRejected:r.anchorFixture.restoredSnapshotRejected,
  pressure:r.playableObservation.totalPressureObservations,recovery:r.playableObservation.observedRecoveryTransitions}));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
