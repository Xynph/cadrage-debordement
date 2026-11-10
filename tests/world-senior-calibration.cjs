'use strict';

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
      const model = ask('new_career', { mode: 'world-champ', club: 0 });
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

    const baseline = withBridge(path.join(root, 'nationale'), ask => state(ask('new_career', { mode: 'world-nationale', club: 0 })));
    const oldPlayers = new Map(players(baseline).map(player => [player.id, player]));
    const opener = model.squad.find(player => player.id === 'lnr:2436');
    const oldOpener = oldPlayers.get(opener.id);
    assert.equal(created.lineup[9], opener.id);
    assert.equal(opener.shirtNumber, 10);
    assert.ok(opener.rating >= 87 && opener.rating <= 89, `Globale de l’ouvreur : ${opener.rating}`);
    assert.ok(opener.note >= 90 && opener.note <= 92, `Note au poste de l’ouvreur : ${opener.note}`);
    assert.equal(opener.attributes.goal, oldOpener.skills.goal);
    assert.ok(opener.attributes.pass > oldOpener.skills.pass);
    assert.ok(opener.attributes.kick > oldOpener.skills.kick);
    assert.equal(created.seniorCalibrationVersion, 1);
    assert.equal(baseline.seniorCalibrationVersion, undefined);

    for (const player of players(created)) {
      const old = oldPlayers.get(player.id);
      if (!old || !player.attributesV2) continue;
      assert.equal(player.potential, old.potential, player.id);
      if (player.id !== opener.id && player.rating > old.rating) {
        assert.equal(player.dev.potential, Math.min(Math.max(97, old.dev.potential), old.dev.potential + player.rating - old.rating), player.id);
      }
      if (player.age < 23) assert.deepEqual(numbers(player), numbers(old), player.id);
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
