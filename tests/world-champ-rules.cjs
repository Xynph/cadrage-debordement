'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {factory} = require('../native/engine/champ-rugby.cjs');
const geometry = require('../native/engine/champ-calendar-2026-27.json');
const C = factory(geometry);
const clubs = Array.from({length: 14}, (_, i) => 102 + i);
const seeds = clubs.slice(0, 6);

function result(f, score, tries = [0, 0], extra = {}) {
  return {competitionId: f.competitionId, fixtureId: f.id, phase: f.phase, season: f.season,
    pair: [f.homeId, f.awayId], score, tries, ...extra};
}

function r(homeId, awayId, competitionRound, score, tries = [0, 0]) {
  return result({competitionId: 'champ', id: `t:${homeId}:${awayId}`, phase: 'league', homeId, awayId},
    score, tries, {competitionRound});
}

test('26 journées et 182 matches RFU, avec créneaux anonymes et horaires', () => {
  const fixtures = C.calendarFixtures({clubs});
  assert.equal(fixtures.length, 182);
  assert.equal(new Set(fixtures.map(f => f.id)).size, 182);
  assert.equal(new Set(fixtures.map(f => f.week)).size, 26);
  for (const [i, f] of fixtures.entries()) {
    const published = geometry.fixtures[i];
    assert.deepEqual([f.date, f.kickoffLocal, f.kickoffSource, f.competitionRound, f.timezone],
      [published.date, published.kickoffLocal, published.kickoffSource, published.competitionRound, 'Europe/London']);
    assert.deepEqual([f.homeId, f.awayId], [clubs[published.home], clubs[published.away]]);
    assert(!Object.hasOwn(published, 'sourceId'));
  }
  assert.deepEqual([fixtures[0].date, fixtures[0].week, fixtures.at(-1).date, fixtures.at(-1).week],
    ['2026-09-18', 4, '2027-04-24', 35]);
  for (const id of clubs) {
    const own = fixtures.filter(f => f.homeId === id || f.awayId === id);
    assert.equal(new Set(own.map(f => f.week)).size, 26);
    assert.equal(own.filter(f => f.homeId === id).length, 13);
  }
  assert.throws(() => factory({...geometry, fixtures: geometry.fixtures.with(1, geometry.fixtures[0])}), /calendrier/);
  assert.throws(() => C.calendarFixtures({clubs: clubs.with(1, 102)}), /clubs/);
  assert.throws(() => C.calendarFixtures({clubs, anchor:'2026-09-21'}), /horizon/);
});

test('une seconde saison repose sur un gabarit de jeu explicite', () => {
  assert.throws(() => C.calendarFixtures({clubs, season: 2027}), /convention/);
  const opts = {clubs, season: 2027, seasonModel: C.FROZEN_MODEL};
  const later = C.calendarFixtures(opts);
  assert.deepEqual(later, C.calendarFixtures(opts));
  assert.equal(later[0].date, '2027-09-17');
  assert.equal(later[0].scheduleSource, 'generated-frozen-format');
  assert.equal(later[0].kickoffLocal, null);
});

test('RFU §3.1 : bonus trois essais d’écart et sept points de marge', () => {
  assert.deepEqual(C.terrainPoints([29, 22], [4, 3]), [4, 1]);
  assert.deepEqual(C.terrainPoints([21, 14], [3, 0]), [5, 1]);
  assert.deepEqual(C.terrainPoints([21, 13], [3, 0]), [5, 0]);
  assert.deepEqual(C.terrainPoints([15, 15], [3, 0]), [3, 2]);
  assert.throws(() => C.terrainPoints([9, 8], [2, 1]), /score/);
});

