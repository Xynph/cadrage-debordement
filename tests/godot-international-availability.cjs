'use strict';
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const {test} = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE;
test('international availability: real routes, player identity, coverage and no career writes', {
  skip:!godot && 'SDK Godot requis',
},()=>{
  const output = process.env.CD_INTERNATIONAL_AVAILABILITY_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(),'oval-international-availability-'));
  fs.mkdirSync(output,{recursive:true});
  const graphics=process.env.CD_INTERNATIONAL_AVAILABILITY_GRAPHICS==='1';
  const resolution=process.env.QA_RESOLUTION || '1920x1080';
  assert.match(resolution,/^(1280x720|1920x1080|2560x1440)$/);
  const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution',resolution]:['--headless']),
    '--audio-driver','Dummy','--max-fps','60','--path','native/godot','--script',path.resolve(__dirname,'godot-international-availability.gd')],
    {cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:150000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',
      CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-availability-profile-')),
      CD_INTERNATIONAL_AVAILABILITY_OUTPUT:output,QA_RESOLUTION:resolution}});
  const log=(result.stdout||'')+(result.stderr||'');
  fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves : '+output);
  if(result.error)throw result.error;
  assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
