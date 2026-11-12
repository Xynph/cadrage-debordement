'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
test('Consultations nation et staff ciblées, clavier et lecture pure des projections', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, () => {
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.join(__dirname, 'godot-entity-projections.gd'),
  ], {encoding:'utf8', timeout:30000, env:{...process.env, CD_GODOT_SELF_TEST:'0'}});
  const output = (result.stdout || '') + (result.stderr || '');
  console.log(output.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
  assert.match(output, /ENTITY_PROJECTIONS.*"failures":\[\]/);
});
