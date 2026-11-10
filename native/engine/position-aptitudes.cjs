'use strict';
// Inject once, after explicit Nationale/Japan qualification hooks. This is a
// fictional sporting model, not a source of first-row training qualifications.
module.exports=function positionAptitudes(){
 const baseSlot=slotEligible,baseBench=benchEligible,baseNote=roleNote;
 const cover=[2,1,3,4,6,9,10,11],adjacent=[[],[3],[3],[2],[5,6],[4,8,7],[7,8],[6,8,5],[6,5,7]];
 const critical=[['scrum','power'],['lineout','scrum'],['lineout','tackle'],['tackle','stamina'],['pass','mental'],['pass','kick'],['speed'],['pass','tackle'],['kick','speed']];
 const cache=new Map();
 function positionNumber(slot){return slot<15?slot+1:cover[slot-15]??null;}
 function project(p){
  if(!p)return {primaryPosition:null,secondaryPositions:[],positionRatings:{},qualifiedFrontRowPositions:[]};
  // Legacy missing skills are deterministically generated on a detached object.
  const q={...p,skills:p.skills?{...p.skills}:undefined};ensureSkills(q);
  const qualities=Object.keys(ATTR).map(k=>skill(q,k));
  const front=[0,1,2].filter(i=>baseSlot(p,i)).map(i=>i+1);
  const key=[p.id,p.pos,p.fam,p.rating,p.skillBase,...qualities,...front].join('|');
  let result=cache.get(key);
  if(!result){
   const found=POS.indexOf(p.pos),primary=found>=0?found+1:FAMILIES.indexOf(p.fam)+1;
   const main=baseNote(q),raw=FAMILIES.map(f=>baseNote(q,f));
   const candidates=(adjacent[p.fam]||[]).filter(f=>{
    const value=baseNote(q,f);return value>=Math.max(55,main*.90)&&critical[f].every(k=>skill(q,k)>=Math.max(50,main*.72));
   }).sort((a,b)=>baseNote(q,b)-baseNote(q,a)||(adjacent[p.fam].indexOf(a)-adjacent[p.fam].indexOf(b)));
   const mastered=candidates[0],ratings={},secondary=[];
   for(let i=0;i<15;i++){
    const f=FAMILIES[i],natural=f===p.fam;
    let n;
    if(i<3)n=front.includes(i+1)?Math.min(main,baseNote(q,f)):0;
    else if(natural)n=main;
    else if(f===mastered)n=Math.max(1,Math.min(main-3,raw[i]-4));
    else {
     const close=(adjacent[p.fam]||[]).includes(f),sameUnit=(p.fam<=3)===(f<=3);
     n=Math.max(5,Math.min(main-8,Math.round(raw[i]*(close?.64:sameUnit?.49:.32))));
    }
    ratings[i+1]=n;
    if(i+1!==primary&&(i<3?front.includes(i+1):natural||f===mastered))secondary.push(i+1);
   }
   secondary.sort((a,b)=>ratings[b]-ratings[a]||a-b);
   result={primaryPosition:primary,secondaryPositions:secondary,positionRatings:ratings,qualifiedFrontRowPositions:front};
   if(cache.size>=32768)cache.delete(cache.keys().next().value);cache.set(key,result);
  }
  return {...result,secondaryPositions:result.secondaryPositions.slice(),positionRatings:{...result.positionRatings},qualifiedFrontRowPositions:result.qualifiedFrontRowPositions.slice()};
 }
 return Object.freeze({project,positionNumber});
};
