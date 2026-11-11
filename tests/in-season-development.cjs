'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./native-reference-harness.cjs');
test('real detailed attributes and current level improve during the season without rewriting source identity',()=>{
 const h=context({seed:917});h.run(`CDCommonCareer.start(0);var learner=S.clubs[0].players.find(p=>p.age<=22&&p.dev.potential>=p.rating+5);if(!learner)throw Error('Learner missing');var original=JSON.parse(JSON.stringify(learner));`);
 h.run('for(var i=0;i<16;i++)growPlayer(learner,.25,false);');
 assert.ok(h.run('learner.rating>original.rating'),'current ability grows before any birthday or season transition');
 assert.ok(h.run('Object.keys(learner.attributesV2).some(k=>learner.attributesV2[k]>original.attributesV2[k])'));
 assert.equal(h.run('learner.pos'),h.run('original.pos'));assert.equal(h.run('JSON.stringify(learner.hiddenTraitsV2)'),h.run('JSON.stringify(original.hiddenTraitsV2)'));
 assert.equal(h.run('learner.potential'),h.run('original.potential'));assert.equal(h.run('learner.lnrRatingsVersion'),1);
 assert.equal(h.run('learner.skillBase-learner.rating'),h.run('original.skillBase-original.rating'));
 h.run('validateCareer(S);var inSeasonLevel=learner.rating;ageDevelopmentPlayer(learner,1);validateCareer(S);');
 assert.equal(h.run('learner.rating'),h.run('inSeasonLevel'),'no second positive training reward at the annual transition');
 assert.equal(h.run('learner.age'),h.run('original.age+1'));
 const once=h.run('JSON.stringify(learner)');h.run('ageDevelopmentPlayer(learner,1);');assert.equal(h.run('JSON.stringify(learner)'),once);
});
test('focused learning updates real attributes and remains bounded by the current ceiling',()=>{
 const h=context({seed:917});h.run(`CDCommonCareer.start(0);var learner=S.clubs[0].players.find(p=>p.age<=22&&p.dev.potential>=p.rating+3&&developmentFocusOptions(p).includes('pass'));var start=learner.rating;if(!setDevelopmentFocus(learner.id,'pass'))throw Error('Focus unavailable');var original=JSON.parse(JSON.stringify(learner));for(var i=0;i<24;i++)growPlayer(learner,.25,true);`);
 assert.ok(h.run('learner.attributesV2.passing>original.attributesV2.passing'));
 assert.ok(h.run('learner.rating<=learner.dev.potential'));
 h.run('validateCareer(S);');
});
test('historical annual youth baselines remain readable and can switch to a weekly focused plan',()=>{
 const h=context({seed:917});h.run(`CDCommonCareer.start(0);CDYouthDevelopment.enable(S);var learner=S.clubs[0].players.find(p=>p.age<=22&&developmentFocusOptions(p).includes('pass'));var row=S.youthDevelopment.rows.find(r=>r.id===learner.id);row.baseline.model='annual-v11';row.latest.model='annual-v11';var baseline=JSON.stringify(row.baseline);CDYouthDevelopment.validate(S);`);
 assert.equal(h.run('JSON.stringify(row.baseline)'),h.run('baseline'),'legacy baseline not rewritten by reads');
 h.run(`CDYouthDevelopment.setPlan(S,learner.id,'specialist','pass');CDYouthDevelopment.validate(S);`);
 assert.equal(h.run('row.latest.model'),'xp');assert.equal(h.run('row.baseline.model'),'annual-v11');
 h.run('for(var i=0;i<8;i++)growPlayer(learner,.25,true);CDYouthDevelopment.observe(S,"trainWeek");CDYouthDevelopment.validate(S);validateCareer(S);');
});
test('a real detailed player can receive staff mentoring with the existing shared XP budget',()=>{
 const h=context({seed:917});h.run(`CDCommonCareer.start(0);CDStaffCareer.initialize(S);var learner=S.clubs[0].players.find(p=>p.age<=22&&p.dev.potential>=p.rating+3&&developmentFocusOptions(p).includes('pass'));var mentor=S.staffCareer.people.flat().find(m=>m.clubId===0&&['coach','assistant','formation'].includes(m.role)&&m.contractEnd>=S.season);var ctx={season:S.season,week:S.franceMode.week,club:S.club};nativeSystems.execute('staff_mentoring_enable',{context:ctx,confirmed:true});nativeSystems.execute('staff_mentor_assign',{context:ctx,confirmed:true,staffId:mentor.id,playerId:learner.id,focus:'pass'});learner.dev.xp=0;learner.dev.specialization.xp=0;developmentTraining(learner,'normal',0);`);
 assert.equal(h.run('S.staffMentoring.experience[0].sessions.length'),1);
 assert.ok(h.run('Math.abs(learner.dev.xp-learner.dev.specialization.xp*3)<.000001'),'novice mentor routes 25% of the same learning budget');
 h.run('validateCareer(S)');
});
test('a saturated legacy skill baseline cannot double-count a current-level gain',()=>{
 const h=context({seed:917});h.run(`CDCommonCareer.start(0);var learner=S.clubs[0].players[0];learner.rating=98;learner.skillBase=99;learner.dev.potential=99;learner.dev.xp=0;learner.attributesV2=Object.fromEntries(Object.keys(learner.attributesV2).map(k=>[k,60]));learner.skills=Object.fromEntries(Object.keys(learner.skills).map(k=>[k,60]));var beforeSkill=skill(learner,'pass');growPlayer(learner,2,false);`);
 assert.equal(h.run('learner.rating'),99);assert.equal(h.run('learner.attributesV2.passing'),61);
 assert.equal(h.run('skill(learner,"pass")-beforeSkill'),1);
 h.run('validateCareer(S)');
});
test('a hooker lineout focus updates the exact specialist attribute matrix once',()=>{
 const h=context({seed:917});h.run(`CDCommonCareer.start(0);var learner=S.clubs[0].players.find(p=>p.pos==='Talonneur');learner.rating=learner.skillBase=60;learner.dev.potential=90;learner.dev.xp=0;learner.attributesV2=Object.fromEntries(Object.keys(learner.attributesV2).map(k=>[k,60]));learner.skills=lnrProjectV12(learner);setDevelopmentFocus(learner.id,'lineout');learner.dev.specialization.xp=.49;var beforeLineout=skill(learner,'lineout');growPlayer(learner,.1,true);`);
 assert.equal(h.run('focusedBonus(learner,"lineout")'),1);
 assert.equal(h.run('learner.attributesV2.ballHandling'),61);assert.equal(h.run('learner.attributesV2.decisions'),61);
 assert.equal(h.run('skill(learner,"lineout")-beforeLineout'),1);
});
