'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Effectif : chaque colonne triable, liste complète et scroll interne sans mutation',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_SQUAD_SORT_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-squad-sort-'));
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'oval-squad-profile-'));fs.mkdirSync(output,{recursive:true});
 const graphics=process.env.CD_SQUAD_SORT_GRAPHICS==='1';
 const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-squad-column-sort.gd')],{
  cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:180000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:profile,CD_SQUAD_SORT_OUTPUT:output}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves tri effectif : '+output);
 if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 const report=JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8'));assert.deepEqual(report.failures,[]);assert.equal(report.profile_unchanged,true);
});
