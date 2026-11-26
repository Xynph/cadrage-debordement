'use strict';
// Défense sur pénalité et tir au but (matchScene, loi 20 World Rugby, profil 2025/26) : match filmé du
// 25/11 (défenseurs à 7-9 m du point quand l'équipe 1 a la pénalité, à 4 m avec le plan « pression »).
//  - chaque défenseur est à 10 m au moins de la marque, vers sa ligne de but, ou sur sa ligne de but
//    quand elle est plus proche (la scène borne x à 1,5 m de la ligne) ;
//  - la défense est répartie sur la largeur (40 m au moins entre les deux défenseurs extrêmes).
// Repère : x de 0 (ligne de but de l'équipe 0) à 100, y de 0 à 70.
const assert = require('node:assert/strict');
const { context } = require('./harness.cjs');

function reseed(run, seed) {
  run(`(function(){let s=${seed}*7919+13;Math.random=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296};})()`);
}

const vus = { penalty: 0, goal: 0, miss: 0 };
const camps = new Set();
for (const seed of [1, 2, 3, 4]) {
  for (const club of [0, 7]) {
    const { run } = context();
    reseed(run, seed);
    run(`start(${club}); beginMatch(); continueMatch();`);
    const cles = new Set();
    for (let i = 0; i < 4000 && !run('S.live.finished'); i++) {
      run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
      const raw = JSON.parse(run('JSON.stringify(matchScene(S.live))'));
      if (!(raw.kind in vus)) continue;
      const cle = JSON.stringify([raw.event && raw.event.min, raw.event && raw.event.text]);
      if (cles.has(cle)) continue;
      cles.add(cle);
      const T = raw.possession, dir = T === 0 ? 1 : -1, ligne = T === 0 ? 100 : 0;
      const marque = raw.kind === 'penalty' ? raw.ball : raw.origin;
      const label = `${raw.kind} de l'équipe ${T} en (${marque.x}, ${marque.y}), ${raw.event && raw.event.text}`;
      const defense = raw.players.filter(p => p.side !== T);
      assert.ok(defense.length >= 13, `${label} : défense présente`);
      for (const p of defense) {
        const recul = (p.x - marque.x) * dir;
        const surSaLigne = Math.abs(p.x - ligne) <= 1.5 + 1e-9;
        assert.ok(recul >= 10 - 1e-9 || surSaLigne, `${label} : défenseur ${p.id} à ${recul.toFixed(1)} m de la marque (loi 20 : 10 m)`);
      }
      const ys = defense.map(p => p.y);
      assert.ok(Math.max(...ys) - Math.min(...ys) >= 40, `${label} : défense répartie sur la largeur (${Math.min(...ys)} à ${Math.max(...ys)})`);
      vus[raw.kind]++;
      camps.add(T);
    }
  }
}
assert.ok(vus.penalty >= 10, `Trop peu de pénalités réelles (${vus.penalty})`);
assert.ok(vus.goal + vus.miss >= 5, `Trop peu de tirs au but réels (${vus.goal + vus.miss})`);
assert.deepEqual([...camps].sort(), [0, 1], 'Pénalités des deux équipes');
console.log('match3d-penalite-defense ok', JSON.stringify(vus));
