'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./france-harness.cjs');
const {bootstrap} = require('../native/engine/world-vm.cjs');
const compose = require('../native/engine/world-pacific-registry.cjs');
const base = require('../native/engine/world-registry.json');
const pacific = compose.extendWorldRegistry(base, require('../native/engine/world-pacific-extension.json'));
const japan = compose.extendJapanRegistry(pacific, require('../native/engine/world-japan-extension.json'));
const nationale = compose.extendNationaleRegistry(japan, require('../native/engine/world-nationale-extension.json'));
const champ = compose.extendChampRegistry(nationale, require('../native/engine/world-champ-extension.json'));

function worldContext() {
  const h = context(827381);
  for (const [key,registry] of Object.entries({nativeWorldRegistryText:base,nativeWorldPacificRegistryText:pacific,
    nativeWorldJapanRegistryText:japan,nativeWorldNationaleRegistryText:nationale,nativeWorldChampRegistryText:champ}))
    h.ctx[key] = JSON.stringify(registry);
  h.run(bootstrap());
  return h;
}

// Three explicit weekly contracts: 1000 for this season, 1500 for two,
// 2000 for three. This small arithmetic fixture is not exported as a career.
function contracts(h) {
  h.run(`S.season=2;club().players=club().players.slice(0,3);
    club().players.forEach((p,i)=>{p.salary=[1000,1500,2000][i];p.contractEnd=2+i;});`);
}
function at(h,week) {
  h.ctx.auditWeek=week;
  h.run('S.round=auditWeek;if(S.franceMode)S.franceMode.week=auditWeek;if(S.worldMode)S.worldMode.week=auditWeek;');
  return h.run('futureWages()');
}

test('Monde v1 à v5 : engagements de trois contrats sur les 46 semaines de gestion', () => {
  const h=worldContext();
  for (const [mode,club] of [['world',0],['world-pacific',58],['world-japan',68],['world-nationale',88],['world-champ',102]]) {
    h.ctx.auditMode=mode;h.ctx.auditClub=club;
    h.run('CDWorldCareer.start(auditClub,auditMode)');
    assert.equal(h.run('CDWorldCareer.sizing(S).rounds'),46);
    contracts(h);
    assert.equal(at(h,0),460000,mode+' : 46 × (1000 + 2×1500 + 3×2000)');
    assert.equal(at(h,23),356500,mode+' : 23 semaines courantes déjà payées');
    assert.equal(at(h,46),253000,mode+' : seules les années contractuelles suivantes restent');
    assert.equal(at(h,50),253000,mode+' : aucune semaine négative');
  }
});

test('France conserve 34 semaines, la carrière historique conserve 29 et le bon compteur de semaine', () => {
  const h=context(827381);
  h.run("start(0,'fiction')");contracts(h);
  assert.equal(at(h,0),290000);assert.equal(at(h,14),227000);assert.equal(at(h,29),159500);
  h.run("CDFranceCareer.start(0)");contracts(h);
  assert.equal(at(h,0),340000);assert.equal(at(h,17),263500);assert.equal(at(h,34),187000);
  h.run('S.round=2;S.franceMode.week=17');
  assert.equal(h.run('futureWages()'),263500,'le calendrier France est indépendant de la journée élite');
});

test('Le vrai état Monde et sa sauvegarde gardent leurs octets et leur RNG pendant la prévision', () => {
  const h=worldContext();
  for (const mode of ['world','world-champ']) {
    h.ctx.auditMode=mode;h.run('CDWorldCareer.start(0,auditMode)');
    const state=h.run('JSON.stringify(S)'),store=JSON.stringify(h.store),seed=h.seed();
    const exported=h.run('JSON.stringify(createSaveDocument())');
    const forecast=h.run('futureWages()');
    assert(forecast>0);
    assert.equal(h.run('JSON.stringify(S)'),state);
    assert.equal(JSON.stringify(h.store),store);assert.equal(h.seed(),seed);
    assert.equal(h.run('JSON.stringify(createSaveDocument())'),exported);
    h.ctx.auditExport=exported;h.run('var forecastIncoming=parseSaveDocument(auditExport);');
    assert.equal(h.run('JSON.stringify(forecastIncoming.state)'),state,'export validé sans migration de format');
  }
});

test('Les rendus réels Finances et Contrats annoncent le même calendrier que leurs montants', () => {
  const h=worldContext();
  for (const [mode,weeks] of [['fiction',29],['france',34],['world',46],['world-champ',46]]) {
    h.ctx.auditMode=mode;
    h.run("if(auditMode.startsWith('world'))CDWorldCareer.start(0,auditMode);else if(auditMode==='france')CDFranceCareer.start(0);else start(0,'fiction');");
    const forecast=h.run('money(futureWages())');
    const annual=h.run('money(totalWages()*'+weeks+')');
    const finance=h.run('financeOriginal()'),contractsPanel=h.run('contractsPanel()');
    assert(finance.includes('Salaires sur une saison complète ('+weeks+' semaines)</span><strong>'+annual),mode+' : montant annuel affiché');
    assert(finance.includes('Salaires restant à verser (estimation)</span><strong>'+forecast),mode+' : engagement affiché');
    assert(contractsPanel.includes('Estimation sur '+weeks+' semaines payées par saison'),mode+' : libellé Contrats');
    assert(contractsPanel.includes('Salaires restant à verser : environ '+forecast),mode+' : même engagement');
  }
});
