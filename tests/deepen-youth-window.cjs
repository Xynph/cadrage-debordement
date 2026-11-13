'use strict';
const { test, after } = require('node:test'), assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
// Carrière Monde (world-champ) partagée : chaque cas repart du même état et du même curseur RNG.
const world=context(),base=world.checkpoint();
after(()=>world.close());
const { factory } = require('../native/engine/youth-development.cjs');
function setup(pro=true) {
 const h=world.restore(base); h.run('var Y=('+factory.toString()+')();var p=S.development.academy.find(p=>p.fam===0);p.age=19;p.dev.potential=94;'+(pro?'promoteYouth(p.id);':'')+'Y.enable(S);Y.setPlan(S,p.id,"integration","scrum");var get=()=>Y.project(S).players.find(x=>x.id===p.id).review;'); return h;
}
const review=h=>JSON.parse(h.run('JSON.stringify(get())'));
test('a recent observed window replaces lifetime surplus as evidence for a playing-time review',()=>{
 const h=setup();h.run('for(let w=1;w<=12;w++){S.round=w;if(w<=6)p.dev.careerMinutes+=100;p.condition=90-w;Y.observe(S,"trainWeek")}');
 const v=review(h);assert.equal(v.evidence.minutesDelta,600);assert.equal(v.recent.available,true);assert.equal(v.recent.from.week,8);assert.equal(v.recent.to.week,12);assert.equal(v.recent.weeks,4);assert.equal(v.recent.minutesDelta,0);assert.equal(v.recommendation.key,'loan');
});
test('window computes measured changes only and survives the six-observation cap',()=>{
 const h=setup();h.run('for(let w=1;w<=10;w++){S.round=w;p.dev.careerMinutes+=20;p.condition=90-w;if(w===8)p.rating+=1;Y.observe(S,"recordDevelopmentMatch")}Y.validate(S)');
 const v=review(h);assert.equal(v.recent.from.week,6);assert.equal(v.recent.minutesDelta,80);assert.equal(v.recent.ratingDelta,1);assert.equal(v.recent.observations,4);assert.equal(v.recent.to.week,10);
 const before=h.run('JSON.stringify(S)');h.run('Y.project(S);Y.project(S);Y.validate(S)');assert.equal(h.run('JSON.stringify(S)'),before);
 const projected=h.run('JSON.stringify(Y.project(S))');const reload=world.restore({text:before,seed:h.seed()});reload.run('var Y=('+factory.toString()+')();Y.validate(S)');assert.equal(reload.run('JSON.stringify(Y.project(S))'),projected);
});
test('a revised plan gets a dated objective and excludes gains before the decision',()=>{
 const h=setup();h.run('S.round=3;p.dev.careerMinutes+=120;Y.observe(S,"recordDevelopmentMatch");Y.setPlan(S,p.id,"general",null);p.rating+=1;S.round=4;Y.observe(S,"trainWeek")');
 const v=review(h);assert.equal(v.shortTermObjective.from.week,3);assert.equal(v.shortTermObjective.due.week,7);assert.equal(v.shortTermObjective.value,1);assert.equal(v.shortTermObjective.achieved,true);
 h.run('Y.setPlan(S,p.id,"integration","scrum")');const changed=review(h).shortTermObjective;assert.equal(changed.value,0);assert.equal(changed.target,80);assert.equal(changed.due.week,8);
});
test('expired bounded plan anchor is explicitly unknown rather than measured from career start',()=>{
 const h=setup();h.run('for(let w=1;w<=12;w++){S.round=w;p.dev.careerMinutes+=10;Y.observe(S,"recordDevelopmentMatch")}');
 const v=review(h).shortTermObjective;assert.equal(v.from.week,0);assert.equal(v.value,null);assert.equal(v.achieved,false);assert.equal(v.coverage,'unavailable');
});
test('season rollover has no invented weekly span and requires new-season observations',()=>{
 const h=setup();h.run('S.round=20;p.dev.careerMinutes+=200;Y.observe(S,"recordDevelopmentMatch");S.season++;S.round=0;Y.observe(S,"advanceSeason")');
 let v=review(h);assert.equal(v.recent.available,false);assert.equal(v.recent.reason,'insufficient');assert.notEqual(v.recommendation.key,'loan');
 h.run('for(let w=1;w<=4;w++){S.round=w;p.condition=90-w;Y.observe(S,"trainWeek")}');v=review(h);assert.equal(v.recent.from.season,2);assert.equal(v.recent.minutesDelta,0);assert.equal(v.recommendation.key,'loan');
});
test('a negative intermediate lifetime counter invalidates recent evidence even after recovery',()=>{
 const h=setup();h.run('p.dev.careerMinutes=100;S.round=1;Y.observe(S,"recordDevelopmentMatch");p.dev.careerMinutes=20;S.round=2;Y.observe(S,"recordDevelopmentMatch");p.dev.careerMinutes=120;S.round=4;Y.observe(S,"recordDevelopmentMatch")');
 assert.equal(review(h).recent.available,false);assert.equal(review(h).recent.reason,'counter');assert.notEqual(review(h).recommendation.key,'loan');
});
test('mobility and promotion never mix contexts in recent evidence',()=>{
 const h=setup(false);h.run('S.round=2;p.dev.careerMinutes=80;Y.observe(S,"recordDevelopmentMatch");promoteYouth(p.id);Y.observe(S,"promoteYouth")');assert.equal(review(h).recent.available,false);
 h.run('S.youthDevelopment.rows.find(x=>x.id===p.id).baseline.clubId=1');assert.equal(review(h).recent.reason,'club');
});
// Moteur natif Monde : les profils officiels de l'édition progressent en cours de saison
// (nativeInSeasonDevelopment) ; le modèle annuel « annual-v11 » n'existe que hors moteur natif.
test('official edition profiles follow in-season growth in the native world engine',()=>{
 const h=world.restore(base);h.run('var Y=('+factory.toString()+')();var p=club().players.find(p=>p.lnrRatingsVersion===1&&p.age<=23);Y.enable(S);Y.setPlan(S,p.id,"general",null)');
 assert.equal(h.run('Y.project(S).players.find(x=>x.id===p.id).model'),'xp');
});

test('reconfirming the same plan in a later week creates a fresh dated objective without spending XP',()=>{
 const h=setup();h.run('for(let w=1;w<=12;w++){S.round=w;p.dev.careerMinutes+=10;Y.observe(S,"recordDevelopmentMatch")}var personBefore=JSON.stringify(p);Y.setPlan(S,p.id,"integration","scrum")');
 const v=review(h).shortTermObjective;assert.equal(v.from.week,12);assert.equal(v.value,0);assert.equal(v.due.week,16);assert.equal(v.coverage,'observed');assert.equal(h.run('JSON.stringify(p)'),h.run('personBefore'));
});
