'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const pure=(t,expr)=>{
 const before=t.run('JSON.stringify(S)'),storage=t.run('localStorage.getItem("bdt-v1")');
 const result=t.run(expr);
 assert.equal(t.run('JSON.stringify(S)'),before,'Model must not mutate a career');
 assert.equal(t.run('localStorage.getItem("bdt-v1")'),storage,'Model must not save');
 return JSON.parse(t.run('JSON.stringify('+expr+')'));
};
const t=context();t.run('start(0)');
const base=pure(t,'successionSimulate(S,[],3)');
assert.ok(base.valid);
assert.equal(base.years.length,3);
assert.ok(base.years.every(y=>y.covered<=15&&y.covered>=0&&y.slots.length===15));
assert.equal(base.finance.points.length,4);
assert.equal(base.fee,0);
assert.equal(base.finance.points[0].central,t.run('club().cash'));
assert.equal(base.finance.points.at(-1).central,t.run('forecastFinancialScenario(S,{kind:"baseline"},3).points.at(-1).central'));
assert.ok(t.run('successionPlanningPanel().includes("PLANIFICATION V32")'));
t.run('squadTab="planning"');
assert.ok(t.run('managerTeamView().includes("Planification sur plusieurs saisons")'));
assert.ok(t.run('setSuccessionChoice("slot",2)'));
assert.equal(t.run('successionChoice.slot'),2);
assert.equal(t.run('setSuccessionChoice("slot",15)'),false);
assert.equal(t.run('setSuccessionChoice("horizon",9)'),false);
assert.equal(t.run('setSuccessionChoice("unknown","x")'),false);
assert.equal(t.run('setSuccessionChoice("horizon",2)'),true);
assert.equal(t.run('S.round'),0);

// Couverture des postes : un joueur polyvalent ne remplit qu'un seul siège.
// Pilier gauche, talonneur et pilier droit conservent leurs qualifications exactes.
const positions=context();positions.run('start(0);var p=club().players.find(p=>p.pos===POS[0]);var same=Array.from({length:15},()=>[]);same[0]=[p];same[2]=[p]');
assert.equal(positions.run('successionAssignment(same).size'),1);
assert.equal(positions.run('slotEligible(p,0)'),true);
assert.equal(positions.run('slotEligible(p,2)'),false);
positions.run('club().players=club().players.filter(q=>q.pos!==POS[0]);var missing=successionSimulate(S,[],2)');
assert.equal(positions.run('missing.years[0].gaps.includes(0)'),true);
assert.equal(positions.run('missing.years[0].slots[2].count>0'),true);

// Contrats : fin S1 et retraite après S1 suppriment la couverture en S2.
// L'âge futur est dérivé ; les retraites et départs futurs sont des bornes,
// pas une simulation de progression arbitraire.
const endings=context();endings.run('start(0);var q=club().players.find(p=>p.pos===POS[0]);club().players=club().players.filter(p=>p.pos!==POS[0]||p.id===q.id);q.contractEnd=S.season;var before=successionSimulate(S,[],3)');
assert.equal(endings.run('before.years[0].slots[0].count'),1);
assert.equal(endings.run('before.years[1].slots[0].count'),0);
endings.run('q.contractEnd=S.season+3;q.dev.retireAge=q.age+1;var retired=successionSimulate(S,[],3)');
assert.equal(endings.run('retired.years[0].slots[0].count'),1);
assert.equal(endings.run('retired.years[1].slots[0].count'),0);

// Prolongation : mêmes frais, durée et salaire que le moteur V31, sans
// appliquer une négociation ou créer une ligne de journal.
const renewal=context();renewal.run('start(0);var p=club().players[0];p.contractEnd=S.season;var id=p.id;var quote=forecastQuote(S,{kind:"renew",id,years:2})');
const renewed=pure(renewal,'successionSimulate(S,[{kind:"renew",id,years:2}],3)');
assert.ok(renewed.valid);
assert.equal(renewed.fee,renewal.run('quote.fee'));
assert.equal(renewed.finance.points[0].central,renewal.run('club().cash-quote.fee'));
assert.equal(renewed.finance.annual[0].payroll,
 renewal.run('forecastFinancialScenario(S,{kind:"renew",id,years:2},3).annual[0].payroll'));
assert.ok(renewed.years[1].slots.some(x=>x.ids.includes(renewal.run('id'))));
assert.equal(renewal.run('p.contractEnd'),1);
assert.equal(renewal.run('S.economy.transfers.length'),0);

// Promotion : le salaire est payé deux saisons et le potentiel des espoirs
// reste indicatif. L'espoir n'apparaît jamais chez les professionnels réels.
const academy=context();academy.run('start(0);var youth=S.development.academy[0],id=youth.id,wage=youth.salary,role=POS.indexOf(youth.pos)');
const recruited=pure(academy,'successionSimulate(S,[{kind:"youth",id}],3)');
assert.ok(recruited.valid);
assert.equal(recruited.fee,0);
const none=pure(academy,'successionSimulate(S,[],3)');
assert.equal(recruited.finance.annual[0].payroll-none.finance.annual[0].payroll,academy.run('wage*29'));
assert.equal(recruited.finance.annual[1].payroll-none.finance.annual[1].payroll,academy.run('wage*29'));
assert.equal(recruited.finance.annual[2].payroll-none.finance.annual[2].payroll,0);
assert.equal(academy.run('club().players.some(p=>p.id===id)'),false);
assert.equal(academy.run('S.development.academy.some(p=>p.id===id)'),true);
assert.ok(recruited.years[0].slots[academy.run('role')].count>=none.years[0].slots[academy.run('role')].count);

