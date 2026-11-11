'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./france-harness.cjs'),systems=require('../native/engine/native-systems.cjs');
function world(mode='world'){
 const h=context(),base=require('../native/engine/world-registry.json');
 h.ctx.nativeWorldRegistryText=JSON.stringify(base);
 if(mode==='world-pacific'){
  const {extendWorldRegistry}=require('../native/engine/world-pacific-registry.cjs');
  h.ctx.nativeWorldPacificRegistryText=JSON.stringify(extendWorldRegistry(base,require('../native/engine/world-pacific-extension.json')));
 }
 h.run(require('../native/engine/world-vm.cjs').bootstrap());
 h.run(systems.bootstrap());
 h.run(mode==='world-pacific'?"CDWorldCareer.start(58,'world-pacific');":'CDWorldCareer.start(30);');
 return h;
}
test('Sauvegarde mondiale : les seuls face-à-face bénéficient de la borne de leur édition',()=>{
 const h=world('world-pacific');
 h.run(`S.interclubWorld=CDInterclubWorld.state(S);
 for(const a of S.clubs)for(const b of S.clubs){
  if(a.id>=b.id)continue;
  S.interclubWorld.pairs[a.id+':'+b.id]={a:a.id,b:b.id,games:1,winsA:1,winsB:0,draws:0,tension:20,years:[1],lastWinner:a.id,lastSeason:1};
 }`);
 assert.equal(h.run('Object.keys(S.interclubWorld.pairs).length'),2278);
 assert.doesNotThrow(()=>h.run('validateCareer(S)'));
 assert.throws(()=>h.run('S.otherCollection={...S.interclubWorld.pairs};safeTree(S)'),/incohérentes/);
 assert.throws(()=>h.run('S.otherCollection=Array(2001).fill(null);safeTree(S)'),/incohérentes/);
 h.run('delete S.otherCollection');
 assert.throws(()=>h.run("S.interclubWorld.pairs['0:68']=null;safeTree(S)"),/incohérentes/);
 h.run("delete S.interclubWorld.pairs['0:68']");
 assert.throws(()=>h.run("S.interclubWorld.pairs['0:1'].games++;validateCareer(S)"),/face-à-face/);
});
test('Domaines monde : note et conférence semaine35, quatre classements distincts',()=>{
 const h=world();h.run('S.round=35;S.worldMode.week=35');
 // Contrôle des domaines sur une horloge de fixture. Aucune saison jouée n'est revendiquée.
 h.run(`const notes35=(${require('../native/engine/coach-notes.cjs').factory.toString()})();notes35.execute('coach_note_save',{context:{season:S.season,week:35,club:S.club},target:'career',text:'Préparer les prochaines rencontres.'});notes35.validate(S);`);
 assert.equal(h.run('S.coachNotebook.entries[0].week'),35);
 h.run(`const press35=(${require('../native/engine/press.cjs').factory.toString()})();var journal35=press35.project();`);
 const ids=JSON.parse(h.run('JSON.stringify(journal35.journal.divisions.map(d=>d.id))'));for(const id of ['elite','accession','prem','urc'])assert.ok(ids.includes(id),id);
 h.run(`press35.execute('press_conference',{context:{season:S.season,week:35,club:S.club},answers:journal35.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});press35.validate(S);`);
 assert.ok(h.run('S.pressConference.history.every(h=>h.week===35)'));
 const before=h.run('JSON.stringify(S.coachNotebook)');assert.throws(()=>h.run("notes35.execute('coach_note_save',{context:{season:S.season,week:34,club:S.club},target:'career',text:'Contexte périmé.'})"));assert.equal(h.run('JSON.stringify(S.coachNotebook)'),before);
 assert.throws(()=>h.run('S.coachNotebook.entries[0].week=47;notes35.validate(S)'),/note|carnet/i);
});
test('Domaines monde : résultat européen canonique, déduplication et borne1200',()=>{
 const h=world();h.run(`S.round=35;S.worldMode.week=35;var domainResult={fixtureId:'world-domain-pool35',competitionId:'champions',leagueId:'prem',season:1,phase:'pool',round:35,competitionRound:4,week:35,pair:[30,40],score:[17,17],tries:[1,1],stats:[makeStats(),makeStats()]};S.history.push(domainResult);worldRecordResult(domainResult);`);
 assert.equal(h.run('S.interclubWorld.events.at(-1).phase'),'pool');assert.equal(h.run('S.interclubWorld.events.at(-1).fixtureId'),'world-domain-pool35');
 assert.equal(h.run("CDMediaNativeAdapter.collect(S).find(e=>e.id===domainResult.fixtureId).facts.divisionId"),'champions');
 const count=h.run('S.interclubWorld.seasonMatches');h.run('worldRecordResult(domainResult)');assert.equal(h.run('S.interclubWorld.seasonMatches'),count);
 assert.throws(()=>h.run(`S.interclubWorld.seen.push('1:invented-fixture');S.interclubWorld.seasonMatches++;nativeSystems.validate(S)`),/rencontres mondiales/);
 assert.throws(()=>h.run(`S.interclubWorld.seen.pop();S.interclubWorld.seasonMatches--;S.interclubWorld.events.at(-1).home++;nativeSystems.validate(S)`),/non corroboré/);
 h.run(`S.interclubWorld.events.at(-1).home--;S.history.push(...Array.from({length:1199},(_,i)=>({fixtureId:'fixture-'+i})));S.interclubWorld.seen=S.history.map(r=>'1:'+r.fixtureId);S.interclubWorld.seasonMatches=1200;nativeSystems.validate(S)`);
 assert.throws(()=>h.run(`S.history.push({fixtureId:'fixture-over'});S.interclubWorld.seen.push('1:fixture-over');S.interclubWorld.seasonMatches=1201;nativeSystems.validate(S)`),/registre des rencontres/);
});
test('Domaines monde : staffsemaine35 et projection manager46semaines',()=>{
 const h=world();h.run(`S.round=35;S.worldMode.week=35;S.nativeSupport={version:1,meeting:{context:{season:1,week:35,club:S.club},plan:Object.keys(CDStaffMeetingV65.OPTIONS)[0]}};nativeSystems.validate(S);`);
 assert.equal(h.run(`(${require('../native/engine/manager-career.cjs').factory.toString()})().project().weeksPerSeason`),46);
});
test('Domaines monde : objectif de conseil semaine 46 et bureau archivé',()=>{
 const h=world();h.run(`S.round=35;S.worldMode.week=35;var boardContext={season:1,week:35,club:S.club};nativeSystems.execute('club_board_objective',{context:boardContext,type:'wins',target:3,deadline:46});nativeSystems.validate(S);`);
 assert.equal(h.run('S.nativeBoardCalendar.objectives[0].deadline'),46);
 assert.throws(()=>h.run(`nativeSystems.execute('club_board_objective',{context:boardContext,type:'rank',target:3,deadline:47})`),/Objectif invalide/);
 h.run(`S.nativeStrategyOffices={version:1,clubs:{'31':{nativeBoardCalendar:{...S.nativeBoardCalendar,clubId:'club-31',objectives:S.nativeBoardCalendar.objectives.map(o=>({...o}))}}}};nativeSystems.validate(S);`);
 assert.throws(()=>h.run(`S.nativeStrategyOffices.clubs['31'].nativeBoardCalendar.objectives[0].deadline=47;nativeSystems.validate(S)`),/Objectif de direction invalide/);
});
test('Domaines monde : formation de base conservée, activationEspoirs refusée sans mutation',()=>{
 const h=world();h.run(`const academyWorld=(${require('../native/engine/academy.cjs').factory.toString()})();var academyModel=academyWorld.project()`);
 assert.equal(h.run('academyModel.available'),false);assert.equal(h.run('academyModel.baseAvailable'),true);assert.match(h.run('academyModel.reason'),/Espoirs|championnat/i);
 const before=h.run('JSON.stringify(S)');assert.throws(()=>h.run("academyWorld.execute('academy_activate',{context:{season:S.season,week:S.round,club:S.club},confirmed:true})"),/Espoirs|championnat/);assert.equal(h.run('JSON.stringify(S)'),before);assert.ok(h.run('S.development.academy.length')>0);
});
