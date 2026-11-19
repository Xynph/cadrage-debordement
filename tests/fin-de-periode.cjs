'use strict';
// Fin de période et prolongations (lois 5 et 8 de World Rugby ; docs/rugby-rules-reference.md, « Fin de période ») :
// sirène annoncée une fois quand le ballon est vivant, pénalité après la sirène jouée puis fin de période, horloge
// et annonces des prolongations, tirs au but commentés tir par tir. Carrière Monde (world-champ), club d'URC (40),
// tirages imposés : chaque cas repart du même état.
const assert = require('node:assert/strict');
const path = require('node:path');
const {test, after} = require('node:test');
const {context} = require(path.join(__dirname, 'monde-harness.cjs'));

const shared = context(82389, {club: 40}).toMatch(), base = shared.checkpoint();
after(() => shared.close());
const SIRENE = /sirène|temps est écoulé/i;

// Vraie rencontre de la semaine (phase régulière), en pause au coup d'envoi.
function live() {
  const h = shared.restore(base);
  h.run(`beginMatch();pauseMatch();var l=S.live;
    var sirenes=()=>l.events.filter(e=>/sirène a retenti|^Sirène|temps est écoulé/i.test(e.text)&&!/^Pénalité/.test(e.text));
    var saveOk=()=>!!createSaveDocument();`);
  return h;
}
// Phase finale rejouée sur l'affiche de la semaine (même montage que tests/world-urc-shootout-v5.cjs).
function knockout(competition = 'urc', phase = 'quarter') {
  const h = shared.restore(base);
  Object.assign(h.ctx, {competition, phase});
  h.run(`var pair=nextMatch();
    var f={id:'vm:'+competition+':'+phase,competitionId:competition,phase,season:1,week:S.round,homeId:pair[0],awayId:pair[1]};
    var l=createRugbyMatch(pair,null,false);l.worldContext=f;
    var end=minute=>{l.minute=minute;endFlowPeriod(l);if(l.flow.atBreak){resumeFlowHalf(l);l.paused=false}};
    var liveCheck=()=>{validateFlowState(l,S);validateRestartState(l,S);const p=S;S=null;try{CDWorldValidation.live(l,f,5)}finally{S=p}};
    end(42);`);
  return h;
}

test('Nouvelle rencontre : marqueur endPeriodVersion posé à la création', () => {
  const h = live();
  assert.equal(h.run('l.endPeriodVersion'), 1);
  assert.equal(h.run('l.sirene'), undefined);
});

test('Sirène annoncée une seule fois quand le ballon est vivant à 40′', () => {
  const h = live();
  h.run('l.minute=39;ballPossession(l,0,50);l.paused=false;Math.random=()=>.99;advanceRugby(l)');
  assert.equal(h.run('l.minute'), 40);
  assert.equal(h.run('l.sirene'), 40);
  assert.equal(h.run('sirenes().length'), 1);
  assert.match(h.run('sirenes()[0].text'), /mi-temps/);
  assert.equal(h.run('sirenes()[0].period'), 1);
  // Les actions suivantes de la même période n'annoncent plus rien.
  h.run('if(!l.flow.atBreak){l.minute=40;advanceFlowPlay(l);annonceSirene(l)}');
  assert.equal(h.run('sirenes().length'), 1);
  assert.equal(h.run('saveOk()'), true);
  // Sauvegarde hostile : sirène hors du temps joué refusée.
  assert.throws(() => h.run('l.sirene=l.minute+5;createSaveDocument()'), /Sirène/);
});

test('Pas de sirène quand le ballon est mort à la limite (renvoi dû) ni dans un match sans marqueur', () => {
  let h = live();
  h.run('l.minute=39;ballPossession(l,0,50);l.chrono.relance=["kickoff",1,"score",0];l.paused=false;advanceRugby(l)');
  assert.equal(h.run('atHalftime(l)'), true);
  assert.equal(h.run('sirenes().length'), 0);
  assert.equal(h.run('l.sirene'), undefined);
  h = live();
  h.run('delete l.endPeriodVersion;l.minute=39;ballPossession(l,0,50);l.paused=false;Math.random=()=>.99;advanceRugby(l)');
  assert.equal(h.run('sirenes().length'), 0);
  assert.equal(h.run('l.sirene'), undefined);
  assert.equal(h.run('saveOk()'), true);
});

