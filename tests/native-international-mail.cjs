'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const createNativeInternational = require('../native/engine/international-native.cjs');

const player = { id: 'lnr:hook', name: 'Joueur de référence', pos: 'Talonneur', fam: 1, age: 29, rating: 85, condition: 100, injury: 0,
 primaryPosition: 2, primaryPositions: [2], secondaryPositions: [], positionRatings: {2:85}, qualifiedFrontRowPositions: [2] };
const facts = { nations: { FRA: ['France', 'fr'] }, players: { [player.id]: { seniorNation: 'FRA', seniorCaps: 5 } } };
const dateAfter = date => new Date(Date.parse(date) + 86400000).toISOString().slice(0, 10);

function bridge({ date = '2027-01-30', opening = '2027-08-16', phase = 'league', profile, players = [player], facts: known = facts } = {}) {
 const ctx = vm.createContext({
  S: { club: 0, clubs: [{ id: 0, players }], phase, worldMode: { day: 0 }, ...(profile ? { national: profile } : {}) },
  CDWorldCareer: { active: () => true, calendarToday: () => date, nextOpening: () => opening },
  roleNote: p => p.rating,
  // This mail unit fixture supplies the same published position contract as
  // the full worker; aptitude calculations have their own engine suites.
  nativePositionAptitudes: { project: p => Object.fromEntries(['primaryPosition','primaryPositions','secondaryPositions','positionRatings','qualifiedFrontRowPositions'].map(key=>[key,p[key]])) },
 });
 const international = createNativeInternational(source => vm.runInContext(source, ctx), ctx, known, true);
 international.initialize(42, { nationalRole: 'dual', nation: 'FRA' });
 return {
  read: international.read,
  advance() {
   international.advance(international.read().career.date);
   if (phase !== 'ended') date = dateAfter(date);
  },
  project() {
   const model = { club: { id: 0 }, meta: { calendarToday: date, canAdvanceSeason: phase === 'ended' } };
   international.project(model);
   return model;
  },
  play(fixture) { international.command('national_play_match', { fromDate: fixture.date, fixtureId: fixture.id }); },
  checkSeason: international.checkSeason,
 };
}

test('a new profile starting on the camp opening day immediately gets the call-up mail', () => {
 const date = '2027-01-31';
 const fresh = bridge({ date });
 const profile = fresh.read();
 assert.ok(profile.career.callups.some(camp => camp.nation === 'FRA' && camp.from === date));
 assert.equal(profile.mail.filter(mail => mail.nation === 'FRA' && mail.kind === 'international_callup').length, 1);
 assert.equal(profile.mail.filter(mail => mail.nation === 'FRA' && mail.kind === 'international_release').length, 1);
 assert.deepEqual(bridge({ date, profile }).read(), profile);
});

test('international mail explains the camp and records the club return exactly once after reloading', () => {
 const initial = bridge();
 initial.advance();
 const released = initial.read().mail.find(mail => mail.kind === 'international_release');
 assert.equal(released.nation, 'FRA');
 assert.equal(released.action, 'international');
 assert.match(released.body, /Tournoi des Six Nations 2027/);
 assert.match(released.body, /31 janvier 2027/);
 assert.match(released.body, /février 2027/);
 const camp = initial.read().mail.find(mail => mail.kind === 'international_callup');
 assert.match(camp.body, /30 joueurs/);
 assert.equal(camp.date, released.date);

 while (initial.read().career.date < '2027-02-06') initial.advance();
 const first = initial.project().international.currentManagedFixture;
 assert.equal(first.date, '2027-02-06');
 const before = initial.read();
 assert.throws(() => initial.advance(), /Joue ton match international/);
 assert.deepEqual(initial.read(), before);
 initial.play(first);
 assert.equal(initial.read().mail.filter(mail => mail.kind === 'international_result').length, 1);

 const saved = JSON.parse(JSON.stringify(initial.read()));
 const reopened = bridge({ date: saved.career.date, profile: saved });
 assert.deepEqual(reopened.read(), saved);
 while (reopened.read().career.date < '2027-02-26') {
  const fixture = reopened.project().international.currentManagedFixture;
  if (fixture) reopened.play(fixture);
  reopened.advance();
 }
 const returns = reopened.project().international.mail.filter(mail => mail.kind === 'international_return');
 assert.equal(returns.length, 1);
 assert.equal(returns[0].nation, 'FRA');
 assert.equal(returns[0].action, 'international');
 assert.equal(returns[0].title, 'Retour des internationaux : 1 joueur');
 assert.deepEqual(returns[0].players, [player.id], 'lien vers la fiche du joueur');
 assert.match(returns[0].body, /Tournoi des Six Nations 2027/);
 const afterReturn = JSON.parse(JSON.stringify(reopened.read()));
 const again = bridge({ date: afterReturn.career.date, profile: afterReturn });
 assert.deepEqual(again.project().international.mail.filter(mail => mail.kind === 'international_return'), returns);
 again.advance();
 assert.deepEqual(again.project().international.mail.filter(mail => mail.kind === 'international_return'), returns);
});

