'use strict';
// Sifflets de foule et bruits de match (arbitre, rumeur, « oooh », applaudissements, impacts,
// ballon frappé) d'Oval Legacy 27 : synthèse déterministe locale, sans échantillon,
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
// --- Bruits de match (18/11/2026) : arbitre, foule qui réagit, impacts, ballon frappé. ---
// Même principe : formules et bruit pseudo-aléatoire à graine fixe, rien d'enregistré.
function pcm(values,channels,peak,keepEnds=false){
 let max=0;for(const v of values)max=Math.max(max,Math.abs(v));
 if(!keepEnds){for(let c=0;c<channels;c++){values[c]=0;values[values.length-channels+c]=0;}}
 const gain=peak/Math.max(max,1e-9),bytes=Buffer.alloc(44+values.length*2);
 bytes.write('RIFF');bytes.writeUInt32LE(bytes.length-8,4);bytes.write('WAVE',8);bytes.write('fmt ',12);bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(channels,22);bytes.writeUInt32LE(RATE,24);bytes.writeUInt32LE(RATE*channels*2,28);bytes.writeUInt16LE(channels*2,32);bytes.writeUInt16LE(16,34);bytes.write('data',36);bytes.writeUInt32LE(values.length*2,40);
 for(let n=0;n<values.length;n++)bytes.writeInt16LE(Math.round(values[n]*gain*32767),44+n*2);
 return bytes;
}
function edge(t,duration,attack,release){return Math.min(1,t/attack)*Math.min(1,Math.max(0,(duration-t)/release));}
// Sifflet d'arbitre (sifflet à bille) : une note aiguë qui roule, un souffle léger. `blasts` : [début, durée] en s.
function referee(blasts,seed){
 const rng=random(seed),duration=blasts.reduce((m,[a,l])=>Math.max(m,a+l),0)+.05,frames=Math.round(duration*RATE),values=new Float64Array(frames);let phase=0,air=0;
 for(let n=0;n<frames;n++){const t=n/RATE;let env=0,age=0;
  for(const[at,length]of blasts){const a=t-at;if(a>=0&&a<=length){env=Math.max(env,Math.min(1,a/.012)*Math.min(1,(length-a)/.05));age=a;}}
  const roll=Math.sin(TAU*37*t+1.3*Math.sin(TAU*5*t)),f=2780*(1+.004*age)*(1+.011*roll);phase+=TAU*f/RATE;
  const white=rng()*2-1;air=air*.55+white*.45;
  values[n]=env*((Math.sin(phase)+.16*Math.sin(2*phase))*(.8+.2*roll)+(white-air)*.12);}
 return pcm(values,1,.075);
}
// Rumeur de foule bouclable (4 s, mono) : bande médium de bruit, modulée lentement par
// plusieurs « groupes » ; la fin est fondue dans le début pour une boucle sans couture.
function murmur(){
 const rng=random(272720),N=4*RATE,X=Math.round(.5*RATE),total=N+X,raw=new Float64Array(total);
 const groups=Array.from({length:7},()=>({f:.18+rng()*.5,p:rng()*TAU,depth:.25+rng()*.35}));let low=0,mid=0,lp=0;
 for(let n=0;n<total;n++){const t=n/RATE,white=rng()*2-1;low=low*.985+white*.015;mid=mid*.82+white*.18;const band=mid-low;lp=lp*.6+band*.4;
  let mod=0;for(const g of groups)mod+=1-g.depth+g.depth*Math.sin(TAU*g.f*t+g.p);raw[n]=lp*mod/groups.length;}
 const out=new Float64Array(N);for(let n=0;n<N;n++)out[n]=n<X?raw[n]*(n/X)+raw[N+n]*(1-n/X):raw[n];
 return pcm(out,1,.06,true);
}
// « Oooh » déçu (mono) : bruit passé dans un résonateur dont la fréquence descend.
function groan(){
 const rng=random(272721),duration=1.1,frames=Math.round(duration*RATE),values=new Float64Array(frames);const r=[[0,0],[0,0],[0,0]];
 for(let n=0;n<frames;n++){const t=n/RATE,white=rng()*2-1;let x=0;
  [[1,.94],[1.5,.96],[2.6,.97]].forEach(([k,q],i)=>{const f=k*(430-170*Math.min(1,t/duration)),w=TAU*f/RATE,y=white*(1-q)*2+2*q*Math.cos(w)*r[i][0]-q*q*r[i][1];r[i][1]=r[i][0];r[i][0]=y;x+=y/(i+1);});
  const swell=Math.sin(Math.PI*Math.min(1,t/.3)/2)**2*Math.exp(-Math.max(0,t-.3)*2.2);values[n]=x*swell*edge(t,duration,.04,.2);}
 return pcm(values,1,.08);
}
// Applaudissements légers (stéréo) : claquements brefs de bruit filtré, denses puis clairsemés.
function applause(){
 const rng=random(272722),duration=1.6,frames=Math.round(duration*RATE),values=new Float64Array(frames*2);
 const claps=Array.from({length:70},()=>{const at=Math.pow(rng(),1.6)*1.35;return{at,gain:.3+rng()*.7,pan:rng(),tone:.35+rng()*.4};});let hp=[0,0];
 for(let n=0;n<frames;n++){const t=n/RATE;for(let c=0;c<2;c++){let x=0;const white=rng()*2-1;hp[c]=hp[c]*.7+white*.3;const bright=white-hp[c];
  for(const k of claps){const age=t-k.at;if(age<0||age>.06)continue;x+=k.gain*(c?k.pan:1-k.pan)*Math.exp(-age*95)*(bright*k.tone+white*(1-k.tone)*.4);}
  values[n*2+c]=x*edge(t,duration,.02,.35);}}
 return pcm(values,2,.08);
}
// Impacts au contact (mono) : coup sourd grave à hauteur descendante et frottement amorti.
function impact(kind){
 const heavy=kind==='scrum',rng=random(heavy?272724:272723),duration=heavy?.5:.22,frames=Math.round(duration*RATE),values=new Float64Array(frames);
 const bodies=heavy?Array.from({length:8},()=>({at:rng()*.07,f:55+rng()*25,gain:.5+rng()*.5})):[{at:0,f:82,gain:1}];let low=0;const phases=new Float64Array(bodies.length);
 for(let n=0;n<frames;n++){const t=n/RATE,white=rng()*2-1;low=low*(heavy?.93:.9)+white*(heavy?.07:.1);let x=0;
  bodies.forEach((b,i)=>{const age=t-b.at;if(age<0)return;phases[i]+=TAU*b.f*(1+.6*Math.exp(-age*30))/RATE;x+=b.gain*Math.sin(phases[i])*Math.exp(-age*(heavy?14:24));});
  values[n]=(x*.8+low*(heavy?2.2:1.6)*Math.exp(-t*(heavy?9:40)))*edge(t,duration,.003,heavy?.12:.06);}
 return pcm(values,1,heavy?.13:.12);
}
// Ballon frappé (mono) : « pock » bref, attaque de bruit et corps creux qui descend.
function pock(){
 const rng=random(272725),duration=.14,frames=Math.round(duration*RATE),values=new Float64Array(frames);let p1=0,p2=0;
 for(let n=0;n<frames;n++){const t=n/RATE;p1+=TAU*(300+140*Math.exp(-t*60))/RATE;p2+=TAU*150/RATE;
  values[n]=(Math.sin(p1)*Math.exp(-t*45)+.5*Math.sin(p2)*Math.exp(-t*30)+(rng()*2-1)*Math.exp(-t*420)*.9)*edge(t,duration,.0015,.04);}
 return pcm(values,1,.12);
}
function buildCrowd(){return{'crowd-whistle.wav':whistle(),
 'referee-whistle.wav':referee([[0,.3]],272726),'referee-whistle-long.wav':referee([[0,.22],[.34,.22],[.68,.8]],272727),
 'crowd-murmur.wav':murmur(),'crowd-groan.wav':groan(),'crowd-applause.wav':applause(),
 'impact-tackle.wav':impact('tackle'),'impact-scrum.wav':impact('scrum'),'kick-pock.wav':pock()};}
function manifest(sounds){return{version:1,origin:'Synthèse procédurale originale locale — Oval Legacy 27',generator:'scripts/build-native-crowd.cjs',third_party_assets:false,sample_rate:RATE,sounds:Object.entries(sounds).map(([file,data])=>({file,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')}))};}
function writeCrowd(directory,check=false){const sounds=buildCrowd(),files={...sounds,'crowd-manifest.json':Buffer.from(JSON.stringify(manifest(sounds),null,2)+'\n')};
 for(const[name,data]of Object.entries(files)){const target=path.join(directory,name);if(check){if(!fs.existsSync(target)||!fs.readFileSync(target).equals(data))throw new Error('Son à régénérer : '+target);}else fs.writeFileSync(target,data);}return manifest(sounds);}
module.exports={buildCrowd,writeCrowd};
if(require.main===module){const check=process.argv.includes('--check'),directory=path.resolve(__dirname,'../native/godot/audio/assets');const r=writeCrowd(directory,check);console.log((check?'Sons vérifiés : ':'Sons générés : ')+r.sounds.length);}
