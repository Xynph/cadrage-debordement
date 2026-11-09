'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const api = require('../native/engine/league-one-d1.cjs');
const ledger = require('../native/engine/jlo-d1-calendar-2026-27-public.json');
const clubs = ledger.clubKeys.map((key, i) => ({key,id:68+i}));
const ids = clubs.map(c => c.id);
const d2Ids = Array.from({length:8},(_,i) => 80+i);
const standing = (teams, games) => teams.map((id,i) => ({id,rank:i+1,played:games,sportingTie:false}));
const sample = (id, pair, score, tries = [0,0], conversions = [0,0]) =>
  ({fixtureId:id,competitionId:'jlo-d1',season:2026,phase:'league',pair,score,tries,conversions});
const koResult = (fixture, winner) => ({fixtureId:fixture.id,competitionId:fixture.competitionId,phase:fixture.phase,
  season:fixture.season,pair:[fixture.homeId,fixture.awayId],score:winner===fixture.homeId?[19,12]:[12,19],tries:[2,2],winner});

test('108 fixtures officielles, 18 tours et sept adversaires aller-retour', () => {
  const f = api.calendarFixtures({clubs});
  assert.equal(f.length,108);
  assert.equal(new Set(f.map(x=>x.id)).size,108);
  assert.equal(f.filter(x=>x.date===null).length,7);
  assert.equal(f.filter(x=>x.kickoffUtc!==null).length,53);
  for (const id of ids) {
    const opposition = new Map();
    assert.equal(f.filter(x=>x.homeId===id).length,9);
    assert.equal(f.filter(x=>x.awayId===id).length,9);
    for (const g of f.filter(x=>[x.homeId,x.awayId].includes(id))) {
      const rival = g.homeId===id?g.awayId:g.homeId;
      opposition.set(rival,(opposition.get(rival)||0)+1);
    }
    assert.equal([...opposition.values()].filter(n=>n===1).length,4);
    assert.equal([...opposition.values()].filter(n=>n===2).length,7);
  }
  assert.deepEqual(api.calendarFixtures({clubs:[...clubs].reverse()}),f);
  assert.equal(new Set(f.flatMap(g=>[[g.week,g.homeId].join(':'),[g.week,g.awayId].join(':')])).size,216);
});

test('Une date ouverte reste signalée quand un jour de simulation est choisi', () => {
  const open = api.calendarFixtures({clubs}).find(x=>x.date===null);
  const placed = api.calendarFixtures({clubs,datePolicy:api.regularDatePolicy}).find(x=>x.id===open.id);
  assert.equal(open.dateSource,'published-window');
  assert.equal(placed.dateSource,'simulation-earliest-option');
  assert.equal(placed.date,open.dateOptions[0]);
  assert.equal(placed.week,open.week);
  assert.equal(placed.kickoffUtc,null);
  assert.throws(()=>api.calendarFixtures({clubs,season:2027}),/saison/i);
  assert.throws(()=>api.calendarFixtures({clubs,datePolicy:'assume-confirmed'}),/politique/i);
  assert.doesNotMatch(JSON.stringify(ledger), /"(?:venue|providerMatchId|league_match_id|city|sources)"/);
});

test('Article 4, bonus de trois essais réservé au vainqueur et défaite à sept', () => {
  assert.deepEqual(api.resultPoints({score:[35,28],tries:[5,2]}),[5,1]);
  assert.deepEqual(api.resultPoints({score:[21,20],tries:[0,4]}),[4,1]);
  assert.deepEqual(api.resultPoints({score:[27,27],tries:[5,1]}),[2,2]);
  assert.deepEqual(api.resultPoints({score:[28,20],tries:[3,1]}),[4,0]);
});

test('Annulations de championnat homologuées selon la responsabilité', () => {
  const pair = ids.slice(0,2);
  const cancel = fault => ({pair,status:'cancelled',fault});
  assert.deepEqual(api.leagueResult(cancel([])).points,[2,2]);
  assert.deepEqual(api.leagueResult(cancel([])).score,[14,14]);
  assert.deepEqual(api.leagueResult(cancel([pair[1]])).points,[4,0]);
  assert.deepEqual(api.leagueResult(cancel([pair[1]])).tries,[2,0]);
  assert.deepEqual(api.leagueResult(cancel(pair)).points,[0,0]);
  assert.throws(()=>api.leagueResult(cancel([999])),/responsabilité/i);
});

