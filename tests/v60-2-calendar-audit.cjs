'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),m=require('../dist/press-events.js');
const tests=[];function test(name,fn){fn();tests.push(name)}
const p=(s,id,deadline=4,week=1)=>m.promise(s,{id,kind:'wins',target:3,season:1,week,deadline});
test('plusieurs promesses meme echeance',()=>{let s=p(p(m.start('x'),'p1'),'p2');let r=m.tick(s,{season:1,week:4,metrics:{wins:4}});assert.equal(r.effects.length,2);assert.ok(r.state.promises.every(x=>x.status==='fulfilled'))});
test('deux crises en meme temps',()=>{let s=m.crisis(m.start('x'),{id:'a',kind:'controversy',week:1,severity:2,weeks:4});s=m.crisis(s,{id:'b',kind:'bad-form',week:1,severity:3,weeks:4});let r=m.tick(s,{season:1,week:2});assert.equal(r.state.press.mediaTrust,45)});
test('pas de sanction promesse repetee',()=>{let s=p(m.start('x'),'p');s=m.tick(s,{season:1,week:4,metrics:{wins:0}}).state;const fan=s.press.fanTrust;s=m.tick(s,{season:1,week:5,metrics:{wins:0}}).state;assert.equal(s.press.fanTrust,fan)});
test('crise resout apres duree',()=>{let s=m.crisis(m.start('x'),{id:'c',kind:'supporters',week:1,severity:4,weeks:2});s=m.tick(s,{season:1,week:3}).state;assert.equal(s.crises[0].status,'resolved')});
test('resultat manque reste non verifie',()=>{let s=p(m.start('x'),'p');s=m.tick(s,{season:1,week:4,metrics:{}}).state;assert.equal(s.promises[0].status,'unverified')});
test('reprise json stable',()=>{let s=p(m.start('x'),'p');s=m.tick(s,{season:1,week:4,metrics:{wins:4}}).state;assert.deepEqual(JSON.parse(JSON.stringify(s)),s)});
test('15 saisons et crises deterministes',()=>{function run(){let s=m.start('x');for(let y=1;y<=15;y++){const week=y*3;s=m.crisis(s,{id:'c'+y,kind:'bad-form',week,severity:1,weeks:2});s=m.tick(s,{season:y,week:week+2}).state;}return s}assert.deepEqual(run(),run())});
const report={passed:tests.length,tests,knownLimitations:['Synthetic fixtures only; not connected to match engine or saves','Season and week not normalized across seasons','Repeated tick in same week can repeat crisis effects']};if(process.env.CD_V602_REPORT)fs.writeFileSync(process.env.CD_V602_REPORT,JSON.stringify(report,null,2)+'\n');console.log('V60.2 AUDIT PASS '+JSON.stringify(report));
