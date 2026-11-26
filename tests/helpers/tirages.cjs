'use strict';
// Outils de tests robustes au recalibrage du moteur de match (docs/tests-robustes-20261114.md).
// Trois façons légitimes de tester un moteur à tirages, aucune ne dépend d'un résultat exact à graine fixe :
//   (a) une règle du jeu : vraie quel que soit le tirage, on la vérifie sur beaucoup de tirages ;
//   (b) une statistique : on compare des taux sur un échantillon, avec un test de différence qui tient compte
//       de la variance (z), jamais sur une valeur lue à une graine ;
//   (c) un scénario précis : on force la décision (tirage BAS = « ça réussit », HAUT = « ça échoue » pour tout
//       taux du moteur compris entre 0,01 et 0,99) ou on balaie le tirage et on lit ce que le moteur en fait.
const assert = require('node:assert/strict');

// Dans le moteur, une décision est `Math.random() < p` avec p borné par clamp (jamais ≤ 0 ni ≥ 1) :
// BAS la fait toujours réussir, HAUT toujours échouer, quel que soit le taux recalé.
const BAS = 0;
const HAUT = 0.9999999;

// Tirages injectés dans la VM : les valeurs de `script` sont servies dans l'ordre, puis `apres` (HAUT par défaut).
// `consommes(run)` dit combien de tirages le moteur a demandés (pour vérifier qu'une séquence reste synchrone).
function injecter(run, script, { apres = HAUT } = {}) {
  run(`var __tirages={s:${JSON.stringify(script)},n:0};Math.random=()=>__tirages.n<__tirages.s.length?__tirages.s[__tirages.n++]:(__tirages.n++,${apres})`);
}
const consommes = run => run('__tirages.n');
// Tirage constant (une seule valeur pour toutes les décisions).
function constant(run, valeur) { run(`Math.random=()=>${valeur}`); }

// n tirages régulièrement répartis sur ]0 ; 1[ : (i + 0,5) / n.
const balayage = n => Array.from({ length: n }, (_, i) => (i + 0.5) / n);

// Une phase de jeu (advanceCausalPlay) dont la course réussit : tirage de faute au-dessus de tous les seuils, pas de coup de pied
// dégagé (le tirage correspondant n'est demandé que sous règles tactiques ou en plan occupation), course réussie, puis, dans les
// 22 adverses, finition (`finit: true` : essai franc, hors en-but) ou pas de finition (`finit: false`). Ce sont des décisions,
// pas des seuils : elles valent pour tout taux de course ou de finition du moteur.
function courseReussie(run, side, { finit = null, live = 'l' } = {}) {
  const coup = run(`(tacticalRules(${live})||effectiveAttack(${live},${side})==='occupation')`);
  // Drop à portée (lois manquantes, dist/restarts.js) : un tirage de plus, haut = pas de drop.
  const drop = run(`typeof dropPossible==='function'&&dropPossible(${live},${side})`);
  return [HAUT, ...(drop ? [HAUT] : []), ...(coup ? [HAUT] : []), BAS, ...(finit === null ? [] : finit ? [BAS, 0.5] : [HAUT])];
}

// Photographie de la rencontre en cours (S.live) pour rejouer plusieurs tirages à partir du même état.
function photographier(run) { return run('JSON.stringify(S.live)'); }
function rejouer(run, photo) { run(`S.live=JSON.parse(${JSON.stringify(photo)});l=S.live`); }

// --- Statistiques -----------------------------------------------------------------------------------
const somme = a => a.reduce((s, x) => s + x, 0);
const moyenne = a => somme(a) / a.length;
const variance = a => { const m = moyenne(a); return somme(a.map(x => (x - m) ** 2)) / Math.max(1, a.length - 1); };
const ecartType = a => Math.sqrt(variance(a));
// Écart (a − b) en écarts types de l'estimation (Welch) : > 4 = différence réelle, pas un tirage chanceux.
function zMoyennes(a, b) { return (moyenne(a) - moyenne(b)) / Math.sqrt(variance(a) / a.length + variance(b) / b.length || 1e-12); }
// Idem pour deux proportions (succès / essais).
function zProportions(sa, na, sb, nb) {
  const p = (sa + sb) / (na + nb), se = Math.sqrt(p * (1 - p) * (1 / na + 1 / nb));
  return se === 0 ? 0 : (sa / na - sb / nb) / se;
}
const Z = 4; // 4 écarts types : ≈ 1 chance sur 15 000 qu'un tirage seul le produise
function plusGrand(quoi, z) { assert.ok(z > Z, `${quoi} : écart de ${z.toFixed(1)} écarts types (≥ ${Z} attendus)`); }
// Une moyenne d'échantillon doit tenir dans une fenêtre de plausibilité élargie de k écarts types de la moyenne.
function moyenneDans(quoi, valeurs, [bas, haut], k = 3) {
  const m = moyenne(valeurs), e = k * Math.sqrt(variance(valeurs) / valeurs.length);
  assert.ok(m + e >= bas && m - e <= haut, `${quoi} : moyenne ${m.toFixed(2)} ± ${e.toFixed(2)} hors de [${bas} ; ${haut}] (n = ${valeurs.length})`);
  return m;
}

// Rapport d'échantillon (par exemple temps forts qui marquent / temps forts) : estimateur par rapport sur n matchs et son erreur type
// (méthode delta), car le nombre de temps forts varie d'un match à l'autre.
function rapport(xs, es) {
  const n = xs.length, r = somme(xs) / somme(es), residus = xs.map((x, i) => x - r * es[i]), em = somme(es) / n;
  return { r, se: Math.sqrt(somme(residus.map(v => v * v)) / (n * (n - 1))) / em };
}
function rapportDans(quoi, xs, es, [bas, haut], k = 3) {
  const { r, se } = rapport(xs, es);
  assert.ok(r + k * se >= bas && r - k * se <= haut, `${quoi} : ${(100 * r).toFixed(1)} % ± ${(100 * k * se).toFixed(1)} hors de [${100 * bas} ; ${100 * haut}] % (${xs.length} matchs)`);
  return r;
}

module.exports = { rapport, rapportDans, BAS, HAUT, courseReussie, injecter, consommes, constant, balayage, photographier, rejouer, somme, moyenne, variance, ecartType, zMoyennes, zProportions, Z, plusGrand, moyenneDans };
