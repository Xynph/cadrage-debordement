'use strict';

function factory(eligibility){
 const leagueIds=['jlo-d1','jlo-d2'];
 const basisRank={ 'official-2026-27':3,'derived-official-criteria':2,estimated:1 };
 const check=(yes,message)=>{if(!yes)throw Error('League One : '+message);};
 const count=(xs,c)=>xs.filter(p=>p.category===c).length;
 const valid=xs=>new Set(xs.map(p=>p?.id)).size===xs.length&&xs.every(p=>p&&typeof p.id==='string'&&eligibility.categories.includes(p.category));
 function selectRegistration(players){
  check(valid(players),'catégories d’inscription invalides.');
  const ordered=players.slice().sort((a,b)=>(basisRank[b.basis]||0)-(basisRank[a.basis]||0)||(b.rank||0)-(a.rank||0)||a.id.localeCompare(b.id,'en'));
  let bc=0,c=0;
  return ordered.filter(p=>{
   if(p.category==='A-1'||p.category==='A-2')return true;
   if(bc>=10||(p.category==='C'&&c>=3))return false;
   bc++;c+=+(p.category==='C');return true;
  });
 }
 function partialSheet(starters,bench){
  const all=[...starters,...bench];
  return valid(all)&&starters.length<=15&&bench.length<=8&&count(all,'B')+count(all,'C')<=6&&count(all,'C')<=3
    &&all.length-count(all,'A-1')<=9&&starters.length-count(starters,'A-1')<=7&&count(starters,'C')<=3;
 }
 function changeAllowed(active,out,incoming){
  if(!valid(active)||active.length>15||out!==null&&!active.some(p=>p.id===out)||incoming&&active.some(p=>p.id===incoming.id))return false;
  const next=active.filter(p=>p.id!==out).concat(incoming?[incoming]:[]),a=count(next,'A-1');
  if(!valid(next)||next.length>15||next.length-a>7||count(next,'C')>3)return false;
  const before=count(active,'A-1'),minimum=next.length===15?8:incoming&&out!==null?Math.min(8,before):Math.max(0,next.length-7);
  return a>=minimum;
 }
 const edition=s=>typeof CDWorldCareer!=='undefined'&&[3,4,5].includes(CDWorldCareer.edition(s)?.version)?CDWorldCareer.edition(s):null;
 const activeClub=(s,id)=>edition(s)&&leagueIds.some(k=>s.worldMode.leagues[k].members.includes(id));
 const activeMatch=(s,l)=>edition(s)&&['jlo-d1','jlo-d2','jlo-d1-d2'].includes(l?.worldContext?.competitionId);
 function classified(s,p){
  const e=edition(s),initial=e?.registry.japanCategories?.[p.id];
  if(initial)return {id:p.id,...initial,rank:CDWorldCareer.sourcePlayer(s,p.id)?.rating||0};
  const youth=/^youth-(\d+)-\d+-\d+$/.exec(p.id);
  const trained=!!youth&&Number(youth[1])>=68&&Number(youth[1])<=87||/^jlo-academy-(6[89]|7\d|8[0-7])-\d+-\d+-\d+$/.test(p.id);
  return {id:p.id,category:trained?'A-1':'C',basis:'estimated',reason:trained?'local-game-academy':'unverified-recruit-registration',rank:0};
 }
 const registered=(s,club)=>selectRegistration(club.players.map(p=>classified(s,p)));
 const registrationIds=(s,club)=>new Set(registered(s,club).map(p=>p.id));
 function list(s,c,ids){
  const players=new Map(c.players.map(p=>[p.id,p]));
  return ids.filter(Boolean).map(id=>players.has(id)?classified(s,players.get(id)):{id,category:null});
 }
 function nominations(s,c,lineup,bench,{partial=false}={}){
  if(!activeClub(s,c.id))return true;
  const allowed=registrationIds(s,c),one=list(s,c,lineup),two=list(s,c,bench);
  if([...one,...two].some(p=>!allowed.has(p.id)))return false;
  return partial?partialSheet(one,two):eligibility.teamSheet(one,two,{frontRow:6}).valid;
 }
 function onField(s,l,side){
  const sh=l.sheets[side];
  return list(s,s.clubs[l.pair[side]],sh.on.filter(id=>!sh.cards.some(c=>c.id===id&&c.until>l.minute)));
 }
 function afterSuspensions(s,l,side,out=null,incoming=null,target=-1){
  const sh=l.sheets[side],on=sh.on.slice(),from=out===null?-1:on.indexOf(out);
  if(from>=0)on[from]=null;
  if(incoming!==null){
   const slot=target>=0?target:from>=0?from:on.indexOf(null);
   if(slot>=0)on[slot]=incoming;else on.push(incoming);
  }
  for(const [caseIndex,e] of (sh.front?.exclusions||[]).entries()){
   if(e.kind!=='yellow'||e.closed||e.until<=l.minute||sh.sentOff.includes(e.id))continue;
   on[e.slot]=e.id;
   for(const hold of sh.front.held)if(hold.caseIndex===caseIndex&&!on[hold.slot]&&!sh.sentOff.includes(hold.id))on[hold.slot]=hold.id;
   // A new temporary specialist is about to take the suspended player's
   // place. The donor is still on the team sheet when this choice is tested.
   if(incoming!==null&&target===e.slot&&from>=0&&from!==target&&!on[from])on[from]=out;
  }
  return list(s,s.clubs[l.pair[side]],on);
 }
 function validField(field){
  return valid(field)&&field.length<=15&&field.length-count(field,'A-1')<=7&&count(field,'C')<=3;
 }
 function matchChange(s,l,side,out,incoming,target=-1){
  if(!activeMatch(s,l))return true;
  const c=s.clubs[l.pair[side]],candidate=incoming?c.players.find(p=>p.id===incoming):null;
  return (!incoming||candidate)&&changeAllowed(onField(s,l,side),out,candidate?classified(s,candidate):null)
    &&validField(afterSuspensions(s,l,side,out,incoming,target));
 }
 function validate(s){
  if(!edition(s))return;
  const c=s.clubs[s.club];
  check(nominations(s,c,s.lineup,s.reserves,{partial:true}),'feuille enregistrée hors quotas ou inscription.');
  const l=s.live;if(!activeMatch(s,l))return;
  for(const [i,sh] of l.sheets.entries()){
   const team=s.clubs[l.pair[i]];
   check(Array.isArray(sh.nominated)&&nominations(s,team,sh.nominated.slice(0,15),sh.nominated.slice(15)),'nomination de match incompatible avec les quotas.');
   check(validField(onField(s,l,i))&&validField(afterSuspensions(s,l,i)),'joueurs sur le terrain ou retours de suspension hors quotas.');
  }
 }
 let installed=false;
 function installHooks(){
  if(installed)return;installed=true;
  const originalBuild=buildSheet,originalErrors=sheetErrors,originalLegal=legalChange,originalCover=promoteCover;
  const originalManager=managerSheet;
  const originalSlot=slotEligible,originalBench=benchEligible;
  const qualified=(p,slot,base)=>base(p,slot)||!!p&&p.worldRatingsVersion===1&&p.id.startsWith("world:jlo:")
    &&p.worldProfile?.position?.qualifications?.some(pos=>{const i=POS.indexOf(pos);return i>=0&&pos!==p.pos&&base({...p,pos,fam:FAMILIES[i]},slot);});
  slotEligible=(p,slot)=>qualified(p,slot,originalSlot);
  benchEligible=(p,slot)=>qualified(p,slot,originalBench);
  buildSheet=function(c,preferred=[],preferredBench=[]){
   if(!activeClub(S,c.id))return originalBuild(c,preferred,preferredBench);
   const available=registrationIds(S,c),team={...c,players:c.players.filter(p=>available.has(p.id))};
   let normal=originalBuild(team,preferred,preferredBench);
   if(nominations(S,c,normal.lineup,normal.bench))return normal;
   const favorites=[...preferred,...preferredBench],picks=team.players.filter(p=>!p.injury);
   const slots=Array.from({length:23},(_,slot)=>({
    slot,starter:slot<15,candidates:picks.filter(p=>slot<15?slotEligible(p,slot):benchEligible(p,slot-15))
     .map(p=>({...classified(S,p),rank:fitScore(p)+(favorites[slot]===p.id?1000:0)}))
   }));
   if(slots.every(s=>s.candidates.length)){
    const found=eligibility.planSheet(slots,{frontRow:6});
    if(found.valid)return {lineup:found.assignment.slice(0,15).map(p=>p.id),bench:found.assignment.slice(15).map(p=>p.id)};
   }
   // An incomplete sheet remains editable. Remove over-quota nominations
   // before the existing academy cover path fills the empty positions.
   const ids=[...normal.lineup,...normal.bench];
   for(let i=22;i>=0&&!nominations(S,c,ids.slice(0,15),ids.slice(15),{partial:true});i--){
    const p=team.players.find(p=>p.id===ids[i]);
    if(p&&classified(S,p).category!=='A-1')ids[i]=null;
   }
   return {lineup:ids.slice(0,15),bench:ids.slice(15)};
  };
  managerSheet=function(c,opponent,weather,level){
   const proposed=originalManager(c,opponent,weather,level);
   if(!activeClub(S,c.id)||c.id===S.club||nominations(S,c,proposed.lineup,proposed.bench))return proposed;
   // Keep the tactical preferences where the quota-aware builder can use them.
   const adjusted=buildSheet(c,proposed.lineup,proposed.bench);
   return nominations(S,c,adjusted.lineup,adjusted.bench)?adjusted:buildSheet(c);
  };
  sheetErrors=function(){
   const errors=originalErrors();
   if(activeClub(S,S.club)&&!nominations(S,club(),S.lineup,S.reserves))errors.push('League One : vérifiez les inscriptions et les quotas de la feuille (14 A-1, au plus 6 B/C).');
   return errors;
  };
  promoteCover=function(){
   if(!activeClub(S,S.club))return originalCover();
   if(S.live)return;
   repairSheet();
   const vacancy=[...S.lineup,...S.reserves].map((id,i)=>id?null:i).filter(i=>i!==null);
   if(vacancy.length>professionalPlaces())return false;
   for(const i of vacancy){
    const bench=i>=15,slot=bench?[1,0,2,3,5,8,9,10][i-15]:i,list=bench?S.reserves:S.lineup;
    const p=makePlayer(400+i,slot,56);
    p.id='jlo-academy-'+S.club+'-'+S.season+'-'+S.round+'-'+(S.playerSerial=(S.playerSerial||0)+1);
    p.rating=rand(52,61);p.age=19;p.condition=100;p.salary=2500;delete p.skills;
    ensureSkills(p);ensureContract(p);ensureDevelopment(p);club().players.push(p);list[bench?i-15:i]=p.id;
   }
   if(vacancy.length)news(vacancy.length+' espoir(s) promu(s) pour compléter la feuille de match.');
   save();render();toast(vacancy.length?vacancy.length+' espoir(s) rejoint le groupe.':'Votre feuille de match est complète.');
  };
  legalChange=function(l,side,slot,incoming){
   return originalLegal(l,side,slot,incoming)&&matchChange(S,l,side,l.sheets[side].on[slot],incoming,slot);
  };
 }
 function project(s,m){
  if(!activeClub(s,s.club))return;
  const c=s.clubs[s.club],ids=registrationIds(s,c);
  for(const p of m.squad){
   const info=classified(s,p);p.japanCategory=info.category;p.japanCategoryBasis=info.basis;p.japanRegistered=ids.has(p.id);
   const profile=edition(s).registry.worldProfiles[p.id];if(profile)p.worldProfile=profile;
  }
  for(const slot of m.selection.slots)slot.eligibleIds=slot.eligibleIds.filter(id=>ids.has(id));
  const rows=registered(s,c),selected=list(s,c,[...s.lineup,...s.reserves]);
  m.japanEligibility={registered:rows.length,notRegistered:c.players.length-rows.length,counts:Object.fromEntries(eligibility.categories.map(cat=>[cat,count(selected,cat)])),valid:nominations(s,c,s.lineup,s.reserves),minimumA1:14,maximumBC:6,maximumC:3};
 }
 return Object.freeze({selectRegistration,partialSheet,changeAllowed,activeClub,classified,registrationIds,nominations,matchChange,validate,installHooks,project});
}
module.exports={factory,...factory(require('./japan-eligibility.cjs'))};
