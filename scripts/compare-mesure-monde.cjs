#!/usr/bin/env node
'use strict';
// Tableau avant/après de deux mesures Monde multi-graines (dossiers de g<graine>.json, partie « analyse » de
// scripts/mesure-essais-monde.cjs, rapatriés par ci/mesure-monde.sh) : moyennes par championnat du premier (victoires,
// points), du dernier (victoires) et des corrélations de Spearman (rang / effectif, rang / rang réel), puis part de
// victoires du favori par tranche d'écart de niveau. Usage : node scripts/compare-mesure-monde.cjs <avant> <apres>
const fs = require('node:fs'), path = require('node:path');
function charge(dir) {
  const R = {}, T = {}; let n = 0;
  for (const f of fs.readdirSync(dir).filter(f => /^g\d+\.json$/.test(f))) {
    const j = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')), a = j.analyse || j; n++;
    const tab = Object.fromEntries(a.detail.tableaux.map(t => [t.comp, t]));
    for (const h of a.hierarchie) {
      if (!tab[h.comp]) continue;
      const r = R[h.comp] ||= { v1: [], p1: [], vd: [], sp: [], sr: [] };
      r.v1.push(+h.victoiresTete.split('/')[0]); r.vd.push(+h.victoiresDernier.split('/')[0]);
      r.p1.push(tab[h.comp].premier); r.sp.push(tab[h.comp].spearmanEffectif); r.sr.push(tab[h.comp].spearmanReel);
    }
    for (const t of a.detail.tranches) (T[t.tranche] ||= []).push(t.favori);
  }
  return { R, T, n };
}
const moy = x => x && x.length ? Math.round(x.reduce((a, b) => a + b, 0) / x.length * 100) / 100 : '-';
const [A, B] = process.argv.slice(2, 4).map(charge);
console.log(`Graines : ${A.n} → ${B.n}\n`);
console.log('| Championnat | 1er : victoires | 1er : points | Dernier : victoires | Spearman rang / effectif | Spearman rang / rang réel |\n|---|---|---|---|---|---|');
for (const c of Object.keys(A.R)) if (B.R[c]) console.log(`| ${c} | ${['v1', 'p1', 'vd', 'sp', 'sr'].map(k => `${moy(A.R[c][k])} → ${moy(B.R[c][k])}`).join(' | ')} |`);
console.log('\n| Écart de niveau | Favori gagnant (%) |\n|---|---|');
for (const t of Object.keys(A.T)) console.log(`| ${t} | ${moy(A.T[t])} → ${moy(B.T[t])} |`);
