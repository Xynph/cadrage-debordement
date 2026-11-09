'use strict';
// Experimental controllers. Only worker-visible models enter this module.
const fs=require('node:fs'),crypto=require('node:crypto');
const version='progression-policies-v1';
const sourceHash=crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex');
const phases=Object.freeze(['before-week','before-match','after-season','transition']);
const commands=Object.freeze(['auto_lineup','promote_cover','extend_contract']);
const profiles=Object.freeze([
 Object.freeze({id:'minimal',label:'Gestion minimale jouable',version,maxActionsPerPhase:16,renewalCandidatesPerSeason:0}),
 Object.freeze({id:'attentive',label:'Renouvellement sélectif avec réserve',version,maxActionsPerPhase:16,
  renewalCandidatesPerSeason:6,maxAge:30,targetYears:2,minimumCashReserve:500000,payrollReserveWeeks:8,
  priority:'note descending, potential descending, age ascending, opaque ID ascending',counteroffersPerPlayer:1})
]);
const finite=Number.isFinite;
const lexical=(a,b)=>a<b?-1:a>b?1:0;
function createPolicy(id){
 const profile=profiles.find(p=>p.id===id);if(!profile)throw new RangeError('Unknown progression policy: '+id);
 const issued=new Set(),candidates=new Map(),events=[];
 let waiting=null,counter=null,blocked=false;
 const key=m=>m.meta.season+':'+m.meta.week;
 function funded(model,p,salary,fee){
  const wage=model.finance?.wage??model.squad.reduce((n,q)=>n+q.salary,0);
  const afterPayroll=wage-p.salary+salary,reserve=Math.max(profile.minimumCashReserve,profile.payrollReserveWeeks*afterPayroll);
  return finite(model.club.cash)&&finite(afterPayroll)&&finite(fee)&&fee>=0&&model.club.cash-fee>=reserve;
 }
 function action(model,phase,command,payload,reason,evidence={}){
  const result={command,payload,reason,evidence:{season:model.meta.season,week:model.meta.week,phase,...evidence}};
  waiting=result;return result;
 }
 function renew(model,phase,p,salary,years,fee,kind){
  return action(model,phase,'extend_contract',{playerId:p.id,salary,years,confirmed:true},
   kind==='counter'?'Accepter la contre-proposition publique sous la réserve fixée.':'Conserver un contrat expirant selon les critères visibles fixés.',
   {kind,playerId:p.id,note:p.note,potential:p.potential,age:p.age,currentSalary:p.salary,offeredSalary:salary,fee,years,
    cash:model.club.cash,payroll:model.finance.wage,reserve:Math.max(profile.minimumCashReserve,profile.payrollReserveWeeks*(model.finance.wage-p.salary+salary))});
 }
 function nextAction(model,phase){
  if(!phases.includes(phase))throw new RangeError('Unknown policy phase: '+phase);
  if(blocked||waiting||!model?.meta?.hasCareer||!model.club||model.live)return null;
  if(phase==='before-match'&&model.next){
   const auto='auto:'+key(model);
   if(!issued.has(auto)){issued.add(auto);return action(model,phase,'auto_lineup',{},'Composer le groupe par le sélecteur public, commun aux deux politiques.');}
   const cover='cover:'+key(model);
   if(!model.selection.valid&&!issued.has(cover)){issued.add(cover);return action(model,phase,'promote_cover',{confirmed:true},'Compléter les places manquantes via la couverture publique.',{errors:model.selection.errors.slice()});}
   if(!model.selection.valid)return null;
  }
  if(id!=='attentive'||phase==='transition')return null;
  if(counter){
   const pending=counter;counter=null;
   const p=model.squad.find(q=>q.id===pending.playerId);
   if(p&&key(model)===pending.context&&p.renewal.available&&funded(model,p,pending.salary,pending.fee))
    return renew(model,phase,p,pending.salary,pending.years,pending.fee,'counter');
   events.push({outcome:'counter-not-applied',playerId:pending.playerId,reason:'Contexte changé ou réserve insuffisante.',season:model.meta.season,week:model.meta.week});
  }
  const season=model.meta.season,attempted=candidates.get(season)??0;
  if(attempted>=profile.renewalCandidatesPerSeason)return null;
  const pool=model.squad.filter(p=>Number.isInteger(p.age)&&p.age<=profile.maxAge&&finite(p.note)&&finite(p.potential)&&
   Number.isInteger(p.contractEnd)&&p.contractEnd<=season&&p.renewal?.available&&!issued.has('renew:'+season+':'+p.id)&&
   finite(p.renewal.salary)&&p.renewal.salary>=1000&&p.renewal.salary<=100000&&Number.isInteger(p.renewal.minYears)&&
   Number.isInteger(p.renewal.maxYears)&&p.renewal.minYears<=p.renewal.maxYears)
   .sort((a,b)=>b.note-a.note||b.potential-a.potential||a.age-b.age||lexical(a.id,b.id));
  for(const p of pool){
   const years=Math.max(p.renewal.minYears,Math.min(profile.targetYears,p.renewal.maxYears));
   if(years<1||years>3||!funded(model,p,p.renewal.salary,p.renewal.fee))continue;
   issued.add('renew:'+season+':'+p.id);candidates.set(season,attempted+1);
   return renew(model,phase,p,p.renewal.salary,years,p.renewal.fee,'offer');
  }
  return null;
 }
 function observe(request,reply){
  if(!waiting||JSON.stringify(waiting)!==JSON.stringify(request))throw new Error('Observe must match the outstanding action');
  waiting=null;
  const negotiation=reply?.model?.meta?.negotiation,status=reply?.ok?(negotiation?.status??'applied'):'rejected';
  const event={...request,outcome:status,ok:reply?.ok===true,error:reply?.error??null,
   returnedSalary:negotiation?.salary??null,returnedFee:negotiation?.fee??null,
   cashAfter:reply?.model?.club?.cash??null,actualFee:status==='signed'?negotiation.fee:0};
  events.push(event);
  if(!reply?.ok){blocked=true;return {critical:true,expectedRefusal:false,outcome:status};}
  if(request.command==='extend_contract'&&status==='counter'&&request.evidence.kind==='offer'){
   const q=negotiation;
   if(Number.isInteger(q.salary)&&q.salary>=1000&&q.salary<=100000&&finite(q.fee)&&q.fee>=0)
    counter={playerId:request.payload.playerId,salary:q.salary,years:request.payload.years,fee:q.fee,context:request.evidence.season+':'+request.evidence.week};
  }
  return {critical:false,expectedRefusal:status==='counter',outcome:status};
 }
 return {profile,sourceHash,nextAction,observe,
  summary:()=>({policy:id,version,sourceHash,blocked,events:JSON.parse(JSON.stringify(events)),
   candidatesBySeason:Object.fromEntries(candidates),signed:events.filter(e=>e.outcome==='signed').length,
   actualFees:events.reduce((n,e)=>n+(e.actualFee||0),0)})};
}
module.exports={version,sourceHash,profiles,phases,commands,createPolicy};