// Recrutement V30 : aucune note ou potentiel cachés consultés ; les
// conditions financières et les postes visibles sont les seuls critères.
const scout=context();scout.run('start(0);var p=S.market[0],id=p.id');
const outside=pure(scout,'successionSimulate(S,[{kind:"recruit",id,years:2}],3)');
assert.ok(outside.valid);
assert.equal(outside.fee,scout.run('p.price'));
assert.equal(outside.finance.points[0].central,scout.run('club().cash-p.price'));
scout.run('p.rating=99;p.dev.potential=99;Object.keys(p.skills).forEach(k=>p.skills[k]=99)');
const changed=pure(scout,'successionSimulate(S,[{kind:"recruit",id,years:2}],3)');
assert.deepEqual(outside,changed,'Unknown external skills/potential must not leak into planning');
assert.ok(outside.reasons.some(x=>x.includes('non observés')));
scout.run('S.manager.reports.unshift({id:"v32-r",playerId:p.id,note:75,potential:90,week:S.economy.week,season:S.season})');
const observed=pure(scout,'successionSimulate(S,[{kind:"recruit",id,years:2}],3)');
assert.ok(observed.reasons.some(x=>x.includes('Rapport de scouting')));
assert.ok(observed.years.every(y=>y.covered<=15));

// Le plan combiné paie bien la prime de prolongation + les salaires des deux.
const combo=context();combo.run('start(0);var p=club().players[0];p.contractEnd=S.season;var id=p.id,young=S.development.academy[0].id');
const together=pure(combo,'successionSimulate(S,[{kind:"renew",id,years:2},{kind:"youth",id:young}],3)');
assert.equal(together.fee,combo.run('contractFee(p,"renew")'));
assert.equal(together.finance.annual[0].payroll,
 combo.run('forecastFinancialScenario(S,{kind:"renew",id,years:2},3).annual[0].payroll+S.development.academy[0].salary*29'));
assert.equal(pure(combo,'successionSimulate(S,[{kind:"youth",id:young},{kind:"youth",id:young}],3)').valid,false);
assert.equal(pure(combo,'successionSimulate(S,[],4)').valid,false);
combo.run('club().cash=0;var noCash=successionSimulate(S,[{kind:"renew",id,years:2}],2)');
assert.equal(combo.run('noCash.executable'),false);

// Qualités V29 : la spécialisation modifie seulement la qualité du joueur
// connu, sans devenir une note inventée pour les candidats non observés.
const qualities=context();qualities.run('start(0);var p=club().players[0],old=successionPerson(p).level;var key=Object.keys(ROLE_WEIGHTS[p.fam])[0];ensureSpecialization(p).bonuses[key]=4;var higher=successionPerson(p).level');
assert.ok(qualities.run('higher>old'));

// Match suspendu et sauvegarde historique : aucune donnée V32 requise.
const existing=context();existing.run('start(0);beginMatch();pauseMatch()');
const legacy=JSON.parse(existing.run('JSON.stringify(S)'));
const loaded=context(legacy);
const info=pure(loaded,'successionSimulate(S,[],3)');
assert.ok(info.valid);
assert.equal(info.executable,false);
assert.equal(loaded.run('S.live.minute'),legacy.live.minute);
assert.deepEqual(JSON.parse(loaded.run('JSON.stringify(S.live.score)')),legacy.live.score);
assert.ok(loaded.run('!!createSaveDocument()'));

// Calibration sur quatre intersaisons de carrière réelle : disponibilité
// bornée, finances finies, anciennes feuilles réglementaires et exports valides.
const years=context();years.run('start(0)');
const sampled=[];
for(let i=0;i<4;i++){
 const row=pure(years,'successionSimulate(S,[],3)');
 assert.ok(row.valid&&row.years.length===3&&row.years.every(y=>y.covered<=15));
 assert.ok(row.finance.points.every(p=>Number.isFinite(p.central)));
 sampled.push({season:years.run('S.season'),coverage:row.years.map(y=>y.covered),cash:row.finance.points.at(-1).central});
 years.run('S.phase="ended";S.round=26;advanceSeason()');
 assert.equal(years.run('S.season'),i+2);
 assert.ok(years.run('!!createSaveDocument()'));
 assert.equal(years.run('sheetErrors().length'),0);
}
console.log(JSON.stringify({passed:true,years:4,sampled,checks:['pure financial and career state','distinct frontrow roles','contract expiration','retirements','renewal quote','academy promotion without action','scouting uncertainty','combined strategy','V29 specialization','legacy live save','four interseasons']}));
