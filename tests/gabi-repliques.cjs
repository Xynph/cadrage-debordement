'use strict';
// Gabi : sélection déterministe de la réplique spontanée (native/engine/gabi-repliques.cjs).
// Une réplique commence par une information utile tirée de l'état, avec une action ; l'ambiance est rare.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const G = require('../native/engine/gabi-repliques.cjs');

const joueur = (id, extra = {}) => ({ id, name: 'Joueur ' + id, rating: 70, condition: 100, injury: 0, contractEnd: 3, ...extra });
function base(extra = {}) {
  const squad = Array.from({ length: 15 }, (_, i) => joueur('p' + i));
  return {
    club: { id: 0, name: 'Capitole XV' }, meta: { hasCareer: true, season: 1, week: 2, calendarToday: '2026-09-03' },
    squad, selection: { valid: true, slots: squad.map((p, i) => ({ slot: i, playerId: p.id })) },
    next: { id: 'f1', date: '2026-09-05', week: 2, home: { id: 0, name: 'Capitole XV' }, away: { id: 4, name: 'Les Ormes' } },
    calendarMail: [], clubLife: { press: { invitations: [] } }, ...extra,
  };
}

test('Sans carrière ou sans club : aucune réplique', () => {
  assert.equal(G.choisir({}).replique, null);
  assert.equal(G.choisir({ club: { id: 0 }, meta: { hasCareer: false } }).replique, null);
});

test('Le prochain match est la réplique de repli, avec son action', () => {
  const r = G.choisir(base()).replique;
  assert.equal(r.genre, 'match');
  assert.match(r.texte, /dans 2 jours contre Les Ormes/);
  assert.deepEqual([r.action.type, r.action.route, r.action.libelle], ['ecran', 'Préparation', 'Ouvrir la préparation']);
});

test('Priorités : courrier > feuille > blessé > condition > presse > contrat > match', () => {
  const m = base();
  m.squad[3].condition = 55; m.squad[5].condition = 62;
  assert.equal(G.choisir(m).replique.genre, 'condition');
  assert.match(G.choisir(m).replique.texte, /2 titulaires sous 70 % de condition dans 2 jours : Joueur p3 \(55 %\) et Joueur p5 \(62 %\)/);
  m.squad[1].injury = 2;
  assert.equal(G.choisir(m).replique.genre, 'blesses');
  m.selection.valid = false;
  assert.equal(G.choisir(m).replique.genre, 'feuille');
  m.calendarMail = [{ id: 'c1', status: 'pending', opponent: 'Les Ormes' }];
  const r = G.choisir(m).replique;
  assert.equal(r.genre, 'courrier');
  assert.equal(r.action.route, 'Réception');
  assert.match(r.texte, /Les Ormes/);
  assert.deepEqual(G.choisir(m).autres.length, 3);
});

test('Condition et blessures ne comptent qu’à l’approche du match (3 jours)', () => {
  const m = base();
  m.squad[3].condition = 40;
  m.meta.calendarToday = '2026-08-20';
  assert.equal(G.choisir(m).replique.genre, 'match');
  m.meta.calendarToday = '2026-09-05';
  assert.equal(G.choisir(m).replique.genre, 'condition');
  assert.match(G.choisir(m).replique.texte, /aujourd’hui/);
});

test('Contrat urgent : les mieux notés d’abord, sans match au calendrier', () => {
  const m = base({ next: null, calendar: [] });
  m.squad[2] = joueur('p2', { contractEnd: 1, rating: 88 });
  m.squad[7] = joueur('p7', { contractEnd: 1, rating: 91 });
  m.squad[9] = joueur('p9', { contractEnd: 1, rating: 60 });
  const r = G.choisir(m).replique;
  assert.equal(r.genre, 'contrat');
  assert.match(r.texte, /^Joueur p7 \(91\) et Joueur p2 \(88\) s’arrêtent en fin de saison, avec 1 autre contrats?/);
  assert.equal(r.action.route, 'Effectif');
});

test('Déterminisme et ambiance rare : une fois sur quatre au plus, jamais seule', () => {
  const m = base();
  assert.deepEqual(G.choisir(m), G.choisir(structuredClone(m)));
  let avec = 0;
  for (let d = 1; d <= 120; d++) {
    const x = base(); x.meta.calendarToday = '2026-08-' + String(d % 28 + 1).padStart(2, '0'); x.club.id = d;
    const r = G.choisir(x);
    assert.ok(r.replique, 'une information utile précède toujours l’ambiance');
    if (r.ambiance) avec++;
  }
  assert.ok(avec > 10 && avec < 60, 'ambiance : ' + avec + ' / 120');
});

test('Carrière Monde : le moteur attache la réplique à l’instantané (jour 1 et jour de match)', () => {
  const M = require('./helpers/carriere-monde.cjs');
  const jeu = M.ouvrir({ hebdomadaire: true });
  try {
    let model = M.creer(jeu, 0);
    assert.ok(model.gabi.replique, 'réplique utile dès le jour 1');
    assert.ok(['match', 'contrat', 'courrier'].includes(model.gabi.replique.genre));
    assert.ok(model.gabi.replique.action.route);
    model = M.jusquAuMatch(jeu, model);
    assert.ok(model.gabi.replique.texte.length > 10);
    assert.deepEqual(model.gabi, jeu.call('snapshot').gabi, 'relecture identique');
  } finally { jeu.fermer(); }
});

test('Registre unique : Gabi tutoie le manager dans toutes ses répliques', () => {
  const m = base();
  m.squad[3].condition = 55; m.squad[1].injury = 2; m.squad[2].contractEnd = 1; m.selection.valid = false;
  m.calendarMail = [{ id: 'c1', status: 'pending', opponent: 'Les Ormes' }];
  m.clubLife.press.invitations = [{ id: 'i1', status: 'pending' }];
  for (const c of G.candidats(m)) assert.doesNotMatch(c.texte, /\b(vous|votre|vos)\b/i, c.cle);
});
