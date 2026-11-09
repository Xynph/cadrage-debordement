'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { context } = require('./harness.cjs');
const { normalize } = require('../dist/match3d/scene-adapter.js');

function play(project) {
  const { run } = context();
  run('start(3); S.tactic="large"; beginMatch(); continueMatch();');
  const passes = [];
  let previous;
  for (let i = 0; i < 180 && !run('S.live.finished'); i++) {
    run('if (S.live.paused) continueMatch(); S.live.tactics=["large","large"]; presentationTick(S.live);');
    if (!project) continue;
    const raw = JSON.parse(run('JSON.stringify(matchScene(S.live))'));
    const scene = normalize(raw);
    if (scene.pass && previous && previous.key !== scene.key && !run('S.live.paused')) {
      passes.push({ before: previous, scene, raw });
    }
    previous = scene;
  }
  return { passes, career: run('JSON.stringify(S)'), nextRandom: run('Math.random()') };
}

const projected = play(true);

test('Le jeu au large projette une passe arrière entre deux joueurs réellement présents', () => {
  for (const side of [0, 1]) {
    for (const period of [1, 2]) {
      assert.ok(projected.passes.some(({ scene }) => scene.possession === side && scene.period === period),
        `Aucune passe de l’équipe ${side} dans la période ${period}`);
    }
  }
  for (const { scene, raw } of projected.passes) {
    const { pass, possession: side } = scene;
    const action = raw.event.scene;
    const direction = side === 0 ? 1 : -1;
    assert.equal(action.style, 'large');
    assert.equal(action.kind, 'carry');
    assert.equal(action.actor, pass.toId);
    assert.notEqual(pass.fromId, pass.toId);
    for (const id of [pass.fromId, pass.toId]) {
      assert.ok(action.on[side].includes(id));
      assert.equal(scene.players.find(player => player.id === id).side, side);
    }
    assert.ok((pass.from.x - pass.catch.x) * direction > 0);
    assert.ok((pass.from.x - action.from.x) * direction >= 0);
    assert.ok((pass.from.x - action.from.x) * direction <= 3);
    assert.ok((scene.ball.x - pass.catch.x) * direction > 0);
    assert.deepEqual(scene.ball, action.to);
    assert.deepEqual(scene.origin, action.from);
    assert.deepEqual(normalize(raw), scene);
  }
});

test('La projection ne modifie ni carrière, ni tirage, et laisse les anciennes scènes lisibles', () => {
  const baseline = play(false);
  assert.equal(projected.career, baseline.career);
  assert.equal(projected.nextRandom, baseline.nextRandom);
  const { raw } = projected.passes[0];
  const withoutAction = { ...raw, event: undefined };
  assert.equal(normalize(withoutAction).pass, undefined);
  assert.deepEqual(normalize(withoutAction).ball, normalize(raw).ball);
  const setPiece = { ...raw, kind: 'reception', event: { ...raw.event, scene: { ...raw.event.scene, kind: 'reception' } } };
  assert.equal(normalize(setPiece).pass, undefined);
  const duplicated = { ...raw, players: [raw.players.find(p => p.featured), ...raw.players] };
  assert.equal(normalize(duplicated).pass, undefined);
});

test('Godot joue la passe issue du moteur et rend la main au porteur canonique', {
  skip: !process.env.CD_GODOT_EXE && 'SDK Godot absent',
}, () => {
  assert.ok(projected.passes.length > 0);
  const tempRoot = fs.realpathSync(os.tmpdir());
  const temporary = fs.mkdtempSync(path.join(tempRoot, 'oval-live-pass-'));
  assert.equal(path.dirname(fs.realpathSync(temporary)), tempRoot);
  try {
    const fixture = path.join(temporary, 'scenes.json');
    fs.writeFileSync(fixture, JSON.stringify(projected.passes[0]));
    const project = process.env.CD_MATCH_PROJECT || path.resolve(__dirname, '../native/godot');
    const script = path.resolve(__dirname, 'godot-match-live-pass.gd');
    const result = spawnSync(process.env.CD_GODOT_EXE, ['--headless', '--path', project, '--script', script], {
      env: { ...process.env, CD_LIVE_PASS_FIXTURE: fixture, APPDATA: temporary, LOCALAPPDATA: temporary },
      encoding: 'utf8', windowsHide: true, timeout: 60_000,
    });
    if (result.error) throw result.error;
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
    assert.match(output, /MATCH_LIVE_PASS_OK/);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});
