'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
function testPure(t,expr){
 const state=t.run('JSON.stringify(S)'),stored=t.run('localStorage.getItem("bdt-v1")');
 const result=JSON.parse(t.run('JSON.stringify('+expr+')'));
 assert.equal(t.run('JSON.stringify(S)'),state,'The model must not change the saved career');
 assert.equal(t.run('localStorage.getItem("bdt-v1")'),stored,'The model must not persist anything');
 return result;
}
const base=context(),r=base.run;
r('start(0)');
const priorities=testPure(base,'renewalPriorities(S,3,2)');
assert.ok(priorities.length>=3,'At least three candidates must be available in the starter club');
assert.ok(priorities.every(p=>p.score>=0&&p.score<=100));
assert.ok(priorities.every((p,i)=>!i||priorities[i-1].score>=p.score));
assert.ok(priorities.every(p=>p.terms.years>=p.terms.min&&p.terms.years<=p.terms.max));
assert.ok(priorities.every(p=>p.reasons.some(x=>x.includes('V30'))));
assert.ok(priorities.every(p=>p.reasons.some(x=>x.includes('V32'))));
assert.ok(priorities.every(p=>p.reasons.some(x=>x.includes('Potentiel'))));
assert.ok(priorities.every(p=>p.reasons.some(x=>x.includes('Âge'))));
assert.ok(priorities.every(p=>p.reasons.some(x=>x.includes('Prime'))));
assert.equal(JSON.stringify(priorities.map(p=>p.id)),JSON.stringify(testPure(base,'renewalPriorities(S,3,2)').map(p=>p.id)));
assert.ok(r('renewalAdvisorPanel().includes("CONSEILLER V33")'));
assert.ok(r('contractsPanel().includes("Prioriser les prolongations")'));
assert.ok(r('renewalAdvisorPanel().includes("Sans prolongation")'));
assert.equal(r('setRenewalChoice("years",0)'),false);
assert.equal(r('setRenewalChoice("horizon",4)'),false);
assert.equal(r('setRenewalChoice("first","not-a-player")'),false);
assert.equal(r('setRenewalChoice("unknown","")'),false);
assert.equal(r('setRenewalChoice("years",1)'),true);
assert.equal(r('renewalChoice.years'),1);
assert.equal(r('setRenewalChoice("horizon",2)'),true);
assert.equal(r('renewalChoice.horizon'),2);
assert.equal(r('S.season'),1);

// Une négociation hypothétique conserve tous les contrôles financiers V31.
const chosen=priorities.slice(0,3).map(x=>x.id);
const single=testPure(base,'renewalCompare(S,'+JSON.stringify(chosen.slice(0,1))+',3,2)');
const multi=testPure(base,'renewalCompare(S,'+JSON.stringify(chosen)+',3,2)');
assert.ok(single.valid&&multi.valid);
assert.equal(single.cases.length,2);
assert.equal(multi.cases.length,6);
const sc=single.cases[1],first=priorities[0];
assert.equal(sc.fee,first.fee);
assert.equal(sc.fee,r('contractFee(player('+JSON.stringify(first.id)+'),"renew")'));
const exact=r('JSON.stringify(forecastFinancialScenario(S,{kind:"renew",id:'+JSON.stringify(first.id)+',years:'+first.terms.years+'},3))');
const financial=JSON.parse(exact);
assert.equal(sc.cashCentral,financial.points.at(-1).central);
assert.equal(sc.cashLow,financial.points.at(-1).low);
assert.equal(sc.annual[0].payroll,financial.annual[0].payroll);
assert.equal(sc.financialChange,sc.cashCentral-single.cases[0].cashCentral);
assert.deepEqual(sc.coverage,first.projection.years.map(y=>y.covered));
assert.equal(sc.savedGaps,single.cases[0].gaps.reduce((s,x)=>s+x,0)-sc.gaps.reduce((s,x)=>s+x,0));
const combined=multi.cases.at(-1);
assert.equal(combined.fee,priorities.slice(0,3).reduce((s,x)=>s+x.fee,0));
assert.equal(combined.financialChange,combined.cashCentral-multi.cases[0].cashCentral);
assert.equal(combined.coverage.length,3);
assert.ok(multi.cases.every(x=>x.cashLow<=x.cashCentral&&x.cashCentral<=x.cashHigh));
assert.equal(testPure(base,'renewalCompare(S,["bad-id"],3,2)').valid,false);
assert.equal(testPure(base,'renewalCompare(S,'+JSON.stringify([chosen[0],chosen[0]])+',3,2)').valid,false);
assert.equal(testPure(base,'renewalCompare(S,'+JSON.stringify(chosen)+',4,2)').valid,false);

// Valeur V29 : une qualité ciblée acquise affecte la vraie note au poste,
// et donc le constat sportif, sans génération fictive de points gratuits.
const skillCase=context(),sk=skillCase.run;
sk('start(0);var p=club().players.find(x=>x.fam===0&&x.contractEnd<=S.season+1);var before=renewalPriorities(S,3,2).find(x=>x.id===p.id)?.here;var k=Object.keys(ROLE_WEIGHTS[p.fam])[0];ensureSpecialization(p).bonuses[k]=4;var after=renewalPriorities(S,3,2).find(x=>x.id===p.id)?.here');
assert.ok(sk('after>before'));

