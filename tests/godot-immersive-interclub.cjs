'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const assert = require('node:assert/strict');
test('Marché entre clubs : entrée immersive cliquable en 720p et 1080p', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis' }, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-immersive-interclub-'));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(process.env.CD_INTERCLUB_GRAPHICS === '1' ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility'] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '120', '--path', 'native/godot',
    '--script', path.resolve(__dirname, 'godot-immersive-interclub.gd')
  ], { cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 180000,
    env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath,
      CD_GODOT_DATA_DIR: path.join(directory, 'profile'), CD_INTERCLUB_ARTIFACTS: directory,
      XDG_DATA_HOME: path.join(directory, 'xdg-data'), XDG_CONFIG_HOME: path.join(directory, 'xdg-config'), XDG_CACHE_HOME: path.join(directory, 'xdg-cache') } });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(directory, 'godot.log'), output);
  console.log(output.trim()); console.log('Preuves marché immersif : ' + directory);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
