'use strict';
// Sonde des contacts du match filmé (tools/match-filme/sonde_contacts.gd) : joueur sans piste du
// chorégraphe à côté d'un joueur qui en a une, sans erreur de script ; membres en cause et moyenne.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;

test('Sonde des contacts : couple avec et sans piste mesuré sans erreur, membres en cause', { skip: !godot && 'Godot SDK required' }, () => {
  const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');
  const run = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', project, '--script', path.resolve(__dirname, 'godot-sonde-contacts.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 60000,
  });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  console.log(output);
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.match(output, /SONDE_CONTACTS_CHECKS .*"failures":\[\]/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