// V30 : renforcer la pénurie d'un poste augmente le besoin d'effectif,
// sans changer les qualifications spécifiques de première ligne.
const depth=context(),d=depth.run;
d('start(0);var p=club().players.find(x=>x.pos===POS[0]);var before=recruitmentNeed(club(),0).score;club().players=club().players.filter(q=>q.pos!==POS[0]||q.id===p.id);var after=recruitmentNeed(club(),0).score');
assert.ok(d('after>=before'));
assert.equal(d('slotEligible(p,2)'),false);
const newPriority=testPure(depth,'renewalPriorities(S,3,2)');
assert.ok(newPriority.every(x=>x.primarySlot>=0&&x.primarySlot<=14));
assert.ok(newPriority.every(x=>x.projection.years.every(y=>y.covered<=15)));

// Retraite et fin de contrat : respecter exactement la durée minimale du moteur,
// sans afficher un contrat impossible comme renouvelable.
const retire=context(),rt=retire.run;
rt('start(0);var p=club().players.find(x=>x.contractEnd===S.season);var id=p.id;p.dev.retireAge=p.age+1');
assert.equal(rt('renewalEligibleYears(S,p,2)'),null);
assert.equal(rt('renewalPriorities(S,3,2).some(x=>x.id===id)'),false);
rt('p.dev.retireAge=p.age+3');
const term=rt('renewalEligibleYears(S,p,3)');
assert.equal(term.min,2);
assert.ok(term.years<=3);
assert.equal(rt('forecastQuote(S,{kind:"renew",id,years:'+term.years+'}).valid'),true);

// L'impossibilité financière est explicitée, pas contournée.
const unaffordable=context(),u=unaffordable.run;
u('start(0);club().cash=0');
const zero=testPure(unaffordable,'renewalCompare(S,renewalPriorities(S,3,2).slice(0,2).map(x=>x.id),3,2)');
assert.ok(zero.valid);
assert.ok(zero.cases.slice(1).some(c=>c.valid&&!c.executable));
assert.equal(u('club().cash'),0);

// Ancienne V32 en match suspendu : les contrats, minutes et sauvegarde sont intacts.
const from=context();from.run('start(0);beginMatch();pauseMatch()');
const legacy=JSON.parse(from.run('JSON.stringify(S)'));
const resumed=context(legacy),l=resumed.run;
const oldCash=l('club().cash'),oldLedger=l('JSON.stringify(S.ledger)'),oldRound=l('S.round');
const live=testPure(resumed,'renewalCompare(S,renewalPriorities(S,3,2).slice(0,2).map(x=>x.id),3,2)');
assert.ok(live.valid);
assert.ok(live.cases.slice(1).every(x=>!x.executable));
assert.equal(l('S.live.minute'),legacy.live.minute);
assert.deepEqual(JSON.parse(l('JSON.stringify(S.live.score)')),legacy.live.score);
assert.equal(l('S.round'),oldRound);
assert.equal(l('club().cash'),oldCash);
assert.equal(l('JSON.stringify(S.ledger)'),oldLedger);
assert.ok(l('!!createSaveDocument()'));
const exported=l('JSON.stringify(createSaveDocument())');
assert.equal(l('parseSaveDocument('+JSON.stringify(exported)+').state.live.minute'),legacy.live.minute);

// Calibration sur quatre intersaisons : répéter le diagnostic après la vraie
// transition de saison et garder les sauvegardes, finances et 23 rugby valides.
const seasons=context(),y=seasons.run;seasons.run('start(0)');
const measured=[];
for(let i=0;i<4;i++){
 const ranked=testPure(seasons,'renewalPriorities(S,3,2)');
 const scenario=testPure(seasons,'renewalCompare(S,renewalPriorities(S,3,2).slice(0,3).map(x=>x.id),3,2)');
 assert.ok(scenario.valid&&scenario.cases.every(c=>c.valid&&c.coverage.length===3));
 assert.ok(scenario.cases.every(c=>Number.isFinite(c.cashCentral)&&c.coverage.every(n=>n<=15)));
 measured.push({season:y('S.season'),candidates:ranked.length,leaders:ranked.slice(0,3).map(x=>({score:x.score,slot:x.primarySlot,gain:x.futureDelta})),cash:scenario.cases.at(-1).cashCentral});
 y('S.phase="ended";S.round=26;advanceSeason()');
 assert.equal(y('S.season'),i+2);
 assert.equal(y('sheetErrors().length'),0);
 assert.ok(y('!!createSaveDocument()'));
}
console.log(JSON.stringify({passed:true,seasons:4,measured,checks:['deterministic ranking','V29 skill','V30 needs','V32 succession','V31 fees and cash','multi-renewal cumulative effects','retirement limits','cash warning','pure career and storage','legacy paused match','four interseasons']}));
