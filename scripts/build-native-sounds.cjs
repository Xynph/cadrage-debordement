'use strict';
// Sons originaux d'Oval Legacy 27. Synthèse déterministe locale, sans paquet,
// enregistrement, voix, musique, service ou échantillon tiers.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const RATE=24000,TAU=2*Math.PI;
function random(seed){let s=seed>>>0;return()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296;};}
function fade(t,duration,attack,release){return Math.sin(Math.PI/2*Math.min(1,t/attack))**2*Math.sin(Math.PI/2*Math.min(1,(duration-t)/release))**2;}
function wave(duration,channels,peak,sample){
 const frames=Math.round(duration*RATE),values=new Float64Array(frames*channels);let maximum=0;
 for(let n=0;n<frames;n++)for(let c=0;c<channels;c++){const x=(n===0||n===frames-1)?0:sample(n/RATE,c);values[n*channels+c]=x;maximum=Math.max(maximum,Math.abs(x));}
 const bytes=Buffer.alloc(44+values.length*2);bytes.write('RIFF');bytes.writeUInt32LE(bytes.length-8,4);bytes.write('WAVE',8);bytes.write('fmt ',12);
 bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(channels,22);bytes.writeUInt32LE(RATE,24);bytes.writeUInt32LE(RATE*channels*2,28);bytes.writeUInt16LE(channels*2,32);bytes.writeUInt16LE(16,34);bytes.write('data',36);bytes.writeUInt32LE(values.length*2,40);
 const gain=peak/Math.max(maximum,1e-9);for(let n=0;n<values.length;n++)bytes.writeInt16LE(Math.round(values[n]*gain*32767),44+n*2);return bytes;
}
function tap(error=false){
 const duration=error?0.145:0.065,rng=random(error?2702:2701);let low=0;
 return wave(duration,1,error?0.105:0.115,t=>{const noise=rng()*2-1;low=low*.68+noise*.32;const decay=Math.exp(-t*(error?25:52));const tone=Math.sin(TAU*(error?235:680)*t)+.22*Math.sin(TAU*(error?318:1130)*t);return (low*.65+tone*.12)*decay*fade(t,duration,.005,.028);});
}
function bed(){
 const duration=8,rng=random(272700),low=[0,0],mid=[0,0];
 return wave(duration,2,.05,(t,c)=>{const white=rng()*2-1;low[c]=low[c]*.992+white*.008;mid[c]=mid[c]*.7+white*.3;const air=(mid[c]-low[c])*.24+low[c]*.6;const swell=.75+.13*Math.sin(TAU*t/3.7+c*.16)+.07*Math.sin(TAU*t/1.9);return air*swell*fade(t,duration,.4,.4);});
}
function reaction(kind){
 const durations={try:1.55,goal:1.05,miss:.7},duration=durations[kind],rng=random({try:272701,goal:272702,miss:272703}[kind]),low=[0,0];
 const claps=Array.from({length:kind==='try'?19:kind==='goal'?11:3},(_,i)=>({at:.08+i*.055+rng()*.025,gain:.25+rng()*.4}));
 return wave(duration,2,kind==='try'?.145:kind==='goal'?.115:.075,(t,c)=>{const white=rng()*2-1;low[c]=low[c]*.8+white*.2;let pulse=0;for(const clap of claps){const age=t-clap.at-c*.0015;if(age>0&&age<.08)pulse+=clap.gain*Math.exp(-age*70);}
  const swell=Math.sin(Math.PI*Math.min(1,t/duration))**2;return ((white-low[c])*.24*pulse+low[c]*.5*swell)*fade(t,duration,.04,.17);});
}
function buildSounds(){return{'ui-tap.wav':tap(),'ui-error.wav':tap(true),'stadium-bed.wav':bed(),'stadium-try.wav':reaction('try'),'stadium-goal.wav':reaction('goal'),'stadium-miss.wav':reaction('miss')};}
function manifest(sounds){return{version:1,origin:'Synthèse procédurale originale locale — Oval Legacy 27',generator:'scripts/build-native-sounds.cjs',generator_sha256:crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex'),recordings:false,third_party_assets:false,voices:false,music:false,sample_rate:RATE,format:'PCM 16-bit little-endian',sounds:Object.entries(sounds).map(([file,data])=>({file,bytes:data.length,channels:data.readUInt16LE(22),duration_seconds:(data.length-44)/data.readUInt32LE(28),sha256:crypto.createHash('sha256').update(data).digest('hex')}))};}
function writeSounds(directory,check=false){const sounds=buildSounds();const files={...sounds,'manifest.json':Buffer.from(JSON.stringify(manifest(sounds),null,2)+'\n')};if(!check)fs.mkdirSync(directory,{recursive:true});for(const[name,data]of Object.entries(files)){const target=path.join(directory,name);if(check){if(!fs.existsSync(target)||!fs.readFileSync(target).equals(data))throw new Error('Son à régénérer : '+target);}else fs.writeFileSync(target,data);}return manifest(sounds);}
module.exports={buildSounds,writeSounds};
if(require.main===module){const args=process.argv.slice(2),check=args.includes('--check'),out=args.indexOf('--out-dir');if(args.some((x,i)=>x!=='--check'&&x!=='--out-dir'&&!(out>=0&&i===out+1))||(out>=0&&(!args[out+1]||args[out+1].startsWith('--'))))throw new Error('Usage : node scripts/build-native-sounds.cjs [--check] [--out-dir dossier]');const directory=out>=0?path.resolve(args[out+1]):path.resolve(__dirname,'../native/godot/audio/assets');const result=writeSounds(directory,check);console.log((check?'Sons vérifiés : ':'Sons originaux générés : ')+result.sounds.length+' — '+directory);}
