'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const repo = path.join(__dirname, '..');
const {context} = require('./france-harness.cjs');
const oldKnockout = require(path.join(repo, 'native/engine/world-knockout.cjs'));
const matchFactory = require('../native/engine/nationale-match.cjs');
const rulesFactory = require('../native/engine/nationale.cjs').factory;
const geometry = require('../native/engine/nationale-calendar-2026-27.json');

function setup({seed = 827381, phase = 'barrage', version = 4, competition = 'nationale', enabled = true} = {}) {
  const h = context(seed, {source: file => fs.readFileSync(path.join(repo, 'dist', file), 'utf8')});
  Object.assign(h.ctx, {geometry, phase, version, competition});
  // Le vrai setup v2 s'exécute avant les doubles lexicaux Monde.
  h.run('start(0)');
  h.run(`
    const N=(${rulesFactory.toString()})(geometry);
    const CDWorldCareer={active(s){return [3,4].includes(s?.worldMode?.version)}};
    const CDWorldKnockout=(${oldKnockout.toString()})();
    const CDWorldNationaleMatch=(${matchFactory.toString()})(N);
    const previous=finishRugbyMatch;
    finishRugbyMatch=function(l){
      if(!l.worldContext)return previous(l);
      if(${enabled} && CDWorldNationaleMatch.applies(l,S)?CDWorldNationaleMatch.finish(l):CDWorldKnockout.finish(l))return;
      l.finished=true;l.paused=false;addEvent(l,'Coup de sifflet final.','end');
    };
    const pair=nextMatch();
    const fixture={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:2026,homeId:pair[0],awayId:pair[1]};
    let l=createRugbyMatch(pair,null,false);l.worldContext=fixture;
    S.worldMode={version};S.commonDatabase={id:version===4?'rugby-world-2026-11-09-nationale-v4':'rugby-world-2026-11-09-japan-v3',version};
    const end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false;}};
    const validate=()=>{validateRestartState(l,S);validateFlowState(l,S);CDWorldNationaleMatch.validateLive(l,fixture)};
    const result=()=>JSON.parse(JSON.stringify({fixtureId:fixture.id,competitionId:fixture.competitionId,phase:fixture.phase,season:fixture.season,
      pair:l.pair,score:l.score,tries:l.tries,stats:l.stats,duration:l.minute,weather:l.weather,winner:l.winner,decision:l.decision,
      ...CDWorldNationaleMatch.historyFields(l)}));
    const verifyResult=()=>CDWorldNationaleMatch.validateResult(result(),fixture);`);
  return h;
}

test('Deux périodes de dix minutes, reprise en sens inverse et score causal conservé', () => {
  const h = setup();
  h.run(`end(40);end(80);validate();
    l.minute=85;const rng=Math.random;Math.random=()=>0;try{scoreTry(l,0,'open')}finally{Math.random=rng};
    validate();end(90);validate();
    const saved=JSON.stringify(l);l=JSON.parse(saved);validate();
    const oldWorld=S.worldMode,oldDb=S.commonDatabase;
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
  h.run(`end(40);end(80);l.minute=83;const rng=Math.random;Math.random=()=>0;
    try{scoreTry(l,0,'open');l.minute=85;scoreTry(l,0,'open');l.minute=87;scoreTry(l,0,'open')}
    finally{Math.random=rng}
    end(90);validate();
    const wants=wantsPosts;wantsPosts=()=>true;Math.random=()=>0;
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
    const rng=Math.random;let calls=0;Math.random=()=>calls++===13?0:.99;
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
  // Le setup v2 consomme le pool avant le match ; ce témoin donne un vrai nul à 80 minutes.
  const h = setup({phase:'final',seed:71});
  h.run(`let reloads=0;
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

test('Le contexte est limité aux KO v4 et le moteur v3 garde le même RNG', () => {
  for (const args of [{version:3}, {phase:'league'}, {competition:'access-nationale',phase:'access'}, {competition:'jlo-d1',phase:'final'}]) {
    const h = setup(args);
    assert.equal(h.run('CDWorldNationaleMatch.applies(l,S)'), false);
  }
  const outcomes = [false, true].map(enabled => {
    const h = setup({enabled,version:3,competition:'elite',phase:'final',seed:73});
    h.run('for(let i=0;i<150&&!l.finished;i++){l.paused=false;advanceRugby(l)}');
    return h.run('JSON.stringify([l.score,l.stats,l.restartLog,l.decision,l.nationaleExtra,Math.random()])');
  });
  assert.equal(outcomes[0], outcomes[1]);
});


test('La première série FFR continue jusqu’à cinq tirs par côté même avec un écart acquis', () => {
  const h = setup({phase:'barrage'});
  h.run(`end(40);end(80);end(90);
    const rng=Math.random;let calls=0;Math.random=()=>calls++%2===0?0:.99;
    try{end(100)}finally{Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.decision.shootout.attempts.length'), 5);
  assert.equal(h.run('l.decision.shootout.score.slice().sort().join()'), '0,5');
});


test('Une séance terminée se vérifie avec le profil v3 présent en mémoire',()=>{
 const h=setup();
 h.run("end(40);end(80);end(90);let tries=0;Math.random=()=>++tries<=2?0:tries%2?.99:0;end(100)");
 h.run("const old=S;const saved=JSON.stringify(l);try{S={worldMode:{version:3},clubs:[]};l=JSON.parse(saved);CDWorldNationaleMatch.validateLive(l,fixture)}finally{S=old}");
});
