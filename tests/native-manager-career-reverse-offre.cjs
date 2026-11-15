'use strict';
// Mobilité du manager, vrai worker de production, mode Monde (1/2) : Accession (club 29) → Élite à l'ouverture de la
// fenêtre de fin de saison. Reprend la première moitié de l'ancien tests/manuel/native-manager-career-reverse.cjs
// (déplacé hors CI par #694 faute de pouvoir rejouer ~850 s de saison) : la saison est lue dans la sauvegarde générée
// par scripts/generer-sauvegarde-mobilite.cjs (cache CI sur l'empreinte du moteur). Mêmes assertions que l'original :
// candidature, refus puis acceptation impossible, annulation (témoin), pureté octets, reprise exacte.
// La seconde moitié (saison suivante, comptes/effectifs/centre conservés) : native-manager-career-reverse-saison.cjs.
const assert = require('node:assert/strict'), fs = require('node:fs');
const { banc } = require('./helpers/sauvegarde-mobilite.cjs');
const t = banc();
try {
 const { open, good, raw, doc, data, act, ouvrirFinDeSaison, cibleElite } = t;
 const b = ouvrirFinDeSaison('accession');
 const target = cibleElite(b);
 act(b, 'manager_career_apply', { clubId: target.clubId }); const offerId = 'job-1-' + target.clubId;
 const current = good(b, 'export').meta.exportText, declined = open('declined'); good(declined, 'import', { text: current });
 act(declined, 'manager_career_decline', { offerId });
 assert.equal(data(declined).applications.find(a => a.id === offerId).status, 'declined');
 assert.equal(raw(declined, 'manager_career_accept', { context: data(declined).context, offerId, confirmed: true }).ok, false);
 act(b, 'manager_career_accept', { offerId, confirmed: true });
 const control = open('control'); good(control, 'import', { text: good(b, 'export').meta.exportText }); act(control, 'manager_career_cancel');
 assert.ok(data(b).pending, 'offre acceptée en attente de la saison suivante');
 assert.ok(!data(control).pending, 'annulation témoin : plus d’offre en attente');
 const saved = good(b, 'export').meta.exportText, file = require('node:path').join(good(b, 'snapshot').meta.dataDir, 'donnees.json'), bytes = fs.readFileSync(file);
 for (let i = 0; i < 3; i++) good(b, 'snapshot');
 assert.deepEqual(fs.readFileSync(file), bytes); assert.equal(good(b, 'export').meta.exportText, saved);
 good(b, 'shutdown'); const resumed = open('accession');
 assert.equal(good(resumed, 'snapshot').meta.recoveryRequired, false); assert.equal(good(resumed, 'export').meta.exportText, saved);
 console.log('PASS mobilité manager (1/2) : Accession29→Élite, refus, annulation témoin, pureté octets, reprise exacte');
} finally { t.fermer(); }
