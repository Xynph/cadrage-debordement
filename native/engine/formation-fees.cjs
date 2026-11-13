'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Indemnités de formation et contrats Espoirs à la sortie du centre (décision de Léo du
// 12/11/2026). Barème inventé, aucun barème public : quand un jeune quitte le centre à 22 ans
// et signe son premier contrat pro dans un autre club, ce club paie le club formateur.
// Un jeune sous contrat Espoir à sa sortie coûte deux fois plus cher.
function factory(){
 const POLICY='formation-fees-v1',BUCKETS=32,WINDOW=2,HISTORY=60,PER_SEASON=30000,SEASONS=3;
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('Indemnités de formation : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const hash=x=>{let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0;};
 const bucketOf=pid=>'b'+(hash(pid)%BUCKETS);
 const active=s=>s?.formationFees?.version===1;
 function ensure(s){
  if(!s)return false;
  if(!active(s))s.formationFees={version:1,policy:POLICY,graduates:{},payments:[]};
  return true;
 }
 const record=(s,pid)=>s.formationFees.graduates[bucketOf(pid)]?.[pid]||null;
 function setRecord(s,pid,r){const b=bucketOf(pid);(s.formationFees.graduates[b]||(s.formationFees.graduates[b]={}))[pid]=r;}
 function dropRecord(s,pid){const b=bucketOf(pid),bucket=s.formationFees.graduates[b];if(!bucket)return;delete bucket[pid];if(!Object.keys(bucket).length)delete s.formationFees.graduates[b];}
 const allRecords=s=>Object.values(s.formationFees.graduates).flatMap(b=>Object.entries(b));
 // Contrat Espoir en cours : contrats du centre du club joué ; l'ordinateur protège ses meilleurs espoirs.
 function contracted(s,p,clubId){
  if(clubId===s.club)return (s.v78to81?.contracts||[]).some(x=>x.id===p.id&&x.expires>=s.season-1);
  return Math.round(p.dev?.potential||p.rating||0)>=85;
 }
 function amountFor(r){
  const [,,isContracted,potential]=r;
  const level=1+Math.max(0,potential-70)/15;
  return Math.round(PER_SEASON*SEASONS*level*(isContracted?2:1)/5000)*5000;
 }
 // Sortie du centre : on retient le club formateur pour deux saisons.
 function graduate(s,p,clubId){
  if(!s||!p||!id(p.id)||!int(clubId,0,s.clubs.length-1))return false;
  ensure(s);
  for(const [pid,r] of allRecords(s))if(r[1]<s.season-WINDOW)dropRecord(s,pid);
  setRecord(s,p.id,[clubId,s.season,contracted(s,p,clubId)?1:0,Math.max(0,Math.min(99,Math.round(p.dev?.potential||p.rating||0)))]);
  return true;
 }
 // Indemnité due si un autre club que le formateur signe le jeune dans la fenêtre.
 function due(s,p,buyerId){
  if(!active(s)||!p)return 0;
  const r=record(s,p.id);if(!r||r[0]===buyerId||r[1]<s.season-WINDOW)return 0;
  return amountFor(r);
 }
 function settle(s,p,buyerId,paidByBuyer){
  if(!active(s)||!p)return 0;
  const r=record(s,p.id);if(!r)return 0;
  dropRecord(s,p.id);
  if(r[0]===buyerId||r[1]<s.season-WINDOW)return 0;
  const amount=amountFor(r),seller=s.clubs[r[0]],buyer=s.clubs[buyerId];
  if(!seller||!buyer)return 0;
  if(!paidByBuyer&&Number.isFinite(buyer.cash))buyer.cash-=amount;
  if(Number.isFinite(seller.cash))seller.cash+=amount;
  s.formationFees.payments=s.formationFees.payments.concat({season:s.season,playerId:p.id,from:buyerId,to:r[0],amount,contracted:r[2]}).slice(-HISTORY);
  if(typeof news==='function'&&(buyerId===s.club||r[0]===s.club))
   news(r[0]===s.club?`Indemnité de formation : ${buyer.name} verse ${amount.toLocaleString('fr-FR')} € pour ${p.name}, formé au club.`:`Indemnité de formation : ${amount.toLocaleString('fr-FR')} € versés à ${seller.name}, club formateur de ${p.name}.`);
  return amount;
 }
 function validate(s){
  if(!s||s.formationFees===undefined)return true;
  const st=s.formationFees;
  check(shape(st,['version','policy','graduates','payments'])&&st.version===1&&st.policy===POLICY,'état invalide');
  check(object(st.graduates)&&Object.keys(st.graduates).length<=BUCKETS&&Object.entries(st.graduates).every(([b,bucket])=>/^b\d{1,2}$/.test(b)&&object(bucket)&&Object.keys(bucket).length>0&&Object.keys(bucket).length<=2000&&Object.entries(bucket).every(([k,r])=>id(k)&&bucketOf(k)===b&&Array.isArray(r)&&r.length===4&&int(r[0],0,s.clubs.length-1)&&int(r[1],1,s.season)&&int(r[2],0,1)&&int(r[3],0,99))),'sorties de centre invalides');
  check(Array.isArray(st.payments)&&st.payments.length<=HISTORY&&st.payments.every(x=>shape(x,['season','playerId','from','to','amount','contracted'])&&int(x.season,1,s.season)&&id(x.playerId)&&int(x.from,0,s.clubs.length-1)&&int(x.to,0,s.clubs.length-1)&&x.from!==x.to&&int(x.amount,0,2000000)&&int(x.contracted,0,1)),'indemnités versées invalides');
  return true;
 }
 function execute(){throw Error('Indemnités de formation : aucune commande.');}
 function project(){
  const s=state();if(!s||!active(s))return {available:false};
  return {available:true,perSeason:PER_SEASON,seasons:SEASONS,window:WINDOW,
   received:s.formationFees.payments.filter(x=>x.to===s.club).slice(-10),paid:s.formationFees.payments.filter(x=>x.from===s.club).slice(-10)};
 }
 function installHooks(){
  if(typeof aiRosterGraduateAcademyPlayer==='function'&&!aiRosterGraduateAcademyPlayer.__formationFees){
   const original=aiRosterGraduateAcademyPlayer,wrapped=function(p,clubId){const result=original.apply(this,arguments);const s=state();if(result&&s)graduate(s,p,clubId);return result;};
   Object.assign(wrapped,original);wrapped.__formationFees=true;aiRosterGraduateAcademyPlayer=wrapped;
  }
  if(typeof contractFee==='function'&&!contractFee.__formationFees){
   // Le club joué voit l'indemnité incluse dans la prime avant de signer.
   const original=contractFee,wrapped=function(p,kind){const fee=original.apply(this,arguments);const s=state();return kind==='recruit'&&s&&Number.isFinite(fee)?fee+due(s,p,s.club):fee;};
   Object.assign(wrapped,original);wrapped.__formationFees=true;contractFee=wrapped;
  }
  if(typeof logContractSignature==='function'&&!logContractSignature.__formationFees){
   const original=logContractSignature,wrapped=function(p,t){const result=original.apply(this,arguments);const s=state();if(s&&t?.kind==='recruit')settle(s,p,s.club,true);return result;};
   Object.assign(wrapped,original);wrapped.__formationFees=true;logContractSignature=wrapped;
  }
  if(typeof aiRosterEvent==='function'&&!aiRosterEvent.__formationFees){
   const original=aiRosterEvent,wrapped=function(clubId,kind,p){const result=original.apply(this,arguments);const s=state();if(s&&kind==='recruit'&&clubId!==s.club)settle(s,p,clubId,false);return result;};
   Object.assign(wrapped,original);wrapped.__formationFees=true;aiRosterEvent=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,ensure,graduate,due,settle,amountFor,record};
}
module.exports={files,commands,factory};
