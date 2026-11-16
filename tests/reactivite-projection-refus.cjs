'use strict';
// Réactivité du moteur (lot 19), commande refusée : une commande refusée sans effet part comme un patch « rien n'a
// changé » qui reconstruit le même modèle qu'un instantané complet ; sans révision concordante, la réponse redevient
// complète. Séparé de tests/reactivite-projection-rapide*.cjs (même test) le 16/11/2026 pour rester sous le délai de
// 180 s du lanceur CI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { DOSSIER, M, createEncoder } = require('./helpers/reactivite-projection-parcours.cjs');

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
