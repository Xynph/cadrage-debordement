'use strict';
// Tests des vraies fonctions de carrière chargées par le harness natif du dépôt.
const assert=require('node:assert/strict'),fs=require('node:fs'),{context}=require('./harness.cjs');
const checks=[];function check(label,fn){fn();checks.push(label);}
const game=context(),run=game.run;
run('start(0)');
check('activation native monde et carrière',()=>{assert.equal(run('worldActive()'),true);assert.equal(run('careerIntegrated()'),true);});
check('sauvegarde officielle exportable',()=>assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true));
check('offre de travaux réelle valorisée',()=>assert.equal(run('worldFacilityQuote(S.club).affordable'),true));
check('écriture financière réelle une fois',()=>{const cash=run('club().cash'),price=run('worldFacilityQuote(S.club).cost');assert.equal(run('worldUpgradeFacility()'),true);assert.equal(run('club().cash'),cash-price);assert.equal(run('worldUpgradeFacility()'),false);assert.equal(run('club().cash'),cash-price);});
check('historique des travaux conservé',()=>assert.equal(run('S.worldManagement.upgrades.filter(x=>x.id===S.club).length'),1));
check('tableaux de carrière sans mutation',()=>{const before=run('JSON.stringify(S)');run('worldLeaguePanel();worldFinancePanel();worldOfficePanel()');assert.equal(run('JSON.stringify(S)'),before);});
check('reprise native avec état conservé',()=>{const stored=JSON.parse(run('JSON.stringify(S)'));const restored=context(stored);assert.equal(restored.run('worldClub(S.club).facilities'),3);assert.equal(restored.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);});
check('ancien format sans monde toujours validé',()=>{const old=JSON.parse(run('JSON.stringify(S)'));delete old.worldVersion;delete old.worldManagement;const g=context(old);assert.equal(g.run('worldActive()'),false);assert.equal(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);});
check('contrôle sauvegarde rejette réputation corrompue',()=>{const g=context();g.run('start(0);S.worldManagement.clubInfo[0].reputation=200');assert.throws(()=>g.run('validateCareer(S)'));});
check('finance et historique d’une vraie journée',()=>{const cash=run('club().cash');run('finishRound()');assert.equal(run('S.round'),1);assert.equal(run('S.worldManagement.matches.length'),7);assert.equal(run('club().cash'),cash+run('S.ledger.filter(x=>x.title.includes("Journée 1")).reduce((n,x)=>n+x.amount,0)'));assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);});
check('écritures de finance identifiées et bornées',()=>{assert.ok(run('S.ledger.every(x=>Number.isFinite(x.amount))'));assert.ok(run('S.worldManagement.matches.every(x=>x.season===S.season)'));});
const report={engine:'native harness, real match-day simulation',passed:checks.length,checks,limitations:['does not activate candidate PR60-68 modules','not a native Windows test','does not mutate user save']};
if(process.env.CD_V63_REPORT)fs.writeFileSync(process.env.CD_V63_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V63 NATIVE CAREER PASS '+JSON.stringify(report));
