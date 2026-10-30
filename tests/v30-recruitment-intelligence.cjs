'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const eq=(a,b)=>assert.deepEqual(JSON.parse(JSON.stringify(a)),JSON.parse(JSON.stringify(b)));

// Analyse pure du besoin : postes de première ligne non interchangeables.
const t=context(),run=t.run;
run('start(0)');
assert.equal(run('S.recruitmentIntelVersion'),1);
const state=run('JSON.stringify(S)');
assert.equal(run('recruitmentNeeds().length'),15);
assert.ok(run('recruitmentNeeds().every(n=>n.score>=0&&n.score<=100)'));
assert.ok(run('recruitmentNeedsPanel().includes("Diagnostic de l’effectif")'));
assert.ok(run('recruitmentPanel().includes("Fourchette indicative")'));
assert.equal(run('JSON.stringify(S)'),state,'Dashboard and recommendations must be read-only');
run('var c=club(),beforeLeft=recruitmentNeed(c,0),beforeRight=recruitmentNeed(c,2);c.players=c.players.filter(p=>p.pos!==POS[0])');
assert.equal(run('recruitmentNeed(c,0).healthy'),0);
assert.ok(run('recruitmentNeed(c,0).score>beforeLeft.score'));
assert.equal(run('recruitmentNeed(c,2).healthy'),run('beforeRight.healthy'),'Right prop cover must survive left-prop removal');
// Contrats + relève réelle atténuent la priorité sans ajouter un pro artificiel.
run('var depth=recruitmentNeed(c,1),hook=c.players.find(p=>p.fam===1);hook.contractEnd=S.season');
assert.ok(run('recruitmentNeed(c,1).score>=depth.score'));
run('var academy=academyPlayer(S.club,1,S.season,42);academy.dev.potential=99;S.development.academy.push(academy);var withYouth=recruitmentNeed(c,1)');
assert.ok(run('withYouth.youth>0'));
assert.ok(run('withYouth.score<=recruitmentNeed({...c,id:3},1).score'));

// Information incomplète : l'algorithme ne doit pas utiliser les véritables
// skills/rating/potentiel d'un agent libre sans rapport.
const unknown=context(),u=unknown.run;
u('start(0);var p=S.market[0];var publicBefore=recruitmentEvidence(p);var noteBefore=publicBefore.noteMin+":"+publicBefore.noteMax;var level=roleNote(p)');
assert.equal(u('publicBefore.seen'),false);
u('p.rating=99;p.dev.potential=99;for(const k of Object.keys(p.skills))p.skills[k]=99');
assert.equal(u('recruitmentEvidence(p).noteMin+":"+recruitmentEvidence(p).noteMax'),u('noteBefore'));
u('inspectCareerPlayer(p.id)');
assert.ok(u('modal.includes("Joueur non observé")'));
assert.equal(u('modal.includes("99 / 100")'),false);
// Rapport daté : davantage d'information, mais une fourchette et un risque de vieillissement.
u('S.manager.reports.unshift({id:"report-test",mission:"mission-test",playerId:p.id,name:p.name,pos:p.pos,family:p.fam,age:p.age,note:82,potential:90,salary:p.salary,price:p.price,grade:"A",week:S.economy.week,season:S.season})');
assert.equal(u('recruitmentEvidence(p).seen'),true);
assert.equal(u('recruitmentEvidence(p).noteMin'),80);
assert.equal(u('recruitmentEvidence(p).potentialMax'),95);
u('S.economy.week+=20');
assert.equal(u('recruitmentEvidence(p).stale'),true);
assert.ok(u('recruitmentEvidence(p).noteMax>84'));
// Une mission coûte 5 000 €, dure deux journées et débouche sur un rapport.
// Ce n'est PAS une signature et aucun contrat n'est signé par le diagnostic.
const scout=context(),s=scout.run;
s('start(0);var target=S.market.find(p=>p.fam===0);S.market=[target];S.economy.freeAgents=[];var cash=club().cash;var count=club().players.length');
assert.equal(s('createScoutMission(0,40,10000000,100000)'),true);
assert.equal(s('club().cash'),s('cash-5000'));
assert.equal(s('club().players.length'),s('count'));
s('S.economy.week++;managerWeek();S.economy.week++;managerWeek()');
assert.ok(s('S.manager.reports.some(r=>r.playerId===target.id)'));
assert.equal(s('club().players.length'),s('count'));
assert.equal(s('recruitmentEvidence(target).seen'),true);

