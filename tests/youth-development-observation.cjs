'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {context}=require('./harness.cjs');
function setup(){const file=path.join(__dirname,'../native/engine/youth-development.cjs');assert.ok(fs.existsSync(file),'native youth observation factory must exist');const {factory}=require(file),h=context();h.run('start(0);var CDYouthDevelopment=('+factory.toString()+')();var p=S.development.academy.find(p=>p.fam===0);p.age=19;p.dev.potential=94');return h;}

test('projection is pure and activation starts a real baseline without reconstructing past growth',()=>{
 const h=setup(),r=h.run,old=r('JSON.stringify(S)');r('CDYouthDevelopment.project(S);CDYouthDevelopment.validate(S)');assert.equal(r('JSON.stringify(S)'),old);
 r('p.rating+=2;CDYouthDevelopment.enable(S)');const rating=r('p.rating');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).baseline.rating'),rating);
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).deltas.rating'),0);
 const before=r('JSON.stringify(S)');r('CDYouthDevelopment.project(S);CDYouthDevelopment.validate(S)');assert.equal(r('JSON.stringify(S)'),before);
});

test('observation records actual attribute changes once and gives no growth itself',()=>{
 const h=setup(),r=h.run;r('CDYouthDevelopment.enable(S);var initial=p.rating;growPlayer(p,1.2);var earned=JSON.stringify(p)');
 assert.ok(r('CDYouthDevelopment.observe(S,"trainWeek")')>0);assert.equal(r('JSON.stringify(p)'),r('earned'));
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).deltas.rating'),r('p.rating-initial'));
 assert.ok(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).deltas.attributes.scrum')>0);
 const snapshot=r('JSON.stringify(S)');assert.equal(r('CDYouthDevelopment.observe(S,"trainWeek")'),0);assert.equal(r('JSON.stringify(S)'),snapshot);
});

test('promotion and annual rollover preserve the baseline and real lifetime minutes',()=>{
 const h=setup(),r=h.run;r('CDYouthDevelopment.enable(S);var id=p.id;var baseline=JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===id).baseline);promoteYouth(id);CDYouthDevelopment.observe(S,"promoteYouth");var match={pair:[S.club,1],developmentFocusVersion:1,sheets:[{used:[id],minutes:{[id]:30}},{used:[],minutes:{}}]};recordDevelopmentMatch(match);recordDevelopmentMatch(match);CDYouthDevelopment.observe(S,"recordDevelopmentMatch")');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===id).deltas.minutes'),30);
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===id).stage'),'professional');
 r('rollDevelopmentYear();CDYouthDevelopment.observe(S,"rollDevelopmentYear");S.season++;S.round=0;CDYouthDevelopment.observe(S,"advanceSeason");CDYouthDevelopment.validate(S)');
 assert.equal(r('JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===id).baseline)'),r('baseline'));
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===id).deltas.minutes'),30);
});

test('observations and serialization stay bounded and forged numeric baselines are rejected',()=>{
 const h=setup(),r=h.run;r('CDYouthDevelopment.enable(S);for(let i=0;i<12;i++){growPlayer(p,.2);CDYouthDevelopment.observe(S,"trainWeek")}CDYouthDevelopment.validate(S)');
 assert.ok(r('S.youthDevelopment.rows.find(x=>x.id===p.id).observations.length')<=6);
 const state=JSON.parse(r('JSON.stringify(S)')),reload=context(state);reload.run('var CDYouthDevelopment=('+require('../native/engine/youth-development.cjs').factory.toString()+')();CDYouthDevelopment.validate(S)');assert.equal(reload.run('JSON.stringify(S)'),JSON.stringify(state));
 for(const change of ['baseline.attributes.scrum=NaN','baseline.rating=999','baseline.season=S.season+1']){
  r('var original=JSON.stringify(S.youthDevelopment);var row=S.youthDevelopment.rows.find(x=>x.id===p.id);row.'+change);assert.throws(()=>r('CDYouthDevelopment.validate(S)'));r('S.youthDevelopment=JSON.parse(original)');
 }
});

test('import rejects a tracked focus outside the actual player role and a baseline before activation',()=>{
 const h=setup(),r=h.run;r('S.round=5;CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"specialist","scrum");var row=S.youthDevelopment.rows.find(x=>x.id===p.id);var original=JSON.stringify(S.youthDevelopment);row.focus="goal"');
 assert.throws(()=>r('CDYouthDevelopment.validate(S)'));
 r('S.youthDevelopment=JSON.parse(original);S.youthDevelopment.rows.find(x=>x.id===p.id).baseline.week=0');
 assert.throws(()=>r('CDYouthDevelopment.validate(S)'));
});

test('mobility does not apply a former-club plan or reveal transferred players',()=>{
 const h=setup(),r=h.run;r('CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"integration","scrum");var id=p.id;S.development.academy=S.development.academy.filter(x=>x.id!==id);p.academy=false;S.clubs[1].players.push(p);CDYouthDevelopment.observe(S,"managerMobilityOnSeasonStart");CDYouthDevelopment.validate(S)');
 assert.equal(r('CDYouthDevelopment.project(S).players.some(x=>x.id===id)'),false);
 assert.equal(r('CDYouthDevelopment.growthShare(S,p,true)'),null);
 r('S.club=1;CDYouthDevelopment.observe(S,"managerMobilityOnSeasonStart");CDYouthDevelopment.validate(S)');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===id).tracked'),true);
 assert.equal(r('CDYouthDevelopment.growthShare(S,p,true)'),null,'old club plan requires a fresh local decision');
});

test('chosen plans have distinct measurable steps and integration counts new real minutes only',()=>{
 const h=setup(),r=h.run;r('p.dev.careerMinutes=600;promoteYouth(p.id);CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"general",null)');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).nextSteps.some(x=>x.key==="generalProgress")'),true);
 r('CDYouthDevelopment.setPlan(S,p.id,"specialist","scrum")');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).nextSteps.some(x=>x.key==="qualityProgress")'),true);
 r('CDYouthDevelopment.setPlan(S,p.id,"integration","scrum")');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).nextSteps.find(x=>x.key==="minutes").done'),false);
 r('p.dev.careerMinutes+=240');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).nextSteps.find(x=>x.key==="minutes").done'),true);
});

test('a professional with no baseline never gets invented zero minutes since a reference',()=>{
 const h=setup(),r=h.run;r('promoteYouth(p.id);p.dev.careerMinutes=600');
 const detail=r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).nextSteps.find(x=>x.key==="minutes").detail');
 assert.match(detail,/référence.*suivi|suivi.*référence/i);
 assert.doesNotMatch(detail,/^0 minutes/);
});
