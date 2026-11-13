'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { factory } = require('../native/engine/youth-national.cjs');

const positions = [[0, 'Pilier gauche'], [1, 'Talonneur'], [0, 'Pilier droit'], [2, 'Deuxième ligne'], [2, 'Deuxième ligne'],
  [3, 'Troisième ligne'], [3, 'Troisième ligne'], [3, 'Numéro 8'], [4, 'Demi de mêlée'], [5, 'Demi d’ouverture'],
  [6, 'Ailier'], [7, 'Centre'], [7, 'Centre'], [6, 'Ailier'], [8, 'Arrière']];

function world() {
  const clubs = [];
  ['FRA', 'ENG', 'IRE', 'NZL', 'JPN', 'GEO'].forEach((nation, c) => {
    const players = [];
    for (let i = 0; i < 60; i++) {
      const [fam, pos] = positions[i % 15];
      players.push({ id: `youth-${c}-1-${i}`, name: nation + ' ' + i, fam, pos, age: 16 + (i % 4), rating: 50 + (i * 7 + c) % 18,
        injury: 0, youthNation: nation });
    }
    clubs.push({ id: c, players });
  });
  return { season: 1, round: 0, club: 0, clubs, development: { academy: [] }, aiRoster: { academies: [] }, seed: 11 };
}

test('calendrier : U20 ~10 et U18 ~6 matchs par nation et par saison, vraies compétitions comprises', () => {
  const yn = factory();
  for (let season = 1; season <= 20; season++) {
    const fixtures = yn.seasonCalendar(season);
    const count = cat => {
      const n = new Map(yn.NATIONS.map(id => [id, 0]));
      for (const f of fixtures.filter(f => f.cat === cat)) {
        if (f.home) { n.set(f.home, n.get(f.home) + 1); n.set(f.away, n.get(f.away) + 1); }
      }
      return n;
    };
    const u20 = count('U20'), u18 = count('U18');
    // Les phases finales (sans équipes connues d'avance) ajoutent 1 à 2 matchs aux équipes concernées.
    for (const [id, n] of u20) assert.ok(n >= 6 && n <= 10, season + ' U20 ' + id + ' ' + n);
    for (const [id, n] of u18) assert.ok(n >= 5 && n <= 6, season + ' U18 ' + id + ' ' + n);
    const year = 2025 + season;
    assert.equal(fixtures.filter(f => f.comp === 'u20-six-nations-' + (year + 1)).length, 15);
    assert.equal(fixtures.filter(f => f.comp === 'u20-world-championship-' + (year + 1)).length, 40);
    assert.equal(fixtures.filter(f => f.comp === 'u20-rugby-championship-' + (year + 1)).length, 6);
    assert.equal(fixtures.filter(f => f.comp === 'u18-six-nations-festival-' + (year + 1)).length, 12);
    assert.ok(fixtures.every(f => f.date >= year + '-08-01' && f.date < (year + 1) + '-08-01'));
  }
});

test('saison simulée : convocations par âge et nation, compteur par joueur, montée et descente', () => {
  const yn = factory();
  const s = world();
  globalThis.S = s;
  try {
    yn.initialize(s);
    assert.equal(yn.playUntil(s, '2026-12-31') > 0, true);
    yn.closeSeason(s);
    assert.equal(yn.validate(s), true);
    const played = Object.values(s.youthNational.played[1]);
    assert.ok(played.length >= 180, String(played.length));
    const pool = s.clubs.flatMap(c => c.players);
    const fra = pool.filter(p => p.youthNation === 'FRA');
    const u20 = fra.filter(p => p.age >= 18).sort((a, b) => b.rating - a.rating)[0];
    assert.ok(yn.matches(s, u20.id) >= 8, String(yn.matches(s, u20.id)));
    assert.ok(yn.matches(s, u20.id) <= 16);
    assert.equal(yn.nation(s, u20.id), 'FRA');
    assert.equal(yn.dates(s, u20.id).length, yn.matches(s, u20.id));
    assert.ok(yn.dates(s, u20.id).every(d => d >= '2026-08-01' && d < '2027-08-01'));
    const u18 = fra.filter(p => p.age <= 17).sort((a, b) => b.rating - a.rating)[0];
    assert.ok(yn.matches(s, u18.id) >= 4);
    assert.equal(yn.matches(s, 'inconnu'), 0);
    assert.equal(yn.matches(s, u20.id, 2), 0);
    // Personne ne joue pour deux nations ; aucun joueur hors limite d'âge.
    for (const p of pool) {
      const n = yn.nation(s, p.id);
      if (n) assert.equal(n, p.youthNation);
      if (p.age > 19) assert.equal(yn.matches(s, p.id), 0);
    }
    const entry = s.youthNational.history.at(-1);
    assert.ok(entry.relegated && entry.promoted && entry.u20 && entry.trophy);
    s.season = 2;
    yn.openSeason(s);
    assert.ok(s.youthNational.divisions.jwc.flat().includes(entry.promoted));
    assert.ok(s.youthNational.divisions.trophy.includes(entry.relegated));
    yn.closeSeason(s);
    assert.equal(yn.validate(JSON.parse(JSON.stringify(s))), true);
    assert.ok(Buffer.byteLength(JSON.stringify(s.youthNational)) < 200_000);
    // Rejouer est sans effet ; un état abîmé est refusé.
    const before = JSON.stringify(s.youthNational);
    assert.equal(yn.playUntil(s, '2028-07-31'), 0);
    assert.equal(JSON.stringify(s.youthNational), before);
    const broken = JSON.parse(JSON.stringify(s));
    broken.youthNational.divisions.trophy[0] = broken.youthNational.divisions.jwc[0][0];
    assert.throws(() => yn.validate(broken), /divisions/);
  } finally { delete globalThis.S; }
});

test('vingt saisons enchaînées sans dérive ni croissance de la sauvegarde', () => {
  const yn = factory();
  const s = world();
  globalThis.S = s;
  try {
    yn.initialize(s);
    for (let season = 1; season <= 20; season++) {
      s.season = season;
      if (season > 1) yn.openSeason(s);
      yn.closeSeason(s);
    }
    assert.equal(yn.validate(s), true);
    assert.equal(Object.keys(s.youthNational.played).length, 3);
    assert.equal(s.youthNational.history.length, 20);
    assert.ok(Buffer.byteLength(JSON.stringify(s.youthNational)) < 250_000);
    assert.equal(yn.project().available, true);
  } finally { delete globalThis.S; }
});
