'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const repo = path.resolve(__dirname,'..');
const pkg = path.join(repo,'native','engine');
const {context} = require(path.join(repo,'tests','france-harness.cjs'));
const japanFactory = require(path.join(pkg,'japan-match.cjs'));
const rulesFactory = require(path.join(pkg,'league-one-d1.cjs')).factory;
const srpFactory = require(path.join(pkg,'srp-match.cjs'));
const srpRulesFactory = require(path.join(pkg,'super-rugby-pacific.cjs')).factory;
const validation = require(path.join(pkg,'world-validation.cjs'));

function setup({phase='quarter',automated=false,installJapan=true,competition='jlo-d1',seed=827381}={}) {
  const h = context(seed,{source:file => fs.readFileSync(path.join(repo,'dist',file),'utf8')});
  Object.assign(h.ctx,{japanCalendar:require(path.join(pkg,'jlo-d1-calendar-2026-27-public.json')),pacificCalendar:require(path.join(pkg,'srp-calendar-2027.json')),phase,competition});
  h.run(`start(0);const CDWorldJapanRules=(${rulesFactory.toString()})(japanCalendar);
    const CDWorldSRP=(${srpRulesFactory.toString()})(pacificCalendar);
    const CDWorldCareer={active(s){return [2,3].includes(s?.worldMode?.version)}};
    const CDWorldSRPMatch=(${srpFactory.toString()})(CDWorldSRP);CDWorldSRPMatch.installHooks();
    const CDWorldJapanMatch=(${japanFactory.toString()})(CDWorldJapanRules);
    ${installJapan?'CDWorldJapanMatch.installHooks();':''}
    const CDWorldValidation=(${validation.toString()})();
    const previous=finishRugbyMatch;
    finishRugbyMatch=function(l){
      if(CDWorldJapanMatch.applies(l,S)){if(CDWorldJapanMatch.finish(l))return;}
      else if(CDWorldSRPMatch.applies(l,S)){if(CDWorldSRPMatch.finish(l))return;}
      else return previous(l);
      l.finished=true;l.paused=false;addEvent(l,'Coup de sifflet final.','end');
    };
    const pair=nextMatch();
    const fixture={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:2026,homeId:pair[0],awayId:pair[1],seeds:[3,6]};
    const l=createRugbyMatch(pair,null,${automated});l.worldContext=fixture;
    const v2=competition==='srp';
    S.worldMode={version:v2?2:3};S.commonDatabase={id:v2?'rugby-world-2026-11-09-pacific-v2':'rugby-world-2026-11-09-japan-v3',version:v2?2:3};
    const end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false;}};
    const validate=()=>{validateRestartState(l,S);validateFlowState(l,S);CDWorldValidation.live(l,fixture);validateActionScenes(l,S);};
    const result=()=>JSON.parse(JSON.stringify({fixtureId:fixture.id,competitionId:fixture.competitionId,phase:fixture.phase,season:fixture.season,
      pair:l.pair,weather:l.weather,duration:l.minute,score:l.score,tries:l.tries,stats:l.stats,winner:l.winner,decision:l.decision,
      ...CDWorldJapanMatch.historyFields(l),...CDWorldSRPMatch.historyFields(l)}));
    const verifyResult=()=>CDWorldValidation.result(result(),fixture);`);
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
    const wants=wantsPosts,rng=Math.random;wantsPosts=()=>true;Math.random=()=>0;
    try{executePenaltyChoice(l,1)}finally{wantsPosts=wants;Math.random=rng}
    validate();verifyResult()`);
  assert.equal(h.run('l.userSide'),-1);
  assert.equal(h.run('l.score.join()'),'0,3');
  assert.equal(h.run('l.events.filter(e=>e.scene).length'),1);
});

test('Bronze : cinq joueurs puis première position à la sixième tentative', () => {
  const h=setup({phase:'third-place'});
  h.run(`end(40);end(80);validate();const rng=Math.random;let n=0;Math.random=()=>n++===11?0:.99;
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
  const h=setup({phase:'final',seed:73});
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

test('SRP v2 et son RNG sont exactement identiques avec ou sans hooks japonais', () => {
  const outcomes=[false,true].map(installJapan=>{
    const h=setup({phase:'league',competition:'srp',installJapan});
    h.run("end(40);end(80);l.minute=81;scoreTry(l,0,'open');validate();verifyResult()");
    assert.equal(h.run('l.finished && l.srpExtra!==undefined && l.japanExtra===undefined'),true);
    assert.throws(()=>h.run('{const r=result();r.japanExtra={};CDWorldValidation.result(r,fixture)}'),/hors de sa compétition/i);
    return [h.run('JSON.stringify(l)'),h.seed()];
  });
  assert.deepEqual(outcomes[0],outcomes[1]);
});
