'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const os = require('node:os');
const { createBridge } = require('../native/engine/worker.cjs');

function encode(doc) {
  let h = 2166136261;
  for (const c of JSON.stringify(doc.state)) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  doc.checksum = (h >>> 0).toString(16).padStart(8, '0');
  return JSON.stringify(doc);
}
function worker(t) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-prevision-'));
  const bridge = createBridge({ dataDir: profile, seed: 409, now: 1700000000000 });
  t.after(() => { bridge.close(); fs.rmSync(profile, { recursive: true, force: true }); });
  let id = 0;
  const call = (command, payload = {}, expected = true) => {
    const response = bridge.handle({ id: ++id, command, payload });
    assert.equal(response.ok, expected, `${command}: ${response.error}`);
    return response.model;
  };
  const read = () => JSON.parse(call('export').meta.exportText);
  return { call, read };
}
const support = model => model.clubLife.clubSupport;
const roster = state => state.clubs[state.club].players;
const plan = (model, key) => support(model).training.plans.find(option => option.key === key);
const player = (state, id) => roster(state).find(p => p.id === id);
function staged(w, {condition=70, delegated=true, highLoad=false}={}) {
  w.call('new_career', { mode: 'common', club: 29 });
  const doc = w.read();
  const state = doc.state;
  state.training = 'intense';
  state.manager.delegation.training = delegated;
  for (const p of roster(state)) {
    p.condition = condition;
    p.physicalLoad = { version: 1, fatigue: 30, plan: 'collective' };
  }
  const [starter, exception] = state.lineup;
  if (highLoad) player(state, exception).physicalLoad.fatigue = 50;
  const model = w.call('import', { text: encode(doc) });
  return { model, starter, exception };
}

for (const [condition, expectedMode, expectedCondition, expectedLoad] of [[70,'repos',99,10],[75,'normal',93,20]]) {
  test(`délégation sous/au seuil ${condition} : la proposition rejoint la séance ${expectedMode}`, t => {
    const w = worker(t);
    const {model, starter, exception} = staged(w, {condition,highLoad:true});
    const saved = w.read();
    const option = plan(model,'equilibrer');
    const predicted = option.players.find(p=>p.id===starter);
    assert.equal(predicted.plan,'collective');
    assert.deepEqual([predicted.condition,predicted.fatigue],[expectedCondition,expectedLoad]);
    assert.equal(predicted.effectiveMode,expectedMode);
    assert.equal(option.collective.mode,expectedMode);
    assert.match(option.collective.reason,condition<75?/sous 75 %/u:/au moins 75 %/u);
    const resting = option.players.find(p=>p.id===exception);
    assert.equal(resting.plan,'repos');
    assert.equal(resting.effectiveMode,'repos');
    assert.equal(option.counts.collective,option.players.length-1);
    assert.equal(option.effectiveCounts[expectedMode],expectedMode==='repos'?option.players.length:option.players.length-1);
    w.call('snapshot');assert.deepEqual(w.read(),saved,'la prévision est en lecture seule');
    const context = support(model).context;
    w.call('training_plan',{context,plan:'equilibrer'});
    const configured = w.read().state;
    assert.equal(configured.training,'normal');
    assert.equal(player(configured,starter).physicalLoad.plan,'collective');
    assert.equal(player(configured,starter).condition,condition,'configurer ne lance pas la séance');
    const executed = w.call('train',{mode:'intense'});
    const actual = w.read().state;
    assert.equal(actual.training,expectedMode,'la délégation garde la priorité réelle');
    assert.equal(player(actual,starter).condition,expectedCondition);
    assert.equal(player(actual,starter).physicalLoad.fatigue,expectedLoad);
    assert.equal(support(executed).training.session.status,'applied');
    assert.match(support(executed).training.session.reason,new RegExp(`condition moyenne de ${condition}%`,'u'));
    assert.deepEqual(support(executed).training.plans,[],'aucune projection suivante affichée comme un résultat');
    const toggled = w.call('set_delegation',{key:'training',enabled:false});
    assert.deepEqual(support(toggled).training.session,support(executed).training.session,'le reçu réel survit au changement de réglage');
    w.call('training_plan',{context,plan:'proteger'},false);
  });
}

test('sans délégation, le plan remet le mode collectif à normal et conserve les exceptions', t => {
  const w = worker(t);
  const {model, starter, exception} = staged(w,{delegated:false,highLoad:true});
  const option = plan(model,'equilibrer');
  const projected = option.players.find(p=>p.id===starter);
  assert.deepEqual([projected.plan,projected.effectiveMode,projected.condition,projected.fatigue],['collective','normal',88,20]);
  assert.match(option.collective.reason,/mode collectif normal/u);
  assert.equal(option.players.find(p=>p.id===exception).effectiveMode,'repos');
  const context = support(model).context;
  w.call('training_plan',{context,plan:'equilibrer'});
  const executed = w.call('train');
  const actual = w.read().state;
  assert.equal(player(actual,starter).condition,88);
  assert.equal(player(actual,starter).physicalLoad.fatigue,20);
  assert.equal(support(executed).training.session.status,'applied');
  assert.equal(support(executed).training.session.reason,null,'aucun reçu inventé si le moteur ne l’a pas enregistré');
});

test('les joueurs blessés et la relève gardent leur mode individuel sous délégation', t => {
  const w = worker(t);
  staged(w);
  const doc = w.read();
  const old = roster(doc.state).find(p=>!doc.state.lineup.includes(p.id)&&p.age<=23);
  assert(old);
  old.condition=85;old.physicalLoad.fatigue=0;
  const injured = player(doc.state,doc.state.lineup[0]);
  injured.injury=1;injured.condition=58;
  const model = w.call('import',{text:encode(doc)});
  const option = plan(model,'relever');
  assert.equal(option.players.find(p=>p.id===old.id).effectiveMode,'intense');
  assert.equal(option.players.find(p=>p.id===injured.id).effectiveMode,'repos');
  assert.equal(option.collective.mode,'repos');
});
