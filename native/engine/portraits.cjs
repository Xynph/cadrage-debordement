'use strict';
// Offline visual identity only. No game RNG, network, model inference or save mutation.
const VERSION=1;
const key=x=>typeof x==='string'&&x.length>0&&x.length<=256?x:null;
const age=x=>Number.isInteger(x)&&x>=0&&x<=120?x:null;
function hash(text){let h=2166136261;for(const b of Buffer.from(text,'utf8')){h^=b;h=Math.imul(h,16777619)>>>0;}return h;}
function describe(person={}){
 const p=person&&typeof person==='object'&&!Array.isArray(person)?person:{};
 const source=key(p.sourcePlayerId),appearanceId=key(p.appearanceId)||source||key(p.id)||'anonymous';
 const staff=p.portraitRole==='staff'||p.appearanceRole==='staff'||typeof p.role==='string'&&!p.pos;
 const origin=source?'player':staff?'staff':'player',seed=hash(appearanceId);
 let state=seed||1;
 const next=()=>{state^=state<<13;state^=state>>>17;state^=state<<5;state>>>=0;return state/4294967296;};
 const ref=age(p.appearanceAge),current=age(p.age);
 const band=origin==='staff'?(ref===null?(seed>>>8)%4:Math.max(0,Math.min(3,Math.floor((ref-40)/10)))):null;
 const cell=origin==='staff'?band*4+seed%4:seed%32;
 const faceWidth=.965+next()*.07,eyeSpacing=-.010+next()*.020,noseWidth=-.012+next()*.024,jawWidth=-.012+next()*.024;
 const zoom=1.005+next()*.025,cropX=-.008+next()*.016,cropY=-.006+next()*.012;
 const saturation=.94+next()*.12,exposure=.97+next()*.06,shirt=next(),mirror=next()>=.5;
 const illustrativeAge=origin==='staff'?45+band*10:25;
 const visualAge=current??ref??illustrativeAge;
 return {version:VERSION,appearanceId,seed,origin,atlas:origin==='staff'?'staff':'players',cell,
  ageBasis:current!==null?'current-age':ref!==null?'appearance-reference':'illustrative',referenceAge:ref,
  ageBand:band,maturity:Math.max(0,Math.min(1,(visualAge-30)/50)),
  faceWidth,eyeSpacing,noseWidth,jawWidth,zoom,cropX,cropY,saturation,exposure,shirt,mirror};
}
module.exports={VERSION,hash,describe};
