'use strict';
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { Worker } = require('node:worker_threads');
const { once } = require('node:events');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { replaceStaged } = require('../native/engine/atomic-replace.cjs');
const cli = path.resolve(__dirname, '../native/engine/atomic-replace.cjs');
function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-atomic-é '));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const source = path.join(directory, 'préférences temporaires.json');
  const destination = path.join(directory, 'préférences.json');
  fs.writeFileSync(source, 'nouveau'); fs.writeFileSync(destination, 'ancien');
  return { directory, source, destination };
}
test('remplacement et création : chemins avec espaces et accents', t => {
  const { source, destination } = fixture(t);
  assert.deepEqual(replaceStaged(source, destination), { ok: true });
  assert.equal(fs.readFileSync(destination, 'utf8'), 'nouveau');
  assert.equal(fs.existsSync(source), false);
  fs.writeFileSync(source, 'initial');
  assert.deepEqual(replaceStaged(source, destination + '.nouveau'), { ok: true });
});
test('refus valident les chemins et préservent les deux fichiers', t => {
  const { directory, source, destination } = fixture(t);
  const other = path.join(directory, 'autre'); fs.mkdirSync(other);
  for (const [from, to] of [[source, source], ['relative', destination], [source, 'relative'],
    [source + '.absent', destination], [directory, destination], [source, directory],
    [source, path.join(other, 'sortie')], ['https://example.com/a', destination]]) {
    const result = replaceStaged(from, to);
    assert.equal(result.ok, false);
    assert.match(result.code, /^[A-Z_]+$/);
    assert.equal(fs.readFileSync(destination, 'utf8'), 'ancien');
    assert.equal(fs.readFileSync(source, 'utf8'), 'nouveau');
  }
});
test('CLI : JSON borné sans contenu ni chemin dans les erreurs', t => {
  const { source, destination } = fixture(t);
  const bad = spawnSync(process.execPath, [cli, source + '.secret', destination], { encoding: 'utf8', windowsHide: true });
  assert.equal(bad.status, 1); assert.equal(bad.stderr, '');
  assert.equal(JSON.parse(bad.stdout).ok, false);
  assert.ok(bad.stdout.length < 512); assert.ok(!bad.stdout.includes(source));
  const good = spawnSync(process.execPath, [cli, source, destination], { encoding: 'utf8', windowsHide: true });
  assert.equal(good.status, 0); assert.deepEqual(JSON.parse(good.stdout), { ok: true });
});
test('CLI : erreur française en ASCII et aller-retour intact avec chemins accentués', t => {
  const { directory, source, destination } = fixture(t);
  const other = path.join(directory, 'autre dossier accentué'); fs.mkdirSync(other);
  const rejected = path.join(other, 'préférences.json');
  const expected = replaceStaged(source, rejected);
  assert.match(expected.error, /même dossier/);
  const run = spawnSync(process.execPath, [cli, source, rejected], { encoding: 'utf8', windowsHide: true });
  assert.equal(run.status, 1); assert.equal(run.stderr, '');
  assert.match(run.stdout, /^[\x00-\x7f]*$/);
  assert.deepEqual(JSON.parse(run.stdout), expected);
  assert.ok(!run.stdout.includes(source) && !run.stdout.includes('nouveau') && !run.stdout.includes('ancien'));
  assert.equal(fs.readFileSync(destination, 'utf8'), 'ancien');
  assert.equal(fs.readFileSync(source, 'utf8'), 'nouveau');
});
test('80 remplacements avec lecteur concurrent : aucun trou ni JSON partiel', async t => {
  const { source, destination } = fixture(t);
  const payload = 'é'.repeat(4096);
  fs.writeFileSync(destination, JSON.stringify({ sequence: 0, payload }));
  const control = new SharedArrayBuffer(4);
  const reader = new Worker(path.join(__dirname, 'godot-atomic-file-reader.cjs'), { workerData: { destination, control } });
  t.after(() => reader.terminate());
  assert.deepEqual(await once(reader, 'message'), ['ready']);
  const finished = once(reader, 'message');
  let successful = 0, refused = 0;
  try {
    for (let attempt = 0; successful < 80 && attempt < 1600; attempt++) {
      const sequence = successful + 1;
      fs.writeFileSync(source, JSON.stringify({ sequence, payload }));
      const result = replaceStaged(source, destination);
      if (result.ok) successful++;
      else {
        refused++;
        assert.equal(JSON.parse(fs.readFileSync(destination, 'utf8')).sequence, successful, 'Refus explicite conserve l’original');
        assert.equal(JSON.parse(fs.readFileSync(source, 'utf8')).sequence, sequence, 'Refus conserve le temporaire');
      }
    }
  } finally { Atomics.store(new Int32Array(control), 0, 1); }
  const [result] = await finished;
  console.log('Lecteur Node : ' + JSON.stringify({ ...result, successful, refused }));
  assert.equal(successful, 80);
  assert.ok(result.samples > 80); assert.equal(result.missing + result.invalid + result.other, 0);
  assert.equal(JSON.parse(fs.readFileSync(destination, 'utf8')).sequence, 80);
});
test('Windows : destination réellement en lecture seule conservée', { skip: process.platform !== 'win32' && 'Attribut Windows requis' }, t => {
  const { source, destination } = fixture(t);
  fs.chmodSync(destination, 0o444);
  try {
    assert.equal(replaceStaged(source, destination).ok, false);
    assert.equal(fs.readFileSync(destination, 'utf8'), 'ancien');
    assert.equal(fs.readFileSync(source, 'utf8'), 'nouveau');
  } finally { fs.chmodSync(destination, 0o666); }
});
test('Windows : lecteur sans partage DELETE conserve original et temporaire', { skip: process.platform !== 'win32' && 'Partage Windows requis', timeout: 15000 }, async t => {
  const { source, destination } = fixture(t);
  const lock = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command',
    '$f=[System.IO.File]::Open($env:CD_ATOMIC_LOCK,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read); try { [Console]::WriteLine("READY"); [Console]::Out.Flush(); [Console]::ReadLine() | Out-Null } finally { $f.Dispose() }'],
  { env: { ...process.env, CD_ATOMIC_LOCK: destination }, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
  t.after(() => { if (lock.exitCode === null) lock.kill(); });
  const [ready] = await once(lock.stdout, 'data'); assert.match(String(ready), /READY/);
  try {
    assert.equal(replaceStaged(source, destination).ok, false);
    assert.equal(fs.readFileSync(destination, 'utf8'), 'ancien');
    assert.equal(fs.readFileSync(source, 'utf8'), 'nouveau');
  } finally { lock.stdin.end('\n'); }
  const [code] = await once(lock, 'exit'); assert.equal(code, 0);
});
