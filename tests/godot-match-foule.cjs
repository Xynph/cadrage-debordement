'use strict';
// Foule qui réagit et clameur qui monte (19/11/2026) : intensité qui enfle dans les 22 m et culmine
// à l'essai, part du public debout qui augmente sur un essai, coût borné, trace du son pour le film.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;

test('Foule du stade : 22 m, essai, public debout, clameur et trace', { skip: !godot && 'SDK Godot requis' }, () => {
  const proof = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-foule-'));
  const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');
  const run = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', project, '--script', path.resolve(__dirname, 'godot-match-foule.gd')], {
    env: { ...process.env, CD_FOULE_PROOF: proof }, encoding: 'utf8', windowsHide: true, timeout: 120000,
  });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.match(output, /MATCH_FOULE .*"failures":\[\]/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
});
