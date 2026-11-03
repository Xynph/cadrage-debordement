'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
function run({load=0,focused=false,injury=0,mode='normal',cycles=36,legacy=false,potential=98}={}){
 const g=context();g.run('start(0)');g.ctx.opts={load,focused,injury,mode,cycles,legacy,potential};
 return JSON.parse(g.run(`(()=>{
  const a=opts,p=club().players[0];ensureDevelopment(p);
  p.age=19;p.rating=50;p.dev.xp=0;p.dev.potential=a.potential;p.condition=100;p.injury=a.injury;
  if(a.legacy)delete p.physicalLoad;else p.physicalLoad={version:1,fatigue:a.load,plan:'normal'};
  const option=developmentFocusOptions(p).find(x=>x!=='equilibre');
  p.dev.specialization={version:1,focus:a.focused?option:'equilibre',xp:0,bonuses:{}};
  for(let i=0;i<a.cycles;i++)developmentTraining(p,a.mode,S.club);
  const s=p.dev.specialization;
  return JSON.stringify({rating:p.rating,xp:p.dev.xp,specialXp:s.xp,bonuses:Object.values(s.bonuses).reduce((a,b)=>a+b,0),hasLoad:Object.prototype.hasOwnProperty.call(p,'physicalLoad')});
 })()`));
}
const rating=r=>r.rating+r.xp;
let checks=0;
for(const cycles of [1,12,36,72]){
 const a=run({cycles}),b=run({cycles,load:80});
 assert.ok(rating(a)>rating(b),'balanced fatigue XP, sessions '+cycles);checks++;
}
for(const cycles of [12,36,72]){
 const a=run({cycles,focused:true}),b=run({cycles,focused:true,load:80});
 assert.ok(rating(a)>=rating(b),'focused general XP, sessions '+cycles);
 assert.ok(a.bonuses+a.specialXp>=b.bonuses+b.specialXp,'focused skill XP, sessions '+cycles);checks++;
}
for(const mode of ['normal','intense']){
 const a=run({injury:2,mode}),b=run({mode:'repos'});
 assert.equal(rating(a),50,'injury blocks progression');assert.equal(rating(b),50,'rest blocks progression');checks++;
}
const old=run({legacy:true,cycles:36});
assert.equal(old.hasLoad,false);assert.ok(rating(old)>50);checks++;
const capped=run({potential:51,cycles:2000});
assert.equal(capped.rating,51);assert.equal(capped.xp,0);checks++;
console.log('V24 CAREER INVARIANTS '+checks+'/'+checks+' PASS: balanced/focused fatigue, injury, rest, legacy and potential cap');
