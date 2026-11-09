'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { factory } = require('../native/engine/world-competitions.cjs');
const fixture = require('./fixtures/world-rules/initial-202627.json');
const C = factory();
const clubs = fixture.clubs;
const snapshot = x => JSON.stringify(x);
const result = (id, competitionId, a,b,score,tries,extra={}) => ({fixtureId:id,competitionId,phase:'league',season:2026,round:0,pair:[a,b],score,tries,...extra});

for (const [competitionId,count,matches,rounds] of [['elite',14,182,26],['accession',16,240,30],['prem',10,90,18],['urc',16,144,18]]) {
  test(`${competitionId}: full calendar, stable identities, home balance, reserved European weeks`, () => {
    const input=clubs.filter(c=>c.leagueId===competitionId), before=snapshot(input);
    const fs=C.regularFixtures({clubs:input,competitionId,season:2026,startDate:'2026-09-05'});
    assert.equal(fs.length,matches); assert.equal(new Set(fs.map(f=>f.id)).size,matches);
    assert.equal(new Set(fs.map(f=>f.round)).size,rounds);
    const weeks=new Set(C.europeanWeeks({season:2026}).map(C.weekKey));
    for (const c of input) {
      const home=fs.filter(f=>f.homeId===c.id), away=fs.filter(f=>f.awayId===c.id);
      assert.equal(home.length,rounds/2); assert.equal(away.length,rounds/2);
      assert.equal(new Set([...home,...away].map(f=>f.round)).size,rounds);
      const opponents=new Map();
      for(const f of [...home,...away]) {const o=f.homeId===c.id?f.awayId:f.homeId;opponents.set(o,(opponents.get(o)||0)+1);}
      assert.equal(opponents.size,count-1);
      for(const [id,n] of opponents) assert.equal(n,competitionId==='urc'?(input.find(x=>x.id===id).shield===c.shield?2:1):2);
    }
    for(const f of fs) {assert.equal(f.phase,'league');assert.equal(f.scheduleSource,'generated-game');assert(!weeks.has(C.weekKey(f.date)));assert.match(f.date,/^\d{4}-\d{2}-\d{2}$/);}
    assert.equal(snapshot(input),before); assert.equal(snapshot(fs),snapshot(C.regularFixtures({clubs:input,competitionId,season:2026,startDate:'2026-09-05'})));
  });
}

test('factory survives toString VM injection with no module closure',()=>{
  const other=vm.runInNewContext(`(${factory.toString()})()`);
  assert.equal(other.rules('champions').bonus.tryMargin,3);
  assert.equal(other.regularFixtures({clubs:clubs.filter(c=>c.leagueId==='prem'),competitionId:'prem',season:2027}).length,90);
});

test('bonus boundaries differ by competition; table ignores other phases and competitions',()=>{
  const rs=[result('a','elite',0,1,[30,25],[4,1]),result('b','elite',0,2,[20,14],[2,2]),result('c','prem',0,1,[90,0],[12,0]),result('d','elite',0,1,[90,0],[12,0],{phase:'final'})];
  const before=snapshot(rs); const rows=C.table([0,1,2],rs,'elite',{season:2026});
  assert.equal(rows.find(r=>r.clubId===0).points,9);assert.equal(rows.find(r=>r.clubId===1).bonus,1);assert.equal(rows.find(r=>r.clubId===2).bonus,0);
  assert.equal(C.table([0,1],[result('e','prem',0,1,[30,23],[4,3])],'prem')[0].points,5);
  assert.equal(C.table([0,1],[result('e','champions',0,1,[30,23],[4,3])],'champions')[0].points,4);
  assert.equal(C.table([0,1],[result('e','champions',0,1,[30,23],[6,3])],'champions')[0].points,5);
  assert.equal(snapshot(rs),before);
});

