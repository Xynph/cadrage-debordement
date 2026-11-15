'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {engineContext:context}=require('./harness.cjs');
const {annualWorldDataContext}=require('./helpers/gestion-domaines.cjs');
const activeCases=new Set();require('node:test').afterEach(()=>{for(const h of activeCases)h.close();activeCases.clear();});
function setup(data=true,prepareWorld=null){const file=path.join(__dirname,'../native/engine/youth-development.cjs');assert.ok(fs.existsSync(file),'native youth observation factory must exist');const {factory}=require(file),h=data?annualWorldDataContext(0,{prepareWorld}):context();if(!data)h.start(0);h.run('var youthObserver=('+factory.toString()+')();var p=S.development.academy.find(p=>p.fam===0'+(data?'':'&&p.age>=18')+');p.age=19;p.dev.potential=94');activeCases.add(h);return h;}

test('projection is pure and activation starts a real baseline without reconstructing past growth',()=>{
 const h=setup(),r=h.run,old=r('JSON.stringify(S)');r('youthObserver.project(S);youthObserver.validate(S)');assert.ok(r('JSON.stringify(S)')===old);
 r('p.rating+=2;youthObserver.enable(S)');const rating=r('p.rating');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).baseline.rating'),rating);
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).deltas.rating'),0);
 const before=r('JSON.stringify(S)');r('youthObserver.project(S);youthObserver.validate(S)');assert.ok(r('JSON.stringify(S)')===before);
});

test('observation records actual attribute changes once and gives no growth itself',()=>{
 const h=setup(),r=h.run;r('youthObserver.enable(S);var initial=p.rating;growPlayer(p,1.2);var earned=JSON.stringify(p)');
 assert.ok(r('youthObserver.observe(S,"trainWeek")')>0);assert.equal(r('JSON.stringify(p)'),r('earned'));
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).deltas.rating'),r('p.rating-initial'));
 assert.ok(r('youthObserver.project(S).players.find(x=>x.id===p.id).deltas.attributes.scrum')>0);
 const snapshot=r('JSON.stringify(S)');assert.equal(r('youthObserver.observe(S,"trainWeek")'),0);assert.ok(r('JSON.stringify(S)')===snapshot);
});

test('promotion and annual data rollover preserve the baseline and observed lifetime minutes',()=>{
 const {factory}=require('../native/engine/youth-development.cjs');
 const h=annualWorldDataContext(0,{prepareWorld:g=>g.run('var youthObserver=('+factory.toString()+')();var p=S.development.academy.find(p=>p.fam===0&&p.age>=18),trackedYouthId=p.id;youthObserver.enable(S);var baseline=JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===p.id).baseline);promoteYouth(p.id);youthObserver.observe(S,"promoteYouth");var match={pair:[S.club,1],developmentFocusVersion:1,sheets:[{used:[p.id],minutes:{[p.id]:30}},{used:[],minutes:{}}]};recordDevelopmentMatch(match);recordDevelopmentMatch(match);youthObserver.observe(S,"recordDevelopmentMatch")')}),r=h.run;
 r('var p=club().players.find(p=>p.id===trackedYouthId),id=p.id');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===id).deltas.minutes'),30);
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===id).stage'),'professional');
 r('rollDevelopmentYear();youthObserver.observe(S,"rollDevelopmentYear");S.season++;S.round=0;youthObserver.observe(S,"advanceSeason");youthObserver.validate(S)');
 assert.equal(r('JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===id).baseline)'),r('baseline'));
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===id).deltas.minutes'),30);h.close();
});

test('observations and serialization stay bounded and forged numeric baselines are rejected',()=>{
 const h=setup(),r=h.run;r('youthObserver.enable(S);for(let i=0;i<12;i++){growPlayer(p,.2);youthObserver.observe(S,"trainWeek")}youthObserver.validate(S)');
 assert.ok(r('S.youthDevelopment.rows.find(x=>x.id===p.id).observations.length')<=6);
 const state=JSON.parse(r('JSON.stringify(S)')),reload=annualWorldDataContext();reload.ctx.observationFixture=JSON.stringify(state);reload.run('S=JSON.parse(observationFixture);var youthObserver=('+require('../native/engine/youth-development.cjs').factory.toString()+')();youthObserver.validate(S)');assert.ok(reload.run('JSON.stringify(S)')===JSON.stringify(state));reload.close();
 for(const change of ['baseline.attributes.scrum=NaN','baseline.rating=999','baseline.season=S.season+1']){
  r('var original=JSON.stringify(S.youthDevelopment);var row=S.youthDevelopment.rows.find(x=>x.id===p.id);row.'+change);assert.throws(()=>r('youthObserver.validate(S)'));r('S.youthDevelopment=JSON.parse(original)');
 }
});

test('import rejects a tracked focus outside the actual player role and a baseline before activation',()=>{
 const h=setup(true,g=>{g.deferSaves();g.week(5)}),r=h.run;r('youthObserver.enable(S);youthObserver.setPlan(S,p.id,"specialist","scrum");var row=S.youthDevelopment.rows.find(x=>x.id===p.id);var original=JSON.stringify(S.youthDevelopment);row.focus="goal"');
 assert.throws(()=>r('youthObserver.validate(S)'));
 r('S.youthDevelopment=JSON.parse(original);S.youthDevelopment.rows.find(x=>x.id===p.id).baseline.week=0');
 assert.throws(()=>r('youthObserver.validate(S)'));
});

test('mobility does not apply a former-club plan or reveal transferred players',()=>{
 const h=setup(),r=h.run;r('youthObserver.enable(S);youthObserver.setPlan(S,p.id,"integration","scrum");var id=p.id;S.development.academy=S.development.academy.filter(x=>x.id!==id);p.academy=false;S.clubs[1].players.push(p);youthObserver.observe(S,"managerMobilityOnSeasonStart");youthObserver.validate(S)');
 assert.equal(r('youthObserver.project(S).players.some(x=>x.id===id)'),false);
 assert.equal(r('youthObserver.growthShare(S,p,true)'),null);
 r('S.club=1;youthObserver.observe(S,"managerMobilityOnSeasonStart");youthObserver.validate(S)');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===id).tracked'),true);
 assert.equal(r('youthObserver.growthShare(S,p,true)'),null,'old club plan requires a fresh local decision');
});

test('chosen plans have distinct measurable steps and integration counts new real minutes only',()=>{
 const h=setup(false),r=h.run;r('p.dev.careerMinutes=600;promoteYouth(p.id);youthObserver.enable(S);youthObserver.setPlan(S,p.id,"general",null)');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).nextSteps.some(x=>x.key==="generalProgress")'),true);
 r('youthObserver.setPlan(S,p.id,"specialist","scrum")');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).nextSteps.some(x=>x.key==="qualityProgress")'),true);
 r('youthObserver.setPlan(S,p.id,"integration","scrum")');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).nextSteps.find(x=>x.key==="minutes").done'),false);
 r('p.dev.careerMinutes+=240');
 assert.equal(r('youthObserver.project(S).players.find(x=>x.id===p.id).nextSteps.find(x=>x.key==="minutes").done'),true);
});

test('a professional with no baseline never gets invented zero minutes since a reference',()=>{
 const h=setup(false),r=h.run;r('promoteYouth(p.id);p.dev.careerMinutes=600');
 const detail=r('youthObserver.project(S).players.find(x=>x.id===p.id).nextSteps.find(x=>x.key==="minutes").detail');
 assert.match(detail,/référence.*suivi|suivi.*référence/i);
 assert.doesNotMatch(detail,/^0 minutes/);
});
