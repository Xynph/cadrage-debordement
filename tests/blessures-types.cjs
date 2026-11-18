'use strict';
// Types de blessure (native/engine/club-mail.cjs, données « blessures » de club-mail.json ; demande de Léo, 18/11/2026) :
// type tiré à la création, cohérent avec la durée, stable (empreinte, pas de hasard), cause lue dans le journal du
// club, effacé à la guérison ; commotion = protocole (une à deux semaines) ; ancienne sauvegarde sans type acceptée.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory, DATA } = require('../native/engine/club-mail.cjs');

globalThis.nativeClubMailData = DATA;
const mail = factory();

const state = () => ({ season: 2, club: 0, news: ['Jean Dupont est blessé après la rencontre : 3 semaine(s) d’indisponibilité.', 'Marc Petit s’est blessé à l’entraînement : indisponible 1 semaine(s).'],
  clubs: { 0: { players: [
    { id: 'a', name: 'Jean Dupont', pos: 'Pilier gauche', injury: 3 },
    { id: 'b', name: 'Marc Petit', pos: 'Ailier', injury: 1 },
    { id: 'c', name: 'Luc Martin', pos: 'Centre', injury: 0 },
  ] }, 1: { players: Array.from({ length: 60 }, (_, i) => ({ id: 'x' + i, name: 'Adverse ' + i, pos: i % 2 ? 'Talonneur' : 'Arrière', injury: 1 + (i % 4) })) } } });

test('Données : types crédibles, durées et poids valides, commotion sous protocole', () => {
  const types = DATA.blessures.types;
  assert.ok(Object.keys(types).length >= 8);
  for (const [k, t] of Object.entries(types)) {
    assert.ok(t.libelle && t.conseil, k);
    assert.ok(t.semaines[0] >= 1 && t.semaines[0] <= t.semaines[1], k + ' : durée');
    assert.ok(t.poids.avants >= 0 && t.poids.arrieres >= 0 && t.poids.avants + t.poids.arrieres > 0, k + ' : poids');
  }
  assert.match(types.commotion.libelle, /protocole/i);
  assert.ok(types.commotion.semaines[1] <= 2);
  assert.ok(types.croises.semaines[0] >= 12, 'ligaments croisés : longue absence');
});

test('Type tiré à la création, cohérent avec la durée, stable, cause du journal, effacé à la guérison', () => {
  const s = state();
  mail.blessures.typer(s, '2026-09-20');
  const [a, b, c] = s.clubs[0].players;
  for (const p of [a, b, ...s.clubs[1].players]) {
    const t = DATA.blessures.types[p.injuryType];
    assert.ok(t, p.id + ' : type');
    assert.ok(p.injury >= t.semaines[0] && p.injury <= t.semaines[1], p.id + ' : ' + p.injuryType + ' pour ' + p.injury + ' sem.');
    assert.equal(p.injuryDate, '2026-09-20');
  }
  assert.equal(c.injuryType, undefined);
  assert.equal(a.injuryCause, 'match');
  assert.equal(b.injuryCause, 'entrainement');
  assert.ok(!s.clubs[1].players.some(p => /Arri/.test(p.pos) && p.injuryType === 'cou'), 'cervicales : avants seulement');
  assert.ok(new Set(s.clubs[1].players.map(p => p.injuryType)).size >= 4, 'variété des types');
  // Stable : même état, même jour -> mêmes types ; un type déjà posé ne change plus.
  const again = state();
  mail.blessures.typer(again, '2026-09-20');
  assert.deepEqual(again.clubs[1].players.map(p => p.injuryType), s.clubs[1].players.map(p => p.injuryType));
  const kept = a.injuryType;
  a.injury = 2;
  mail.blessures.typer(s, '2026-09-27');
  assert.equal(a.injuryType, kept);
  // Guérison : type, cause et date effacés.
  a.injury = 0;
  mail.blessures.typer(s, '2026-10-04');
  assert.equal(a.injuryType, undefined);
  assert.equal(a.injuryCause, undefined);
  assert.equal(a.injuryDate, undefined);
});

test('Ancienne sauvegarde : joueur blessé sans type accepté, type inconnu refusé', () => {
  const s = state();
  s.clubMail = { version: 1, seq: 0, last: null, mails: [], sent: {}, suites: [], memo: {} };
  assert.equal(mail.validate(s), true);
  s.clubs[0].players[0].injuryType = 'inconnu';
  assert.throws(() => mail.validate(s), /type de blessure/);
});
