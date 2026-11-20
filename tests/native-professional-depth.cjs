'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');

const extra = player => player.id.startsWith('depth-');
const readCareer = file => JSON.parse(JSON.parse(fs.readFileSync(file)).store['bdt-v1']);

// Décision de Léo du 19/11/2026 (docs/gdd/calendrier-mutations.md § 3 quater) : en carrière Monde, le club joué n'a plus
// de plancher de 40 ni de joueurs de complément ; les clubs gérés gardent le leur.
test('Clubs gérés du Monde complet : 40 pros ou plus ; club joué : effectif réel, sans joueurs de complément', () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-pro-depth-'));
  let bridge = createBridge({ dataDir, seed: 37, now: 1788134400000 });
  let id = 0;
  const request = (command, payload = {}) => {
    const result = bridge.handle({ id: ++id, command, payload });
    assert.equal(result.ok, true, result.error);
    return result.model;
  };
  try {
    // This reference-floor contract uses the unchanged current levels. Default
    // variation, bounds and replay for every pool (including depth players) are
    // covered by career-variation-worker.cjs across all native editions.
    const created = request('new_career', { mode: 'world-champ', club: 103, varyCurrent: false });
    assert.equal(created.meta.careerVariation.varyCurrent, false);
    const file = path.join(created.meta.dataDir, 'donnees.json');
    const state = readCareer(file);
    const all = state.clubs.flatMap(club => club.players);
    assert.ok(state.clubs.every(club => club.id === state.club || club.players.length >= 40));
    assert.equal(new Set(all.map(player => player.id)).size, all.length);
    for (const club of state.clubs) {
      const original = club.players.filter(player => !extra(player));
      const additions = club.players.filter(extra);
      assert.equal(additions.length, club.id === state.club ? 0 : Math.max(0, 40 - original.length));
      if (additions.length) {
        assert.ok(additions.every(player => player.rating < Math.min(...original.map(p => p.rating))));
        assert.ok(additions.every(player => player.salary > 0 && player.contractEnd >= state.season));
      }
    }
    assert.equal(created.squad.filter(player => !extra(player)).length, 26);
    assert.equal(created.squad.filter(extra).length, 0, 'club joué : aucun joueur de complément');
    // Joueurs de complément des clubs gérés : variés (âges, postes), sous le moins bon joueur d'origine (contrôlé plus haut).
    const managedAdditions = state.clubs.filter(club => club.id !== state.club).flatMap(club => club.players.filter(extra));
    assert.ok(managedAdditions.length > 0, 'clubs gérés : des joueurs de complément');
    assert.ok(new Set(managedAdditions.map(player => player.age)).size >= 6);
    assert.ok(new Set(managedAdditions.map(player => player.pos)).size >= 5);
    assert.equal(created.meta.champCatalogue[103].startingRoster.forwards + created.meta.champCatalogue[103].startingRoster.backs, 26);
    assert.equal(created.meta.champDatabase.startingPlayerCount, all.length);

    bridge.close();
    const profile = JSON.parse(fs.readFileSync(file));
    for (const club of state.clubs) club.players = club.players.filter(player => !extra(player));
    for (const key of ['lineup', 'reserves']) state[key] = state[key].map(playerId => playerId?.startsWith('depth-') ? null : playerId);
    profile.store['bdt-v1'] = JSON.stringify(state);
    const originalBytes = Buffer.from(JSON.stringify(profile));
    fs.writeFileSync(file, originalBytes);
    bridge = createBridge({ dataDir });
    assert.equal(request('snapshot').squad.length, 26, 'au chargement, le club joué n’est pas complété');
    assert.deepEqual(fs.readFileSync(file), originalBytes);
    request('save');
    const restored = readCareer(file);
    assert.ok(restored.clubs.every(club => club.id === restored.club || club.players.length >= 40));
    assert.deepEqual(restored.clubs[103].players.filter(p => !extra(p)), state.clubs[103].players);
    assert.deepEqual(restored.history, state.history);
    assert.deepEqual(restored.clubs.map(club => club.cash), state.clubs.map(club => club.cash));
    assert.deepEqual(request('import', { text: request('export').meta.exportText }).squad.map(p => p.id), restored.clubs[103].players.map(p => p.id));
  } finally {
    bridge.close();
  }
});
