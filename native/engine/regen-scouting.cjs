'use strict';
// A view of the existing adult supply, reports, watch list and contracts.
// No player generation, observation engine, finance tariff or save field here.
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x));
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).every(k=>keys.includes(k));
 const int=(x,min,max)=>Number.isInteger(x)&&x>=min&&x<=max;
 const check=(ok,message)=>{if(!ok)throw Error('Détection des regens : '+message+'.');};
 const week=s=>s.worldMode?.week??s.franceMode?.week??(s.phase==='league'?s.round:({barrage:26,semi:27,final:28,ended:29}[s.phase]??s.round));
 const context=s=>({season:s.season,week:week(s),club:s.club});
 const eligible=p=>p.age>=18&&p.population?.version===1&&['academy','small-club'].includes(p.population.origin);
 function filtersOf(value){
  const f=value===undefined?{}:value;
  check(shape(f,['family','minAge','maxAge','needsOnly','watchedOnly'])&&(f.family===undefined||int(f.family,0,8))&&(f.minAge===undefined||int(f.minAge,18,60))&&(f.maxAge===undefined||int(f.maxAge,18,60))&&(f.minAge??18)<=(f.maxAge??60)&&['needsOnly','watchedOnly'].every(k=>f[k]===undefined||typeof f[k]==='boolean'),'filtre invalide');
  return f;
 }
 function origin(s,p){
  const pop=p.population,academy=pop.origin==='academy',c=academy?s.clubs.find(c=>c.id===pop.clubId):null;
  return {kind:pop.origin,clubId:academy?pop.clubId:null,season:pop.season,availableSince:pop.availableSince,abstract:!academy,label:academy?'Diplômé du centre de '+(c?.name||'club non identifié'):'Bassin des petits clubs (simulation abstraite)'};
 }
 function project(filters){
  const f=filtersOf(filters),s=typeof S==='undefined'?null:S;
  const base={available:!!s?.manager,context:s?context(s):null,locked:!s||!!s.live||s.phase==='ended',candidates:[],shortlist:[],needs:[],missions:[],reportCount:0,shortlistLimit:30,missionCost:5000,missionCommand:'scout_mission',recruitCommand:'recruit',notice:'Agents libres majeurs issus des centres de formation ou des petits clubs. Suivre un joueur ne le réserve pas. Une mission coûte 5 000 € et dure deux journées.'};
  if(!base.available)return base;
  const own=s.clubs[s.club],watched=new Set(s.manager.watch),pool=managerPool().filter(eligible);
  const needs=recruitmentNeeds(copy(own)).map(n=>({slot:n.slot,family:n.family,pos:n.pos,score:n.score,need:n.need,reasons:n.reasons.slice()}));
  const slots=needs.filter(n=>n.need),weeks=wageForecastWeeks(s),remaining=s.phase==='ended'?weeks:Math.max(0,weeks-week(s));
  const rows=pool.map(source=>{
   // Existing quote/evidence helpers receive a copy, never a live player.
   const p=copy(source),e=recruitmentEvidence(p),fee=contractFee(p,'recruit'),salary=askingWage(p,'recruit'),maxYears=Math.min(3,careerContractYears(p));
   const reason=s.live?'Match en cours':s.phase==='ended'?'Saison terminée':!s.market.some(q=>q.id===p.id)?'En attente de l’actualisation du marché':professionalPlaces(own)<=0?'Effectif complet':own.cash<fee?'Trésorerie insuffisante':maxYears<1?'Retraite prévue':'';
   return {id:p.id,playerId:p.id,name:p.name,identity:{id:p.id,name:p.name},pos:p.pos,family:p.fam,age:p.age,...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),origin:origin(s,p),watched:watched.has(p.id),matchingSlots:slots.filter(n=>slotEligible(p,n.slot)).map(n=>n.slot),evidence:{seen:e.seen,stale:e.stale,noteMin:e.noteMin,noteMax:e.noteMax,potentialMin:e.potentialMin,potentialMax:e.potentialMax,label:e.label,season:e.report?.season??null,week:e.report?.week??null},fee,salary,minYears:1,maxYears,terms:Array.from({length:Math.max(0,maxYears)},(_,i)=>{const years=i+1,payments=remaining+i*weeks;return {years,payments,salary,fee,knownCommitment:fee+salary*payments};}),available:!reason,reason};
  }).sort((a,b)=>a.age-b.age||a.id.localeCompare(b.id));
  const byId=new Map(rows.map(p=>[p.id,p]));
  base.shortlist=s.manager.watch.map(id=>byId.get(id)||{id,playerId:id,watched:true,available:false,reason:'Profil absent du vivier de regens adultes ; suivi partagé conservé'});
  base.candidates=rows.filter(p=>(f.family===undefined||p.family===f.family)&&p.age>=(f.minAge??18)&&p.age<=(f.maxAge??60)&&(!f.needsOnly||p.matchingSlots.length>0)&&(!f.watchedOnly||p.watched));
  base.needs=needs;base.missions=s.manager.missions.map(m=>({id:m.id,family:m.family,maxAge:m.maxAge,budget:m.budget,maxWage:m.maxWage,remaining:m.remaining,status:m.status,week:m.week}));base.reportCount=s.manager.reports.length;
  return base;
 }
 function execute(command,p){
  check(command==='regen_shortlist','commande inconnue');
  check(typeof S!=='undefined'&&S?.manager&&!S.live&&S.phase!=='ended','suivi indisponible pendant un match ou après la saison');
  const c=context(S);
  check(shape(p,['playerId','watched','context'])&&typeof p.playerId==='string'&&p.playerId.length>0&&p.playerId.length<=120&&typeof p.watched==='boolean'&&shape(p.context,['season','week','club'])&&Object.keys(p.context).length===3&&Object.keys(c).every(k=>p.context[k]===c[k]),'contexte périmé ou données invalides');
  const before=S.manager.watch.includes(p.playerId);
  if(p.watched){check(managerPool().some(q=>q.id===p.playerId&&eligible(q)),'candidat majeur indisponible');check(before||S.manager.watch.length<30,'shortlist complète (30 joueurs partagés)');}
  if(before!==p.watched){watchPlayer(p.playerId);check(S.manager.watch.includes(p.playerId)===p.watched,'modification du suivi refusée');}
  return {regenScoutingDecision:{playerId:p.playerId,watched:p.watched,changed:before!==p.watched}};
 }
 return {project,execute,validate:()=>true,installHooks:()=>true};
}
module.exports={files:[],commands:['regen_shortlist'],factory};
