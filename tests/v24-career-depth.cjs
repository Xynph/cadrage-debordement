'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const years=[3,5,10];
function caseTraining(yearCount,fatigue){
 const g=context();g.run('start(0)');
 g.ctx.__years=yearCount;g.ctx.__fatigue=fatigue;
 const out=g.run(`(()=>{
   const p=club().players[0];
   ensureDevelopment(p);
   p.age=19;p.rating=50;p.dev.potential=98;p.dev.xp=0;
   p.dev.specialization={version:1,focus:'equilibre',xp:0,bonuses:{}};
   p.condition=100;p.physicalLoad={version:1,fatigue:__fatigue,plan:'normal'};
   for(let year=0;year<__years;year++){
     for(let week=0;week<28;week++)developmentTraining(p,'normal',S.club);
     p.age++;
   }
   return JSON.stringify({rating:p.rating,xp:p.dev.xp,age:p.age,physical:p.physicalLoad.fatigue});
 })()`);
 return JSON.parse(out);
}
for(const year of years){
 const fresh=caseTraining(year,0),fatigued=caseTraining(year,80);
 assert.equal(fresh.age,19+year);
 assert.equal(fatigued.age,fresh.age);
 assert.equal(fatigued.physical,80);
 const xp=p=>p.rating+p.xp;
 assert.ok(xp(fresh)>xp(fatigued)+0.2,`${year} years: accumulated load must reduce balanced progress`);
 console.log('V24 PASS '+year+' annual training cycles: balanced progression '+xp(fresh).toFixed(3)+' vs high-load '+xp(fatigued).toFixed(3));
}
{
 const g=context();g.run('start(0)');
 const legacy=g.run(`(()=>{
 const p=club().players[0];delete p.physicalLoad;
 return JSON.stringify({factor:growthFitnessFactor(p),hadField:Object.prototype.hasOwnProperty.call(p,'physicalLoad')});
 })()`);
 const v=JSON.parse(legacy);
 assert.equal(v.factor,1);assert.equal(v.hadField,false);
 console.log('V24 PASS old saves: physicalLoad absent remains absent after read-only factor');
}
console.log('V24 CAREER DEPTH 4/4 PASS; scenarios are controlled 3/5/10-year training cycles, not full fixture calendars');
