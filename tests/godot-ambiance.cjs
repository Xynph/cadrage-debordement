'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
const dir=path.join(__dirname,'../native/godot/audio/assets');
test('Sifflets de foule : WAV déterministe, discret, publié égal au générateur ; bruits synthétisés retirés',()=>{
 const {buildCrowd}=require('../scripts/build-native-crowd.cjs');
 const first=buildCrowd(),second=buildCrowd();
 assert.deepEqual(Object.keys(first),['crowd-whistle.wav']);
 const manifest=JSON.parse(fs.readFileSync(path.join(dir,'crowd-manifest.json'),'utf8'));
 assert.equal(manifest.third_party_assets,false);
 assert.deepEqual(manifest.sounds.map(s=>s.file),['crowd-whistle.wav']);
 const wave=first['crowd-whistle.wav'];
 // Sifflets de foule d'origine : octets inchangés.
 assert.equal(crypto.createHash('sha256').update(wave).digest('hex'),'5a2c50a7506529ca4725e1fb19e2b1019a76e6808b3a295fbe55ed42ee67e9fd');
 assert.deepEqual(wave,second['crowd-whistle.wav'],'déterministe');
 assert.equal(wave.toString('ascii',0,4),'RIFF');assert.equal(wave.readUInt32LE(24),24000);assert.equal(wave.readUInt32LE(40),wave.length-44);
 let peak=0;for(let n=44;n<wave.length;n+=2)peak=Math.max(peak,Math.abs(wave.readInt16LE(n)/32768));
 assert.ok(peak>0.01&&peak<=0.16,'pic sans clipping');
 assert.equal(wave.readInt16LE(44),0);assert.equal(wave.readInt16LE(wave.length-2),0);
 assert.deepEqual(fs.readFileSync(path.join(dir,'crowd-whistle.wav')),wave,'asset publié égal au générateur');
 assert.equal(manifest.sounds[0].sha256,crypto.createHash('sha256').update(wave).digest('hex'));
 // Les huit bruits synthétisés du 18/11/2026 ont laissé place aux enregistrements.
 for(const name of ['referee-whistle','referee-whistle-long','crowd-murmur','crowd-groan','crowd-applause','impact-tackle','impact-scrum','kick-pock'])
  assert.ok(!fs.existsSync(path.join(dir,name+'.wav')),name+'.wav retiré');
});
test('Bruits de match enregistrés : OGG présents, empreintes, boucles signalées, tous branchés, provenance sans clé',()=>{
 const match=path.join(dir,'match'),manifest=JSON.parse(fs.readFileSync(path.join(match,'manifest.json'),'utf8'));
 assert.equal(manifest.recordings,true);assert.equal(manifest.third_party_assets,true);assert.match(manifest.origin,/ElevenLabs/);
 const source=fs.readFileSync(path.join(__dirname,'../native/godot/audio/soundscape.gd'),'utf8');
 const referenced=new Set([...source.matchAll(/"match\/([a-z0-9-]+\.ogg)"/g)].map(m=>m[1]));
 const files=manifest.sounds.map(s=>s.file);
 assert.deepEqual([...referenced].sort(),[...files].sort(),'chaque enregistrement est branché, aucun chemin orphelin');
 assert.deepEqual(fs.readdirSync(match).filter(f=>f.endsWith('.ogg')).sort(),[...files].sort(),'aucun OGG hors manifeste');
 let total=0;
 for(const sound of manifest.sounds){
  const data=fs.readFileSync(path.join(match,sound.file));
  assert.equal(data.toString('ascii',0,4),'OggS',sound.file+' : OGG');
  assert.equal(crypto.createHash('sha256').update(data).digest('hex'),sound.sha256,sound.file+' : empreinte');
  assert.ok(sound.peak_dbfs<=-1,sound.file+' : pas de saturation');
  total+=data.length;
 }
 assert.ok(total<1000000,'enregistrements légers : '+total+' octets');
 // Boucles : la rumeur et les deux prises de nappe, et elles seules.
 const loops=manifest.sounds.filter(s=>s.loop).map(s=>s.file).sort();
 assert.deepEqual(loops,['ambiance-stade-1.ogg','ambiance-stade-2.ogg','foule-rumeur.ogg']);
 assert.match(source,/"crowd-murmur": "match\/foule-rumeur\.ogg"/);
 assert.match(source,/_murmur\.stream = _looped\(_streams\["crowd-murmur"\], true\)/,'rumeur bouclée en code');
 assert.match(source,/BED_VARIANTS: Array\[String\] = \["match\/ambiance-stade-1\.ogg", "match\/ambiance-stade-2\.ogg"\]/);
 assert.match(source,/playlist\.loop = true/,'nappe en boucle (liste de lecture)');
 // Provenance : invites et réglages ElevenLabs versionnés, sans aucune clé.
 const provenance=fs.readFileSync(path.join(__dirname,'../docs/provenance/elevenlabs-bruits-match-20261118.json'),'utf8');
 assert.doesNotMatch(provenance,/api[_-]?key|xi-api|sk_[a-z0-9]/i);
 const prompts=JSON.parse(provenance);
 for(const sound of manifest.sounds)assert.ok(prompts.sons.some(s=>s.file===sound.source&&s.text),sound.source+' : invite connue');
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
