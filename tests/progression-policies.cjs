'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {profiles,createPolicy,commands,sourceHash}=require('../ci/progression-policies.cjs');
const copy=x=>JSON.parse(JSON.stringify(x));
const freeze=x=>{if(x&&typeof x==='object'){for(const v of Object.values(x))freeze(v);Object.freeze(x);}return x;};
test('Le renouvellement utilise les niveaux et fourchettes visibles sans lire le potentiel exact',()=>{
 const candidate=(id,min)=>({id,age:24,rating:80,potentialRange:{min,max:min+4},knowledge:{owned:true},salary:2000,contractEnd:1,
  renewal:{available:true,salary:2200,fee:5000,minYears:1,maxYears:3}});
 const squad=[candidate('a',82),candidate('b',84)];
 for(const p of squad)for(const field of ['potential','note','hiddenTraitsV2'])Object.defineProperty(p,field,{get(){throw Error('Non-displayed quality read: '+field);}});
 const model=freeze({meta:{hasCareer:true,season:1,week:0},club:{cash:5000000},finance:{wage:4000},squad,live:null});
 const request=createPolicy('attentive').nextAction(model,'before-week');
 assert.equal(request?.payload.playerId,'b','equal levels use the conservative visible potential bound');
 assert.equal(request.evidence.rating,80);assert.deepEqual(request.evidence.potentialRange,{min:84,max:88});
});
function worker(root,name){
 const bridge=createBridge({dataDir:path.join(root,name),seed:827381,now:1794178800000});let serial=0;
 const raw=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const good=(command,payload={})=>{const reply=raw(command,payload);assert.equal(reply.ok,true,reply.error);return reply.model;};
 return {bridge,raw,good};
}
function applyPhase(worker,controller,model,phase){
 let count=0;
 while(true){
  const before=JSON.stringify(model),request=controller.nextAction(model,phase);
  assert.equal(JSON.stringify(model),before,'planning never mutates the visible model');
  if(!request)break;
  assert(++count<=controller.profile.maxActionsPerPhase,'finite phase');
  assert(commands.includes(request.command));
  const reply=worker.raw(request.command,request.payload),outcome=controller.observe(request,reply);
  assert.equal(outcome.critical,false,reply.error);assert.equal(reply.ok,true);
  model=reply.model;
 }
 return model;
}

test('Deux bras réels commencent identiques et le renouvellement exerce un traitement signé et payé',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-policy-smoke-'));
 let a,b;
 try{
  a=worker(root,'minimal');b=worker(root,'attentive');
  const initialA=settleClubMeetings(a.good('new_career',{mode:'world',club:0}),(command,payload)=>a.good(command,payload)),initialB=settleClubMeetings(b.good('new_career',{mode:'world',club:0}),(command,payload)=>b.good(command,payload));
  assert.deepEqual(JSON.parse(a.good('export').meta.exportText).state,JSON.parse(b.good('export').meta.exportText).state,'paired initial states');
  const minimal=createPolicy('minimal'),attentive=createPolicy('attentive');
  const aModel=applyPhase(a,minimal,initialA,'before-week');
  const bModel=applyPhase(b,attentive,initialB,'before-week');
  const trace=attentive.summary();
  assert(trace.signed>0,'the treatment must actually sign renewals');assert(trace.signed<=6);
  assert.equal(trace.blocked,false);assert.equal(minimal.summary().signed,0);
  assert.equal(initialB.club.cash-bModel.club.cash,trace.actualFees,'fees actually paid through public commands');
  assert(trace.events.some(e=>e.command==='extend_contract'));
  for(const event of trace.events.filter(e=>e.outcome==='signed')){
   const p=bModel.squad.find(p=>p.id===event.payload.playerId),old=initialB.squad.find(q=>q.id===event.payload.playerId);
   assert(p.contractEnd>old.contractEnd);assert.equal(event.actualFee,event.returnedFee);
   assert(event.evidence.cash-event.evidence.fee>=event.evidence.reserve);
  }
  assert.equal(aModel.squad.length,bModel.squad.length);assert.equal(aModel.meta.week,bModel.meta.week);
  const preparedA=applyPhase(a,minimal,aModel,'before-match'),preparedB=applyPhase(b,attentive,bModel,'before-match');
  assert.equal(preparedA.selection.valid,true);assert.equal(preparedB.selection.valid,true);
  assert.deepEqual(preparedA.lineup,preparedB.lineup,'the initial comparison does not manufacture a bad minimal lineup');
  assert.equal(attentive.nextAction(preparedB,'before-week'),null,'no repeat spending on same candidates');
  assert.match(sourceHash,/^[a-f0-9]{64}$/);
  console.log(JSON.stringify({policySmoke:true,signed:trace.signed,candidates:trace.candidatesBySeason,fees:trace.actualFees,counters:trace.events.filter(e=>e.outcome==='counter').length}));
 }finally{a?.bridge.close();b?.bridge.close();fs.rmSync(root,{recursive:true,force:true});}
});

