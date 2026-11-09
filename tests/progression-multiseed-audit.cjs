'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const A=require('../ci/progression-multiseed-audit.cjs');
const clone=x=>JSON.parse(JSON.stringify(x)),digest='a'.repeat(64);
function complete(){return {schema:'progression-multiseed-audit-v1',status:'completed',passed:true,seed:827381,policy:{id:'minimal',hash:digest},sources:{commit:'b'.repeat(40),digest,runnerHash:digest,policiesHash:digest},initialHash:digest,initialProfileHash:digest,requestedSeasons:2,completedSeasons:2,observations:['initial','end-S1','opening-S2','end-S2','opening-S3'].map((label,i)=>({label,season:[1,1,2,2,3][i]})),annual:[1,2].map(season=>({season,fixtures:791,results:791,closingLabel:'end-S'+season,transitionLabel:'opening-S'+(season+1)})),financialPeriods:[1,2].map(season=>({season,cashOpening:10,cashClosing:8,cashAfterManagement:8,cashAfterTransition:12,minCash:8,categories:{wages:-2,financing:4},unexplainedCash:0,negativeWeeks:0,longestNegativeStreak:0})),reopened:true,restarts:['end-S1','end-S2','opening-S3'].map(label=>({label,publicExact:true,privateExact:true,stateHash:digest,profileHash:digest}))};}
test('Incomplete seasons, mixed method receipts and false reopening cannot pass as complete',()=>{
 a.equal(A.validateReport(complete()),true);
 const mutations=[r=>r.completedSeasons=1,r=>r.annual[1].results--,r=>r.observations.pop(),r=>r.restarts[1].privateExact=false,r=>r.policy.hash='c'.repeat(64),r=>r.financialPeriods[0].cashAfterTransition=100];
 for(const mutate of mutations){const r=complete();mutate(r);a.throws(()=>A.validateReport(r));}
});
test('Ledger prefix accounting preserves repeated entries and keeps unknown cash distinct',()=>{
 const same={title:'Salaires',amount:-100},bonus={title:'Prime de victoire',amount:80},before=[same,bonus,same],after=[same,same,bonus];
 a.deepEqual(A.ledgerDelta(before,after),[same]);a.deepEqual(A.ledgerDelta(before,before),[]);a.equal(A.category('Financement de début de saison'),'financing');a.equal(A.category('Signature : joueur'),'contractFees');a.equal(A.category('Opération non décrite'),'other');a.equal(A.category('Entretien des installations'),'maintenance');
 const r=complete();r.financialPeriods[0].categories.financing=1;r.financialPeriods[0].unexplainedCash=3;a.equal(A.validateReport(r),true,'unexplained amount remains visible rather than fabricated ledger revenue');
});
test('Policies cannot receive export state or mutate their model; unsafe actions rejected',()=>{
 const source={meta:{exportText:'hidden state',season:1},squad:[{id:'x'}]},m=A.publicModel(source);a.equal(m.meta.exportText,undefined);a.equal(source.meta.exportText,'hidden state');a.throws(()=>{m.squad[0].id='changed';},TypeError);
 a.throws(()=>A.validateAction({command:'import',payload:{text:'fake'},reason:'inject'},['auto_lineup']));a.equal(A.validateAction({command:'auto_lineup',payload:{},reason:'visible decision'},['auto_lineup']).command,'auto_lineup');
});
test('Fixed cohorts retain departures, unknowns and initial age bands without survivor imputation',()=>{
 const baseline=[{id:'own',age:23,rating:70},{id:'other',age:29,rating:75},{id:'retired',age:36,rating:80},{id:'gone',age:25,rating:60}],s={club:0,clubs:[{id:0,players:[{id:'own',age:24,rating:72}]},{id:1,players:[{id:'other',age:30,rating:74}]}],development:{retired:[{id:'retired',age:37}]},economy:{freeAgents:[]},market:[]};
 const before=clone(s),r=A.cohortRecords(s,baseline);a.deepEqual(s,before);a.deepEqual(r.map(p=>p.status),['own','other-professional','retired','untracked']);a.deepEqual(r.map(p=>p.initialAgeBand),['<=23','24-29','>=30','24-29']);a.equal(r[3].rating,null);a.equal(r[2].rating,null);
});
test('Experiment arguments enforce preregistered pair design and report raw quantiles',()=>{
 a.equal(A.argumentsFor(['--seed','318','--policy','attentive','--out','/tmp/cd-progression-protocol-unused.json']).seasons,2);
 a.throws(()=>A.argumentsFor(['--seed','123','--policy','minimal','--out','/tmp/cd-progression-protocol-unused.json']));a.throws(()=>A.argumentsFor(['--seed','318','--policy','minimal','--seasons','1','--out','/tmp/cd-progression-protocol-unused.json']));a.deepEqual(A.quantiles([80,60,70]),{n:3,q25:60,median:70,q75:80});a.equal(A.quantiles([]).median,null);
});
