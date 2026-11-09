'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { test } = require('node:test');

test('Passe de démonstration sur le squelette Quaternius dans Godot', {
  skip: !process.env.CD_GODOT_EXE && 'Godot SDK required',
}, () => {
  const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');
  const script = path.resolve(__dirname, 'godot-match-pass.gd');
  const run = spawnSync(process.env.CD_GODOT_EXE, ['--headless', '--path', project, '--script', script], {
    encoding: 'utf8', windowsHide: true, timeout: 60_000,
  });
  if (run.error) throw run.error;
  const output = (run.stdout || '') + (run.stderr || '');
  assert.equal(run.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  const receipt = /^MATCH_PASS_CHECKS (.+)$/m.exec(output);
  assert.ok(receipt, output);
  const report = JSON.parse(receipt[1]);
  assert.deepEqual(report.failures, []);
  assert.deepEqual(report.phases, ['held', 'flight', 'received']);
  assert.equal(report.real_rig, true);
  assert.ok(report.catch_displacement_m > 1);
  assert.ok(report.largest_hold_gap_m < 0.39);
});
