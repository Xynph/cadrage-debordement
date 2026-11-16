'use strict';
// Palmarès dès le jour 1 (native/engine/club-palmares.cjs) : fusion du palmarès connu
// (club-history.json) et des saisons archivées en carrière ; état vide propre ; carrière Monde.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const P = require('../native/engine/club-palmares.cjs');
const history = require('../native/engine/club-history.json');

test('Fusion : titres connus + titre de carrière, finales et rangs, tri déterministe', () => {
  const h = { founded: 1907, results: [{ competition: 'elite', titles: 25, year: 2026 }, { competition: 'champions', titles: 6, year: 2024 }, { competition: 'challenge', finish: 'final', year: 2019 }, { competition: 'accession', rank: 5, year: 2025 }] };
  const archives = { seasons: [{ season: 1, champions: [{ leagueId: 'elite', clubId: 7 }, { leagueId: 'accession', clubId: 8 }], standings: { elite: [8, 7], accession: [9, 8] }, finalists: { elite: 8 }, europe: { champions: { champion: 7 } } }] };
  const p = P.build({ history: h, archives, clubId: 7, clubName: 'Capitole XV' });
  assert.equal(p.vide, false);
  assert.deepEqual(p.titles.map(t => [t.competition, t.count, t.lastYear]), [['elite', 26, 2027], ['champions', 7, 2027]]);
  assert.equal(p.totalTitles, 33);
  assert.equal(p.headline, '33 titres au palmarès');
  assert.deepEqual(p.finals.map(f => [f.competition, f.year, f.finish]), [['challenge', 2019, 'final']]);
  assert.equal(p.recent[0].year, 2027);
  assert.equal(p.recent.find(r => r.competition === 'accession').text, '5e place');
  assert.equal(p.careerSeasons, 1);
  assert.equal(p.recent.at(-1).season, '2018-19');
  assert.deepEqual(P.build({ history: h, archives, clubId: 7, clubName: 'Capitole XV' }), p, 'déterministe');
  // Autre club : rang et finale de carrière, jamais le titre d'un autre.
  const q = P.build({ archives, clubId: 8 });
  assert.equal(q.totalTitles, 1);
  assert.ok(q.recent.some(r => r.kind === 'final' && r.competition === 'elite' && r.source === 'carriere'));
});

test('Club sans historique : état vide en langage de club, jamais « 0 »', () => {
  const p = P.build({ history: { results: [] }, archives: { seasons: [] }, clubId: 57, clubName: 'Les Écureuils' });
  assert.equal(p.vide, true);
  assert.equal(p.totalTitles, 0);
  assert.equal(p.headline, 'Palmarès vierge');
  assert.match(p.emptyText, /Les Écureuils/);
  assert.match(p.emptyText, /s’écrit avec vous/);
  assert.doesNotMatch(p.headline + p.emptyText, /\b0\b|archiv/i);
  assert.equal(P.build({ clubId: 3 }).vide, true, 'club absent du fichier');
});

test('Aucune prose du fichier d’historique n’est reprise (présentation à noms réels exclue)', () => {
  for (const [id, h] of Object.entries(history)) {
    const json = JSON.stringify(P.build({ history: h, clubId: Number(id), clubName: 'X' }));
    assert.ok(!json.includes(h.bio) && !json.includes('http'), 'club ' + id);
  }
});

test('Carrière Monde : un club connu a un palmarès dès le jour 1, un club sans historique un état vide propre', () => {
  const M = require('./helpers/carriere-monde.cjs');
  const jeu = M.ouvrir({ hebdomadaire: true });
  try {
    const model = M.creer(jeu, 0);
    assert.equal(model.archives.seasons.length, 0, 'aucune saison archivée au jour 1');
    const p = model.club.palmares;
    assert.equal(p.vide, false);
    assert.ok(p.totalTitles > 0 && p.titles.length > 0, 'titres connus au jour 1');
    assert.deepEqual(p.titles.map(t => [t.competition, t.count]), history[0].results.filter(r => r.titles).map(r => [r.competition, r.titles]).sort((a, b) => b[1] - a[1]));
    assert.equal(p.careerSeasons, 0);
    // Fiche d'un autre club connu et d'un club sans historique.
    const connu = jeu.brut('club_sheet', { club: 1 }).model.clubSheet.palmares;
    assert.equal(connu.vide, false);
    assert.ok(connu.finals.length + connu.titles.length > 0);
    const r = jeu.brut('club_sheet', { club: 57 });
    assert.equal(r.ok, true, r.error);
    const vide = r.model.clubSheet.palmares;
    assert.equal(vide.vide, true);
    assert.match(vide.emptyText, new RegExp(r.model.clubSheet.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  } finally { jeu.fermer(); }
});