// Les prévisions financières guident sans agir et les montants restent fictifs.
const finance=context(),f=finance.run;
f('start(0);var p=S.market[0],originalCash=club().cash,report=recruitmentFinance(club(),p)');
assert.ok(f('report.weeks>=6&&report.weeks<=29'));
assert.equal(f('report.fee'),f('p.price'));
assert.equal(f('report.commitment'),f('p.price+p.salary*report.weeks'));
f('p.price=club().cash+1');
assert.equal(f('recruitmentFinance(club(),p).available'),false);
assert.equal(f('recruitmentFinance(club(),p).sustainable'),false);
f('recruitmentNeedsPanel()');
assert.equal(f('club().cash'),f('originalCash'));
f('p.price=0');
const rec=f('recruitmentTargets().every(x=>x.reasons.length>=2&&x.evidence.noteMin<=x.evidence.noteMax)');
assert.equal(rec,true);

// Décision IA : le besoin réel et le budget commandent l'achat sur le marché.
// Garde-fous : un maximum de deux signatures par fenêtre, aucun accord humain
// automatique, pas d'achat pendant une rencontre, aucun doublon.
const ai=context(),a=ai.run;
a('start(0);var me=club().cash;S.round=13;var buyer=S.clubs[1],budget=buyer.cash,headcount=buyer.players.length;buyer.players=buyer.players.filter(p=>p.pos!==POS[0]);var pool=S.market.length');
const bought=a('aiRecruitmentWeek()');
assert.ok(bought>=1&&bought<=2);
assert.equal(a('buyer.players.length>headcount-2'),true);
assert.equal(a('club().cash'),a('me'));
assert.ok(a('buyer.cash<=budget'));
assert.equal(a('aiRecruitmentWeek()'),0,'A window cannot buy twice');
assert.ok(a('S.economy.aiRecruitmentWindow==="1:13"'));
assert.ok(a('S.market.length<=pool'));
assert.ok(a('!!createSaveDocument()'));
// Un match engagé interdit les décisions de marché automatiques.
const locked=context(),l=locked.run;
l('start(0);S.round=13;beginMatch();pauseMatch()');
assert.equal(l('aiRecruitmentWeek()'),0);

// Anciennes sauvegardes V29, y compris en direct, rechargées sans mutation.
const legacy=context(),old=legacy.run;
old('start(0);beginMatch();pauseMatch()');
const saved=JSON.parse(old('JSON.stringify(S)'));
delete saved.recruitmentIntelVersion;
delete saved.economy.aiRecruitmentWindow;
const oldScores=JSON.stringify(saved.clubs.map(c=>c.players.map(p=>[p.id,p.pos,p.rating,p.salary,p.contractEnd])));
const restored=context(saved);
assert.equal(restored.run('S.recruitmentIntelVersion'),1);
assert.equal(restored.run('S.live.minute'),saved.live.minute);
eq(JSON.parse(restored.run('JSON.stringify(S.live.score)')),saved.live.score);
assert.equal(restored.run('JSON.stringify(S.clubs.map(c=>c.players.map(p=>[p.id,p.pos,p.rating,p.salary,p.contractEnd])))'),oldScores);
assert.ok(restored.run('!!createSaveDocument()'));
const exported=restored.run('JSON.stringify(createSaveDocument())');
assert.equal(restored.run('parseSaveDocument('+JSON.stringify(exported)+').state.recruitmentIntelVersion'),1);
const invalid=context(),v=invalid.run;
v('start(0);var base=JSON.parse(JSON.stringify(S))');
for(const change of ['bad.recruitmentIntelVersion=3','bad.economy.aiRecruitmentWindow="2000:42"','bad.economy.aiRecruitmentWindow="garbage"']){
 v('var bad=JSON.parse(JSON.stringify(base))');
 assert.throws(()=>v(change+';validateCareer(bad)'),change);
}

// Quatre intersaisons : compatibilité des feuilles à 23, contrats, coûts,
// unicité des ID et possibilité de sauvegarde après évolution du mercato IA.
const seasons=context(),y=seasons.run;
y('start(0)');
const measure=[];
for(let i=0;i<4;i++){
 y('S.round=13;refreshMarket()');
 const snap=JSON.parse(y('JSON.stringify({year:S.season,transferCount:S.economy.transfers.length,freeAgents:S.economy.freeAgents.length,market:S.market.length,cash:club().cash})'));
 measure.push(snap);
 assert.ok(y('S.clubs.every(c=>c.players.length<=42&&new Set(c.players.map(p=>p.id)).size===c.players.length)'));
 assert.ok(y('S.clubs.every(c=>[...buildSheet(c).lineup,...buildSheet(c).bench].filter(Boolean).length===23)'));
 assert.ok(y('!!createSaveDocument()'));
 y('S.round=26;S.phase="ended";advanceSeason()');
 assert.equal(y('S.season'),i+2);
 assert.ok(y('!!createSaveDocument()'));
}
console.log(JSON.stringify({passed:true,seasons:4,measure,checks:['frontrow position','real contract/succession gaps','read-only dashboard','imperfect estimates','scout mission and dated reports','financial projection','AI recruitment/idempotence','legacy match and save','invalid documents','four interseasons']}));