test('a closed club season retains the international date at the next opening after 2027', () => {
 const initial = bridge({ date: '2028-07-16', opening: '2028-07-18', phase: 'ended' });
 assert.throws(() => initial.checkSeason(), /Termine les journées/);
 initial.advance();
 assert.equal(initial.project().meta.calendarToday, '2028-07-17');
 assert.equal(initial.project().meta.canAdvanceSeason, false);
 initial.advance();
 const atOpening = initial.project();
 assert.equal(atOpening.meta.calendarToday, '2028-07-18');
 assert.equal(atOpening.meta.canAdvanceSeason, true);
 assert.equal(atOpening.meta.calendarCadence.canAdvance, false);
 assert.doesNotThrow(() => initial.checkSeason());
 const saved = initial.read();
 const reopened = bridge({ date: '2028-07-16', opening: '2028-07-18', phase: 'ended', profile: saved });
 assert.deepEqual(reopened.read(), saved);
 assert.equal(reopened.project().meta.calendarToday, '2028-07-18');
 assert.throws(() => reopened.advance(), /Commence la saison suivante/);
});

// Bug du 19/11/2026 : le courrier annonçait une fin de mise à disposition (13 septembre) différente de la fenêtre
// affichée par l'écran Sélections (20 septembre, retour le 21). La date du courrier suit la fenêtre stockée.
test('the call-up mail ends on the same day as the camp window shown in Selections', () => {
 const fijian = { ...player, id: 'fru:hook', name: 'Talonneur fidjien' };
 const known = { nations: { FRA: ['France', 'fr'], FIJ: ['Fidji', 'fj'] }, players: { [fijian.id]: { seniorNation: 'FIJ', seniorCaps: 9 } } };
 const career = bridge({ date: '2026-09-06', opening: '2027-08-16', phase: 'league', players: [fijian], facts: known });
 const french = date => new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(date));
 while (career.read().career.date < '2026-09-22') {
  const fixture = career.project().international.currentManagedFixture;
  if (fixture) career.play(fixture);
  career.advance();
 }
 const profile = career.read();
 const camp = profile.career.callups.find(row => row.nation === 'FIJ' && row.competitionId.startsWith('pacific-nations-cup'));
 assert.equal(camp.through, '2026-09-20', 'fenêtre affichée : jusqu’au 20 septembre, retour le 21');
 const release = profile.mail.find(mail => mail.kind === 'international_release');
 assert.ok(release, 'courrier de convocation du club');
 assert.match(release.body, new RegExp(`au ${french(camp.through)} inclus`));
 assert.doesNotMatch(release.body, /13 septembre/);
});
// Décision de Léo (16/11/2026) : un seul courrier par vague de convocations, toutes sélections confondues.
test('one call-up wave with several nations produces a single club mail listing every player', () => {
 const english = { ...player, id: 'rfu:hook', name: 'Talonneur anglais' };
 const both = { nations: { FRA: ['France', 'fr'], ENG: ['Angleterre', 'gb'] },
  players: { [player.id]: { seniorNation: 'FRA', seniorCaps: 5 }, [english.id]: { seniorNation: 'ENG', seniorCaps: 7 } } };
 const career = bridge({ players: [player, english], facts: both });
 career.advance();
 const released = career.read().mail.filter(mail => mail.kind === 'international_release');
 assert.equal(released.length, 1, JSON.stringify(released.map(mail => mail.title)));
 assert.equal(released[0].title, 'Convocations internationales : 2 joueurs');
 assert.deepEqual([...released[0].players].sort(), [english.id, player.id].sort());
 assert.match(released[0].body, /France \(Tournoi des Six Nations 2027\) : Joueur de référence/);
 assert.match(released[0].body, /Angleterre \(Tournoi des Six Nations 2027\) : Talonneur anglais/);
 assert.equal(released[0].nation, undefined, 'plusieurs sélections : pas de pays unique');
});

