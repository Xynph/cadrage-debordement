'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

// Carrière Monde réelle (world-champ, club 0) ; chaque cas repart du même état et RNG.
const shared = context(827381), base = shared.checkpoint();
require('node:test').after(() => shared.close());
function worldContext() { return shared.restore(base); }

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

test('Monde : engagements de trois contrats sur les 46 semaines de gestion', () => {
  {
    const h=worldContext(),mode='world-champ';
    assert.equal(h.run('CDWorldCareer.sizing(S).rounds'),46);
    contracts(h);
    assert.equal(at(h,0),460000,mode+' : 46 × (1000 + 2×1500 + 3×2000)');
    assert.equal(at(h,23),356500,mode+' : 23 semaines courantes déjà payées');
    assert.equal(at(h,46),253000,mode+' : seules les années contractuelles suivantes restent');
    assert.equal(at(h,50),253000,mode+' : aucune semaine négative');
  }
});

test('Le vrai état Monde et sa sauvegarde gardent leurs octets et leur RNG pendant la prévision', () => {
  const h=worldContext();
  {
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
  {
    const mode='world-champ',weeks=46;
    const forecast=h.run('money(futureWages())');
    const annual=h.run('money(totalWages()*'+weeks+')');
    const finance=h.run('financeOriginal()'),contractsPanel=h.run('contractsPanel()');
    assert(finance.includes('Salaires sur une saison complète ('+weeks+' semaines)</span><strong>'+annual),mode+' : montant annuel affiché');
    assert(finance.includes('Salaires restant à verser (estimation)</span><strong>'+forecast),mode+' : engagement affiché');
    assert(contractsPanel.includes('Estimation sur '+weeks+' semaines payées par saison'),mode+' : libellé Contrats');
    assert(contractsPanel.includes('Salaires restant à verser : environ '+forecast),mode+' : même engagement');
  }
});

test('Prévision Monde : paies et recettes connues restent distinctes, sans recettes de repos ou de terrain neutre', () => {
  const h=worldContext();contracts(h);
  // Query-only calendar fixture; not exported as a complete valid season.
  h.run(`S.worldMode.fixtures=[
    {week:0,homeId:0,awayId:1,phase:'league',neutral:false},
    {week:15,homeId:0,awayId:4,phase:'pool',neutral:false},
    {week:30,homeId:1,awayId:0,phase:'league',neutral:false},
    {week:40,homeId:0,awayId:2,phase:'quarter',neutral:true}
  ];`);
  for(const week of [0,30,46]) {
    at(h,week);
    const before=h.run('JSON.stringify(S)'),store=JSON.stringify(h.store),rng=h.seed();
    const p=JSON.parse(h.run('JSON.stringify(forecastFinancialScenario(S,{kind:"baseline"},3))'));
    assert.equal(p.valid,true);assert.equal(p.annual[0].payments,46-week);
    assert.equal(p.annual[0].payroll,(46-week)*4500);
    assert.equal(p.annual[0].partners,(46-week)*160000);
    assert.equal(p.annual[0].homes,week===0?2:0);
    assert.equal(p.annual[0].matchDays,week===0?4:week===30?2:0);
    assert.equal(p.annual[1].payments,46);assert.equal(p.annual[1].payroll,3500*46);
    assert.equal(p.annual[2].payroll,2000*46);
    assert.equal(p.annual[1].homes,1);assert.equal(p.annual[1].matchDays,2,'ni Coupe d’Europe ni KO futurs inventés');
    assert.equal(p.annual[1].calendarPolicy,'repeat-current-domestic-template-no-europe-or-knockouts');
    assert.equal(p.points[2].central-p.points[1].central,2500000+46*160000-3500*46+375000+2*40000);
    assert.equal(h.run('JSON.stringify(S)'),before);assert.equal(JSON.stringify(h.store),store);assert.equal(h.seed(),rng);
    const html=h.run('financialForecastPanel()');
    assert(html.includes('Dès cette saison : '+(46-week)+' semaine(s) de flux'));
    assert(html.includes('aucune nouvelle qualification européenne'));
    assert(!html.includes('-1 semaine(s)')&&!html.includes('-16 semaine(s)'));
  }
});

test('Accord de contrat réel : le récapitulatif emploie le calendrier courant sans changer l’accord', () => {
  const h=worldContext();
  {
    const mode='world-champ',weeks=46;
    h.run(`var wagePlayer=club().players.find(p=>p.age<30&&p.contractEnd<=S.season+1);
      if(!wagePlayer)throw Error('Missing renewal fixture');
      if(!negotiateContract(wagePlayer.id,'renew',100000,3))throw Error('Renewal setup failed');`);
    const expected=h.run('money(S.economy.talks[talkKey(wagePlayer.id,"renew")].acceptedSalary*'+weeks+'*3)');
    const state=h.run('JSON.stringify(S)'),store=JSON.stringify(h.store),rng=h.seed();
    h.run('openContract(wagePlayer.id,"renew")');const html=h.run('modal');
    assert(html.includes('Salaires sur 3 saison(s) complète(s) : '+expected),mode);
    assert(html.includes('('+weeks+' semaines payées par saison ; estimation, hors primes).'),mode);
    assert.equal(h.run('JSON.stringify(S)'),state);assert.equal(JSON.stringify(h.store),store);assert.equal(h.seed(),rng);
  }
});
