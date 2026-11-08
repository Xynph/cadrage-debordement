'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
test('Sons originaux : WAV déterministes, doux, bornés et fondus sans dépendance',()=>{
 const {buildSounds}=require('../scripts/build-native-sounds.cjs');
 const first=buildSounds(),second=buildSounds();
 assert.deepEqual(Object.keys(first),['ui-tap.wav','ui-error.wav','stadium-bed.wav','stadium-try.wav','stadium-goal.wav','stadium-miss.wav']);
 for(const [name,wave]of Object.entries(first)){
  assert.deepEqual(wave,second[name],name+' reproductible');
  assert.equal(wave.toString('ascii',0,4),'RIFF');assert.equal(wave.toString('ascii',8,12),'WAVE');
  assert.equal(wave.readUInt16LE(20),1);assert.equal(wave.readUInt32LE(24),24000);assert.equal(wave.readUInt16LE(34),16);
  const channels=wave.readUInt16LE(22),frames=(wave.length-44)/(channels*2),duration=frames/24000;
  assert.equal(channels,name.startsWith('stadium-')?2:1);assert.equal(wave.readUInt32LE(40),wave.length-44);
  assert.ok(duration>0.03&&duration<=8.01,name+' durée bornée');
  let peak=0,squares=0;
  for(let n=44;n<wave.length;n+=2){const x=wave.readInt16LE(n)/32768;peak=Math.max(peak,Math.abs(x));squares+=x*x;}
  assert.ok(peak>0.01&&peak<=0.16,name+' pic sans clipping');
  assert.ok(Math.sqrt(squares/((wave.length-44)/2))<0.055,name+' RMS discret');
  for(let channel=0;channel<channels;channel++){
   assert.equal(wave.readInt16LE(44+channel*2),0,name+' départ fondu');
   assert.equal(wave.readInt16LE(wave.length-channels*2+channel*2),0,name+' fin fondue');
  }
  let edgePeak=0;for(let n=0;n<24*channels;n++){edgePeak=Math.max(edgePeak,Math.abs(wave.readInt16LE(44+n*2)/32768),Math.abs(wave.readInt16LE(wave.length-2-n*2)/32768));}
  assert.ok(edgePeak<peak*.2,name+' attaque et sortie sans impulsion abrupte');
  const checked=fs.readFileSync(path.join(__dirname,'../native/godot/audio/assets',name));assert.deepEqual(checked,wave,name+' asset publié égal au générateur');
 }
 const manifest=JSON.parse(fs.readFileSync(path.join(__dirname,'../native/godot/audio/assets/manifest.json'),'utf8'));
 assert.equal(manifest.version,1);assert.equal(manifest.recordings,false);assert.equal(manifest.third_party_assets,false);
 assert.equal(manifest.generator_sha256,crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'../scripts/build-native-sounds.cjs'))).digest('hex'));
 for(const item of manifest.sounds){assert.equal(crypto.createHash('sha256').update(first[item.file]).digest('hex'),item.sha256);}
});
