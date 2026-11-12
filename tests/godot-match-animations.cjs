'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');

const GODOT = path.resolve(__dirname, '../native/godot');
const ROOT = path.resolve(__dirname, '..');

// Les fichiers d'animation d'origine (Mixamo) ne doivent jamais entrer dans le dépôt.
test('Aucun fichier d’animation tiers dans le dépôt', () => {
  const found = [];
  const walk = folder => {
    for (const entry of fs.readdirSync(folder, {withFileTypes: true})) {
      if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === '.godot') continue;
      const full = path.join(folder, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (/\.fbx$/i.test(entry.name) || /^mixamo.*\.glb$/i.test(entry.name)) found.push(path.relative(ROOT, full));
    }
  };
  walk(path.join(ROOT, 'native'));
  walk(path.join(ROOT, 'scripts'));
  assert.deepEqual(found, []);
});

test('Animations adaptées : absentes par défaut, quatre paliers avec une bibliothèque', {
  skip: !process.env.CD_GODOT_EXE && 'Godot SDK required',
}, () => {
  const project = process.env.CD_MATCH_PROJECT || GODOT;
  const env = {...process.env};
  for (const name of ['CD_MATCH_ANIMATIONS', 'CD_MATCH_GESTES', 'CD_MATCH_RENDU']) delete env[name];
  const run = spawnSync(process.env.CD_GODOT_EXE, ['--headless', '--path', project, '--script', path.resolve(__dirname, 'godot-match-animations.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 150000, env,
  });
  const output = (run.stdout || '') + (run.stderr || '');
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.match(output, /MATCH_ANIMATIONS_CHECKS {"checks":\d+,"failures":\[\]}/);
});
