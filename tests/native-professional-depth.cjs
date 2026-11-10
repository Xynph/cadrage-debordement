'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');

const extra = player => player.id.startsWith('depth-');
const readCareer = file => JSON.parse(JSON.parse(fs.readFileSync(file)).store['bdt-v1']);

test('Tous les clubs du Monde complet disposent de 40 pros ou plus', () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-pro-depth-'));
  let bridge = createBridge({ dataDir, seed: 37, now: 1788134400000 });
  let id = 0;
  const request = (command, payload = {}) => {
    const result = bridge.handle({ id: ++id, command, payload });
    assert.equal(result.ok, true, result.error);
    return result.model;
  };
  try {
    const created = request('new_career', { mode: 'world-champ', club: 103 });
    const file = path.join(created.meta.dataDir, 'donnees.json');
    const state = readCareer(file);
    const all = state.clubs.flatMap(club => club.players);
    assert.ok(state.clubs.every(club => club.players.length >= 40));
    assert.equal(new Set(all.map(player => player.id)).size, all.length);
    for (const club of state.clubs) {
      const original = club.players.filter(player => !extra(player));
      const additions = club.players.filter(extra);
      assert.equal(additions.length, Math.max(0, 40 - original.length));
      if (additions.length) {
        assert.ok(additions.every(player => player.rating < Math.min(...original.map(p => p.rating))));
        assert.ok(additions.every(player => player.salary > 0 && player.contractEnd >= state.season));
      }
    }
    const original = created.squad.filter(player => !extra(player));
    const additions = created.squad.filter(extra);
    assert.equal(original.length, 26);
    assert.equal(additions.length, 14);
    assert.ok(new Set(additions.map(player => player.age)).size >= 6);
    assert.ok(new Set(additions.map(player => player.pos)).size >= 5);
    for (const player of additions) {
      const peers = original.filter(p => p.pos === player.pos);
      assert.ok(player.note < Math.min(...(peers.length ? peers : original).map(p => p.note)));
      assert.equal(Object.keys(player.attributesV2).length, 36);
    }
    assert.equal(created.meta.champCatalogue[103].startingRoster.forwards + created.meta.champCatalogue[103].startingRoster.backs, 40);
    assert.equal(created.meta.champDatabase.startingPlayerCount, all.length);

    bridge.close();
    const profile = JSON.parse(fs.readFileSync(file));
    for (const club of state.clubs) club.players = club.players.filter(player => !extra(player));
    for (const key of ['lineup', 'reserves']) state[key] = state[key].map(playerId => playerId?.startsWith('depth-') ? null : playerId);
    profile.store['bdt-v1'] = JSON.stringify(state);
    const originalBytes = Buffer.from(JSON.stringify(profile));
    fs.writeFileSync(file, originalBytes);
    bridge = createBridge({ dataDir });
    assert.equal(request('snapshot').squad.length, 40);
    assert.deepEqual(fs.readFileSync(file), originalBytes);
    request('save');
    const restored = readCareer(file);
    assert.ok(restored.clubs.every(club => club.players.length >= 40));
    assert.deepEqual(restored.clubs[103].players.filter(p => !extra(p)), state.clubs[103].players);
    assert.deepEqual(restored.history, state.history);
    assert.deepEqual(restored.clubs.map(club => club.cash), state.clubs.map(club => club.cash));
    assert.deepEqual(request('import', { text: request('export').meta.exportText }).squad.map(p => p.id), restored.clubs[103].players.map(p => p.id));
  } finally {
    bridge.close();
  }
});
