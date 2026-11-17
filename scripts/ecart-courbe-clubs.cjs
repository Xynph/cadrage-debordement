#!/usr/bin/env node
'use strict';
// Écart à la courbe de niveau par club et par lieu, sur les JSON de scripts/mesure-essais-monde.cjs (--json).
// Usage : node scripts/ecart-courbe-clubs.cjs [--comp elite] [--pente .206] [--terrain .95] a.json b.json …
// Pente et terrain par défaut : banc de la courbe joué en Top 14 (tests/helpers/courbe-niveau.cjs, competitionId elite),
// mesuré le 17/11/2026 : 0,206 et 0,95. Voir docs/top14-dispute-20261117.md §7.
const args = process.argv.slice(2), opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args.splice(i, 2)[1] : d; };
const comp = opt('--comp', 'elite'), pente = Number(opt('--pente', .206)), terrain = Number(opt('--terrain', .95));
const L = x => 1 / (1 + Math.exp(-x)), clubs = {}, X = [];
for (const f of args) {
  const d = require(require('node:path').resolve(f)).brut;
  for (const m of d.matchs.filter(m => m.niv && m.phase === 'league' && m.comp === comp)) {
    const g = m.niv[0] - m.niv[1], y = m.score[0] > m.score[1] ? 1 : m.score[0] === m.score[1] ? .5 : 0;
    X.push([g, y, m.niv[2] - 2 * m.niv[3]]);
    for (const s of [0, 1]) {
      const c = clubs[d.noms[m.pair[s]]] ||= { dom: [0, 0, 0], ext: [0, 0, 0] }, r = c[s ? 'ext' : 'dom'];
      r[0]++; r[1] += s ? 1 - y : y; r[2] += L(pente * (s ? -g : g) + (s ? -terrain : terrain));
    }
  }
}
// Ajustement logistique de la saison (pente, terrain) et pente du terme hors niveau (unités tactiques, moral, nombre).
let a = .18, h = .6; for (let i = 0; i < 4000; i++) { let ga = 0, gh = 0; for (const [g, y] of X) { const p = L(a * g + h); ga += (y - p) * g; gh += y - p; } a += ga / X.length * .01; h += gh / X.length * .05; }
const n = X.length, sx = X.reduce((s, x) => s + x[0], 0), sy = X.reduce((s, x) => s + x[2], 0), sxx = X.reduce((s, x) => s + x[0] ** 2, 0), sxy = X.reduce((s, x) => s + x[0] * x[2], 0);
console.log(`${comp} : ${n} matchs ; saison pente ${a.toFixed(3)} terrain ${h.toFixed(2)} (banc ${pente} / ${terrain}) ; terme hors niveau ${((n * sxy - sx * sy) / (n * sxx - sx * sx)).toFixed(4)} par point (courbe 0,008)`);
console.log('| club | dom. V / courbe | ext. V / courbe | surplus |\n|---|---|---|---|');
for (const [k, c] of Object.entries(clubs).sort((p, q) => (q[1].dom[1] + q[1].ext[1]) - (p[1].dom[1] + p[1].ext[1])))
  console.log(`| ${k} | ${c.dom[1]} / ${c.dom[2].toFixed(1)} | ${c.ext[1]} / ${c.ext[2].toFixed(1)} | ${(c.dom[1] + c.ext[1] - c.dom[2] - c.ext[2]).toFixed(1)} |`);
