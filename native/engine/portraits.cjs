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
 const bank=p.appearanceBankVersion===2?2:1;
 const cell=origin==='staff'?band*(bank===2?10:4)+seed%(bank===2?10:4):seed%(bank===2?160:32);
 let faceWidth=.965+next()*.07,eyeSpacing=-.010+next()*.020,noseWidth=-.012+next()*.024,jawWidth=-.012+next()*.024;
 let zoom=1.005+next()*.025;const cropX=-.008+next()*.016,cropY=-.006+next()*.012;
 const saturation=.94+next()*.12,exposure=.97+next()*.06,shirt=next(),mirror=next()>=.5;
 // Carrure (écart entre la carrure attendue et celle de la base choisie, de -1 à 1) : le visage s'élargit ou s'affine
 // un peu plus que le seul aléa (largeurs > 1 = visage plus étroit dans le shader) ; l'aléa propre au joueur est gardé.
 const build=typeof p.appearanceBuild==='number'&&Number.isFinite(p.appearanceBuild)&&Math.abs(p.appearanceBuild)<=1?p.appearanceBuild:null;
 if(build!==null){faceWidth=1-.05*build+(faceWidth-1)*.45;jawWidth=-.024*build+jawWidth*.6;zoom=1.005+(zoom-1.005)*.6+.012*(1-build)/2;}
 const illustrativeAge=origin==='staff'?45+band*10:25;
 const visualAge=current??ref??illustrativeAge;
 const result={version:VERSION,appearanceId,seed,origin,atlas:origin==='staff'?'staff':'players',cell,
  ageBasis:current!==null?'current-age':ref!==null?'appearance-reference':'illustrative',referenceAge:ref,
  ageBand:band,maturity:Math.max(0,Math.min(1,(visualAge-30)/50)),
  faceWidth,eyeSpacing,noseWidth,jawWidth,zoom,cropX,cropY,saturation,exposure,shirt,mirror};
 if(build!==null)result.build=build;
 if(bank===2){
  const within=cell%10,newStaff=origin==='staff'&&within>=4;
  Object.assign(result,{version:2,bankVersion:2,baseId:result.atlas+':'+String(cell).padStart(3,'0'),
   assetPath:origin==='player'?(cell<32?'res://assets/editorial/portraits-'+Math.floor(cell/16)+'.webp':'res://art/regen-bank-v2/players-'+String(Math.floor(cell/16)).padStart(2,'0')+'.png'):(newStaff?'res://art/regen-bank-v2/staff-01.png':'res://art/regen-staff-atlas.png'),
   columns:newStaff?6:4,rows:4,assetCell:origin==='player'?cell%16:band*(newStaff?6:4)+(newStaff?within-4:within)});
 }
 return result;
}
module.exports={VERSION,hash,describe};
