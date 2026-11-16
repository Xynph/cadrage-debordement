'use strict';
// Réactivité du moteur (lot 19), projection rapide, semaines (suite séparée le 16/11/2026 pour rester sous le délai de
// 180 s du lanceur CI : une partie du parcours par fichier, mêmes assertions et mêmes graines ; voir
// tests/helpers/reactivite-projection-parcours.cjs).
//
// Sur la même graine, carrière Monde (`world-champ`, cadence de la semaine pour atteindre vite un match) : modèles
// identiques section par section, et profil écrit identique, entre la projection d'avant (projectionSections:false) et
// la projection par sections. Partie couverte : semaines closes jusqu’au prochain match.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { parcoursIsole, comparer } = require('./helpers/reactivite-projection-parcours.cjs');

test('Projection par sections, semaines : mêmes modèles et même profil', { timeout: 1800000 }, () => {
  // Un seul pont Monde à la fois (machine de 8 Go).
  const avant = parcoursIsole({ segment: 'semaines', projectionSections: false });
  const rapide = parcoursIsole({ segment: 'semaines' });
  comparer(avant, rapide, 'sections');
  assert.ok(rapide.etapes.every(e => e.joint), 'textes des sections joints aux réponses');
});
