'use strict';

const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const {test} = require('node:test');

test('Native match stadium: evening preset is reversible with thirty actors', {
  skip: !process.env.CD_GODOT_EXE && 'Godot SDK required',
}, () => {
  const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');
  const script = path.resolve(__dirname, 'godot-match-stadium-evening.gd');
  const run = spawnSync(process.env.CD_GODOT_EXE, ['--headless', '--path', project, '--script', script], {
    encoding: 'utf8', windowsHide: true, timeout: 60000,
  });
  const output = (run.stdout || '') + (run.stderr || '');
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.match(output, /MATCH_STADIUM_EVENING {"failures":\[\],"players":30}/);
});
