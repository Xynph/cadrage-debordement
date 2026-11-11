'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const repo = path.resolve(__dirname, '..');
const careerVariation = require('../native/engine/career-variation.cjs')();
const calibrationVariation = careerVariation.settings(20261110, false);
const { createBridge } = require(path.join(repo, 'native/engine/worker.cjs'));
const rugby = fs.readFileSync(path.join(repo, 'dist/rugby.js'), 'utf8');
const roleNote = vm.runInNewContext(rugby.slice(0, rugby.indexOf('function slotEligible')) + '\nroleNote', {
  clamp: (value, min, max) => Math.min(max, Math.max(min, value)),
  focusedBonus: () => 0,
});

const profile = model => path.join(model.meta.dataDir, 'donnees.json');
const state = model => JSON.parse(JSON.parse(fs.readFileSync(profile(model))).store['bdt-v1']);
const players = career => career.clubs.flatMap(club => club.players);
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
      const roster = created.clubs[id].players;
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
    assert.equal(competitions.length, 5);

    const baseline = withBridge(path.join(root, 'nationale'), ask => state(ask('new_career', { mode: 'world-nationale', club: 0, varyCurrent: false })));
    const oldPlayers = new Map(players(baseline).map(player => [player.id, player]));
    const opener = model.squad.find(player => player.id === 'lnr:2436');
    const oldOpener = require('../dist/rugby-common-rosters.js').clubs[0].players.find(player => player.id === opener.id);
    assert.equal(created.lineup[9], opener.id);
    assert.equal(opener.shirtNumber, 10);
    assert.ok(opener.rating >= 87 && opener.rating <= 89, `Globale de l’ouvreur : ${opener.rating}`);
    assert.ok(opener.note >= 90 && opener.note <= 92, `Note au poste de l’ouvreur : ${opener.note}`);
    assert.equal(opener.attributes.goal, oldOpener.skills.goal);
    assert.ok(opener.attributes.pass > oldOpener.skills.pass);
    assert.ok(opener.attributes.kick > oldOpener.skills.kick);
    assert.equal(created.seniorCalibrationVersion, 1);
    assert.equal(baseline.seniorCalibrationVersion, 1);

    for (const player of players(created)) {
      const old = oldPlayers.get(player.id);
      if (!old || !player.attributesV2) continue;
      assert.deepEqual(numbers(player), numbers(old), player.id);
      assert.equal(player.name, old.name, player.id);
      assert.equal(player.pos, old.pos, player.id);
      assert.equal(player.salary, old.salary, player.id);
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
    const modes = { common: 2, world: 7, 'world-pacific': 9, 'world-japan': 10, 'world-nationale': 10, 'world-champ': 10 };
    for (const [mode, above90] of Object.entries(modes)) {
      withBridge(path.join(root, mode), ask => {
        const model = ask('new_career', { mode, club: 0, varyCurrent: false });
        const created = state(model);
        const opener = model.squad.find(player => player.id === 'lnr:2436');
        assert.equal(opener.rating, 88, mode);
        assert.equal(opener.note, 91, mode);
        assert.equal(opener.attributes.goal, 84.4, mode);
        assert.equal(created.lineup[9], opener.id, mode);
        assert.equal(created.seniorCalibrationVersion, 1, mode);
        const roster = new Map(players(created).map(player => [player.id, player]));
        const centre = roster.get('world:srp:p-724f734b6caa9dbb76061ef4');
        const scrumHalf = roster.get('world:urc:193699');
        if (mode === 'common') assert.equal(scrumHalf, undefined);
        else {
          assert.deepEqual([scrumHalf.rating, roleNote(scrumHalf)], [85, 86], mode);
          assert.deepEqual([scrumHalf.attributesV2.acceleration, scrumHalf.attributesV2.evasion, scrumHalf.attributesV2.decisions], [94, 94, 93], mode);
          assert.equal(scrumHalf.attributesV2.tackling, 62, mode);
          assert.equal(scrumHalf.dev.seasonStart, 85, mode);
        }
        if (mode === 'common' || mode === 'world') assert.equal(centre, undefined);
        else {
          assert.deepEqual([centre.rating, roleNote(centre)], [87, 88], mode);
          assert.deepEqual([centre.attributesV2.ballCarry, centre.attributesV2.tackling, centre.attributesV2.leadership], [96, 96, 87], mode);
          assert.equal(centre.attributesV2.kickAccuracy, 52, mode);
          assert.equal(centre.dev.seasonStart, 87, mode);
        }
        assert.equal(players(created).filter(player => player.rating > 90 && roleNote(player) > 90).length, above90, mode);
      });
    }
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
    const starts = ['common', 'world-champ'].map(mode => withBridge(path.join(root, mode), ask => {
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
      const [common, world] = starts.map(roster => roster.get(source.id));
      assert.equal(common.pos, foundation[source.id].position.primary, source.id);
      assert.equal(common.gameplayPosition, common.pos, source.id);
      assert.deepEqual(numbers(common), numbers(world), source.id);
      assert.notDeepEqual(common.attributesV2, source.attributesV2, source.id);
      assert.deepEqual(common.skills, projectSkills(common.attributesV2, common.pos), source.id);
      const before = roleNote({ ...source, fam: common.fam });
      assert.ok(roleNote(common) >= before - 1, source.id + ' note existante');
      assert.ok(roleNote(common) > common.rating - 8, source.id + ' écart au poste');
    }
    const young = original.filter(player => player.age < 23 && foundation[player.id].position.basis === 'official' &&
      player.gameplayPosition !== foundation[player.id].position.primary);
    assert.ok(young.length > 0);
    for (const source of young) for (const roster of starts) assert.deepEqual(numbers(roster.get(source.id)), numbers(careerVariation.player(source, calibrationVariation)));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
