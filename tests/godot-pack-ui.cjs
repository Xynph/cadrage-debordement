'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const {test}=require('node:test');
test('Godot : packs personnalisés à la création et en carrière',{
 skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot absent ; réception native exécutée séparément.',
},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-pack-ui-'));
 const image=path.join(directory,'image.webp');
 fs.copyFileSync(path.resolve(__dirname,'../native/godot/assets/editorial/portraits-0.webp'),image);
 const database=require('../dist/rugby-common-rosters.js'),{crc32}=require('../native/engine/media-packs.cjs');
 const manifest=Buffer.from(JSON.stringify({schema:'cd-identity-pack-v1',id:'ui-edge',name:'Univers de réception',version:'1',databaseId:database.id,rightsStatus:'test-local',clubs:[{id:0,name:'Club de réception',abbr:'REC'}],players:[],assets:[]}));
 const name=Buffer.from('pack.json'),local=Buffer.alloc(30),central=Buffer.alloc(46),end=Buffer.alloc(22),crc=crc32(manifest);
 local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt32LE(crc,14);local.writeUInt32LE(manifest.length,18);local.writeUInt32LE(manifest.length,22);local.writeUInt16LE(name.length,26);
 central.writeUInt32LE(0x02014b50);central.writeUInt16LE(20,4);central.writeUInt16LE(20,6);central.writeUInt32LE(crc,16);central.writeUInt32LE(manifest.length,20);central.writeUInt32LE(manifest.length,24);central.writeUInt16LE(name.length,28);
 end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,8);end.writeUInt16LE(1,10);end.writeUInt32LE(central.length+name.length,12);end.writeUInt32LE(local.length+name.length+manifest.length,16);
 const valid=path.join(directory,'valid.zip'),invalid=path.join(directory,'invalid.zip');
 fs.writeFileSync(valid,Buffer.concat([local,name,manifest,central,name,end]));fs.writeFileSync(invalid,'ZIP invalide');
 const args=[...(process.env.CD_GODOT_PACK_GRAPHICS==='1'?['--position','-4000,-4000']:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-pack-ui.gd')];
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,args,{
  cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:directory,CD_GODOT_PACK_TEST_IMAGE:image,CD_GODOT_PACK_EDGE_VALID:valid,CD_GODOT_PACK_EDGE_INVALID:invalid},encoding:'utf8',timeout:150000,windowsHide:true,
 });
 const output=(result.stdout||'')+(result.stderr||'');
 console.log(output.trim());
 if(result.error)throw result.error;
 if(result.status!==0||/SCRIPT ERROR|Parse Error|ERROR:/.test(output))throw Error('Réception packs native échouée ; profil de preuve : '+directory);
});
