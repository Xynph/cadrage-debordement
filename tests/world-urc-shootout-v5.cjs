'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test} = require('node:test');

const repo = path.join(__dirname, '..');
const engine = path.join(repo, 'native', 'engine');
const {context} = require(path.join(repo, 'tests', 'monde-harness.cjs'));
const copy = value => JSON.parse(JSON.stringify(value));

// Carrière Monde réelle (world-champ, édition v5) d'un club d'URC (40) : règles, validation et fin de match
// sont celles du moteur. Chaque cas repart du même état et de la même graine.
const shared = context(82389, {club: 40}).toMatch(), base = shared.checkpoint();
require('node:test').after(() => shared.close());
function fixture({competition = 'urc', phase = 'quarter'} = {}) {
  const h = shared.restore(base);
  Object.assign(h.ctx, {competition, phase});
  h.run(`
    var pair=nextMatch(); // vraie affiche de la semaine, rejouée selon la phase du cas
    var f={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:1,week:S.round,homeId:pair[0],awayId:pair[1]};
    var l=createRugbyMatch(pair,null,false);l.worldContext=f;
    var end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false}};
    var liveCheck=()=>{validateFlowState(l,S);validateRestartState(l,S)};
    var proof=()=>JSON.parse(JSON.stringify({pair:l.pair,score:l.score,tries:l.tries,stats:l.stats,
      weather:l.weather,duration:l.minute,winner:l.winner,decision:l.decision}));
    var checkWithoutGlobal=(r,version,live=null)=>{
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

test('Les autres compétitions v5 gardent leur arrêt historique', () => {
  for(const options of ['prem','champions','challenge','elite'].map(competition=>({competition}))){
    const h = fixture(options);
    const result = finish(h, nearCertain);
    assert.equal(result.calls, 9);
    validate(h, result.proof, 5);
    validate(h, result.proof, 5, result.live);
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
