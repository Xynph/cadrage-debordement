'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const repo = path.resolve(__dirname, '..');
const {context} = require('./france-harness.cjs');
const sharedKnockout = require('../native/engine/world-knockout.cjs');
const champFactory = require('../native/engine/champ-match.cjs');
const champRules = require('../native/engine/champ-rugby.cjs').factory;
const nationaleMatch = require('../native/engine/nationale-match.cjs');
const nationaleRules = require('../native/engine/nationale.cjs').factory;
const geometry = require('../native/engine/champ-calendar-2026-27.json');
const nationaleGeometry = require('../native/engine/nationale-calendar-2026-27.json');

function setup({phase='quarter', competition='champ', version=5, enabled=true, seed=827381}={}) {
  const h = context(seed, {source: file => fs.readFileSync(path.join(repo, 'dist', file), 'utf8')});
  Object.assign(h.ctx, {geometry, nationaleGeometry, phase, competition, version, enabled});
  h.run(`const CDWorldCareer={active(s){return [1,2,3,4,5].includes(s?.worldMode?.version)}};
    start(0);
    const C=(${champRules.toString()})(geometry);
    const N=(${nationaleRules.toString()})(nationaleGeometry);
    const CDWorldKnockout=(${sharedKnockout.toString()})();
    const CDWorldNationaleMatch=(${nationaleMatch.toString()})(N);
    const CDWorldChampMatch=(${champFactory.toString()})(C);
    const oldFinish=finishRugbyMatch;
    finishRugbyMatch=function(l){
      if(!l.worldContext)return oldFinish(l);
      const more=enabled&&CDWorldChampMatch.applies(l,S)?CDWorldChampMatch.finish(l):
        CDWorldNationaleMatch.applies(l,S)?CDWorldNationaleMatch.finish(l):CDWorldKnockout.finish(l);
      if(more)return;
      l.finished=true;l.paused=false;addEvent(l,'Coup de sifflet final.','end');
    };
    const pair=nextMatch();
    const fixture={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:2026,homeId:pair[0],awayId:pair[1]};
    let l=createRugbyMatch(pair,null,false);l.worldContext=fixture;
    const editionId={1:'world-v1',2:'rugby-world-2026-11-09-pacific-v2',3:'rugby-world-2026-11-09-japan-v3',
      4:'rugby-world-2026-11-09-nationale-v4',5:'rugby-world-2026-11-09-champ-v5'}[version];
    S.worldMode={version};S.commonDatabase={id:editionId,version};
    const end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false}};
    const validate=()=>{validateRestartState(l,S);validateFlowState(l,S);CDWorldChampMatch.validateLive(l,fixture)};
    const result=()=>JSON.parse(JSON.stringify({fixtureId:fixture.id,competitionId:fixture.competitionId,phase:fixture.phase,
      season:fixture.season,pair:l.pair,score:l.score,tries:l.tries,stats:l.stats,duration:l.minute,weather:l.weather,
      winner:l.winner,decision:l.decision,...CDWorldChampMatch.historyFields(l)}));
    const verifyResult=()=>CDWorldChampMatch.validateResult(result(),fixture);`);
  return h;
}

test('Deux périodes jouées, reprises inversées et import du direct indépendant de S', () => {
  const h=setup();
  h.run(`end(42);end(83);validate();
    const rng=Math.random;Math.random=()=>0;
    try{l.minute=86;scoreTry(l,0,'open')}finally{Math.random=rng}
    end(94);validate();
    l=JSON.parse(JSON.stringify(l));validate();
    const current=S;S={worldMode:{version:3},commonDatabase:{id:'rugby-world-2026-11-09-japan-v3'}};
    try{CDWorldChampMatch.validateLive(l,fixture)}finally{S=current}
    Math.random=()=>0;
    try{l.minute=99;scoreTry(l,0,'open')}finally{Math.random=rng}
    end(105);validate();verifyResult()`);
  assert.equal(h.run('l.champExtra.regulationEnd'),83);
  assert.equal(h.run('l.champExtra.firstEnd'),94);
  assert.equal(h.run('l.champExtra.end'),105);
  assert.equal(h.run('l.champExtra.first.score.join()'),'7,0');
  assert.equal(h.run('l.score.join()'),'14,0');
  assert.equal(h.run("l.restartLog.filter(r=>r.cause.startsWith('extra-')).map(r=>r.minute).join()"),'83,94');
  assert.equal(h.run("l.restartLog.filter(r=>r.cause.startsWith('extra-')).map(r=>r.team).join()")==='0,1' ||
    h.run("l.restartLog.filter(r=>r.cause.startsWith('extra-')).map(r=>r.team).join()")==='1,0',true);
  assert.throws(()=>h.run('{const r=result();r.champExtra.firstEnd=91;CDWorldChampMatch.validateResult(r,fixture)}'),/chronologie/);
  assert.throws(()=>h.run('{const r=result();r.score[0]++;CDWorldChampMatch.validateResult(r,fixture)}'),/score/);
  assert.throws(()=>h.run("{l.worldContext={...fixture,id:'falsifie'};validate()}"),/contexte/);
});

