'use strict';
// The authoritative profile and rating stay unchanged. Current FFR starting
// shirts may prove an extra qualification, including for a reused LNR ID.
module.exports=function installNationaleSquad(){
 const baseSlot=slotEligible,baseBench=benchEligible,baseBuild=buildSheet;
 function can(p,slot,base){
  if(base(p,slot))return true;
  return !!p&&Array.isArray(p.nationaleQualifications)&&p.nationaleQualifications.some(pos=>{
   const i=POS.indexOf(pos);
   return i>=0&&pos!==p.pos&&base({...p,pos,fam:FAMILIES[i]},slot);
  });
 }
 slotEligible=(p,slot)=>can(p,slot,baseSlot);
 benchEligible=(p,slot)=>can(p,slot,baseBench);
 buildSheet=function(c,preferred=[],preferredBench=[]){
  const normal=baseBuild(c,preferred,preferredBench);
  if(!c.players.some(p=>p.nationaleQualifications?.length))return normal;
  const front=[0,1,2,15,16,17],draft=[...normal.lineup,...normal.bench];
  if(front.every(i=>draft[i]))return normal;
  // Protect all six front-row slots when a versatile prop was chosen for the
  // wrong side by greedy selection. Other positions are still filled normally.
  const assigned=new Map(),slots=new Map();
  const opts=new Map(front.map(i=>[i,c.players.filter(p=>!p.injury&&(i<15?slotEligible(p,i):benchEligible(p,i-15)))
   .sort((a,b)=>(Number(b.id===draft[i])-Number(a.id===draft[i]))*1000+fitScore(b)-fitScore(a)||a.id.localeCompare(b.id))]));
  function place(i,seen){
   for(const p of opts.get(i)){
    if(seen.has(p.id))continue;seen.add(p.id);
    if(!assigned.has(p.id)||place(assigned.get(p.id),seen)){assigned.set(p.id,i);slots.set(i,p.id);return true;}
   }
   return false;
  }
  for(const i of front.slice().sort((a,b)=>opts.get(a).length-opts.get(b).length||a-b))if(!place(i,new Set()))return normal;
  const choices=draft.slice();for(const [i,id]of slots)choices[i]=id;
  // Lock the new six assignments to avoid a prop being taken out of position
  // by a preferred, non-front-row bench slot when the ordinary builder reruns.
  for(let i=0;i<choices.length;i++)if(!slots.has(i)&&assigned.has(choices[i]))choices[i]=null;
  return baseBuild(c,choices.slice(0,15),choices.slice(15));
 };
 const strategy=managerSheet;
 const complete=sheet=>[...sheet.lineup,...sheet.bench].every(Boolean);
 managerSheet=function(c,opponent,weather,level){
  const proposed=strategy(c,opponent,weather,level);
  if((CDWorldEditions.forState(S)?.version??0)<4||complete(proposed))return proposed;
  // The tactical picker can consume a versatile prop in a different slot
  // after the pre-match AI has already built a legal sheet. Reassign the
  // selected group before using the valid ordinary sheet as a fallback.
  const adjusted=buildSheet(c,proposed.lineup,proposed.bench);
  return complete(adjusted)?adjusted:buildSheet(c);
 };
};
