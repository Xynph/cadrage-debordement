'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('preparation briefing: genuine actions, mandatory press, unknown data and read-only navigation', {skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_PREPARATION_BRIEFING_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-preparation-briefing-'));
 fs.mkdirSync(output,{recursive:true});
 const graphics=process.env.CD_PREPARATION_BRIEFING_GRAPHICS==='1';
 const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),
 '--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-preparation-briefing.gd')],
 {cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:150000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',
 CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-briefing-profile-')),CD_PREPARATION_BRIEFING_OUTPUT:output}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves : '+output);
 if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
