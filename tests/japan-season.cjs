'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const J=require('../native/engine/japan-season.cjs');
const keys=Object.fromEntries(J.leagues.map(id=>[id,J.slotKeys(id)]));
const slots={'jlo-d1':keys['jlo-d1'].map((_,i)=>68+i),'jlo-d2':keys['jlo-d2'].map((_,i)=>80+i)};
const anchor='2026-08-31',future='2027-08-30';
const chart=(fixtures,clubIds)=>clubIds.map(id=>[id,fixtures.filter(f=>f.homeId===id).length,fixtures.filter(f=>f.awayId===id).length]);
test('published calendars include all fixtures and record open dates without inventing published precision',()=>{
 for(const [id,n,h,w] of [['jlo-d1',108,9,7],['jlo-d2',56,7,11]]){
  const fs=J.regular({id,members:slots[id],year:2026,anchor});
  a.equal(fs.length,n);a.equal(fs.filter(f=>f.dateSource==='simulation-earliest-option').length,w);
  a.ok(fs.every(f=>f.date===f.dateOptions[0]));a.ok(fs.filter(f=>f.dateSource!=='published').every(f=>f.kickoffUtc===null));
  a.deepEqual(chart(fs,slots[id]),slots[id].map(id=>[id,h,h]));
  const taken=fs.flatMap(f=>[[f.week,f.homeId].join(':'),[f.week,f.awayId].join(':')]);
  a.equal(new Set(taken).size,taken.length);
 }
});
test('next season swaps vacated slots, preserving competitive balance and generating fresh dates',()=>{
 const pair={upperId:79,lowerId:80},result={promoted:true,upperNext:80,lowerNext:79};
 const next=J.move(slots,[pair],[result]);
 a.deepEqual(next,{'jlo-d1':[...slots['jlo-d1'].slice(0,-1),80],'jlo-d2':[79,...slots['jlo-d2'].slice(1)]});
 for(const id of J.leagues){
  const initial=J.regular({id,members:slots[id],year:2026,anchor});
  const fs=J.regular({id,members:next[id],year:2027,anchor:future});
  a.deepEqual(chart(fs,next[id]),next[id].map(clubId=>[clubId,initial.length/next[id].length,initial.length/next[id].length]));
  a.ok(fs.every((f,i)=>f.id!==initial[i].id&&f.date!==initial[i].date&&f.week===initial[i].week&&f.dateSource==='simulation-future-calendar'&&f.kickoffUtc===null));
 }
});
test('official local match bonuses and chronological recent form survive projection',()=>{
 const id='jlo-d1',members=slots[id],fs=J.regular({id,members,year:2026,anchor});
 const f=fs[0],r={fixtureId:f.id,competitionId:id,season:1,phase:'league',pair:[f.homeId,f.awayId],score:[22,15],tries:[4,1]};
 const ranked=J.table({id,members,fixtures:fs,results:[r],season:1});
 const h=ranked.find(c=>c.clubId===f.homeId),v=ranked.find(c=>c.clubId===f.awayId);
 a.deepEqual([h.points,h.bonus,h.won,h.form],[5,1,1,['W']]);a.deepEqual([v.points,v.bonus,v.lost,v.form],[1,1,1,['L']]);
});
test('quarter and promotion dates preserve weeks across seasons and use different identities',()=>{
 const q=J.knockout({year:2027,anchor:future,seeds:slots['jlo-d1'].slice(0,6),phase:'quarter',results:[]});
 a.equal(q[0].id,'jlo:2027-28:d1:quarter:m01');a.deepEqual([q[0].homeId,q[0].awayId],[70,73]);a.deepEqual(q[0].seeds,[3,6]);
 const d1=slots['jlo-d1'].map((id,i)=>({id,rank:i+1,played:18,sportingTie:false}));
 const d2=slots['jlo-d2'].map((id,i)=>({id,rank:i+1,played:14,sportingTie:false}));
 const p=J.promotion({d1,d2,year:2027,anchor:future});
 a.deepEqual(p.pairs.map(x=>[x.upperId,x.lowerId]),[[78,81],[79,80]]);
 a.ok(p.fixtures.every(f=>f.round===f.leg-1&&f.dateSource==='simulation-future-calendar'));
 const r=p.fixtures.slice(0,2).map(f=>({fixtureId:f.id,pair:[f.homeId,f.awayId],score:[7,7],tries:[1,1],stats:[{conversions:1},{conversions:1}]}));
 a.equal(J.promotionDecision(p.pairs[0],r).method,'incumbent');
 a.equal(J.promotionDecision(p.pairs[1],r),null);
});