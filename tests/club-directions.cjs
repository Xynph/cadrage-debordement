'use strict';
// Directions des clubs gérés : traits persistants, stratégie émergente, évaluation
// bruitée, erreurs, prêts, jokers médicaux, changements d'hommes, déterminisme et
// validation, sur un petit monde factice de deux championnats.
const assert=require('node:assert/strict'),vm=require('node:vm');
const transfers=require('../native/engine/club-transfers.cjs'),directions=require('../native/engine/club-directions.cjs');
const POS=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne aile','Troisième ligne aile','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière'];
function world(seed=27,{cash,ages,staff}={}){
 const N=8;cash??=[9e6,1.2e6,3e6,3e6,2.5e6,0.6e6,2e6,4e6];ages??=[27,26,21,32,25,28,24,26];
 const player=(club,i,age)=>({id:`p${club}-${i}`,name:`Joueur ${club}-${i}`,pos:POS[i%15],age,salary:4000+120*(i%9)+club*150,contractEnd:2+(i%3),joinedSeason:0,note:58+(i*7+club*5)%26,injury:0,dev:{retireAge:37}});
 const clubs=cash.map((c,id)=>({id,name:'Club '+id,cash:c,base:70+(id%3),players:Array.from({length:46},(_,i)=>player(id,i,ages[id]+(i%6)-2))}));
 const leagues={elite:{members:[0,1,2,3]},accession:{members:[4,5,6,7]}};
 const reports=[],events=[],news=[];
 const leagueId=(s,id)=>Object.keys(leagues).find(k=>leagues[k].members.includes(id))||'guest';
 const formOf=id=>id===3?['L','L','L','L','L','L']:id===0?['W','W','W','W','L','W']:['W','L','W','L','D','W'];
 const ctx={S:{season:1,round:0,club:7,phase:'league',live:null,clubs,economy:{transfers:[],freeAgents:[],aiRecruitmentWindow:null},market:[],worldMode:{week:0,leagues,yearbook:[]}},
  CDWorldCareer:{active:()=>true,leagueId,rows:(s,lg)=>leagues[lg].members.map(id=>({clubId:id,played:ctx.S.worldMode.week,form:formOf(id)})).sort((a,b)=>(a.clubId===3)-(b.clubId===3)||a.clubId-b.clubId)},
  aiRosterPopulationActive:()=>true,aiRosterActive:()=>true,POS,AI_POPULATION_DEPTH:[[0,3],[1,3],[2,3],[3,5],[5,7],[8,3],[9,3],[10,4],[11,4],[14,2]],
  clamp:(v,a,b)=>Math.max(a,Math.min(b,v)),seedHash:s=>[...String(s)].reduce((h,c)=>Math.imul(h^c.charCodeAt(0),16777619)>>>0,2166136261),
  roleNote:p=>p.note,slotEligible:(p,slot)=>p.pos===POS[slot],worldClub:id=>({reputation:[92,80,84,78,70,62,66,72][id],facilities:id===2?3:2,debt:id===5?300000:0}),
  aiRosterPayroll:c=>c.players.reduce((n,p)=>n+p.salary,0),aiRosterWageLimit:c=>c.id===1?150000:420000,aiRosterTarget:()=>46,
  aiRosterMayRecruit:c=>c.players.length<46,professionalPlaces:c=>52-c.players.length,money:x=>x+' €',
  aiRosterReport:id=>{let r=reports.find(x=>x.clubId===id&&x.season===ctx.S.season);if(!r){r={clubId:id,season:ctx.S.season,recruited:0};reports.push(r);}return r;},
  aiRosterEvent:(clubId,kind,p,fee)=>events.push({clubId,kind,playerId:p.id,fee}),aiRosterRecruitmentWeek:()=>0,news:t=>news.push(t)};
 if(staff)ctx.S.staffCareer={version:1,people:[staff],history:[]};
 vm.createContext(ctx);
 vm.runInContext('var nativeClubTransfers=('+transfers.toString()+')();var api=('+directions.toString()+')(nativeClubTransfers,('+require("../native/engine/staff-completion.cjs").factory.toString()+')());',ctx);
 assert.ok(ctx.api.create(ctx.S,seed));
 return {ctx,api:ctx.api,S:ctx.S,events,news};
}
const ids=S=>S.clubs.flatMap(c=>c.players.map(p=>p.id)).sort();
// Création : chaque club a une direction aux traits bornés, un réseau, un objectif ; état valide.
{const {S,api}=world();const d=S.clubDirections;
 assert.equal(Object.keys(d.clubs).length,8);
 for(const x of Object.values(d.clubs)){
  for(const t of [x.president.traits,x.director.traits,x.coach.traits])for(const v of Object.values(t))assert.ok(Number.isInteger(v)&&v>=0&&v<=100);
  assert.ok(x.director.network.length>=1&&api.STRATEGIES.includes(x.strategy)&&x.objective>=1&&x.objective<=4);
 }
 assert.ok(api.validate(S));
 assert.ok(new Set(Object.values(d.clubs).map(x=>x.president.traits.ambition)).size>=5,'des présidents différents');
 assert.equal(world(28).S.clubDirections.clubs[0].president.traits.ambition===d.clubs[0].president.traits.ambition&&world(28).S.clubDirections.clubs[1].director.traits.evaluation===d.clubs[1].director.traits.evaluation,false,'la graine change les directions');
 assert.deepEqual(JSON.stringify(world(27).S.clubDirections),JSON.stringify(d),'même graine, mêmes directions');
 assert.throws(()=>api.validate({...S,clubDirections:{...d,version:2}}),/Directions/);}
