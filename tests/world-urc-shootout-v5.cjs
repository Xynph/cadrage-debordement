'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test} = require('node:test');

const repo = path.join(__dirname, '..');
const engine = path.join(repo, 'native', 'engine');
const {context} = require(path.join(repo, 'tests', 'france-harness.cjs'));
const competitionRules = require(path.join(engine, 'world-competitions.cjs')).factory;
const dispatcher = require(path.join(engine, 'world-dispatch.cjs'));
const copy = value => JSON.parse(JSON.stringify(value));

function fixture({edition = 5, competition = 'urc', phase = 'quarter'} = {}) {
  const sources = engine;
  const career = require(path.join(sources, 'world-career.cjs'));
  const knockout = require(path.join(sources, 'world-knockout.cjs'));
  const validation = require(path.join(sources, 'world-validation.cjs'));
  const h = context(82389, {source: name => fs.readFileSync(path.join(repo, 'dist', name), 'utf8')});
  Object.assign(h.ctx, {edition, competition, phase});
  // Initialiser le vrai moteur avant de déclarer les doubles lexicaux Monde.
  h.run('start(0)');
  h.run(`
    const CDWorldCompetitions=(${competitionRules.toString()})();
    const CDWorldKnockout=(${knockout.toString()})();
    const CDWorldValidation=(${validation.toString()})();
    const entries=[1,2,3,4,5].map(version=>({
      version,registry:{clubs:[]},leagueIds:['urc'],playable:[]
    }));
    const editions={entries,forState:s=>entries.find(e=>e.version===s?.worldMode?.version)||null};
    const CDWorldCareer=(${dispatcher.toString()})(editions,${career.toString()});
    const pair=nextMatch();
    const f={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:1,week:40,homeId:pair[0],awayId:pair[1]};
    S.worldMode={version:edition,fixtures:[f]};S.round=f.week;
    CDWorldCareer.installHooks();
    let l=createRugbyMatch(pair);
    const end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false}};
    const liveCheck=()=>{validateFlowState(l,S);validateRestartState(l,S)};
    const proof=()=>JSON.parse(JSON.stringify({pair:l.pair,score:l.score,tries:l.tries,stats:l.stats,
      weather:l.weather,duration:l.minute,winner:l.winner,decision:l.decision}));
    const checkWithoutGlobal=(r,version,live=null)=>{
      const previous=S;S=null;
      try{
        if(live)CDWorldValidation.live(live,f,version);
        else CDWorldValidation.result(r,f,null,version);
      }finally{S=previous}
    };
    end(42);end(83);
  `);
  return h;
}

const bothFail = [0.999, 0.999];
const homeWins = [0, 0.999];
const bothScore = [0, 0];
const nearCertain = Array.from({length:6}, () => homeWins).flat();

function finish(h, attempts) {
  h.ctx.attemptRandom = attempts;
  return copy(h.run(`{
    if(l.knockout)end(94);
    const preShootout={score:l.score.slice(),tries:l.tries.slice(),stats:JSON.stringify(l.stats)};
    let calls=0;const rng=Math.random;
    Math.random=()=>{const value=calls<2?.1:attemptRandom[calls-2];calls++;if(value===undefined)throw Error('Unexpected draw');return value};
    try{end(l.knockout?105:83)}finally{Math.random=rng}
    liveCheck();
    const restartTimes=l.restartLog.filter(r=>r.cause.startsWith('extra-')).map(r=>r.minute);
    ({preShootout,after:{score:l.score,tries:l.tries,stats:JSON.stringify(l.stats)},proof:proof(),
      live:JSON.parse(JSON.stringify(l)),calls,restartTimes,nextRandom:Math.random()})
  }`));
}

function validate(h, result, edition, live = null) {
  Object.assign(h.ctx, {testResult: result, testEdition: edition, testLive: live});
  h.run('checkWithoutGlobal(testResult,testEdition,testLive)');
}

