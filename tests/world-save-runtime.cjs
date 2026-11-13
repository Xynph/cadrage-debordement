'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict');
const {test}=require('node:test');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');

// Même checksum UTF-16 que saveChecksum : chaque fichier altéré a une somme
// valide. La structure et les faits de la carrière doivent faire échouer l’import.
function checksum(state){
 const text=JSON.stringify(state);let hash=2166136261;
 for(let i=0;i<text.length;i++)hash=Math.imul(hash^text.charCodeAt(i),16777619);
 return (hash>>>0).toString(16).padStart(8,'0');
}
function accepted(handle,command,payload={}){
 const response=handle(command,payload);assert.equal(response.ok,true,command+' : '+response.error);return response.model;
}
function exportText(handle){return accepted(handle,'export').meta.exportText;}
function rejectedImport(handle,baseline,change,expected){
 const doc=JSON.parse(baseline);assert.equal(checksum(doc.state),doc.checksum);
 const original=doc.checksum;change(doc.state);doc.checksum=checksum(doc.state);
 assert.notEqual(doc.checksum,original,'L’attaque modifie effectivement le contenu');
 const response=handle('import',{text:JSON.stringify(doc)});
 // Restaure le témoin si la régression laisse passer cette attaque afin que
 // les cas suivants restent indépendants ; l’assertion conserve le vrai verdict.
 if(response.ok)accepted(handle,'import',{text:baseline});
 assert.equal(response.ok,false,'Le worker a accepté un export altéré à checksum valide');
 assert.match(response.error,expected);
 assert.equal(JSON.parse(exportText(handle)).checksum,original,'L’import refusé doit conserver la carrière ouverte');
}

// À appeler avec le checkpoint réellement joué de world-worker-season.cjs.
// Réutilise la saison complète pour éviter de la simuler deux fois en CI.
function assertWorldKnockoutImports(handle,baseline){
 const {state}=JSON.parse(baseline);
 const completed=state.history.find(r=>r.competitionId==='champions'&&['r16','quarter','semi','final'].includes(r.phase)&&r.decision);
 assert.ok(completed,'Un résultat européen à élimination directe a réellement été joué');
 const match=s=>s.history.find(r=>r.fixtureId===completed.fixtureId);
 const tests=[
  ['vainqueur',s=>{const r=match(s);r.winner=r.pair.find(id=>id!==r.winner);},/résultat|départage|vainqueur|score/i],
  ['méthode de départage',s=>{const r=match(s);r.decision.method=r.decision.method==='score'?'tries':'score';},/résultat|départage|décision|score|critère/i],
  ['score incompatible avec les statistiques',s=>{const r=match(s);r.score[0]+=r.score[0]<250?1:-1;},/résultat|score|statistiques|classement/i],
  ['phase hors règlement',s=>{match(s).phase='friendly';},/résultat|phase|calendrier|incohérente/i],
 ];
 const failures=[];
 for(const [label,change,expected] of tests)try{rejectedImport(handle,baseline,change,expected);}catch(error){failures.push(Error(label+': '+error.message,{cause:error}));}
 if(failures.length)throw new AggregateError(failures,failures.map(x=>x.message).join('\n'));
 return tests.length;
}

function assertWorldArchiveImports(handle,baseline){
 const {state}=JSON.parse(baseline);assert.equal(state.season,2);assert.ok(state.worldMode.yearbook.length);
 rejectedImport(handle,baseline,s=>{s.worldMode.yearbook[0].europe.champions.pools=[[999]];},/poules archivées/i);
 rejectedImport(handle,baseline,s=>{delete s.worldMode.yearbook[0].draws['pool:champions'];},/tirage/i);
 return 2;
}

