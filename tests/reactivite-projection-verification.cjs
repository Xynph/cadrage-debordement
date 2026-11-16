'use strict';
// Réactivité du moteur (lot 19), 1/2 : mode vérification (point 1) : projection par sections (projection-sections.cjs), versions des sections de la
// carrière (state-versions.cjs), réponses légères aux commandes refusées et direct du match allégé.
//
// Sur la même graine, carrière Monde (`world-champ`, cadence de la semaine pour atteindre vite un match) :
//   1. modèles identiques section par section, et profil écrit identique, entre la projection d'avant
//      (projectionSections:false) et la projection par sections, avec et sans le mode vérification (chaque section
//      reprise recalculée et comparée, chaque section de la carrière relue pour contrôler state-versions.cjs ; les
//      commandes déclarées sans effet sur les joueurs relèvent quand même qualités et connaissance et refusent toute
//      progression ; catalogues de création et carrière internationale repris sont recalculés et comparés) ;
//   2. pendant le direct, seules les sections gardées (grands domaines, carrière internationale, développement,
//      planification) peuvent différer, et elles valent la dernière réponse complète ; après le match, tout est égal ;
//   3. une commande refusée sans effet part comme un patch « rien n'a changé » qui reconstruit le même modèle qu'un
//      instantané complet ; sans révision concordante, la réponse redevient complète ;
//   4. une lecture (fiche club, instantané) ne recalcule pas les grands domaines (sections reprises).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { parcoursIsole, comparer } = require('./helpers/reactivite-projection-parcours.cjs');

test('Projection par sections, mode vérification : mêmes modèles et même profil que la projection d’avant', { timeout: 1800000 }, () => {
  // Un seul pont Monde à la fois (machine de 8 Go).
  const avant = parcoursIsole({ projectionSections: false });
  const verifie = parcoursIsole({ verifyProjection: true, verifyMemo: true, verifyCleanCopy: true });
  comparer(avant, verifie, 'vérification');
});
