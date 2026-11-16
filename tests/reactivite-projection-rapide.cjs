'use strict';
// Réactivité du moteur (lot 19), 2/2 : projection rapide, direct, lectures et commande refusée (points 2 à 4) : projection par sections (projection-sections.cjs), versions des sections de la
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
const fs = require('node:fs');
const { test } = require('node:test');
const { DOSSIER, M, createEncoder, parcoursIsole, comparer } = require('./helpers/reactivite-projection-parcours.cjs');

test('Projection par sections : mêmes modèles et même profil, direct allégé, lectures sans grands domaines', { timeout: 1800000 }, () => {
  // Un seul pont Monde à la fois (machine de 8 Go).
  const avant = parcoursIsole({ projectionSections: false });
  const rapide = parcoursIsole({});
  assert.ok(comparer(avant, rapide, 'sections') > 0, 'direct : des sections gardées de la dernière réponse complète');
  assert.ok(rapide.etapes.slice(2).every(e => e.joint), 'textes des sections joints aux réponses');
  assert.equal(rapide.lecturesMarche, 0, 'instantané et fiches club sans recalcul du marché entre clubs');
});

test('Commande refusée : réponse légère « rien n’a changé », même modèle reconstruit', { timeout: 600000 }, () => {
  fs.rmSync(DOSSIER, { recursive: true, force: true });
  const jeu = M.ouvrir({ hebdomadaire: true, deferredCommits: true, lightErrors: true, dataDir: DOSSIER });
  try {
    const encoder = createEncoder();
    let base = -1, model = null, id = 100;
    const envoyer = (command, payload = {}) => {
      const result = jeu.bridge.handle({ id: ++id, command, payload });
      const ligne = encoder.encode(result, base), reponse = JSON.parse(ligne);
      if (reponse.patch) { model = encoder.apply(model, reponse.patch); base = reponse.patch.rev; }
      jeu.bridge.handle.flush();
      return { reponse, octets: ligne.length };
    };
    envoyer('new_career', { mode: 'world-champ', club: 102 });
    model = jeu.regler(model);
    envoyer('snapshot');
    const avant = JSON.stringify(model);
    const refus = envoyer('club_meeting_ack', { meetingId: 'inconnu' });
    assert.equal(refus.reponse.ok, false);
    assert.match(refus.reponse.error, /rendez-vous/i);
    assert.equal(refus.reponse.patch.full, false);
    assert.deepEqual(refus.reponse.patch.set, {}, 'aucune section renvoyée');
    assert.ok(refus.octets < 4096, 'réponse légère (' + refus.octets + ' octets)');
    assert.equal(JSON.stringify(model), avant, 'modèle reconstruit inchangé');
    // Modèle d'un instantané complet : le même.
    const complet = envoyer('snapshot');
    assert.equal(complet.reponse.ok, true);
    assert.equal(JSON.stringify(model), avant, 'instantané identique au modèle gardé');
    // Révision inconnue : la réponse au refus redevient complète.
    const result = jeu.bridge.handle({ id: ++id, command: 'club_meeting_ack', payload: { meetingId: 'inconnu' } });
    const plein = JSON.parse(encoder.encode(result, 999999));
    assert.equal(plein.patch.full, true);
    assert.equal(JSON.stringify(encoder.apply(null, plein.patch)), avant, 'réponse complète identique');
  } finally { jeu.fermer(); fs.rmSync(DOSSIER, { recursive: true, force: true }); }
});
