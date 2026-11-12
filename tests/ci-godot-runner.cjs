'use strict';
// Lanceurs de la CI : shards « Suites » en parallèle (ci/run-shard-suites.sh), détection
// uniforme du SDK Godot (ci/godot-env.cjs) et refus des suites qui se sautent faute de
// moteur (ci/run-godot-suites.sh). Faux exécutable, aucun SDK requis.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { resolveGodot, applyGodotEnv } = require('../ci/godot-env.cjs');

// Noms construits pour que ce fichier ne soit pas lui-même classé « suite Godot ».
const EXE = 'CD_GODOT_' + 'EXE', EXECUTABLE = 'CD_GODOT_' + 'EXECUTABLE';
const root = path.resolve(__dirname, '..');
const unix = process.platform !== 'win32';

test('les deux variables désignent le même SDK, l’une suffit', () => {
  for (const name of [EXE, EXECUTABLE]) {
    const env = { [name]: '/opt/godot' };
    assert.equal(applyGodotEnv(env), '/opt/godot');
    assert.equal(env[EXE], '/opt/godot');
    assert.equal(env[EXECUTABLE], '/opt/godot');
  }
  assert.equal(resolveGodot({}), null);
  assert.equal(resolveGodot({ [EXE]: '/a', [EXECUTABLE]: '/a' }), '/a');
  assert.throws(() => resolveGodot({ [EXE]: '/a', [EXECUTABLE]: '/b' }), /deux exécutables différents/);
  assert.throws(() => applyGodotEnv({ CD_GODOT_REQUIRED: '1' }), /SDK Godot requis/);
  assert.throws(() => applyGodotEnv({ CD_GODOT_REQUIRED: '1', [EXE]: path.join(os.tmpdir(), 'absent-godot') }), /absent ou non exécutable/);
  assert.equal(applyGodotEnv({}), null, 'Hors CI stricte, l’absence reste permise');
});

test('préchargé, le module transmet le SDK aux suites qui ne lisent qu’une variable', () => {
  const run = spawnSync(process.execPath, ['--require', path.join(root, 'ci/godot-env.cjs'), '-e',
    'console.log(process.env.' + EXE + '+"|"+process.env.' + EXECUTABLE + ')'],
  { encoding: 'utf8', env: { ...process.env, [EXE]: '', [EXECUTABLE]: '/opt/godot-4.7.2' } });
  assert.equal(run.status, 0, run.stderr);
  assert.equal(run.stdout.trim(), '/opt/godot-4.7.2|/opt/godot-4.7.2');
});

test('le lanceur Godot échoue sur un saut faute de moteur et accepte les vraies réussites', { skip: !unix && 'bash POSIX requis' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-godot-runner-'));
  try {
    const fake = path.join(dir, 'godot');
    fs.writeFileSync(fake, '#!/bin/sh\necho "4.7.2.stable.official.faux"\n', { mode: 0o755 });
    const suite = (name, body) => { const file = path.join(dir, name + '.cjs'); fs.writeFileSync(file, body); return file; };
    const ok = suite('ok', "console.log('ok 1 - rendu natif');\n");
    const skipped = suite('saute', "console.log('ok 1 - réception # SKIP SDK Godot requis');\n");
    const manual = suite('manuel', "console.log('SKIP outil-capture : outil manuel (CD_CAPTURE absent).');\n");
    const failing = suite('rouge', 'process.exit(3);\n');
    const runList = (files, extra = {}) => {
      const list = path.join(dir, 'liste-' + files.length + '-' + Math.random().toString(16).slice(2) + '.txt');
      fs.writeFileSync(list, files.join('\n') + '\n');
      const summary = path.join(dir, 'resume-' + path.basename(list) + '.md');
      const result = spawnSync('bash', [path.join(root, 'ci/run-godot-suites.sh'), list, 'Essai'], {
        encoding: 'utf8', timeout: 60000,
        env: { ...process.env, [EXE]: '', [EXECUTABLE]: fake, GITHUB_STEP_SUMMARY: summary, NODE_OPTIONS: '', ...extra }
      });
      return { ...result, summary: fs.existsSync(summary) ? fs.readFileSync(summary, 'utf8') : '' };
    };
    let r = runList([ok, manual]);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /PASS .*ok\.cjs/);
    assert.match(r.stdout, /CD_CPU_PROFILE suite=.*ok\.cjs .*wall_s=/);
    assert.match(r.summary, /Essai : 2 suites, 0 échec/);
    r = runList([ok, skipped]);
    assert.equal(r.status, 1);
    assert.match(r.summary, /saute\.cjs \| ECHEC \(saut faute de moteur\)/);
    r = runList([failing]);
    assert.equal(r.status, 1);
    assert.match(r.summary, /rouge\.cjs \| ECHEC \(3\)/);
    r = runList([ok], { [EXECUTABLE]: path.join(dir, 'absent') });
    assert.notEqual(r.status, 0, 'SDK absent : le job échoue avant toute suite');
    assert.doesNotMatch(r.stdout, /PASS /);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('le lanceur de shard exécute en parallèle, garde chaque journal et compte les échecs', { skip: !unix && 'bash POSIX requis' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-shard-runner-'));
  try {
    const suite = (name, body) => { const file = path.join(dir, name + '.cjs'); fs.writeFileSync(file, body); return file; };
    const slow = suite('lente', "setTimeout(()=>console.log('fin lente'),800);\n");
    const quick = suite('rapide', "console.log('fin rapide');\n");
    const red = suite('rouge', 'process.exit(4);\n');
    const run = (files, parallel) => {
      const list = path.join(dir, 'liste-' + parallel + '-' + files.length + '.txt');
      const summary = list + '.md';
      fs.writeFileSync(list, files.join('\n') + '\n');
      const r = spawnSync('bash', [path.join(root, 'ci/run-shard-suites.sh'), list, 'Essai', String(parallel)], {
        encoding: 'utf8', timeout: 60000, env: { ...process.env, GITHUB_STEP_SUMMARY: summary } });
      return { ...r, summary: fs.existsSync(summary) ? fs.readFileSync(summary, 'utf8') : '' };
    };
    let r = run([slow, quick], 2);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    // La lente démarre la première mais la rapide termine avant elle : vraie exécution parallèle.
    assert.ok(r.stdout.indexOf('PASS ' + quick) < r.stdout.indexOf('PASS ' + slow), r.stdout);
    assert.match(r.stdout, /::group::.*lente\.cjs\nfin lente\n/);
    assert.match(r.stdout, /CD_CPU_PROFILE suite=.*rapide\.cjs .*wall_s=/);
    assert.match(r.summary, /Essai : 2 suites sur \d+ \(2 en parallèle, mémoire réservée max \d+\/\d+ Mo, délais 100 %\)/);
    r = run([slow, red, quick], 2);
    assert.equal(r.status, 1);
    assert.match(r.summary, /rouge\.cjs \| ECHEC \(4\)/);
    assert.match(r.summary, /Échecs : 1/);
    assert.equal(run([quick], 9).status, 2, 'Parallélisme borné');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
