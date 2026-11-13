'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createBridge} = require('../native/engine/worker.cjs');

const directory = fs.mkdtempSync(path.join(os.tmpdir(),'oval-calendar-worker-'));
const options = {dataDir:directory,seed:248,now:1700000000000};
let bridge = createBridge(options);
let sequence = 0;
const request = (command,payload={}) => bridge.handle({id:++sequence,command,payload});
const good = (command,payload) => {
  const result = request(command,payload);
  assert.equal(result.ok,true,result.error);
  return result.model;
};

function signed(document) {
  const state = JSON.stringify(document.state);
  let checksum = 2166136261;
  for (let index = 0; index < state.length; index++) checksum = Math.imul(checksum ^ state.charCodeAt(index),16777619);
  return JSON.stringify({...document,checksum:(checksum>>>0).toString(16).padStart(8,'0')});
}

function reopen() {
  good('shutdown');
  bridge = createBridge(options);
  return good('snapshot');
}

try {
  const initial = settleClubMeetings(good('new_career',{mode:'fiction',club:0}),(command,payload)=>good(command,payload));
  const first = initial.calendarPlanning.fixtures[0];
  assert.equal(initial.calendarPlanning.simulatedDates,true);
  assert.equal(initial.calendarPlanning.today,'2026-09-07');
  assert.equal(first.date,'2026-09-12');
  assert.equal(initial.calendar[0].date,undefined,'Le calendrier historique conserve sa structure.');
  assert.ok(initial.calendarPlanning.sessions.filter(session=>session.fixtureId===first.id).length>=3);
  const legacy = good('export').meta.exportText;
  assert.equal(JSON.parse(legacy).state.calendarPlanning,undefined);
  assert.equal(JSON.parse(legacy).state.calendarMail,undefined);
  assert.equal(good('import',{text:legacy}).calendarPlanning.today,initial.calendarPlanning.today);
  good('calendar_template',{fixtureId:first.id,template:'away'});
  const planned = good('export').meta.exportText;
  assert.equal(JSON.parse(planned).state.calendarPlanning.fixtures[first.id].template,'away');
  assert.equal(request('calendar_template',{fixtureId:first.id,template:'unknown'}).ok,false);
  assert.equal(good('export').meta.exportText,planned,'Un choix invalide ne modifie pas la sauvegarde.');
  good('begin_match');
  good('delegate');
  const next = settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));
  const sessions = next.calendarPlanning.sessions;
  assert.ok(sessions.some(session=>session.date<next.calendarPlanning.today));
  assert.ok(sessions.every(session=>session.completed===(session.date<next.calendarPlanning.today)));
  assert.deepEqual(reopen().calendarPlanning.sessions,sessions);

  const world = settleClubMeetings(good('new_career',{mode:'world',club:0}),(command,payload)=>good(command,payload));
  assert.equal(world.calendarPlanning.simulatedDates,false);
  const current = world.calendar.find(fixture=>fixture.date>world.calendarPlanning.today);
  assert.ok(current);
  const document = JSON.parse(good('export').meta.exportText);
  const reference = document.state.calendarMail.fixtures.find(fixture=>fixture.id===current.id);
  const previousDate = new Date(Date.parse(current.date)-2*86400000).toISOString().slice(0,10);
  reference.date = previousDate;
  reference.planDate = previousDate;
  const scenario = signed(document);
  const delayed = good('import',{text:scenario});
  assert.equal(delayed.calendar.find(fixture=>fixture.id===current.id).date,current.date);
  const [letter] = delayed.calendarMail.filter(message=>message.status==='pending');
  assert.equal(letter.fixtureId,current.id);
  assert.equal(letter.fromDate,previousDate);
  assert.equal(letter.toDate,current.date);
  const kept = good('calendar_mail_decide',{id:letter.id,choice:'keep'});
  assert.equal(kept.calendarMail.find(message=>message.id===letter.id).status,'kept');
  assert.deepEqual(kept.calendarPlanning.sessions,delayed.calendarPlanning.sessions);
  assert.equal(reopen().calendarMail.find(message=>message.id===letter.id).status,'kept');
  const again = good('import',{text:scenario});
  const actionable = again.calendarMail.find(message=>message.status==='pending');
  const recalibrated = good('calendar_mail_decide',{id:actionable.id,choice:'recalibrate'});
  assert.equal(recalibrated.calendarMail.find(message=>message.id===actionable.id).status,'recalibrated');
  assert.equal(recalibrated.calendar.find(fixture=>fixture.id===current.id).date,current.date);
  assert.equal(request('calendar_mail_decide',{id:actionable.id,choice:'keep'}).ok,false);
  assert.deepEqual(reopen().calendarPlanning.sessions,recalibrated.calendarPlanning.sessions);
  console.log('Calendrier natif : dates simulées, import, choix, séances effectuées, courrier et reprise vérifiés.');
} finally {
  bridge.close();
  fs.rmSync(directory,{recursive:true,force:true});
}
