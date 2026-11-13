'use strict';
const files=Object.freeze([]),commands=Object.freeze(['manager_plan_lineup','manager_plan_scenario','manager_plan_goal']);
// Intentions only. No call to a lineup setter, transfer, growth or RNG function.
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x));
 const obj=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>obj(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_-]{1,240}$/.test(x)&&!['__proto__','constructor','prototype'].includes(x);
 const check=(x,m)=>{if(!x)throw Error('Préparation du manager : '+m+'.');};
 const week=()=>S.worldMode?.week??S.franceMode?.week??S.round;
 const context=()=>({season:S.season,week:week(),club:S.club});
 const current=()=>S.managerPlanning?.season===S.season&&S.managerPlanning.club===S.club?S.managerPlanning:null;
 function validate(s){
  if(!s||s.managerPlanning===undefined)return true;
  const p=s.managerPlanning;
  check(shape(p,['version','season','club','lineups','scenario','goal'])&&p.version===1&&int(p.season,1,s.season)&&int(p.club,0,s.clubs.length-1),'en-tête invalide');
  check(Array.isArray(p.lineups)&&p.lineups.length<=3,'trois compositions au maximum');
  const fixtures=new Set();for(const l of p.lineups){check(shape(l,['fixtureId','slots'])&&id(l.fixtureId)&&!fixtures.has(l.fixtureId)&&Array.isArray(l.slots)&&l.slots.length===23&&l.slots.every(p=>p===null||id(p)),'composition invalide');const ids=l.slots.filter(p=>p!==null);check(new Set(ids).size===ids.length,'joueur répété');fixtures.add(l.fixtureId);
   for(let slot=0;slot<23;slot++){const player=s.clubs[p.club].players.find(x=>x.id===l.slots[slot]);if(player)check(slot<15?slotEligible(player,slot):benchEligible(player,slot-15),'composition importée : poste non qualifié');}
  }
  check(Array.isArray(p.scenario)&&p.scenario.length<=8,'huit opérations au maximum');
  const people=new Set();for(const o of p.scenario){check(shape(o,['kind','playerId','years','salary','fee'])&&['renew','recruit','promote'].includes(o.kind)&&id(o.playerId)&&!people.has(o.playerId)&&int(o.years,1,3)&&int(o.salary,0,1000000)&&int(o.fee,0,1000000000),'hypothèse contractuelle invalide');people.add(o.playerId);}
  check(p.goal===null||shape(p.goal,['metric','target','startedAt'])&&['lineouts','scrums','penalties'].includes(p.goal.metric)&&Number.isFinite(p.goal.target)&&p.goal.target>=0&&p.goal.target<=100&&int(p.goal.startedAt,0,10000000),'objectif invalide');return true;
 }
 function project(){
  if(typeof S==='undefined'||!S)return {context:null,settings:null,slots:[],goalRows:[]};
  const p=current(),players=S.clubs[S.club].players;
  const goalRows=p?.goal?(S.history||[]).slice(p.goal.startedAt).filter(r=>r.pair?.includes(S.club)&&(r.season===undefined||r.season===S.season)).slice(-40).map(r=>{
   const side=r.pair.indexOf(S.club),opponent=r.pair[1-side];
   return {fixtureId:r.fixtureId??null,week:r.week??r.round??null,phase:r.phase??null,opponent,opponentName:S.clubs[opponent]?.name??'Adversaire',home:side===0,neutral:r.neutral??null,score:r.score??null,stats:copy(r.stats?.[side]||{}),events:(r.events||[]).filter(e=>['lineout','scrum','penalty'].includes(e.scene?.kind??e.kind)).slice(-30).map(e=>({minute:e.minute??null,kind:e.scene?.kind??e.kind,text:e.text??''}))};
  }):[];
  const loans=[S.v78to81,...Object.values(S.nativeAcademy?.offices||{}).map(o=>o.v78to81)].flatMap(o=>o?.loans||[]).filter(l=>l.season===S.season&&(l.from===S.club||l.to===S.club)).filter((l,i,a)=>a.findIndex(x=>x.id===l.id)===i).map(l=>{
   const player=S.clubs[l.to]?.players.find(p=>p.id===l.id);
   return {id:l.id,from:l.from,to:l.to,returnSeason:S.season+1,player:player?{id:player.id,name:player.name,pos:player.pos,age:player.age,salary:player.salary,contractEnd:player.contractEnd??null}:null};
  });
  return {context:context(),settings:p?copy(p):null,slots:players.map(p=>({id:p.id,eligible:Array.from({length:23},(_,slot)=>slot).filter(slot=>slot<15?slotEligible(p,slot):benchEligible(p,slot-15))})),goalRows,loans};
 }
 function execute(command,payload){
  check(typeof S!=='undefined'&&!!S,'aucune carrière');
  const fields={manager_plan_lineup:['context','fixtureId','slot','playerId'],manager_plan_scenario:['context','operations'],manager_plan_goal:['context','metric','target']}[command];
  check(fields&&shape(payload,fields)&&shape(payload.context,['season','week','club'])&&Object.entries(context()).every(([k,v])=>payload.context[k]===v),'contexte périmé ou champs invalides');
  check(!S.live&&S.phase!=='ended','planning indisponible pendant le match ou après la saison');
  const p=current()?copy(current()):{version:1,season:S.season,club:S.club,lineups:[],scenario:[],goal:null};
  if(command==='manager_plan_lineup'){
   check(id(payload.fixtureId)&&(int(payload.slot,0,22)||payload.slot===null&&payload.playerId===null)&&(payload.playerId===null||id(payload.playerId)),'case invalide');
   if(payload.playerId!==null){const player=S.clubs[S.club].players.find(x=>x.id===payload.playerId);check(player&&(payload.slot<15?slotEligible(player,payload.slot):benchEligible(player,payload.slot-15)),'poste non qualifié ou joueur absent');}
   let row=p.lineups.find(l=>l.fixtureId===payload.fixtureId);
   if(!row){check(p.lineups.length<3,'retirez une ancienne composition avant d’en préparer une autre');row={fixtureId:payload.fixtureId,slots:Array(23).fill(null)};p.lineups.push(row);}
   if(payload.slot===null)row.slots.fill(null);else row.slots[payload.slot]=payload.playerId;
   if(row.slots.every(x=>x===null))p.lineups=p.lineups.filter(l=>l!==row);
  }else if(command==='manager_plan_scenario')p.scenario=copy(payload.operations);
  else p.goal=payload.metric===null&&payload.target===null?null:{metric:payload.metric,target:payload.target,startedAt:(S.history||[]).length};
  validate({...S,managerPlanning:p});S.managerPlanning=p;return {managerPlanningReceipt:{command}};
 }
 return {project,execute,validate,installHooks:()=>true};
}
const finite=x=>typeof x==='number'&&Number.isFinite(x);
const copy=x=>JSON.parse(JSON.stringify(x));
const publicPlayer=p=>Object.fromEntries(['id','name','pos','age','salary','fee','contractEnd','condition','injury','suspension','rating','ratingRange','potential','potentialRange','knowledge'].filter(k=>p[k]!==undefined).map(k=>[k,copy(p[k])]));
// Première occurrence de chaque identifiant (même résultat que findIndex, en temps linéaire :
// le vivier mondial compte plusieurs milliers de joueurs et la projection tourne à chaque commande).
const candidatesOf=model=>{const seen=new Set();return [...(model.market||[]),...(model.clubLife?.interclubMarket?.candidates||[])].filter(p=>{const id=p.id;if(seen.has(id))return false;seen.add(id);return true;});};
function project(model){
 const domain=model.clubLife?.managerPlanning||{},settings=domain.settings||{},own=model.squad||[],club=model.club?.id;
 const byId=new Map(own.map(p=>[p.id,p]));
 const slots=new Map((domain.slots||[]).map(p=>[p.id,p.eligible]));
 const players=own.map(p=>({...publicPlayer(p),eligible:slots.get(p.id)||[]}));
 const calls=model.international?.availability?.players||[];
 const relations=new Map((model.clubLife?.relationships?.players||[]).map(p=>[p.id,p]));
 const promiseMinutes=new Map((model.clubLife?.relationships?.promiseOptions||[]).map(p=>[p.id,p.minutes]));
 const fixtures=(model.calendar||[]).filter(f=>!f.played&&f.id&&(f.home?.id===club||f.away?.id===club)&&(typeof f.date!=='string'||!model.meta?.today||f.date>=model.meta.today)).sort((a,b)=>String(a.date||'').localeCompare(String(b.date||''))||(a.week??0)-(b.week??0)||String(a.id).localeCompare(String(b.id))).slice(0,3).map(f=>{
  const draft=settings.lineups?.find(l=>l.fixtureId===f.id),lineup=draft?.slots||Array(23).fill(null),warnings=[];
  for(const id of lineup.filter(Boolean)){
   const p=byId.get(id);if(!p){warnings.push('Un joueur prévu a quitté l’effectif.');continue;}
   if(p.injury>0)warnings.push(p.name+' : blessé actuellement ; retour à confirmer.');
   if(p.suspension>0)warnings.push(p.name+' : suspension actuelle à vérifier.');
   const call=calls.find(c=>c.id===id||c.playerId===id);
   if(call&&(!f.date||!call.returnDate||f.date<call.returnDate))warnings.push(p.name+' : sélection confirmée, retour '+(call.returnDate||'non renseigné')+'.');
  }
  const promises=players.filter(p=>relations.get(p.id)?.promise).map(p=>({id:p.id,name:p.name,promise:copy(relations.get(p.id).promise),targetMinutes:promiseMinutes.get(relations.get(p.id).promise.target)??null,planned:lineup.includes(p.id)}));
  return {id:f.id,date:f.date??null,week:f.week??null,home:f.home,away:f.away,slots:lineup.slice(),filled:lineup.filter(Boolean).length,warnings,promises};
 });
 const candidates=candidatesOf(model);
 const academy=(model.decisions?.development?.academy||[]).map(publicPlayer);
 const finance=model.clubLife?.clubStrategy?.finance||{};
 const weeks=finite(finance.weeksPerSeason)&&finance.weeksPerSeason>0?finance.weeksPerSeason:null;
 let upFront=0,weeklyWages=own.every(p=>finite(p.salary))?own.reduce((n,p)=>n+p.salary,0):null,totalCommitment=weeks===null?null:0;
 const operations=(settings.scenario||[]).map(o=>{
  const source=(o.kind==='renew'?own:o.kind==='promote'?academy:candidates).find(p=>p.id===o.playerId);
  const borrowed=o.kind==='renew'&&(domain.loans||[]).some(l=>l.id===o.playerId&&l.to===club&&l.from!==club),available=!!source&&!borrowed;
  if(available){upFront+=o.fee;if(weeklyWages!==null)weeklyWages+=o.salary-(o.kind==='renew'?source.salary:0);if(totalCommitment!==null)totalCommitment+=o.fee+o.salary*weeks*o.years;}
  return {...o,contractStart:model.meta?.season,contractEnd:model.meta?.season+o.years-1,player:source?publicPlayer(source):null,available,reason:borrowed?'Prêt entrant : aucune prolongation du contrat propriétaire établie.':source?'':'Source absente : hypothèse exclue des totaux.'};
 });
 const season=model.meta?.season;
 const horizons=[{id:'now',label:'Maintenant',season},{id:'end',label:'Fin de saison',season},{id:'next',label:'Saison suivante',season:season+1}].map((h,i)=>{
  const loans=domain.loans||[];
  const roster=own.filter(p=>i<2||(!finite(p.contractEnd)||p.contractEnd>season)&&!loans.some(l=>l.id===p.id&&l.to===club&&l.from!==club));
  const planned=roster.map(publicPlayer);
  if(i===2)for(const loan of loans.filter(l=>l.from===club&&l.to!==club&&l.returnSeason===season+1&&l.player)){
   if(!planned.some(p=>p.id===loan.id)&&(!finite(loan.player.contractEnd)||loan.player.contractEnd>season))planned.push({...publicPlayer(loan.player),loanReturn:true});
  }
  if(i>0)for(const o of operations.filter(o=>o.available)){
   const pi=planned.findIndex(p=>p.id===o.playerId);if(pi>=0)planned.splice(pi,1);
   if(i<2||o.contractEnd>=season+1)planned.push({...copy(o.player),salary:o.salary,contractEnd:o.contractEnd,scenario:true});
  }
  const positions=[...new Set(own.map(p=>p.pos))].map(pos=>({pos,count:planned.filter(p=>p.pos===pos).length}));
  return {...h,players:planned,positions,expiring:planned.filter(p=>p.contractEnd===season).length,unknownContracts:planned.filter(p=>!finite(p.contractEnd)).length,weeklyWages:planned.every(p=>finite(p.salary))?planned.reduce((n,p)=>n+p.salary,0):null};
 });
 const goal=settings.goal?goalProjection(settings.goal,domain.goalRows||[]):null;
 return {available:!!model.meta?.hasCareer||!!model.club,editable:!!model.club&&!model.live&&model.meta?.phase!=='ended',context:domain.context??null,fixtures,players,candidateCount:candidates.length,academy,staleLineups:(settings.lineups||[]).filter(l=>!fixtures.some(f=>f.id===l.fixtureId)),settings:copy(settings),scenario:{operations,upFront,weeklyWages,totalCommitment,weeksPerSeason:weeks,incomplete:operations.some(o=>!o.available)||weeklyWages===null||weeks===null},horizons,goal,notice:'Intentions de préparation : aucune feuille officielle, signature ou dépense n’est modifiée. Les disponibilités seront revérifiées le jour du match.'};
}
function goalProjection(goal,source){
 const metric=goal.metric,kind={lineouts:'lineout',scrums:'scrum',penalties:'penalty'}[metric];
 let attempts=0,won=0,total=0,measuredMatches=0;
 const rows=source.map(r=>{
  const stats=r.stats||{},valid=metric==='penalties'?finite(stats.penalties)&&stats.penalties>=0:finite(stats[metric])&&stats[metric]>0&&finite(stats[metric+'Won'])&&stats[metric+'Won']>=0&&stats[metric+'Won']<=stats[metric];
  if(valid){measuredMatches++;if(metric==='penalties')total+=stats.penalties;else{attempts+=stats[metric];won+=stats[metric+'Won'];}}
  return {...r,value:valid?(metric==='penalties'?stats.penalties:100*stats[metric+'Won']/stats[metric]):null,events:(r.events||[]).filter(e=>e.kind===kind)};
 });
 return {...goal,rows,measuredMatches,value:measuredMatches?(metric==='penalties'?total/measuredMatches:100*won/attempts):null,notice:'Mesures conservées depuis le choix de cet objectif, au plus 40 rencontres. Les écarts ne prouvent pas l’effet de la préparation ; une donnée absente reste inconnue.'};
}
function validateRequest(model,command,payload){
 const p=project(model);
 if(command==='manager_plan_lineup'&&!p.fixtures.some(f=>f.id===payload.fixtureId)&&!(payload.playerId===null&&p.settings.lineups?.some(f=>f.fixtureId===payload.fixtureId)))throw Error('Rencontre absente des trois prochaines rencontres publiées.');
 if(command==='manager_plan_scenario'){
  if(!Array.isArray(payload.operations))throw Error('Hypothèses invalides.');
  for(const o of payload.operations){
   const unchanged=p.settings.scenario?.some(old=>['kind','playerId','years','salary','fee'].every(k=>old[k]===o[k]));
   if(unchanged)continue;
   const source=(o.kind==='renew'?p.players:o.kind==='promote'?p.academy:candidatesOf(model)).find(p=>p.id===o.playerId);if(!source)throw Error('Joueur absent du dossier de préparation.');
   if(o.kind==='renew'&&(model.clubLife?.managerPlanning?.loans||[]).some(l=>l.id===o.playerId&&l.to===model.club.id&&l.from!==model.club.id))throw Error('Prêt entrant : le contrat propriétaire ne peut pas être prolongé dans ce scénario.');
  }
 }
}
module.exports={files,commands,factory,project,validateRequest};
