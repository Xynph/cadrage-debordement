'use strict';
// Bounded long-career campaign: checkpoints are generated test data only.
// node ci/career-resilience-run.cjs reference|deficit|rotation END_SEASON OUT_DIR
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const h=require('../tests/career-resilience/native.cjs');
const TOTAL=15,PROFILES={reference:{club:0,seed:827381},deficit:{club:0,seed:827381,cash:-250000,debt:2000000},rotation:{club:0,seed:913107}};
function atomic(file,value){const tmp=file+'.tmp';fs.writeFileSync(tmp,JSON.stringify(value,null,2)+'\n');fs.renameSync(tmp,file);}
function metrics(g){const s=h.data(g),ranking=h.data(g,'ranked().map(c=>c.id)');return s.clubs.map(c=>({id:c.id,rank:ranking.indexOf(c.id)+1,cash:c.cash,debt:s.worldManagement.clubInfo[c.id].debt,reputation:s.worldManagement.clubInfo[c.id].reputation,facilities:s.worldManagement.clubInfo[c.id].facilities,coachChanges:s.worldManagement.clubInfo[c.id].coachChanges,players:c.players.length,weeklyPayroll:c.players.reduce((n,p)=>n+p.salary,0),academy:h.academies(s).find(a=>a.id===c.id).players.length}));}
function main(argv){
 const [name,endText,out]=argv,end=Number(endText),profile=PROFILES[name];
 assert.ok(profile&&Number.isInteger(end)&&end>=1&&end<=TOTAL&&out&&argv.length===3,'Usage: <reference|deficit|rotation> <end 1..15> <out-dir>');
 fs.mkdirSync(out,{recursive:true});const cp=path.join(out,name+'-checkpoint.json'),rp=path.join(out,name+'-report.json');
 let g,r,completed=0;
 const source=h.sources();
 if(fs.existsSync(cp)){
  const saved=h.unseal(JSON.parse(fs.readFileSync(cp,'utf8')));assert.equal(saved.scenario,name);completed=saved.completed;r=saved.report;
  g=h.restore(saved.document,saved.rng);r.stats.reloads++;
 }else{
  g=h.fresh(profile.club,profile.seed);
  r={schemaVersion:1,scenario:name,status:'running',baseMainSha:h.BASE_SHA,testedCommit:process.env.GITHUB_SHA||process.env.CD_TEST_SHA||'local-exact-main-3655df2-plus-test-files',sourceDigest:source.digest,sourceHashes:source.hashes,requestedSeasons:TOTAL,stats:h.newStats(),annual:[],moves:[],adjustments:[],sourceUnchanged:false,limitations:['Native engine in VM; no native Windows or graphical browser test.','Rotation changes fixture finances/reputations to reach return paths; not natural offer frequency.','RNG sidecar exists only in this test runner, not official career saves.','Cash variation is not accounting profit. Three deterministic cases are not statistical calibration.']};
  if(profile.cash!==undefined){const initial=h.data(g,'({cash:club().cash,debt:worldClub(S.club).debt})');g.run('club().cash='+profile.cash+';worldClub(S.club).debt='+profile.debt);r.adjustments.push({season:1,clubId:profile.club,reason:'initial-deficit-fixture',...initial,cashAfter:profile.cash,debtAfter:profile.debt});}
 }
 assert.ok(completed<end,'This segment was already executed; no duplicate progress');
 try{
  for(let year=completed+1;year<=end;year++){
   assert.equal(g.run('S.season'),year);assert.equal(g.run('S.phase'),'league');assert.equal(g.run('S.round'),0);
   const seasonStarted=Date.now(),start=h.data(g,'({clubId:S.club,cash:club().cash})');
   h.verified(g,r.stats,'season-start-native-save');
   const quote=h.data(g,'worldFacilityQuote(S.club)'),before=h.data(g),invested=g.run('worldUpgradeFacility()');
   h.check(r.stats,'single-investment-and-refusal-purity',()=>{
    if(invested){assert.ok(quote.affordable);assert.equal(g.run('club().cash'),start.cash-quote.cost);const once=g.run('JSON.stringify(S)');assert.equal(g.run('worldUpgradeFacility()'),false);assert.equal(g.run('JSON.stringify(S)'),once);}
    else assert.deepEqual(h.data(g),before);
   });
   let rounds=0,ledgerNet=0;
   while(g.run('S.phase')!=='ended'){
    assert.ok(++rounds<=32,'Season progression stalled');
    ledgerNet+=h.round(g,r.stats).reduce((n,e)=>n+e.amount,0);
    if(g.run('S.phase')==='league'&&g.run('S.round')===13)g=h.reload(g,r.stats,'midseason-native-import');
   }
   const state=h.data(g),offers=h.data(g,'S.clubs.filter(c=>c.id!==S.club).map(c=>managerMobilityDecision(c.id))');
   h.check(r.stats,'complete-native-season-and-ledger',()=>{
    assert.equal(state.history.length,187);assert.ok(state.worldManagement.champion!==null);
    assert.equal(g.run('club().cash'),start.cash-(invested?quote.cost:0)+ledgerNet);
    assert.equal(state.season,year);
   });
   h.verified(g,r.stats,'season-end-native-save');
   const annual={season:year,managerClub:start.clubId,champion:state.worldManagement.champion,nativeMatches:state.history.length,startCash:start.cash,endCash:state.clubs[state.club].cash,investment:invested?quote.cost:0,roundLedgerNet:ledgerNet,naturalOffers:offers.filter(x=>x.accepted).length,refusals:Object.fromEntries(['stable','finances','reputation'].map(k=>[k,offers.filter(x=>x.reason===k).length])),clubs:metrics(g)};
   r.annual.push(annual);
   if(year<TOTAL){
    let target=null;
    if(name==='rotation'){target=[7,12,0][(year-1)%3];h.controlledTarget(g,target,r.adjustments);}
    else if(year%3===0){const choices=offers.filter(x=>x.accepted).sort((a,b)=>b.affinity-a.affinity||a.clubId-b.clubId);target=choices[0]?.clubId??null;}
    if(target!==null){g=h.moveCompared(g,target,r.stats);r.moves.push({departureSeason:year,fromClub:start.clubId,toClub:target,controlled:name==='rotation'});}
    else{g.run('advanceSeason()');h.verified(g,r.stats,'stay-in-club-new-season');}
   }
   completed=year;r.completedSeasons=completed;r.status='partial';annual.durationMs=Date.now()-seasonStarted;
   const recovery=h.capture(g);
   atomic(cp,h.seal({scenario:name,completed,sourceDigest:source.digest,document:recovery.document,rng:recovery.rng,report:r}));atomic(rp,r);
   console.log(JSON.stringify({scenario:name,season:year,club:start.clubId,champion:annual.champion,closingCash:annual.endCash,checks:r.stats.passed,durationMs:annual.durationMs}));
  }
  if(completed===TOTAL){
   h.check(r.stats,'annual-archive-idempotence',()=>{g.run('worldEndSeason()');const s=g.run('JSON.stringify(S)');assert.equal(g.run('worldEndSeason()'),false);assert.equal(g.run('JSON.stringify(S)'),s);assert.equal(g.run('S.worldManagement.yearbook.length'),TOTAL);});
   if(name==='rotation')h.check(r.stats,'fourteen-moves-and-return-to-origin',()=>{assert.equal(r.moves.length,14);assert.equal(r.moves.filter(x=>x.toClub===profile.club).length,4);});
   r.status='passed';
  }else r.status='partial';
  const sample=h.capture(g),a=h.restore(sample.document,sample.rng),b=h.restore(sample.document,sample.rng);
  if(completed<TOTAL){a.run('finishRound()');b.run('finishRound()');}
  h.check(r.stats,'same-checkpoint-and-test-rng-replay',()=>assert.deepEqual(h.data(a),h.data(b)));r.stats.replayComparisons++;
  h.check(r.stats,'native-source-fingerprint-unchanged',()=>assert.equal(h.sources().digest,source.digest));r.sourceUnchanged=true;
  r.completedSeasons=completed;r.finalSaveBytes=Buffer.byteLength(JSON.stringify(sample.document));
  r.finalHistory=h.data(g,'S.managerMobility.history');
  atomic(cp,h.seal({scenario:name,completed,sourceDigest:source.digest,document:sample.document,rng:sample.rng,report:r}));
 }catch(e){r.status='failed';r.completedSeasons=completed;r.error=e.stack;atomic(rp,r);throw e;}
 atomic(rp,r);console.log('CAREER RESILIENCE '+JSON.stringify({scenario:name,status:r.status,seasons:completed,checks:r.stats.passed,reloads:r.stats.reloads}));
}
if(require.main===module){try{main(process.argv.slice(2));}catch(e){console.error(e.stack);process.exitCode=1;}}
module.exports={main,PROFILES,TOTAL};
