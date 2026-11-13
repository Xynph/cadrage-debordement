'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=path.join(__dirname,'../native/engine/manager-planning.cjs');
test('les trois préparations du manager doivent être disponibles',()=>assert.ok(fs.existsSync(source)));
if(fs.existsSync(source)){
 const {project,factory,validateRequest}=require(source);
 const model=()=>({meta:{season:1,week:0,today:'2026-09-01'},club:{id:0},squad:[{id:'p1',name:'Pilier A',pos:'Pilier',salary:1000,contractEnd:1,condition:90,injury:0},{id:'p2',name:'Pilier B',pos:'Pilier',salary:1200,contractEnd:2,condition:70,injury:2}],calendar:[0,1,2,3].map((x)=>({id:'f'+x,date:'2026-09-'+String(4+x*7).padStart(2,'0'),week:x,played:false,home:{id:0,name:'Nous'},away:{id:1,name:'Adversaire'}})),market:[{id:'free',name:'Candidat',pos:'Pilier',salary:2000,fee:5000,rating:null,potential:null,knowledge:{stage:'unobserved'}}],decisions:{development:{academy:[{id:'young',name:'Espoir',pos:'Pilier',salary:500,contractEnd:null}]}},clubLife:{managerPlanning:{context:{season:1,week:0,club:0},settings:null,slots:[{id:'p1',eligible:[0,2,16]},{id:'p2',eligible:[0,2,16]}],goalRows:[]},clubStrategy:{finance:{weeksPerSeason:34,weeklyWages:2200,cash:100000}},relationships:{players:[{id:'p1',promise:{minutes:60}}]}}});
 test('trois rencontres datées, intention de rotation, absences et alertes sans prédire la condition',()=>{
  const m=model();m.clubLife.managerPlanning.settings={lineups:[{fixtureId:'f0',slots:['p2',...Array(22).fill(null)]}],scenario:[],goal:null};
  const before=JSON.stringify(m),p=project(m);assert.equal(p.fixtures.length,3);assert.equal(p.fixtures[0].slots[0],'p2');assert.ok(p.fixtures[0].warnings.some(w=>w.includes('Pilier B')));assert.equal(p.players[0].condition,90);assert.equal(p.players[0].futureCondition,undefined);assert.equal(JSON.stringify(m),before);
 });
 test('scénarios : coûts et trois horizons, connaissances inconnues conservées',()=>{
  const m=model();m.clubLife.managerPlanning.settings={lineups:[],scenario:[{kind:'recruit',playerId:'free',years:2,salary:2000,fee:5000},{kind:'renew',playerId:'p1',years:2,salary:1500,fee:1000}],goal:null};
  const p=project(m);assert.equal(p.scenario.upFront,6000);assert.equal(p.scenario.weeklyWages,4700);assert.equal(p.scenario.operations[0].player.rating,null);assert.equal(p.horizons.length,3);assert.ok(p.horizons[2].players.some(p=>p.id==='p1'));assert.equal(p.scenario.totalCommitment,244000);
  delete m.clubLife.clubStrategy.finance.weeksPerSeason;assert.equal(project(m).scenario.totalCommitment,null);
  m.market=[];assert.equal(project(m).scenario.operations[0].available,false);
 });
 test('objectif : données absentes inconnues et événements structurés seulement',()=>{
  const m=model();m.clubLife.managerPlanning.settings={lineups:[],scenario:[],goal:{metric:'lineouts',target:80,startedAt:0}};
  m.clubLife.managerPlanning.goalRows=[{fixtureId:'f0',opponent:1,home:true,stats:{lineouts:10,lineoutsWon:8},events:[{minute:3,kind:'lineout',text:'Touche conservée'}]},{fixtureId:'f1',opponent:1,home:false,stats:{},events:[]}];
  const g=project(m).goal;assert.equal(g.value,80);assert.equal(g.measuredMatches,1);assert.equal(g.rows[1].value,null);assert.equal(g.rows[0].events.length,1);
 });
 test('saison suivante : fin des prêts entrants et retour des prêts sortants renseignés',()=>{
  const m=model();m.clubLife.managerPlanning.loans=[{id:'p2',from:1,to:0,returnSeason:2,player:m.squad[1]},{id:'loaned',from:0,to:1,returnSeason:2,player:{id:'loaned',name:'Prêt sortant',pos:'Pilier',salary:1000,contractEnd:2}}];
  const next=project(m).horizons[2];assert.equal(next.players.some(p=>p.id==='p2'),false);assert.ok(next.players.some(p=>p.id==='loaned'));
 });
 test('une hypothèse d’une saison se termine cette saison ; un prêt entrant n’est pas prolongé par le scénario',()=>{
  const m=model();m.clubLife.managerPlanning.settings={lineups:[],scenario:[{kind:'recruit',playerId:'free',years:1,salary:2000,fee:5000},{kind:'renew',playerId:'p2',years:2,salary:1200,fee:0}],goal:null};
  m.clubLife.managerPlanning.loans=[{id:'p2',from:1,to:0,returnSeason:2,player:m.squad[1]}];
  const p=project(m);assert.equal(p.scenario.operations[0].contractEnd,1);assert.equal(p.horizons[2].players.some(p=>p.id==='free'),false);assert.equal(p.horizons[2].players.some(p=>p.id==='p2'),false);assert.equal(p.scenario.operations[1].available,false);
 });
 test('une hypothèse périmée peut être retirée même si une autre reste en attente',()=>{
  const m=model(),ops=['gone1','gone2'].map(playerId=>({kind:'recruit',playerId,years:1,salary:1000,fee:0}));m.clubLife.managerPlanning.settings={lineups:[],scenario:ops,goal:null};
  assert.doesNotThrow(()=>validateRequest(m,'manager_plan_scenario',{operations:[ops[1]]}));
  assert.doesNotThrow(()=>validateRequest(m,'manager_plan_scenario',{operations:[Object.fromEntries(Object.entries(ops[1]).reverse())]}));
  assert.throws(()=>validateRequest(m,'manager_plan_scenario',{operations:[{...ops[1],salary:2000}]}));
 });
 function office(){const players=[{id:'p1',pos:'Pilier'},{id:'p2',pos:'Pilier'}],S={season:1,club:0,round:0,history:[],clubs:[{id:0,players}]};const c=vm.createContext({S,slotEligible:(_p,s)=>[0,2].includes(s),benchEligible:(_p,s)=>s===1});vm.runInContext('domain=('+factory.toString()+')()',c);return {S,domain:c.domain};}
 test('intentions bornées : doublons, contexte et schéma refusés sans mutation',()=>{
  const {S,domain:d}=office(),context={season:1,week:0,club:0};
  const send=(command,payload)=>d.execute(command,{context,...payload});
  send('manager_plan_lineup',{fixtureId:'f0',slot:0,playerId:'p1'});const saved=JSON.stringify(S);
  assert.throws(()=>send('manager_plan_lineup',{fixtureId:'f0',slot:2,playerId:'p1'}));assert.throws(()=>send('manager_plan_lineup',{fixtureId:'f0',slot:1,playerId:'p2'}));assert.equal(JSON.stringify(S),saved);
  assert.throws(()=>d.execute('manager_plan_goal',{context:{...context,week:1},metric:'lineouts',target:80}));
  assert.throws(()=>send('manager_plan_scenario',{operations:[{kind:'recruit',playerId:'free',years:2,salary:-1,fee:0}]}));assert.equal(JSON.stringify(S),saved);
  send('manager_plan_goal',{metric:'lineouts',target:80});assert.equal(S.managerPlanning.goal.metric,'lineouts');d.validate(S);
  const hostile=JSON.parse(JSON.stringify(S));hostile.managerPlanning.goal.extra='x';assert.throws(()=>d.validate(hostile));
 });
}
