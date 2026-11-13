'use strict';
// Plans de développement des jeunes (domaine natif youthDevelopment) en carrière Monde (world-champ).
const {test,after}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,a+' != '+b);
// Une seule carrière Monde ; chaque cas repart du même point (état et RNG).
const h=context(),base=h.checkpoint();
after(()=>h.close());
function prepared(){
 h.restore(base);
 h.run('var p=S.development.academy.find(p=>p.fam===0);p.age=19;p.rating=60;p.skillBase=60;p.dev.potential=94;p.dev.xp=0;');
 return h;
}

// Budget d'XP d'une croissance sans plan pour ce jeune : en carrière Monde, growPlayer applique les
// multiplicateurs du club (staff, installations), le plan ne fait que répartir ce budget.
function budget(amount){const r=prepared().run;r('growPlayer(p,'+amount+')');return r('p.dev.xp+(p.dev.specialization?.xp||0)');}

test('integration allocates one existing XP budget rather than duplicating growth',()=>{
 const total=budget(.4);assert.ok(total>0);
 const r=prepared().run;r('CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"integration","scrum");growPlayer(p,.4)');
 near(r('p.dev.xp'),total*.75);near(r('p.dev.specialization.xp'),total*.25);
 near(r('p.dev.xp+p.dev.specialization.xp'),total);
});

test('three real plans conserve the XP budget and never reward choosing or reading a plan',()=>{
 const total=budget(.4);
 for(const [plan,general,target]of [['general',.4,0],['specialist',.2,.2],['integration',.3,.1]]){
  const r=prepared().run;r('CDYouthDevelopment.enable(S)');
  const rating=r('p.rating'),cash=r('club().cash');
  r('CDYouthDevelopment.setPlan(S,p.id,'+JSON.stringify(plan)+','+(plan==='general'?'null':'"scrum"')+')');
  assert.equal(r('p.rating'),rating);assert.equal(r('club().cash'),cash);
  const snapshot=r('JSON.stringify(S)');r('CDYouthDevelopment.project(S);CDYouthDevelopment.project(S)');assert.equal(r('JSON.stringify(S)'),snapshot);
  r('growPlayer(p,.4)');near(r('p.dev.xp'),general/.4*total);near(r('p.dev.specialization?.xp||0'),target/.4*total);
  near(r('p.dev.xp+(p.dev.specialization?.xp||0)'),total);
 }
});

test('plan revision preserves earned skills and respects the existing V29 partial-XP rule',()=>{
 const r=prepared().run;r('CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"specialist","scrum");growPlayer(p,1.2);var earned=focusedBonus(p,"scrum"),general=p.dev.xp;CDYouthDevelopment.setPlan(S,p.id,"integration","scrum")');
 assert.equal(r('focusedBonus(p,"scrum")'),r('earned'));near(r('p.dev.xp'),r('general'));
 const baseline=r('JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===p.id).baseline)');
 r('CDYouthDevelopment.setPlan(S,p.id,"specialist","power")');near(r('p.dev.specialization.xp'),0);
 assert.equal(r('JSON.stringify(S.youthDevelopment.rows.find(x=>x.id===p.id).baseline)'),baseline);
 assert.throws(()=>r('CDYouthDevelopment.setPlan(S,p.id,"specialist","goal")'));
 r('S.trained=true');assert.throws(()=>r('CDYouthDevelopment.setPlan(S,p.id,"general",null)'));
});

test('public potential uses the existing role estimate and never adds a raw ceiling',()=>{
 const r=prepared().run;r('for(const k of Object.keys(p.skills))p.skills[k]=55;CDYouthDevelopment.enable(S);var expected=potentialAtRole(JSON.parse(JSON.stringify(p)))');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).potential'),r('expected'));
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).potentialBasis'),'role-estimate');
});

test('without an explicit plan the growth trace and RNG stay exactly unchanged',()=>{
 // Domaine non activé, puis activé sans plan pour ce jeune : même croissance, même RNG.
 const trace=enable=>{const r=prepared().run;if(enable)r('CDYouthDevelopment.enable(S)');r('ensureSpecialization(p).focus="scrum";for(let i=0;i<12;i++)developmentTraining(p,"normal");growPlayer(p,.4,false)');return {player:r('JSON.stringify(p)'),clubs:r('JSON.stringify(S.clubs)'),rng:r('Math.random()')};};
 assert.deepEqual(trace(true),trace(false));
});

test('plans preserve the existing injury, load, potential and attribute ceilings',()=>{
 const r=prepared().run;r('CDYouthDevelopment.enable(S);CDYouthDevelopment.setPlan(S,p.id,"integration","scrum");var rested=JSON.parse(JSON.stringify(p)),tired=JSON.parse(JSON.stringify(p)),injured=JSON.parse(JSON.stringify(p));rested.physicalLoad={version:1,plan:"normal",fatigue:0};tired.physicalLoad={version:1,plan:"normal",fatigue:90};injured.injury=2;developmentTraining(rested,"normal");developmentTraining(tired,"normal");developmentTraining(injured,"normal")');
 assert.ok(r('rested.dev.xp+rested.dev.specialization.xp')>r('tired.dev.xp+tired.dev.specialization.xp'));
 assert.equal(r('injured.dev.xp+injured.dev.specialization.xp'),0);
 r('growPlayer(p,100)');assert.equal(r('p.rating'),r('p.dev.potential'));
 assert.ok(r('focusedBonusTotal(p.dev.specialization)')<=8);assert.ok(r('focusedBonus(p,"scrum")')<=4);
 assert.equal(r('p.dev.xp+p.dev.specialization.xp'),0);
});

// Moteur natif Monde : les profils officiels de l'édition progressent en cours de saison
// (nativeInSeasonDevelopment) ; le modèle annuel « annual-v11 » n'existe que hors moteur natif.
test('official edition profiles follow in-season growth and accept a specialist plan',()=>{
 h.restore(base);const r=h.run;
 r('var p=club().players.find(p=>p.lnrRatingsVersion===1&&p.age<=23);CDYouthDevelopment.enable(S)');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).model'),'xp');
 assert.equal(r('CDYouthDevelopment.project(S).players.find(x=>x.id===p.id).availablePlans.includes("specialist")'),true);
 r('CDYouthDevelopment.setPlan(S,p.id,"specialist",developmentFocusOptions(p).find(k=>["scrum","lineout","tackle","speed","pass","kick","goal","power","stamina","mental","discipline"].includes(k)));CDYouthDevelopment.validate(S)');
 assert.equal(r('S.youthDevelopment.rows.find(x=>x.id===p.id).plan'),'specialist');
});