test('Pénalité après la sirène, mené de 2 : poteaux pour la gagne, puis fin du match', () => {
  const h = live();
  h.run(`l.minute=42;endFlowPeriod(l);continueMatch();pauseMatch();l.minute=l.flow.fullEnd;
    l.score=[20,22];l.penaltyPolicies=['auto','auto'];l.tactics[0]='conquete';ballPossession(l,0,70);
    Math.random=()=>0;executePenaltyChoice(l,0)`);
  assert.match(h.run('l.events.find(e=>/^Pénalité après la sirène/.test(e.text)).text'), /tente les poteaux pour la gagne/);
  assert.equal(h.run('l.score.join("-")'), '23-22');
  assert.equal(h.run('l.finished'), true);
  assert.equal(h.run('l.restartLog.some(r=>r.cause==="score"&&r.minute>=l.flow.fullEnd)'), false);
});

test('Pénalité après la sirène, mené de 15 : pénaltouche jouée, la période s’arrête au ballon mort suivant', () => {
  const h = live();
  h.run(`l.minute=42;endFlowPeriod(l);continueMatch();pauseMatch();l.minute=l.flow.fullEnd;delete l.quickTapVersion;
    l.score=[7,22];l.penaltyPolicies=['auto','auto'];ballPossession(l,0,75);
    Math.random=()=>.99;executePenaltyChoice(l,0)`);
  assert.match(h.run('l.events.find(e=>/^Pénalité après la sirène/.test(e.text)).text'), /joue la pénaltouche, dernière action : il faut un essai/);
  assert.equal(h.run('l.stats[0].goalAttempts'), 0);
  assert.equal(h.run('l.restartLog.at(-1).cause'), 'penalty-touch');
  assert.equal(h.run('l.finished'), false);
  assert.equal(h.run('saveOk()'), true);
  h.run('handFault(l,l.possession)');
  assert.equal(h.run('l.finished'), true);
});

test('Pénalité après la sirène, mené de 10 en phase régulière : poteaux pour le bonus défensif', () => {
  const h = live();
  h.run(`l.minute=42;endFlowPeriod(l);continueMatch();pauseMatch();l.minute=l.flow.fullEnd;delete l.quickTapVersion;
    l.score=[12,22];l.penaltyPolicies=['auto','auto'];ballPossession(l,0,75);Math.random=()=>0;executePenaltyChoice(l,0)`);
  assert.equal(h.run('nativeMatchBonus.regleDuMatch(l).defensif.ecart'), 7);
  assert.match(h.run('l.events.find(e=>/^Pénalité après la sirène/.test(e.text)).text'), /tente les poteaux pour aller chercher le bonus défensif/);
  assert.equal(h.run('l.score.join("-")'), '15-22');
  assert.equal(h.run('l.finished'), true);
});

test('Pénalité après la sirène : la consigne du manager prime, la mi-temps est annoncée', () => {
  let h = live();
  h.run(`l.minute=42;endFlowPeriod(l);continueMatch();pauseMatch();l.minute=l.flow.fullEnd;delete l.quickTapVersion;
    l.score=[7,22];l.penaltyPolicies=['points','auto'];ballPossession(l,0,75);Math.random=()=>.99;executePenaltyChoice(l,0)`);
  assert.match(h.run('l.events.find(e=>/^Pénalité après la sirène/.test(e.text)).text'), /tente les poteaux pour réduire l’écart/);
  h = live();
  h.run(`l.minute=40;delete l.quickTapVersion;l.penaltyPolicies=['touch','auto'];ballPossession(l,0,60);Math.random=()=>.99;executePenaltyChoice(l,0)`);
  assert.match(h.run('l.events.find(e=>/^Pénalité après la sirène/.test(e.text)).text'), /pénaltouche, dernière action avant la pause/);
  assert.equal(h.run('l.flow.atBreak'), false);
  // Sans marqueur : ni annonce ni choix imposé.
  h = live();
  h.run(`delete l.endPeriodVersion;l.minute=42;endFlowPeriod(l);continueMatch();pauseMatch();l.minute=l.flow.fullEnd;delete l.quickTapVersion;
    l.score=[12,22];l.penaltyPolicies=['auto','auto'];ballPossession(l,0,75);Math.random=()=>.99;executePenaltyChoice(l,0)`);
  assert.equal(h.run('l.events.some(e=>/^Pénalité après la sirène/.test(e.text))'), false);
});

