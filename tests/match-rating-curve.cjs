'use strict';
// Courbe de niveau du moteur (lot 0 « notes réalistes », 14/11/2026, docs/courbe-niveau-moteur-20261114.md).
// Deux copies d'un même club Monde, l'une décalée de k points, s'affrontent en alternant le domicile
// (tests/helpers/courbe-niveau.cjs). Le moteur complet et le résultat rapide doivent suivre la même
// courbe cible (MATCH_LEVEL_CURVE de dist/rugby.js) : logit P(victoire) = 0,183 × écart + 0,64 à domicile,
// soit +6 → 75 %, +10 → 86 %, −10 → 14 % sur terrain neutre et 65 % à domicile à niveau égal,
// sans dérive des scores (points, essais et écarts moyens bornés autour des valeurs d'avant la courbe).
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
  : { complet: { ecarts: [0, 6, 10], n: 240 }, rapide: { ecarts: [-10, 0, 6, 10], n: 1000 }, bases: [4] };
// Bornes : cible ± bruit d'échantillonnage (version CI : écart type ≈ 3 points au moteur complet).
const BORNES = {
  // Moteur complet : courbe un peu plus raide dans les queues (±15 → 96 %), d'où une pente ajustée de 0,20 à 0,22.
  complet: { pente: LONGUE ? [0.16, 0.23] : [0.15, 0.24], domicile: LONGUE ? [0.61, 0.71] : [0.58, 0.73],
    // Essais réalistes (docs/essais-realistes-20261114.md) : ~6 à 8 essais et ~48 à 60 points par match selon le championnat (avant : 2,6-4,4 essais, 24-37 points).
    points: [38, 62], essais: [4.4, 8.8], ecartNul: [5, 17] },
  rapide: { pente: LONGUE ? [0.17, 0.20] : [0.16, 0.21], domicile: LONGUE ? [0.62, 0.69] : [0.61, 0.70],
    points: [43, 57], essais: [4.8, 6.6], ecartNul: [10, 18] },
};
const dans = (x, [a, b], quoi) => assert.ok(x >= a && x <= b, `${quoi} : ${x.toFixed(3)} hors de [${a} ; ${b}]`);

test('Courbe de niveau commune au moteur complet et au résultat rapide (carrière Monde)', { timeout: LONGUE ? 7200000 : 900000 }, () => {
  const h = context(4242, { club: 102, console: false });
  try {
    assert.equal(h.run('CDWorldEditions.forState(S).mode'), 'world-champ');
    assert.equal(h.run('MATCH_LEVEL_CURVE.version'), 1);
    assert.equal(h.run('Object.isFrozen(MATCH_LEVEL_CURVE)&&Object.isFrozen(MATCH_LEVEL_CURVE.complet)'), true);
    // Niveau d'équipe : note × forme, 1,00 à 100 % de condition.
    assert.equal(h.run('teamLevel([{rating:80,condition:100},{rating:70,condition:100}])').toFixed(3), '75.000');
    assert.equal(h.run('teamLevel([{rating:80,condition:80}])').toFixed(3), (80 * (0.57 + 0.0043 * 80)).toFixed(3));
    const cp = h.checkpoint();
    const pentes = {};
    for (const base of PLAN.bases) for (const mode of ['complet', 'rapide']) {
      h.restore(cp);
      const t0 = Date.now(), { ecarts, n } = PLAN[mode], b = BORNES[mode];
      const m = B.mesurer(h, { mode, ecarts, n, base, slots: [7, 11] });
      console.log(B.tableau(`${mode}, club de base ${base} (${Date.now() - t0} ms)`, m.resumes, m.fit));
      dans(m.fit.pente, b.pente, `${mode} ${base} pente par point`);
      dans(m.fit.domicileNiveauEgal, b.domicile, `${mode} ${base} victoires à domicile à niveau égal`);
      const r = k => m.resumes.find(x => x.k === k);
      // Glorieuse incertitude : le plus fort de 10 points perd encore, à domicile comme à l'extérieur.
      assert.ok(r(10).victoires >= 0.78 && r(10).victoires <= 0.93, `${mode} +10 : ${B.pct(r(10).victoires)}`);
      assert.ok(r(10).aDomicile < 1 && r(10).aExterieur < 0.95, `${mode} +10 : surprises à domicile et à l'extérieur`);
      assert.ok(r(6).victoires >= 0.67 && r(6).victoires <= 0.83, `${mode} +6 : ${B.pct(r(6).victoires)}`);
      if (r(-10)) dans(r(-10).victoires, [0.07, 0.21], `${mode} −10`);
      // Équilibre des scores (à niveau égal) : points, essais et écart moyen autour des valeurs d'avant.
      dans(r(0).points, b.points, `${mode} points par match`);
      dans(r(0).essais, b.essais, `${mode} essais par match`);
      dans(r(0).ecart, b.ecartNul, `${mode} écart moyen à niveau égal`);
      for (const x of m.resumes) assert.ok(x.points < b.points[1] + 12, `${mode} ${x.k} : ${x.points.toFixed(1)} points par match`);
      pentes[base + mode] = m.fit;
    }
    // Les deux moteurs suivent la même courbe (à l'échantillonnage près).
    for (const base of PLAN.bases) {
      const c = pentes[base + 'complet'], r = pentes[base + 'rapide'];
      assert.ok(Math.abs(c.pente - r.pente) <= 0.05, `pentes complet ${c.pente.toFixed(3)} / rapide ${r.pente.toFixed(3)}`);
      assert.ok(Math.abs(c.domicileNiveauEgal - r.domicileNiveauEgal) <= 0.08, 'avantage du terrain des deux moteurs');
    }
  } finally { h.close(); }
});
