'use strict';
// Barème senior V2 (nouvelles carrières Monde) : notes et potentiels selon le niveau réel de chaque joueur,
// de son club et de son championnat (data/world/niveaux-v2.json, native/engine/world-rating-scale.json).
// Une carrière world-champ neuve : ordre des championnats, étagement des clubs, stars, potentiels,
// attributs, fournées du centre de formation et compatibilité des sauvegardes au barème V1.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const repo = path.resolve(__dirname, '..');
const { createBridge } = require(path.join(repo, 'native/engine/worker.cjs'));
const { createV2, levels } = require('./helpers/senior-calibration-v2.cjs');

const game = fs.readFileSync(path.join(repo, 'dist/game.js'), 'utf8');
const positions = game.split(/\r?\n/).filter(line => /^const (?:POS|FAMILIES)=/.test(line)).join('\n');
const sandbox = vm.createContext({ clamp: (x, a, b) => Math.max(a, Math.min(b, x)), focusedBonus: () => 0 });
vm.runInContext(positions + '\n' + fs.readFileSync(path.join(repo, 'dist/rugby.js'), 'utf8') + '\nthis.buildSheet=buildSheet;this.roleNote=roleNote;', sandbox);
const { buildSheet, roleNote } = sandbox;
const mean = list => list.reduce((sum, x) => sum + x, 0) / list.length;
const ELITE = ['elite', 'prem', 'urc', 'srp', 'jlo-d1'];

