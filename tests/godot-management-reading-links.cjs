'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const sdk=process.env.CD_GODOT_EXECUTABLE;
if(!sdk){console.log('SKIP management-reading-links : SDK Godot requis ; aucun parcours reçu.');process.exit(0);}
const output=process.env.CD_MANAGEMENT_READING_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'rg27-management-reading-'));
fs.mkdirSync(output,{recursive:true});
const result=spawnSync(sdk,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-management-reading-links.gd')],
 {encoding:'utf8',timeout:90000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_MANAGEMENT_READING_OUTPUT:output}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves liens de gestion : '+output);
if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
