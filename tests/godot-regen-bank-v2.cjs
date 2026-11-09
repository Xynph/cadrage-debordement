'use strict';
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {describe}=require('../native/engine/portraits.cjs');
test('Godot loads all200 catalogued bases with exact source crops and bounded caches',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const catalogue=require('../native/godot/art/regen-bank-v2/catalogue.json'),found=new Map();
 for(let i=0;i<10000&&found.size<200;i++){
  for(const person of [{id:'bank:sample:'+i,appearanceBankVersion:2,age:21},...[40,50,60,70].map(age=>({id:'staff:sample:'+i,appearanceBankVersion:2,portraitRole:'staff',appearanceAge:age,age}))]){
   const profile=describe(person);if(!found.has(profile.baseId))found.set(profile.baseId,{person,profile});
  }
 }
 a.equal(found.size,200);const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-regen-bank-'));
 const rows=catalogue.bases.map(base=>{const asset=catalogue.assets.find(x=>x.id===base.asset);return {...found.get(base.id),base,asset,absoluteAsset:path.resolve(__dirname,'..',asset.file)};});
 const fixtures=path.join(directory,'bases.json');fs.writeFileSync(fixtures,JSON.stringify(rows));const graphics=process.env.CD_REGEN_BANK_GRAPHICS==='1';
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility']:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-regen-bank-v2.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_REGEN_BANK_FIXTURES:fixtures,CD_REGEN_BANK_OUTPUT:directory},encoding:'utf8',timeout:90000});
 const output=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output.trim());console.log('Preuves banque200 : '+directory);if(r.error)throw r.error;a.equal(r.status,0,output);a.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
});
