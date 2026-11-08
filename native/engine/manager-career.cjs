'use strict';
const commands=['manager_career_activate','manager_career_apply','manager_career_accept','manager_career_decline','manager_career_cancel','manager_recruitment_watch'];
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const check=(ok,msg)=>{if(!ok)throw Error('Carrière du manager : '+msg+'.');};
 const shape=(x,keys)=>object(x)&&Object.keys(x).every(k=>keys.split(' ').includes(k));
 const week=s=>s.franceMode?s.franceMode.week:s.phase==='league'?s.round:({barrage:26,semi:27,final:28,ended:29}[s.phase]??s.round);
 const context=()=>({season:S.season,week:week(S),club:S.club});
 function validate(s){
  if(!s||s.managerMobility===undefined&&s.managerMobilityVersion===undefined)return true;
  validateManagerMobility(s);const m=s.managerMobility;
  check(shape(m,'version originClub enabledSeason currentFrom pending applications history archives'),'champs de mobilité inconnus');
  for(const a of m.applications)check(shape(a,'id season fromClub clubId status reason reputation risk affinity coachChanges'),'champs de candidature inconnus');
  if(m.pending!==null)check(shape(m.pending,'offerId fromClub toClub season coachChanges'),'champs de prise de poste inconnus');
  for(const h of m.history)check(shape(h,'fromClub toClub departureSeason arrivalSeason offerId'),'champs de parcours inconnus');
  for(const a of m.archives)check(shape(a,'clubId season ledger boardHistory academyInvestment'),'champs des archives inconnus');
  return true;
 }
 function project(){
  if(!S)return {active:false,available:false,opportunities:[],applications:[],history:[],archives:[],plan:[],recruitment:[]};
  const active=managerMobilityActive(),m=active?S.managerMobility:null,window=managerMobilityWindow(),weeks=S.franceMode?34:29,own=S.clubs[S.club];
  // Coverage comes from the existing pure succession engine. Cash is deliberately
  // not forecast by its historical 29-week finance model in France30.
  const people=own.players.map(p=>successionPerson(p));
  const plan=Array.from({length:3},(_,i)=>{const year=S.season+i,payments=i?weeks:Math.max(0,weeks-week(S)),players=own.players.filter(p=>p.contractEnd>=year);return {...successionYear(S,people,S.development.academy,year),payments,payroll:players.reduce((n,p)=>n+p.salary,0)*payments};});
  const recruitment=managerPool().map(source=>{const p=copy(source);return {playerId:p.id,pos:p.pos,age:p.age,watched:S.manager.watch.includes(p.id),fee:contractFee(p,'recruit'),salary:askingWage(p,'recruit'),terms:[1,2,3].filter(y=>y<=careerContractYears(p)).map(years=>{const payments=(S.phase==='ended'?0:weeks-week(S))+(years-(S.phase==='ended'?0:1))*weeks,salary=askingWage(p,'recruit');return {years,payments,salary,fee:contractFee(p,'recruit'),knownCommitment:contractFee(p,'recruit')+payments*salary};})};});
  return {active,available:!S.live&&worldActive()&&careerIntegrated()&&aiRosterActive(),context:context(),clubId:S.club,originClub:m?.originClub??S.club,currentFrom:m?.currentFrom??S.season,window,locked:!!S.live,capacity:professionalCapacity(own),reserved:professionalLoanReservations(own).length,occupied:own.players.length+professionalLoanReservations(own).length,places:professionalPlaces(own),recruitmentAvailable:professionalPlaces(own)>0&&!S.live&&S.phase!=='ended',pending:m?copy(m.pending):null,applications:m?copy(m.applications).reverse():[],opportunities:window?S.clubs.filter(c=>c.id!==S.club).map(c=>({...managerMobilityDecision(c.id),leagueId:S.franceMode?CDFranceCompetition.leagueId(S,c.id):'historical',applied:m.applications.some(a=>a.season===S.season&&a.clubId===c.id)})):[],history:m?copy(m.history).reverse():[],archives:m?m.archives.map(a=>({clubId:a.clubId,season:a.season,academyInvestment:a.academyInvestment,ledger:copy(a.ledger),boardHistory:copy(a.boardHistory)})):[],recruitment,watch:S.manager.watch.slice(),reports:S.manager.reports.map(r=>({playerId:r.playerId,season:r.season,week:r.week,grade:r.grade,note:r.note,potential:r.potential})),plan,weeksPerSeason:weeks,notice:'Mobilité volontaire après la fin des compétitions, effective au passage à la saison suivante. Les comptes, joueurs et centres restent dans leur club. Aucun salaire ou contrat personnel de manager.',planNotice:'Couverture projetée à partir des contrats et retraites prévus, sans recrutement ni progression inventés. Masse salariale connue sur le calendrier actif, hors primes, futures signatures et recettes.'};
 }
 function execute(command,p){
  check(S&&!S.live,'décision indisponible pendant le match');check(shape(p,'context clubId offerId confirmed playerId')&&shape(p.context,'season week club')&&p.context.season===S.season&&p.context.week===week(S)&&p.context.club===S.club,'contexte périmé ou données inconnues');
  let accepted=false;
  if(command==='manager_career_activate')accepted=managerMobilityEnable();
  else if(command==='manager_recruitment_watch'){
   check(S.phase!=='ended'&&typeof p.playerId==='string','suivi indisponible');const before=S.manager.watch.includes(p.playerId);check(before||managerPool().some(x=>x.id===p.playerId),'candidat indisponible');watchPlayer(p.playerId);accepted=S.manager.watch.includes(p.playerId)!==before;
  }else{
   check(managerMobilityWindow(),'les candidatures ouvrent à la fin de toutes les compétitions');
   if(command==='manager_career_apply'){check(Number.isInteger(p.clubId),'club invalide');accepted=managerMobilityApply(p.clubId);}
   else if(command==='manager_career_accept'){check(p.confirmed===true,'confirmez la prise de poste pour la saison suivante');check(typeof p.offerId==='string','offre invalide');accepted=managerMobilityAccept(p.offerId);}
   else if(command==='manager_career_decline'){check(typeof p.offerId==='string','offre invalide');accepted=managerMobilityDecline(p.offerId);}
   else if(command==='manager_career_cancel')accepted=managerMobilityCancel();
  }
  check(accepted,'décision refusée : offre périmée, doublon ou indisponibilité');validate(S);return {managerCareerDecision:{command}};
 }
 function installHooks(){return true;}
 return {project,validate,execute,installHooks};
}
module.exports={files:[],commands,factory};