test('Essais, puis tirs seulement après la deuxième prolongation', () => {
  const h=setup({phase:'semi'});
  h.run(`end(40);end(80);const rng=Math.random;Math.random=()=>0;
    try{for(let i=0;i<3;i++){l.minute=83+i;scoreTry(l,0,'open')}}finally{Math.random=rng}
    end(90);validate();
    const wants=wantsPosts;wantsPosts=()=>true;Math.random=()=>0;
    try{for(let i=0;i<7;i++){l.minute=91+i;executePenaltyChoice(l,1)}}finally{wantsPosts=wants;Math.random=rng}
    end(100);validate();verifyResult()`);
  assert.equal(h.run('l.score.join()'),'21,21');
  assert.equal(h.run('l.decision.method'),'tries');
  assert.equal(h.run('C.knockoutWinner(CDWorldChampMatch.asRuleResult(result())).winner===l.pair[0]'),true);
  assert.throws(()=>h.run('{const r=result();r.winner=r.pair[1];CDWorldChampMatch.validateResult(r,fixture)}'),/vainqueur/);
});

test('Six tirs par équipe complets à 6–0, puis horloge et score rugby inchangés', () => {
  const h=setup({phase:'final'});
  h.run(`end(40);end(80);end(90);
    const rng=Math.random;let calls=0;Math.random=()=>calls++%2===0?0:.99;
    try{end(100)}finally{Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.decision.shootout.attempts.length'),12);
  assert.equal(h.run('l.decision.shootout.score.slice().sort().join()'),'0,6');
  assert.equal(h.run('l.score.join()'),'0,0');
  assert.equal(h.run('l.minute'),100);
  assert.equal(h.run('l.decision.shootout.attempts.map(a=>a.position).join()'),'1,1,2,2,3,3,4,4,5,5,6,6');
  assert.throws(()=>h.run('{const r=result();r.decision.shootout.attempts.pop();CDWorldChampMatch.validateResult(r,fixture)}'),/tirs/);
});

test('Mort subite au point 4 avec un tir de chaque côté et preuve de terrain', () => {
  const h=setup({phase:'access'});
  h.run(`end(40);end(80);end(90);
    const rng=Math.random;let calls=0;Math.random=()=>calls++===15?0:.99;
    try{end(100)}finally{Math.random=rng}
    validate();verifyResult();l=JSON.parse(JSON.stringify(l));
    const current=S;S={worldMode:{version:3},commonDatabase:{id:'rugby-world-2026-11-09-japan-v3'}};
    try{CDWorldChampMatch.validateLive(l,fixture)}finally{S=current}`);
  assert.equal(h.run('l.decision.shootout.attempts.length'),14);
  assert.equal(h.run('l.decision.shootout.attempts.slice(12).map(a=>a.position).join()'),'4,4');
  assert.equal(h.run('l.decision.shootout.attempts.slice(12).every(a=>a.playerId===l.decision.shootout.kickers[a.side][0])'),true);
  assert.throws(()=>h.run('{const r=result();r.decision.shootout.attempts[12].position=2;CDWorldChampMatch.validateResult(r,fixture)}'),/position/);
  assert.throws(()=>h.run("{l.decision.shootout.eligible[0].push('invented');validate()}"),/terrain/);
});

test('Relecture du match réel à partir de JSON dans les deux périodes', () => {
  // Native v2 initializer consumes RNG for population: seed42 reaches real extra time.
  const h=setup({phase:'relegation',seed:42});
  assert.equal(h.run('S.aiRosterVersion'),2,'exercise real current population setup');
  h.run(`let reloads=0;
    for(let i=0;i<150&&!l.finished;i++){
      l.paused=false;advanceRugby(l);
      if(l.champExtra){
        validate();
        if(reloads===0 || (reloads===1&&l.champExtra.firstEnd!==null)){
          l=JSON.parse(JSON.stringify(l));reloads++;validate()
        }
      }
    }validate();verifyResult()`);
  assert.equal(h.run('l.finished && reloads===2'),true);
  assert.equal(h.run('l.stats.reduce((n,s)=>n+s.possession,0)===l.minute'),true);
});

test('Phase et édition exactes. Les éditions v1 à v4 conservent le même RNG', () => {
  for (const args of [{version:4},{phase:'league'},{competition:'national1-promotion',phase:'promotion'},{competition:'elite',phase:'final'}]) {
    assert.equal(setup(args).run('CDWorldChampMatch.applies(l,S)'),false);
  }
  const wrong=setup();
  assert.equal(wrong.run("CDWorldChampMatch.applies(l,{worldMode:{version:5},commonDatabase:{id:'wrong'}})"),false);
  const legacy=[1,2,3].map(version=>({version,competition:'elite',phase:'final'}));
  for (const args of [...legacy,{version:4,competition:'nationale',phase:'final'}]) {
    const outputs=[false,true].map(enabled=>{
      const h=setup({...args,enabled,seed:73});
      h.run('for(let i=0;i<150&&!l.finished;i++){l.paused=false;advanceRugby(l)}');
      return h.run('JSON.stringify([l.score,l.stats,l.restartLog,l.decision,l.nationaleExtra,l.champExtra,Math.random()])');
    });
    assert.equal(outputs[0],outputs[1]);
  }
});
