'use strict';
const assert=require('node:assert/strict');
const {engineContext:context}=require('./harness.cjs');
let t=context(),run=t.run;
run('start(0);var p=club().players[0],id=p.id;var before=JSON.stringify(S),storage=localStorage.getItem("bdt-v1")');
assert.equal(run('S.satisfactionVersion'),1);
assert.equal(run('p.satisfaction.score'),65);
assert.ok(run('club().players.every(p=>p.satisfaction?.version===1)'));

assert.ok(run('satisfactionPanel().includes("Satisfaction et promesses V36")'));
assert.equal(run('satisfactionWageRate(p,"renew")'),0);
assert.ok(run('JSON.stringify(S)')===run('before'));
assert.equal(run('localStorage.getItem("bdt-v1")'),run('storage'));
assert.equal(run('makePlayingPromise(id,"rotation")'),true);
assert.equal(run('makePlayingPromise(id,"regulier")'),false);
assert.equal(run('makePlayingPromise(id,"inconnu")'),false);
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
for(let i=0;i<3;i++)run('p.dev.minutes+=30;recordSatisfactionRound({finished:true,pair:[S.club,1],userSide:0})');
assert.equal(run('p.satisfaction.score'),73);
assert.equal(run('p.satisfaction.promise'),null);
assert.equal(run('p.satisfaction.history.at(-1).status'),'kept');
// Cas d’observation contrôlé après quatre vraies semaines : le suivi antérieur
// est une donnée de fixture, pas une reconstruction des minutes de ces matchs.
run('var observationBefore=JSON.stringify(p.satisfaction)');t.deferSaves();t.week(4);
run('p=player(id);p.satisfaction=JSON.parse(observationBefore);p.satisfaction.baseline=p.dev.minutes;p.injury=0');
assert.equal(run('makePlayingPromise(id,"titulaire")'),true);
run('p.injury=1;recordSatisfactionRound({finished:true,pair:[S.club,1],userSide:0})');
assert.equal(run('p.satisfaction.promise.completed'),0);
run('p.injury=0');
for(let i=0;i<3;i++)run('p.dev.minutes+=20;recordSatisfactionRound({finished:true,pair:[S.club,1],userSide:0})');
assert.equal(run('p.satisfaction.score'),63);
assert.equal(run('p.satisfaction.history.at(-1).status'),'broken');
run('p.satisfaction.score=35');
assert.equal(run('satisfactionWageRate(p,"renew")'),.02);
assert.equal(run('satisfactionWageRate(p,"recruit")'),0);
run('p.satisfaction.score=85');
assert.equal(run('satisfactionWageRate(p,"renew")'),-.01);
run('p.satisfaction.score=63');
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
run('p.satisfaction.score=110');
assert.throws(()=>run('validateCareer(S)'));
run('p.satisfaction.score=63');
const legacy=JSON.parse(run('JSON.stringify(S)'));delete legacy.satisfactionVersion;delete legacy.relationsVersion;delete legacy.objectivesVersion;delete legacy.economy.objectives;delete legacy.economy.objectiveHistory;delete legacy.economy.relationLog;delete legacy.economy.moodLog;
for(const c of legacy.clubs)for(const p of c.players)delete p.satisfaction;
// Les journaux V37 appartiennent au marqueur retiré : le vrai match a créé
// moodLog. Exiger le format World complet AVANT toute reprise, sans retirer
// autre chose que ces métadonnées optionnelles de suivi.
t.ctx.satisfactionLegacy=legacy;try{run('validateCareer(satisfactionLegacy);parseSaveDocument(JSON.stringify(createSaveDocument(satisfactionLegacy)))')}finally{delete t.ctx.satisfactionLegacy;}
t.close();t=null;run=null;
(()=>{
const old=context(legacy),r=old.run;
assert.equal(r('S.satisfactionVersion'),undefined);
assert.equal(r('satisfactionWageRate(club().players[0],"renew")'),0);
assert.ok(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
assert.equal(r('activateSatisfaction()'),true);
assert.equal(r('S.satisfactionVersion'),1);
assert.ok(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
old.close();
})();
const live=context(legacy),l=live.run;
live.deferSaves();live.toMatch();l('beginMatch();pauseMatch()');
assert.equal(l('activateSatisfaction()'),false);
assert.equal(l('S.satisfactionVersion'),undefined);live.close();
console.log(JSON.stringify({passed:true,checks:['promises','minutes','injury','renewal','legacy','save validation']}));