test('invalid/ambiguous results cannot silently corrupt a table',()=>{
  const a=result('a','prem',30,31,[10,10],[1,1]);
  assert.throws(()=>C.table([30,31],[a,a],'prem'),/duplicate/i);
  assert.throws(()=>C.table([30,31],[a,{...a,fixtureId:'b',season:2027}],'prem'),/season/i);
  assert.throws(()=>C.table([30,31],[{...a,tries:[-1,0]}],'prem'),/tries/i);
  assert.equal(C.table([30,31],[a,{...a,fixtureId:'b',season:2027}],'prem',{season:2026})[0].played,1);
  assert.equal(C.table([30,31],[{...a,season:1}],'prem',{season:1})[0].played,1);
});

test('table form and PREM exclusions use match chronology, not array order',()=>{
  const rs=Array.from({length:6},(_,i)=>result('f'+i,'prem',30,31,i%2?[0,10]:[10,0],[0,0],{round:i}));
  assert.equal(snapshot(C.table([30,31],rs,'prem')),snapshot(C.table([30,31],rs.slice().reverse(),'prem')));
  assert.deepEqual(C.table([30,31],rs,'prem').find(r=>r.clubId===30).form,['L','W','L','W','L']);
});

for(const competitionId of ['champions','challenge']) test(`${competitionId}: sourced pools produce four distinct opponents, 2 home 2 away`,()=>{
  const pools=fixture.pools[competitionId]; const before=snapshot(pools);
  const fs=C.poolStage({clubs,pools,competitionId,season:2026});
  assert.equal(fs.length,competitionId==='champions'?48:36);
  for(const id of pools.flat()) {
    const matches=fs.filter(f=>f.homeId===id||f.awayId===id);
    assert.equal(matches.length,4);assert.equal(matches.filter(f=>f.homeId===id).length,2);
    assert.equal(new Set(matches.map(f=>f.homeId===id?f.awayId:f.homeId)).size,4);
    if(competitionId==='champions') for(const f of matches) assert.notEqual(clubs.find(c=>c.id===f.homeId).leagueId,clubs.find(c=>c.id===f.awayId).leagueId);
  }
  assert.equal(snapshot(pools),before);
});

test('cross-pool wildcard selection and Challenge third-place seeding follow 2026/27 rules',()=>{
  const row=(clubId,points)=>({clubId,points,won:1,pf:points,pa:0,tf:points,ta:0});
  const cp=Array.from({length:4},(_,p)=>Array.from({length:6},(_,i)=>row(p*6+i,100-i*10-p)));
  cp[0][4].points=71; // fifth of this supplied pool outranks another pool fourth: all remaining eligible.
  const cq=C.poolQualifiers({competitionId:'champions',tables:cp});
  assert.equal(cq.qualifiers.length,16);assert.equal(cq.transfers.length,4);
  assert(cq.qualifiers.some(r=>r.clubId===4));assert(!cq.transfers.some(r=>cq.qualifiers.some(q=>q.clubId===r.clubId)));
  const ch=Array.from({length:3},(_,p)=>Array.from({length:6},(_,i)=>row(30+p*6+i,100-i*10-p)));
  const q=C.poolQualifiers({competitionId:'challenge',tables:ch,transfers:cq.transfers});
  assert.equal(q.qualifiers.length,16);assert.deepEqual(q.qualifiers.slice(8,12).map(r=>r.clubId),cq.transfers.map(r=>r.clubId));
  assert.equal(q.qualifiers[12].clubId,44); // third in lowest-ranked pool is seed13.
});

