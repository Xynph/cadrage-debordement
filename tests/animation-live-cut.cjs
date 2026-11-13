'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { createBridge } = require('../native/engine/worker.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const { normalize } = require('../dist/match3d/scene-adapter.js');

function frame(live) {
  const { paused, finished, atBreak, scene } = live;
  return { paused, finished, atBreak, scene };
}

function capture() {
  const parent = path.resolve(os.tmpdir());
  const dataDir = fs.mkdtempSync(path.join(parent, 'oval-cut-live-'));
  const options = { dataDir, seed: 827381, now: 1700000000000 };
  const savePath = path.join(dataDir, 'PrototypeGodot', 'donnees.json');
  let bridge;
  let id = 0;

  function call(command, payload = {}) {
    const response = bridge.handle({ id: ++id, command, payload });
    assert.equal(response.ok, true, response.error);
    return response.model;
  }

  try {
    bridge = createBridge(options);
    settleClubMeetings(call('new_career',{ club: 0 }),call);
    let model = skipMatchTalk(call('begin_match'), call), live = model.live;
    const samples = [];
    const seen = new Set();
    for (let tick = 0; tick < 48 && seen.size < 2 && !live.finished; tick++) {
      model = skipMatchTalk(model, call); live = model.live;
      if (live.paused) live = call('pause', { paused: false }).live;
      const before = frame(live);
      model = call('tick'); live = model.live;
      const event = live.events.findLast(item =>
        JSON.stringify([item.min, item.text, item.scene?.kind, item.scene?.to]) === live.scene.key);
      const action = event?.scene;
      if (live.scene.key === before.scene.key || action?.kind !== 'carry'
          || action.style !== 'equilibre' || Math.abs(action.to.x - action.from.x) < 8) continue;
      const direction = event.min % 2 === 0 ? 1 : -1;
      assert.deepEqual(live.scene.cut, { carrier: String(action.actor), side: direction });
      assert.equal(live.scene.players.length, 30);
      assert.equal(live.scene.players.find(p => p.id === live.scene.cut.carrier).featured, true);
      assert.deepEqual(live.scene.ball, action.to);
      assert.equal(action.cut, undefined, 'L’indication de présentation ne figure pas dans l’événement');
      if (!seen.has(direction)) samples.push({ before, after: frame(live), event });
      seen.add(direction);
    }
    assert.equal(samples.length, 2, 'Le moteur public doit produire les deux appuis');

    call('save');
    const saved = fs.readFileSync(savePath, 'utf8');
    const exported = call('export').meta.exportText;
    for (let i = 0; i < 4; i++) assert.deepEqual(call('snapshot').live.scene, live.scene);
    assert.equal(call('export').meta.exportText, exported);
    assert.equal(fs.readFileSync(savePath, 'utf8'), saved, 'La projection ne modifie ni carrière ni curseur aléatoire');
    assert.ok(JSON.parse(exported).state.live.events.every(item => !Object.hasOwn(item.scene ?? {}, 'cut')));
    bridge.close();
    bridge = createBridge(options);
    const resumed = call('snapshot').live;
    assert.equal(resumed.paused, true, 'Un match restauré revient en pause');
    assert.deepEqual(resumed.scene.cut, live.scene.cut, 'La même action se projette depuis une sauvegarde ordinaire');
    return samples;
  } finally {
    bridge?.close();
    assert.equal(path.dirname(dataDir), parent);
    fs.rmSync(dataDir, { recursive: true, force: true });
  }
}

function checkExcluded(samples) {
  const { after, event } = samples[0];
  const original = { ...after.scene, event };
  const action = event.scene;
  const withAction = fields => ({
    ...original,
    event: { ...event, scene: { ...action, ...fields } },
  });
  const ambiguous = original.players.map(player => ({ ...player, featured: true }));
  for (const raw of [
    { ...original, event: undefined },
    { ...original, kind: 'turnover' },
    { ...original, players: ambiguous },
    withAction({ style: 'large' }),
    withAction({ move: 'maul' }),
    withAction({ actor: 'absent' }),
    withAction({ possession: 1 - action.team }),
    withAction({ to: action.from }),
  ]) {
    assert.equal(normalize(raw).cut, undefined, 'Phase absente, ambiguë ou exclue');
  }
}

function verifyGodot(samples, godot) {
  const parent = path.resolve(os.tmpdir());
  const proof = fs.mkdtempSync(path.join(parent, 'oval-godot-cut-'));
  const fixture = path.join(proof, 'fixtures.json');
  const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');
  fs.writeFileSync(fixture, JSON.stringify(samples), 'utf8');
  try {
    const run = spawnSync(godot, [
      '--headless', '--path', project, '--script', path.join(__dirname, 'godot-animation-live-cut.gd'),
    ], {
      encoding: 'utf8', windowsHide: true, timeout: 60_000,
      env: { ...process.env, CD_ANIMATION_LIVE_CUT_FIXTURE: fixture },
    });
    const output = (run.stdout || '') + (run.stderr || '');
    assert.ifError(run.error);
    assert.equal(run.status, 0, output);
    assert.match(output, /LIVE_CUT_GODOT .*"failures":\[\]/);
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
    console.log(output.trim());
  } finally {
    assert.equal(path.dirname(proof), parent);
    fs.rmSync(proof, { recursive: true, force: true });
  }
}

if (require.main === module) {
  const samples = capture();
  checkExcluded(samples);
  if (process.argv.includes('--fixture')) process.stdout.write(JSON.stringify(samples));
  else {
    console.log('Crochet en match : deux portages réels, scènes stables au rechargement, huit exclusions.');
    const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
    if (godot) verifyGodot(samples, godot);
    else console.log('Réception native du crochet non exécutée : SDK Godot absent.');
  }
}

module.exports = { capture };
