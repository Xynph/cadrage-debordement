'use strict';
// Géométrie de la scène de touche (matchScene, loi 18 World Rugby, profil 2025/26).
// Règles vérifiées (18.9, 18.10, 18.15, 18.16, 18.22, 18.35) :
//  - alignement jamais à moins de 5 m d'une ligne de but (marque ramenée dans la scène seulement) ;
//  - deux rangées à 0,5 m de part et d'autre de la ligne de remise en jeu (couloir d'un mètre),
//    entre les lignes des 5 et des 15 m ;
//  - lanceur sur la marque, sur la ligne de touche ;
//  - vis-à-vis du lanceur à 2 m de la marque (côté de son équipe) et à 2 m de la ligne des 5 m ;
//  - un receveur (demi de mêlée) par équipe à 2 m de sa rangée, entre 5 et 15 m ;
//  - non-participants à 10 m au moins de la ligne de remise en jeu, ou sur leur ligne de but si elle est plus proche.
// Abstractions de la scène, non figées ici : position du ballon (y = 4, marque du moteur),
// ordre des joueurs dans la rangée, espacement régulier, choix du talonneur comme lanceur.
// Repère : x de 0 (ligne de but de l'équipe 0) à 100, y de 0 (ligne de touche de la touche) à 70.
const assert = require('node:assert/strict');
const { context } = require('./harness.cjs');
const { normalize } = require('../dist/match3d/scene-adapter.js');

const EPS = 1e-9;
const near = (a, b) => Math.abs(a - b) < EPS;
function reseed(run, seed) {
  run(`(function(){let s=${seed}*7919+13;Math.random=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296};})()`);
}

const seen = new Map();
let checked = 0, nearGoal = 0, onGoalLine = 0;

function verify(raw, expectedMark) {
  const { team, ball, period } = raw;
  const label = `lancer équipe ${team}, mi-temps ${period}, touche en x=${ball.x}`;
  assert.equal(raw.kind, 'lineout', label);
  assert.ok([0, 1].includes(team), label);
  const mark = ball.x;
  if (expectedMark !== undefined) assert.equal(mark, expectedMark, `${label} : marque de la scène`);
  assert.ok(mark >= 5 && mark <= 95, `${label} : jamais à moins de 5 m d'une ligne de but`);
  const P = raw.players;
  const rows = [0, 1].map(side => P.filter(p => p.side === side && p.slot < 8 && p.slot !== 1));
  for (const side of [0, 1]) {
    const back = side === 0 ? -1 : 1, goal = side === 0 ? 0 : 100;
    const forwards = P.filter(p => p.side === side && p.slot < 8).length;
    // Nombre conservé : tous les avants présents (hors lanceur ou vis-à-vis) forment la rangée.
    assert.equal(rows[side].length, forwards - (P.some(p => p.side === side && p.slot === 1) ? 1 : 0), `${label} : rangée complète`);
    for (const p of rows[side]) {
      assert.ok(near(p.x, mark + back * 0.5), `${label} : joueur ${p.id} à 0,5 m de la ligne de remise en jeu, côté de son équipe (x=${p.x})`);
      assert.ok(p.y >= 5 && p.y <= 15, `${label} : joueur ${p.id} entre les lignes des 5 et 15 m (y=${p.y})`);
    }
    const hooker = P.find(p => p.side === side && p.slot === 1);
    if (hooker && side === team) {
      assert.ok(near(hooker.x, mark) && hooker.y === 0, `${label} : lanceur sur la marque, sur la ligne de touche (${hooker.x}, ${hooker.y})`);
    } else if (hooker) {
      assert.ok(near(hooker.x, mark + back * 2), `${label} : vis-à-vis à 2 m de la ligne de remise en jeu, côté de son équipe (x=${hooker.x})`);
      assert.equal(hooker.y, 3, `${label} : vis-à-vis entre la touche et la ligne des 5 m, à 2 m de celle-ci`);
    }
    const receiver = P.find(p => p.side === side && p.slot === 8);
    if (receiver) {
      assert.ok(near(receiver.x, mark + back * 2.5), `${label} : receveur à 2 m de sa rangée (x=${receiver.x})`);
      assert.ok(receiver.y >= 5 && receiver.y <= 15, `${label} : receveur entre 5 et 15 m`);
    }
    for (const p of P.filter(p => p.side === side && p.slot >= 9)) {
      const distance = (p.x - mark) * back;
      assert.ok(distance > 0, `${label} : non-participant ${p.id} du côté de son équipe`);
      assert.ok(p.x >= 0 && p.x <= 100, `${label} : non-participant ${p.id} dans les limites`);
      const onGoal = p.x === goal;
      if (onGoal) onGoalLine++;
      assert.ok(distance >= 10 || onGoal, `${label} : non-participant ${p.id} à ${distance.toFixed(2)} m sans être sur sa ligne de but`);
      if (onGoal) assert.ok(Math.abs(mark - goal) <= 13 + (p.slot - 8) * 2.8, `${label} : ${p.id} ne recule sur sa ligne de but que si elle est plus proche que sa place habituelle`);
    }
  }
  if (rows[0].length && rows[1].length) {
    const max0 = Math.max(...rows[0].map(p => p.x)), min1 = Math.min(...rows[1].map(p => p.x));
    assert.ok(near(min1 - max0, 1), `${label} : couloir d'un mètre (${min1 - max0})`);
    assert.ok(near((min1 + max0) / 2, mark), `${label} : couloir centré sur la ligne de remise en jeu`);
  }
  if (Math.min(mark, 100 - mark) < 10) nearGoal++;
  // La projection 3D conserve ces positions, y compris sur la ligne de touche et sur la ligne de but.
  const scene = normalize(raw);
  for (const p of P) {
    const q = scene.players.find(x => x.id === String(p.id) && x.side === p.side);
    assert.ok(q && q.x === p.x && q.y === p.y, `${label} : l'adaptateur 3D conserve le joueur ${p.id}`);
  }
  seen.set(`${team}/${period}`, (seen.get(`${team}/${period}`) || 0) + 1);
  checked++;
}

