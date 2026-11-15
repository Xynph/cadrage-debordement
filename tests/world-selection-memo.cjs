'use strict';
const assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');
const testStarted=performance.now();
const fingerprintProbe=require('./helpers/position-fingerprint-probe.cjs');
function sample(positionMemo){
 const h=context(827381,{club:0,bridge:{positionMemo}}),started=performance.now();
 try{
  h.deferSaves();
  assert.equal(h.run('S.worldMode.version'),5);
  assert.equal(h.run('S.leagueDetail??null'),null,'Monde natif avec tous les championnats détaillés');
  const before=h.run('JSON.stringify(S)'),seed=h.seed();
  h.run(`var selectionReads=0,originalSkills=new Map();
   for(const p of club().players){originalSkills.set(p,p.skills);p.skills=new Proxy(p.skills,{get(target,key){if(Object.hasOwn(ATTR,key))selectionReads++;return Reflect.get(target,key);}});}
   var selected=buildSheet(club()),reads=selectionReads;
   selectionReads=0;buildSheet(club());var nextReads=selectionReads;
   try{buildSheet(null);}catch(e){}
   selectionReads=0;buildSheet(club());var afterFailureReads=selectionReads;
   for(const p of club().players)p.skills=originalSkills.get(p);
   for(let i=0;i<50;i++)buildSheet(club());`);
  // Remplir effectivement le cache de portée avant une erreur. Le faux accès
  // équipe appelle le vrai derive puis échoue ; aucun joueur World n'est modifié.
  h.run(`var lateProbe={...club().players[0],skills:Object.fromEntries(Object.keys(ATTR).map(k=>[k,20]))};
   var lateBefore=JSON.stringify(nativePositionAptitudes.project(lateProbe));
   var lateDerived=false,lateTeam=Object.create(club());
   Object.defineProperty(lateTeam,'players',{get(){nativePositionAptitudes.project(lateProbe);lateDerived=true;throw Error('selection-late-error')}});`);
  assert.throws(()=>h.run('buildSheet(lateTeam)'),/selection-late-error/);
  assert.equal(h.run('lateDerived'),true,'derive appelé dans la portée avant l’erreur');
  h.run('for(const key of Object.keys(ATTR))lateProbe.skills[key]=99;var lateAfter=JSON.stringify(nativePositionAptitudes.project(lateProbe))');
  assert.notEqual(h.run('lateAfter'),h.run('lateBefore'),'après erreur tardive, la qualité modifiée doit invalider la projection');
  const selectionStarted=performance.now();h.run('for(let i=0;i<250;i++)buildSheet(club())');
  const selectionMs=Math.round((performance.now()-selectionStarted)*10)/10;
  assert.ok(h.run('JSON.stringify(S)')===before,'une sélection conserve tout l’état');
  assert.equal(h.seed(),seed,'aucun tirage de sélection');
  assert.ok(h.run('nextReads>0&&afterFailureReads>0'),'pas de cache persistant entre deux sélections ni après une erreur');
  const reads=h.run('reads'),sheet=h.run('JSON.stringify(selected)');
  const fingerprint=fingerprintProbe(h);
  assert.equal(fingerprint.malformedRejected,true,'une spécialisation active malformée reste refusée');
  h.toMatch();
  const fixtureId=h.run('CDWorldCareer.userFixture(S).id');
  h.week(1);
  h.ctx.selectionFixtureId=fixtureId;
  assert.equal(h.run('S.history.filter(r=>r.fixtureId===selectionFixtureId).length'),1,'la parité couvre une vraie semaine de match du club');
  const state=h.run('JSON.stringify(S)'),stored=h.store['bdt-v1'];
  assert.ok(stored===state,'vraie sauvegarde complète matérialisée');
  return {state,stored,seed:h.seed(),sheet,reads,fingerprint,selectionMs,milliseconds:Math.round((performance.now()-started)*10)/10};
 }finally{h.close();}
}
const reference=sample(false),memo=sample(true);
assert.ok(memo.state===reference.state,'même état Monde complet après la semaine');
assert.ok(memo.stored===reference.stored,'même sauvegarde');
assert.equal(memo.sheet,reference.sheet,'mêmes titulaires et remplaçants');
assert.equal(memo.seed,reference.seed,'même RNG');
assert.ok(memo.reads<reference.reads,'le cache doit réellement supprimer des relectures de qualités');
assert.deepEqual(memo.fingerprint.sequence,reference.fingerprint.sequence,'mêmes projections après mutations, remplacements et désactivation des bonus');
assert.ok(memo.fingerprint.devReads<reference.fingerprint.devReads,'les contrôles exacts entre appels doivent relire moins souvent la spécialisation');
console.log(JSON.stringify({passed:true,scope:'world-champ, tous détaillés',selections:250,reference:{fingerprintDevReads:reference.fingerprint.devReads,reads:reference.reads,selectionMs:reference.selectionMs,totalMs:reference.milliseconds},memo:{fingerprintDevReads:memo.fingerprint.devReads,reads:memo.reads,selectionMs:memo.selectionMs,totalMs:memo.milliseconds},wallSeconds:Math.round((performance.now()-testStarted)/100)/10,maxRssKb:process.resourceUsage().maxRSS}));
