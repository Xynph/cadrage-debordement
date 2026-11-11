'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const vm = require('node:vm');
const { projectAvailability } = require('../native/engine/international-availability.cjs');
const createNativeInternational = require('../native/engine/international-native.cjs');

const players = [
  {id:'hook',name:'Le talonneur',pos:'Talonneur',clubId:0,injury:0},
  {id:'cover',name:'La relève',pos:'Talonneur',clubId:0,injury:0},
  {id:'injured',name:'Le blessé',pos:'Talonneur',clubId:0,injury:2},
  {id:'other',name:'Un adversaire',pos:'Talonneur',clubId:1,injury:0},
];
const camp = {nation:'FRA',competitionId:'six-2027',from:'2027-01-31',through:'2027-02-07',playerIds:['hook','other']};
const base = {date:'2027-02-07',clubManaged:true,clubId:0,players,callups:[camp],
  releaseWindows:[{...camp,from:'2027-03-01',through:'2027-03-15'}],
  editions:[{id:'six-2027',name:'Tournoi 2027'}],teams:[{id:'FRA',name:'France'}]};

test('confirmed club absences include the final day, return on the following day, and leave opponents out', () => {
  const result = projectAvailability(base);
  assert.equal(result.absentCount,1);
  assert.equal(result.players[0].id,'hook');
  assert.equal(result.nextReturn,'2027-02-08');
  assert.deepEqual(result.positions,[{position:'Talonneur',total:3,available:1,called:1,injured:1}]);
  const returned = projectAvailability({...base,date:'2027-02-08'});
  assert.equal(returned.absentCount,0);
  assert.equal(returned.nextReturn,null);
  assert.equal(returned.returned[0].id,'hook');
  assert.equal(returned.returned[0].returnDate,'2027-02-08');
  assert.deepEqual(projectAvailability({...base,date:'2027-02-16'}).returned,[]);
});

test('announced windows remain separate from confirmed names and are grouped without duplicating nations', () => {
  const window = {competitionId:'six-2027',nation:'FRA',from:'2027-03-01',through:'2027-03-15'};
  const result = projectAvailability({...base,date:'2027-01-01',callups:[],releaseWindows:[window,window,{...window,nation:'ENG'},
    {...window,from:'2028-03-01',through:'2028-03-15'}]});
  assert.equal(result.absentCount,0);
  assert.deepEqual(result.players,[]);
  assert.equal(result.windows.length,1);
  assert.deepEqual(result.windows[0].nations.map(n=>n.id),['ENG','FRA']);
  assert.equal(result.windows[0].from,'2027-03-01');
  assert.equal(result.horizonDate,'2027-04-01');
  assert.equal('playerIds' in result.windows[0],false);
});

test('overlapping supplied releases are counted once and a new active release excludes a recent return', () => {
  const result = projectAvailability({...base,callups:[camp,{...camp,through:'2027-02-15'},
    {...camp,from:'2027-01-01',through:'2027-02-05'}]});
  assert.equal(result.absentCount,1);
  assert.equal(result.nextReturn,'2027-02-16');
  assert.deepEqual(result.returned,[]);
});

test('injuries and suspensions remain distinct from international releases in the position depth', () => {
  const result = projectAvailability({...base,players:players.map(player => player.id === 'cover' ? {...player,suspension:1} : player)});
  assert.equal(result.positions[0].total,3);
  assert.equal(result.positions[0].called,1);
  assert.equal(result.positions[0].injured,1);
  assert.equal(result.positions[0].available,0);
  assert.equal(result.absentCount,1);
});

test('return dates cross leap day and recent returns cover exactly seven calendar dates', () => {
  const release = {...camp,from:'2028-02-20',through:'2028-02-29'};
  assert.equal(projectAvailability({...base,date:'2028-02-29',callups:[release],releaseWindows:[]}).nextReturn,'2028-03-01');
  assert.equal(projectAvailability({...base,date:'2028-03-07',callups:[release],releaseWindows:[]}).returned.length,1);
  assert.equal(projectAvailability({...base,date:'2028-03-08',callups:[release],releaseWindows:[]}).returned.length,0);
});

test('selection-only mandates do not claim a managed club or its player depth', () => {
  const result = projectAvailability({...base,clubManaged:false});
  assert.equal(result.clubManaged,false);
  assert.equal(result.absentCount,0);
  assert.deepEqual(result.positions,[]);
  assert.deepEqual(result.returned,[]);
  assert.equal(result.windows.length,1);
});

test('projection cannot mutate even frozen roster, camps or calendar', () => {
  const input = structuredClone(base);
  const freeze = object => {if(object&&typeof object==='object'){Object.values(object).forEach(freeze);Object.freeze(object);}return object;};
  const before = JSON.stringify(input);
  assert.doesNotThrow(()=>projectAvailability(freeze(input)));
  assert.equal(JSON.stringify(input),before);
});

test('native career exposes confirmed absence and actual release windows without changing the career or RNG', () => {
  const player = {id:'lnr:hook',name:'Talonneur de recette',pos:'Talonneur',fam:1,age:29,rating:90,condition:100,injury:0,
    primaryPosition:2,primaryPositions:[2],secondaryPositions:[],positionRatings:{2:90},qualifiedFrontRowPositions:[2]};
  const ctx = vm.createContext({S:{club:0,clubs:[{id:0,players:[player]}],phase:'league',worldMode:{day:0}},
    CDWorldCareer:{active:()=>true,calendarToday:()=> '2027-01-31',nextOpening:()=> '2027-08-16'},roleNote:p=>p.rating,
    // Availability consumes the worker's published position contract; aptitude
    // calculations are covered by their dedicated engine/integration suites.
    nativePositionAptitudes:{project:p=>Object.fromEntries(['primaryPosition','primaryPositions','secondaryPositions','positionRatings','qualifiedFrontRowPositions'].map(key=>[key,p[key]]))}});
  const native = createNativeInternational(source=>vm.runInContext(source,ctx),ctx,
    {nations:{FRA:['France','fr']},players:{'lnr:hook':{seniorNation:'FRA',seniorCaps:5}}},true);
  native.initialize(42,{nationalRole:'dual',nation:'FRA'});
  const before = JSON.stringify(ctx.S);
  const model = {club:{id:0},meta:{calendarToday:'2027-01-31'}};
  native.project(model);
  assert.equal(model.international.availability.absentCount,1);
  const absence = model.international.availability.players[0];
  assert.equal(absence.id,player.id);
  assert.ok(absence.competitionName.includes('2027'));
  assert.ok(absence.through >= '2027-01-31');
  assert.ok(model.international.availability.windows.every(window=>window.from>'2027-01-31'));
  native.project(model);
  assert.equal(JSON.stringify(ctx.S),before);
});
