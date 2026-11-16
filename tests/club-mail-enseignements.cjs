'use strict';
// Courrier du club, boucle match → semaine (native/engine/club-mail.cjs + club-mail.json, 16/11/2026) :
//   - lendemain d'un match du club : Gabi envoie « trois enseignements » tirés des vraies statistiques du match
//     (mêlée, touche, discipline, buteur, territoire) et propose un axe ; la réponse oriente la préparation collective ;
//   - chaque lundi : « le tour du championnat » (carton, surprise, leader, série) dans le championnat du club.
// Carrière Monde (`world-champ`, départ « veille ») jouée à « Continuer » sur trois semaines.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const FIN = '2026-10-01';

test('Carrière Monde : enseignements du match avec axe de semaine, tour du championnat le lundi', { timeout: 900000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-enseignements-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
  try {
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    const vm = jeu.bridge.vm;
    let repondu = null;
    for (let i = 0; i < 300 && m.meta.calendarToday < FIN; i++) {
      m = jeu.regler(m);
      const bilan = m.clubLife.clubMail.mails.find(x => x.type === 'bilan_match' && x.status === 'nouveau');
      if (bilan && !repondu && !m.live && !m.meta.calendarCadence?.matchReady) {
        const avant = JSON.parse(vm.run('JSON.stringify({ai:S.aiRoster||null,others:Object.keys(S.clubs).filter(k=>String(k)!==String(S.club)).map(k=>S.clubs[k].players?.length)})'));
        const r = jeu.brut('club_mail_reply', { id: bilan.id, choice: 'defense' });
        assert.equal(r.ok, true, r.error);
        m = r.model;
        assert.equal(vm.run('S.collectiveFocus'), 'defence', 'axe de la semaine appliqué');
        const apres = JSON.parse(vm.run('JSON.stringify({ai:S.aiRoster||null,others:Object.keys(S.clubs).filter(k=>String(k)!==String(S.club)).map(k=>S.clubs[k].players?.length)})'));
        assert.deepEqual(apres, avant, 'les autres clubs ne bougent pas');
        repondu = bilan;
      }
      if (m.meta.calendarCadence?.matchReady && m.next) { m = M.jouerLeMatch(jeu, m); continue; }
      if (m.live) { m = jeu.regler(skipMatchTalk(jeu.call('finish_round'), jeu.call)); continue; }
      const borne = Math.max(1, Math.round((Date.parse(FIN) - Date.parse(m.meta.calendarToday)) / 86400000));
      const r = jeu.brut('advance_until_event', { fromDate: m.meta.calendarToday, maxDays: Math.min(120, borne), stops: { messages: 'aucun' } });
      assert.equal(r.ok, true, 'Continuer le ' + m.meta.calendarToday + ' : ' + r.error);
      m = r.model;
      const scene = vm.run('S.sceneInvitations?.activeId||null');
      if (scene) m = jeu.call('scene_invitation_close', { id: scene, dismiss: true });
    }
    const mails = m.clubLife.clubMail.mails;
    const bilans = mails.filter(x => x.type === 'bilan_match'), tours = mails.filter(x => x.type === 'tour_championnats');
    for (const x of [...bilans, ...tours]) { console.log(x.date, x.type, '·', x.sujet, '·', x.corps); assert.doesNotMatch(x.sujet + x.corps, /\{|\}|undefined|NaN|null/, x.type); }
    assert.ok(bilans.length >= 2, 'enseignements après chaque match : ' + bilans.length);
    assert.ok(repondu, 'réponse au bilan donnée');
    assert.ok(tours.length >= 2, 'tour du championnat chaque lundi : ' + tours.length);
    for (let i = 1; i < bilans.length; i++) assert.notEqual(bilans[i].f, bilans[i - 1].f, 'formulation répétée');
  } finally {
    jeu.fermer?.();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
