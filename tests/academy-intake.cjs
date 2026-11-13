'use strict';
// Nouvelle génération du 1er juillet (politique 3 : Crabos 16-17 ans, Espoirs 18-21 ans).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const vm = require('node:vm');
const academyGroups = require('../native/engine/academy-groups.cjs');
const intakeDomain = require('../native/engine/academy-intake.cjs');

const POS = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne', 'Troisième ligne', 'Troisième ligne', 'Numéro 8',
  'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière'];
const FAMILIES = [0, 1, 0, 2, 2, 3, 3, 3, 4, 5, 6, 7, 7, 6, 8];

function world(seed = 0) {
  const clubs = Array.from({ length: 4 }, (_, id) => ({ id, name: `Club ${id}`, players: [] }));
  const S = {
    academyGroupPolicy: 3, club: 0, season: 1, phase: 'league', round: 0, aiRosterVersion: 2,
    clubs, aiRoster: { version: 2, academies: [1, 2, 3].map(clubId => ({ clubId, players: [] })) },
    market: [], economy: { freeAgents: [] }, development: { academy: [], retired: [] },
  };
  const notes = [];
  const context = vm.createContext({
    POS, FAMILIES, S, news: text => notes.push(text),
    academyPlayer: (club, slot, season, index) => {
      const h = (club * 7919 + season * 104729 + index * 31 + slot + seed) % 1000;
      const rating = 45 + h % 15;
      return { id: `youth-${club}-${season}-${index}`, name: `Jeune ${index}`, pos: POS[slot], fam: FAMILIES[slot], age: 17,
        academy: true, rating, dev: { potential: Math.min(99, rating + 10 + h % 25) } };
    },
  });
  const groups = vm.runInContext(`(${academyGroups.toString()})()`, context);
  context.CDNativeAcademyGroups = groups;
  return { S, groups, notes, context };
}
const plain = x => JSON.parse(JSON.stringify(x));
const age = (s, n) => { s.season += 1; for (const p of s.development.academy) p.age += n; for (const c of s.aiRoster.academies) for (const p of c.players) p.age += n; };

test('Départ : deux joueurs par poste en Crabos (16-17) et en Espoirs (18-21), sans génération la première saison', () => {
  const { S, groups } = world();
  groups.start(S);
  for (const players of [S.development.academy, ...S.aiRoster.academies.map(c => c.players)]) {
    assert.equal(players.filter(p => p.age >= 16 && p.age <= 17).length, 30);
    assert.equal(players.filter(p => p.age >= 18 && p.age <= 21).length, 30);
  }
  assert.equal(S.academyIntake, undefined);
  assert.equal(groups.intakeProject(S), null);
});

test('Intersaison : 12 à 20 jeunes de 16 ans proposés, les centres IA choisissent seuls sous le plafond Crabos', () => {
  const { S, groups, notes } = world();
  groups.start(S);
  age(S, 1);
  groups.afterSeason(S, 0);
  const intake = S.academyIntake;
  assert.equal(intake.season, 2);
  assert.ok(intake.players.length >= 12 && intake.players.length <= 29, String(intake.players.length));
  assert.ok(intake.players.every(p => p.age === 16 || (p.age === 15 && p.prodigy)));
  assert.ok(intake.players.every(p => !S.development.academy.some(q => q.id === p.id)));
  assert.match(notes.at(-1), /Nouvelle génération/);
  for (const center of S.aiRoster.academies) {
    const crabos = center.players.filter(p => p.age <= 17);
    assert.ok(crabos.length <= 35, String(crabos.length));
    assert.ok(center.players.some(p => p.age === 16 || p.age === 15));
    assert.ok(center.players.filter(p => p.age >= 18).length <= 36);
  }
  // Déterministe : la même saison produit la même proposition.
  const again = world();
  again.groups.start(again.S);
  age(again.S, 1);
  again.groups.afterSeason(again.S, 0);
  assert.deepEqual(plain(again.S.academyIntake.players.map(p => [p.id, p.pos, p.age])), plain(intake.players.map(p => [p.id, p.pos, p.age])));
  const projected = groups.intakeProject(S);
  assert.equal(projected.crabosCap, 35);
  assert.equal(projected.players.length, intake.players.length);
});

test('Choix du joueur : il faut libérer des Crabos avant de dépasser 35 places', () => {
  const { S, groups } = world();
  groups.start(S);
  age(S, 1);
  groups.afterSeason(S, 0);
  // Un centre déjà bien rempli en Crabos : la génération ne tient pas sans départs.
  const extra = S.development.academy.filter(p => p.age >= 18).slice(0, 15);
  for (const p of extra) p.age = 17;
  const crabos = S.development.academy.filter(p => p.age <= 17);
  const room = 35 - crabos.length;
  const ids = S.academyIntake.players.map(p => p.id);
  assert.ok(ids.length > room, 'la proposition dépasse les places libres');
  const before = JSON.stringify(S.development.academy);
  assert.throws(() => groups.confirmIntake(S, ids, []), /faire de la place/);
  assert.equal(JSON.stringify(S.development.academy), before);
  assert.throws(() => groups.confirmIntake(S, ['youth-9-9-9'], []), /génération/);
  const release = crabos.slice(0, ids.length - room).map(p => p.id);
  const result = groups.confirmIntake(S, ids, release);
  assert.deepEqual(plain(result), { kept: ids.length, released: release.length });
  assert.equal(S.development.academy.filter(p => p.age <= 17).length, 35);
  assert.ok(release.every(id => !S.development.academy.some(p => p.id === id)));
  assert.equal(S.academyIntake, undefined);
  assert.throws(() => groups.confirmIntake(S, [], []), /Aucune nouvelle génération/);
});

