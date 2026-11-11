'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('Liens du carnet : vraie consultation par ID, historique et absence de mutation', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, () => {
  const directory = process.env.CD_NIGHT_NAV_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rg27-night-navigation-'));
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'rg27-night-navigation-profile-'));
  fs.mkdirSync(directory, { recursive: true });
  const project = path.resolve(__dirname, '../native/godot');
  const graphics = process.env.CD_NIGHT_NAV_GRAPHICS === '1';
  const group = process.env.CD_NIGHT_NAV_CASE || 'reading';
  assert.ok(['reading', 'nation', 'guards', 'prospects', 'staff', 'quote'].includes(group), 'Groupe explicite connu');
  const files = [
    'ui/navigation_controller.gd', 'ui/management_state.gd', 'main.gd',
    'ui/international_view.gd', 'ui/staff_view.gd',
    'ui/immersive08/competition_canvas.gd', 'ui/prospect_profile.gd',
    'ui/regen_scouting_view.gd', 'ui/interclub_market_view.gd',
  ];
  const sources = Object.fromEntries(files.filter(file => fs.existsSync(path.join(project, file))).map(file => [file,
    crypto.createHash('sha256').update(fs.readFileSync(path.join(project, file))).digest('hex')]));
  const commit = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: path.resolve(__dirname, '..'), encoding: 'utf8' }).stdout.trim();
  fs.writeFileSync(path.join(directory, 'provenance.json'), JSON.stringify({ commit, sources, group, graphics, profile }, null, 2));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(graphics ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '2560x1440'] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '60', '--path', project,
    '--log-file', path.join(directory, 'engine.log'), '--script', path.resolve(__dirname, 'rg27-night-navigation.gd'),
  ], {
    cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 180000,
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0',
      CD_GODOT_DATA_DIR: profile, CD_NIGHT_NAV_OUTPUT: directory, CD_NIGHT_NAV_CASE: group },
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(directory, 'godot.log'), output);
  console.log(output.trim());
  console.log('Preuves navigation nocturne : ' + directory);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  const report = JSON.parse(fs.readFileSync(path.join(directory, 'report.json'), 'utf8'));
  assert.deepEqual(report.failures, []);
  assert.equal(report.speech_requests, 0);
  assert.equal(report.speech_starts, 0);
  if (graphics) assert.ok(report.captures.length > 0, 'Au moins une vraie capture');
});
