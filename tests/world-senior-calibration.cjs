'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Depuis le barème senior V2 (14/11/2026), les nouvelles carrières mondiales sont au barème 2 : les notes
// réalistes par joueur, club et championnat sont vérifiées par tests/world-rating-scale.cjs (mode Monde).

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const repo = path.resolve(__dirname, '..');
const { createBridge } = require(path.join(repo, 'native/engine/worker.cjs'));
const rugby = fs.readFileSync(path.join(repo, 'dist/rugby.js'), 'utf8');
const roleNote = vm.runInNewContext(rugby.slice(0, rugby.indexOf('function slotEligible')) + '\nroleNote', {
  clamp: (value, min, max) => Math.min(max, Math.max(min, value)),
  focusedBonus: () => 0,
});

const profile = model => path.join(model.meta.dataDir, 'donnees.json');
const state = model => JSON.parse(JSON.parse(fs.readFileSync(profile(model))).store['bdt-v1']);
const players = career => career.clubs.flatMap(club => club.players);
const corrections = require('../native/engine/world-player-corrections.json').players;
const numbers = player => [player.rating, player.skillBase, player.attributesV2, player.skills, player.potential, player.dev.potential];

function withBridge(dataDir, check) {
  const bridge = createBridge({ dataDir, seed: 20261110, now: 1794300000000 });
  let serial = 0;
  try {
    return check((command, payload = {}) => {
      const result = bridge.handle({ id: ++serial, command, payload });
      assert.equal(result.ok, true, command + ' : ' + result.error);
      assert.equal(result.model.meta.profileError, '');
      return result.model;
    });
  } finally {
    bridge.close();
  }
}

