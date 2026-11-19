'use strict';
// Origine des blessures (native/engine/club-mail.cjs, installHooks ; demande de Léo, 18/11/2026) : l'origine (rencontre avec
// son id, entraînement, rechute) est enregistrée sur la blessure au moment où elle survient ; le bulletin du médecin la lit
// là, sans dépendre du journal du club. Tests déterministes : aucun hasard, états construits à la main.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory, DATA } = require('../native/engine/club-mail.cjs');

globalThis.nativeClubMailData = DATA;
const mail = factory();
const names = { 0: 'Toulouse', 7: 'Lyon', 32: 'Exeter Devon XV' };
const name = id => names[id] || '';
const D = '2026-10-19';

const joueur = (id, extra = {}) => ({ id, name: 'Joueur ' + id, pos: 'Ailier', injury: 0, ...extra });
const etat = (joueurs, news = []) => ({ season: 1, round: 8, club: 0, news, clubs: { 0: { players: joueurs } }, worldMode: { fixtures: [{ id: 'champions:2026:league:1:0:2', week: 8, date: '2026-10-18', homeId: 0, awayId: 32, competitionId: 'champions' }] } });
const match = (o = {}) => ({ type: 'match', fixtureId: 'champions:2026:league:1:0:2', opp: 32, oppName: 'Exeter Devon XV', home: true, us: 31, them: 38, date: '2026-10-18', ...o });

test('Le bulletin lit l’origine enregistrée sur la blessure, pas le journal', () => {
  // Journal trompeur (« à l’entraînement ») : l’origine enregistrée (rencontre) prime.
  const s = etat([joueur('a', { injury: 3, injuryOrigin: match() })], ['Joueur a s’est blessé à l’entraînement : indisponible 3 semaine(s).']);
  mail.blessures.typer(s, D);
  assert.equal(s.clubs[0].players[0].injuryCause, 'match');
  // Aucun journal du tout : la cause est quand même connue.
  const sans = etat([joueur('a', { injury: 2, injuryOrigin: { type: 'entrainement' } }), joueur('b', { injury: 2, injuryOrigin: match() })]);
  mail.blessures.typer(sans, D);
  assert.deepEqual(sans.clubs[0].players.map(p => p.injuryCause), ['entrainement', 'match']);
});

test('Rencontre : adversaire, lieu et score viennent de l’origine, même sans résultat archivé', () => {
  const p = { injuryOrigin: match(), injuryCause: 'match', injuryDate: D };
  assert.equal(mail.blessures.cause(p, [], name, D), 'Il est sorti touché à domicile contre Exeter Devon XV (31-38, le 18/10).');
  const dehors = { ...p, injuryOrigin: match({ home: false, us: 12, them: 9 }) };
  assert.equal(mail.blessures.cause(dehors, [], name, D), 'Il est sorti touché sur le terrain de Exeter Devon XV (12-9, le 18/10).');
});

