'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const {test}=require('node:test');
test('Régressions natives Godot : disque, UI, limites et transport',{
 skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot absent : réception Windows exécutée séparément, définir CD_GODOT_EXECUTABLE pour ces 33 contrôles.',
},()=>{
let failed=false;
for(const mode of ['disk','ui','limits','null-response']){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-review-'+mode+'-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-review-regressions.gd')],{
  cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:dir,CD_GODOT_REGRESSION:mode},encoding:'utf8',timeout:45000,windowsHide:true,
 });
 const output=(result.stdout||'')+(result.stderr||'');
 console.log('MODE '+mode+' exit='+result.status+'\n'+output.trim());
 if(result.error)console.error(result.error);
 if(result.status!==0||/SCRIPT ERROR|Parse Error|ERROR:/.test(output))failed=true;
 fs.rmSync(dir,{recursive:true,force:true});
}
if(failed)throw Error('Régression native Godot échouée');
});