test('Le nouveau Monde Champ distingue les dix meilleurs et calibre son ouvreur toulousain', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-senior-'));
  try {
    const livePath = path.join(root, 'nouvelle');
    const { model, created, preview } = withBridge(livePath, ask => {
      const preview = ask('snapshot').meta.champCatalogue;
      const model = ask('new_career', { mode: 'world-champ', club: 0, varyCurrent: false });
      return { model, created: state(model), preview };
    });
    for (const id of [0, 39, 52, 61, 71]) {
      // Aperçu = effectif reçu en prenant ce club : sans joueurs de complément (club joué sans plancher de 40, 19/11/2026).
      const roster = created.clubs[id].players.filter(p => !p.id.startsWith('depth-'));
      const expected = Math.round(10 * roster.reduce((sum, player) => sum + player.rating, 0) / roster.length) / 10;
      assert.equal(preview[id].startingRoster.average, expected, 'Effectif de création ' + id);
    }
    const elite = players(created).filter(player => player.rating > 90 && roleNote(player) > 90);
    assert.ok(elite.length >= 10, `Dix profils doivent dépasser 90 sur les deux notes, trouvé ${elite.length}`);
    const topTen = elite.sort((a, b) => roleNote(b) - roleNote(a) || b.rating - a.rating).slice(0, 10);
    const families = Object.groupBy(topTen, player => player.fam);
    assert.ok(Object.values(families).every(group => group.length <= 2));
    assert.ok(topTen.every(player => player.age >= 23 && Object.keys(player.attributesV2).length === 36));
    const owner = new Map(created.clubs.flatMap(club => club.players.map(player => [player.id, club.id])));
    const competitions = Object.values(created.worldMode.leagues)
      .filter(league => topTen.some(player => league.members.includes(owner.get(player.id))));
    // Barème V3 (20/11/2026) : les dix meilleurs sont des internationaux majeurs, répartis sur au moins trois championnats.
    assert.ok(competitions.length >= 3, 'championnats du top 10 : ' + competitions.length);

    const baseline = withBridge(path.join(root, 'nationale'), ask => state(ask('new_career', { mode: 'world-nationale', club: 0, varyCurrent: false })));
    const oldPlayers = new Map(players(baseline).map(player => [player.id, player]));
    const opener = model.squad.find(player => player.id === 'lnr:2436');
    const oldOpener = require('../dist/rugby-common-rosters.js').clubs[0].players.find(player => player.id === opener.id);
    assert.equal(created.lineup[9], opener.id);
    assert.equal(opener.shirtNumber, 10);
    // Ouvreur international de classe S (barème V3) : 90+ comme toute la classe S, note au poste au moins égale.
    assert.ok(opener.rating >= 90 && opener.rating <= 94, `Globale de l’ouvreur : ${opener.rating}`);
    assert.ok(opener.note >= opener.rating, `Note au poste de l’ouvreur : ${opener.note}`);
    assert.ok(opener.attributes.pass > oldOpener.skills.pass);
    assert.ok(opener.attributes.kick > oldOpener.skills.kick);
    assert.equal(created.seniorCalibrationVersion, 2);
    assert.equal(baseline.seniorCalibrationVersion, 2);

    for (const player of players(created)) {
      const old = oldPlayers.get(player.id);
      // Postes et années de naissance corrigés (world-player-corrections.json) : appliqués selon la base de l'édition.
      if (!old || !player.attributesV2 || corrections[player.id]) continue;
      // Potentiel caché non comparé : settle limite les 90+ par génération sur la population de l'édition.
      // Même note d'une édition à l'autre ; les qualités peuvent venir d'un profil source différent selon l'édition.
      // Un point d'écart toléré : l'étage et le rang d'un club invité dépendent des clubs présents dans l'édition.
      assert.ok(Math.abs(player.rating - old.rating) <= 1 && Math.abs(player.skillBase - old.skillBase) <= 1, player.id);
      assert.equal(player.name, old.name, player.id);
      assert.equal(player.pos, old.pos, player.id);
      assert.deepEqual(player.hiddenTraitsV2, old.hiddenTraitsV2, player.id);
    }

    const before = fs.readFileSync(profile(model));
    withBridge(livePath, ask => {
      const reopened = ask('snapshot');
      assert.deepEqual(reopened.squad, model.squad);
      assert.deepEqual(fs.readFileSync(profile(reopened)), before);
      const exported = ask('export').meta.exportText;
      const imported = ask('import', { text: exported });
      assert.deepEqual(state(imported).clubs.map(club => club.players.map(numbers)), created.clubs.map(club => club.players.map(numbers)));
    });
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('Les références seniors gardent le même barème dans toutes leurs éditions', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-senior-editions-'));
  try {
    // Barème V3 (20/11/2026) : plus de profils réglés à la main ; un même joueur reçoit les mêmes notes et qualités
    // dans chaque édition Monde où il figure (mêmes règles, même table du niveau réel).
    const ids = ['lnr:2436', 'world:urc:193699', 'world:srp:p-724f734b6caa9dbb76061ef4'];
    const seen = new Map();
    for (const mode of ['world', 'world-pacific', 'world-japan', 'world-nationale', 'world-champ']) {
      withBridge(path.join(root, mode), ask => {
        const created = state(ask('new_career', { mode, club: 0, varyCurrent: false }));
        assert.equal(created.seniorCalibrationVersion, 2, mode);
        const roster = new Map(players(created).map(player => [player.id, player]));
        assert.equal(created.lineup[9], 'lnr:2436', mode);
        for (const id of ids) {
          const player = roster.get(id);
          if (!player) continue;
          const value = [...numbers(player), roleNote(player)];
          if (seen.has(id)) assert.deepEqual(value, seen.get(id), mode + ' ' + id);
          else seen.set(id, value);
        }
      });
    }
    assert.equal(seen.size, ids.length);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('Les profils sportifs seniors suivent les postes officiels au démarrage', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-senior-roles-'));
  const original = require('../dist/rugby-common-rosters.js').clubs.flatMap(club => club.players);
  const { players: foundation } = require('../dist/rugby-roster-foundation.js');
  const { projectSkills } = require('../scripts/build-world-registry.cjs');
  try {
    // Carrière Monde seule (barème V3, 20/11/2026) ; l'ancien mode France n'est plus testé.
    const starts = ['world-champ'].map(mode => withBridge(path.join(root, mode), ask => {
      const model = ask('new_career', { mode, club: 0, varyCurrent: false });
      const initial = state(model);
      const exported = ask('export').meta.exportText;
      assert.deepEqual(state(ask('import', { text: exported })), initial);
      return new Map(players(initial).map(player => [player.id, player]));
    }));
    const changed = original.filter(player => player.age >= 23 && foundation[player.id].position.basis === 'official' &&
      player.gameplayPosition !== foundation[player.id].position.primary);
    assert.equal(changed.length, 54);
    for (const source of changed) {
      const [common] = starts.map(roster => roster.get(source.id));
      assert.equal(common.pos, foundation[source.id].position.primary, source.id);
      assert.equal(common.gameplayPosition, common.pos, source.id);
      assert.notDeepEqual(common.attributesV2, source.attributesV2, source.id);
      assert.deepEqual(common.skills, projectSkills(common.attributesV2, common.pos), source.id);
      const before = roleNote({ ...source, fam: common.fam });
      assert.ok(roleNote(common) > common.rating - 8, source.id + ' écart au poste');
    }
    const young = original.filter(player => player.age < 23 && foundation[player.id].position.basis === 'official' &&
      player.gameplayPosition !== foundation[player.id].position.primary);
    assert.ok(young.length > 0);
    for (const source of young) for (const roster of starts) assert.ok(roster.get(source.id).dev.potential >= roster.get(source.id).rating, source.id);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