test('Prolongations : horloge 80′–100′, annonces de début et de fin, sirène et fin sur ballon mort', () => {
  const h = knockout();
  h.run('l.score=[6,6];l.stats.forEach(x=>{x.goals=2;x.goalAttempts=2});end(83)');
  assert.equal(h.run('l.knockout.period'), 1);
  assert.equal(h.run('matchClock(l)'), '80′');
  assert.match(h.run('l.events.findLast(e=>e.type==="break").text'), /^Prolongation : égalité .* au terme du temps réglementaire/);
  h.run('l.minute=88');
  assert.equal(h.run('matchClock(l)'), '85′');
  // Ballon vivant à la fin de la première prolongation : sirène, la période continue.
  h.run('l.minute=93;ballPossession(l,0,50);advanceFlowPlay(l)');
  assert.equal(h.run('l.knockout.period'), 1);
  assert.equal(h.run('l.sirene'), 93);
  assert.match(h.run('l.events.find(e=>/sirène|temps est écoulé/i.test(e.text)&&e.min===93).text'), /première prolongation/);
  assert.equal(h.run('matchClock(l)'), '90′');
  // En-avant après la sirène : l'adversaire peut jouer l'avantage (loi 8) ; l'avantage rendu, la mêlée est due et la
  // période se termine sur l'arrêt de jeu qui suit.
  h.run('l.minute=94;if(l.knockout.period===1){handFault(l,l.possession);if(l.flow.advantage)returnAdvantage(l)}');
  assert.equal(h.run('l.knockout.period'), 2);
  assert.equal(h.run('l.knockout.firstEnd'), 94);
  assert.match(h.run('l.events.findLast(e=>e.type==="break").text'), /^Changement de camp : fin de la première prolongation/);
  assert.equal(h.run('matchClock(l)'), '90′');
  assert.equal(h.run('eventClock(l,l.events.at(-1))'), '90′');
  h.run('l.minute=106');
  assert.equal(h.run('matchClock(l)'), '100+2′');
  h.run('liveCheck()');
});

test('Tirs au but : commentaire tir par tir, même vainqueur et même nombre de tirages', () => {
  const h = knockout('prem', 'semi');
  const r = h.run(`{
    l.score=[6,6];l.stats.forEach(x=>{x.goals=2;x.goalAttempts=2});end(83);end(94);
    let calls=0;const rng=Math.random;let x=0;
    Math.random=()=>{calls++;x=(x*9301+49297)%233280;return x/233280};
    try{end(105)}finally{Math.random=rng}
    liveCheck();
    const q=l.decision.shootout,i=l.events.findIndex(e=>/^Séance de tirs au but/.test(e.text));
    JSON.parse(JSON.stringify({calls,attempts:q.attempts,score:q.score,winner:l.winner,pair:l.pair,method:l.decision.method,
      events:l.events.slice(i).map(e=>e.text),fin:l.events.some(e=>/^Fin de la prolongation/.test(e.text))}))
  }`);
  assert.equal(r.method, 'shootout');
  assert.equal(r.calls, 2 + r.attempts.length, 'tirages : deux pour l’ordre, un par tir');
  assert.equal(r.fin, true);
  const lines = r.events.filter(t => /^(Mort subite, t|T)ir \d+ — /.test(t));
  assert.equal(lines.length, r.attempts.length);
  const tally = [0, 0];
  r.attempts.forEach((a, i) => {
    if (a.made) tally[a.side]++;
    assert.match(lines[i], new RegExp(`: ${a.made ? 'réussi' : 'manqué'}, ${tally[0]} – ${tally[1]}\\.$`));
  });
  assert.deepEqual(tally, r.score);
  const winnerSide = r.pair.indexOf(r.winner);
  assert.ok(r.score[winnerSide] > r.score[1 - winnerSide]);
  assert.match(r.events.at(-2) || '', new RegExp(`se qualifie aux tirs au but \\(${r.score[0]} – ${r.score[1]}\\)\\.$`));
  assert.equal(r.events.at(-1), 'Coup de sifflet final.');
});

test('Critère de départage en français (Élite : essais marqués)', () => {
  const h = knockout('elite', 'semi');
  const text = h.run(`l.score=[15,15];l.tries=[2,1];end(83);end(94);end(105);l.events.findLast(e=>/se qualifie/.test(e.text)).text`);
  assert.match(text, /se qualifie au nombre d’essais marqués\.$/);
  assert.doesNotMatch(text, /\(tries\)|tries|penalties|redCards/);
  assert.equal(h.run('l.decision.method'), 'tries');
});