if(require.main===module)test('Sauvegarde mondiale réelle : profil étranger et contexte du match en cours',async t=>{
 const tempRoot=fs.realpathSync(process.env.CD_WORLD_TEST_ROOT||os.tmpdir());
 const scratch=fs.realpathSync(fs.mkdtempSync(path.join(tempRoot,'cd-world-save-runtime-')));
 assert.equal(path.dirname(scratch),tempRoot);assert.match(path.basename(scratch),/^cd-world-save-runtime-[a-z0-9]+$/i);
 let bridge,serial=0;
 try{
  bridge=createBridge({dataDir:path.join(scratch,'prem'),seed:827381,now:1794178800000});
  const handle=(command,payload={})=>bridge.handle({id:++serial,command,payload});
  let model=settleClubMeetings(accepted(handle,'new_career',{mode:'world',club:30}),(command,payload)=>accepted(handle,command,payload));
  const original=exportText(handle),originalDoc=JSON.parse(original);
  accepted(handle,'import',{text:original});assert.equal(JSON.parse(exportText(handle)).checksum,originalDoc.checksum);
  const selected=originalDoc.state.clubs[30].players.find(p=>p.worldRatingsVersion===1&&p.worldProfile&&Object.keys(p.hiddenTraitsV2).length);
  assert.ok(selected,'Le club choisi a un profil étranger lié au registre réel');
  const player=s=>s.clubs[30].players.find(p=>p.id===selected.id);
  for(const [label,change,expected] of [
   // A saved name belongs to the career (docs/noms-inventes-branchement-20261111.md); markup is still refused.
   ['nom balisé',p=>{p.name='<b>'+p.name+'</b>';},/texte non autorisé|joueur|identité|nom|profil/i],
   ['preuve de référence',p=>{p.worldProfile={...p.worldProfile,preuveFabriquée:true};},/référence|profil/i],
   ['preuve manquante',p=>{delete p.worldProfile;},/référence|profil|identité/i],
   ['date de naissance',p=>{p.birthDate=p.birthDate==='1999-01-01'?'1999-01-02':'1999-01-01';},/joueur|naissance|profil|âge/i],
   ['trait initial',p=>{const key=Object.keys(p.hiddenTraitsV2)[0];p.hiddenTraitsV2[key]=p.hiddenTraitsV2[key]===1?2:1;},/traits/i],
  ])await t.test(label,()=>rejectedImport(handle,original,s=>change(player(s)),expected));
  await t.test('nom renommé conservé',()=>{
   const doc=JSON.parse(original);player(doc.state).name+=' Test';doc.checksum=checksum(doc.state);
   accepted(handle,'import',{text:JSON.stringify(doc)});
   assert.equal(player(JSON.parse(exportText(handle)).state).name,selected.name+' Test');
   accepted(handle,'import',{text:original});assert.equal(JSON.parse(exportText(handle)).checksum,originalDoc.checksum);
  });
  await t.test('qualification de première ligne',()=>rejectedImport(handle,original,s=>{
   const prop=s.clubs[30].players.find(p=>p.pos==='Pilier gauche'&&!s.lineup.includes(p.id)&&!s.reserves.includes(p.id));assert.ok(prop);prop.pos='Pilier droit';
  },/profil|position|qualification/i));
  await t.test('joueur sous contrat aussi agent libre',()=>rejectedImport(handle,original,s=>{
   const copy={...player(s),price:1000,contractEnd:null};s.economy.freeAgents.push(copy);
  },/déjà sous contrat|dupliqué/i));
  for(let n=0;!model.next&&n<4;n++)model=settleClubMeetings(accepted(handle,'finish_round'),(command,payload)=>accepted(handle,command,payload));
  assert.ok(model.next,'Un match est au calendrier pour le club');
  accepted(handle,'begin_match');const live=exportText(handle);
  accepted(handle,'import',{text:live});assert.equal(JSON.parse(exportText(handle)).checksum,JSON.parse(live).checksum);
  await t.test('fixtureId en direct',()=>rejectedImport(handle,live,s=>{s.live.worldContext.fixtureId+='-intrus';},/match|calendrier|contexte|rencontre/i));
 }finally{
  if(bridge)bridge.close();
  fs.rmSync(scratch,{recursive:true,force:true});
 }
});

if(require.main===module)test('Élimination mondiale : prolongation et tirs issus du moteur, falsifications refusées',()=>{
 const h=require('./france-harness.cjs').context();
 h.ctx.nativeWorldRegistryText=JSON.stringify(require('../native/engine/world-registry.json'));
 h.run(require('../native/engine/world-vm.cjs').bootstrap());
 h.run(`CDWorldCareer.start(0);
  var fixtureTest=CDWorldCareer.userFixture(S);
  while(!fixtureTest){CDWorldCareer.finishWeek();fixtureTest=CDWorldCareer.userFixture(S);}
  var gameTest=createRugbyMatch(nextMatch());
  fixtureTest={...fixtureTest,competitionId:'champions',phase:'final'};gameTest.worldContext={...fixtureTest};
  gameTest.minute=40;endFlowPeriod(gameTest);resumeFlowHalf(gameTest);
  gameTest.minute=80;endFlowPeriod(gameTest);CDWorldValidation.live(gameTest,fixtureTest);
  gameTest.minute=90;endFlowPeriod(gameTest);CDWorldValidation.live(gameTest,fixtureTest);
  gameTest.minute=100;endFlowPeriod(gameTest);validateRestartState(gameTest,S);validateFlowState(gameTest,S);CDWorldValidation.live(gameTest,fixtureTest);`);
 assert.equal(h.run('gameTest.decision.method'),'shootout');assert.equal(h.run('gameTest.score.join()'),'0,0');
 for(const [mutation,message] of [
  ['bad.decision.shootout.attempts[0].side=1-bad.decision.shootout.attempts[0].side',/ordre des tirs/],
  ["bad.decision.shootout.kickers[0][0]='buteur-absent'",/buteur inéligible/],
  ['bad.knockout.firstEnd=81',/prolongation incohérente/],
 ])assert.throws(()=>h.run(`{const bad=JSON.parse(JSON.stringify(gameTest));${mutation};CDWorldValidation.live(bad,fixtureTest);}`),message);
});

module.exports={assertWorldKnockoutImports,assertWorldArchiveImports};
