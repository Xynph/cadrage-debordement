'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const {factory}=require('../native/engine/youth-development.cjs');
function setup(){const h=context();h.run('start(0);var Y=('+factory.toString()+')();var p=S.development.academy.find(p=>p.fam===0);p.age=19;p.dev.potential=94;var get=()=>Y.project(S).players.find(x=>x.id===p.id).review;');return h;}
function review(h){assert.equal(h.run('typeof get()'),'object','each young player must expose a factual interim review');return JSON.parse(h.run('JSON.stringify(get())'));}
test('untracked young player has no fabricated assessment or minute delta',()=>{
 const h=setup(),v=review(h);assert.equal(v.status,'untracked');assert.equal(v.evidence,null);assert.equal(v.objective,null);assert.equal(v.recommendation.key,'start');
});
test('interim review measures a general objective against the original dated reference',()=>{
 const h=setup();h.run('Y.enable(S);Y.setPlan(S,p.id,"general",null);p.rating+=1;p.dev.careerMinutes+=80;S.round=4;Y.observe(S,"trainWeek")');
 const v=review(h);assert.equal(v.objective.key,'general');assert.equal(v.objective.target,1);assert.equal(v.objective.achieved,true);assert.equal(v.evidence.ratingDelta,1);assert.equal(v.evidence.minutesDelta,80);assert.equal(v.evidence.from.week,0);assert.equal(v.evidence.to.week,4);assert.match(v.basis,/référence initiale/);
});
test('recent baseline does not manufacture a lack of game time',()=>{
 const h=setup();h.run('promoteYouth(p.id);Y.enable(S);S.round=1');const v=review(h);assert.equal(v.status,'observing');assert.notEqual(v.recommendation.key,'minutes');assert.notEqual(v.recommendation.key,'loan');
});
test('professional short of observed minutes can examine an existing loan without a promise',()=>{
 const h=setup();h.run('promoteYouth(p.id);Y.enable(S);S.round=5;S.lineup=S.lineup.filter(id=>id!==p.id);S.reserves=S.reserves.filter(id=>id!==p.id)');
 const v=review(h);assert.equal(v.status,'review');assert.equal(v.recommendation.key,'loan');assert.equal(v.recommendation.destination,'Centre');assert.equal(v.recommendation.suggestedPlan,'integration');assert.match(v.recommendation.detail,/vérifier/i);
});
test('selected professional receives a minutes review rather than a loan promise',()=>{
 const h=setup();h.run('promoteYouth(p.id);Y.enable(S);S.round=5;S.lineup[0]=p.id');assert.equal(review(h).recommendation.key,'minutes');
});
test('injury and fatigue take priority over a promotion or growth recommendation',()=>{
 const h=setup();h.run('Y.enable(S);p.injury=2;S.round=5');const v=review(h);assert.equal(v.recommendation.key,'recover');assert.equal(v.status,'review');assert.match(v.recommendation.detail,/2/);
});
test('minor stays at the centre and an adult can examine a first pro contract',()=>{
 const h=setup();h.run('p.age=17;Y.enable(S)');assert.equal(review(h).recommendation.key,'academy');h.run('p.age=18');assert.equal(review(h).recommendation.key,'promotion');assert.match(review(h).recommendation.detail,/salaire|contrat/i);
});
test('specialist objective changes after reorientation but never reattributes the old gains',()=>{
 const h=setup();h.run('Y.enable(S);Y.setPlan(S,p.id,"specialist","scrum");p.skills.scrum+=1');assert.equal(review(h).objective.key,'quality');assert.equal(review(h).objective.achieved,true);
 h.run('Y.setPlan(S,p.id,"integration","scrum")');const v=review(h);assert.equal(v.objective.key,'integration');assert.match(v.basis,/ne prouvent pas/i);
});
test('annual model uses the real annual review and does not infer stagnation',()=>{
 const h=require('./france-harness.cjs').context();h.run('var C=('+require('../native/engine/common-rosters.cjs').toString()+')();C.start(0);var Y=('+factory.toString()+')();var p=club().players.find(p=>p.lnrRatingsVersion===1&&p.age<=23);Y.enable(S);Y.setPlan(S,p.id,"general",null);S.round=5;var get=()=>Y.project(S).players.find(x=>x.id===p.id).review');
 const v=review(h);assert.equal(v.objective.measurement,'annual-v11');assert.match(v.basis,/annuel/);assert.equal(v.evidence.ratingDelta,0);
});
test('old-club reference cannot assess new-club playing time and projection is immutable across reload',()=>{
 const h=setup();h.run('Y.enable(S);S.youthDevelopment.rows.find(x=>x.id===p.id).baseline.clubId=1;S.round=5');assert.equal(review(h).status,'context');assert.equal(review(h).evidence,null);
 const before=h.run('JSON.stringify(S)');h.run('Y.project(S);Y.project(S);Y.validate(S)');assert.equal(h.run('JSON.stringify(S)'),before);
 const reload=context(JSON.parse(before));reload.run('var Y=('+factory.toString()+')();Y.validate(S)');assert.equal(reload.run('JSON.stringify(S)'),before);assert.equal(reload.run('JSON.stringify(Y.project(S))'),h.run('JSON.stringify(Y.project(S))'));
});
test('players above the tracked age remain outside the review list',()=>{
 const h=setup();h.run('p.age=25');assert.equal(h.run('Y.project(S).players.some(x=>x.id===p.id)'),false);
});
test('a decreasing imported lifetime-minute counter never produces a false playing-time deficit',()=>{
 const h=setup();h.run('promoteYouth(p.id);p.dev.careerMinutes=600;Y.enable(S);p.dev.careerMinutes=500;S.round=5');const v=review(h);assert.equal(v.status,'context');assert.equal(v.evidence,null);assert.equal(v.recommendation.key,'counter');
});
