'use strict';
// The authoritative profile and rating stay unchanged. Current FFR starting
// shirts may prove an extra qualification, including for a reused LNR ID.
module.exports=function installNationaleSquad(){
 const baseSlot=slotEligible,baseBench=benchEligible,baseBuild=buildSheet;
 const front=[0,1,2,15,16,17];
 function can(p,slot,base){
  if(base(p,slot))return true;
  return !!p&&Array.isArray(p.nationaleQualifications)&&p.nationaleQualifications.some(pos=>{
   const i=POS.indexOf(pos);
   return i>=0&&pos!==p.pos&&base({...p,pos,fam:FAMILIES[i]},slot);
  });
 }
 slotEligible=(p,slot)=>can(p,slot,baseSlot);
 benchEligible=(p,slot)=>can(p,slot,baseBench);
 function assignFront(c,draft){
  const assigned=new Map(),slots=new Map();
  const opts=new Map(front.map(i=>{
   const candidates=c.players.filter(p=>!p.injury&&(i<15?slotEligible(p,i):benchEligible(p,i-15)));
   if(draft)candidates.sort((a,b)=>(Number(b.id===draft[i])-Number(a.id===draft[i]))*1000+fitScore(b)-fitScore(a)||a.id.localeCompare(b.id));
   return [i,candidates];
  }));
  function place(i,seen){
   for(const p of opts.get(i)){
    if(seen.has(p.id))continue;seen.add(p.id);
    if(!assigned.has(p.id)||place(assigned.get(p.id),seen)){assigned.set(p.id,i);slots.set(i,p.id);return true;}
   }
   return false;
  }
  for(const i of front.slice().sort((a,b)=>opts.get(a).length-opts.get(b).length||a-b))if(!place(i,new Set()))return null;
  return {assigned,slots};
 }
 buildSheet=function(c,preferred=[],preferredBench=[]){
  const normal=baseBuild(c,preferred,preferredBench);
  if(!c.players.some(p=>p.nationaleQualifications?.length))return normal;
  const draft=[...normal.lineup,...normal.bench];
  if(front.every(i=>draft[i]))return normal;
  // Protect all six front-row slots when a versatile prop was chosen for the
  // wrong side by greedy selection. Other positions are still filled normally.
  const allocation=assignFront(c,draft);
  if(!allocation)return normal;
  const {assigned,slots}=allocation;
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

 // FFR 2026–27, règle 3. In regular Nationale, 22 can start with a
 // qualified replacement hooker and one replacement prop. Offer this only
 // when the missing prop slot cannot be filled by reassigning versatile players.
 function regularFixture(s){
  if(s?.phase!=='league'||!CDWorldCareer.active(s))return null;
  const f=CDWorldCareer.userFixture(s);
  return f?.competitionId==='nationale'&&f.phase==='league'?f:null;
 }
 function propVacancy(s){
  const {lineup,reserves}=s;
  if(lineup.length!==15||reserves.length!==8)return null;
  const vacancy=reserves.indexOf(null);
  if(vacancy!==1&&vacancy!==2)return null;
  const c=s.clubs[s.club],players=new Map(c.players.map(p=>[p.id,p])),ids=[...lineup,...reserves];
  if(new Set(ids).size!==23)return null;
  const eligible=(id,i)=>{
   if(i===15+vacancy)return id===null;
   const p=players.get(id);
   return p&&!p.injury&&(i<15?slotEligible(p,i):benchEligible(p,i-15));
  };
  return ids.every(eligible)&&!assignFront(c,null)?16+vacancy:null;
 }
 function vacancy(s){return !s?.live&&regularFixture(s)?propVacancy(s):null;}
 function validate(s,l){
  const f=regularFixture(s),marker=l.nationaleReducedBench;
  if(!f||f.id!==l.worldContext?.id||l.pair[0]!==f.homeId||l.pair[1]!==f.awayId)return false;
  if(!saveObject(marker)||Object.keys(marker).length!==1||![17,18].includes(marker.vacantNumber)||propVacancy(s)!==marker.vacantNumber)return false;
  const sh=l.sheets[l.userSide],nominated=[...s.lineup,...s.reserves.filter(Boolean)];
  return sh.initial.every((id,i)=>id===s.lineup[i])&&Array.isArray(sh.nominated)&&sh.nominated.length===nominated.length&&
   sh.nominated.every((id,i)=>id===nominated[i]);
 }
 return Object.freeze({vacancy,validate});
};
