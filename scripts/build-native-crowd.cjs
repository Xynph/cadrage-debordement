'use strict';
// Sifflets de foule d'Oval Legacy 27 : synthèse déterministe locale, sans échantillon,
// enregistrement ni paquet tiers. Fichier séparé de build-native-sounds.cjs (dont les
// sons sont figés par tests/godot-soundscape06-assets.cjs).
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const RATE=24000,TAU=2*Math.PI,DURATION=1.4;
function random(seed){let s=seed>>>0;return()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296;};}
function whistle(){
 const rng=random(272710),voices=Array.from({length:14},()=>({at:rng()*.55,length:.35+rng()*.5,f:2300+rng()*1500,vib:5+rng()*3,gain:.25+rng()*.5,pan:rng()}));
 const frames=Math.round(DURATION*RATE),values=new Float64Array(frames*2),phase=new Float64Array(voices.length);let max=0;
 for(let n=1;n<frames-1;n++){
  const t=n/RATE;
  voices.forEach((v,i)=>{const age=t-v.at;if(age<0||age>v.length)return;
   const env=Math.sin(Math.PI*age/v.length)**2,f=v.f*(1+.03*Math.sin(TAU*v.vib*age)),noise=(rng()*2-1)*.08;
   phase[i]+=TAU*f/RATE;const x=(Math.sin(phase[i])+noise)*env*v.gain;
   values[n*2]+=x*(1-v.pan);values[n*2+1]+=x*v.pan;});
  max=Math.max(max,Math.abs(values[n*2]),Math.abs(values[n*2+1]));
 }
 const peak=.09,gain=peak/Math.max(max,1e-9),bytes=Buffer.alloc(44+values.length*2);
 bytes.write('RIFF');bytes.writeUInt32LE(bytes.length-8,4);bytes.write('WAVE',8);bytes.write('fmt ',12);bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(2,22);bytes.writeUInt32LE(RATE,24);bytes.writeUInt32LE(RATE*4,28);bytes.writeUInt16LE(4,32);bytes.writeUInt16LE(16,34);bytes.write('data',36);bytes.writeUInt32LE(values.length*2,40);
 for(let n=0;n<values.length;n++)bytes.writeInt16LE(Math.round(values[n]*gain*32767),44+n*2);
 return bytes;
}
function buildCrowd(){return{'crowd-whistle.wav':whistle()};}
function manifest(sounds){return{version:1,origin:'Synthèse procédurale originale locale — Oval Legacy 27',generator:'scripts/build-native-crowd.cjs',third_party_assets:false,sample_rate:RATE,sounds:Object.entries(sounds).map(([file,data])=>({file,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')}))};}
function writeCrowd(directory,check=false){const sounds=buildCrowd(),files={...sounds,'crowd-manifest.json':Buffer.from(JSON.stringify(manifest(sounds),null,2)+'\n')};
 for(const[name,data]of Object.entries(files)){const target=path.join(directory,name);if(check){if(!fs.existsSync(target)||!fs.readFileSync(target).equals(data))throw new Error('Son à régénérer : '+target);}else fs.writeFileSync(target,data);}return manifest(sounds);}
module.exports={buildCrowd,writeCrowd};
if(require.main===module){const check=process.argv.includes('--check'),directory=path.resolve(__dirname,'../native/godot/audio/assets');const r=writeCrowd(directory,check);console.log((check?'Sons vérifiés : ':'Sons générés : ')+r.sounds.length);}
