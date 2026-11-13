'use strict';
// Carrière Monde : classement fermé avant la 1re journée, abonnés de départ déterministes et sans effet sur les recettes.
const assert = require('node:assert/strict');
const { ouvrir, creer, jouer } = require('./helpers/carriere-monde.cjs');
const fan = require('../dist/fan-experience-v111-v116.js');

// Abonnés de départ : déterministes, bornés par la capacité, croissants avec la popularité du club.
const stade = base => ({ season: 1, club: 0, live: false, phase: 'league', clubs: [{ id: 0, abbr: 'XXX', base, stadiumCapacity: 12000, players: [] }] });
const petit = fan.ensure(stade(60)).subscribers, gros = fan.ensure(stade(86)).subscribers;
assert.ok(petit >= 0.22 * 12000 && petit <= 0.30 * 12000, 'petit club : environ 25 % de la capacité : ' + petit);
assert.ok(gros >= 0.72 * 12000 && gros <= 0.78 * 12000, 'gros club : environ 75 % de la capacité : ' + gros);
assert.equal(fan.ensure(stade(86)).subscribers, gros, 'déterministe');
const ancien = stade(86); ancien.v111to116 = { version: 1, season: 1, sentiment: 50, price: 'equilibree', subscribers: 0, campaign: null, service: null, community: [], ledger: [], history: [], commercialCash: 0 };
assert.equal(fan.ensure(ancien).subscribers, gros, 'sauvegarde antérieure jamais touchée : socle initial');
const avant = fan.forecast(stade(86)), apres = fan.forecast(ancien);
assert.deepEqual(avant, apres, 'les abonnés n’entrent dans aucune prévision de recette');

const jeu = ouvrir({ hebdomadaire: true });
try {
  let m = creer(jeu, 0);
  const fans = m.clubLife.clubStrategy.fans;
  assert.ok(fans.subscribers >= 0.22 * fans.capacity && fans.subscribers <= fans.capacity, 'Monde : abonnés initiaux ' + fans.subscribers);
  assert.equal(m.club.standingsOpen, false, 'avant la 1re journée : classement fermé');
  assert.ok(m.league.every(c => c.standingsOpen === false && c.played === 0), 'aucun match joué en division');
  const recette = fans.expectedTicketRevenue;
  m = jouer(jeu, m, 1);
  assert.equal(m.club.standingsOpen, true, 'après un match : classement ouvert');
  assert.equal(m.clubLife.clubStrategy.fans.expectedTicketRevenue, recette, 'recette prévue inchangée par les abonnés');
  console.log('Monde club0 : abonnés ' + fans.subscribers + ' / ' + fans.capacity + ', classement fermé puis ouvert PASS');
} finally { jeu.fermer(); }
