'use strict';
const assert = require('node:assert/strict');
const planning = require('../native/engine/calendar-planning.cjs');

const fixture = (id, date, home = 0, away = 1) => ({id, date, home:{id:home}, away:{id:away}});
const original = {
 club:{id:0},
 meta:{season:1},
 calendar:[fixture('m1','2026-09-19'),fixture('m2','2026-09-22',1,0),fixture('m3','2026-10-10')]
};
const today = '2026-09-17';
const projected = planning.project(original, undefined, today);
assert.equal(projected.today,today);
assert.ok(projected.sessions.some(s=>s.kind==='team' && s.forwards.includes('Mêlée') && s.backs.includes('Lancements')));
assert.ok(projected.sessions.some(s=>s.fixtureId==='m1' && s.label==='Activation' && s.date==='2026-09-19'));
assert.ok(projected.sessions.every(s=>s.completed===(s.date<today)));
assert.ok(projected.sessions.some(s=>!s.fixtureId && s.date>'2026-09-24' && s.date<'2026-10-03'));
assert.ok(projected.sessions.filter(s=>s.date==='2026-09-19').every(s=>s.label==='Activation'));
assert.deepEqual(planning.project({...original,calendar:[fixture('unknown',null)]},undefined,null).sessions,[]);

const revised = {...original,calendar:[fixture('m1','2026-09-21'),...original.calendar.slice(1)]};
const change = {fixtureId:'m1',fromDate:'2026-09-19',toDate:'2026-09-21'};
assert.deepEqual(planning.project(revised,undefined,today,{anchors:[{fixtureId:'m1',date:change.fromDate}]}),projected);
const pending = planning.keepSchedule(revised, undefined, change, today);
assert.ok(planning.project(revised,pending,today).sessions.some(s=>s.fixtureId==='m1' && s.label==='Activation' && s.date==='2026-09-19'));
const rescheduled = planning.reschedule(revised, pending, change, today);
const next = planning.project(revised, JSON.parse(JSON.stringify(rescheduled)), today);
const oldPast = projected.sessions.filter(s=>s.fixtureId==='m1' && s.completed);
assert.deepEqual(next.sessions.filter(s=>s.fixtureId==='m1' && s.completed),oldPast);
assert.ok(next.sessions.some(s=>s.fixtureId==='m1' && s.label==='Activation' && s.date==='2026-09-21'));
assert.ok(!next.sessions.some(s=>s.fixtureId==='m1' && s.label==='Activation' && s.date==='2026-09-19'));
assert.deepEqual(planning.reschedule(revised,rescheduled,change,today),rescheduled);
const later = '2026-09-20';
const oldPending = planning.project(revised,pending,later);
const delayed = planning.reschedule(revised,pending,change,later);
assert.deepEqual(planning.project(revised,delayed,later).sessions.filter(s=>s.completed),oldPending.sessions.filter(s=>s.completed));
const pendingTemplate = planning.applyTemplate(revised,undefined,{fixtureId:'m1',template:'congested'},today,{anchors:[{fixtureId:'m1',date:change.fromDate}]});
assert.equal(pendingTemplate.fixtures.m1.date,change.fromDate);
assert.deepEqual(planning.project(revised,pendingTemplate,today).sessions.filter(s=>s.completed),projected.sessions.filter(s=>s.completed));

const chosen = planning.applyTemplate(original,undefined,{fixtureId:'m1',template:'congested'},today);
assert.equal(chosen.fixtures.m1.template,'congested');
assert.deepEqual(planning.project(original,chosen,today).sessions.filter(s=>s.fixtureId==='m1' && s.completed),oldPast);
assert.deepEqual(planning.project({...original,meta:{season:2}},chosen,today),projected);
assert.throws(()=>planning.applyTemplate(original,undefined,{fixtureId:'m1',template:'inconnu'},today),/programme/i);
assert.throws(()=>planning.applyTemplate(original,undefined,{fixtureId:'m1',template:'standard'},'2026-09-20'),/rencontre/i);
assert.throws(()=>planning.reschedule(revised,pending,{...change,toDate:'2026-09-23'},today),/rencontre/i);
assert.throws(()=>planning.validateState({version:1,season:1,fixtures:{m1:{date:'2026-02-30',template:'standard'}}}),/planning/i);
planning.validateState(undefined);
console.log('Planning calendrier : séances, statuts, semaines libres, choix et recalage vérifiés.');
