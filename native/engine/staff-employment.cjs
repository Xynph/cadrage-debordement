'use strict';
const files=[],commands=['staff_employment_enable','staff_employment_adopt','staff_employment_hire','staff_employment_renew','staff_employment_release','staff_employment_retire'];
function factory(){
 const POLICY='voluntary-role-wages-v1',RATES={coach:500,assistant:350,formation:300,scout:250,analyst:250,medical:400,fitness:300,support:200},RESERVE=50000;
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>!!x&&typeof x==='object'&&!Array.isArray(x),shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(v,a,b)=>Number.isSafeInteger(v)&&v>=a&&v<=b,id=v=>typeof v==='string'&&/^[A-Za-z0-9:._-]{1,240}$/.test(v);
 const check=(ok,msg)=>{if(!ok)throw Error('Emploi rémunéré du staff : '+msg+'.');};
 const state=()=>typeof S==='undefined'?null:S,week=s=>s.worldMode?.week??s.franceMode?.week??(s.phase==='league'?s.round:({barrage:26,semi:27,final:28,ended:29}[s.phase]??s.round)),context=s=>({season:s.season,week:week(s),club:s.club});
 const people=s=>(s?.staffCareer?.people||[]).flat(),enabled=(s,club=s.club)=>s.staffEmployment?.clubs.some(c=>c.clubId===club)===true;
 const validContract=(s,c)=>c.endSeason>=s.season&&people(s).some(p=>p.id===c.staffId&&p.clubId===c.clubId&&p.contractEnd>=s.season);
 const paid=(s,c)=>s.staffEmployment?.lastPayroll?.season===s.season&&s.staffEmployment.lastPayroll.week===week(s);
 const seasonWeeks=s=>typeof wageForecastWeeks==='function'?wageForecastWeeks(s):29;
 const remaining=(s,c)=>{const person=c.staffId?people(s).find(p=>p.id===c.staffId):null;const end=person&&Number.isSafeInteger(person.retireAge)&&Number.isSafeInteger(person.age)?Math.min(c.endSeason,s.season+Math.max(0,person.retireAge-person.age-1)):c.endSeason;return Math.max(0,seasonWeeks(s)-week(s)-(paid(s,c)?1:0))+Math.max(0,end-s.season)*seasonWeeks(s);};
 const quote=(s,p)=>{const c=s.staffEmployment?.contracts.find(c=>c.staffId===p.id&&c.clubId===s.club&&validContract(s,c));return {...copy(p),salary:RATES[p.role],employed:!!c,paidSalary:c?.salary??0,remainingPayments:c?remaining(s,c):0,adoptionCommitment:p.clubId===s.club?RATES[p.role]*remaining(s,{staffId:p.id,clubId:s.club,endSeason:p.contractEnd}):0,severance:c?Math.min(2,remaining(s,c))*c.salary:0};};
 function validate(s){
  if(!s||s.staffEmployment===undefined)return true;
  const st=s.staffEmployment;check(s.staffCareer?.version===1&&shape(st,['version','policy','clubs','contracts','payments','lastPayroll'])&&st.version===1&&st.policy===POLICY,'version ou cycle staff requis');
  check(Array.isArray(st.clubs)&&st.clubs.length<=s.clubs.length&&new Set(st.clubs.map(c=>c.clubId)).size===st.clubs.length,'clubs invalides');
  for(const c of st.clubs)check(shape(c,['clubId','season','week'])&&int(c.clubId,0,s.clubs.length-1)&&int(c.season,1,s.season)&&int(c.week,0,100)&&(c.season<s.season||c.week<=week(s)),'activation invalide');
  check(Array.isArray(st.contracts)&&st.contracts.length<=512&&new Set(st.contracts.map(c=>c.staffId)).size===st.contracts.length,'contrats excessifs ou en double');
  for(const c of st.contracts){check(shape(c,['staffId','clubId','role','salary','startSeason','startWeek','endSeason'])&&id(c.staffId)&&enabled(s,c.clubId)&&Object.hasOwn(RATES,c.role)&&c.salary===RATES[c.role]&&int(c.startSeason,1,s.season)&&int(c.startWeek,0,100)&&(c.startSeason<s.season||c.startWeek<=week(s))&&int(c.endSeason,c.startSeason,Math.min(9999,s.season+3)),'engagement invalide');const activation=st.clubs.find(x=>x.clubId===c.clubId);check(c.startSeason>activation.season||c.startSeason===activation.season&&c.startWeek>=activation.week,'engagement avant activation');const person=people(s).find(p=>p.id===c.staffId);if(person&&person.clubId===c.clubId)check(person.role===c.role&&c.endSeason<=person.contractEnd,'rôle ou échéance incompatibles avec le contrat de carrière');}
  check(Array.isArray(st.payments)&&st.payments.length<=256,'reçus excessifs');const seen=new Set();let previous=null;
  for(const p of st.payments){const key=p.season+':'+p.week+':'+p.clubId;check(shape(p,['season','week','clubId','amount'])&&int(p.season,1,s.season)&&int(p.week,0,100)&&(p.season<s.season||p.week<=week(s))&&enabled(s,p.clubId)&&int(p.amount,25,256000)&&p.amount%25===0&&!seen.has(key),'reçu invalide');seen.add(key);check(!previous||p.season>previous.season||p.season===previous.season&&p.week>=previous.week,'reçus désordonnés');previous=p;}
  check(st.lastPayroll===null||shape(st.lastPayroll,['season','week'])&&int(st.lastPayroll.season,1,s.season)&&int(st.lastPayroll.week,0,100)&&(st.lastPayroll.season<s.season||st.lastPayroll.week<=week(s)),'horloge invalide');
  if(previous)check(st.lastPayroll&&(st.lastPayroll.season>previous.season||st.lastPayroll.season===previous.season&&st.lastPayroll.week>=previous.week),'paie sans horloge');return true;
 }
 let delegating=false;
 function withCareer(command,p){delegating=true;try{return CDStaffCareer.execute(command,p);}finally{delegating=false;}}
 function execute(command,p){
  const s=state(),type=command?.replace('staff_employment_','');let actionCost=0;check(s&&['enable','adopt','hire','renew','release','retire'].includes(type),'commande inconnue');
  const fields=type==='enable'?[]:type==='hire'?['candidateId','years','salary']:type==='renew'?['staffId','years','salary']:type==='adopt'?['staffId','salary']:['staffId','severance'];
  check(shape(p,['confirmed','context',...fields])&&p.confirmed===true&&shape(p.context,['season','week','club']),'paramètres invalides');check(Object.keys(context(s)).every(k=>p.context[k]===context(s)[k]),'contexte périmé');check(!s.live&&s.phase==='league','gestion en saison régulière hors match');check(s.staffCareer?.version===1,'activez les carrières du staff');validate(s);
  if(type==='enable'){
   check(!enabled(s),'club déjà activé');if(!s.staffEmployment)s.staffEmployment={version:1,policy:POLICY,clubs:[],contracts:[],payments:[],lastPayroll:null};s.staffEmployment.clubs.push({clubId:s.club,season:s.season,week:week(s)});
  }else{
   check(enabled(s),'activation du club requise');const st=s.staffEmployment,staffId=p.staffId??p.candidateId;check(id(staffId),'identifiant invalide');const person=people(s).find(q=>q.id===staffId);check(person,'profil indisponible');
   const current=st.contracts.find(c=>c.staffId===staffId&&c.clubId===s.club&&validContract(s,c));
   if(type==='release'||type==='retire'){
    check(person.clubId===s.club&&current,'contrat rémunéré absent');const cost=Math.min(2,remaining(s,current))*current.salary;check(p.severance===cost,'indemnité du devis modifiée');
    withCareer(type==='retire'?'staff_retire':'staff_release',{context:p.context,confirmed:true,staffId});if(cost)ledgerEntry('Rupture staff : '+person.name,-cost);actionCost=cost;st.contracts=st.contracts.filter(c=>c.staffId!==staffId);
   }else{
    const salary=RATES[person.role];check(p.salary===salary,'salaire du devis modifié');
    check(type==='hire'?person.clubId===null:person.clubId===s.club,'appartenance incompatible');check(type!=='adopt'||!current,'contrat déjà adopté');
    const end=type==='adopt'?person.contractEnd:s.season+p.years-1;check(int(end,s.season,s.season+2),'échéance invalide');
    const c={staffId,clubId:s.club,role:person.role,salary,startSeason:s.season,startWeek:week(s),endSeason:end};
    const commitments=st.contracts.filter(c=>validContract(s,c)&&c.clubId===s.club&&c.staffId!==staffId).concat(c);
    const provision=commitments.reduce((sum,contract)=>sum+contract.salary*Math.min(8,remaining(s,contract)),0);check(s.clubs[s.club].cash>=RESERVE+provision,'réserve de 50 000 € et provision de huit paies requises');
    check(st.contracts.filter(c=>validContract(s,c)&&c.staffId!==staffId).length<512,'capacité contractuelle atteinte');
    if(type==='hire')withCareer('staff_hire',{context:p.context,confirmed:true,candidateId:staffId,years:p.years});
    else if(type==='renew')withCareer('staff_renew',{context:p.context,confirmed:true,staffId,years:p.years});
    st.contracts=st.contracts.filter(q=>q.staffId!==staffId&&validContract(s,q));st.contracts.push(c);
   }
  }
  validate(s);return {staffEmploymentAction:{command,cost:actionCost,policy:POLICY}};
 }
 function payroll(s){
  if(!s?.staffEmployment)return false;const st=s.staffEmployment,w=week(s),last=st.lastPayroll;
  if(last&&(last.season>s.season||last.season===s.season&&last.week>=w))return false;
  const totals=new Map();for(const c of st.contracts)if(validContract(s,c))totals.set(c.clubId,(totals.get(c.clubId)||0)+c.salary);
  for(const [clubId,amount]of totals){if(clubId===s.club)ledgerEntry('Salaires du staff · semaine '+(w+1),-amount);else s.clubs[clubId].cash-=amount;st.payments.push({season:s.season,week:w,clubId,amount});}
  st.payments=st.payments.slice(-256);st.lastPayroll={season:s.season,week:w};return true;
 }
 function project(){
  const s=state();if(!s)return {available:false};const active=enabled(s),contracts=s.staffEmployment?.contracts.filter(c=>c.clubId===s.club&&validContract(s,c))||[],weeklyWages=contracts.reduce((n,c)=>n+c.salary,0),knownCommitment=contracts.reduce((n,c)=>n+c.salary*remaining(s,c),0);
  return {available:s.staffCareer?.version===1,enabled:active,canEnable:!active&&!s.live&&s.phase==='league',locked:!!s.live||s.phase!=='league',context:context(s),policy:POLICY,reserve:RESERVE,weeklyWages,knownCommitment,remainingPayments:contracts.reduce((n,c)=>n+remaining(s,c),0),weeksPerSeason:seasonWeeks(s),remainingCurrentSeason:Math.max(0,seasonWeeks(s)-week(s)-(paid(s,null)?1:0)),cash:s.clubs[s.club].cash,forecastAfterKnownStaff:s.clubs[s.club].cash-knownCommitment,
   own:people(s).filter(p=>p.clubId===s.club).map(p=>quote(s,p)),candidates:people(s).filter(p=>p.clubId===null).map(p=>quote(s,p)),notice:'Barème de jeu fictif, distinct des salaires réels. Activation seule sans coût ; contrats historiques gratuits jusqu’à adoption nominative. Chaque contrat signé est payé par son club, y compris après votre départ. Rupture plafonnée à deux paies, possible même en trésorerie négative pour arrêter la charge. Cette prévision soustrait uniquement le staff connu, hors autres recettes et dépenses.'};
 }
 function installHooks(){
  const domain=typeof nativeSystems==='undefined'?null:nativeSystems.domain('staffCareer');
  if(domain&&!domain.execute.__employment){const prior=domain.execute;domain.execute=function(command,p){const s=state();if(!delegating&&s&&enabled(s)&&(['staff_hire','staff_renew'].includes(command)||['staff_release','staff_retire'].includes(command)&&s.staffEmployment.contracts.some(c=>c.staffId===p?.staffId&&c.clubId===s.club&&validContract(s,c))))check(false,'utilisez le contrat rémunéré et son devis');return prior.apply(this,arguments);};domain.execute.__employment=true;}
  if(typeof financeWeek==='function'&&!financeWeek.__employment){const prior=financeWeek;const wrapped=function(){const result=prior.apply(this,arguments);payroll(state());return result;};Object.assign(wrapped,prior);wrapped.__employment=true;financeWeek=wrapped;}return true;
 }
 return {execute,project,validate,installHooks,payroll};
}
module.exports={files,commands,factory};
