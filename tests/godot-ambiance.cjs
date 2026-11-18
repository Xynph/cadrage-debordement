'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Sifflets de foule et bruits de match : WAV déterministes, discrets, petits, publiés égaux au générateur',()=>{
 const {buildCrowd}=require('../scripts/build-native-crowd.cjs');
 const first=buildCrowd(),second=buildCrowd();
 assert.deepEqual(Object.keys(first),['crowd-whistle.wav','referee-whistle.wav','referee-whistle-long.wav','crowd-murmur.wav','crowd-groan.wav','crowd-applause.wav','impact-tackle.wav','impact-scrum.wav','kick-pock.wav']);
 const dir=path.join(__dirname,'../native/godot/audio/assets');
 const manifest=JSON.parse(fs.readFileSync(path.join(dir,'crowd-manifest.json'),'utf8'));
 assert.equal(manifest.third_party_assets,false);
 // Sifflets de foule d'origine : octets inchangés.
 assert.equal(crypto.createHash('sha256').update(first['crowd-whistle.wav']).digest('hex'),'5a2c50a7506529ca4725e1fb19e2b1019a76e6808b3a295fbe55ed42ee67e9fd');
 let total=0;
 for(const[name,wave]of Object.entries(first)){
  assert.deepEqual(wave,second[name],name+' déterministe');
  assert.equal(wave.toString('ascii',0,4),'RIFF');assert.equal(wave.readUInt32LE(24),24000);assert.equal(wave.readUInt32LE(40),wave.length-44);
  let peak=0;for(let n=44;n<wave.length;n+=2)peak=Math.max(peak,Math.abs(wave.readInt16LE(n)/32768));
  assert.ok(peak>0.01&&peak<=0.16,name+' : pic sans clipping');
  // Boucle (rumeur) : continue d'un bout à l'autre ; sons ponctuels : départ et fin à zéro.
  if(name==='crowd-murmur.wav')assert.ok(Math.abs(wave.readInt16LE(44)-wave.readInt16LE(wave.length-2))<2000,'rumeur bouclable sans claquement');
  else{assert.equal(wave.readInt16LE(44),0,name);assert.equal(wave.readInt16LE(wave.length-2),0,name);}
  assert.deepEqual(fs.readFileSync(path.join(dir,name)),wave,name+' : asset publié égal au générateur');
  assert.equal(manifest.sounds.find(s=>s.file===name).sha256,crypto.createHash('sha256').update(wave).digest('hex'));
  total+=wave.length;
 }
 assert.ok(total<1100000,'fichiers légers : '+total+' octets');
});
test('Ambiance native : sons de match, ancien sound.json avec champs de musique ignorés, foule selon le camp',{skip:!godot&&'SDK Godot requis'},()=>{
 const base=process.env.CD_SOUNDS_PROOF||os.tmpdir();fs.mkdirSync(base,{recursive:true});
 const proof=fs.mkdtempSync(path.join(base,'cd-ambiance-é '));
 const run=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-ambiance.gd')],{env:{...process.env,CD_AMBIANCE_PROOF:proof,CD_NODE_EXECUTABLE:process.execPath},encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
});
// Captures (rendu graphique) : CD_AMBIANCE_CAPTURE=<dossier> ; sans cette variable, rien n'est lancé.
// Onglet Son des paramètres (volumes Interface et Stade, sons de match).
test('Ambiance native : captures des paramètres audio (CD_AMBIANCE_CAPTURE)',{skip:(!godot&&'SDK Godot requis')||(!process.env.CD_AMBIANCE_CAPTURE&&'CD_AMBIANCE_CAPTURE absent')},()=>{
 const dossier=path.resolve(process.env.CD_AMBIANCE_CAPTURE);fs.mkdirSync(dossier,{recursive:true});
 const racine=fs.mkdtempSync(path.join(os.tmpdir(),'cd-ambiance-capture-'));
 const run=spawnSync(godot,['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','1920x1080','--max-fps','120','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-ambiance.gd')],{
  env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(racine,'PrototypeGodot'),CD_AMBIANCE_CAPTURE:dossier},encoding:'utf8',windowsHide:true,timeout:420000});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;assert.equal(run.status,0,output);
 assert.match(output,/AMBIANCE CAPTURES\s*:\s*\d+ vérifications, 0 échec/);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);
 assert.ok(fs.readdirSync(dossier).filter(f=>f.endsWith('.png')).length>=1,'1 capture PNG au moins attendue');
});
