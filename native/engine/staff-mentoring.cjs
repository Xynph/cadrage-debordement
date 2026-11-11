'use strict';
const files=Object.freeze([]),commands=Object.freeze(['staff_mentoring_enable','staff_mentor_assign','staff_mentor_remove']);
// Serialized with the closed native manifest. No new XP, RNG, fees or salary.
function factory(){
 const POLICY='existing-training-budget-v1',ROLES=['coach','assistant','formation'],MAX_ASSIGNMENTS=6,MAX_EXPERIENCE=64;
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b,id=x=>typeof x==='string'&&/^[A-Za-z0-9:._-]{1,240}$/.test(x);
 const check=(x,message)=>{if(!x)throw Error('Mentorat du staff : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S,week=s=>s.worldMode?.week??s.franceMode?.week??s.round,context=s=>({season:s.season,week:week(s),club:s.club});
 const active=s=>s?.staffMentoring?.version===1,staff=s=>(s?.staffCareer?.people||[]).flat();
 const players=s=>[...(s?.clubs?.[s.club]?.players||[]),...(s?.development?.academy||[])];
 const annual=p=>typeof nativeInSeasonDevelopment==='undefined'&&(p.lnrRatingsVersion===1||p.worldRatingsVersion===1);
 const options=p=>typeof developmentFocusOptions==='function'?developmentFocusOptions(p).filter(k=>k!=='equilibre'):[];
 const eligible=p=>int(p?.age,15,24)&&!annual(p);
 const available=(s,m)=>m&&m.clubId===s.club&&m.contractEnd>=s.season&&ROLES.includes(m.role);
 const locked=s=>!s||!!s.live||!!s.trained||s.phase!=='league';
 const explicit=(s,p)=>s.youthDevelopment?.version===1&&s.youthDevelopment.rows.some(row=>row.id===p.id&&row.plan&&row.planClubId===s.club);
 function validate(s){
  if(!s||s.staffMentoring===undefined)return true;
  check(s.staffCareer?.version===1,'cycle staff requis pour ce mentorat');
  const st=s.staffMentoring;check(shape(st,['version','policy','enabledSeason','assignments','experience'])&&st.version===1&&st.policy===POLICY&&int(st.enabledSeason,1,s.season),'version invalide');
  check(Array.isArray(st.assignments)&&st.assignments.length<=MAX_ASSIGNMENTS&&Array.isArray(st.experience)&&st.experience.length<=MAX_EXPERIENCE,'capacité invalide');
  const mentors=new Set(),pupils=new Set();
  for(const a of st.assignments){check(shape(a,['staffId','playerId','focus','clubId','season','week'])&&id(a.staffId)&&id(a.playerId)&&!mentors.has(a.staffId)&&!pupils.has(a.playerId)&&typeof a.focus==='string'&&['scrum','lineout','tackle','speed','pass','kick','goal','power','stamina','mental','discipline'].includes(a.focus)&&int(a.clubId,0,s.clubs.length-1)&&int(a.season,st.enabledSeason,s.season)&&int(a.week,0,100)&&(a.season<s.season||a.week<=week(s)),'affectation invalide');mentors.add(a.staffId);pupils.add(a.playerId);}
  const seen=new Set();
  for(const e of st.experience){check(shape(e,['staffId','sessions'])&&id(e.staffId)&&!seen.has(e.staffId)&&Array.isArray(e.sessions)&&e.sessions.length<=8,'expérience invalide');seen.add(e.staffId);let prev=null;
   for(const row of e.sessions){check(shape(row,['season','week','playerId','amount'])&&int(row.season,st.enabledSeason,s.season)&&int(row.week,0,100)&&(row.season<s.season||row.week<=week(s))&&id(row.playerId)&&typeof row.amount==='number'&&Number.isFinite(row.amount)&&row.amount>0&&row.amount<=1,'séance invalide');check(!prev||row.season>prev.season||row.season===prev.season&&row.week>prev.week,'séances répétées ou désordonnées');prev=row;}
  }
  check(st.assignments.every(a=>seen.has(a.staffId)),'référence pédagogique absente');return true;
 }
 function assignment(s,p){if(!active(s)||!eligible(p))return null;const a=s.staffMentoring.assignments.find(a=>a.playerId===p.id&&a.clubId===s.club);if(!a||!available(s,staff(s).find(m=>m.id===a.staffId))||!players(s).some(q=>q===p)||developmentFocusValue(p)!==a.focus||explicit(s,p))return null;return a;}
 function experience(s,a){return s.staffMentoring.experience.find(e=>e.staffId===a.staffId);}
 function share(s,a){return experience(s,a).sessions.length>=8?.5:.25;}
 function execute(command,p){
  const s=state(),specific=command==='staff_mentor_assign'?['staffId','playerId','focus']:command==='staff_mentor_remove'?['staffId']:[];
  check(s&&['staff_mentoring_enable','staff_mentor_assign','staff_mentor_remove'].includes(command)&&shape(p,['context','confirmed',...specific])&&p.confirmed===true&&shape(p.context,['season','week','club']),'paramètres invalides');
  check(Object.keys(context(s)).every(k=>p.context[k]===context(s)[k]),'contexte périmé');check(!locked(s),'gestion avant la séance et hors match');validate(s);
  check(s.staffCareer?.version===1,'activez les carrières du staff');
  if(command==='staff_mentoring_enable'){check(!active(s)&&s.staffMentoring===undefined,'mentorat déjà actif');s.staffMentoring={version:1,policy:POLICY,enabledSeason:s.season,assignments:[],experience:[]};}
  else{
   check(active(s),'activer le mentorat');const st=s.staffMentoring;
   if(command==='staff_mentor_remove'){check(id(p.staffId)&&st.assignments.some(a=>a.staffId===p.staffId&&a.clubId===s.club),'affectation absente');st.assignments=st.assignments.filter(a=>a.staffId!==p.staffId);}
   else{
    const m=staff(s).find(m=>m.id===p.staffId),q=players(s).find(q=>q.id===p.playerId);check(available(s,m),'mentor de terrain indisponible');check(eligible(q)&&options(q).includes(p.focus),'jeune ou qualité incompatible');
    const retained=st.assignments.filter(a=>a.clubId===s.club&&available(s,staff(s).find(member=>member.id===a.staffId))&&players(s).some(player=>player.id===a.playerId&&eligible(player)));
    check(!retained.some(a=>a.playerId===q.id&&a.staffId!==m.id),'ce jeune a déjà un mentor');check(retained.some(a=>a.staffId===m.id)||retained.length<MAX_ASSIGNMENTS,'six affectations maximum');
    const retainedExperience=st.experience.filter(e=>staff(s).some(member=>member.id===e.staffId&&available(s,member)));
    let e=retainedExperience.find(e=>e.staffId===m.id);check(e||retainedExperience.length<MAX_EXPERIENCE,'registre pédagogique complet');
    st.assignments=retained;st.experience=retainedExperience;
    if(!e){e={staffId:m.id,sessions:[]};st.experience.push(e);}
    const specialization=ensureSpecialization(q);if(!explicit(s,q)&&specialization.focus!==p.focus){specialization.focus=p.focus;specialization.xp=0;}
    st.assignments=st.assignments.filter(a=>a.staffId!==m.id);st.assignments.push({staffId:m.id,playerId:q.id,focus:p.focus,clubId:s.club,season:s.season,week:week(s)});
   }
  }
  validate(s);return {staffMentoringAction:{command,growthAwarded:0,cost:0}};
 }
 function project(){
  const s=state();if(!s)return {available:false,enabled:false,assignments:[],mentors:[],players:[]};
  const enabled=active(s),st=s.staffMentoring;
  return {available:s.staffCareer?.version===1,enabled,canEnable:s.staffCareer?.version===1&&!enabled&&!locked(s),locked:locked(s),context:context(s),maxAssignments:MAX_ASSIGNMENTS,dormantAssignments:enabled?st.assignments.filter(a=>a.clubId!==s.club||!available(s,staff(s).find(m=>m.id===a.staffId))||!players(s).some(p=>p.id===a.playerId&&eligible(p))).length:0,
   notice:'Un mentor, un jeune : 25 % de l’expérience existante ciblés, puis 50 % après huit séances observées. Le reste progresse en général. Le ciblage manuel existant reste disponible à 50 % : au début, le mentorat privilégie davantage le niveau général, sans avantage exclusif. Aucun point supplémentaire ni coût. Les plans individuels explicites gardent priorité. Une nouvelle affectation libère les liens devenus indisponibles et les références pédagogiques des mentors partis.',
   mentors:staff(s).filter(m=>available(s,m)).map(m=>({id:m.id,name:m.name,role:m.role,converted:!!m.sourcePlayerId,observedSessions:enabled?(st.experience.find(e=>e.staffId===m.id)?.sessions.length||0):0})),
   players:players(s).filter(eligible).map(p=>({id:p.id,name:p.name,pos:p.pos,focusOptions:options(p).map(key=>({key,label:typeof ATTR==='undefined'?key:ATTR[key]}))})),
   assignments:enabled?st.assignments.filter(a=>a.clubId===s.club).map(a=>{const p=players(s).find(p=>p.id===a.playerId),m=staff(s).find(m=>m.id===a.staffId),e=experience(s,a);const reason=!available(s,m)?'Mentor parti, contrat terminé ou rôle incompatible':!p?'Jeune sorti du club':!eligible(p)?'Âge ou progression annuelle incompatible':developmentFocusValue(p)!==a.focus?'Qualité individuelle modifiée':explicit(s,p)?'Plan individuel prioritaire':'';return {...copy(a),playerName:p?.name||a.playerId,staffName:m?.name||a.staffId,sessions:e.sessions.length,targetShare:share(s,a),active:!reason,reason,observations:copy(e.sessions)};}):[]};
 }
 function installHooks(){
  if(typeof developmentTraining!=='function'||developmentTraining.__nativeMentoring)return true;
  const original=developmentTraining;
  const wrapped=function(p,mode,ci=null){
   const s=state(),a=s&&!s.live&&s.phase==='league'&&mode!=='repos'&&!p.injury?assignment(s,p):null;
   if(!a||typeof CDYouthDevelopment==='undefined'||!focusedGrowthAllowed(p))return original.apply(this,arguments);
   const budget=q=>(q.dev?.xp||0)+(q.dev?.specialization?.xp||0)+(q.rating||0)+Object.values(q.dev?.specialization?.bonuses||{}).reduce((n,v)=>n+v,0)*.5;
   const prior=CDYouthDevelopment.growthShare,target=share(s,a),before=budget(p);
   CDYouthDevelopment.growthShare=function(current,q,allow){return current===s&&q===p&&allow?target:prior.apply(this,arguments);};
   let result;try{result=original.apply(this,arguments);}finally{CDYouthDevelopment.growthShare=prior;}
   const after=budget(p),amount=after-before;
   const e=experience(s,a),last=e.sessions.at(-1);
   if(amount>0&&amount<=1&&e.sessions.length<8&&(!last||last.season<s.season||last.season===s.season&&last.week<week(s)))e.sessions.push({season:s.season,week:week(s),playerId:p.id,amount});
   return result;
  };Object.assign(wrapped,original);wrapped.__nativeMentoring=true;developmentTraining=wrapped;return true;
 }
 return {validate,execute,project,installHooks};
}
module.exports={files,commands,factory};
