'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const repo = path.join(__dirname, '..');
const {context} = require('./monde-harness.cjs');

// Carrière Monde réelle (world-champ) d'un club de Nationale (88) : règles, match et crochets de fin de
// match sont ceux du moteur (CDWorldNationale, CDWorldNationaleMatch, finishRugbyMatch du Monde). Chaque
// cas repart du même état ; seule la graine du direct varie.
const shared = context(827381, {club: 88}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
function setup({seed = 827381, phase = 'barrage', competition = 'nationale'} = {}) {
  const h = shared.restore(base);
  h.setSeed(seed);
  Object.assign(h.ctx, {phase, competition});
  h.run(`var N=CDWorldNationale;
    var pair=nextMatch(); // vraie affiche de la semaine, rejouée en phase finale
    var fixture={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:2026,homeId:pair[0],awayId:pair[1]};
    var l=createRugbyMatch(pair,null,false);l.worldContext=fixture;
    var end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false;}};
    var validate=()=>{validateRestartState(l,S);validateFlowState(l,S);CDWorldNationaleMatch.validateLive(l,fixture)};
    var result=()=>JSON.parse(JSON.stringify({fixtureId:fixture.id,competitionId:fixture.competitionId,phase:fixture.phase,season:fixture.season,
      pair:l.pair,score:l.score,tries:l.tries,stats:l.stats,duration:l.minute,weather:l.weather,winner:l.winner,decision:l.decision,
      ...CDWorldNationaleMatch.historyFields(l)}));
    var verifyResult=()=>CDWorldNationaleMatch.validateResult(result(),fixture);`);
  return h;
}

test('Deux périodes de dix minutes, reprise en sens inverse et score causal conservé', () => {
  const h = setup();
  h.run(`end(40);end(80);validate();
    l.minute=85;var rng=Math.random;Math.random=()=>0;try{scoreTry(l,0,'open')}finally{Math.random=rng};
    validate();end(90);validate();
    var saved=JSON.stringify(l);l=JSON.parse(saved);validate();
    var oldWorld=S.worldMode,oldDb=S.commonDatabase;
    S.worldMode={version:3};S.commonDatabase={id:'rugby-world-2026-11-09-japan-v3'};
    try{CDWorldNationaleMatch.validateLive(l,fixture)}finally{S.worldMode=oldWorld;S.commonDatabase=oldDb}
    l.minute=95;Math.random=()=>0;try{scoreTry(l,0,'open')}finally{Math.random=rng};
    validate();end(100);validate();verifyResult()`);
  assert.equal(h.run('l.score.join()'), '14,0');
  assert.equal(h.run('l.decision.method'), 'score');
  assert.equal(h.run('l.stats[0].conversions'), 2);
  assert.equal(h.run('l.nationaleExtra.first.score.join()'), '7,0');
  assert.equal(h.run("l.restartLog.filter(r=>r.cause.startsWith('extra-')).map(r=>r.minute).join()"), '80,90');
  assert.throws(() => h.run('{const r=result();r.nationaleExtra.firstEnd=88;CDWorldNationaleMatch.validateResult(r,fixture)}'), /chronologie/i);
  assert.throws(() => h.run('{const r=result();r.score[0]++;CDWorldNationaleMatch.validateResult(r,fixture)}'), /score/i);
});

test('Le départage par essais attend la fin de la seconde prolongation', () => {
  const h = setup({phase:'semi'});
  h.run(`end(40);end(80);l.minute=83;var rng=Math.random;Math.random=()=>0;
    try{scoreTry(l,0,'open');l.minute=85;scoreTry(l,0,'open');l.minute=87;scoreTry(l,0,'open')}
    finally{Math.random=rng}
    end(90);validate();
    var wants=wantsPosts;wantsPosts=()=>true;Math.random=()=>0;
    try{for(let i=0;i<7;i++){l.minute=91+i;executePenaltyChoice(l,1)}}finally{Math.random=rng;wantsPosts=wants}
    end(100);validate();verifyResult()`);
  assert.equal(h.run('l.score.join()'), '21,21');
  assert.equal(h.run('l.decision.method'), 'tries');
  assert.equal(h.run('l.winner===l.pair[0]'), true);
  assert.equal(h.run('N.knockoutWinner(CDWorldNationaleMatch.asRuleResult(result())).winner===l.winner'), true);
});

test('Cinq tirs complets, relance avec autres joueurs et validation après sérialisation', () => {
  const h = setup({phase:'final'});
  h.run(`end(40);end(80);end(90);validate();
    var rng=Math.random;var calls=0;Math.random=()=>calls++===13?0:.99;
    try{end(100)}finally{Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.decision.method'), 'shootout');
  assert.equal(h.run('l.decision.shootout.attempts.length'), 6);
  assert.equal(h.run('l.score.join()'), '0,0');
  assert.equal(h.run('l.decision.shootout.attempts[5].every(k=>!l.decision.shootout.attempts.slice(0,5).flat().some(a=>a.playerId===k.playerId))'), true);
  assert.throws(() => h.run('{const r=result();r.decision.shootout.attempts[5][0].playerId=r.decision.shootout.attempts[0][0].playerId;CDWorldNationaleMatch.validateResult(r,fixture)}'), /buteur/i);
  assert.throws(() => h.run('{const r=result();r.decision.shootout.score=[9,9];CDWorldNationaleMatch.validateResult(r,fixture)}'), /tirs/i);
  assert.throws(() => h.run("{l.restartLog=l.restartLog.filter(r=>r.cause!=='extra-second');validate()}"), /reprise/i);
});

test('Horloge de match réelle avec seconde période et reprise depuis JSON', () => {
  // Première graine du direct (1 à 400) dont la finale va réellement en prolongation dans cette carrière.
  let h, found=0;
  for (let seed=1; seed<=400&&!found; seed++) {
    h=setup({phase:'final',seed});
    h.run('for(var i=0;i<150&&!l.finished&&!l.nationaleExtra;i++){l.paused=false;advanceRugby(l)}');
    if (h.run('!!l.nationaleExtra')) found=seed;
  }
  assert.ok(found,'une finale va en prolongation');
  h = setup({phase:'final',seed:found});
  h.run(`var reloads=0;
    for(let i=0;i<150&&!l.finished;i++){
      l.paused=false;advanceRugby(l);
      if(l.nationaleExtra){
        validate();
        if(reloads===0 || (reloads===1 && l.nationaleExtra.firstEnd!==null)){l=JSON.parse(JSON.stringify(l));reloads++;validate()}
      }
    }
    validate();verifyResult()`);
  assert.equal(h.run('l.finished && reloads===2'), true);
  assert.ok(h.run('l.stats.reduce((n,s)=>n+s.possession,0)===l.minute && l.minute>=100'));
});

test('Le contexte est limité aux phases KO de Nationale', () => {
  for (const args of [{phase:'league'}, {competition:'access-nationale',phase:'access'}, {competition:'jlo-d1',phase:'final'}]) {
    const h = setup(args);
    assert.equal(h.run('CDWorldNationaleMatch.applies(l,S)'), false);
  }
  assert.equal(setup().run('CDWorldNationaleMatch.applies(l,S)'), true);
});


test('La première série FFR continue jusqu’à cinq tirs par côté même avec un écart acquis', () => {
  const h = setup({phase:'barrage'});
  h.run(`end(40);end(80);end(90);
    var rng=Math.random;var calls=0;Math.random=()=>calls++%2===0?0:.99;
    try{end(100)}finally{Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.decision.shootout.attempts.length'), 5);
  assert.equal(h.run('l.decision.shootout.score.slice().sort().join()'), '0,5');
});


test('Une séance terminée se vérifie avec le profil v3 présent en mémoire',()=>{
 const h=setup();
 h.run("end(40);end(80);end(90);var tries=0;Math.random=()=>++tries<=2?0:tries%2?.99:0;end(100)");
 h.run("var old=S;var saved=JSON.stringify(l);try{S={worldMode:{version:3},clubs:[]};l=JSON.parse(saved);CDWorldNationaleMatch.validateLive(l,fixture)}finally{S=old}");
});
