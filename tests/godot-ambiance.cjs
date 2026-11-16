'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Sifflets de foule : WAV déterministe, discret, publié égal au générateur',()=>{
 const {buildCrowd}=require('../scripts/build-native-crowd.cjs');
 const first=buildCrowd(),second=buildCrowd();
 assert.deepEqual(Object.keys(first),['crowd-whistle.wav']);
 const wave=first['crowd-whistle.wav'];assert.deepEqual(wave,second['crowd-whistle.wav']);
 assert.equal(wave.toString('ascii',0,4),'RIFF');assert.equal(wave.readUInt16LE(22),2);assert.equal(wave.readUInt32LE(40),wave.length-44);
 let peak=0;for(let n=44;n<wave.length;n+=2)peak=Math.max(peak,Math.abs(wave.readInt16LE(n)/32768));
 assert.ok(peak>0.01&&peak<=0.16,'pic sans clipping');
 assert.equal(wave.readInt16LE(44),0);assert.equal(wave.readInt16LE(wave.length-2),0);
 const dir=path.join(__dirname,'../native/godot/audio/assets');
 assert.deepEqual(fs.readFileSync(path.join(dir,'crowd-whistle.wav')),wave,'asset publié égal au générateur');
 const manifest=JSON.parse(fs.readFileSync(path.join(dir,'crowd-manifest.json'),'utf8'));
 assert.equal(manifest.third_party_assets,false);assert.equal(manifest.sounds[0].sha256,crypto.createHash('sha256').update(wave).digest('hex'));
});
test('Musique : aucun fichier de plus de 3 Mo, uniquement OGG, dans audio/music',()=>{
 const dir=path.join(__dirname,'../native/godot/audio/music');
 if(!fs.existsSync(dir))return;
 for(const f of fs.readdirSync(dir).filter(n=>!n.endsWith('.import')&&n!=='.gitkeep')){assert.match(f,/\.ogg$/,f+' en OGG');assert.ok(fs.statSync(path.join(dir,f)).size<3*1024*1024,f+' < 3 Mo');}
});
test('Ambiance native : bus Musique, musique coupée en match, foule selon le camp',{skip:!godot&&'SDK Godot requis'},()=>{
 const base=process.env.CD_SOUNDS_PROOF||os.tmpdir();fs.mkdirSync(base,{recursive:true});
 const proof=fs.mkdtempSync(path.join(base,'cd-ambiance-é '));
 const run=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-ambiance.gd')],{env:{...process.env,CD_AMBIANCE_PROOF:proof,CD_NODE_EXECUTABLE:process.execPath},encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
});
// Captures (rendu graphique) : CD_AMBIANCE_CAPTURE=<dossier> ; sans cette variable, rien n'est lancé.
// Onglet Son des paramètres : trois cases et volume Musique, case « Musique » cochée puis décochée.
test('Ambiance native : captures des paramètres audio (CD_AMBIANCE_CAPTURE)',{skip:(!godot&&'SDK Godot requis')||(!process.env.CD_AMBIANCE_CAPTURE&&'CD_AMBIANCE_CAPTURE absent')},()=>{
 const dossier=path.resolve(process.env.CD_AMBIANCE_CAPTURE);fs.mkdirSync(dossier,{recursive:true});
 const racine=fs.mkdtempSync(path.join(os.tmpdir(),'cd-ambiance-capture-'));
 const run=spawnSync(godot,['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','1920x1080','--max-fps','120','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-ambiance.gd')],{
  env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(racine,'PrototypeGodot'),CD_AMBIANCE_CAPTURE:dossier},encoding:'utf8',windowsHide:true,timeout:420000});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;assert.equal(run.status,0,output);
 assert.match(output,/AMBIANCE CAPTURES\s*:\s*\d+ vérifications, 0 échec/);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);
 assert.ok(fs.readdirSync(dossier).filter(f=>f.endsWith('.jpg')).length>=1,'1 capture PNG au moins attendue');
});
