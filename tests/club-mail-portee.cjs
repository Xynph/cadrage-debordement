'use strict';
// Portée de la réponse à un courrier du club (club_mail_reply) pour la projection de l'interface (state-versions.cjs).
// Ses effets (moral, confiance, presse, satisfaction, charge, promesse, promotion d'un jeune, trésorerie) ne touchent que
// le club du manager ; la boîte, le journal et les nouvelles sont des sections légères. Elle est donc déclarée
// « club du manager seulement » (UNTOUCHED sauf `clubs`, OWN_CLUB).
//   1. Déclaration : sections lourdes hors `clubs` intactes, club du manager seul relu.
//   2. Carrière Monde (`world-champ`, calendrier journalier) en mode vérification : chaque réponse reçue est jouée, les
//      autres clubs sont relus et comparés, et toute section déclarée intacte qui change lève une erreur.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const SV = require('../native/engine/state-versions.cjs');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

test('Déclaration : club_mail_reply ne relit que le club du manager parmi les sections lourdes', () => {
  assert.equal(SV.ownClubOnly('club_mail_reply'), true);
  assert.deepEqual(SV.untouched('club_mail_reply', { id: 'mail-1', choice: 'x' }), SV.HEAVY.filter(k => k !== 'clubs'));
});

test('Carrière Monde, mode vérification : les réponses au courrier ne modifient que le club du manager', { timeout: 900000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-courrier-portee-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, verifyProjection: true });
  const reponses = [], durees = [];
  try {
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    for (let i = 0; i < 40 && reponses.length < 3; i++) {
      for (const mail of m.clubLife.clubMail.mails.filter(x => x.status === 'nouveau' && x.reponses.some(r => r.disponible) && !reponses.some(y => y.startsWith(x.type + '/')))) {
        const choix = mail.reponses.find(r => r.disponible);
        const debut = Date.now(), r = jeu.brut('club_mail_reply', { id: mail.id, choice: choix.id });
        durees.push(Date.now() - debut);
        assert.equal(r.ok, true, mail.type + '/' + choix.id + ' : ' + r.error);
        m = r.model;
        reponses.push(mail.type + '/' + choix.id);
      }
      if (m.meta.calendarCadence?.matchReady && m.next) { m = M.jouerLeMatch(jeu, m); continue; }
      if (m.live) { m = jeu.regler(skipMatchTalk(jeu.call('finish_round'), jeu.call)); continue; }
      const r = jeu.brut('advance_until_event', { fromDate: m.meta.calendarToday, maxDays: 3, stops: { messages: 'aucun' } });
      assert.equal(r.ok, true, 'Continuer : ' + r.error);
      m = jeu.regler(r.model);
    }
    assert.ok(reponses.length >= 3, 'au moins trois réponses jouées : ' + reponses.join(', '));
  } finally { jeu.fermer(); fs.rmSync(dir, { recursive: true, force: true }); }
});