test('Le contrôleur est déterministe sur modèle visible, borné et prudent, sans accès à des traits cachés',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-policy-input-'));let w;
 try{
  w=worker(root,'public');const model=settleClubMeetings(w.good('new_career',{mode:'world',club:0}),(command,payload)=>w.good(command,payload));
  const first=createPolicy('attentive'),second=createPolicy('attentive'),before=JSON.stringify(model);
  for(const p of model.squad)Object.defineProperty(p,'hiddenTraitsV2',{get(){throw Error('Hidden trait access forbidden');}});
  const request=first.nextAction(freeze(model),'before-week');assert(request);
  assert.deepEqual(request,second.nextAction(model,'before-week'));assert.equal(JSON.stringify(model),before);
  assert.equal(first.nextAction(model,'before-week'),null,'observe required before another request');
  assert.throws(()=>first.observe({...request,payload:{}},{ok:true,model}),/match/);
  assert.equal(first.observe(request,{ok:false,error:'Écriture de sauvegarde impossible',model}).critical,true);
  assert.equal(first.nextAction(model,'before-week'),null,'a real API failure blocks this controller');
  const poor=copy(model);poor.club.cash=0;
  assert.equal(createPolicy('attentive').nextAction(poor,'before-week'),null);
  assert.equal(createPolicy('minimal').nextAction(model,'before-week'),null);
  assert.equal(createPolicy('attentive').nextAction(model,'transition'),null);
  assert.throws(()=>createPolicy('optimal'),RangeError);
  assert.throws(()=>createPolicy('minimal').nextAction(model,'unknown'),RangeError);
  assert.deepEqual(profiles.map(p=>p.id),['minimal','attentive']);
 }finally{w?.bridge.close();fs.rmSync(root,{recursive:true,force:true});}
});

test('Une contre-proposition du vrai worker est observable et acceptée au plus une fois',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-policy-counter-'));let w;
 try{
  w=worker(root,'counter');const actual=settleClubMeetings(w.good('new_career',{mode:'world',club:0}),(command,payload)=>w.good(command,payload)),displayed=copy(actual);
  // Fault fixture: a stale displayed asking price. No worker state is edited.
  // This forces the real negotiation controller to publish its counteroffer.
  const candidate=displayed.squad.find(p=>p.age<=30&&p.contractEnd<=displayed.meta.season&&p.renewal.available&&p.salary>1000);
  assert(candidate);for(const p of displayed.squad)p.renewal.available=p.id===candidate.id;
  candidate.renewal.salary=1000;
  const controller=createPolicy('attentive'),offer=controller.nextAction(displayed,'before-week');assert(offer);
  const first=w.raw(offer.command,offer.payload);assert.equal(first.ok,true,first.error);
  assert.equal(first.model.meta.negotiation.status,'counter');
  assert.equal(controller.observe(offer,first).expectedRefusal,true);
  const response=controller.nextAction(first.model,'before-week');
  assert.equal(response.evidence.kind,'counter');assert.equal(response.payload.salary,first.model.meta.negotiation.salary);
  assert.equal(controller.nextAction(first.model,'before-week'),null);
  const second=w.raw(response.command,response.payload);assert.equal(second.ok,true,second.error);
  assert.equal(second.model.meta.negotiation.status,'signed');controller.observe(response,second);
  assert.equal(controller.summary().events.filter(e=>e.payload?.playerId===candidate.id).length,2);
 }finally{w?.bridge.close();fs.rmSync(root,{recursive:true,force:true});}
});
