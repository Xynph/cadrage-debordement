'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawn, spawnSync } = require('node:child_process');
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('Liens du carnet : vraie consultation par ID, historique et absence de mutation', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, async () => {
  const directory = process.env.CD_NIGHT_NAV_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rg27-night-navigation-'));
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'rg27-night-navigation-profile-'));
  fs.mkdirSync(directory, { recursive: true });
  const project = path.resolve(__dirname, '../native/godot');
  const graphics = process.env.CD_NIGHT_NAV_GRAPHICS === '1';
  const group = process.env.CD_NIGHT_NAV_CASE || 'reading';
  assert.ok(['reading', 'nation', 'guards', 'prospects', 'staff', 'quote', 'report'].includes(group), 'Groupe explicite connu');
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
  const started = Date.now();
  if (group === 'report') {
    const preparation = spawnSync(process.execPath, [path.resolve(__dirname, 'rg27-night-helpers/report-prepare.cjs'), profile, directory], {
      cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: 110000, env: process.env,
    });
    const preparationLog = (preparation.stdout || '') + (preparation.stderr || '');
    fs.writeFileSync(path.join(directory, 'report-preparation.log'), preparationLog);
    if (preparation.error) throw preparation.error;
    assert.equal(preparation.status, 0, preparationLog);
  }
  const remaining = 180000 - (Date.now() - started);
  assert.ok(remaining > 0, 'La préparation garde le budget global de 180 secondes');
  const args = [
    ...(graphics ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '2560x1440'] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '60', '--path', project,
    '--log-file', path.join(directory, 'engine.log'), '--script', path.resolve(__dirname, 'rg27-night-navigation.gd'),
  ];
  const options = {
    cwd: path.resolve(__dirname, '..'), encoding: 'utf8', timeout: remaining,
    env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0',
      CD_GODOT_DATA_DIR: profile, CD_NIGHT_NAV_OUTPUT: directory, CD_NIGHT_NAV_CASE: group },
  };
  // The SDK supervisor still buffers this wrapper. Forward guards output now
  // so its partial capture survives an outer timeout; this is not live CI UI.
  let result;
  if (group === 'guards') {
    const eventsFile = path.join(directory, 'node-events.jsonl');
    fs.writeFileSync(eventsFile, '');
    const event = (stage, fields = {}) => {
      const entry = { stage, case: group, elapsed_ms: Date.now() - started, ...fields };
      const line = JSON.stringify(entry);
      fs.appendFileSync(eventsFile, line + '\n');
      process.stdout.write('NIGHT_CHILD ' + line + '\n');
    };
    result = await new Promise(resolve => {
      const stdout = [];
      const stderr = [];
      let error;
      let timer;
      const recordError = value => {
        if (error) return;
        error = value;
        event('error', { code: value.code || null, message: value.message });
      };
      const { timeout, ...spawnOptions } = options;
      event('begin', { timeout_ms: timeout });
      let child;
      try {
        child = spawn(process.env.CD_GODOT_EXECUTABLE, args, spawnOptions);
      } catch (value) {
        recordError(value);
        resolve({ stdout: '', stderr: '', status: null, error });
        return;
      }
      child.stdout.setEncoding('utf8');
      child.stderr.setEncoding('utf8');
      child.stdout.on('data', chunk => { stdout.push(chunk); process.stdout.write(chunk); });
      child.stderr.on('data', chunk => { stderr.push(chunk); process.stderr.write(chunk); });
      child.on('error', recordError);
      child.once('exit', () => clearTimeout(timer));
      child.once('close', (status, signal) => {
        clearTimeout(timer);
        const out = stdout.join('');
        const err = stderr.join('');
        event('exit', { status, signal, stdout_bytes: Buffer.byteLength(out), stderr_bytes: Buffer.byteLength(err) });
        resolve({ stdout: out, stderr: err, status, error });
      });
      timer = setTimeout(() => {
        const expired = new Error('Godot guards exceeded its existing child timeout');
        expired.code = 'ETIMEDOUT';
        recordError(expired);
        child.kill('SIGTERM');
      }, timeout);
    });
  } else {
    result = spawnSync(process.env.CD_GODOT_EXECUTABLE, args, options);
  }
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(directory, 'godot.log'), output);
  if (group !== 'guards') console.log(output.trim());
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
