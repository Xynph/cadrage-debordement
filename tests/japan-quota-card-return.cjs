'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const repo = path.resolve(__dirname,'..');
const {context}=require(path.join(repo,'tests','monde-harness.cjs'));
const quota=require(path.join(repo,'native','engine','japan-quota-runtime.cjs')).factory;
const eligibility=require(path.join(repo,'native','engine','japan-eligibility.cjs')).factory;
const h=context(827381,{club:68}).toMatch();
h.run(`// Carrière Monde réelle d'un club de League One (68) : catégories japonaises de l'édition, quota natif.
const l=createRugbyMatch(nextMatch());S.live=l;l.worldContext={competitionId:'jlo-d1',phase:'league'};
const side=l.userSide,sh=l.sheets[side];
const chosen=sh.on.map((id,slot)=>({id,slot,incoming:sh.bench.find(p=>p&&slotEligible(matchPlayer(l,side,p),slot))}))
  .find(x=>x.slot>=3 && x.incoming);
const yellowSlot=chosen.slot===14?13:14;
const categories=CDWorldCareer.edition(S).registry.japanCategories;
const set=(id,category)=>categories[id]={category,basis:'estimated'};
const a1Slots=[chosen.slot,...sh.on.map((_,i)=>i).filter(i=>i!==chosen.slot&&i!==yellowSlot)].slice(0,8);
sh.on.forEach((id,i)=>set(id,a1Slots.includes(i)?'A-1':'A-2'));
sh.bench.forEach(id=>set(id,id===chosen.incoming?'A-2':'A-1'));
l.sheets[1-side].nominated.forEach(id=>set(id,'A-1'));
const field=()=>{const ids=activePlayers(l,side).map(p=>p.id);return {a1:ids.filter(id=>categories[id].category==='A-1').length,others:ids.filter(id=>categories[id].category!=='A-1').length}};
const report={initial:field()};
CDWorldJapanQuota.validate(S);
l.minute=1;report.red=giveMatchCard(l,side,chosen.id,'red20');
l.minute=15;report.yellow=giveMatchCard(l,side,sh.on[yellowSlot],'yellow');
l.minute=21;report.beforeReplacement=field();
report.replacement=makeSub(l,side,chosen.slot,chosen.incoming);
report.beforeYellowReturn=field();CDWorldJapanQuota.validate(S);
const oldFlow=advanceFlowPlay;advanceFlowPlay=()=>{};l.minute=24;
try{advanceRugby(l)}finally{advanceFlowPlay=oldFlow}
report.afterYellowReturn=field();report.minute=l.minute;
try{CDWorldJapanQuota.validate(S)}catch(e){report.error=e.message;}
`);
const report=JSON.parse(h.run('JSON.stringify(report)'));
assert.equal(report.red,true);
assert.equal(report.yellow,true);
assert.equal(report.replacement,false);
assert.deepEqual(report.initial,{a1:8,others:7});
assert.deepEqual(report.beforeReplacement,{a1:7,others:6});
assert.deepEqual(report.beforeYellowReturn,{a1:7,others:6});
assert.deepEqual(report.afterYellowReturn,{a1:7,others:7});
assert.equal(report.minute,25);
assert.equal(report.error,undefined,JSON.stringify(report));
console.log(JSON.stringify(report));
