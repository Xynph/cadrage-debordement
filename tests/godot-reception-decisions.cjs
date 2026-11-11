'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
test('Réception 1440p : décisions explicites, groupes, filtres et retour clavier sans écriture', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, () => {
  const output = process.env.CD_RECEPTION_DECISIONS_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'oval-reception-decisions-'));
  fs.mkdirSync(output, { recursive: true });
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-reception-profile-'));
  const graphics = process.env.CD_RECEPTION_DECISIONS_GRAPHICS === '1';
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(graphics ? ['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440'] : ['--headless']),
    '--audio-driver','Dummy','--max-fps','60','--path','native/godot',
    '--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-reception-decisions.gd'),
  ], {
    cwd: path.resolve(__dirname,'..'), encoding:'utf8', timeout:180000,
    env: { ...process.env, CD_GODOT_SELF_TEST:'0', CD_GODOT_GUIDE_MODULE_TEST:'1',
      CD_GODOT_DATA_DIR:profile, CD_NODE_EXECUTABLE:process.execPath, CD_RECEPTION_DECISIONS_OUTPUT:output },
  });
  const log = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(output,'godot.log'),log); console.log(log.trim()); console.log('Preuves Réception : '+output);
  if (result.error) throw result.error;
  assert.equal(result.status,0,log); assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
