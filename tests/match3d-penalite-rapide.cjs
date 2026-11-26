'use strict';
// Pénalité jouée vite à la main et défense près de sa ligne (matchScene, loi 20 World Rugby) : match filmé du 26/11
// (24′ : pénalité tapée à 10 m de la ligne, défense plantée en file sur sa ligne d'essai, porteur seul sur 30 m ;
// 74′ : essai près des poteaux, défense en file sur toute la largeur de sa ligne).
//  - à la tape, la défense est encore à ses 10 m (ou sur sa ligne) et le tapeur est au point de la faute ;
//  - au fait suivant de la même équipe, elle est montée sur le porteur : les cinq défenseurs les plus proches
//    se sont rapprochés du ballon (essai, gain court ; tape à 5 m au moins de la ligne) et les avants ont jailli vers le point de la tape ;
//  - près de sa ligne (essai, temps de jeu à moins de 15 m) : défense face au jeu, étagée en profondeur
//    (pas tous sur la même ligne), resserrée sur la largeur autour du ballon, personne hors-jeu derrière le
//    porteur, deux défenseurs jamais l'un sur l'autre.
// Repère : x de 0 (ligne de but de l'équipe 0) à 100, y de 0 à 70.
const assert = require('node:assert/strict');
const { context } = require('./harness.cjs');

function reseed(run, seed) {
  run(`(function(){let s=${seed}*7919+13;Math.random=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296};})()`);
}
const proches = (s, n = 5) => {
  const d = s.players.filter(p => p.side !== s.possession).map(p => Math.hypot(p.x - s.ball.x, p.y - s.ball.y)).sort((a, b) => a - b);
  return d.slice(0, n).reduce((a, v) => a + v, 0) / n;
};

let taps = 0, montees = 0, presLigne = 0;
for (const seed of [1, 2, 3, 4, 5, 6]) {
  const { run } = context();
  reseed(run, seed);
  run('start(0); beginMatch(); S.live.penaltyPolicies = ["main", "main"]; continueMatch();');
  for (let i = 0; i < 6000 && !run('S.live.finished'); i++) run('if (S.live.paused) continueMatch(); S.live.penaltyPolicies = ["main", "main"]; presentationTick(S.live);');
  const scenes = JSON.parse(run(`(function(){const l=S.live,p=playback(l),c=p.cursor,out=[];
    l.events.forEach((e,i)=>{if(!e.scene)return;p.cursor=i;const s=matchScene(l);out.push({i,kind:s.kind,possession:s.possession,team:s.team,ball:s.ball,players:s.players.map(q=>({id:q.id,side:q.side,slot:q.slot,x:q.x,y:q.y,featured:q.featured}))})});
    p.cursor=c;return JSON.stringify(out)})()`));
  scenes.forEach((s, k) => {
    const T = s.possession, dir = T === 0 ? 1 : -1, ligne = T === 0 ? 100 : 0, defense = s.players.filter(p => p.side !== T);
    const label = `graine ${seed}, ${s.kind} n° ${s.i} (équipe ${T}, ballon ${s.ball.x}, ${s.ball.y})`;
    if (s.kind === 'quick-tap') {
      taps++;
      for (const p of defense) {
        const recul = (p.x - s.ball.x) * dir;
        assert.ok(recul >= 10 - 1e-9 || Math.abs(p.x - ligne) <= 1.5 + 1e-9, `${label} : défenseur ${p.id} à ${recul.toFixed(1)} m à la tape (loi 20 : 10 m)`);
      }
      const tapeur = s.players.find(p => p.featured && p.side === T);
      assert.ok(tapeur && Math.hypot(tapeur.x - s.ball.x, tapeur.y - s.ball.y) < 0.6, `${label} : le tapeur est au point de la faute (dans le terrain)`);
      const n = scenes[k + 1];
      if (n && n.possession === T && n.team === T && ['carry', 'try', 'hand-fault'].includes(n.kind)) {
        const avant = proches(s), apres = proches(n), gain = (n.ball.x - s.ball.x) * dir;
        if ((n.kind === 'try' || gain < 5) && (ligne - s.ball.x) * dir >= 5) assert.ok(apres <= avant - Math.min(3, avant * 0.3), `${label} → ${n.kind} : la défense monte sur le porteur (5 plus proches à ${avant.toFixed(1)} m puis ${apres.toFixed(1)} m)`);
        // Les avants jaillissent vers le point de la tape (ils étaient à 10 m au moins) ; dépassés si le porteur a gagné plus.
        const avants = q => q.players.filter(p => p.side !== T && p.slot < 8).reduce((a, p, _, t) => a + (p.x - s.ball.x) * dir / t.length, 0);
        if ((ligne - s.ball.x) * dir >= 10 && (n.kind === 'try' || (ligne - n.ball.x) * dir >= 10)) assert.ok(avants(n) <= avants(s) - 3, `${label} → ${n.kind} : les avants montent vers la tape (à ${avants(s).toFixed(1)} m du point puis ${avants(n).toFixed(1)} m)`);
        montees++;
      }
    }
    const room = (ligne - s.ball.x) * dir;
    if (s.kind === 'try' || s.kind === 'carry' && room < 10) {
      presLigne++;
      const xs = defense.map(p => p.x), ys = defense.map(p => p.y);
      assert.ok(Math.max(...xs) - Math.min(...xs) >= 1.5, `${label} : défense étagée, pas en file sur sa ligne (x de ${Math.min(...xs)} à ${Math.max(...xs)})`);
      const largeur = Math.max(...ys) - Math.min(...ys);
      assert.ok(largeur >= 15 && largeur <= 40, `${label} : défense en largeur, resserrée autour du ballon (${largeur.toFixed(1)} m)`);
      if (s.kind === 'carry') for (const p of defense) assert.ok((p.x - s.ball.x) * dir >= 0, `${label} : défenseur ${p.id} hors-jeu derrière le porteur`);
      for (let a = 0; a < defense.length; a++) for (let b = a + 1; b < defense.length; b++) {
        assert.ok(Math.hypot(defense[a].x - defense[b].x, defense[a].y - defense[b].y) >= 1, `${label} : ${defense[a].id} et ${defense[b].id} l'un sur l'autre`);
      }
    }
  });
}
assert.ok(taps >= 20, `Trop peu de pénalités jouées à la main (${taps})`);
assert.ok(montees >= 8, `Trop peu de suites de pénalité jouée vite (${montees})`);
assert.ok(presLigne >= 15, `Trop peu de phases près de la ligne (${presLigne})`);
console.log('match3d-penalite-rapide ok', JSON.stringify({ taps, montees, presLigne }));
