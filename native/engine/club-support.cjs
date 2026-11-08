'use strict';
const files=Object.freeze(['staff-meeting-v65.js','staff-advisor-v66.js','training-plans-v67.js','medical-decisions-v68.js','briefing-strategique-v69.js','bureau-agents-v71.js']);
const commands=Object.freeze(['staff_meeting','training_plan','medical_protocol','medical_return','strategic_briefing','agent_negotiate','agent_confirm']);
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x),keys=(x,list)=>obj(x)&&Object.keys(x).every(k=>list.includes(k)),int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b;
 const check=(ok,message='État staff, médical ou agents invalide.')=>{if(!ok)throw Error(message);};
 const week=s=>s.franceMode?.version===1?s.franceMode.week:s.round,context=s=>({season:s.season,week:week(s),club:s.club});
 const roster=s=>s.clubs[s.club].players;
 const sameContext=(a,b)=>a?.season===b.season&&a?.week===b.week&&a?.club===b.club;
 const meetingAvailable=()=>CDStaffMeetingV65.available(S)&&!sameContext(S.nativeSupport?.meeting?.context,context(S));
 const bridge=()=>({reservation:reservationWage,fee:contractFee,negotiate:negotiateContract,save:()=>true});
 function validate(s){
  if(!s)return true;
  const max=s.franceMode?.version===1?34:29,date=(season,w)=>int(season,1,s.season)&&int(w,0,max)&&(season<s.season||w<=week(s)),serialDate=(season,w)=>int(season,1,s.season)&&int(w,0,s.economy.week);
  if(s.nativeSupport!==undefined){const n=s.nativeSupport,m=n.meeting;check(keys(n,['version','meeting'])&&Object.keys(n).length===2&&n.version===1&&keys(m,['context','plan'])&&Object.keys(m).length===2&&keys(m.context,['season','week','club'])&&Object.keys(m.context).length===3&&date(m.context.season,m.context.week)&&int(m.context.club,0,s.clubs.length-1)&&Object.hasOwn(CDStaffMeetingV65.OPTIONS,m.plan),'Décision de staff native invalide.');}
  const meetings=new Set();for(const receipt of s.manager?.inbox||[]){if(receipt.kind!=='staff-v65')continue;const key=receipt.season+':'+receipt.week;check(!meetings.has(key)&&Object.values(CDStaffMeetingV65.OPTIONS).some(o=>receipt.title==='Réunion de staff : '+o.label)&&serialDate(receipt.season,receipt.week),'Compte rendu de staff V65 invalide.');meetings.add(key);}
  const medical=p=>{if(p.medicalV68===undefined)return;const m=p.medicalV68;check(keys(m,['version','protocol','stage'])&&Object.keys(m).length===3&&m.version===1&&Object.hasOwn(CDMedicalV68.PROTOCOLS,m.protocol)&&['blesse','reprise','progressif','termine'].includes(m.stage),'État médical V68 invalide.');};
  for(const c of s.clubs)for(const p of c.players)medical(p);
  for(const p of [...(s.market||[]),...(s.economy?.freeAgents||[]),...(s.development?.academy||[])])medical(p);
  if(s.v71AgentDesk!==undefined){
   const d=s.v71AgentDesk;check(keys(d,['version','history'])&&Object.keys(d).length===2&&d.version===1&&Array.isArray(d.history)&&d.history.length<=24,'Historique des agents V71 invalide.');
   const seen=new Set();let prior=Infinity;
   for(const h of d.history){check(keys(h,['id','season','week','years','policy','wage','status','attempt'])&&Object.keys(h).length===8&&typeof h.id==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(h.id)&&serialDate(h.season,h.week)&&int(h.years,1,3)&&Object.hasOwn(CDAgentsV71.POLICY,h.policy)&&int(h.wage,1000,100000)&&['ready','counter','withdrawn','signed'].includes(h.status)&&int(h.attempt,1,3),'Mandat d’agent V71 invalide.');const stamp=h.season*100+h.week,key=stamp+':'+h.id+':'+h.attempt;check(stamp<=prior&&!seen.has(key),'Mandat d’agent répété ou mal daté.');seen.add(key);prior=stamp;}
  }
  if(s.v69Briefing!==undefined){
   const b=s.v69Briefing,m=typeof b.context==='string'&&b.context.match(/^(\d+):(\d+):(league|barrage|semi|final):(\d+):(\d+)$/);check(keys(b,['version','context','plan'])&&Object.keys(b).length===3&&b.version===1&&Object.hasOwn(V69_PLANS,b.plan)&&m&&date(+m[1],+m[2])&&int(+m[4],0,s.clubs.length-1)&&int(+m[5],0,s.clubs.length-1)&&m[4]!==m[5],'Briefing stratégique V69 invalide.');
  }
  if(s.live?.v69Briefing!==undefined){const b=s.live.v69Briefing;check(keys(b,['version','plan','side','opponent','strength'])&&Object.keys(b).length===5&&b.version===1&&Object.hasOwn(V69_PLANS,b.plan)&&int(b.side,0,1)&&s.live.pair[1-b.side]===b.opponent&&keys(b.strength,['pack','backs','danger'])&&Object.keys(b.strength).length===3&&Object.values(b.strength).every(x=>int(x,-100,100)),'Briefing de match V69 invalide.');}
  return true;
 }
 function project(){
  if(!S)return null;
  const plans=Object.entries(CDTrainingPlansV67.PLANS).map(([key,p])=>{const preview=copy(CDTrainingPlansV67.preview(S,key,{outcome:physicalTrainingOutcome}));for(const row of preview.players)delete row.name;return {...copy(p),...preview};});
  const dossier=!S.live&&S.phase!=='ended'?matchDossier():null;
  const players=roster(S).map(p=>({id:p.id,contractEnd:p.contractEnd,salary:p.salary,quotes:[1,2,3].flatMap(years=>Object.keys(CDAgentsV71.POLICY).map(policy=>CDAgentsV71.quote(S,p.id,years,policy,bridge())).filter(Boolean).map(q=>{const result=copy(q);delete result.name;return result;}))})).filter(p=>p.quotes.length);
  return {context:context(S),notice:'Arbitrages fictifs du jeu. Le suivi médical générique ne représente ni une commotion, ni un protocole HIA, ni un avis de santé. Les budgets sont fictifs.',diagnostic:{...copy(CDStaffAdvisorV66.diagnostic(S,CDStaffMeetingV65)),available:meetingAvailable()},meeting:{available:meetingAvailable(),receipt:copy(CDStaffMeetingV65.currentMeeting(S)),lastDecision:copy(S.nativeSupport?.meeting||null),options:Object.entries(CDStaffMeetingV65.OPTIONS).map(([key,o])=>({key,...copy(o),preview:copy(CDStaffMeetingV65.preview(S,key))}))},training:{available:CDTrainingPlansV67.allowed(S),plans},medical:{available:CDMedicalV68.canManage(S),protocols:Object.entries(CDMedicalV68.PROTOCOLS).map(([key,p])=>({key,...copy(p)})),players:roster(S).filter(p=>p.injury>0||p.medicalV68?.stage==='reprise').map(p=>({id:p.id,injury:p.injury,condition:p.condition,fatigue:p.physicalLoad?.fatigue??0,protocol:CDMedicalV68.treatment(p),stage:p.medicalV68?.stage??'blesse'}))},briefing:{available:!!dossier,fixture:dossier?v69Context(dossier):null,opponentId:dossier?.opponent.id??null,selected:dossier?v69Selection(dossier):'neutre',evidence:dossier?copy(v69Evidence(dossier)):null,plans:Object.entries(V69_PLANS).map(([key,p])=>({key,...copy(p)}))},agents:{players,policies:Object.entries(CDAgentsV71.POLICY).map(([key,p])=>({key,label:p.label,detail:p.detail})),history:copy(S.v71AgentDesk?.history||[]),talks:Object.entries(S.economy?.talks||{}).filter(([,t])=>t.kind==='renew').map(([key,t])=>({key,...copy(t)}))}};
 }
 function execute(command,payload){
  check(!!S,'Créez ou importez une carrière.');check(!S.live&&S.phase!=='ended','Décision indisponible pendant un match ou après la saison.');validate(S);
  const fields={staff_meeting:['plan'],training_plan:['plan'],medical_protocol:['id','protocol'],medical_return:['id','choice'],strategic_briefing:['plan','fixture'],agent_negotiate:['id','years','policy'],agent_confirm:['key','confirmed','wage','years','fee']};
  check(Object.hasOwn(fields,command),'Commande de support inconnue.');check(keys(payload,['context',...fields[command]])&&Object.keys(payload).length===fields[command].length+1&&keys(payload.context,['season','week','club'])&&Object.keys(payload.context).length===3,'Paramètres de support invalides.');
  check(sameContext(payload.context,context(S)),'Décision périmée : consultez la semaine actuelle.');
  const callbacks={save:()=>true};let ok=false;
  if(command==='staff_meeting'){check(typeof payload.plan==='string'&&Object.hasOwn(CDStaffMeetingV65.OPTIONS,payload.plan),'Arbitrage de staff invalide.');check(meetingAvailable(),'Réunion de staff déjà réalisée ou indisponible.');ok=CDStaffMeetingV65.perform(S,payload.plan,{...callbacks,message:managerMessage});if(ok)S.nativeSupport={version:1,meeting:{context:context(S),plan:payload.plan}};}
  if(command==='training_plan'){check(typeof payload.plan==='string'&&Object.hasOwn(CDTrainingPlansV67.PLANS,payload.plan),'Plan de travail invalide.');ok=CDTrainingPlansV67.apply(S,payload.plan,{...callbacks,outcome:physicalTrainingOutcome});}
  if(command==='medical_protocol'||command==='medical_return'){check(typeof payload.id==='string'&&roster(S).some(p=>p.id===payload.id),'Joueur absent de l’effectif.');check(command==='medical_protocol'?typeof payload.protocol==='string'&&Object.hasOwn(CDMedicalV68.PROTOCOLS,payload.protocol):['progressif','complet'].includes(payload.choice),'Choix médical invalide.');ok=command==='medical_protocol'?CDMedicalV68.choose(S,payload.id,payload.protocol,callbacks):CDMedicalV68.returnToPlay(S,payload.id,payload.choice,callbacks);}
  if(command==='strategic_briefing'){const d=matchDossier();check(d&&payload.fixture===v69Context(d)&&Object.hasOwn(V69_PLANS,payload.plan),'Préparation de rencontre périmée.');S.v69Briefing={version:1,context:payload.fixture,plan:payload.plan};ok=true;}
  if(command==='agent_negotiate'){check(typeof payload.id==='string'&&roster(S).some(p=>p.id===payload.id)&&int(payload.years,1,3)&&Object.hasOwn(CDAgentsV71.POLICY,payload.policy),'Mandat d’agent invalide.');ok=CDAgentsV71.perform(S,payload.id,payload.years,payload.policy,bridge());}
  if(command==='agent_confirm'){check(payload.confirmed===true&&typeof payload.key==='string','Confirmez la prime et l’engagement salarial.');const t=S.economy.talks[payload.key];check(t&&t.kind==='renew'&&payload.key===talkKey(t.id,'renew')&&['ready','counter'].includes(t.status)&&CDAgentsV71.eligible(S,roster(S).find(p=>p.id===t.id),t.years)&&payload.wage===t.acceptedSalary&&payload.years===t.years&&payload.fee===t.fee,'Accord contractuel périmé.');ok=confirmContract(payload.key);if(ok)CDAgentsV71.signed(S,payload.key);}
  check(ok,'Décision refusée : vérifiez la phase, le joueur, le budget ou les tentatives restantes.');validate(S);return {supportDecision:command};
 }
 function installHooks(){
  if(trainWeek.__nativeSupportMedical)return true;
  const prior=trainWeek,wrapped=function(...args){const state=S,trained=state?.trained,before=new Map((state?.clubs?.[state.club]?.players||[]).map(p=>[p.id,{injury:p.injury,protocol:CDMedicalV68.treatment(p)}]));const result=prior.apply(this,args);if(state&&S===state&&!trained&&state.trained)CDMedicalV68.completeTraining(state,before);return result;};wrapped.__nativeSupportMedical=true;trainWeek=wrapped;return true;
 }
 return {project,validate,execute,installHooks};
}
module.exports={files,commands,factory};
