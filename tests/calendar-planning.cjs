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
assert.deepEqual(projected.appliedTemplates,{});
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
const withArchived = {...chosen,fixtures:{...chosen.fixtures,archived:{date:'2026-09-20',template:'away'}}};
const storedBeforeProjection = JSON.stringify(withArchived);
assert.deepEqual(planning.project(original,withArchived,today).appliedTemplates,{m1:'congested'});
assert.equal(JSON.stringify(withArchived),storedBeforeProjection);
const withPlayed = {...original,calendar:[{...original.calendar[0],played:true},...original.calendar.slice(1)]};
assert.deepEqual(planning.project(withPlayed,chosen,today).appliedTemplates,{});
assert.deepEqual(planning.project(original,chosen,today).sessions.filter(s=>s.fixtureId==='m1' && s.completed),oldPast);
assert.deepEqual(planning.project({...original,meta:{season:2}},chosen,today),projected);
assert.throws(()=>planning.applyTemplate(original,undefined,{fixtureId:'m1',template:'inconnu'},today),/programme/i);
assert.throws(()=>planning.applyTemplate(original,undefined,{fixtureId:'m1',template:'standard'},'2026-09-20'),/rencontre/i);
assert.throws(()=>planning.reschedule(revised,pending,{...change,toDate:'2026-09-23'},today),/rencontre/i);
assert.throws(()=>planning.validateState({version:1,season:1,fixtures:{m1:{date:'2026-02-30',template:'standard'}}}),/planning/i);
planning.validateState(undefined);

// Une seule séance d'un jour remplacée (fiche de séance, 23/11/2026) : même jour, même place, nouvelle famille.
const avenir = projected.sessions.find(s=>!s.completed && s.fixtureId==='m3' && s.kind==='strength');
const swap = planning.swapSession(original,undefined,{sessionId:avenir.id,kind:'recovery',label:'Mobilité'},today);
planning.validateState(swap);
const apres = planning.project(original,swap,today).sessions;
const remplacee = apres.find(s=>s.sourceId===avenir.id);
assert.ok(remplacee && remplacee.kind==='recovery' && remplacee.label==='Mobilité' && remplacee.date===avenir.date && remplacee.swapped);
assert.equal(apres.filter(s=>s.date===avenir.date).findIndex(s=>s.sourceId===avenir.id),
 projected.sessions.filter(s=>s.date===avenir.date).findIndex(s=>s.id===avenir.id),'même place dans la journée');
assert.equal(apres.length,projected.sessions.length);
assert.throws(()=>planning.swapSession(original,swap,{sessionId:avenir.id,kind:'recovery',label:'Inventée'},today),/séance/i);
const passee = projected.sessions.find(s=>s.completed);
assert.throws(()=>planning.swapSession(original,undefined,{sessionId:passee.id,kind:'recovery',label:'Mobilité'},today),/séance/i);
assert.equal(planning.swapSession(original,swap,{sessionId:avenir.id,kind:avenir.kind,label:avenir.label},today).swaps,undefined,'retour à la séance d’origine');
assert.equal(planning.applyTemplate(original,swap,{fixtureId:'m3',template:'congested'},today).swaps,undefined,'nouvelle semaine type : remplacements du match effacés');
assert.throws(()=>planning.validateState({version:1,season:1,fixtures:{},swaps:{x:{kind:'recovery',label:'Inventée'}}}),/planning/i);
// Une fois passée, la séance remplacée entre dans l'historique sous sa nouvelle famille (format validé).
const plusTard = planning.swapSession(original,swap,{sessionId:projected.sessions.find(s=>s.fixtureId==='m3' && s.date>='2026-10-09' && s.kind!=='video').id,kind:'video',label:'Vidéo'},'2026-10-09');
planning.validateState(plusTard);
assert.ok(plusTard.history.some(s=>s.id===remplacee.id && s.kind==='recovery' && !('sourceId' in s)));
console.log('Planning calendrier : séances, statuts, semaines libres, choix et recalage vérifiés.');
