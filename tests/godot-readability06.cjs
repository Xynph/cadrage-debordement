'use strict';
// Freeze the scripts so parallel producers cannot change this run's evidence.
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
test('Lisibilité 0.6 : repères actifs, trois formats, clavier et brouillons intacts', {
  skip: !godot && 'SDK Godot requis',
}, () => {
  const dir = fs.mkdtempSync(path.join(process.env.CD_READABILITY06_TEMP || os.tmpdir(), 'cd-readability06-'));
  const source = path.resolve(__dirname, '../native/godot'), project = path.join(dir, 'godot');
  fs.mkdirSync(project, { recursive: true });
  for (const name of fs.readdirSync(source)) {
    const file = path.join(source, name);
    if (fs.statSync(file).isFile()) fs.copyFileSync(file, path.join(project, name));
  }
  for (const name of ['ui', 'guide', 'audio']) fs.cpSync(path.join(source, name), path.join(project, name), { recursive: true });
  fs.copyFileSync(path.join(__dirname, 'godot-readability06.gd'), path.join(project, 'readability06-test.gd'));
  for (const name of ['assets', 'fonts', 'branding', 'shaders', '.godot']) fs.symlinkSync(path.join(source, name), path.join(project, name), 'junction');
  fs.symlinkSync(path.resolve(source, '../engine'), path.join(dir, 'engine'), 'junction');
  const manifest = {};
  for (const base of ['', 'ui', 'guide', 'audio']) for (const name of fs.readdirSync(path.join(project, base))) {
    const file = path.join(project, base, name);
    if (fs.statSync(file).isFile() && /\.(gd|godot|tscn|json)$/.test(name)) {
      manifest[path.join(base, name)] = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
    }
  }
  fs.writeFileSync(path.join(dir, 'source-manifest.json'), JSON.stringify(manifest, null, 2));
  for (const name of ['AppData/Roaming', 'AppData/Local', 'tmp']) fs.mkdirSync(path.join(dir, name), { recursive: true });
  const result = spawnSync(godot, [
    ...(process.env.CD_READABILITY06_GRAPHICS === '1' ? [] : ['--headless']),
    '--audio-driver', 'Dummy', '--max-fps', '120', '--log-file', path.join(dir, 'runtime.log'), '--path', project,
    '--script', path.join(project, 'readability06-test.gd'),
  ], { env: { ...process.env, APPDATA: path.join(dir, 'AppData/Roaming'), LOCALAPPDATA: path.join(dir, 'AppData/Local'),
    TEMP: path.join(dir, 'tmp'), TMP: path.join(dir, 'tmp'), CD_NODE_EXECUTABLE: process.execPath,
    CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(dir, 'profile'), CD_READABILITY06_ARTIFACTS: dir,
  }, encoding: 'utf8', windowsHide: true, timeout: 180000 });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(dir, 'godot.log'), output);
  console.log(output.trim()); console.log('Preuves lisibilité06 : ' + dir);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  for (const [file, hash] of Object.entries(manifest)) assert.equal(
    crypto.createHash('sha256').update(fs.readFileSync(path.join(project, file))).digest('hex'), hash, file);
});
