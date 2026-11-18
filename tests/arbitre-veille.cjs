'use strict';
// Arbitre désigné la veille du match (club-mail.cjs `arbitre`, avant-match.cjs `arbitre`, match-pilotage.js) : le mail
// de la veille, la tuile « avant-match » et le direct annoncent le même arbitre, tiré avec les mêmes fixtureId et
// competitionId que ceux du match joué (`worldContext.id` / `worldContext.competitionId`).
const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('./helpers/carriere-monde.cjs');

test('Arbitre : mail de la veille, avant-match et direct désignent le même arbitre', { timeout: 600000 }, () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    const vm = jeu.bridge.vm;
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102 }));
    const mails = [];
    for (let j = 0; j < 150; j++) {
      m = jeu.regler(m);
      for (const x of m.clubLife.clubMail.mails) if (x.type === 'arbitre' && !mails.some(y => y.id === x.id)) mails.push(x);
      if (m.meta.calendarCadence?.matchReady && m.next) break;
      assert.equal(m.meta.calendarCadence?.canAdvance, true);
      m = jeu.call('advance_day', { fromDate: m.meta.calendarToday });
    }
    assert.ok(m.meta.calendarCadence?.matchReady, 'jour de match atteint');
    const f = JSON.parse(vm.run('JSON.stringify(CDWorldCareer.userFixture(S))'));
    const attendu = JSON.parse(vm.run(`JSON.stringify(arbitreDuMatch(${JSON.stringify(f.id)},${JSON.stringify(f.competitionId)}))`));
    const am = m.clubLife.avantMatch;
    assert.ok(am && am.arbitre, 'avantMatch.arbitre présent avant le match');
    assert.equal(am.arbitre.nom, attendu.nom);
    assert.deepEqual([am.arbitre.rucks, am.arbitre.melee, am.arbitre.horsJeu, am.arbitre.cartons, am.arbitre.resume],
      [attendu.rucks, attendu.melee, attendu.horsJeu, attendu.cartons, attendu.resume]);
    const mail = mails.find(x => x.key === f.id || (x.corps || '').includes(attendu.nom));
    assert.ok(mail, 'mail d\'arbitre reçu avant le match : ' + mails.length);
    assert.ok(`${mail.sujet} ${mail.corps}`.includes(attendu.nom), 'le mail nomme l\'arbitre');
    assert.ok(mail.corps.includes(attendu.resume), 'le mail reprend le résumé');
    assert.match(mail.corps, /\([1-5]\/5\)/, 'tendances chiffrées');
    assert.equal(mail.expediteur || mail.from || 'La commission des arbitres', 'La commission des arbitres');
    const veille = new Date(Date.parse(m.meta.calendarToday + 'T00:00:00Z') - 86400000).toISOString().slice(0, 10);
    assert.equal(String(mail.date).slice(0, 10), veille, 'reçu la veille du match');
    m = M.jouerLeMatch(jeu, m, { delegue: false });
    const ctx = JSON.parse(vm.run('JSON.stringify({id:S.live.worldContext.id,c:S.live.worldContext.competitionId})'));
    assert.deepEqual([ctx.id, ctx.c], [f.id, f.competitionId], 'mêmes identifiants que le direct');
    assert.equal(m.live.pilotage.arbitre.nom, attendu.nom, 'le direct a le même arbitre');
    assert.equal(m.live.pilotage.arbitre.nom, am.arbitre.nom);
  } finally { jeu.fermer(); }
});
