'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const {test}=require('node:test');
test('Godot : packs personnalisés à la création et en carrière',{
 skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot absent ; réception native exécutée séparément.',
},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-pack-ui-'));
 const image=path.join(directory,'image.webp');
 fs.copyFileSync(path.resolve(__dirname,'../native/godot/assets/editorial/portraits-0.webp'),image);
 const args=[...(process.env.CD_GODOT_PACK_GRAPHICS==='1'?['--position','-4000,-4000']:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-pack-ui.gd')];
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,args,{
  cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:directory,CD_GODOT_PACK_TEST_IMAGE:image},encoding:'utf8',timeout:150000,windowsHide:true,
 });
 const output=(result.stdout||'')+(result.stderr||'');
 console.log(output.trim());
 if(result.error)throw result.error;
 if(result.status!==0||/SCRIPT ERROR|Parse Error|ERROR:/.test(output))throw Error('Réception packs native échouée ; profil de preuve : '+directory);
});