test('égalité RFU : compare les victoires restantes après retrait des premiers matches de chaque club', () => {
  const matches = [r(102,104,0,[10,0]), r(103,105,0,[0,10]), r(105,102,1,[10,0]), r(104,103,1,[0,10])];
  const table = C.table(clubs,matches,{deductions:{104:1,105:5}});
  assert.deepEqual(table.slice(0,2).map(row=>row.clubId),[103,102]);
  assert.deepEqual(table.slice(0,2).map(row=>[row.points,row.won,row.diff,row.pf]),[[4,1,0,10],[4,1,0,10]]);
  const unresolved = C.table(clubs, []);
  assert(unresolved.every(row=>row.unresolvedTie));
  const drawOrder=Object.fromEntries(clubs.slice().reverse().map((id,i)=>[id,i]));
  assert.equal(C.table(clubs,[],{tieBreaks:{drawOrder}})[0].clubId,115);
  assert.equal(C.table(clubs,[],{tieBreaks:{drawOrder}})[0].tieResolution,'game-draw');
});

test('la table exige les fixtures canoniques quand elles sont fournies et le titre attend 26 journées', () => {
  const fixtures=C.calendarFixtures({clubs});
  const example=result(fixtures[0],[21,14],[3,0]);
  assert.equal(C.table(clubs,[example],{fixtures})[0].points,5);
  assert.throws(()=>C.table(clubs,[example,example],{fixtures}),/doublon/);
  assert.throws(()=>C.table(clubs,[{...example,pair:example.pair.slice().reverse()}],{fixtures}),/calendrier/);
  assert.throws(()=>C.playoffSeeds(C.table(clubs,[example],{fixtures})),/26/);
  const drawOrder=Object.fromEntries(clubs.map((id,i)=>[id,i]));
  const all=fixtures.map((f,i)=>result(f,i%3===0?[10,0]:[0,10]));
  assert.equal(C.playoffSeeds(C.table(clubs,all,{fixtures,tieBreaks:{drawOrder}})).length,6);
});

test('quarts 3–6 et 4–5, nouveau classement des vainqueurs et finale au mieux classé', () => {
  const quarter=C.knockoutFixtures({phase:'quarter',seeds});
  assert.deepEqual(quarter.map(f=>[f.homeId,f.awayId,f.date,f.week]),
    [[104,107,'2027-05-08',37],[105,106,'2027-05-08',37]]);
  assert.deepEqual(C.knockoutFixtures({phase:'semi',seeds}),[]);
  const results=[result(quarter[0],[21,9]),result(quarter[1],[24,12])];
  const semi=C.knockoutFixtures({phase:'semi',seeds,results});
  assert.deepEqual(semi.map(f=>[f.homeId,f.awayId,f.date]),[[102,105,'2027-05-15'],[103,104,'2027-05-15']]);
  results.push(result(semi[0],[12,15]),result(semi[1],[24,3]));
  const [final]=C.knockoutFixtures({phase:'final',seeds,results});
  assert.deepEqual([final.homeId,final.awayId,final.venueHostId,final.date],[103,105,103,'2027-05-29']);
  assert.deepEqual(C.finalOutcome({seeds,results:[...results,result(final,[10,13])]}),{champion:105,finalist:103});
  const upset=C.knockoutFixtures({phase:'semi',seeds,results:[result(quarter[0],[9,21]),results[1]]});
  assert.deepEqual(upset.map(f=>[f.homeId,f.awayId]),[[102,107],[103,105]]);
  assert.throws(()=>C.knockoutFixtures({phase:'semi',seeds,results:[...results,results[0]]}),/doublon/);
});

function shots(flags, first=1) {
  const eligible=[['a0','a1','a2','a3'],['b0','b1','b2','b3']];
  const kickers=eligible.map(team=>team.slice(0,3));
  const attempts=flags.flatMap((pair,round)=>[first,1-first].map(side=>({
    side,playerId:kickers[side][round%3],position:round<6?round+1:4,made:pair[side],
  })));
  return {first,end:0,eligible,kickers,attempts,score:[0,1].map(side=>flags.filter(p=>p[side]).length)};
}

test('diagramme RFU 22 m puis ligne des 10 m côté but, côtés à 15 m des touches', () => {
  assert.deepEqual([0,1,2,3,4,5,6,7,8].map(round=>{
    const a=C.kickAt(round);
    return [a.position,a.kicker,a.depth,a.lateral];
  }),[[1,0,22,0],[2,1,22,20],[3,2,22,-20],[4,0,40,0],[5,1,40,20],[6,2,40,-20],[4,0,40,0],[4,1,40,0],[4,2,40,0]]);
  const a=C.kickAt(5,{length:94,width:68});
  assert.deepEqual([a.depth,a.lateral,a.distance,a.angle],[37,-19,Math.hypot(37,19),Math.atan2(19,37)]);
  assert.throws(()=>C.kickAt(-1),/tir/);
});

