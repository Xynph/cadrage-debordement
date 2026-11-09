'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {factory} = require('../native/engine/nationale-qualification.cjs');
const Q = factory();
const season = 2026;
const own = 88;
const other = 89;
const input = {season, clubId: own};
const selected = Array.from({length:23},(_,i)=>'p'+i);
const ids = {4:'rugby-world-2026-11-09-nationale-v4',5:'rugby-world-2026-11-09-champ-v5'};
const state = v => ({club:own,commonDatabase:{id:ids[v],version:v},worldMode:{version:v,
  leagues:{nationale:{members:[own,other]}}}});
const fixture = {id:'nat:2026:league:0:0',competitionId:'nationale',phase:'league',season,homeId:own,awayId:other};
const card = (code, change={})=>({card:{code,season,clubId:own,authority:'ffr-issued',evidenceRef:'registry:test',...change}});
const fact = (kind, extra={})=>({kind,evidenceRef:'witness:test',...extra});

test('règle v4 et v5 seulement, selon division courante et rencontre canonique', () => {
  assert(Q.project(state(4),fixture,selected));
  assert(Q.project(state(5),{...fixture,phase:'final'},selected));
  assert.equal(Q.project(state(3),fixture,selected),null);
  assert.equal(Q.project(state(5),{...fixture,competitionId:'access-nationale'},selected),null);
  assert.equal(Q.project(state(5),null,selected),null);
  assert.equal(Q.project({...state(5),club:90},fixture,selected),null);
  const moved=state(5);
  moved.worldMode.leagues.nationale.members=[90,other];
  assert(Q.project({...moved,club:90},{...fixture,homeId:90},selected));
  assert.equal(Q.project({...state(5),commonDatabase:{version:5,id:'wrong'}},fixture,selected),null);
});

test('sans registre officiel, chaque joueur est non vérifié et aucune sanction proposée', () => {
  const fakeRoster = Object.fromEntries(selected.map(id=>[id,{name:'Nom',nationality:'FR',clubCountry:'FR'}]));
  const q=Q.summarize(selected,{...input,evidenceByPlayerId:fakeRoster});
  assert.equal(q.status,'unverified');
  assert.equal(q.unverified,23);
  assert.deepEqual(q.verified,{A:0,B:0,C:0});
  assert.deepEqual(q.estimates,{A:0,B:0,C:0});
  assert.equal(q.scope,'advisory-only');
  assert.equal(q.notice.summary,'B/C vérifiées 0/4 · C vérifiées 0/1');
  assert.equal(q.notice.detail,'23 cartes non vérifiées · Plafonds indéterminés.');
  assert.equal(q.notice.tone,'neutral');
});

test('23 joueurs, remplaçants inclus, deux plafonds indépendants', () => {
  const common=Object.fromEntries(selected.map(id=>[id,card('A')]));
  const good={...common,p0:card('B'),p1:card('B'),p2:card('B'),p22:card('C')};
  const q=Q.summarize(selected,{...input,evidenceByPlayerId:good});
  assert.deepEqual([q.status,q.verified.B,q.verified.C,q.limits.bc,q.limits.c],['within-bounds',3,1,4,1]);
  const over=Q.summarize(selected,{...input,evidenceByPlayerId:{...good,p21:card('B')}});
  assert.equal(over.status,'verified-excess');
  assert.equal(over.notice.tone,'alert');
  assert.equal(Q.summarize(selected,{...input,evidenceByPlayerId:{p1:card('C'),p22:card('C')}}).status,'verified-excess');
});

test('une carte ancienne, rattachée à un autre club ou à une autre autorité reste non vérifiée', () => {
  const q=Q.summarize(selected.slice(0,4),{...input,evidenceByPlayerId:{
    p0:card('A',{season:2025}),p1:card('C',{clubId:99}),p2:card('B',{authority:'club-website'}),
    p3:card('C',{evidenceRef:''}),
  }});
  assert.equal(q.unverified,4);
  assert.equal(q.status,'unverified');
});

test('une estimation exige des faits vérifiés et ne compte pas dans la conformité', () => {
  const q=Q.summarize(selected,{...input,evidenceByPlayerId:{
    p0:{facts:[fact('french-citizenship',{basis:'explicit-civil-citizenship'})]},
    p1:{facts:[fact('ffr-active-licence-history',{basis:'official-licence-records',seasons:[2019,2020,2022,2023,2025]})]},
    p2:{facts:[fact('ffr-active-licence-history',{basis:'club-history',seasons:[2019,2020,2022,2023,2025]})]},
    p3:{facts:[fact('non-a-assessment',{basis:'reviewed-dossier',season,clubId:own,
      completeCivilCitizenships:true,allABasesReviewed:true,agreementClass:'outside'})]},
    p4:{facts:[fact('non-a-assessment',{basis:'reviewed-dossier',season,clubId:own,
      completeCivilCitizenships:true,allABasesReviewed:false,agreementClass:'covered'})]},
  }});
  assert.deepEqual(q.estimates,{A:2,B:0,C:1});
  assert.equal(q.unverified,23);
  assert.equal(q.status,'unverified');
  assert.equal(q.entries[2].estimate,null);
  assert.equal(q.entries[4].estimate,null);
  assert.equal(q.notice.estimates,'Estimations documentées · A 2 · B 0 · C 1');
});

test('bornes sur une feuille partielle, doublon ignoré et aucun champ de sanction', () => {
  const evidenceByPlayerId={p0:card('B'),p1:card('A')};
  const q=Q.summarize(['p0','p1','p2',null,'p0'],{...input,evidenceByPlayerId});
  assert.equal(q.status,'within-bounds');
  assert.deepEqual(q.bounds,{bc:[1,2],c:[0,1]});
  assert.equal(q.duplicates,1);
  assert.equal(q.emptySlots,1);
  assert.equal(q.unverified,1);
  assert.equal(q.sanction,undefined);
});
