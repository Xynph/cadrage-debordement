'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),art=path.join(root,'native/godot/art/immersive08');
assert.ok(fs.existsSync(path.join(art,'manifest.json')),'Les illustrations approuvées doivent être intégrées comme assets indépendants');
const manifest=JSON.parse(fs.readFileSync(path.join(art,'manifest.json'),'utf8'));
for(const weight of ['Medium','SemiBold','Bold','ExtraBold']){
 const fonts=weight==='SemiBold'?'native/godot/fonts':'native/godot/ui/immersive08/fonts';
 const file='BarlowCondensed-'+weight+'.ttf';
 assert.deepEqual(fs.readFileSync(path.join(root,fonts,file)),fs.readFileSync(path.join(root,'dist/fonts',file)),'Font exact de la référence : '+weight);
}
assert.deepEqual(fs.readFileSync(path.join(root,'native/godot/fonts/DMSans.ttf')),fs.readFileSync(path.join(root,'dist/fonts/DMSans-Variable.ttf')),'DM Sans exact de la référence');
const generated=fs.existsSync(path.join(art,'generated-manifest.json'))?JSON.parse(fs.readFileSync(path.join(art,'generated-manifest.json'),'utf8')).assets:[];
assert.equal(manifest.schema,'oval-immersive-art-v1');
assert.equal(manifest.assets.length,new Set(manifest.assets.map(a=>a.id)).size,'IDs uniques');
assert.ok(manifest.assets.length>=18,'Une bibliothèque illustrée, pas une seule capture de menu');
for(const id of ['brand','office-hero','tactics-briefing','training-session','stadium','academy-training','trophy','scouting','hospitality','forest','player-hero','recruit-profile','mail-staff'])assert.ok(manifest.assets.some(a=>a.id===id),'Illustration '+id);
const sources=new Set();
for(const a of [...manifest.assets,...generated]){
 assert.match(a.file,/^[a-z0-9-]+\.png$/);assert.match(a.source_sha256,/^[a-f0-9]{64}$/);
 assert.equal(a.synthetic,true,'Provenance IA explicite');assert.equal(a.crop.length,4);
 const data=fs.readFileSync(path.join(art,a.file));assert.equal(data.subarray(1,4).toString(),'PNG');
 assert.equal(data.readUInt32BE(16),a.width);assert.equal(data.readUInt32BE(20),a.height);
 assert.equal(crypto.createHash('sha256').update(data).digest('hex'),a.sha256,'Empreinte '+a.id);
 assert.equal(data.length,a.bytes);assert.ok(a.width>=24&&a.height>=24);if(a.sourceType!=='generated')sources.add(a.source);
 if(['generated','mockup'].includes(a.sourceType))assert.ok(a.prompt?.length>100&&a.tool==='built-in image_gen','Prompt et outil conservés pour les nouvelles images');
}
assert.equal(sources.size,13,'Les deux nouvelles maquettes complètent les onze références précédentes');
console.log(`Illustrations immersive08 : ${manifest.assets.length+generated.length} PNG vérifiés, treize références, empreintes et provenance.`);
const territory=path.join(root,'native/godot/art/territories');
const territoryAssets=JSON.parse(fs.readFileSync(path.join(territory,'provenance.json'),'utf8')).assets;
const territorySlots=[];
for(const asset of territoryAssets){
 assert.ok(asset.prompt.length>100,'Prompt de '+asset.file);
 const data=fs.readFileSync(path.join(territory,asset.file));
 assert.equal(crypto.createHash('sha256').update(data).digest('hex'),asset.sha256,'Empreinte de '+asset.file);
 if(asset.clubs){
  for(const id of asset.clubs)territorySlots.push(id+'-city',id+'-stadium');
 }else territorySlots.push(path.basename(asset.file,'.png'));
}
const expectedSlots=Array.from({length:116},(_,id)=>[id+'-city',id+'-stadium']).flat();
assert.deepEqual(territorySlots.sort(),expectedSlots.sort(),'Une illustration de ville et de stade pour les 116 clubs');
if(process.argv.includes('--art-only'))process.exit(0);
const {spawnSync}=require('node:child_process'),os=require('node:os');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){require('node:test')('Réception native immersive08',{skip:'SDK Godot absent de cet environnement'},()=>{});return;}
assert.ok(fs.existsSync(godot),'SDK Godot configuré mais introuvable');
for(const script of ['components','shell'].filter(id=>fs.existsSync(path.join(root,'native/godot/ui/immersive08',id+'.gd')))){
 const parsed=spawnSync(godot,['--headless','--path',path.join(root,'native/godot'),'--check-only','--script','res://ui/immersive08/'+script+'.gd'],{encoding:'utf8',windowsHide:true,timeout:30000});
 assert.equal(parsed.status,0,(parsed.stdout||'')+(parsed.stderr||''));
}
const dir=fs.mkdtempSync(path.join(process.env.TEMP||os.tmpdir(),'oval-immersive08-'));
fs.mkdirSync(path.join(dir,'profile'));
const result=spawnSync(godot,[...(process.env.CD_IMMERSIVE_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--path',path.join(root,'native/godot'),'--script',path.join(__dirname,'godot-immersive08.gd'),'--log-file',path.join(dir,'runtime.log')],{encoding:'utf8',windowsHide:true,timeout:400000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'profile'),CD_IMMERSIVE_ARTIFACTS:dir}});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'test.log'),output);
console.log(output.trim());console.log('Preuves immersive08 : '+dir);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