test('EPCR lots are explicit, persisted caller inputs and clear unresolved ties only when complete',()=>{
  const pools=Array.from({length:4},(_,p)=>Array.from({length:6},(_,i)=>({clubId:p*6+i,points:10,won:2,pf:30,pa:30,tf:3,ta:3})));
  const before=snapshot(pools), undecided=C.poolQualifiers({competitionId:'champions',tables:pools});assert(undecided.unresolved.length>0);
  const drawOrder=Object.fromEntries(Array.from({length:24},(_,id)=>[id,24-id]));
  const resolved=C.poolQualifiers({competitionId:'champions',tables:pools,drawOrder});
  assert.equal(resolved.unresolved.length,0);assert.deepEqual(resolved.qualifiers.slice(0,4).map(r=>r.clubId),[23,17,11,5]);assert(resolved.qualifiers.every(r=>r.unresolvedTie===false));
  const partial=C.poolQualifiers({competitionId:'champions',tables:pools,drawOrder:{0:1}});assert(partial.unresolved.length>0);
  assert.equal(snapshot(pools),before);assert.equal(snapshot(resolved),snapshot(C.poolQualifiers({competitionId:'champions',tables:pools,drawOrder})));
});

test('annual European qualification reallocates within league quota and requires future invitations',()=>{
  const tables=Object.fromEntries(['elite','prem','urc'].map(l=>[l,clubs.filter(c=>c.leagueId===l).map(c=>({clubId:c.id}))]));
  const q=C.qualifyEurope({tables,clubs,season:2027,titles:{champions:39,challenge:48,urc:47},invitations:[56,57]});
  assert.equal(q.champions.length,24);assert(q.champions.includes(39));assert(!q.champions.includes(37));assert(q.champions.includes(48));assert(q.champions.includes(47));assert(!q.champions.includes(46));
  assert.equal(q.challenge.length,18);assert.equal(new Set([...q.champions,...q.challenge]).size,42);
  const no=C.qualifyEurope({tables,clubs,season:2028,titles:{}});assert.equal(no.challenge.length,16);assert(no.unresolved.some(x=>x.code==='INVITATIONS_REQUIRED'));
  const guest=C.qualifyEurope({tables,clubs,season:2027,titles:{challenge:56},invitations:[57]});assert(guest.unresolved.some(x=>x.code==='TITLE_HOLDER_OUTSIDE_DOMESTIC_QUOTAS'));assert(guest.unresolved.some(x=>x.code==='INVITATIONS_REQUIRED'&&x.missing===1));
  const demoted=C.qualifyEurope({tables,clubs,season:2027,titles:{challenge:14},invitations:[56,57]});assert.equal(demoted.ineligibleTitles[0].code,'LNR_TOP14_REQUIRED');assert(!demoted.champions.includes(14));
  const prem=C.qualifyEurope({tables,clubs,season:2027,titles:{prem:33,premFinalist:32},invitations:[56,57]});assert.deepEqual(prem.byLeague.prem.slice(0,2),[33,32]);assert.deepEqual([...prem.byLeague.prem].sort((a,b)=>a-b),[30,31,32,33,34,35,36,37]);
});

test('league tie provenance is explicit and unresolved lots are not invented',()=>{
  const rows=C.table([30,31],[],'champions');
  assert(rows.every(r=>r.unresolvedTie===true));
  assert.equal(C.rules('urc').provenance.edition,'2025/26');
  assert.equal(C.rules('urc').provenance.status,'provisional-current-edition-unavailable');
  assert.equal(C.rules('prem').membership.automaticPromotionRelegation,false);
  assert.equal(C.rules('prem').membership.effective,'2026/27');
  assert.equal(C.rules('prem').provenance.edition,'2026/27');assert.equal(C.rules('prem').provenance.status,'confirmed');
});

test('a missing last ranking criterion is recorded; partial lots do not resolve it',()=>{
  const a=C.table([0,1],[],'elite',{tieBreaks:{previousRank:{1:4},drawOrder:{1:1}}});
  assert(a.every(r=>r.unresolvedTie&&r.unavailableTieBreak==='previousRank'));
  const b=C.table([0,1],[],'elite',{tieBreaks:{previousRank:{0:6,1:4}}});assert.deepEqual(b.map(r=>r.clubId),[1,0]);
  const c=C.table([40,41],[],'urc',{tieBreaks:{yellowCards:{40:0,41:2},drawOrder:{40:2,41:1}}});
  assert.deepEqual(c.map(r=>r.clubId),[41,40]);assert(c.every(r=>!r.unresolvedTie&&r.unavailableTieBreak==='suspendedPlayers'));
});

