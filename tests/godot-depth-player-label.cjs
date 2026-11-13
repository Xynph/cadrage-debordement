'use strict';
// Mode Monde uniquement : les joueurs viennent du vrai moteur (carrière world-champ).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');

const godot = process.env.CD_GODOT_EXECUTABLE;
test('Effectif : un joueur généré pour compléter l’effectif est présenté comme tel', { skip: !godot && 'SDK Godot requis' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-depth-label-'));
  const profile = path.join(dir, 'profil');
  fs.mkdirSync(profile);
  try {
    const bridge = createBridge({ dataDir: path.join(dir, 'moteur'), seed: 37, now: 1788134400000 });
    const created = bridge.handle({ id: 1, command: 'new_career', payload: { mode: 'world-champ', club: 103, varyCurrent: false } });
    assert.equal(created.ok, true, created.error);
    const generated = created.model.squad.find(player => player.id.startsWith('depth-'));
    const original = created.model.squad.find(player => !player.id.startsWith('depth-'));
    assert.ok(generated && original, 'La carrière Monde contient des joueurs générés et des joueurs d’origine');
    const fixture = path.join(dir, 'fixture.json');
    fs.writeFileSync(fixture, JSON.stringify({ generated, original }));
    const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-depth-player-label.gd')], {
      cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 120000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile, CD_DEPTH_FIXTURE: fixture },
    });
    const log = (result.stdout || '') + (result.stderr || '');
    if (result.error) throw result.error;
    assert.equal(result.status, 0, log);
    assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error|FAIL:/);
    assert.match(log, /depth-player-label : \d+ contrôles, 0 échec/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
