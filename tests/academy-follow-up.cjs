'use strict';
// Suivi des jeunes sans les gérer : projection en lecture seule et alertes du fil d'actualités.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const vm = require('node:vm');
const domain = require('../native/engine/academy-follow-up.cjs');

function youth(n, age, rating, potential, extra = {}) {
  return { id: `youth-0-1-${n}`, name: `Jeune ${n}`, pos: 'Centre', fam: 7, age, rating, condition: 100, injury: 0, academy: true,
    dev: { potential, seasonStart: rating - 2, minutes: 120, appearances: 2 }, ...extra };
}
function world({ france = true } = {}) {
  const notes = [];
  const S = {
    academyGroupPolicy: 3, club: 0, season: 2, phase: 'league', round: 1, live: null,
    franceMode: france ? { week: 1 } : undefined,
    clubs: [{ id: 0, name: 'Club', players: [] }],
    development: { academy: [
      youth(1, 16, 50, 70), youth(2, 17, 55, 88), youth(3, 18, 60, 75, { injury: 5 }), youth(4, 21, 66, 72), youth(5, 19, 62, 74),
      youth(6, 15, 58, 92, { prodigy: true }),
    ] },
    v78to81: { contracts: [{ id: 'youth-0-1-5', name: 'Jeune 5', season: 1, expires: 2, stipend: 0, fee: 0 }, { id: 'youth-0-1-3', name: 'Jeune 3', season: 2, expires: 3, stipend: 0, fee: 0 }] },
    v73Espoirs: { minutes: { 'youth-0-1-3': 240 } },
    academyReport: { season: 2, week: 4, ratings: { 'youth-0-1-1': 47 } },
    jiff: { version: 1 },
  };
  const statuses = { 'youth-0-1-4': [1, 3, 0], 'youth-0-1-5': [0, 2, 0] };
  const context = vm.createContext({ S, news: text => notes.push(text), CDJiff: { getStatus: (s, pid) => statuses[pid] || null } });
  context.finishRound = function () { S.round++; if (S.franceMode) S.franceMode.week++; return 'ok'; };
  const api = vm.runInContext(`(${domain.factory.toString()})()`, context);
  return { S, api, notes, context };
}
const plain = x => JSON.parse(JSON.stringify(x));

test('Projection : effectifs Crabos/Espoirs, niveau, progression, temps de jeu, blessures, contrats et JIFF', () => {
  (() => {
    const { S, api } = world();
    const view = plain(api.project());
    assert.equal(view.available, true);
    assert.deepEqual(view.crabos, { count: 3, cap: 35 });
    assert.deepEqual(view.espoirs, { count: 3 });
    assert.equal(view.capacity, 75);
    assert.equal(view.players[0].group, 'crabos');
    assert.equal(view.players.at(-1).group, 'espoirs');
    const one = view.players.find(p => p.id === 'youth-0-1-1');
    assert.deepEqual(one.progression, { season: 2, month: 3 });
    assert.equal(one.rating, 50);
    assert.equal(one.potential, 70, 'le potentiel exact est masqué ensuite par la frontière de connaissance');
    const hurt = view.players.find(p => p.id === 'youth-0-1-3');
    assert.equal(hurt.injury, 5);
    assert.equal(hurt.juniorMinutes, 240);
    assert.equal(hurt.contractEnd, 3);
    assert.equal(view.players.find(p => p.id === 'youth-0-1-5').contractEnd, 2);
    assert.equal(view.players.find(p => p.id === 'youth-0-1-4').lastSeason, true);
    assert.deepEqual(view.players.find(p => p.id === 'youth-0-1-4').jiff, { status: true, centreSeasons: 3 });
    assert.equal(view.players.find(p => p.id === 'youth-0-1-2').crack, true);
    assert.equal(view.players.find(p => p.id === 'youth-0-1-6').crack, true);
    assert.equal(view.summary.injured, 1);
    assert.equal(view.summary.cracks, 2);
    assert.equal(view.summary.ending, 2);
    assert.equal(view.summary.jiff, 1);
    assert.equal(view.summary.lastReport, 4);
    // Sans le chantier des compétitions de jeunes : emplacement vide, rien d'inventé.
    assert.deepEqual(view.competitions, { available: false });
    assert.equal(view.matchCap.connected, false);
    assert.ok(view.players.every(p => p.matchCap === null));
    S.academyGroupPolicy = 2;
    assert.deepEqual(plain(api.project()), { available: false });
  })();
});

