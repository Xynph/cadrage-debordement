'use strict';
// V58 : moteur pur de mobilite des entraineurs, sans mutation des sauvegardes existantes.
(function(root,factory){const api=factory(typeof module==='object'&&module.exports?require('./coach-market.js'):root.CDCoachMarket);if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDCoachCareer=api})(typeof globalThis==='object'?globalThis:null,function(market){
const validNumber=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
const clone=x=>JSON.parse(JSON.stringify(x));
const check=(ok,msg)=>{if(!ok)throw Error(msg)};
function validate(state){check(state&&Array.isArray(state.clubs)&&Array.isArray(state.coaches)&&Array.isArray(state.events),'Etat invalide');const clubIds=new Set(),coachIds=new Set();
for(const c of state.clubs){check(c&&typeof c.id==='string'&&c.id&&!clubIds.has(c.id)&&validNumber(c.budget)&&validNumber(c.reputation)&&c.reputation<=100,'Club invalide');clubIds.add(c.id);}
for(const c of state.coaches){check(c&&typeof c.id==='string'&&c.id&&!coachIds.has(c.id)&&validNumber(c.salary)&&validNumber(c.reputation)&&c.reputation<=100&&Number.isInteger(c.experience)&&c.experience>=0,'Entraineur invalide');coachIds.add(c.id);}
for(const c of state.clubs)if(c.coachId!=null)check(coachIds.has(c.coachId),'Entraineur manquant');
check(new Set(state.clubs.map(c=>c.coachId).filter(Boolean)).size===state.clubs.filter(c=>c.coachId).length,'Entraineur employe deux fois');return true;}
function profile({id,reputation,experience=0,salary=0,skills={}}){check(typeof id==='string'&&id&&validNumber(reputation)&&reputation<=100&&Number.isInteger(experience)&&experience>=0&&validNumber(salary),'Profil invalide');return {id,reputation,experience,salary,skills:{leadership:Math.max(0,Math.min(100,skills.leadership??50)),training:Math.max(0,Math.min(100,skills.training??50))},history:[]};}
function openings(state){validate(state);return market.vacancies(state.clubs.map(c=>({id:c.id,budget:c.budget,reputation:c.reputation,vacant:!c.coachId})),state.coaches.map(c=>({...c,available:!state.clubs.some(t=>t.coachId===c.id)})));}
function offers(state,coachId){validate(state);const c=state.coaches.find(x=>x.id===coachId);check(c,'Entraineur absent');return market.jobOffers(state.clubs.map(x=>({id:x.id,budget:x.budget,reputation:x.reputation,vacant:!x.coachId})),c).map(o=>({...o,contractYears:Math.max(1,Math.min(4,Math.round((o.affinity+20)/35)))}));}
function apply(state,action){validate(state);check(action&&typeof action==='object'&&Number.isInteger(action.season)&&action.season>=1,'Action invalide');const next=clone(state),club=next.clubs.find(c=>c.id===action.clubId);
check(club,'Club absent');let event;
if(action.type==='dismiss'){check(club.coachId,'Poste deja vacant');const former=club.coachId;club.coachId=null;event={type:'dismiss',season:action.season,clubId:club.id,coachId:former};}
else if(action.type==='hire'){const c=next.coaches.find(c=>c.id===action.coachId);check(c&&!club.coachId&&!next.clubs.some(x=>x.coachId===c.id)&&c.salary<=club.budget,'Offre impossible');const years=action.years??2;check(Number.isInteger(years)&&years>=1&&years<=5,'Duree invalide');club.coachId=c.id;club.budget-=c.salary;event={type:'hire',season:action.season,clubId:club.id,coachId:c.id,salary:c.salary,years};c.history.push({clubId:club.id,from:action.season,years});}
else if(action.type==='move'){const c=next.coaches.find(c=>c.id===action.coachId),previous=next.clubs.find(x=>x.coachId===action.coachId);check(c&&previous&&previous.id!==club.id&&!club.coachId&&c.salary<=club.budget,'Mutation impossible');previous.coachId=null;club.coachId=c.id;club.budget-=c.salary;event={type:'move',season:action.season,from:previous.id,clubId:club.id,coachId:c.id,salary:c.salary};c.history.push({clubId:club.id,from:action.season});}
else throw Error('Action inconnue');
next.events.push(event);validate(next);return {state:next,event};}
function negotiate({salaryRequested,salaryCap,years,objectives=0}){check(validNumber(salaryRequested)&&validNumber(salaryCap)&&Number.isInteger(years)&&years>=1&&years<=5&&validNumber(objectives)&&objectives<=100,'Negociation invalide');return {accepted:salaryRequested<=salaryCap,proposedSalary:Math.min(salaryRequested,salaryCap),years,objectivePressure:objectives};}
function aiTurn(state,season){validate(state);let next=clone(state),events=[];for(const vacancy of openings(next)){const best=vacancy.options[0];if(!best)continue;const r=apply(next,{type:'hire',clubId:vacancy.clubId,coachId:best,season,years:2});next=r.state;events.push(r.event);}return {state:next,events};}
return Object.freeze({profile,validate,openings,offers,apply,negotiate,aiTurn});
});