test('initial snapshot preserves fixture dates and rejects calendar collisions without rewriting it',()=>{
  const competitionId='urc',season=2026,list=clubs.filter(c=>c.leagueId===competitionId), args={clubs:list,competitionId,season};
  const generated=C.regularFixtures(args), before=snapshot(generated), initial=generated.map(f=>({...f,scheduleSource:'test-input'}));
  assert.deepEqual(C.regularFixtures({...args,initialFixtures:initial}),initial);
  initial.find(f=>f.round===1).date=initial[0].date;
  assert.throws(()=>C.regularFixtures({...args,initialFixtures:initial}),/initial week/i);assert.equal(snapshot(generated),before);
});

test('initial pool calendar preserves per-match dates and provisional labels, validates round week',()=>{
  const args={clubs,pools:fixture.pools.champions,competitionId:'champions',season:2026};
  const initial=C.poolStage(args).map(f=>({...f,scheduleSource:'test-input'}));initial[0].date='2026-10-16';
  assert.deepEqual(C.poolStage({...args,initialFixtures:initial}),initial);
  initial[0].date='2026-10-23';assert.throws(()=>C.poolStage({...args,initialFixtures:initial}),/outside round week/i);
});

test('annual Champions draw honours league/shield separation and protected champions without mutating entrants',()=>{
  const entrants=['elite','prem','urc'].flatMap(l=>clubs.filter(c=>c.leagueId===l).slice(0,8).map(c=>c.id)), before=snapshot(entrants);
  const protectedIds=[0,30,40,31];
  const pools=C.drawPools({competitionId:'champions',clubs,participants:entrants,protectedIds,order:entrants.slice().reverse()});
  assert.equal(pools.length,4);assert.equal(new Set(pools.flat()).size,24);
  for(const pool of pools) {assert.equal(pool.length,6);assert.equal(pool.filter(id=>protectedIds.includes(id)).length,1);for(const leagueId of ['elite','prem','urc'])assert.equal(pool.filter(id=>clubs[id].leagueId===leagueId).length,2);const urc=pool.filter(id=>clubs[id].leagueId==='urc');assert.notEqual(clubs[urc[0]].shield,clubs[urc[1]].shield);}
  assert.equal(snapshot(entrants),before);assert.equal(C.poolStage({competitionId:'champions',clubs,pools,season:2027}).length,48);
});

test('European knockout bracket follows fixed path and original seed, not reseeding survivors',()=>{
  const seeds=Array.from({length:16},(_,i)=>i), competitionId='champions', season=2026;
  const r16=C.knockoutFixtures({competitionId,season,seeds,phase:'r16'});
  assert.deepEqual(r16.map(f=>[f.homeId,f.awayId]),[[0,15],[1,14],[2,13],[3,12],[4,11],[5,10],[6,9],[7,8]]);
  const results=r16.map((f,i)=>result(f.id,competitionId,f.homeId,f.awayId,i===0?[0,10]:[10,0],[0,0],{phase:'r16'}));
  const qf=C.knockoutFixtures({competitionId,season,seeds,phase:'quarter',results});
  assert.deepEqual(qf.map(f=>[f.homeId,f.awayId]),[[7,15],[1,6],[2,5],[3,4]]);
  const next=results.concat(qf.map(f=>result(f.id,competitionId,f.homeId,f.awayId,[10,0],[0,0],{phase:'quarter'})));
  const semi=C.knockoutFixtures({competitionId,season,seeds,phase:'semi',results:next});
  assert.deepEqual(semi.map(f=>[f.homeId,f.awayId]),[[3,7],[1,2]]);assert(semi.every(f=>f.neutral&&f.venuePolicy==='epcr-designated'));
  assert.equal(C.knockoutFixtures({competitionId,season,seeds,phase:'quarter',results:results.slice(0,7)}).length,0);
});

