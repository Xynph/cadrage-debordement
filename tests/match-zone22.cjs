'use strict';
// Entrées dans les 22 mètres adverses (direct.zone22) : comptées sur les faits montrés seulement.
// Cas construits à la main (journal minimal passé par la normalisation du moteur), puis un
// match réel d'une carrière Monde joué par le worker.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const { advanceToNextMatch } = require('./helpers/monde-matchs.cjs');
const H = require('../native/engine/match-highlights.cjs');
const Z = require('../native/engine/match-zone22.cjs');

// Fait du journal : l'équipe 0 attaque vers x = 100 (ses 22 adverses : x >= 78),
// l'équipe 1 vers x = 0 (ses 22 adverses : x <= 22).
let score = [0, 0];
const fait = (min, kind, possession, depuis, x, points) => {
  if (points) score = [score[0] + (points[0] || 0), score[1] + (points[1] || 0)];
  return { min, type: 'play', text: kind, scene: { kind, team: possession, possession, from: { x: depuis, y: 35 }, to: { x, y: 35 }, score: [...score], tries: [0, 0] } };
};
const calcul = events => Z.zone22(H.normaliser(events));
const debut = () => { score = [0, 0]; return [fait(0, 'kickoff', 1, 50, 50)]; };

test('Une entrée sans points : une course de l’équipe 0 franchit la ligne des 22 adverses', () => {
  const ev = debut();
  ev.push(fait(1, 'reception', 0, 50, 30), fait(1, 'carry', 0, 30, 60), fait(2, 'carry', 0, 60, 82), fait(2, 'carry', 0, 82, 88), fait(3, 'turnover', 1, 88, 88));
  const z = calcul(ev);
  assert.deepEqual(z.entrees, [1, 0]);
  assert.deepEqual(z.points, [0, 0]);
  assert.ok(z.secondes[0] > 0 && z.secondes[1] === 0, JSON.stringify(z));
});

test('Une entrée conclue par un essai transformé rapporte 7 points', () => {
  const ev = debut();
  ev.push(fait(1, 'reception', 0, 50, 40), fait(1, 'carry', 0, 40, 75), fait(2, 'carry', 0, 75, 90), fait(2, 'try', 0, 90, 100, [7, 0]), fait(3, 'kickoff', 1, 50, 50));
  const z = calcul(ev);
  assert.deepEqual(z.entrees, [1, 0]);
  assert.deepEqual(z.points, [7, 0]);
});

test('Deux entrées de suite séparées par une perte de balle : deux entrées pour l’équipe 0', () => {
  const ev = debut();
  ev.push(fait(1, 'reception', 0, 50, 50), fait(1, 'carry', 0, 50, 80), fait(2, 'turnover', 1, 80, 80),
    fait(2, 'carry', 1, 80, 60), fait(3, 'kick', 1, 60, 40), fait(3, 'reception', 0, 40, 40), fait(4, 'carry', 0, 40, 79), fait(4, 'carry', 0, 79, 85));
  const z = calcul(ev);
  assert.deepEqual(z.entrees, [2, 0], JSON.stringify(z));
  assert.deepEqual(z.points, [0, 0]);
});

test('Sortir des 22 puis y revenir dans la même possession : une seule entrée', () => {
  const ev = debut();
  ev.push(fait(1, 'reception', 1, 50, 50), fait(1, 'carry', 1, 50, 18), fait(2, 'carry', 1, 18, 30), fait(2, 'carry', 1, 30, 15), fait(3, 'carry', 1, 15, 10));
  const z = calcul(ev);
  assert.deepEqual(z.entrees, [0, 1], JSON.stringify(z));
});

test('Une séquence commencée dans les 22 (ballon récupéré) n’est pas une entrée', () => {
  const ev = debut();
  ev.push(fait(1, 'reception', 0, 50, 70), fait(1, 'carry', 0, 70, 70), fait(2, 'turnover', 1, 15, 15), fait(2, 'carry', 1, 15, 10));
  const z = calcul(ev);
  assert.deepEqual(z.entrees, [0, 0], JSON.stringify(z));
});

test('Rien au-delà de la borne : une entrée après les faits montrés n’est pas comptée', () => {
  const ev = debut();
  ev.push(fait(1, 'reception', 0, 50, 50), fait(1, 'carry', 0, 50, 60), fait(2, 'carry', 0, 60, 85), fait(2, 'try', 0, 85, 100, [5, 0]));
  const lignes = H.normaliser(ev);
  assert.deepEqual(Z.zone22(lignes).entrees, [1, 0]);
  const borne = 3; // les faits 0..2 seulement
  const z = Z.zone22(lignes.slice(0, borne));
  assert.deepEqual(z, { entrees: [0, 0], points: [0, 0], secondes: [0, 0] });
});

test('Match réel (carrière Monde) : direct.zone22 est lu dans le journal montré et reste cohérent', t => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-zone22-'));
  const bridge = createBridge({ dataDir, seed: 1002, now: 1700000000000, matchHighlights: 'dynamique' });
  let id = 0;
  const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, r.error); return r.model; };
  try {
    advanceToNextMatch(settleClubMeetings(call('new_career', { mode: 'world-champ', club: 0 }), call), call);
    let model = skipMatchTalk(call('begin_match'), call);
    let vus = 0, maxEntrees = 0;
    for (let k = 0; k < 200 && !model.live.finished; k++) {
      if (model.live.atBreak || model.live.paused) {
        // Mi-temps ou arrêt : causerie passée, puis reprise.
        model = skipMatchTalk(model, call);
        if (model.live.atBreak || model.live.paused) model = call('pause', { paused: false });
        continue;
      }
      model = call('tick', { minute: true, temps_forts: 'dynamique' });
      const live = model.live, direct = live.direct;
      if (!direct) continue;
      const z = direct.zone22;
      assert.equal(direct.version, 1, 'champ en plus, version inchangée');
      assert.ok(z && [z.entrees, z.points, z.secondes].every(a => Array.isArray(a) && a.length === 2 && a.every(n => Number.isInteger(n) && n >= 0)), JSON.stringify(z));
      for (const s of [0, 1]) assert.ok(z.points[s] <= direct.score[s], `points ${z.points[s]} <= score ${direct.score[s]}`);
      // Même calcul sur les seules lignes montrées : rien au-delà de la borne.
      assert.deepEqual(z, Z.zone22(H.normaliser(live.events).slice(0, direct.borne)));
      // Temps passé dans les 22 : jamais plus que le temps de match montré.
      assert.ok(z.secondes[0] + z.secondes[1] <= (direct.echantillon.minutes + 1) * 60, JSON.stringify(z));
      for (const s of [0, 1]) if (z.entrees[s] === 0) assert.equal(z.points[s], 0, 'pas de points sans entrée');
      maxEntrees = Math.max(maxEntrees, z.entrees[0] + z.entrees[1]);
      vus++;
    }
    t.diagnostic(`fin : ${model.live.finished ? 'match terminé' : 'match en cours'}, score ${model.live.direct?.score}, zone22 ${JSON.stringify(model.live.direct?.zone22)}, projections ${vus}`);
    assert.ok(vus > 10,`projections observées : ${vus}`);
    assert.ok(maxEntrees > 0, 'au moins une entrée dans un match réel');
  } finally {
    try { bridge.close?.(); } catch (error) { /* déjà fermé */ }
    fs.rmSync(dataDir, { recursive: true, force: true });
  }
});
