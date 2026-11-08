'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test');
const assert=require('node:assert/strict');
test('Carnet du club : tous menus natifs, vraies actions, focus et lectures sans mutation', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-carnet-ui-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_CARNET_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-carnet-ui.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:root,CD_CARNET_CAPTURES:process.env.CD_CARNET_CAPTURES||root},encoding:'utf8',windowsHide:true,timeout:180000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),output);console.log(output.trim());console.log('Preuves Carnet : '+root);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
