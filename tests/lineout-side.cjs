'use strict';
// Côté des deux alignements dans la scène de touche (matchScene, loi 18).
// Règle appliquée : chaque équipe se place du côté de son PROPRE en-but par rapport
// à la ligne de touche, quelle que soit l'équipe qui lance et quelle que soit la mi-temps.
// L'équipe 0 attaque vers x croissant (son en-but est en x=0), l'équipe 1 vers x décroissant.
// Les scènes sont celles du vrai moteur (aucun fait écrit à la main) ; le test ne fige
// volontairement ni l'écart entre les alignements, ni leur profondeur, ni la position du
// ballon, qui restent des abstractions de la scène.
const assert = require('node:assert/strict');
const { context } = require('./harness.cjs');
const { normalize } = require('../dist/match3d/scene-adapter.js');

function reseed(run, seed) {
  run(`(function(){let s=${seed}*7919+13;Math.random=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296};})()`);
}

const seen = new Map(); // « équipe qui lance / mi-temps » -> nombre de scènes vérifiées
let checked = 0;

function verify(raw) {
  const { team, ball, period } = raw;
  const dir = team === 0 ? 1 : -1;
  const label = `lancer équipe ${team}, mi-temps ${period}, touche en x=${ball.x}`;
  assert.ok([0, 1].includes(team), label);
  assert.equal(raw.possession, team, `${label} : la possession est celle de l’équipe qui lance`);
  const lines = [0, 1].map(side => raw.players.filter(p => p.side === side && p.slot < 8));
  const backs = [0, 1].map(side => raw.players.filter(p => p.side === side && p.slot >= 8));
  for (const side of [0, 1]) {
    // Sens d’attaque de cette équipe : +1 pour l’équipe 0, -1 pour l’équipe 1.
    const attack = side === 0 ? 1 : -1;
    assert.ok(lines[side].length > 0, `${label} : alignement de l’équipe ${side} présent`);
    for (const p of lines[side]) {
      // Du côté de son propre en-but = derrière la ligne de touche dans son sens d’attaque.
      assert.ok((p.x - ball.x) * attack < 0, `${label} : le joueur ${p.id} de l’équipe ${side} est du côté de son propre en-but`);
    }
    // Les non-participants restent du même côté que leur alignement.
    for (const p of backs[side]) {
      assert.ok((p.x - ball.x) * attack < 0, `${label} : le joueur ${p.id} (non-participant) de l’équipe ${side} est du côté de son propre en-but`);
    }
  }
  // Les deux alignements sont de part et d’autre de la ligne de touche, sans se chevaucher.
  const max0 = Math.max(...lines[0].map(p => p.x)), min1 = Math.min(...lines[1].map(p => p.x));
  assert.ok(max0 < ball.x && min1 > ball.x, `${label} : alignements de part et d’autre de la ligne de touche`);
  // Lien explicite avec le sens d’attaque de l’équipe qui lance.
  assert.ok((lines[team][0].x - ball.x) * dir < 0, `${label} : l’équipe qui lance est derrière la ligne de touche dans son sens d’attaque`);
  // La projection 3D (adaptateur) conserve ces positions.
  const scene = normalize(raw);
  assert.equal(scene.kind, 'lineout');
  for (const p of raw.players) {
    const q = scene.players.find(x => x.id === String(p.id) && x.side === p.side);
    assert.ok(q && q.x === p.x && q.y === p.y, `${label} : l’adaptateur 3D conserve le joueur ${p.id}`);
  }
  seen.set(`${team}/${period}`, (seen.get(`${team}/${period}`) || 0) + 1);
  checked++;
}

for (const seed of [1, 2, 3, 4]) {
  for (const club of [0, 3, 7]) {
    const { run } = context();
    reseed(run, seed);
    run(`start(${club}); S.tactic="${seed % 2 ? 'conquete' : 'large'}"; beginMatch(); continueMatch();`);
    const keys = new Set();
    for (let i = 0; i < 4000 && !run('S.live.finished'); i++) {
      run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
      const before = run('JSON.stringify(S.live,(k,v)=>k==="visualSource"?undefined:v)');
      const raw = JSON.parse(run('JSON.stringify(matchScene(S.live))'));
      // La scène est une simple projection : elle ne modifie pas l’état du match.
      assert.equal(run('JSON.stringify(S.live,(k,v)=>k==="visualSource"?undefined:v)'), before);
      if (raw.kind !== 'lineout') continue;
      const key = JSON.stringify([raw.event && raw.event.min, raw.team, raw.ball.x, raw.period]);
      if (keys.has(key)) continue;
      keys.add(key);
      verify(raw);
    }
  }
}

// Les deux sens d’attaque et les deux mi-temps doivent avoir été réellement rencontrés.
for (const team of [0, 1]) {
  for (const period of [1, 2]) {
    assert.ok((seen.get(`${team}/${period}`) || 0) >= 5,
      `Trop peu de touches lancées par l’équipe ${team} en mi-temps ${period} : ${seen.get(`${team}/${period}`) || 0}`);
  }
}

// Scène construite à la main pour les deux équipes, aux deux extrémités du terrain.
for (const team of [0, 1]) {
  for (const x of [25, 75]) {
    const { run } = context();
    reseed(run, 9);
    run('start(0); beginMatch(); continueMatch();');
    run(`(function(){const l=S.live;l.possession=${team};l.territory=${x};addEvent(l,"Touche","setup",{kind:"lineout",team:${team},from:{x:${x},y:4},to:{x:${x},y:4}});syncMatchPresentation(l)})()`);
    const raw = JSON.parse(run('JSON.stringify(matchScene(S.live))'));
    assert.equal(raw.kind, 'lineout');
    assert.equal(raw.team, team);
    verify(raw);
  }
}

console.log(JSON.stringify({ passed: true, scenesVerifiees: checked, parEquipeEtMiTemps: Object.fromEntries(seen) }));
