'use strict';
const assert=require('node:assert/strict');
const {engineContext:context}=require('./harness.cjs');
let t=context(),r=t.run;
function valid(run){return run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))');}
function observationWeeks(n){
 // Conserver l’échantillon synthétique original de minutes/apparitions et de
 // satisfaction pendant les vrais matchs de calendrier, reçus séparément.
 r('var controlledObservation=JSON.stringify({minutes:p.dev.minutes,appearances:p.dev.appearances,injury:p.injury,satisfaction:p.satisfaction,objectives:S.economy.objectives,objectiveHistory:S.economy.objectiveHistory})');
 t.week(n);
 r('p=player(id);var sample=JSON.parse(controlledObservation);p.dev.minutes=sample.minutes;p.dev.appearances=sample.appearances;p.injury=sample.injury;p.satisfaction=sample.satisfaction;S.economy.objectives=sample.objectives;S.economy.objectiveHistory=sample.objectiveHistory');
}
t.deferSaves();
r('start(0);var p=club().players[0],id=p.id;var cash=club().cash,old=JSON.stringify(S),stored=localStorage.getItem("bdt-v1")');
assert.equal(r('S.objectivesVersion'),1);
assert.equal(r('objectivesActive()'),true);
assert.ok(r('individualObjectivesPanel().includes("Objectifs sportifs individuels")'));
assert.ok(r('JSON.stringify(S)')===r('old'),'reading dashboard cannot mutate career');
assert.equal(r('localStorage.getItem("bdt-v1")'),r('stored'));
assert.equal(r('proposeIndividualObjective(id,"minutes",900,3)'),false);
assert.equal(r('proposeIndividualObjective(id,"minutes",180,3)'),true);
assert.equal(r('S.economy.objectives[0].status'),'proposed');
assert.equal(r('S.economy.objectives[0].reply'),'agree');
assert.equal(r('proposeIndividualObjective(id,"minutes",120,3)'),false);
assert.ok(valid(r));
assert.equal(r('confirmIndividualObjective(id)'),true);
assert.equal(r('confirmIndividualObjective(id)'),false);
assert.equal(r('S.economy.objectives[0].status'),'active');
assert.equal(r('club().cash'),r('cash'));
assert.ok(valid(r));
// Each round once; delta comes solely from the development counters.
r('p.dev.minutes+=70;p.dev.appearances++;var match={finished:true,pair:[S.club,1],userSide:0};recordIndividualObjectivesRound(match);recordIndividualObjectivesRound(match)');
assert.equal(r('S.economy.objectives[0].completed'),1);
assert.equal(r('S.economy.objectives[0].observed'),70);
assert.equal(r('reviseIndividualObjective(id,200)'),true);
assert.equal(r('S.economy.objectives[0].target'),180,'a proposed revision is NOT applied');
assert.equal(r('S.economy.objectives[0].revision.target'),190,'counterproposal based on remaining matches');
assert.ok(valid(r));
assert.equal(r('confirmIndividualObjective(id)'),true);
assert.equal(r('S.economy.objectives[0].target'),190);
assert.ok(valid(r));
observationWeeks(1);r('p.dev.minutes+=70;p.dev.appearances++;recordIndividualObjectivesRound(match)');
assert.equal(r('S.economy.objectives[0].observed'),140);
observationWeeks(1);r('p.dev.minutes+=60;p.dev.appearances++;recordIndividualObjectivesRound(match)');
assert.equal(r('S.economy.objectives.length'),0);
assert.equal(r('S.economy.objectiveHistory[0].kind'),'met');
assert.equal(r('p.satisfaction.score'),65,'objective V38 never changes V36 satisfaction');
assert.ok(valid(r));
// Appearances, injuries and failure do not use fabricated stats.
observationWeeks(4-r('S.round'));
assert.equal(r('proposeIndividualObjective(id,"appearances",3,3)'),true);
assert.equal(r('S.economy.objectives[0].target'),2,'player counter on full appearances');
assert.equal(r('confirmIndividualObjective(id)'),true);
r('p.injury=1;recordIndividualObjectivesRound(match)');
assert.equal(r('S.economy.objectives[0].completed'),0);
r('p.injury=0');
for(let i=0;i<3;i++){observationWeeks(1);r('recordIndividualObjectivesRound(match)');}
assert.equal(r('S.economy.objectives.length'),0);
assert.equal(r('S.economy.objectiveHistory[0].kind'),'missed');
assert.ok(valid(r));
// Injury lock, active match and cancellation are safe.
observationWeeks(9-r('S.round'));
assert.equal(r('proposeIndividualObjective(id,"minutes",120,3)'),true);
assert.equal(r('cancelObjectiveDraft(id)'),true);
assert.equal(r('S.economy.objectives.length'),0);
const copy=JSON.parse(r('JSON.stringify(S)'));
let restored=context(copy),q=restored.run;
assert.ok(valid(q));
assert.equal(q('S.economy.objectiveHistory[0].kind'),'proposed');
// New season closes unfinished objectives without penalties.
observationWeeks(12-r('S.round'));r('proposeIndividualObjective(id,"minutes",120,3);confirmIndividualObjective(id)');
// Clôture reçue réellement ; l’API annuelle publique traite ensuite son entrée
// non achevée comme le faisait ce contrôle de composant historique.
r('var objectiveBeforeClosure=JSON.stringify(S.economy.objectives)');t.season();
r('S.economy.objectives=JSON.parse(objectiveBeforeClosure);advanceSeason()');
assert.equal(r('S.economy.objectives.length'),0);
assert.equal(r('S.economy.objectiveHistory[0].kind'),'expired');
assert.ok(valid(r));
t.close();t=null;r=null;
// Bad external input fails validation.
const bad=context(),b=bad.run;b('start(0);S.economy.objectives=[{playerId:"unknown"}]');
assert.throws(()=>b('validateCareer(S)'));bad.close();
const legacy=JSON.parse(q('JSON.stringify(S)'));
delete legacy.objectivesVersion;delete legacy.economy.objectives;delete legacy.economy.objectiveHistory;
restored.ctx.objectivesLegacy=legacy;try{q('validateCareer(objectivesLegacy);parseSaveDocument(JSON.stringify(createSaveDocument(objectivesLegacy)))')}finally{delete restored.ctx.objectivesLegacy;}
restored.close();restored=null;q=null;
const oldGame=context(legacy),h=oldGame.run;
assert.equal(h('objectivesActive()'),false);
assert.equal(h('proposeIndividualObjective(club().players[0].id,"minutes",120,3)'),false);
assert.ok(h('individualObjectivesPanel().includes("Activation volontaire")'));
assert.ok(valid(h));
assert.equal(h('activateObjectives()'),true);
assert.ok(valid(h));oldGame.close();
const pause=context(legacy),z=pause.run;
pause.deferSaves();pause.toMatch();z('beginMatch();pauseMatch()');
assert.equal(z('activateObjectives()'),false);
assert.equal(z('S.objectivesVersion'),undefined);
assert.ok(valid(z));pause.close();
console.log(JSON.stringify({passed:true,checks:['proposal and counter','explicit acceptance','measured minutes','idempotent round','revision by agreement','appearances','injury skip','season expiry','save validity','legacy and paused match']}));