test('six tirs complets même si écart acquis, puis paires de mort subite au point 4', () => {
  const first=Array.from({length:6},()=>[true,false]);
  assert.equal(C.shootoutWinner(shots(first)),0);
  assert.throws(()=>C.shootoutWinner(shots(first.slice(0,4))),/tirs/);
  const sudden=Array.from({length:6},()=>[false,false]).concat([[false,false],[false,true]]);
  const q=shots(sudden);
  assert.equal(C.shootoutWinner(q),1);
  assert.throws(()=>C.shootoutWinner({...q,attempts:q.attempts.slice(0,-1)}),/tirs/);
  assert.throws(()=>C.shootoutWinner({...q,attempts:q.attempts.with(14,{...q.attempts[14],position:2})}),/position/);
  assert.throws(()=>C.shootoutWinner(shots([...sudden,[false,false]])),/décisif/);
});

test('un buteur blessé peut être remplacé par un autre joueur présent, sans changer son numéro', () => {
  const q=shots(Array.from({length:6},()=>[true,false]));
  q.replacements=[{before:7,side:0,kicker:0,outId:'a0',inId:'a3'}];
  q.attempts[7].playerId='a3';
  assert.equal(C.shootoutWinner(q),0);
  assert.throws(()=>C.shootoutWinner({...q,replacements:[{...q.replacements[0],inId:'b3'}]}),/remplaçant/);
});

test('les deux prolongations précèdent le départage aux essais ou la séance', () => {
  const f=C.knockoutFixtures({phase:'quarter',seeds})[0];
  assert.deepEqual(C.EXTRA_TIME,{halves:[10,10],startDelay:0,interval:1});
  assert.deepEqual(C.knockoutWinner(result(f,[18,10])),{winner:104,method:'score'});
  assert.throws(()=>C.knockoutWinner(result(f,[18,18])),/prolongation/);
  const overtime={regulationEnd:80,firstEnd:92,end:104,regulationScore:[12,12]};
  assert.deepEqual(C.knockoutWinner(result(f,[18,18],[3,1],{overtime})),{winner:104,method:'tries'});
  const shootout=shots(Array.from({length:6},()=>[true,false]));
  assert.deepEqual(C.knockoutWinner(result(f,[18,18],[2,2],{overtime,shootout})),{winner:104,method:'shootout'});
  assert.throws(()=>C.knockoutWinner(result(f,[18,18],[2,2],{overtime:{...overtime,end:100},shootout})),/prolongation/);
});

test('frontières : PREM fermée par le règlement, accès National1 dépend des MOS et témoins', () => {
  assert.equal(C.PREM_PROMOTION_2026_27,false);
  const missing=C.lowerPlan({ranked:clubs});
  assert.equal(missing.status,'awaiting-national1');
  assert.equal(missing.directRelegation,115);
  assert.deepEqual([missing.relegation.homeId,missing.relegation.awayId,missing.relegation.date],[113,114,null]);
  assert.equal(C.lowerPlan({ranked:clubs,closedBoundary:true}).status,'closed-game-boundary');
  const nlr=[200,201,202];
  const national1={ranked:nlr,approval:{200:false,201:true,202:true}};
  const rel=result(missing.relegation,[18,21]);
  const access=C.lowerPlan({ranked:clubs,national1,results:[rel]});
  assert.equal(access.directPromotion,201);
  assert.deepEqual([access.accession.homeId,access.accession.awayId],[113,202]);
  const done=C.lowerPlan({ranked:clubs,national1,results:[rel,result(access.accession,[15,18])]});
  assert.deepEqual([done.promoted,done.relegated],[[201,202],[115,113]]);
  assert.equal(C.lowerPlan({ranked:clubs,national1:{ranked:nlr,approval:{200:false,201:false,202:false}}}).status,'awaiting-rfu');
});
