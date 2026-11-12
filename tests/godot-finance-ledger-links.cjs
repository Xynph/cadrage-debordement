'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const zlib = require('node:zlib');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Graphique financier : écritures archivées exactes, clavier, clic et lecture pure', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent',
}, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-finance-ledger-links-'));
  const fixture = path.join(profile, 'career-fixture.json');
  fs.writeFileSync(fixture, zlib.gunzipSync(fs.readFileSync(path.join(__dirname, 'fixtures/roster-foundation-v1-s2.json.gz'))));
  const graphics = process.env.CD_LEDGER_GRAPHICS === '1';
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(graphics ? [] : ['--headless']), '--audio-driver', 'Dummy', '--max-fps', '120', '--path', 'native/godot',
    '--script', path.resolve(__dirname, 'godot-finance-ledger-links.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile, CD_LEDGER_FIXTURE: fixture, CD_LEDGER_OUTPUT: process.env.CD_LEDGER_OUTPUT || profile },
    encoding: 'utf8', windowsHide: true, timeout: 180000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim());
  console.log('Preuves graphique financier : ' + profile);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
