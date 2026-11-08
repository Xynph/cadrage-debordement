'use strict';
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { spawnSync } = require('node:child_process');
const { Worker } = require('node:worker_threads');
const { once } = require('node:events');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const project = path.resolve(__dirname, '../native/godot');
test('Godot : remplacement avec lecteur Windows concurrent et refus visibles', { skip: !godot && 'SDK Godot requis', timeout: 180000 }, async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-godot-atomic-é '));
  const destination = path.join(directory, 'préférences.json');
  fs.writeFileSync(destination, JSON.stringify({ sequence: 0, payload: 'é'.repeat(4096) }));
  const control = new SharedArrayBuffer(4);
  const reader = new Worker(path.join(__dirname, 'godot-atomic-file-reader.cjs'), { workerData: { destination, control } });
  t.after(() => reader.terminate());
  assert.deepEqual(await once(reader, 'message'), ['ready']);
  const finished = once(reader, 'message');
  let run;
  try {
    run = spawnSync(godot, ['--headless', '--path', project, '--script', path.join(__dirname, 'godot-atomic-file.gd')], {
      env: { ...process.env, CD_ATOMIC_DIRECTORY: directory, CD_NODE_EXECUTABLE: process.execPath }, encoding: 'utf8', windowsHide: true, timeout: 150000
    });
  } finally { Atomics.store(new Int32Array(control), 0, 1); }
  const [result] = await finished;
  const output = (run.stdout || '') + (run.stderr || '');
  fs.writeFileSync(path.join(directory, 'godot.log'), output);
  fs.writeFileSync(path.join(directory, 'monitor-report.json'), JSON.stringify(result));
  console.log(output.trim()); console.log('Lecteur Godot : ' + JSON.stringify(result)); console.log('Preuves : ' + directory);
  if (run.error) throw run.error;
  assert.equal(run.status, 0, output); assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.ok(result.samples > 80); assert.equal(result.missing + result.invalid + result.other, 0);
});
test('Godot : réponses absentes, malformées, excessives et nonzero refusées', { skip: !godot && 'SDK Godot requis', timeout: 60000 }, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-atomic-protocol-'));
  const privateProject = path.join(directory, 'project'), engine = path.join(directory, 'engine');
  fs.mkdirSync(privateProject); fs.mkdirSync(engine);
  fs.writeFileSync(path.join(privateProject, 'project.godot'), 'config_version=5\n');
  fs.copyFileSync(path.join(project, 'atomic_file.gd'), path.join(privateProject, 'atomic_file.gd'));
  const cases = ['', 'process.stdout.write("illisible")', 'process.stdout.write("x".repeat(2048))'];
  const response = (value, exitCode) => 'process.stdout.write(' + JSON.stringify(JSON.stringify(value)) + ');process.exitCode=' + exitCode;
  for (const exitCode of [0, 1]) {
    for (const ok of [1, 0, 'true', [], {}, null]) cases.push(response({ ok }, exitCode));
    cases.push(response({}, exitCode));
    for (const error of [1, true, [], {}, null, '']) cases.push(response({ ok: false, code: 'EPERM', error }, exitCode));
    for (const code of [1, true, [], {}, null, '']) cases.push(response({ ok: false, code, error: 'Refus' }, exitCode));
  }
  cases.push(response({ ok: true }, 1), response({ ok: true }, 2), response({ ok: false, code: 'EPERM', error: 'Refus' }, 0),
    response({ ok: false, code: 'EPERM', error: 'Refus' }, 2), response({ ok: true, error: 'Réponse contradictoire' }, 0));
  for (const [index, script] of cases.entries()) {
    fs.writeFileSync(path.join(engine, 'atomic-replace.cjs'), script);
    fs.writeFileSync(path.join(directory, 'préférences.json'), 'ancien');
    const run = spawnSync(godot, ['--headless', '--path', privateProject, '--script', path.join(__dirname, 'godot-atomic-file.gd')], {
      env: { ...process.env, CD_ATOMIC_DIRECTORY: directory, CD_NODE_EXECUTABLE: process.execPath, CD_ATOMIC_RESPONSE_FAILURE: '1' }, encoding: 'utf8', windowsHide: true, timeout: 15000
    });
    const output = (run.stdout || '') + (run.stderr || '');
    fs.writeFileSync(path.join(directory, 'case-' + index + '.log'), output);
    if (run.error) throw run.error;
    assert.equal(run.status, 0, 'Réponse ' + index + ' : ' + output); assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  }
  console.log('Protocole : ' + cases.length + ' réponses refusées sans faux succès ; preuves ' + directory);
});
test('Godot Windows : guide readonly conserve octets et état mémoire', { skip: !godot ? 'SDK Godot requis' : process.platform !== 'win32' && 'Attribut Windows requis' }, () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-atomic-guide-'));
  const destination = path.join(directory, 'guide.json');
  fs.writeFileSync(path.join(directory, 'préférences.json'), 'ancien');
  fs.writeFileSync(destination, JSON.stringify({ version: 1, enabled: true, muted: false, voice: '', rate: 1, step: 'bienvenue', completed: [], seen: [], events: [] }));
  fs.chmodSync(destination, 0o444);
  try {
    const run = spawnSync(godot, ['--headless', '--path', project, '--script', path.join(__dirname, 'godot-atomic-file.gd')], {
      env: { ...process.env, CD_ATOMIC_DIRECTORY: directory, CD_NODE_EXECUTABLE: process.execPath, CD_ATOMIC_GUIDE_FAILURE: '1' }, encoding: 'utf8', windowsHide: true, timeout: 15000
    });
    const output = (run.stdout || '') + (run.stderr || '');
    fs.writeFileSync(path.join(directory, 'godot.log'), output); console.log(output.trim());
    if (run.error) throw run.error;
    assert.equal(run.status, 0, output); assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  } finally { fs.chmodSync(destination, 0o666); }
});
