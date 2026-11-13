'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Lecteurs natifs : fenêtres exactes, chaîne modale et retour sans mutation', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent',
}, () => {
  // Budget global 270 s (la recette SDK coupe une suite à 300 s) : la saison Monde compte ~46 jours de
  // préparation avant le premier match du club ; ils sont joués par les commandes publiques du moteur
  // côté Node (même helper que la recette graphique Analyse/Club), puis Godot ouvre la carrière préparée.
  const deadline = Date.now() + 270000;
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-reader-history-'));
  const preparation = spawnSync(process.execPath, [path.resolve(__dirname, 'helpers/analysis-club-public-prepare.cjs'), profile, path.join(profile, 'preparation')], {
    env: process.env, encoding: 'utf8', windowsHide: true, timeout: 150000,
  });
  const prepared = (preparation.stdout || '') + (preparation.stderr || '');
  if (preparation.error) throw preparation.error;
  assert.equal(preparation.status, 0, prepared);
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', 'native/godot',
    '--script', path.resolve(__dirname, 'godot-reader-history.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile, CD_READER_HISTORY_COPIED: '1' },
    encoding: 'utf8', windowsHide: true, timeout: Math.max(1000, deadline - Date.now() - 1000),
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim());
  console.log('Preuves historique lecteurs : ' + profile);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
