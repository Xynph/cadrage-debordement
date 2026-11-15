'use strict';
// Tests des vraies fonctions de carrière chargées par le harness natif du dépôt.
const assert=require('node:assert/strict'),fs=require('node:fs'),{engineContext:context}=require('./harness.cjs');
const checks=[];function check(label,fn){fn();checks.push(label);}
const game=context(),run=game.run;
run('start(0)');
check('activation native monde et carrière',()=>{assert.equal(run('worldActive()'),true);assert.equal(run('careerIntegrated()'),true);});
check('sauvegarde officielle exportable',()=>assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true));
check('offre de travaux réelle valorisée',()=>assert.equal(run('worldFacilityQuote(S.club).affordable'),true));
check('écriture financière réelle une fois',()=>{const cash=run('club().cash'),price=run('worldFacilityQuote(S.club).cost');assert.equal(run('worldUpgradeFacility()'),true);assert.equal(run('club().cash'),cash-price);assert.equal(run('worldUpgradeFacility()'),false);assert.equal(run('club().cash'),cash-price);});
check('historique des travaux conservé',()=>assert.equal(run('S.worldManagement.upgrades.filter(x=>x.id===S.club).length'),1));
check('tableaux de carrière sans mutation',()=>{const before=run('JSON.stringify(S)');run('worldLeaguePanel();worldFinancePanel();worldOfficePanel()');assert.equal(run('JSON.stringify(S)'),before);});
check('reprise native avec état conservé',()=>{const stored=JSON.parse(run('JSON.stringify(S)'));const restored=context(stored);assert.equal(restored.run('worldClub(S.club).facilities'),3);assert.equal(restored.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);restored.close();});
check('ancien format sans gestion monde : codec pur, sans démarrage',()=>{const state=run('JSON.stringify(S)'),seed=game.seed();run('var probe=JSON.parse(JSON.stringify(S));delete probe.worldVersion;delete probe.worldManagement;var parsedProbe=parseSaveDocument(JSON.stringify(createSaveDocument(probe)))');assert.equal(run('parsedProbe.state.worldVersion'),undefined);assert.equal(run('parsedProbe.state.worldManagement'),undefined);assert.equal(run('parsedProbe.state.worldMode.version'),5);assert.equal(run('JSON.stringify(S)'),state);assert.equal(game.seed(),seed);});
check('contrôle sauvegarde rejette réputation corrompue',()=>{const g=context();g.run('start(0);S.worldManagement.clubInfo[0].reputation=200');assert.throws(()=>g.run('validateCareer(S)'));g.close();});
check('finance et historique d’une vraie journée',()=>{game.toMatch();const cash=run('club().cash'),week=run('S.round'),matches=run('S.schedule[S.round].length'),history=run('S.history.length');run('var ledgerBefore=new Set(S.ledger);finishRound()');assert.equal(run('S.round'),week+1);assert.equal(run('S.history.length'),history+matches);assert.equal(run('S.worldManagement.matches.length'),Math.min(180,history+matches));assert.equal(run('club().cash'),cash+run('S.ledger.filter(x=>!ledgerBefore.has(x)).reduce((n,x)=>n+x.amount,0)'));assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);});
check('écritures de finance identifiées et bornées',()=>{assert.ok(run('S.ledger.every(x=>Number.isFinite(x.amount))'));assert.ok(run('S.worldManagement.matches.every(x=>x.season===S.season)'));});
const report={engine:'native harness, real match-day simulation',passed:checks.length,checks,limitations:['does not activate candidate PR60-68 modules','not a native Windows test','does not mutate user save']};
if(process.env.CD_V63_REPORT)fs.writeFileSync(process.env.CD_V63_REPORT,JSON.stringify(report,null,2)+'\n');
game.close();
console.log('V63 NATIVE CAREER PASS '+JSON.stringify(report));
