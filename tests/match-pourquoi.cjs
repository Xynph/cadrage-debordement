'use strict';
// « Pourquoi » d'après-match (native/engine/match-pourquoi.cjs) : trois raisons au plus, classées, chacune
// reliée à un levier du manager et à l'écran où l'actionner, tirées des seuls faits mesurés du match.
//   1. Faits extraits de la projection de fin de match (tableau, score, notes, énergie), vus depuis notre camp.
//   2. Défaite : les faits qui ont coûté d'abord ; victoire : ceux qui ont porté ; un levier une seule fois.
//   3. Aucun écart net : aucune raison (rien d'inventé). Déterminisme : même entrée, même sortie.
//   4. Projection réelle (match-direct.cjs) : `direct.pourquoi` posé au coup de sifflet final seulement.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const P = require('../native/engine/match-pourquoi.cjs');

// Tableau de fin de match (mêmes clés que match-direct.cjs), camp 0 = notre club.
const tableau = (v = {}) => [
  { cle: 'possession', valeurs: v.possession || [50, 50] },
  { cle: 'occupation', valeurs: v.occupation || [50, 50] },
  { cle: 'plaquages_manques', valeurs: v.manques || [10, 10] },
  { cle: 'melees', valeurs: v.melees || [6, 6], sur: v.meleesSur || [6, 6] },
  { cle: 'touches', valeurs: v.touches || [10, 10], sur: v.touchesSur || [10, 10] },
  { cle: 'penalites', valeurs: v.penalites || [9, 9] },
  { cle: 'cartons', valeurs: v.cartons || [0, 0] },
];
const direct = (score, v = {}, notes = {}) => ({ camp: v.camp ?? 0, score, tableau: tableau(v), notes });

test('Défaite : discipline, conquête et condition classées, une action par levier', () => {
  const d = direct([13, 27], { penalites: [14, 6], cartons: [1, 0], touches: [8, 12], touchesSur: [14, 12], occupation: [47, 53] });
  const r = P.raisons(P.faits(d, { energie: [55, 69] }));
  assert.equal(r.issue, 'defaite');
  assert.equal(r.raisons.length, 3);
  assert.deepEqual(r.raisons.map(x => x.levier), ['discipline', 'preparation', 'condition']);
  assert.deepEqual(r.raisons.map(x => x.rang), [1, 2, 3]);
  assert.ok(r.raisons.every(x => x.sens === 'negatif'));
  assert.match(r.raisons[0].texte, /14 pénalités et 1 carton \(6 pour eux\)/);
  assert.match(r.raisons[1].texte, /Touche : 8 gagnées sur 14/);
  assert.match(r.raisons[2].texte, /55 % d’énergie contre 69 %/);
  assert.deepEqual(r.raisons.map(x => x.action), ['Travailler la discipline', 'Préparer la semaine', 'Voir la condition']);
  assert.deepEqual(r.raisons.map(x => x.route), ['Composition', 'Préparation', 'Effectif']);
  // L'occupation (3 points d'écart) reste sous le seuil : non citée.
  assert.ok(!r.raisons.some(x => x.texte.includes('moitié')));
});

test('Victoire : ce qui a porté d’abord, un levier une seule fois', () => {
  const d = direct([31, 12], { occupation: [64, 36], manques: [6, 17], penalites: [7, 12] });
  const r = P.raisons(P.faits(d));
  assert.equal(r.issue, 'victoire');
  // Discipline (5 pénalités d'écart, 6 points) devant la défense (11 plaquages manqués d'écart, 4,9) ; la défense
  // pèse plus que l'occupation (3,5), même levier « tactique » : une seule raison tactique.
  assert.deepEqual(r.raisons.map(x => x.levier), ['discipline', 'tactique']);
  assert.match(r.raisons[0].texte, /Discipline propre : 7 pénalités concédées contre 12/);
  assert.match(r.raisons[1].texte, /6 plaquages manqués seulement, contre 17/);
  assert.ok(r.raisons.every(x => x.sens === 'positif'));
  assert.equal(r.raisons[1].action, 'Ajuster la tactique');
});

test('Composition : joueurs sous 5,5 nommés ; notes adverses ignorées', () => {
  const notes = { a: { note: 4.8, faits: 6, cote: 0 }, b: { note: 5.2, faits: 3, cote: 0 }, c: { note: 7.1, faits: 9, cote: 0 }, x: { note: 3.9, faits: 4, cote: 1 } };
  const r = P.raisons(P.faits(direct([10, 18], {}, notes), { noms: { a: 'Martin', b: 'Durand', x: 'Adverse' } }));
  assert.deepEqual(r.raisons.map(x => x.levier), ['composition']);
  assert.match(r.raisons[0].texte, /2 joueurs sous 5,5 de note : Martin \(4,8\), Durand \(5,2\)/);
  assert.ok(!r.raisons[0].texte.includes('Adverse'));
  assert.equal(r.raisons[0].action, 'Revoir la composition');
});

test('Match équilibré : aucune raison inventée ; même entrée, même sortie ; camp 1', () => {
  assert.deepEqual(P.raisons(P.faits(direct([20, 20]))).raisons, []);
  assert.equal(P.raisons(P.faits(direct([20, 20]))).issue, 'nul');
  assert.deepEqual(P.raisons(P.faits({ camp: -1, tableau: [] })), { issue: null, raisons: [] });
  const d = direct([9, 22], { camp: 1, penalites: [15, 6] });
  // Camp 1 : nos pénalités sont la seconde valeur ; score lu depuis notre camp (22-9 : victoire).
  const a = P.raisons(P.faits(d)), b = P.raisons(P.faits(JSON.parse(JSON.stringify(d))));
  assert.deepEqual(a, b);
  assert.equal(a.issue, 'victoire');
  assert.match(a.raisons[0].texte, /Discipline propre : 6 pénalités concédées contre 15 en face/);
  // Lignes masquées (« vide ») ou absentes : jamais de chiffre inventé.
  const masque = { camp: 0, score: [3, 30], tableau: [{ cle: 'penalites', valeurs: [12, 2], vide: true }] };
  assert.deepEqual(P.raisons(P.faits(masque)).raisons, []);
});
