'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const godot = process.env.CD_GODOT_EXECUTABLE;
test('Fatigue : vrais identifiants, seuils communs, filtres et charge confirmée sans séance implicite', {skip:!godot&&'SDK Godot requis'}, () => {
 const profile = fs.mkdtempSync(path.join(os.tmpdir(),'oval-fatigue-profile-'));
 const output = process.env.CD_FATIGUE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(),'oval-fatigue-reception-'));
 fs.mkdirSync(output,{recursive:true});
 const graphics = process.env.CD_FATIGUE_GRAPHICS === '1';
 const result = spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),
  '--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-fatigue-overview.gd')],{
   cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:150000,
   env:{...process.env,CD_GODOT_DATA_DIR:profile,CD_NODE_EXECUTABLE:process.execPath,CD_FATIGUE_OUTPUT:output,CD_GODOT_SELF_TEST:'0'},
  });
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Réception fatigue : '+output);
 if(result.error)throw result.error;
 assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