test('Mini-classement à trois, la moyenne neutralise les matchs en plus', () => {
  const [a,b,c,d] = ids;
  const matches = [sample('ab1',[a,b],[0,0]),sample('ab2',[b,a],[0,0]),sample('ac',[a,c],[0,0]),
    sample('bc',[b,c],[0,0]),sample('cd',[c,d],[7,7],[1,1],[1,1])];
  const rows = api.table(ids,matches);
  assert.equal(rows[0].id,c);
  assert.equal(rows[0].points,6);
  assert.deepEqual(rows.slice(1,3).map(r=>[r.rank,r.sportingTie]),[[2,true],[2,true]]);
  const drawn = api.table(ids,matches,'jlo-d1',{drawOrder:[b,a,c,...ids.slice(3)]});
  assert.deepEqual(drawn.slice(0,3).map(r=>r.id),[c,b,a]);
  assert.throws(()=>api.table(ids,[...matches,matches[0]]),/dupliqué/i);
});

test('Le face-à-face départage avant le différentiel global', () => {
  const [a,b,c,d] = ids;
  const matches = [sample('ab',[a,b],[10,5],[2,1]),sample('ac',[a,c],[10,17],[2,2]),sample('bd',[b,d],[38,30],[5,5])];
  const rows = api.table(ids,matches);
  const aRow = rows.find(r=>r.id===a), bRow = rows.find(r=>r.id===b);
  assert.equal(aRow.points,bRow.points);
  assert.ok(aRow.pd<bRow.pd);
  assert.ok(aRow.rank<bRow.rank);
});

test('La saison complète alimente les six têtes depuis les 108 fixtures canoniques', () => {
  const fixtures = api.calendarFixtures({clubs,datePolicy:api.regularDatePolicy});
  const results = fixtures.map((f,i)=>sample(f.id,[f.homeId,f.awayId],[10+i%11,10+i%7],[2,2]));
  const table = api.table(ids,results,'jlo-d1',{fixtures,drawOrder:ids});
  assert.ok(table.every((r,i)=>r.played===18 && r.rank===i+1 && !r.sportingTie));
  assert.deepEqual(api.playoffSeeds(table),table.slice(0,6).map(r=>r.id));
  const [r,...rest] = results;
  assert.throws(()=>api.table(ids,[{...r,pair:r.pair.slice().reverse()},...rest],'jlo-d1',{fixtures}),/hors fixture/i);
});

test('Les phases finales gardent le tableau fixe et établissent les six places', () => {
  const regular = standing(ids,18);
  const seeds = api.playoffSeeds(regular);
  const fixtures = (phase,results=[]) => api.knockoutFixtures({seeds,phase,results});
  const quarters = fixtures('quarter');
  assert.deepEqual(quarters.map(f=>f.seeds),[[3,6],[4,5]]);
  assert.ok(quarters.every(f=>f.date===null));
  const q = [koResult(quarters[0],ids[5]),koResult(quarters[1],ids[3])];
  assert.deepEqual(fixtures('semi',q.slice(0,1)),[]);
  const semis = fixtures('semi',q);
  assert.deepEqual(semis.map(f=>f.seeds),[[1,4],[2,6]]);
  const s = [koResult(semis[0],ids[3]),koResult(semis[1],ids[1])];
  const final = fixtures('final',[...q,...s])[0], bronze = fixtures('third-place',[...q,...s])[0];
  assert.equal(final.date,'2027-06-06');
  assert.equal(final.dateSource,'published');
  assert.equal(bronze.date,null);
  const result = [...q,...s,koResult(final,ids[1]),koResult(bronze,ids[5])];
  assert.deepEqual(api.finalRanking(regular,result).slice(0,6).map(r=>r.id),[ids[1],ids[3],ids[5],ids[0],ids[2],ids[4]]);
  assert.throws(()=>api.playoffSeeds(regular.map((row,i)=>i===5?{...row,sportingTie:true}:row)),/classement/i);
  const assumed = api.knockoutFixtures({seeds,phase:'quarter',datePolicy:api.playoffDatePolicy});
  assert.equal(assumed[0].dateSource,'simulation-window');
  assert.equal(assumed[0].date,'2027-05-22');
  assert.equal(assumed[0].week,37);
});

test('Fin de match, une prolongation décisive et une séance qui repart au point 1', () => {
  assert.deepEqual(api.nextMatchPeriod({period:'regulation',score:[12,12]}),{period:'golden',minutes:10,rest:5});
  assert.deepEqual(api.nextMatchPeriod({period:'golden',score:[12,12]}),{period:'shootout',kickers:5,rest:5});
  const q = {first:0,kickers:[['a','b','c','d','e'],['f','g','h','i','j']],score:[1,0],attempts:[]};
  for (let i=0;i<6;i++) for (const side of [0,1]) q.attempts.push({side,playerId:q.kickers[side][i%5],location:[1,2,3,1,2][i%5],made:i===5&&side===0});
  assert.equal(api.shootoutWinner(q),0);
  q.attempts[10].location=3;
  assert.throws(()=>api.shootoutWinner(q),/tirs/i);
});

