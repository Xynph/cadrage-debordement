'use strict';
// Inject once, after explicit Nationale/Japan qualification hooks. This is a
// fictional sporting model, not a source of first-row training qualifications.
module.exports=function positionAptitudes(){
 const baseSlot=slotEligible,baseBench=benchEligible,baseNote=roleNote;
 const cover=[2,1,3,4,6,9,10,11],adjacent=[[],[],[3],[2],[5,6],[4,8,7],[7,8],[6,8,5],[6,5,7]];
 const critical=[['scrum','power'],['lineout','scrum'],['lineout','tackle'],['tackle','stamina'],['pass','mental'],['pass','kick'],['speed'],['pass','tackle'],['kick','speed']];
 const cache=new Map(),playerCache=new WeakMap(),keys=Object.keys(ATTR);
 const compareId=(a,b)=>String(a.id)<String(b.id)?-1:String(a.id)>String(b.id)?1:0;
 function positionNumber(slot){return slot<15?slot+1:cover[slot-15]??null;}
 function derive(p){
  if(!p)return {primaryPosition:null,primaryPositions:[],secondaryPositions:[],positionRatings:{},qualifiedFrontRowPositions:[]};
  const qualifierKey=[p.nationaleQualifications?.join('|'),p.worldProfile?.position?.qualifications?.join('|'),p.worldRatingsVersion].join(';');
  const cached=playerCache.get(p);
  if(cached&&cached.id===p.id&&cached.name===p.name&&cached.rating===p.rating&&cached.skillBase===p.skillBase&&cached.pos===p.pos&&cached.fam===p.fam&&cached.qualifierKey===qualifierKey&&
   keys.every((k,i)=>cached.skills[i]===p.skills?.[k]&&cached.bonuses[i]===focusedBonus(p,k)))return cached.result;
  // Legacy missing skills are deterministically generated on a detached object.
  const q=p.skills?p:{...p};ensureSkills(q);
  const qualities=keys.map(k=>skill(q,k));
  const front=[0,1,2].filter(i=>baseSlot(p,i)).map(i=>i+1);
  const key=[p.id,p.pos,p.fam,p.rating,p.skillBase,...qualities,...front].join('|');
  let result=cache.get(key);
  if(!result){
   const found=POS.indexOf(p.pos),primary=found>=0?found+1:FAMILIES.indexOf(p.fam)+1;
   // A main role can cover two shirts. These are not secondary roles;
   // prop sides still come exclusively from existing front-row qualifications.
   const primaryPositions=primary===1||primary===3?front.filter(n=>n===1||n===3):
    [[4,5],[6,7],[11,14],[12,13]].find(numbers=>numbers.includes(primary))??[primary];
   const main=baseNote(q),familyNotes=Array.from({length:9},(_,f)=>baseNote(q,f)),raw=FAMILIES.map(f=>familyNotes[f]);
   const candidates=(adjacent[p.fam]||[]).filter(f=>{
    const value=familyNotes[f];return value>=Math.max(55,main*.90)&&critical[f].every(k=>skill(q,k)>=Math.max(50,main*.72));
   }).sort((a,b)=>familyNotes[b]-familyNotes[a]||(adjacent[p.fam].indexOf(a)-adjacent[p.fam].indexOf(b)));
   const mastered=candidates[0],ratings={},secondary=[];
   for(let i=0;i<15;i++){
    const f=FAMILIES[i],natural=f===p.fam;
    let n;
    if(i<3)n=front.includes(i+1)?Math.min(main,familyNotes[f]):0;
    else if(natural)n=main;
    else if(f===mastered)n=Math.max(1,Math.min(main-3,raw[i]-4));
    else {
     const close=(adjacent[p.fam]||[]).includes(f),sameUnit=(p.fam<=3)===(f<=3);
     n=Math.max(5,Math.min(main-8,Math.round(raw[i]*(close?.64:sameUnit?.49:.32))));
    }
    ratings[i+1]=n;
    if(!primaryPositions.includes(i+1)&&(i<3?front.includes(i+1):natural||f===mastered))secondary.push(i+1);
   }
   secondary.sort((a,b)=>ratings[b]-ratings[a]||a-b);
   result={primaryPosition:primary,primaryPositions,secondaryPositions:secondary,positionRatings:ratings,qualifiedFrontRowPositions:front,_familyNotes:familyNotes};
   if(cache.size>=32768)cache.delete(cache.keys().next().value);cache.set(key,result);
  }
  playerCache.set(p,{id:p.id,name:p.name,rating:p.rating,skillBase:p.skillBase,pos:p.pos,fam:p.fam,qualifierKey,skills:keys.map(k=>p.skills?.[k]),bonuses:keys.map(k=>focusedBonus(p,k)),result});
  return result;
 }
 function project(p){
  const {_familyNotes,...result}=derive(p);
  return {...result,primaryPositions:result.primaryPositions.slice(),secondaryPositions:result.secondaryPositions.slice(),positionRatings:{...result.positionRatings},qualifiedFrontRowPositions:result.qualifiedFrontRowPositions.slice()};
 }

 function rating(p,slot){return derive(p).positionRatings[positionNumber(slot)]??0;}
 function efficiency(p,slot){const f=FAMILIES[positionNumber(slot)-1],data=derive(p);return Math.min(1,data.positionRatings[positionNumber(slot)]/Math.max(1,data._familyNotes[f]));}
 function contextualSkill(p,key,slot){return skill(p,key,true)*efficiency(p,slot);}
 let reservations=null,installed=false;
 function eligible(p,slot){
  if(!p)return false;
  if(reservations?.has(p.id)&&reservations.get(p.id)!==slot)return false;
  const n=positionNumber(slot);
  return n<=3?(slot<15?baseSlot(p,slot):baseBench(p,slot-15)):true;
 }
 // Reserve a complete matching of the six designated front-row shirts before
 // greedy selection can use one of those specialists as an emergency back.
 function availablePool(team){
  let pool=team.players.filter(p=>!p.injury);
  if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)){
   const fixture=CDWorldCareer.fixtures(S).find(f=>f.homeId===team.id||f.awayId===team.id);if(fixture)pool=pool.filter(p=>!CDWorldCareer.clubReleaseOn(S,p.id,fixture.date));
  }
  if(typeof CDWorldJapanQuota!=='undefined'&&CDWorldJapanQuota.activeClub(S,team.id)){
   const registered=CDWorldJapanQuota.registrationIds(S,team);pool=pool.filter(p=>registered.has(p.id));
  }
  return pool;
 }
 function reserveFront(team,preferred,bench){
  const prefs=Array.from({length:23},(_,i)=>i<15?preferred[i]:bench[i-15]),frontSlots=[0,1,2,15,16,17],taken=new Map(),assigned=new Map();
  const pool=availablePool(team);
  const fixedOther=new Set(prefs.filter((id,i)=>id&&!frontSlots.includes(i)));
  function place(slot,seen){
   const options=pool.filter(p=>!fixedOther.has(p.id)&&(slot<15?baseSlot(p,slot):baseBench(p,slot-15)))
    .sort((a,b)=>Number(b.id===prefs[slot])-Number(a.id===prefs[slot])||baseNote(b)-baseNote(a)||compareId(a,b));
   for(const p of options){if(seen.has(p.id))continue;seen.add(p.id);const previous=taken.get(p.id);
    if(previous===undefined||place(previous,seen)){taken.set(p.id,slot);assigned.set(slot,p.id);return true;}
   }return false;
  }
  for(const slot of frontSlots)place(slot,new Set());
  return new Map([...assigned].map(([slot,id])=>[id,slot]));
 }
 function installHooks(){
  if(installed)return;installed=true;
  const oldBuild=buildSheet,oldManager=managerSheet,oldStrategic=strategicPlayerScore;
  slotEligible=(p,slot)=>eligible(p,slot);benchEligible=(p,slot)=>eligible(p,slot+15);
  fitScore=(p,f=p.fam)=>{
   const n=FAMILIES.indexOf(f);return (f===p.fam?baseNote(p):rating(p,n))*(.5+p.condition*.005);
  };
  strategicPlayerScore=(p,slot,...args)=>oldStrategic({...p,fam:FAMILIES[slot]},slot,...args)*efficiency(p,slot);
  function improveBench(team,sheet,preferred=[]){
   const used=new Set(sheet.lineup.filter(Boolean)),wanted=[],pool=availablePool(team);
   for(let i=0;i<8;i++){
    const slot=i+15;
    let p=pool.find(p=>p.id===preferred[i]&&!p.injury&&!used.has(p.id)&&eligible(p,slot));
    if(!p&&i<3)p=pool.find(p=>p.id===sheet.bench[i]);
    if(!p)p=pool.filter(p=>!p.injury&&!used.has(p.id)&&eligible(p,slot))
     .sort((a,b)=>rating(b,slot)*(.5+b.condition*.005)-rating(a,slot)*(.5+a.condition*.005)||compareId(a,b))[0];
    wanted.push(p?.id??null);if(p)used.add(p.id);
   }
   // Existing registration/quota hooks remain the final authority.
   return oldBuild(team,sheet.lineup,wanted);
  }
  function reservedBuild(fn,team,preferred=[],bench=[],...args){
   if(reservations)return fn(team,preferred,bench,...args);
   reservations=reserveFront(team,preferred,bench);
   try{return improveBench(team,fn(team,preferred,bench,...args),bench);}finally{reservations=null;}
  }
  buildSheet=(team,preferred=[],bench=[])=>reservedBuild(oldBuild,team,preferred,bench);
  managerSheet=(team,...args)=>{
   if(reservations)return oldManager(team,...args);
   reservations=reserveFront(team,[],[]);try{return improveBench(team,oldManager(team,...args));}finally{reservations=null;}
  };
  unit=(live,side,key,filter)=>{
   const on=live.sheets[side].on,players=activePlayers(live,side);
   const list=players.map(p=>({p,slot:on.indexOf(p.id)})).filter(({p,slot})=>!filter||filter({...p,fam:FAMILIES[slot]}));
   return list.length?mean(list.map(({p,slot})=>contextualSkill(p,key,slot))):25;
  };
  sheetAverage=(team,ids,key,filter=()=>true)=>{
   const list=ids.map((id,slot)=>({p:team.players.find(p=>p.id===id),slot})).filter(({p,slot})=>p&&filter({...p,fam:FAMILIES[slot]}));
   return list.length?mean(list.map(({p,slot})=>contextualSkill(p,key,slot))):25;
  };
  dossierMetrics=(team,ids)=>{
   const players=ids.map(id=>team.players.find(p=>p.id===id)).filter(Boolean);
   const domains=Object.fromEntries(DOSSIER_DOMAINS.map(d=>{
    const has=ids.some((id,slot)=>id&&team.players.some(p=>p.id===id)&&d.families.includes(FAMILIES[slot]));
    return [d.key,has?mean(d.skills.map(key=>sheetAverage(team,ids,key,p=>d.families.includes(p.fam)))):0];
   }));
   return {...domains,fitness:mean(players.map(p=>p.condition)),tackle:players.length?sheetAverage(team,ids,'tackle'):0,speed:players.length?sheetAverage(team,ids,'speed'):0};
  };
 }
 return Object.freeze({project,positionNumber,rating,efficiency,contextualSkill,installHooks});
};
