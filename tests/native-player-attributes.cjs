'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const roster = require('../dist/rugby-common-rosters.js');

const referenceKeys = Object.keys(roster.clubs[0].players[0].attributesV2).sort();

for (const mode of ['common', 'world-champ', 'fiction']) {
  test(`Fiche joueur native · ${mode}`, () => {
    const temporaryRoot = path.resolve(os.tmpdir());
    const dataDir = fs.mkdtempSync(path.join(temporaryRoot, 'cd-player-attributes-'));
    let bridge = createBridge({ dataDir, seed: 213, now: 1700000000000 });
    let id = 0;
    const request = (command, payload = {}) => {
      const result = bridge.handle({ id: ++id, command, payload });
      assert.equal(result.ok, true, `${command}: ${result.error}`);
      return result.model;
    };

    try {
      const created = request('new_career', { mode, club: 0 });
      const file = path.join(created.meta.dataDir, 'donnees.json');
      const before = fs.readFileSync(file);
      const saved = JSON.parse(JSON.parse(before).store['bdt-v1']);
      const source = new Map(saved.clubs[created.club.id].players.map(player => [player.id, player]));
      const model = request('snapshot');
      let detailed = 0;
      for (const player of model.squad) {
        assert.equal(Object.keys(player.attributes).length, 11);
        const original = source.get(player.id);
        assert.ok(original);
        if (original.attributesV2 === undefined) {
          assert.equal(player.attributesV2Estimated, true, player.id);
          assert.deepEqual(Object.keys(player.attributesV2).sort(), referenceKeys);
          assert.ok(Object.values(player.attributesV2).every(value => Number.isFinite(value) && value >= 20 && value <= 97));
          assert.equal(player.rating, original.rating);
        } else {
          assert.deepEqual(Object.keys(original.attributesV2).sort(), referenceKeys);
          assert.deepEqual(player.attributesV2, original.attributesV2, player.id);
          assert.equal(player.attributesV2Estimated, false);
          detailed++;
        }
      }
      assert.equal(referenceKeys.length, 36);
      assert.equal(detailed, mode === 'fiction' ? 0 : model.squad.length);
      assert.deepEqual(fs.readFileSync(file), before);
      const academy = model.decisions.development.academy;
      assert.ok(academy.length > 0);
      for (const player of [...academy, ...model.market]) {
        assert.equal(player.attributesV2Estimated, true, player.id);
        assert.deepEqual(Object.keys(player.attributesV2).sort(), referenceKeys);
      }

      request('shutdown');
      bridge.close();
      bridge = createBridge({ dataDir, seed: 93, now: 1700000000000 });
      const reopened = request('snapshot');
      const detail = player => [player.id, player.rating, player.attributes, player.attributesV2];
      assert.deepEqual(reopened.squad.map(detail), model.squad.map(detail));
      assert.deepEqual(reopened.decisions.development.academy.map(detail), academy.map(detail));
      assert.deepEqual(fs.readFileSync(file), before);
      if (mode === 'fiction') {
        const byPosition = pos => model.squad.filter(player => player.pos === pos);
        const mean = (players, key) => players.reduce((sum, player) => sum + player.attributesV2[key], 0) / players.length;
        assert.ok(mean(byPosition('Pilier gauche'), 'scrumTechnique') > mean(byPosition('Ailier'), 'scrumTechnique'));
        assert.ok(mean(byPosition('Ailier'), 'topSpeed') > mean(byPosition('Pilier gauche'), 'topSpeed'));
        const prospect = academy[0];
        const promoted = request('promote_academy', { playerId: prospect.id, confirmed: true });
        const professional = promoted.squad.find(player => player.id === prospect.id);
        assert.ok(professional);
        assert.deepEqual(professional.attributesV2, prospect.attributesV2);
      }
    } finally {
      bridge.close();
      assert.equal(path.dirname(path.resolve(dataDir)), temporaryRoot);
      fs.rmSync(dataDir, { recursive: true, force: true });
    }
  });
}