test('Annulation playoff, score puis essais puis transformations et rang', () => {
  const fixture = api.knockoutFixtures({seeds:ids.slice(0,6),phase:'quarter'})[0];
  const base = {fixtureId:fixture.id,competitionId:'jlo-d1',phase:'quarter',season:2026,pair:[fixture.homeId,fixture.awayId]};
  assert.equal(api.knockoutWinner({...base,status:'cancelled-before-kickoff'},fixture).winner,fixture.homeId);
  assert.equal(api.knockoutWinner({...base,status:'cancelled-after-kickoff',score:[14,14],tries:[1,2],conversions:[0,2]},fixture).winner,fixture.awayId);
  assert.equal(api.knockoutWinner({...base,status:'cancelled-after-kickoff',score:[17,17],tries:[2,2],conversions:[2,1]},fixture).winner,fixture.homeId);
});

test('Une première marque de prolongation change exactement le score à sa minute', () => {
  const fixture = api.knockoutFixtures({seeds:ids.slice(0,6),phase:'quarter'})[0];
  const result = {...koResult(fixture,fixture.awayId),score:[14,19],
    overtime:{start:82,end:85,regulationScore:[14,14],firstScore:{kind:'try',side:1,minute:85}}};
  assert.equal(api.knockoutWinner(result,fixture).method,'golden-score');
  assert.throws(()=>api.knockoutWinner({...result,score:[14,21]},fixture),/première marque/i);
  assert.throws(()=>api.knockoutWinner({...result,score:[14,14]},fixture),/prolongation achevée/i);
});

test('Barrages 11 D1–2 D2 et 12 D1–1 D2, dates et hôte restent explicites', () => {
  const pairs = api.promotionPairs(standing(ids,18),standing(d2Ids,14));
  assert.deepEqual(pairs.map(p=>[p.upperId,p.lowerId]),[[ids[10],d2Ids[1]],[ids[11],d2Ids[0]]]);
  assert.deepEqual(pairs[0].dateWindow,['2027-05-21','2027-05-30']);
  const legs = api.promotionFixtures(pairs[0],{firstHomeId:pairs[0].lowerId,dates:['2027-05-23','2027-05-30']});
  assert.deepEqual(legs.map(f=>[f.homeId,f.awayId]),[[d2Ids[1],ids[10]],[ids[10],d2Ids[1]]]);
  assert.throws(()=>api.promotionPairs(standing(ids,18),[]),/D2/i);
  assert.throws(()=>api.promotionFixtures(pairs[0],{firstHomeId:999}),/hôte/i);
});

test('Barrages : les points précèdent l’agrégat, maintien sur égalité et annulation', () => {
  const [upper,lower] = [ids[10],d2Ids[1]];
  const pairing = api.promotionPairs(standing(ids,18),standing(d2Ids,14))[0];
  const leg = (pair,score,tries=[0,0],conversions=[0,0])=>({pair,score,tries,conversions});
  const decide = legs=>api.promotionOutcome(pairing,legs);
  const a = leg([upper,lower],[23,20],[1,2],[0,2]);
  const b = leg([lower,upper],[40,0],[5,0],[3,0]);
  assert.equal(decide([a,b]).winner,lower);
  assert.equal(decide([a,b]).method,'points');
  assert.equal(decide([leg([upper,lower],[0,0]),leg([lower,upper],[0,0])]).method,'incumbent');
  const cancelled = (pair,fault)=>({pair,status:'cancelled',fault});
  assert.equal(decide([cancelled([upper,lower],[upper]),null]).winner,lower);
  assert.throws(()=>decide([cancelled([upper,lower],[upper]),b]),/second/i);
  assert.equal(decide([a,cancelled([lower,upper],[])]).winner,upper);
  assert.equal(decide([cancelled([upper,lower],[]),cancelled([lower,upper],[upper,lower])]).winner,upper);
  assert.equal(decide([a,null]),null);
  assert.throws(()=>decide([{pair:[upper,lower],status:'pending'},cancelled([lower,upper],[upper])]),/état de manche/i);
});

test('Factory utilisable en VM sans import Node', () => {
  const context = vm.createContext({ledger,clubs});
  const len = vm.runInContext(`(${api.factory.toString()})(ledger).calendarFixtures({clubs}).length`,context);
  assert.equal(len,108);
});