test('Sans décision, le responsable de la formation choisit à la première journée', () => {
  const { S, groups, context } = world();
  groups.start(S);
  age(S, 1);
  groups.afterSeason(S, 0);
  const size = S.development.academy.length;
  let rounds = 0;
  context.finishRound = () => { rounds++; };
  const domain = vm.runInContext(`(${intakeDomain.factory.toString()})()`, context);
  domain.installHooks();
  vm.runInContext('finishRound()', context);
  assert.equal(rounds, 1);
  assert.equal(S.academyIntake, undefined);
  const added = S.development.academy.length - size;
  assert.ok(added >= 1 && added <= 17, String(added));
  assert.ok(S.development.academy.filter(p => p.age <= 17).length <= 35);
  assert.equal(domain.project().available, false);
  // Pronostic du responsable vers le 1er avril.
  S.round = 34;
  vm.runInContext('finishRound()', context);
  assert.equal(S.academyIntakeForecast, S.season);
});

test('Commande academy_intake_confirm : contexte vérifié et retour arrière en cas de refus', () => {
  const { S, groups, context } = world();
  groups.start(S);
  age(S, 1);
  groups.afterSeason(S, 0);
  const domain = vm.runInContext(`(${intakeDomain.factory.toString()})()`, context);
  const view = domain.project();
  assert.equal(view.available, true);
  const ctx = { season: 2, week: 0, club: 0 };
  assert.deepEqual(plain(view.context), ctx);
  const ids = S.academyIntake.players.map(p => p.id);
  for (const p of S.development.academy.filter(p => p.age >= 18).slice(0, 15)) p.age = 17;
  assert.throws(() => domain.execute('academy_intake_confirm', { context: { ...ctx, week: 1 }, confirmed: true, keep: [], release: [] }), /périmé/);
  const before = JSON.stringify({ a: S.development.academy, i: S.academyIntake });
  assert.throws(() => domain.execute('academy_intake_confirm', { context: ctx, confirmed: true, keep: ids, release: [] }), /place/);
  assert.equal(JSON.stringify({ a: S.development.academy, i: S.academyIntake }), before);
  const kept = ids.slice(0, 3);
  assert.deepEqual(plain(domain.execute('academy_intake_confirm', { context: ctx, confirmed: true, keep: kept, release: [] }).academyIntake), { kept: 3, released: 0 });
  assert.ok(kept.every(id => S.development.academy.some(p => p.id === id)));
  groups.validate(S);
});

test('Sur vingt saisons, les centres gardent des Crabos à chaque poste sans dépasser leurs plafonds', () => {
  const { S, groups } = world(17);
  groups.start(S);
  for (let season = 2; season <= 21; season++) {
    age(S, 1);
    for (const c of [S.development, ...S.aiRoster.academies]) {
      const list = c.academy ?? c.players, keep = list.filter(p => p.age <= 21);
      list.splice(0, list.length, ...keep);
    }
    groups.afterSeason(S, 0);
    groups.settleIntake(S);
    for (const players of [S.development.academy, ...S.aiRoster.academies.map(c => c.players)]) {
      const crabos = players.filter(p => p.age <= 17);
      assert.ok(crabos.length <= 35 && players.length <= 75, `${season}: ${crabos.length}/${players.length}`);
      const families = new Set(crabos.map(p => FAMILIES[POS.indexOf(p.pos)]));
      assert.equal(families.size, 9, `saison ${season} : familles ${[...families]}`);
    }
  }
});

test('Rapport mensuel du responsable : progrès, jeunes au niveau pro, blessures longues', () => {
  const { S, groups, notes, context } = world();
  groups.start(S);
  S.clubs[0].players = [{ id: 'pro-1', fam: 4, rating: 60 }, { id: 'pro-2', fam: 4, rating: 75 }];
  const domain = vm.runInContext(`(${intakeDomain.factory.toString()})()`, context);
  S.round = 3;
  assert.equal(domain.report(S), false);
  S.round = 4;
  assert.equal(domain.report(S), true);
  assert.equal(S.academyReport.week, 4);
  const espoir = S.development.academy.find(p => p.age >= 18 && p.fam === 4);
  const crabe = S.development.academy.find(p => p.age <= 17 && p.fam !== 4);
  espoir.rating = 59; espoir.injury = 0;
  crabe.rating += 3; crabe.injury = 6;
  S.round = 8;
  assert.equal(domain.report(S), true);
  const text = notes.at(-1);
  assert.match(text, /^Rapport du responsable de la formation/);
  assert.ok(text.includes(`${crabe.name} (+3)`), text);
  assert.ok(text.includes(espoir.name), text);
  assert.match(text, /blessés longue durée/);
  assert.equal(domain.report(S), false, 'un seul rapport par semaine');
  domain.validate(S);
  S.academyReport.week = 0;
  assert.throws(() => domain.validate(S), /rapport/);
});
