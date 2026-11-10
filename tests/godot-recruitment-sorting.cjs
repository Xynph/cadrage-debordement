'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('recruitment: every column sorts both ways, full inner scroll, stable identities and no writes',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_RECRUITMENT_SORT_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-recruitment-sorting-'));fs.mkdirSync(output,{recursive:true});
 const graphics=process.env.CD_RECRUITMENT_SORT_GRAPHICS==='1';
 const run=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),
 '--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-recruitment-sorting.gd')],
 {cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:150000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',
 CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-sort-profile-')),CD_RECRUITMENT_SORT_OUTPUT:output}});
 const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves : '+output);
 if(run.error)throw run.error;assert.equal(run.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