// Scènes réelles du moteur.
for (const seed of [1, 2, 3, 4, 5, 6]) {
  for (const club of [0, 3, 7]) {
    const { run } = context();
    reseed(run, seed);
    run(`start(${club}); S.tactic="${seed % 2 ? 'conquete' : 'large'}"; beginMatch(); continueMatch();`);
    const keys = new Set();
    for (let i = 0; i < 4000 && !run('S.live.finished'); i++) {
      run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
      const before = run('JSON.stringify(S.live,(k,v)=>k==="visualSource"?undefined:v)');
      const draw = run('(function(){const r=Math.random;let n=0;Math.random=function(){n++;return r.apply(this,arguments)};const s=JSON.stringify(matchScene(S.live));Math.random=r;return JSON.stringify([n,s])})()');
      const [draws, text] = JSON.parse(draw);
      // La scène est une simple projection : ni état modifié, ni tirage aléatoire consommé.
      assert.equal(draws, 0, 'matchScene ne consomme aucun tirage');
      assert.equal(run('JSON.stringify(S.live,(k,v)=>k==="visualSource"?undefined:v)'), before);
      const raw = JSON.parse(text);
      if (raw.kind !== 'lineout') continue;
      const key = JSON.stringify([raw.event && raw.event.min, raw.event && raw.event.text, raw.team, raw.ball.x, raw.period]);
      if (keys.has(key)) continue;
      keys.add(key);
      verify(raw);
    }
  }
}
for (const team of [0, 1]) for (const period of [1, 2]) {
  assert.ok((seen.get(`${team}/${period}`) || 0) >= 5, `Trop peu de touches réelles lancées par l'équipe ${team} en mi-temps ${period}`);
}
assert.ok(nearGoal >= 1, 'Au moins une touche réelle à moins de 10 m d’une ligne de but');
const real = { scenes: checked, presEnBut: nearGoal };

// Scènes construites : les deux équipes, les deux mi-temps, près des deux en-buts et au centre.
// 2 et 98 : marques hors des 5 m (anciennes données) ramenées à 5 et 95 dans la scène seulement.
for (const team of [0, 1]) {
  for (const period of [1, 2]) {
    for (const [x, expected] of [[2, 5], [5, 5], [8, 8], [12, 12], [50, 50], [88, 88], [92, 92], [95, 95], [98, 95]]) {
      const { run } = context();
      reseed(run, 9);
      run('start(0); beginMatch(); continueMatch();');
      run(`(function(){const l=S.live;l.possession=${team};l.territory=${x};if(l.flow)l.flow.period=${period};l.minute=${period === 2 ? 55 : 15};addEvent(l,"Touche","setup",{kind:"lineout",team:${team},from:{x:${x},y:4},to:{x:${x},y:4}});syncMatchPresentation(l)})()`);
      const territory = run('S.live.territory');
      const raw = JSON.parse(run('JSON.stringify(matchScene(S.live))'));
      assert.equal(raw.team, team);
      assert.equal(raw.period, period);
      verify(raw, expected);
      // La marque ramenée à 5 m ne touche pas l'action sportive enregistrée.
      assert.equal(run('S.live.territory'), territory);
      assert.equal(run('S.live.events.at(-1).scene.to.x'), x);
    }
  }
}

assert.ok(onGoalLine > 0, 'Des non-participants se replient sur leur ligne de but près de l’en-but');
console.log(JSON.stringify({ passed: true, scenesReelles: real, scenesVerifiees: checked, parEquipeEtMiTemps: Object.fromEntries(seen), nonParticipantsSurLigneDeBut: onGoalLine }));