// Stratégie fondée sur la situation : dette → vente ; riche et ambitieux → vedettes possible ; inertie.
{const {S,api}=world();const d=S.clubDirections;
 assert.equal(d.clubs[5].strategy,'vente','dette et trésorerie basse');
 const x=d.clubs[0];x.president.traits.ambition=90;x.director.traits.formation=10;x.strategy='equilibre';
 const sit=api.situation(S.clubs[0],S.clubs.slice(0,4),x),sc=api.scores(sit,x);
 assert.ok(sc.vedettes>sc.formateur&&sc.vedettes>sc.equilibre,'club riche et ambitieux');
 const y=d.clubs[3];y.missed=2;const s3=api.scores(api.situation(S.clubs[3],S.clubs.slice(0,4),y),y);
 assert.ok(s3.reconstruction>s3.equilibre,'objectif manqué et effectif âgé : reconstruction');}
// Évaluation bruitée : plus la compétence est faible, plus l'erreur est grande ; stable dans la saison.
{const {S,api}=world();const d=S.clubDirections,c=S.clubs[0];
 const err=ev=>{d.clubs[0].director.traits.evaluation=ev;return S.clubs[1].players.reduce((n,p)=>n+Math.abs(api.estimate(c,p,'elite')-p.note),0)/46;};
 assert.ok(err(10)>err(95)*1.8,'compétence et précision');
 const p=S.clubs[1].players[0];assert.equal(api.estimate(c,p,'elite'),api.estimate(c,p,'elite'));
 d.clubs[0].director.network=['elite'];d.clubs[0].director.traits.evaluation=80;
 const far=S.clubs[4].players.reduce((n,p)=>n+Math.abs(api.estimate(c,p,'accession')-p.note),0),near=S.clubs[1].players.reduce((n,p)=>n+Math.abs(api.estimate(c,p,'elite')-p.note),0);
 assert.ok(far>near,'hors réseau, moins bien connu');}
// Besoins : blessures, âge et fins de contrat comptent.
{const {S,api}=world();const c=S.clubs[0];
 const base=api.needs(c).find(n=>n.slot===1)?.score||0;
 c.players.filter(p=>p.pos==='Talonneur').forEach((p,i)=>{if(i<2)p.injury=8;});
 assert.ok((api.needs(c).find(n=>n.slot===1)?.score||0)>base,'talonneurs blessés : besoin');}
// Fenêtres sur deux saisons : mouvements, indemnités conservées, aucun doublon, comptes tenus, déterminisme.
function run(seed){
 const w=world(seed),{S,api}=w;const total=()=>S.clubs.reduce((n,c)=>n+c.cash,0);
 S.clubs[0].players.splice(0,8);S.clubs[2].players.splice(5,4);
 const cash=total(),before=ids(S),moves=[];
 S.worldMode.week=13;S.round=13;moves.push(...api.openWindow());
 assert.equal(total(),cash,'les indemnités passent d’un club à l’autre');
 assert.deepEqual(ids(S),before,'aucun joueur perdu ni dupliqué');
 S.clubDirections.clubs[3].objective=1;
 S.season=2;S.worldMode.week=0;S.round=0;S.worldMode.yearbook=[{standings:{elite:[0,2,1,3],accession:[4,6,7,5]}}];
 moves.push(...api.openWindow());
 assert.deepEqual(ids(S),before);
 assert.ok(api.validate(S));
 return {w,moves};
}
{const a=run(27),b=run(27);
 assert.ok(a.moves.length>0,'des mouvements');
 assert.equal(JSON.stringify(a.moves),JSON.stringify(b.moves),'déterministe');
 assert.equal(JSON.stringify(a.w.S.clubDirections),JSON.stringify(b.w.S.clubDirections));
 const t=a.w.S.clubDirections.tally;assert.ok(Object.keys(t).some(k=>k.includes('|strategie:')),'stratégies comptées');
 assert.ok(a.moves.every(m=>m.buyer!==a.w.S.club&&m.seller!==a.w.S.club),'le club du manager n’est pas concerné');
 // Revue de saison : objectif manqué compté, direction réévaluée.
 assert.ok(Object.keys(t).some(k=>/\|objectif-(manque|depasse)$/.test(k)));}
