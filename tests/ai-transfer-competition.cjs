'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const t=context(),run=t.run;
run('start(0)');
assert.equal(run('aiRosterActive()'),true);
const offers=[
 {clubId:2,priority:550,cashBuffer:900000},
 {clubId:1,priority:600,cashBuffer:800000},
 {clubId:3,priority:600,cashBuffer:700000}
];
run('var proposed='+JSON.stringify(offers));
assert.equal(run('aiRosterAuctionWinner(proposed).clubId'),1,'priority, then cash buffer');
run('proposed.reverse()');
assert.equal(run('aiRosterAuctionWinner(proposed).clubId'),1,'stable against arrival order');
run('proposed[2].cashBuffer=800000');
assert.equal(run('aiRosterAuctionWinner(proposed).clubId'),1,'stable club id on tie');
assert.equal(run('aiRosterAuctionWinner([])'),null);
const base=JSON.parse(run('JSON.stringify(S)'));
assert.equal(run('aiRosterRecruitmentWeek()'),0,'first day season one excluded');
assert.equal(run('JSON.stringify(S)'),JSON.stringify(base),'excluded window does not mutate');
run('S.round=13;var beforeCash=club().cash;var beforeIds=S.clubs.flatMap(c=>c.players.map(p=>p.id));var available=S.market.length+S.economy.freeAgents.length;');
const count=run('aiRosterRecruitmentWeek()');
assert.ok(count>=0&&count<=6);
assert.equal(run('aiRosterRecruitmentWeek()'),0,'same window idempotent');
assert.equal(run('S.economy.aiRecruitmentWindow'),'1:13');
assert.equal(run('club().cash'),run('beforeCash'),'no human club cash mutation');
assert.equal(run('S.clubs.every(c=>new Set(c.players.map(p=>p.id)).size===c.players.length)'),true,'no duplicate roster player');
assert.equal(run('new Set(S.clubs.flatMap(c=>c.players.map(p=>p.id))).size===S.clubs.reduce((s,c)=>s+c.players.length,0)'),true,'exclusive player ownership');
assert.equal(run('S.aiRoster.reports.reduce((sum,r)=>sum+r.recruited,0)'),count);
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'save roundtrip');
const historic=context();
historic.run('start(0);delete S.aiRosterVersion;delete S.aiRoster');
assert.equal(historic.run('aiRosterRecruitmentWeek()'),0,'legacy saves unchanged');
const poor=context(),p=poor.run;
p('start(0);S.round=13;for(const c of S.clubs){if(c.id!==S.club){c.cash=0;worldClub(c.id).debt=2000000}}');
assert.equal(p('aiRosterRecruitmentWeek()'),0,'insolvent clubs excluded');
assert.ok(p('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
console.log(JSON.stringify({passed:true,signings:count,checks:['deterministic auction','priority cash tie club id','ineligible window','market idempotence','exclusive ownership','cash protection','reports','save roundtrip','legacy opt-in','insolvent clubs']}));