test('v5 URC : six séries même à 6–0, sans avance de l’horloge ni changement du score', () => {
  const h = fixture();
  assert.equal(h.run('l.knockout.period'), 1);
  assert.equal(h.run('l.finished'), false);
  const result = finish(h, nearCertain);
  const q = result.proof.decision.shootout;
  assert.equal(result.calls, 14);
  assert.deepEqual(result.restartTimes, [83, 94]);
  assert.equal(result.proof.duration, 105);
  assert.deepEqual(result.preShootout, result.after);
  assert.deepEqual(q.score, [6, 0]);
  assert.deepEqual(q.attempts.map(a => a.location), [1,1,2,2,3,3,4,4,5,5,6,6]);
  assert.deepEqual(q.attempts.map(a => a.side), Array.from({length:6}, () => [0,1]).flat());
  validate(h, result.proof, 5);
  validate(h, result.proof, 5, result.live);
  assert.throws(() => validate(h, result.proof, 4), /tirs/);
});

test('v5 URC : mort subite par paires, rotation des buteurs à la position 4', () => {
  const h = fixture({phase: 'semi'});
  const result = finish(h, [...Array.from({length:6}, () => bothFail).flat(), ...bothScore, ...homeWins]);
  const q = result.proof.decision.shootout;
  assert.equal(result.calls, 18);
  assert.deepEqual(q.score, [2,1]);
  assert.deepEqual(q.attempts.slice(12).map(a => a.location), [4,4,4,4]);
  assert.deepEqual(q.attempts.slice(12).map(a => a.playerId),
    [q.kickers[0][0],q.kickers[1][0],q.kickers[0][1],q.kickers[1][1]]);
  assert.equal(result.proof.winner, result.proof.pair[0]);
  validate(h, result.proof, 5);
  validate(h, result.proof, 5, result.live);

  const oneKickShort = copy(result.proof);
  oneKickShort.decision.shootout.attempts.pop();
  assert.throws(() => validate(h, oneKickShort, 5), /tirs/);
  const extraPair = copy(result.proof);
  const dq = extraPair.decision.shootout;
  dq.attempts.push({side:0,playerId:dq.kickers[0][2],location:4,made:false},
    {side:1,playerId:dq.kickers[1][2],location:4,made:false});
  assert.throws(() => validate(h, extraPair, 5), /tirs/);
});

test('v5 URC : un arrêt anticipé historiquement valide est rejeté dans le direct et le résultat', () => {
  const old = finish(fixture({edition:4,phase:'final'}), nearCertain);
  const h = fixture({phase:'final'});
  assert.deepEqual(old.proof.decision.shootout.score, [4,0]);
  assert.equal(old.proof.decision.shootout.attempts.length, 7);
  validate(h, old.proof, 4);
  validate(h, old.proof, 4, old.live);
  assert.throws(() => validate(h, old.proof, 5), /tirs/);
  assert.throws(() => validate(h, old.proof, 5, old.live), /tirs/);
});

test('v1–v4 URC et autres compétitions v5 gardent leur arrêt historique', () => {
  for(const options of [...[1,2,3,4].map(edition=>({edition})), ...['prem','champions','challenge','elite'].map(competition=>({competition}))]){
    const h = fixture(options);
    const result = finish(h, nearCertain);
    assert.equal(result.calls, 9);
    validate(h, result.proof, options.edition ?? 5);
    validate(h, result.proof, options.edition ?? 5, result.live);
  }
});

test('v5 URC : nul de phase régulière et buteur exclu', () => {
  const regular = fixture({phase:'league'});
  assert.equal(regular.run('l.finished'), true);
  assert.equal(regular.run('l.decision'), undefined);
  assert.equal(regular.run('l.knockout'), undefined);

  const h = fixture({phase:'final'});
  const result = finish(h, nearCertain);
  const bad = copy(result.live);
  bad.sheets[0].cards.push({id:result.proof.decision.shootout.kickers[0][0],until:106});
  assert.throws(() => validate(h, result.proof, 5, bad), /inéligible/);
});
