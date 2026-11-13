'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const repo = path.resolve(__dirname,'..');
const pkg = path.join(repo,'native','engine');
const {context} = require(path.join(repo,'tests','monde-harness.cjs'));

// Carrière Monde réelle (world-champ) d'un club de League One (68) : règles japonaises et SRP, validation et
// fin de match sont celles du moteur. Chaque cas repart de la semaine du premier match du club.
const shared = context(827381,{club:68}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
function setup({phase='quarter',automated=false,competition='jlo-d1',seed=827381}={}) {
  const h = shared.restore(base);
  h.setSeed(seed);
  Object.assign(h.ctx,{phase,competition});
  h.run(`var pair=nextMatch();
    var fixture={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:2026,homeId:pair[0],awayId:pair[1],seeds:[3,6]};
    var l=createRugbyMatch(pair,null,${automated});l.worldContext=fixture;
    var end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false;}};
    var validate=()=>{validateRestartState(l,S);validateFlowState(l,S);CDWorldValidation.live(l,fixture);validateActionScenes(l,S);};
    var result=()=>JSON.parse(JSON.stringify({fixtureId:fixture.id,competitionId:fixture.competitionId,phase:fixture.phase,season:fixture.season,
      pair:l.pair,weather:l.weather,duration:l.minute,score:l.score,tries:l.tries,stats:l.stats,winner:l.winner,decision:l.decision,
      ...CDWorldJapanMatch.historyFields(l),...CDWorldSRPMatch.historyFields(l)}));
    var verifyResult=()=>CDWorldValidation.result(result(),fixture);`);
  return h;
}

test('Play-off D1, essai décisif réel à cinq points et preuve de scène', () => {
  const h=setup();
  h.run("end(40);end(80);validate();l.minute=81;scoreTry(l,0,'open');validate();verifyResult()");
  assert.equal(h.run('l.finished && l.minute===81 && l.flow.fullEnd===90'),true);
  assert.equal(h.run('l.score.join()'),'5,0');
  assert.equal(h.run('l.stats[0].conversionAttempts'),0);
  assert.equal(h.run('l.decision.method'),'golden-score');
  assert.equal(h.run("l.restartLog.filter(r=>r.cause==='jlo-golden').length"),1);
  assert.throws(()=>h.run("{const r=result();r.japanExtra.firstScore.minute++;CDWorldValidation.result(r,fixture)}"),/première marque/i);
  assert.throws(()=>h.run("{l.events=l.events.filter(e=>e.type!=='try');validate()}"),/causal/i);
});

test('Marque décisive IA : une seule scène et userSide inchangé', () => {
  const h=setup({automated:true,phase:'semi'});
  h.run(`end(40);end(80);l.minute=82;
    var wants=wantsPosts,rng=Math.random;wantsPosts=()=>true;Math.random=()=>0;
    try{executePenaltyChoice(l,1)}finally{wantsPosts=wants;Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.userSide'),-1);
  assert.equal(h.run('l.score.join()'),'0,3');
  assert.equal(h.run('l.events.filter(e=>e.scene).length'),1);
});

test('Bronze : cinq joueurs puis première position à la sixième tentative', () => {
  const h=setup({phase:'third-place'});
  h.run(`end(40);end(80);validate();var rng=Math.random;var n=0;Math.random=()=>n++===11?0:.99;
    try{end(90)}finally{Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.decision.method'),'shootout');
  assert.equal(h.run('l.decision.shootout.kickers.map(a=>a.length).join()'),'5,5');
  assert.equal(h.run('l.decision.shootout.attempts.length'),12);
  assert.equal(h.run('l.decision.shootout.attempts[10].location'),1);
  assert.equal(h.run('l.score.join()'),'0,0');
  assert.throws(()=>h.run("{const r=result();r.decision.shootout.attempts[10].location=3;CDWorldValidation.result(r,fixture)}"),/tirs/i);
  assert.throws(()=>h.run("{const r=result();r.duration=89;r.japanExtra.end=89;CDWorldValidation.result(r,fixture)}"),/durée|prolongation/i);
  assert.throws(()=>h.run("{l.restartLog=l.restartLog.filter(r=>r.cause!=='jlo-golden');validate()}"),/reprise/i);
});

test('Chronomètre effectif et match complet sans mutation de la durée du règlement', () => {
  // Première graine du direct (1 à 400) dont la finale fait un vrai nul réglementaire : aucun score injecté,
  // le match réel produit sa prolongation.
  let h, found=0;
  for (let seed=1; seed<=400&&!found; seed++) {
    h=setup({phase:'final',seed});
    h.run('for(var i=0;i<130&&!l.finished&&!l.japanExtra;i++){l.paused=false;advanceRugby(l)}');
    if (h.run('!!l.japanExtra')) found=seed;
  }
  assert.ok(found,'une finale va en prolongation');
  h=setup({phase:'final',seed:found});
  h.run(`for(let i=0;i<130&&!l.finished;i++){
      l.paused=false;advanceRugby(l);
      if(l.japanExtra)validate();
    }validate();verifyResult()`);
  assert.ok(h.run('l.finished && l.japanExtra && l.stats.reduce((n,s)=>n+s.possession,0)===l.minute'));
});

test('Le nul reste valide en championnat et dans chaque manche de barrage', () => {
  for (const [competition,phase] of [['jlo-d1','league'],['jlo-d1-d2','promotion']]) {
    const h=setup({phase,competition});
    h.run('end(40);end(80);validate();verifyResult()');
    assert.equal(h.run('l.finished && l.minute===80 && l.winner===undefined && l.japanExtra===undefined'),true);
    assert.throws(()=>h.run('l.japanExtra={};validateRestartState(l,S)'),/hors de son édition/i);
  }
});

test('SRP : prolongation propre à la compétition, sans état japonais', () => {
  const h=setup({phase:'league',competition:'srp'});
  h.run("end(40);end(80);l.minute=81;scoreTry(l,0,'open');validate();verifyResult()");
  assert.equal(h.run('l.finished && l.srpExtra!==undefined && l.japanExtra===undefined'),true);
  assert.throws(()=>h.run('{const r=result();r.japanExtra={};CDWorldValidation.result(r,fixture)}'),/hors de sa compétition/i);
});
