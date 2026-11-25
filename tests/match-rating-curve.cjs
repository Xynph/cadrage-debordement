'use strict';
// Courbe de niveau du moteur (lot 0 « notes réalistes », 14/11/2026, docs/courbe-niveau-moteur-20261114.md).
// Deux copies d'un même club Monde, l'une décalée de k points, s'affrontent en alternant le domicile
// (tests/helpers/courbe-niveau.cjs). Le moteur complet et le résultat rapide doivent suivre la même
// courbe. Le banc joue en URC, dont la courbe est calée sur les vrais matchs (25/11/2026, docs/realite-matchs-20261125.md,
// tests/fixtures/realite-matchs-20261125.json) : domicile à niveau égal = URC réelle (70 %), poids de l'écart de niveau
// = celui qui redonne la hiérarchie réelle de l'URC sur des saisons Monde (pente ≈ 0,32 par point : +6 → 85 %,
// +10 → 95 %, −10 → 5 %), sans dérive des scores. Les autres championnats : tests/match-realite-championnats.cjs.
// Carrière world-champ (club 102, hors des clubs du banc), aucun ancien mode.
// Version CI : 3 écarts × 240 matchs au moteur complet, 4 écarts × 1 000 résultats rapides (~2 min).
// Version longue (manuelle, sous verrou) : CD_COURBE_LONGUE=1 node tests/match-rating-curve.cjs
// (9 écarts, 600 matchs complets et 4 000 rapides par écart, trois clubs de base : Top 14, PRO D2, URC).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const B = require('./helpers/courbe-niveau.cjs');

const LONGUE = process.env.CD_COURBE_LONGUE === '1';
const PLAN = LONGUE
  ? { complet: { ecarts: [-15, -10, -6, -3, 0, 3, 6, 10, 15], n: 600 }, rapide: { ecarts: [-15, -10, -6, -3, 0, 3, 6, 10, 15], n: 4000 }, bases: [4, 20, 44] }
  : { complet: { ecarts: [0, 6, 10], n: 240 }, rapide: { ecarts: [-10, 0, 6, 10], n: 3000 }, bases: [4] };
// Série de la queue (+15, hors ajustement logistique) : version CI seulement, la version longue la contient déjà.
PLAN.queue = { complet: 600, rapide: 2000 };
// Bornes : cible ± tolérance de conception ± trois erreurs types de l'ajustement (variance mesurée de l'échantillon, tests/helpers/courbe-niveau.cjs).
// La tolérance de conception ne bouge pas avec les réglages des taux du moteur : la courbe de niveau est la cible commune (MATCH_LEVEL_CURVE).
// URC réelle (2022-23 à 2025-26, 545 matchs) : 63,5 % de victoires à domicile, 70,2 % à niveau égal (ajustement sur le bilan de saison).
const REEL_URC = require('./fixtures/realite-matchs-20261125.json').championnats.urc;
const DOM = [REEL_URC.domicileNiveauEgal / 100 - 0.07, REEL_URC.domicileNiveauEgal / 100 + 0.07];
const BORNES = {
  // Pente visée 0,32 (ECART_CHAMPIONNAT.urc de dist/rugby.js : moteur complet ×2,6, résultat rapide ×1,52).
  complet: { pente: LONGUE ? [0.26, 0.38] : [0.24, 0.40], domicile: DOM,
    // Scores : enveloppe de la réalité récente (docs/essais-realistes-20261114.md : 5,2 à 8,6 essais et 45 à 62 points par match selon le
    // championnat), et non plus l'intervalle mesuré à chaque réglage du moteur (38-62 puis 4,4-8,8 puis…) ; l'écart moyen reste ample.
    points: [38, 66], essais: [4.4, 9.2], ecartNul: [5, 20],
    // Queue à +15 (domicile alterné, match piège) : le plus faible gagne encore parfois. Avec la pente de l'URC réelle,
    // 15 points d'écart est un très gros écart (plus que le 1er contre le dernier d'une saison).
    queue: [0.003, 0.08] },
  rapide: { pente: LONGUE ? [0.28, 0.36] : [0.26, 0.38], domicile: DOM,
    points: [43, 60], essais: [4.8, 7.5], ecartNul: [10, 20], queue: [0.003, 0.08] },
};
const dans = (x, [a, b], quoi, se = 0) => assert.ok(x + 3 * se >= a && x - 3 * se <= b, `${quoi} : ${x.toFixed(3)} (± ${(3 * se).toFixed(3)}) hors de [${a} ; ${b}]`);

