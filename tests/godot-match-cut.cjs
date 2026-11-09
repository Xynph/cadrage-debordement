'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXE;
const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');

function verify(script, verdict) {
  const run = spawnSync(godot, ['--headless', '--path', project, '--script', path.join(__dirname, script)], {
    encoding: 'utf8',
    windowsHide: true,
    timeout: 60000,
  });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.match(output, verdict);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  console.log(output.trim());
}

test('Native match: mirrored cut preserves the root, ball anchor and grounded support', { skip: !godot && 'Godot SDK required' }, () => {
  verify('godot-match-cut.gd', /MATCH_CUT_CHECKS .*"failures":\[\]/);
});

test('Native match: a carrying turn reaches the live view and clears on pause', { skip: !godot && 'Godot SDK required' }, () => {
  verify('godot-match-cut-integration.gd', /MATCH_CUT_INTEGRATION .*"failures":\[\]/);
});