(function () {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-bareme-v2-'));
  let created, exported, model, preview;
  const bridge = createBridge({ dataDir: path.join(root, 'carriere'), seed: 20261114, now: 1794300000000 });
  let serial = 0;
  const ask = (command, payload = {}) => {
    const result = bridge.handle({ id: ++serial, command, payload });
    assert.equal(result.ok, true, command + ' : ' + result.error);
    return result.model;
  };
  try {
    preview = ask('snapshot').meta.champCatalogue;
    model = ask('new_career', { mode: 'world-champ', club: 0, varyCurrent: false });
    exported = ask('export').meta.exportText;
    created = JSON.parse(exported).state;
  } catch (error) {
    bridge.close();
    fs.rmSync(root, { recursive: true, force: true });
    throw error;
  }
  const leagueOf = new Map(Object.entries(created.worldMode.leagues).flatMap(([id, league]) => league.members.map(club => [club, id])));
  const league = clubId => leagueOf.get(clubId) || 'guest';
  const xv = club => {
    const { lineup } = buildSheet(club);
    const byId = new Map(club.players.map(p => [p.id, p]));
    return mean(lineup.map(id => byId.get(id)).filter(Boolean).map(p => p.rating));
  };
  const clubs = created.clubs.map(club => ({ id: club.id, league: league(club.id), xv: xv(club), players: club.players }));
  const byLeague = id => clubs.filter(club => club.league === id).sort((a, b) => b.xv - a.xv);
  const leagueXV = id => mean(byLeague(id).map(club => club.xv));
  const players = created.clubs.flatMap(club => club.players.map(p => ({ ...p, league: league(club.id) })));
  const table = levels().joueurs;

  test('Barème V2 : nouvelle carrière Monde marquée, sauvegarde relue à l’identique', () => {
    assert.equal(created.seniorCalibrationVersion, 2);
    // L'aperçu de création annonce les effectifs du barème V2.
    for (const id of [0, 13, 30, 40, 51, 61, 71, 103]) {
      const roster = created.clubs[id].players;
      assert.equal(preview[id].startingRoster.average, Math.round(10 * mean(roster.map(p => p.rating))) / 10, 'aperçu du club ' + id);
    }
    const reopened = ask('import', { text: exported });
    assert.equal(ask('export').meta.exportText, exported);
    assert.ok(reopened.squad.length > 0);
  });

  test('Ordre des championnats : Top 14 en tête, Championship et Nationale en bas', () => {
    const xvs = Object.fromEntries(['elite', 'prem', 'urc', 'srp', 'jlo-d1', 'accession', 'jlo-d2', 'nationale', 'champ'].map(id => [id, leagueXV(id)]));
    assert.ok(xvs.elite > xvs.prem && xvs.elite > xvs.urc && xvs.elite > xvs.srp, 'Top 14 au-dessus : ' + JSON.stringify(xvs));
    for (const id of ['prem', 'urc', 'srp']) assert.ok(xvs[id] > xvs['jlo-d1'] + 1, id + ' au-dessus du Japon D1');
    assert.ok(xvs['jlo-d1'] > xvs.accession && xvs.accession > xvs['jlo-d2'] && xvs['jlo-d2'] > xvs.nationale, 'Japon D1 > PRO D2 > Japon D2 > Nationale');
    assert.ok(xvs.champ < xvs['jlo-d2'] && Math.abs(xvs.nationale - xvs.champ) <= 4, 'Championship proche de la Nationale');
    assert.ok(xvs.elite >= 79 && xvs.elite <= 83, 'XV moyen du Top 14 ≈ 81 : ' + xvs.elite.toFixed(1));
    assert.ok(xvs.accession >= 71 && xvs.accession <= 75, 'XV moyen de PRO D2 ≈ 73 : ' + xvs.accession.toFixed(1));
  });

  test('Étagement des clubs : écarts réels dans chaque championnat d’élite, cadors devant', () => {
    for (const id of ELITE) {
      const list = byLeague(id);
      const gap = list[0].xv - list.at(-1).xv;
      assert.ok(gap >= 5 && gap <= 14, `${id} : écart meilleur/dernier XV ${gap.toFixed(1)} hors de [5 ; 14]`);
    }
    const etages = levels().clubs;
    for (const id of ELITE) {
      const list = byLeague(id), top = list.filter(c => etages[c.id] === 'cador'), low = list.filter(c => etages[c.id] === 'releguable');
      if (top.length && low.length) assert.ok(mean(top.map(c => c.xv)) > mean(low.map(c => c.xv)) + 3, id + ' : cadors au-dessus des relégables');
    }
    const elite = byLeague('elite'), urc = byLeague('urc');
    assert.equal(elite[0].id, 0, 'Club 0 (cador, le plus d’internationaux) en tête du Top 14');
    assert.ok(elite.slice(-3).some(c => c.id === 13), 'Club 13 (promu) dans le bas du Top 14');
    assert.equal(urc[0].id, 40, 'Club 40 en tête de l’URC');
    assert.ok(urc.slice(-4).some(c => c.id === 51), 'Club 51 dans le bas de l’URC');
    const accession = byLeague('accession');
    assert.ok(accession[0].xv >= elite.at(-1).xv - 4, 'Le haut de PRO D2 reste proche du bas du Top 14');
  });

  test('Stars : 85+ et 90+ en nombre réaliste, réparties, classe S toujours 90+', () => {
    const ge85 = players.filter(p => p.rating >= 85), ge90 = players.filter(p => p.rating >= 90);
    assert.ok(ge85.length >= 100 && ge85.length <= 200, '85+ : ' + ge85.length);
    assert.ok(ge90.length >= 12 && ge90.length <= 35, '90+ : ' + ge90.length);
    const share = Object.values(ge85.reduce((o, p) => (o[p.league] = (o[p.league] || 0) + 1, o), {}));
    assert.ok(Math.max(...share) <= ge85.length / 2, 'aucun championnat n’a la moitié des 85+');
    const classS = players.filter(p => table[p.id]?.[0] === 'S');
    assert.ok(classS.length >= 5 && classS.every(p => p.rating >= 90), 'classe S à 90+ quel que soit le club');
    const nonIntl = players.filter(p => !table[p.id] || table[p.id][0] === 'aucune');
    assert.ok(nonIntl.every(p => !['accession', 'nationale', 'champ', 'jlo-d2'].includes(p.league) || p.rating < 85), 'aucun 85+ non international hors élite');
  });

  test('Attributs : 36 qualités bornées qui suivent la note, note au poste alignée', () => {
    let aligned = 0, total = 0;
    for (const p of players) {
      if (!p.attributesV2) continue;
      assert.equal(Object.keys(p.attributesV2).length, 36, p.id);
      assert.ok(Object.values(p.attributesV2).every(v => Number.isInteger(v) && v >= 20 && v <= 97), p.id);
      assert.equal(p.dev.seasonStart, p.rating, p.id);
      total++;
      if (Math.abs(roleNote(p) - p.rating) <= 2) aligned++;
    }
    assert.ok(aligned / total >= 0.95, `note au poste alignée sur la note : ${aligned}/${total}`);
  });

  test('Potentiels : marge selon l’âge, peu de 90+ par génération, jeunes d’élite devant', () => {
    for (const p of players) assert.ok(p.dev.potential >= p.rating && p.dev.potential <= 99, p.id);
    const veterans = players.filter(p => p.age >= 31);
    assert.ok(mean(veterans.map(p => p.dev.potential - p.rating)) <= 1.5, 'potentiel ≈ note à 31 ans et plus');
    const young = players.filter(p => p.age <= 19);
    assert.ok(mean(young.map(p => p.dev.potential - p.rating)) >= 7, 'marge des 16-19 ans');
    const perAge = {};
    for (const p of players) if (p.age <= 25 && p.rating < 90 && p.dev.potential >= 90) perAge[p.age] = (perAge[p.age] || 0) + 1;
    assert.ok(Object.values(perAge).every(n => n <= 10), 'potentiels 90+ par génération : ' + JSON.stringify(perAge));
    const top14Young = players.filter(p => p.league === 'elite' && p.age <= 21);
    assert.ok(top14Young.filter(p => p.dev.potential >= 85).length <= 3 * 14, 'jeunes du Top 14 à 85+ : quelques-uns par club');
    for (const p of players.filter(p => p.age <= 21 && ['nationale', 'champ', 'jlo-d2', 'accession'].includes(p.league) && !table[p.id]?.[2])) {
      assert.ok(p.dev.potential <= 87 + 5, p.id + ' : potentiel hors élite sans U20');
    }
  });

  test('Centre de formation : jeunes recalés sur l’échelle du championnat', () => {
    const academies = [{ clubId: created.club, players: created.development.academy }, ...created.aiRoster.academies];
    // Potentiel affiché au poste (academyPotential) : note au poste + marge du potentiel général.
    const share = id => {
      const youth = academies.filter(a => league(a.clubId) === id).flatMap(a => a.players);
      return youth.filter(p => p.dev.potential - p.rating + roleNote(p) >= 85).length / youth.length;
    };
    assert.ok(share('elite') < 0.2, 'Top 14 : potentiels 85+ minoritaires au centre (' + share('elite').toFixed(3) + ')');
    assert.ok(share('nationale') < share('elite') && share('champ') < share('elite'), 'les centres modestes visent moins haut');
    const { calibration } = createV2();
    const club = created.clubs[0];
    const sample = { id: 'youth-0-1-70000', rating: 60, age: 16, fam: 3, pos: 'Deuxième ligne', skills: created.development.academy[0].skills, skillBase: 60 };
    const value = calibration.youthPotential(created, club, sample, 3);
    assert.ok(Number.isInteger(value) && value >= 64 && value <= 99);
  });

  test('Sauvegarde au barème V1 : toujours valide, jamais recalculée', () => {
    const v1 = JSON.parse(exported);
    v1.state.seniorCalibrationVersion = 1;
    // Empreinte d'export recalculée comme dist/saves.js (saveChecksum) : une carrière créée avant le barème V2.
    const raw = JSON.stringify(v1.state);
    let hash = 2166136261;
    for (let i = 0; i < raw.length; i++) hash = Math.imul(hash ^ raw.charCodeAt(i), 16777619);
    v1.checksum = (hash >>> 0).toString(16).padStart(8, '0');
    const text = JSON.stringify(v1);
    ask('import', { text });
    const reread = JSON.parse(ask('export').meta.exportText).state;
    assert.equal(reread.seniorCalibrationVersion, 1);
    assert.deepEqual(reread.clubs[5].players.map(p => [p.id, p.rating, p.dev.potential]), created.clubs[5].players.map(p => [p.id, p.rating, p.dev.potential]));
  });

  test('Table publique du niveau réel : identifiants et classes seulement', () => {
    const file = path.join(repo, 'data/world/niveaux-v2.json');
    const published = JSON.parse(fs.readFileSync(file, 'utf8'));
    assert.deepEqual(Object.keys(published).sort(), ['champs', 'classes', 'clubs', 'couverture', 'etages', 'joueurs', 'note', 'schema', 'statuts', 'version']);
    const registry = new Set(created.clubs.flatMap(c => c.players.map(p => p.id)));
    for (const [id, value] of Object.entries(published.joueurs)) {
      assert.ok(registry.has(id), 'identifiant du registre : ' + id);
      assert.equal(value.length, 4, id);
      assert.ok(published.classes.includes(value[0]) && published.statuts.includes(value[1]) && [0, 1].includes(value[2]) && ['haute', 'moyenne', 'basse'].includes(value[3]), id);
    }
    assert.equal(Object.keys(published.clubs).length, 116);
    assert.ok(Object.values(published.clubs).every(e => published.etages.includes(e)));
    const { classe, tier } = require('../tools/compile-niveaux-v2.cjs');
    assert.deepEqual([tier('France'), tier('Écosse'), tier('Pays de Galles'), tier('Tonga'), tier('')], [5, 8, 12, 20, 0]);
    assert.equal(classe({ intl_nation: 'Nouvelle-Zélande', intl_caps_total: '60', distinctions: '' }, 28), 'S');
    assert.equal(classe({ intl_nation: 'France', intl_caps_total: '20', distinctions: '' }, 26), 'A');
    assert.equal(classe({ intl_nation: 'France', intl_caps_total: '0', distinctions: '' }, 22), 'B');
    assert.equal(classe({ intl_nation: 'Italie', intl_caps_total: '', distinctions: '' }, 27), 'C');
    assert.equal(classe({ intl_nation: 'Irlande', intl_caps_total: '80', distinctions: '' }, 34), 'A', 'un cran de moins à 33 ans et plus');
    assert.equal(classe({ intl_nation: '', intl_caps_total: '', distinctions: '' }, 25), 'aucune');
  });

  test.after(() => {
    bridge.close();
    fs.rmSync(root, { recursive: true, force: true });
  });
})();
