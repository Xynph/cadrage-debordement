'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Tactique existante : aptitude au numéro, effectif, clavier et glisser-déposer',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_TACTICS_DRAG_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-tactics-drag-'));fs.mkdirSync(output,{recursive:true});
 const graphics=process.env.CD_TACTICS_DRAG_GRAPHICS==='1';
 const env={...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-tactics-profile-')),CD_TACTICS_DRAG_OUTPUT:output};
 for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=path.join(output,key.toLowerCase());fs.mkdirSync(env[key],{recursive:true});}
 const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-tactics-position-drag.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:180000,env});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves tactique : '+output);if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
