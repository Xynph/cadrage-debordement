'use strict';
const assert=require('node:assert/strict');
const h=require('./career-resilience/native.cjs');
const {engineContext:context}=require('./harness.cjs');
const results=[],keepers=new Set();
function test(name,fn){try{fn();results.push(name);console.log('PASS '+name);}finally{h.releaseExcept(...keepers)}}
const initial=h.fresh();keepers.add(initial);
test('copy restore and real import preserve state and seed sidecar',()=>{const resumed=h.fork(initial);assert.ok(JSON.stringify(h.data(initial))===JSON.stringify(h.data(resumed)),'reprise exacte de tous les clubs');assert.deepEqual(h.rng(initial),h.rng(resumed));});
test('native round obeys exact cash ledger identity',()=>{const g=h.fork(initial),stats=h.newStats();h.round(g,stats);assert.equal(stats.failed.length,0);assert.equal(stats.passed,1);});
test('native persistence error rolls back without overwriting last good save',()=>{
 const g=h.fork(initial),old=g.store['bdt-v1'],before=g.run('JSON.stringify(S)');
 g.run('globalThis.__write=gameStorage.setItem;gameStorage.setItem=()=>{throw Error("test quota")}');
 assert.throws(()=>g.command('finish_round'),/test quota/);
 assert.ok(g.run('JSON.stringify(S)')===before,'rollback intégral après erreur IO native');assert.ok(g.store['bdt-v1']===old,'sauvegarde Monde inchangée');
 g.run('gameStorage.setItem=__write');g.week();
 const progressed=g.run('JSON.stringify(S)');g.run('save()');assert.ok(g.store['bdt-v1']===progressed,'sauvegarde Monde inchangée');
 g.run('save()');assert.ok(g.run('JSON.stringify(S)')===progressed,'écriture native idempotente');
});
test('confirmed import preserves active career if primary write fails',()=>{
 const g=h.fork(initial),different=h.fresh(13),before=g.run('JSON.stringify(S)'),stored=g.store['bdt-v1'];
 g.ctx.__doc=JSON.stringify(h.data(different,'createSaveDocument()'));
 g.run('pendingSave=parseSaveDocument(__doc);globalThis.__write=gameStorage.setItem;gameStorage.setItem=(k,v)=>{if(k==="bdt-v1")throw Error("test quota");return __write(k,v)}');
 assert.equal(g.run('confirmSaveImport()'),false);assert.ok(g.run('JSON.stringify(S)')===before,'état Monde inchangé');assert.ok(g.store['bdt-v1']===stored,'sauvegarde Monde inchangée');assert.equal(g.run('lastSaveError'),true);
});
test('generated checkpoint integrity detects edited data',()=>{
 const state={sourceDigest:h.sources().digest,scenario:'reference',document:h.data(initial,'createSaveDocument()'),rng:h.rng(initial)};
 const envelope=h.seal(state);assert.deepEqual(h.unseal(envelope),state);envelope.payload.document.state.club=13;assert.throws(()=>h.unseal(envelope),/Corrupt test checkpoint/);
});
test('checkpoint provenance covers the actual World engine and harness',()=>{const files=h.sources().hashes;for(const name of ['native/engine/worker.cjs','native/engine/world-career.cjs','native/engine/world-editions.cjs','tests/monde-harness.cjs'])assert.match(files[name],/^[a-f0-9]{64}$/);});
test('test checkpoint from other sources is rejected',()=>assert.throws(()=>h.unseal(h.seal({sourceDigest:'obsolete'})),/sources changed/));
test('invalid test RNG sidecar cannot silently change replay',()=>{for(const value of [-1,NaN,Infinity,2**32])assert.throws(()=>h.setRng(initial,{value,calls:0}));});
// One actual completed championship supplies all following integration fixtures.
const finished=h.fork(initial);keepers.add(finished);let turns=0;while(finished.run('S.phase')!=='ended'){assert.ok(++turns<=80);finished.week();}
assert.equal(finished.run('S.round'),46);assert.equal(finished.run('S.history.length'),finished.run('S.worldMode.fixtures.length'));
const ended=h.data(finished),endRng=h.rng(finished),candidate=h.data(finished,'S.clubs.filter(c=>c.id!==S.club).map(c=>managerMobilityDecision(c.id)).find(x=>x.accepted)');assert.ok(candidate);
function endGame(){return h.restore(h.data(finished,'createSaveDocument()'),endRng);}
function pendingGame(){const g=endGame();assert.equal(g.run('managerMobilityApply('+candidate.clubId+')'),true);assert.equal(g.run('managerMobilityAccept("job-1-'+candidate.clubId+'")'),true);return g;}
test('financial refusal on acceptance changes no money or employer',()=>{const g=endGame();g.run('managerMobilityApply('+candidate.clubId+');S.clubs['+candidate.clubId+'].cash=-1');const before=g.run('JSON.stringify(S)');assert.equal(g.run('managerMobilityAccept("job-1-'+candidate.clubId+'")'),false);assert.ok(g.run('JSON.stringify(S)')===before,'état Monde inchangé');});
test('season error restores full state and memory storage',()=>{const g=pendingGame(),before=g.run('JSON.stringify(S)'),stored=g.store['bdt-v1'];g.run('managerMobilityOnSeasonStart=()=>{throw Error("test interrupted transition")}');assert.throws(()=>g.command('next_season',{confirmed:true}),/test interrupted transition/);assert.ok(g.run('JSON.stringify(S)')===before,'état Monde inchangé');assert.ok(g.store['bdt-v1']===stored,'sauvegarde Monde inchangée');assert.equal(g.run('validatingStartup'),false);});
test('pending move reload is exact and duplication is refused',()=>{const g=h.fork(pendingGame());const before=g.run('JSON.stringify(S)');assert.equal(g.run('managerMobilityAccept("job-1-'+candidate.clubId+'")'),false);assert.equal(g.run('managerMobilityApply(13)'),false);assert.ok(g.run('JSON.stringify(S)')===before,'état Monde inchangé');});
test('long campaign handover oracle compares all clubs to a native control',()=>{const stats=h.newStats();const g=h.moveCompared(endGame(),candidate.clubId,stats);assert.equal(g.run('S.season'),2);assert.equal(g.run('S.club'),candidate.clubId);assert.equal(stats.failed.length,0);assert.equal(stats.reloads,2);});
test('checksum and ownership corruption rejected before import',()=>{
 const good=h.data(pendingGame(),'createSaveDocument()');
 for(const edit of [d=>d.checksum='00000000',d=>d.state.managerMobility.pending.toClub=d.state.club,d=>d.state.managerMobility.archives.push({clubId:0,season:1,ledger:[],boardHistory:[],academyInvestment:-1}),d=>d.state.clubs[1].players.push(h.clone(d.state.clubs[0].players[0]))]){
  const d=h.clone(good);edit(d);const blank=context();blank.ctx.__bad=JSON.stringify(d);assert.throws(()=>blank.run('parseSaveDocument(__bad)'));assert.equal(blank.run('S'),null);blank.close();
 }
});
test('legacy without mobility stays opt-in after native import',()=>{const legacy=h.clone(ended);delete legacy.managerMobility;delete legacy.managerMobilityVersion;const g=context(legacy);assert.equal(g.run('managerMobilityActive()'),false);assert.equal(g.run('S.managerMobility'),undefined);assert.ok(g.run('parseSaveDocument(JSON.stringify(createSaveDocument()))'));g.close();});
test('same saved state and explicit test RNG replay the same transition',()=>{const a=pendingGame(),b=h.fork(a);a.run('advanceSeason();finishRound()');b.run('advanceSeason();finishRound()');assert.ok(JSON.stringify(h.data(a))===JSON.stringify(h.data(b)),'reprise identique de la transition Monde');});
test('report gate refuses missing, partial or mixed-source campaigns',()=>{
 const {summarize}=require('../ci/career-resilience-report.cjs');
 assert.throws(()=>summarize([]));
 function report(scenario){return {scenario,status:'passed',completedSeasons:15,testedCommit:'synthetic-report-test-only',sourceDigest:'a'.repeat(64),sourceUnchanged:true,stats:{passed:1,failed:[],byCheck:{unit:1},reloads:1},annual:Array.from({length:15},(_,i)=>({season:i+1,nativeMatches:187,champion:0,investment:0,clubs:Array.from({length:14},(_,id)=>({id,cash:1,debt:0,coachChanges:0}))})),moves:[],adjustments:[],finalSaveBytes:1};}
 const sample=['reference','deficit','rotation'].map(report);assert.equal(summarize(sample).seasons,45);
 for(const mutate of [r=>r[0].status='partial',r=>r[1].sourceDigest='b'.repeat(64),r=>r[2].stats.failed=['failure'],r=>r[0].stats.passed=99,r=>r[0].annual.pop()]){const changed=h.clone(sample);mutate(changed);assert.throws(()=>summarize(changed));}
 assert.throws(()=>summarize(sample,'another-commit'));
});
console.log('CAREER RESILIENCE CONTRACTS '+JSON.stringify({passed:results.length,checks:results,scope:'native functions with generated fixtures; RNG sidecar only for tests'}));

h.releaseExcept();