test('European finals always share the reserved weekend in future seasons',()=>{
  for(const season of [2027,2033,2034,2040]) {
    const days=C.europeanWeeks({season});assert(days.every(d=>new Date(d+'T00:00:00Z').getUTCDay()===6));
    for(const competitionId of ['champions','challenge']) {
      const seeds=Array.from({length:16},(_,i)=>i), results=[];
      for(const phase of ['r16','quarter','semi','final']) {
        const fs=C.knockoutFixtures({competitionId,season,seeds,phase,results});
        assert.equal(C.weekKey(fs[0].date),C.weekKey(days[phase==='r16'?4:phase==='quarter'?5:phase==='semi'?6:7]));
        results.push(...fs.map(f=>result(f.id,competitionId,f.homeId,f.awayId,[10,0],[0,0],{phase,season})));
      }
    }
  }
});

test('domestic six-team bracket and URC venue rules remain competition-specific',()=>{
  const seeds=Array.from({length:16},(_,i)=>i);
  const barrage=C.knockoutFixtures({competitionId:'elite',season:2026,seeds,phase:'barrage'});
  assert.deepEqual(barrage.map(f=>[f.homeId,f.awayId]),[[2,5],[3,4]]);
  const results=barrage.map(f=>result(f.id,'elite',f.homeId,f.awayId,[10,0],[0,0],{phase:'barrage'}));
  const semi=C.knockoutFixtures({competitionId:'elite',season:2026,seeds,phase:'semi',results});assert.deepEqual(semi.map(f=>[f.homeId,f.awayId]),[[0,3],[1,2]]);assert(semi.every(f=>f.neutral));
  const urc=C.knockoutFixtures({competitionId:'urc',season:2026,seeds,phase:'quarter'});assert.deepEqual(urc.map(f=>[f.homeId,f.awayId]),[[0,7],[1,6],[2,5],[3,4]]);
  const urcResults=urc.map(f=>result(f.id,'urc',f.homeId,f.awayId,[0,10],[0,0],{phase:'quarter'}));
  const urcSemi=C.knockoutFixtures({competitionId:'urc',season:2026,seeds,phase:'semi',results:urcResults});assert.deepEqual(urcSemi.map(f=>[f.homeId,f.awayId]),[[4,7],[5,6]]);assert(urcSemi.every(f=>!f.neutral));
  const urcFinal=C.knockoutFixtures({competitionId:'urc',season:2026,seeds,phase:'final',results:urcResults.concat(urcSemi.map(f=>result(f.id,'urc',f.homeId,f.awayId,[10,0],[0,0],{phase:'semi'})))});
  assert.equal(urcFinal[0].venuePolicy,'urc-designated');assert.equal(urcFinal[0].venueDesignationPending,true);assert.equal(urcFinal[0].neutral,false);assert.equal(urcFinal[0].venueHostId,4);
});

test('knockout winner requires extra time and uses European tries before kicks, never French penalty count',()=>{
  const r=result('ko','champions',0,1,[24,24],[3,2],{phase:'r16',penalties:[3,4]});
  assert.equal(C.knockoutWinner(r,'champions').requires,'extra-time');
  assert.equal(C.knockoutWinner({...r,afterExtraTime:true},'champions').winner,0);
  const equal={...r,afterExtraTime:true,tries:[2,2]};assert.equal(C.knockoutWinner(equal,'champions').requires,'place-kicks');
  assert.equal(C.knockoutWinner(equal,'elite').winner,1);
  assert.equal(C.knockoutWinner({...equal,winner:0,decision:{method:'shootout'}},'champions').winner,0);
  assert.equal(C.knockoutWinner({...equal,penalties:undefined,winner:0,duration:100,decision:{method:'shootout'}},'elite').winner,0);
  assert.throws(()=>C.knockoutWinner({...r,score:[10,0],winner:1},'champions'),/contradict/i);
});
