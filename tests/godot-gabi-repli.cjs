'use strict';
// Repli du visage de Gabi dans le bandeau (sans fichier Mixamo privé, sans GLB) : exécution native Godot,
// ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const assert = require('node:assert/strict');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');

const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;

test('Gabi (bandeau) : repli propre et vivant sans fichier privé ni GLB', {skip: !godot && 'SDK Godot requis', timeout: 300000}, () => {
  const env = {...process.env};
  delete env.CD_GABI_MIXAMO;
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-gabi-repli.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 120000, env,
  });
  const log = (result.stdout || '') + (result.stderr || '');
  console.log(log.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, log);
  assert.match(log, /GABI_REPLI \d+ controles, 0 echec/);
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
});
