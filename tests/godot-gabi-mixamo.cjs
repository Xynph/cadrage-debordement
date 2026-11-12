'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');

const ROOT = path.resolve(__dirname, '..');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;

// Le Gabi rigué par Mixamo et ses gestes restent dans le dépôt privé (licence Mixamo).
test('Aucun fichier du Gabi Mixamo dans le dépôt', () => {
  const found = [];
  const walk = folder => {
    for (const entry of fs.readdirSync(folder, {withFileTypes: true})) {
      if (['.git', 'node_modules', '.godot'].includes(entry.name)) continue;
      const full = path.join(folder, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (/^gabi-mixamo.*\.(glb|gltf|scn|res|fbx|blend)$/i.test(entry.name)) found.push(path.relative(ROOT, full));
    }
  };
  for (const folder of ['native', 'scripts', 'dist', 'tests']) walk(path.join(ROOT, folder));
  assert.deepEqual(found, []);
});

test('Gabi Mixamo : repli sans fichier, chargement et choix des clips', {
  skip: !godot && 'SDK Godot requis',
}, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-gabi-mixamo-'));
  const env = {...process.env, APPDATA: directory, LOCALAPPDATA: directory};
  for (const name of ['CD_GABI_MIXAMO', 'CD_MATCH_ANIMATIONS']) delete env[name];
  try {
    const run = spawnSync(godot, [
      '--headless', '--path', path.join(ROOT, 'native/godot'),
      '--log-file', path.join(directory, 'godot.log'),
      '--script', path.resolve(__dirname, 'godot-gabi-mixamo.gd'), '--', directory,
    ], {encoding: 'utf8', timeout: 60000, windowsHide: true, env});
    const output = (run.stdout || '') + (run.stderr || '');
    assert.ifError(run.error);
    assert.equal(run.status, 0, output);
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
    assert.match(output, /GABI_MIXAMO_CHECKS {"checks":\d+,"failures":\[\]}/);
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});
