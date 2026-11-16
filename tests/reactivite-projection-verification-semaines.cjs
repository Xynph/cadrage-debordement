'use strict';
// Réactivité du moteur (lot 19), mode vérification, semaines (suite séparée le 16/11/2026 pour rester sous le délai de
// 180 s du lanceur CI : une partie du parcours par fichier, mêmes assertions et mêmes graines ; voir
// tests/helpers/reactivite-projection-parcours.cjs).
//
// Sur la même graine, carrière Monde (`world-champ`, cadence de la semaine pour atteindre vite un match) : modèles
// identiques section par section, et profil écrit identique, entre la projection d'avant (projectionSections:false) et
// la projection par sections avec le mode vérification (chaque section reprise recalculée et comparée, chaque section
// de la carrière relue pour contrôler state-versions.cjs ; commandes sans effet sur les joueurs ; catalogues de création
// et carrière internationale repris recalculés et comparés). Partie couverte : semaines closes jusqu’au prochain match.
const { test } = require('node:test');
const { parcoursIsole, comparer } = require('./helpers/reactivite-projection-parcours.cjs');

test('Projection par sections, mode vérification, semaines : mêmes modèles et même profil que la projection d’avant', { timeout: 1800000 }, () => {
  // Un seul pont Monde à la fois (machine de 8 Go).
  const avant = parcoursIsole({ segment: 'semaines', projectionSections: false });
  const verifie = parcoursIsole({ segment: 'semaines', verifyProjection: true, verifyMemo: true, verifyCleanCopy: true });
  comparer(avant, verifie, 'vérification');
});
