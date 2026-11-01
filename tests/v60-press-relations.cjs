'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),m=require('../dist/press-relations.js');
let passed=0;function test(name,f){f();passed++;console.log('PASS '+name)}
test('creation et bornes',()=>{const s=m.create('club-1');assert.equal(s.mediaTrust,50);m.validate(s);assert.throws(()=>m.create(''))});
test('cinq sujets quatre tons',()=>{assert.equal(m.topics.length,5);assert.equal(m.tones.length,4)});
test('interview affecte quatre indicateurs',()=>{const s=m.create('a'),r=m.interview(s,{topic:'derby',tone:'honest',season:1,week:1});assert.ok(r.state.fanTrust>50&&r.state.mediaTrust>50);assert.equal(s.stories.length,0)});
test('interview hebdomadaire sans doublon',()=>{const r=m.interview(m.create('a'),{topic:'form',tone:'confident',season:1,week:1}).state;assert.throws(()=>m.interview(r,{topic:'form',tone:'confident',season:1,week:1}))});
test('dates passees interdites',()=>{const r=m.interview(m.create('a'),{topic:'form',tone:'confident',season:1,week:3}).state;assert.throws(()=>m.interview(r,{topic:'derby',tone:'honest',season:1,week:2}))});
test('performance match influe',()=>{const a=m.interview(m.create('a'),{topic:'form',tone:'honest',season:1,week:1,performance:2}).state;const b=m.interview(m.create('a'),{topic:'form',tone:'honest',season:1,week:1,performance:-2}).state;assert.ok(a.fanTrust>b.fanTrust)});
test('decisions communication repli reputation',()=>{let s=m.create('a');for(let y=1;y<=4;y++){s=m.interview(s,{topic:'form',tone:'aggressive',season:y,week:1}).state;s=m.nextSeason(s)}assert.ok(s.mediaTrust>=0&&s.mediaTrust<=100)});
test('conseils briefing selon pression',()=>{let s=m.create('a');const x=m.briefing(s,{lastResults:[-1,-1,-1]});assert.equal(x.topic,'form');assert.ok(x.risk>s.boardPressure)});
test('15 saisons reprises deterministes',()=>{function run(){let s=m.create('a');for(let y=1;y<=15;y++){for(let w=1;w<=6;w++)s=m.interview(s,{topic:m.topics[w%5],tone:m.tones[y%4],season:y,week:w,performance:(w%3)-1}).state;s=m.nextSeason(s)}return s}assert.deepEqual(run(),run());assert.deepEqual(JSON.parse(JSON.stringify(run())),run())});
test('rejet entree corrompue',()=>{const s=m.create('a');s.mediaTrust=NaN;assert.throws(()=>m.validate(s))});
const report={passed,scope:'synthetic pure module, not playable',limitations:['not wired into real save or results','no UI','effect coefficients illustrative']};if(process.env.CD_V60_REPORT)fs.writeFileSync(process.env.CD_V60_REPORT,JSON.stringify(report,null,2)+'\n');console.log('V60 PRESS PASS '+JSON.stringify(report));
