'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const sdk=process.env.CD_GODOT_EXECUTABLE;
if(!sdk){console.log('SKIP management-reading-flow : SDK Godot requis ; aucune qualification de retour modal.');process.exit(0);}
const output=process.env.CD_MANAGEMENT_READING_FLOW_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'rg27-management-reading-flow-'));
fs.mkdirSync(output,{recursive:true});
const graphics=process.env.CD_MANAGEMENT_READING_FLOW_GRAPHICS==='1';
const result=spawnSync(sdk,[...(graphics?[]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-management-reading-flow.gd')],
 {encoding:'utf8',timeout:150000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'0',CD_GODOT_DATA_DIR:path.join(output,'profile'),CD_MANAGEMENT_READING_FLOW_OUTPUT:output}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves parcours gestion : '+output);
if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
