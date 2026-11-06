'use strict';
const fs=require('node:fs');
const C=require('./calibration.cjs'),N=require('./native.cjs'),A=require('./aging.cjs');
const {seed,summarize}=require('./campaign.cjs');
function run({seeds=64}={}){
 const master=require('../../modding/data06/rugby-master-2026-2027.json'),candidate=C.apply(master,C.consolidate(master));
 const reference=N.laboratory(candidate),pro=reference.clubs.filter(c=>c.league==='prod2').sort((a,b)=>reference.quality(b)-reference.quality(a))[0];
 const tops=reference.clubs.filter(c=>c.league==='top14').sort((a,b)=>reference.quality(a)-reference.quality(b));const opponent=tops[Math.floor(tops.length/2)].slug;
 const results={};
 // Controlled age-only intervention: identical IDs/starting attributes and exposure,
 // hypothetical starting ages 20/34 isolate progression versus physical decline.
 for(const profile of ['unchanged','youngFourYears','veteranFourYears']){
  const source=C.clone(candidate),ps=source.players.filter(p=>p.club===pro.slug),changes=[];
  if(profile!=='unchanged')for(const p of ps){
   let current=p;const start=profile==='youngFourYears'?20:34;
   for(let y=0;y<4;y++)current=A.step(current,{age:start+y,season:y+1},{minutes:1600,training:1}).player;
   changes.push({id:p.id,speedBefore:p.attributesV2.topSpeed,speedAfter:current.attributesV2.topSpeed});p.attributesV2=current.attributesV2;
  }
  const lab=N.laboratory(source,'projected',{qualityCoefficient:.008}),a=lab.clubs.find(c=>c.slug===pro.slug),b=lab.clubs.find(c=>c.slug===opponent);
  const rows=[];for(let i=0;i<seeds;i++)for(const home of [0,1])rows.push({seed:seed(i),home,...lab.match(a,b,seed(i),{home})});
  results[profile]={roster:pro.slug,opponent,summary:summarize(rows),changes,rows};
 }
 return {schema:'rugby-real-v11-age-native-impact',matches:seeds*2*3,results,trajectories:A.trajectories(master),
  limitations:['Hypothetical equal starting ages, NOT actual player histories or natural career seasons','Held roster: no retirement, transfer, injuries or budget decisions between age steps','Same unmodified native match engine; x2 skill-response sandbox proposal active','Observed win differences can include sampling noise, not proof of historical ageing rates']};
}
if(require.main===module){const r=run({seeds:Number(process.argv[3]||64)});fs.writeFileSync(process.argv[2]||'/tmp/v11-age-impact.json',JSON.stringify(r)+'\n');for(const [k,v] of Object.entries(r.results))console.log(k,JSON.stringify(v.summary));}
module.exports={run};
