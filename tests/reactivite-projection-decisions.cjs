'use strict';
// Réactivité du moteur (lot 20, #777) : décisions sur un joueur du club et délégation.
//
// Sur la même graine, carrière Monde (`world-champ`) sans match : consigne de charge (deux fois, la seconde sur un champ
// déjà présent), délégations de la composition et de l'entraînement, axe de progression, plan de travail.
//   1. modèles identiques section par section, et profil écrit identique, entre la projection d'avant
//      (projectionSections:false), le mode vérification (state-versions.cjs : autres clubs relus et comparés pour les
//      décisions sur le club du manager, lectures relevées champ par champ, devis d'agents mémorisés à part recalculés et
//      comparés) et la projection rapide ;
//   2. la seconde consigne de charge et les délégations ne recalculent pas le marché entre clubs.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { parcoursIsole, comparer } = require('./helpers/reactivite-projection-parcours.cjs');

test('Charge, délégation, axe et plan de travail : mêmes modèles et même profil, sans recalcul du marché', { timeout: 1800000 }, () => {
  // Un seul pont Monde à la fois (machine de 8 Go).
  const avant = parcoursIsole({ scenario: 'decisions', projectionSections: false });
  const verifie = parcoursIsole({ scenario: 'decisions', verifyProjection: true, verifyMemo: true, verifyCleanCopy: true });
  comparer(avant, verifie, 'vérification');
  const rapide = parcoursIsole({ scenario: 'decisions' });
  comparer(avant, rapide, 'sections');
  assert.equal(rapide.decisionsMarche, 0, 'charge d’un joueur et délégation sans recalcul du marché entre clubs');
});
