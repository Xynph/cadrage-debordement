'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { createBridge } = require('../native/engine/worker.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
test('Raccordements natifs06 : vrais boutons, son indépendant et réponse tick avant la file', { skip: !godot && 'SDK Godot requis' }, () => {
  const dir = fs.mkdtempSync(path.join(process.env.CD_NATIVE06_TEMP || os.tmpdir(), 'cd-native06-integration-'));
  const source = path.resolve(__dirname, '../native/godot'), project = path.join(dir, 'godot');
  fs.mkdirSync(project);
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    const from = path.join(source, entry.name), to = path.join(project, entry.name);
    if (entry.isFile()) fs.copyFileSync(from, to);
    else if (['ui', 'guide', 'audio'].includes(entry.name)) fs.cpSync(from, to, { recursive: true });
    else fs.symlinkSync(from, to, 'junction');
  }
  fs.symlinkSync(path.resolve(source, '../engine'), path.join(dir, 'engine'), 'junction');
  fs.copyFileSync(path.join(__dirname, 'godot-native06-integration.gd'), path.join(project, 'native06-integration.gd'));
  const bridge = createBridge({ dataDir: path.join(dir, 'fixture'), seed: 506, now: 1700000000000 });
  let sequence = 0, found = false;
  const call = (command, payload = {}) => {
    const response = bridge.handle({ id: ++sequence, command, payload });
    assert.equal(response.ok, true, command + ': ' + response.error);
    return response.model;
  };
  try {
    call('new_career', { club: 0, mode: 'fiction' });
    let previous = skipMatchTalk(call('begin_match'), call);
    for (let tick = 0; tick < 240; tick++) {
      previous = skipMatchTalk(previous, call);
      const previousProjection = previous;
      const before = call('export').meta.exportText;
      let current = call('tick', { steps: 1 });
      if (!current.live.finished) current = skipMatchTalk(current, call);
      if (current.live && !current.live.paused && !current.live.atBreak && !current.live.finished &&
          ['try', 'goal', 'miss'].includes(current.live.scene.kind) && previous.live.scene.key !== current.live.scene.key) {
        fs.writeFileSync(path.join(dir, 'fixture-before.json'), before);
        fs.writeFileSync(path.join(dir, 'fixture-before-model.json'), JSON.stringify(previousProjection));
        fs.writeFileSync(path.join(dir, 'fixture-event.json'), JSON.stringify(current));
        found = true;
        break;
      }
      if (current.live.paused) previous = call('pause', { paused: false });
      else previous = current;
    }
  } finally { bridge.close(); }
  assert.ok(found, 'Fixture événement typé réellement issue du worker natif');
  const manifest = {};
  for (const base of ['', 'ui', 'guide', 'audio']) for (const name of fs.readdirSync(path.join(project, base))) {
    const file = path.join(project, base, name);
    if (fs.statSync(file).isFile() && /\.(gd|godot|tscn|json)$/.test(name))
      manifest[path.join(base, name)] = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  }
  fs.writeFileSync(path.join(dir, 'source-manifest.json'), JSON.stringify(manifest, null, 2));
  for (const name of ['appdata', 'localappdata', 'tmp']) fs.mkdirSync(path.join(dir, name));
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--log-file', path.join(dir, 'runtime.log'),
    '--path', project, '--script', path.join(project, 'native06-integration.gd')], {
    env: { ...process.env, APPDATA: path.join(dir, 'appdata'), LOCALAPPDATA: path.join(dir, 'localappdata'), TEMP: path.join(dir, 'tmp'), TMP: path.join(dir, 'tmp'),
      CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(dir, 'profile'), CD_NATIVE06_ARTIFACTS: dir },
    encoding: 'utf8', windowsHide: true, timeout: 60000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(dir, 'godot.log'), output);
  console.log(output.trim()); console.log('Preuves raccordements06 : ' + dir);
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
  for (const [file, hash] of Object.entries(manifest)) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(project, file))).digest('hex'), hash, file);
});
