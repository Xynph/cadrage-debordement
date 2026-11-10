'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { context } = require('./france-harness.cjs');
const worldVm = require('../native/engine/world-vm.cjs');
const registry = require('../native/engine/world-registry.json');

function world() {
 const h = context();
 h.ctx.nativeWorldRegistryText = JSON.stringify(registry);
 h.run(worldVm.bootstrap());
 h.run(`CDWorldCareer.start(0, 'world', true);
  while (!CDWorldCareer.userFixture(S)) CDWorldCareer.finishWeek();
  const fixture = CDWorldCareer.userFixture(S);
  while (CDWorldCareer.calendarToday(S) < fixture.date) CDWorldCareer.advanceDay(S, CDWorldCareer.calendarToday(S));`);
 return h;
}

test('the club match keeps the selected club and opposition players released to their unions', () => {
 const h = world();
 h.run(`const opposition = S.clubs[fixture.homeId === S.club ? fixture.awayId : fixture.homeId];
  const called = [S.lineup[5], buildSheet(opposition).lineup[5]];
  S.national = {role:{club:true,nation:'FRA'},career:{callups:[{nation:'FRA',from:fixture.date,through:fixture.date,playerIds:called}]}};
  beginMatch();`);
 assert.equal(h.run('S.live.sheets.every(sheet=>sheet.nominated.length===23)'), true);
 assert.equal(h.run('S.live.sheets.every(sheet=>called.every(id=>!sheet.nominated.includes(id)))'), true);
 assert.equal(h.run('called.every(id=>S.clubs.some(c=>c.players.some(p=>p.id===id)))'), true);
 assert.equal(h.run('called.every(id=>S.clubs.some(c=>c.players.some(p=>p.id===id&&!p.injury)))'), true);
 assert.equal(h.run('!!CDWorldCareer.clubReleaseOn(S,called[0])'), true);
 assert.equal(h.run('CDWorldCareer.clubReleaseOn(S,called[0],"2027-08-01")'), null);
});

test('selection-only career advances over the anchor match and records its AI result', () => {
 const h = world();
 assert.equal(h.run('CDWorldCareer.dailyStatus(S).matchReady'), true);
 h.run(`S.national = {role:{club:false,nation:'FRA'},career:{callups:[]}};`);
 assert.equal(h.run('CDWorldCareer.dailyStatus(S).canAdvance'), true);
 assert.equal(h.run('nextMatch()'), undefined);
 assert.equal(h.run('CDWorldCareer.nextOpening(S)'), '2027-08-30');
 h.run(`let anchorMatch;
  const nativeAdvance = advanceRugby;
  advanceRugby = l => {
   if (l.worldContext?.id === fixture.id && !anchorMatch) anchorMatch = l;
   nativeAdvance(l);
  };
  while (S.round === fixture.week) CDWorldCareer.advanceDay(S, CDWorldCareer.calendarToday(S));
  validateCareer(S);`);
 assert.equal(h.run('anchorMatch.userSide'), -1);
 assert.equal(h.run('S.history.some(result=>result.fixtureId===fixture.id)'), true);
 assert.equal(h.run('S.club'), 0);
});

test('the technical anchor can add injury cover without leaving invalid AI roster reports', () => {
 const h = world();
 h.run(`S.national = {role:{club:false,nation:'FRA'},career:{callups:[]}};
  const rosterBefore = new Set(S.clubs[S.club].players.map(p => p.id));
  for (const p of S.clubs[S.club].players) if (p.pos === 'Pilier gauche') p.injury = 3;
  let anchorSheet;
  const nativeAdvance = advanceRugby;
  advanceRugby = l => {
   if (l.worldContext?.id === fixture.id && !anchorSheet) anchorSheet = l.sheets[l.pair.indexOf(S.club)].nominated;
   nativeAdvance(l);
  };
  while (S.round === fixture.week) CDWorldCareer.advanceDay(S, CDWorldCareer.calendarToday(S));`);
 assert.equal(h.run('anchorSheet.length'), 23);
 assert.equal(h.run('anchorSheet.filter(id=>!rosterBefore.has(id)).length'), 2);
 assert.equal(h.run('S.clubs[S.club].players.filter(p=>!rosterBefore.has(p.id)).length'), 2);
 assert.equal(h.run('S.aiRoster.reports.some(report=>report.clubId===S.club)'), false);
 assert.equal(h.run('S.aiRoster.events.some(event=>event.clubId===S.club)'), false);
 assert.doesNotThrow(() => h.run('validateCareer(S)'));
});
