'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP godot-club-memory : SDK Godot absent ; aucun profil créé, réception native non exécutée.');process.exit(0);}
assert.ok(fs.existsSync(path.join(__dirname,'../native/godot/ui/club_memory_view.gd')),'Vue Histoire du club à implémenter');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-club-memory-')),b=createBridge({dataDir:root,seed:827381,now:1700000000000});let id=0,multiBridge;
const good=(command,payload={})=>{const r=b.handle({id:++id,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
try{
 const model=good('import',{text:zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/roster-foundation-v1-s2.json.gz'))).toString()});
 assert.equal(model.archives.seasons.length,1);assert.equal(model.archives.seasons[0].season,1);
 multiBridge=createBridge({dataDir:path.join(root,'multiseason'),seed:827381,now:1700000000000});
 const checkpoint=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/france-long-career-s6.json.gz'))).toString()).checkpoint.save;
 const multi=multiBridge.handle({id:1,command:'import',payload:{text:JSON.stringify(checkpoint)}});assert.equal(multi.ok,true,multi.error);assert.equal(multi.model.archives.seasons.length,5,'Cinq vraies archives du checkpoint S6');
 const multiDisk=path.join(root,'multiseason','PrototypeGodot','donnees.json'),multiBytes=fs.readFileSync(multiDisk),multiBefore=multiBridge.handle({id:2,command:'export'}).model.meta.exportText;
 const multiFixture=path.join(root,'multi.json');fs.writeFileSync(multiFixture,JSON.stringify(multi.model));
 const before=good('export').meta.exportText,disk=path.join(root,'PrototypeGodot','donnees.json'),bytes=fs.readFileSync(disk);
 const fixture=path.join(root,'model.json');fs.writeFileSync(fixture,JSON.stringify(model));
 const run=spawnSync(godot,[...(process.env.CD_CLUB_MEMORY_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-club-memory.gd')],{windowsHide:true,encoding:'utf8',timeout:90000,env:{...process.env,CD_CLUB_MEMORY_MODEL:fixture,CD_CLUB_MEMORY_MULTI:multiFixture,CD_CLUB_MEMORY_ARTIFACTS:root}});
 const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves Histoire du club : '+root);
 if(run.error)throw run.error;assert.equal(run.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.deepEqual(good('snapshot').archives,model.archives);assert.equal(good('export').meta.exportText,before,'Aucune mutation du modèle canonique / RNG');assert.deepEqual(fs.readFileSync(disk),bytes,'Aucune écriture de sauvegarde en consultation');
 assert.equal(multiBridge.handle({id:3,command:'export'}).model.meta.exportText,multiBefore,'S6 sans mutation S/RNG');assert.deepEqual(fs.readFileSync(multiDisk),multiBytes,'S6 sans écriture de sauvegarde');
 const historical=good('new_career',{club:0,mode:'fiction'});assert.deepEqual(historical.archives.seasons,[],'Ancienne ligue à 14 : aucun passé reconstruit');
 console.log('Mémoire du club : fixtures worker S2/S6, projection/UI, pureté S/RNG/disque et ancien format PASS');
}finally{b.close();if(multiBridge)multiBridge.close();}