test('Alertes : crack une seule fois, fin de contrat une fois par saison, rien pendant un match', () => {
  (() => {
    const { S, api, notes } = world();
    S.live = { minute: 10 };
    assert.equal(api.alerts(S).length, 0);
    S.live = null;
    const first = api.alerts(S);
    assert.equal(first.length, 1);
    assert.match(first[0], /2 cracks/);
    assert.match(first[0], /Jeune 2/);
    assert.match(first[0], /Jeune 6/);
    assert.doesNotMatch(first[0], /\d{2,}\s*\/|potentiel \d/, 'aucun chiffre de potentiel révélé');
    assert.equal(api.alerts(S).length, 0, 'pas de répétition');
    S.development.academy.push(youth(7, 16, 52, 90));
    assert.match(api.alerts(S)[0], /un crack : Jeune 7/);
    S.franceMode.week = 20;
    const ending = api.alerts(S);
    assert.equal(ending.length, 1);
    assert.match(ending[0], /contrat Espoir qui se termine en fin de saison : Jeune 5/);
    assert.match(ending[0], /dernière saison au centre : Jeune 4/);
    assert.equal(api.alerts(S).length, 0);
    S.season = 3; S.franceMode.week = 25;
    for (const p of S.development.academy) p.age++;
    const next = api.alerts(S);
    assert.match(next.join(' '), /Jeune 3/, 'nouvelle saison, nouvelle annonce');
    assert.equal(notes.length, 4);
    // Les jeunes partis sont oubliés.
    S.development.academy = S.development.academy.filter(p => p.id !== 'youth-0-1-2');
    api.alerts(S);
    assert.ok(!S.academyFollowUp.cracks.includes('youth-0-1-2'));
    api.validate(S);
  })();
});

test('Monde : la fin de contrat attend la 30e semaine', () => {
  (() => {
    const { S, api } = world({ france: false });
    S.worldMode = { week: 29 };
    api.alerts(S);
    assert.equal(S.academyFollowUp.contractSeason, 0);
    S.worldMode.week = 30;
    assert.match(api.alerts(S).join(' '), /Fin de contrat proche/);
  })();
});

test('Plafond de 30 matchs : branchement simple, alerte à 25 puis à 30', () => {
  (() => {
    const { S, api, notes } = world();
    api.alerts(S);
    const counts = { 'youth-0-1-3': 24 };
    assert.equal(api.connect({ appearances: (s, pid) => counts[pid] ?? null,
      summary: () => ({ competitions: [{ name: 'Espoirs Élite', standings: [{ club: 'Club', played: 4, points: 14 }] }] }) }), true);
    assert.equal(api.alerts(S).length, 0);
    counts['youth-0-1-3'] = 26;
    assert.match(api.alerts(S)[0], /Jeune 3 a disputé 26 matchs : il approche du plafond de 30/);
    counts['youth-0-1-3'] = 28;
    assert.equal(api.alerts(S).length, 0);
    counts['youth-0-1-3'] = 30;
    assert.match(api.alerts(S)[0], /Jeune 3 a atteint le plafond de 30 matchs/);
    assert.equal(api.alerts(S).length, 0);
    const view = plain(api.project());
    assert.deepEqual(view.players.find(p => p.id === 'youth-0-1-3').matchCap, { count: 30, limit: 30 });
    assert.equal(view.matchCap.connected, true);
    assert.equal(view.competitions.available, true);
    assert.equal(view.competitions.competitions[0].name, 'Espoirs Élite');
    assert.ok(notes.length >= 3);
    api.validate(S);
  })();
});

test('Accroche : les alertes suivent la fin de journée ; validation stricte de la sauvegarde', () => {
  (() => {
    const { S, api, notes, context } = world();
    api.installHooks();
    api.installHooks();
    assert.equal(context.finishRound(), 'ok');
    assert.equal(notes.length, 1);
    assert.equal(context.finishRound.__academyFollowUp, true);
    api.validate(S);
    const bad = [
      x => { x.extra = 1; }, x => { x.version = 2; }, x => { x.cracks.push(x.cracks[0]); }, x => { x.contractSeason = S.season + 1; },
      x => { x.caps.push('youth-0-1-3@12'); }, x => { x.cracks.push('<script>'); },
    ];
    for (const change of bad) {
      const saved = plain(S.academyFollowUp);
      change(S.academyFollowUp);
      assert.throws(() => api.validate(S), /Suivi du centre/);
      S.academyFollowUp = saved;
    }
    S.academyGroupPolicy = 2;
    assert.throws(() => api.validate(S), /Suivi du centre/);
    assert.throws(() => api.execute('x', {}), /aucune commande/);
  })();
});
