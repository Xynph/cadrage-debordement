'use strict';
// Transferts entre clubs gérés : stratégies, valeur, bornes et exécution sur un petit monde factice.
const assert=require('node:assert/strict'),vm=require('node:vm');
const factory=require('../native/engine/club-transfers.cjs');
const POS=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne aile','Troisième ligne aile','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière'];
function world({cash=[6e6,1.2e6,3e6,3e6],reputation=[90,70,75,60],ages=[26,26,21,33]}={}){
 const player=(club,i,age)=>({id:`p${club}-${i}`,name:`Joueur ${club}-${i}`,pos:POS[i%15],age,salary:4000+100*(i%7),contractEnd:3,joinedSeason:0,note:60+(i*7+club*3)%25,dev:{retireAge:38}});
 const clubs=cash.map((c,id)=>({id,name:'Club '+id,cash:c,base:70,players:Array.from({length:44},(_,i)=>player(id,i,id===3?ages[3]+(i%3):ages[id]-(i%5)))}));
 const reports=[],events=[];
 const ctx={S:{season:2,round:13,club:9,phase:'league',live:null,clubs,economy:{transfers:[],aiRecruitmentWindow:null},worldMode:{leagues:{a:{members:[0,1,2,3]}}}},
  CDWorldCareer:{active:()=>true},aiRosterPopulationActive:()=>true,aiRosterActive:()=>true,POS,AI_POPULATION_DEPTH:[[0,3],[1,3],[2,3],[3,5],[5,7],[8,3],[9,3],[10,4],[11,4],[14,2]],
  clamp:(v,a,b)=>Math.max(a,Math.min(b,v)),seedHash:s=>[...s].reduce((h,c)=>Math.imul(h^c.charCodeAt(0),16777619)>>>0,2166136261),
  roleNote:p=>p.note,slotEligible:(p,slot)=>p.pos===POS[slot],worldClub:id=>({reputation:reputation[id],facilities:2,debt:0}),
  aiRosterPayroll:c=>c.players.reduce((n,p)=>n+p.salary,0),aiRosterWageLimit:c=>c.id===1?100000:400000,aiRosterTarget:()=>44,
  aiRosterMarketNeeds:c=>c.players.filter(p=>p.pos==='Talonneur').length<4?[{slot:1,pos:'Talonneur',score:60}]:[],
  aiRosterMayRecruit:c=>c.players.length<44,professionalPlaces:c=>50-c.players.length,money:x=>x+' €',
  aiRosterReport:id=>{let r=reports.find(x=>x.clubId===id&&x.season===2);if(!r){r={clubId:id,season:2,recruited:0};reports.push(r);}return r;},
  aiRosterEvent:(clubId,kind,p,fee)=>events.push({clubId,kind,playerId:p.id,fee}),aiRosterRecruitmentWeek:()=>0};
 vm.createContext(ctx);vm.runInContext('var api=('+factory.toString()+')();',ctx);
 return {ctx,api:ctx.api,reports,events};
}
// Stratégies lisibles, déduites de la situation publique du club dans son championnat.
{const {ctx,api}=world();const S=ctx.S,peers=S.clubs;
 assert.equal(api.strategy(S.clubs[0],peers),'vedettes','riche et réputé');
 assert.equal(api.strategy(S.clubs[1],peers),'vente','masse au-dessus de sa limite');
 assert.equal(api.strategy(S.clubs[3],peers),'rajeunissement','effectif âgé');
 assert.equal(api.strategy(S.clubs[2],peers),'formateur','effectif jeune');}
// Valeur : salaire annuel × années restantes (au plus deux) × âge.
{const {api,ctx}=world();const v=p=>api.value({salary:5000,contractEnd:3,age:p});
 assert.equal(api.value({salary:5000,contractEnd:2,age:25}),340000);assert.ok(v(22)>v(27)&&v(27)>v(30)&&v(30)>v(34));
 assert.equal(ctx.S.season,2);}
// Une fenêtre : des transferts ont lieu, l'acheteur paie le vendeur, bornes respectées, rien n'est dupliqué.
{const {ctx,api,reports,events}=world();const S=ctx.S,before=S.clubs.reduce((n,c)=>n+c.cash,0),ids=S.clubs.flatMap(c=>c.players.map(p=>p.id)).sort();
 S.clubs[0].players.splice(0,6);// le club riche a de la place et des besoins
 const ids2=S.clubs.flatMap(c=>c.players.map(p=>p.id)).sort();
 const moves=api.transferWindow();
 assert.ok(moves.length>0,'au moins un transfert');
 assert.equal(S.clubs.reduce((n,c)=>n+c.cash,0),before,'les indemnités passent d’un club à l’autre');
 assert.deepEqual(S.clubs.flatMap(c=>c.players.map(p=>p.id)).sort(),ids2,'aucun joueur perdu ni dupliqué');
 for(const r of reports)assert.ok((r.bought||0)<=3&&(r.sold||0)<=3);
 for(const m of moves){assert.ok(S.clubs[m.buyer].players.some(p=>p.id===m.playerId&&p.joinedSeason===2));assert.ok(events.some(e=>e.kind==='sell'&&e.clubId===m.seller&&e.playerId===m.playerId));}
 assert.ok(moves.every(m=>m.buyer!==S.club&&m.seller!==S.club),'le club du manager n’est pas concerné');
 assert.ok(ids.length>ids2.length);
 assert.equal(api.transferWindow().filter(m=>moves.some(x=>x.playerId===m.playerId)).length,0,'un joueur arrivé cette saison n’est pas revendu');}
console.log('PASS transferts entre clubs gérés : stratégies, valeur, fenêtre bornée, indemnités conservées, aucun doublon');