test('Courbe de niveau commune au moteur complet et au résultat rapide (carrière Monde)', { timeout: LONGUE ? 7200000 : 900000 }, () => {
  const h = context(4242, { club: 102, console: false });
  try {
    assert.equal(h.run('CDWorldEditions.forState(S).mode'), 'world-champ');
    assert.equal(h.run('MATCH_LEVEL_CURVE.version'), 2);
    assert.equal(h.run('Object.isFrozen(MATCH_LEVEL_CURVE)&&Object.isFrozen(MATCH_LEVEL_CURVE.complet)'), true);
    // Niveau d'équipe : note × forme, 1,00 à 100 % de condition.
    assert.equal(h.run('teamLevel([{rating:80,condition:100},{rating:70,condition:100}])').toFixed(3), '75.000');
    assert.equal(h.run('teamLevel([{rating:80,condition:80}])').toFixed(3), (80 * (0.57 + 0.0043 * 80)).toFixed(3));
    // Match piège : rien jusqu'à 10 points d'écart ; au-delà, probabilité 0,04 par point (au plus 0,3), le favori joue
    // ce jour-là avec 40 % de l'écart en moins (décalage du point de vue du camp 0), x 2,8 au moteur complet.
    const piege = (gap, u) => h.run(`matchTrapOffset(${gap},()=>${u})`);
    assert.equal(piege(10, 0), 0); assert.equal(piege(-10, 0), 0);
    assert.equal(piege(16, 0.23).toFixed(2), '-6.40'); assert.equal(piege(-16, 0.23).toFixed(2), '6.40');
    assert.equal(piege(16, 0.25), 0); assert.equal(piege(30, 0.29).toFixed(2), '-12.00'); assert.equal(piege(30, 0.31), 0);
    assert.equal(h.run('MATCH_LEVEL_CURVE.complet.piege'), 2.8);
    const cp = h.checkpoint();
    const pentes = {}, queues = {};
    for (const base of PLAN.bases) for (const mode of ['complet', 'rapide']) {
      h.restore(cp);
      const t0 = Date.now(), { ecarts, n } = PLAN[mode], b = BORNES[mode];
      const m = B.mesurer(h, { mode, ecarts, n, base, slots: [7, 11] });
      console.log(B.tableau(`${mode}, club de base ${base} (${Date.now() - t0} ms)`, m.resumes, m.fit));
      dans(m.fit.pente, b.pente, `${mode} ${base} pente par point`, m.fit.se.pente);
      dans(m.fit.domicileNiveauEgal, b.domicile, `${mode} ${base} victoires à domicile à niveau égal`, m.fit.se.terrain / 4);
      const r = k => m.resumes.find(x => x.k === k);
      // Glorieuse incertitude : le plus fort de 10 points perd encore à l'extérieur (URC réelle : le favori d'un gros écart
      // de bilan gagne 72 % de ses déplacements).
      assert.ok(r(10).victoires >= 0.86 && r(10).victoires <= 0.99, `${mode} +10 : ${B.pct(r(10).victoires)}`);
      assert.ok(r(10).aExterieur < 0.98, `${mode} +10 : surprises à l'extérieur`);
      assert.ok(r(6).victoires >= 0.75 && r(6).victoires <= 0.92, `${mode} +6 : ${B.pct(r(6).victoires)}`);
      if (r(-10)) dans(r(-10).victoires, [0.02, 0.15], `${mode} −10`);
      // Équilibre des scores (à niveau égal) : points, essais et écart moyen autour des valeurs d'avant.
      dans(r(0).points, b.points, `${mode} points par match`);
      dans(r(0).essais, b.essais, `${mode} essais par match`);
      dans(r(0).ecart, b.ecartNul, `${mode} écart moyen à niveau égal`);
      for (const x of m.resumes) assert.ok(x.points < b.points[1] + 12, `${mode} ${x.k} : ${x.points.toFixed(1)} points par match`);
      pentes[base + mode] = m.fit;
      // Queue de la courbe (match piège, MATCH_LEVEL_CURVE.piege, 15/11/2026) : à 15 points d'écart, le plus faible gagne encore parfois.
      if (!LONGUE || !r(15)) {
        h.restore(cp);
        const q = B.mesurer(h, { mode, ecarts: [15], n: PLAN.queue[mode], base, slots: [7, 11] });
        console.log(B.tableau(`${mode}, club de base ${base}, queue`, q.resumes));
        queues[base + mode] = q.resumes[0];
      } else queues[base + mode] = r(15);
      const t = queues[base + mode];
      dans(1 - t.victoires, b.queue, `${mode} ${base} surprises à 15 points`);
    }
    // Les deux moteurs suivent la même courbe (à l'échantillonnage près).
    for (const base of PLAN.bases) {
      const c = pentes[base + 'complet'], r = pentes[base + 'rapide'];
      assert.ok(Math.abs(c.pente - r.pente) <= 0.05, `pentes complet ${c.pente.toFixed(3)} / rapide ${r.pente.toFixed(3)}`);
      assert.ok(Math.abs(c.domicileNiveauEgal - r.domicileNiveauEgal) <= 0.08, 'avantage du terrain des deux moteurs');
      const qc = queues[base + 'complet'], qr = queues[base + 'rapide'];
      assert.ok(Math.abs(qc.victoires - qr.victoires) <= 0.05, `queue à 15 points : complet ${B.pct(1 - qc.victoires)} / rapide ${B.pct(1 - qr.victoires)}`);
    }
  } finally { h.close(); }
});
