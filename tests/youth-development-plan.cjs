'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,a+' != '+b);

test('integration allocates one existing XP budget rather than duplicating growth',()=>{
 const h=context(),r=h.run;r('start(0);var p=S.development.academy.find(p=>p.fam===0);p.age=19;p.rating=60;p.skillBase=60;p.dev.potential=94;p.dev.xp=0;ensureSpecialization(p).focus="scrum";var CDYouthDevelopment={growthShare:()=>.25};growPlayer(p,.4)');
 near(r('p.dev.xp'),.3);near(r('p.dev.specialization.xp'),.1);
 near(r('p.dev.xp+p.dev.specialization.xp'),.4);
});

function prepared(){
 const fs=require('node:fs'),path=require('node:path'),file=path.join(__dirname,'../native/engine/youth-development.cjs');
 assert.equal(fs.existsSync(file),true,'native youth-development factory must exist');
 const {factory}=require(file),h=context(),r=h.run;
 r('start(0);var p=S.development.academy.find(p=>p.fam===0);p.age=19;p.rating=60;p.skillBase=60;p.dev.potential=94;p.dev.xp=0;');
 r('var CDYouthDevelopment=('+factory.toString()+')();');return h;
}
test('three real plans conserve the XP budget and never reward choosing or reading a plan',()=>{
 for(const [plan,general,target]of [['general',.4,0],['specialist',.2,.2],['integration',.3,.1]]){
  const h=prepared(),r=h.run;r('CDYouthDevelopment.enable(S)');
  const rating=r('p.rating'),cash=r('club().cash');
  r('CDYouthDevelopment.setPlan(S,p.id,'+JSON.stringify(plan)+','+(plan==='general'?'null':'"scrum"')+')');
  assert.equal(r('p.rating'),rating);assert.equal(r('club().cash'),cash);
  const snapshot=r('JSON.stringify(S)');r('CDYouthDevelopment.project(S);CDYouthDevelopment.project(S)');assert.equal(r('JSON.stringify(S)'),snapshot);
  r('growPlayer(p,.4)');near(r('p.dev.xp'),general);near(r('p.dev.specialization?.xp||0'),target);
  near(r('p.dev.xp+(p.dev.specialization?.xp||0)'),.4);
 }
});

test('plan revision preserves earned skills and respects the existing V29 partial-XP rule',()=>{
 const h=prepared(),r=h.run;r('CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"specialist","scrum");growPlayer(p,1.2);var earned=focusedBonus(p,"scrum"),general=p.dev.xp;CDYouthDevelopment.setPlan(S,p.id,"integration","scrum")');
 assert.equal(r('focusedBonus(p,"scrum")'),r('earned'));near(r('p.dev.xp'),r('general'));
 const baseline=r('JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===p.id).baseline)');
 r('CDYouthDevelopment.setPlan(S,p.id,"specialist","power")');near(r('p.dev.specialization.xp'),0);
 assert.equal(r('JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===p.id).baseline)'),baseline);
 assert.throws(()=>r('CDYouthDevelopment.setPlan(S,p.id,"specialist","goal")'));
 r('S.trained=true');assert.throws(()=>r('CDYouthDevelopment.setPlan(S,p.id,"general",null)'));
});

test('public potential uses the existing role estimate and never adds a raw ceiling',()=>{
 const h=prepared(),r=h.run;r('for(const k of Object.keys(p.skills))p.skills[k]=55;CDYouthDevelopment.enable(S);var expected=potentialAtRole(JSON.parse(JSON.stringify(p)))');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).potential'),r('expected'));
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).potentialBasis'),'role-estimate');
});

test('without an explicit plan the legacy growth trace and RNG stay exactly unchanged',()=>{
 const a=prepared(),b=prepared();a.run('CDYouthDevelopment=undefined');
 for(const h of [a,b])h.run('ensureSpecialization(p).focus="scrum";for(let i=0;i<12;i++)developmentTraining(p,"normal");growPlayer(p,.4,false)');
 assert.equal(a.run('JSON.stringify(S)'),b.run('JSON.stringify(S)'));
 assert.equal(a.run('Math.random()'),b.run('Math.random()'));
});

test('plans preserve the existing injury, load, potential and attribute ceilings',()=>{
 const h=prepared(),r=h.run;r('CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"integration","scrum");var rested=JSON.parse(JSON.stringify(p)),tired=JSON.parse(JSON.stringify(p)),injured=JSON.parse(JSON.stringify(p));rested.physicalLoad={version:1,plan:"normal",fatigue:0};tired.physicalLoad={version:1,plan:"normal",fatigue:90};injured.injury=2;developmentTraining(rested,"normal");developmentTraining(tired,"normal");developmentTraining(injured,"normal")');
 assert.ok(r('rested.dev.xp+rested.dev.specialization.xp')>r('tired.dev.xp+tired.dev.specialization.xp'));
 assert.equal(r('injured.dev.xp+injured.dev.specialization.xp'),0);
 r('growPlayer(p,100)');assert.equal(r('p.rating'),r('p.dev.potential'));
 assert.ok(r('focusedBonusTotal(p.dev.specialization)')<=8);assert.ok(r('focusedBonus(p,"scrum")')<=4);
 assert.equal(r('p.dev.xp+p.dev.specialization.xp'),0);
});

test('official annual profiles expose real activity and reject a specialist with no effect',()=>{
 const h=require('./france-harness.cjs').context(),r=h.run;
 r('var CDCommonCareer=('+require('../native/engine/common-rosters.cjs').toString()+')();CDCommonCareer.start(0);var CDYouthDevelopment=('+require('../native/engine/youth-development.cjs').factory.toString()+')();var p=club().players.find(p=>p.lnrRatingsVersion===1&&p.age<=23);CDYouthDevelopment.enable(S)');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).model'),'annual-v11');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).availablePlans.includes("specialist")'),false);
 assert.throws(()=>r('CDYouthDevelopment.setPlan(S,p.id,"specialist","scrum")'));
 r('CDYouthDevelopment.setPlan(S,p.id,"integration",null);var before=p.rating,skills=JSON.stringify(p.skills);growPlayer(p,.4)');
 assert.equal(r('p.rating'),r('before'));assert.equal(r('JSON.stringify(p.skills)'),r('skills'));
 assert.equal(r('CDYouthDevelopment.growthShare(S,p,true)'),null);
 r('ageDevelopmentPlayer(p);CDYouthDevelopment.observe(S,"rollDevelopmentYear");CDYouthDevelopment.validate(S)');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).current.age'),r('p.age'));
});