test('Rencontre de coupe d’Europe : l’origine prime sur le dernier résultat archivé', () => {
  // Un match de championnat est archivé le lendemain : l’ancienne recherche (dernier résultat ≤ date) le choisissait.
  const resultats = [{ date: '2026-10-19', fixtureId: 'elite:2026:league:6:5', opp: 7, home: false, us: 20, them: 20 }];
  const p = { injuryOrigin: match(), injuryCause: 'match', injuryDate: D };
  assert.match(mail.blessures.cause(p, resultats, name, D), /Exeter Devon XV \(31-38/);
  assert.doesNotMatch(mail.blessures.cause(p, resultats, name, D), /Lyon/);
});

test('Terrain neutre : ni « à domicile » ni « sur le terrain de »', () => {
  const p = { injuryOrigin: match({ neutral: true }), injuryCause: 'match', injuryDate: D };
  assert.equal(mail.blessures.cause(p, [], name, D), 'Il est sorti touché contre Exeter Devon XV (31-38, le 18/10).');
});

test('Club hors base : le nom gardé à la blessure remplace « l’adversaire »', () => {
  const inconnu = { injuryOrigin: match({ opp: 'hors-base:12', oppName: 'Benetton Trévise' }), injuryCause: 'match', injuryDate: D };
  assert.match(mail.blessures.cause(inconnu, [], name, D), /à domicile contre Benetton Trévise \(31-38/);
  // Ni identifiant connu ni nom gardé : le résultat archivé de la même rencontre nomme l’adversaire.
  const archive = [{ date: '2026-10-18', fixtureId: 'champions:2026:league:1:0:2', opp: 7, home: true, us: 31, them: 38 }];
  const sansNom = { injuryOrigin: match({ opp: 'hors-base:12', oppName: null }), injuryCause: 'match', injuryDate: D };
  assert.match(mail.blessures.cause(sansNom, archive, name, D), /contre Lyon \(31-38/);
  // Rien de nommable : seulement alors la formule générique.
  assert.match(mail.blessures.cause(sansNom, [], name, D), /contre l'adversaire \(31-38/);
});

test('Anciennes sauvegardes : sans origine enregistrée, le journal et le dernier résultat servent encore', () => {
  const p = { injuryCause: 'match', injuryDate: D };
  const resultats = [{ date: '2026-10-18', opp: 32, home: false, us: 5, them: 6 }];
  assert.match(mail.blessures.cause(p, resultats, name, D), /sur le terrain de Exeter Devon XV \(5-6/);
  assert.equal(mail.blessures.cause({ injuryCause: 'rechute', injuryDate: D }, [], name, D), "Il a rechuté à l'entraînement, le 19/10, à son retour de blessure.");
});

test('Rechute : origine posée à la rechute ; guérison : origine effacée', () => {
  const s = etat([joueur('a', { injury: 1, injuryType: 'ischios', injuryDate: '2026-10-01', injuryOrigin: match() })]);
  s.clubs[0].players[0].injury = 0;
  mail.blessures.typer(s, D);
  const p = s.clubs[0].players[0];
  assert.equal(p.injuryOrigin, undefined);
  assert.equal(p.injuryCause, undefined);
});

test('Crochets : entraînement et rencontre enregistrés sur la blessure qui survient (seulement les nouvelles, seulement le club géré)', () => {
  const g = globalThis;
  const avant = { S: g.S, trainWeek: g.trainWeek, applyMatchInjuries: g.applyMatchInjuries };
  try {
    g.S = etat([joueur('sain'), joueur('deja', { injury: 2 }), joueur('autre')]);
    g.S.clubs[32] = { name: 'Exeter Devon XV', players: [joueur('adverse')] };
    g.trainWeek = function () { if (g.S.trained) return; g.S.trained = true; const [sain, , autre] = g.S.clubs[0].players; sain.injury = 2; autre.injury = 0; g.S.clubs[32].players[0].injury = 1; };
    g.applyMatchInjuries = function (l) { if (l.injuriesApplied) return; l.injuriesApplied = true; g.S.clubs[0].players[2].injury = 3; g.S.clubs[0].players[1].injury = 5; g.S.clubs[32].players[0].injury = 2; };
    mail.installHooks();
    mail.installHooks(); // idempotent : un seul enrobage
    g.trainWeek();
    const [sain, deja, autre] = g.S.clubs[0].players;
    assert.equal(sain.injuryOrigin.type, 'entrainement');
    assert.equal(deja.injuryOrigin, undefined, 'blessé avant : origine inchangée');
    assert.equal(g.S.clubs[32].players[0].injuryOrigin, undefined, 'club adverse non suivi');
    const live = { pair: [0, 32], score: [31, 38], finished: true };
    g.applyMatchInjuries(live);
    assert.deepEqual({ ...autre.injuryOrigin }, match({ date: '2026-10-18', season: 1, round: 8, neutral: false }));
    assert.equal(deja.injuryOrigin, undefined, 'déjà blessé avant le match : origine inchangée');
    assert.equal(g.S.clubs[32].players[0].injuryOrigin, undefined);
    // Un match déjà traité n’enregistre rien de plus.
    const depuis = JSON.stringify(g.S.clubs[0].players);
    g.applyMatchInjuries(live);
    assert.equal(JSON.stringify(g.S.clubs[0].players), depuis);
    // Match à l’extérieur : lieu et score pris du côté du club géré.
    g.S.clubs[0].players[0].injury = 0; delete g.S.clubs[0].players[0].injuryOrigin;
    g.S.worldMode.fixtures.push({ id: 'elite:2026:league:7:5', week: 8, date: '2026-10-19', homeId: 7, awayId: 0 });
    g.applyMatchInjuries = (function (orig) { return Object.assign(function (l) { if (l.injuriesApplied) return; l.injuriesApplied = true; g.S.clubs[0].players[0].injury = 1; }, orig); })(g.applyMatchInjuries);
    // L’enrobage d’origine n’est plus en place sur la fonction remplacée : on en pose un neuf.
    g.applyMatchInjuries.__injuryOrigin = false;
    mail.installHooks();
    g.S.clubs[7] = { name: 'Lyon', players: [] };
    g.applyMatchInjuries({ pair: [7, 0], score: [10, 14], finished: true });
    assert.deepEqual({ ...g.S.clubs[0].players[0].injuryOrigin }, { type: 'match', fixtureId: 'elite:2026:league:7:5', opp: 7, oppName: 'Lyon', home: false, neutral: false, us: 14, them: 10, date: '2026-10-19', season: 1, round: 8 });
  } finally {
    for (const [k, v] of Object.entries(avant)) { if (v === undefined) delete g[k]; else g[k] = v; }
  }
});

test('Validation : origine invalide refusée', () => {
  const base = () => ({ ...etat([joueur('a', { injury: 1, injuryType: 'ischios', injuryOrigin: match() })]), clubMail: { version: 1, seq: 0, last: null, mails: [], sent: {}, suites: [], memo: { injured: [], squad: [], arrivals: {}, apps: {}, missions: [], pools: [], calendar: [], lastF: {}, lastType: {}, cartons: 0 } } });
  const ok = base();
  const check = s => { try { return mail.validate(s) === true; } catch (e) { assert.match(String(e.message), /origine de blessure invalide/); return false; } };
  assert.equal(check(ok), true);
  const mauvais = base(); mauvais.clubs[0].players[0].injuryOrigin = { type: 'inconnu' };
  assert.equal(check(mauvais), false);
});
