'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const game=context(),run=game.run;
let passed=0;
function check(label,fn){fn();passed++;console.log('PASS '+label)}
check('module natif charge avec moteur V48',()=>assert.equal(run('typeof CDCoachOpportunities.snapshot'),'function'));
run('start(0)');
check('bureau manager montre les bancs sous pression',()=>{const html=run('worldOfficePanel()');assert.ok(html.includes('Bancs adverses sous pression'));assert.equal((html.match(/Risque \d+\/100/g)||[]).length>=3,true)});
check('le club du joueur est exclu',()=>{const r=run('CDCoachOpportunities.snapshot(S.clubs,S.worldManagement.clubInfo,S.club)');assert.equal(r.length,13);assert.equal(r.some(x=>x.id===0),false)});
check('tri de risque etucune offre fabriquee',()=>{const r=run('CDCoachOpportunities.snapshot(S.clubs,S.worldManagement.clubInfo,S.club)');assert.ok(r.every((x,i)=>i===0||r[i-1].risk>=x.risk));assert.ok(!run('worldOfficePanel()').includes('Accepter une offre'))});
check('aucune modification des donnees par observatoire',()=>{const before=run('JSON.stringify(S)');run('worldOfficePanel()');assert.equal(run('JSON.stringify(S)'),before)});
check('risque identique au calcul natif pour chaque club',()=>{const a=run('CDCoachOpportunities.snapshot(S.clubs,S.worldManagement.clubInfo,S.club)');for(const x of a){const v=run('CDCoachMarket.dismissalRisk({confidence:'+x.confidence+',consecutiveLosses:'+run('worldClub('+x.id+').consecutiveLosses')+'}).risk');assert.equal(x.risk,v)}});
check('defaite change un signal sans creer de poste',()=>{run('worldClub(1).coachConfidence=9;worldClub(1).consecutiveLosses=4');const r=run('CDCoachOpportunities.snapshot(S.clubs,S.worldManagement.clubInfo,S.club)');assert.equal(r[0].id,1);assert.equal(r[0].critical,true)});
check('incoherence du monde refusee',()=>{run('worldClub(1).coachConfidence=200');assert.throws(()=>run('CDCoachOpportunities.snapshot(S.clubs,S.worldManagement.clubInfo,S.club)'));run('worldClub(1).coachConfidence=55')});
check('sauvegarde native compatible sans nouveau champ',()=>{assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);assert.equal(run('S.coachCareer===undefined'),true);assert.equal(run('S.coachContracts===undefined'),true)});
check('ancien format de carriere accepte',()=>{const s=JSON.parse(run('JSON.stringify(S)'));delete s.worldManagement;delete s.worldVersion;const old=context(s);assert.equal(old.run('worldActive()'),false);assert.equal(old.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true)});
check('une journee de vrais matchs laisse le panneau valide',()=>{run('finishRound()');assert.equal(run('S.round'),1);assert.ok(run('worldOfficePanel()').includes('Bancs adverses sous pression'));assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true)});
console.log('V58 NATIVE OBSERVATORY PASS '+passed+' / '+passed);