// Prêts : un club formateur de première division prête un jeune à la division inférieure, retour la saison suivante.
{const {S,api}=world();const d=S.clubDirections,c=S.clubs[2];
 d.clubs[2].coach.traits.youth=90;d.clubs[2].director.traits.formation=90;
 for(let i=0;i<4;i++)c.players.push({id:'p2-x'+i,name:'Talonneur '+i,pos:'Talonneur',age:27,salary:5000,contractEnd:4,joinedSeason:0,note:76,injury:0,dev:{retireAge:37}});
 Object.assign(c.players[1],{age:19,note:52,contractEnd:4});
 S.season=2;S.worldMode.week=0;S.round=0;
 api.openWindow();
 const loan=d.loans.find(l=>l.from===2);assert.ok(loan,'un prêt');
 assert.equal(S.clubDirections.clubs[loan.to]&&['accession'].includes(ctx2(S,loan.to)),true);
 assert.ok(S.clubs[loan.to].players.some(p=>p.id===loan.playerId));
 S.season=3;api._internal.returnLoans();
 assert.ok(S.clubs[2].players.some(p=>p.id===loan.playerId),'retour au club prêteur');
 assert.equal(d.loans.filter(l=>l.playerId===loan.playerId).length,0);}
function ctx2(S,id){return Object.keys(S.worldMode.leagues).find(k=>S.worldMode.leagues[k].members.includes(id));}
// Joker médical : blessure longue à un poste dégarni, joueur libre engagé jusqu'à la fin de saison.
{const {S,api}=world();const c=S.clubs[4];
 const hookers=c.players.filter(p=>p.pos==='Talonneur');hookers.forEach(p=>{p.injury=9;});
 S.economy.freeAgents=[{id:'libre-1',name:'Libre Un',pos:'Talonneur',age:29,salary:2000,note:66,injury:0,dev:{retireAge:37}}];
 S.worldMode.week=7;S.round=7;api.weekly();
 assert.ok(c.players.some(p=>p.id==='libre-1'),'joker engagé');assert.equal(S.economy.freeAgents.length,0);
 assert.ok(Object.keys(S.clubDirections.tally).some(k=>k.endsWith('|joker-medical')));}
// Série noire : l'entraîneur d'un club qui perd tout et manque son objectif finit renvoyé.
{const {S,api,news}=world();const x=S.clubDirections.clubs[3];x.objective=1;x.president.traits.patience=5;const before=x.coach.since;
 for(let wk=6;wk<14&&x.coach.since===before;wk++){S.worldMode.week=wk;S.round=wk;api.weekly();}
 assert.notEqual(x.coach.since,before,'entraîneur remplacé');
 assert.ok(!news.some(t=>/se sépare/.test(t)),'hors du championnat du manager : pas de nouvelle');
 assert.ok(S.clubDirections.feed.some(t=>/se sépare de son entraîneur/.test(t)),'fil des directions');}
// Personnes : président et directeur sportif identifiés par club, nom inventé ; entraîneur = entraîneur principal du staff.
{const coach=(id,clubId,roleLabel,level)=>({id,name:'Nom '+id,role:'coach',roleLabel,level,clubId,contractEnd:clubId===null?null:2,age:50,retireAge:70,appearanceId:id,appearanceAge:50,sourcePlayerId:null});
 const staff=[coach('s-avants',3,'Forwards Coach',80),coach('s-chef',3,'Head Coach',60),coach('s-libre',null,'Entraîneur',72),coach('s-libre2',null,'Entraîneur',55)];
 const {S,api}=world(27,{staff});const x=S.clubDirections.clubs[3];
 assert.equal(x.president.id,'pres-3');assert.equal(x.director.id,'ds-3');assert.ok(/\S+ \S+/.test(x.president.name)&&x.president.name!==x.director.name,'noms inventés');
 assert.equal(x.president.name,require('../native/engine/board-identities.cjs').baseName('pres-3',{clubs:[{id:3,country:'FR'}]}),'même nom de base que la rubrique boards');
 assert.equal(x.coach.id,'s-chef','entraîneur principal du staff, pas son adjoint mieux noté');assert.equal(x.coach.name,'Nom s-chef');
 x.objective=1;x.president.traits.patience=5;
 for(let wk=6;wk<14&&x.coach.id==='s-chef';wk++){S.worldMode.week=wk;S.round=wk;api.weekly();}
 assert.equal(x.coach.id,'s-libre','meilleur entraîneur libre engagé');
 assert.equal(staff[1].clubId,null);assert.equal(staff[2].clubId,3);
 assert.deepEqual(S.staffCareer.history.map(e=>e.kind+':'+e.id),['release:s-chef','ai-hire:s-libre']);
 assert.ok(S.clubDirections.feed.some(t=>t.includes('Nom s-chef')&&t.includes('Nom s-libre')));
 assert.ok(api.validate(S));}
console.log('PASS directions des clubs gérés : traits, stratégie émergente, évaluation bruitée, besoins, fenêtres déterministes, prêts, jokers, renvoi d’entraîneur');
