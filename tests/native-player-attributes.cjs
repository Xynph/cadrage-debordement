'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const roster = require('../dist/rugby-common-rosters.js');

const referenceKeys = Object.keys(roster.clubs[0].players[0].attributesV2).sort();
const activePlayers = state => [
  ...state.clubs.flatMap(club => club.players), ...state.development.academy,
  ...state.market, ...state.economy.freeAgents,
  ...((state.aiRoster?.academies ?? []).flatMap(center => center.players))
];

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
      if (mode === 'fiction') settleClubMeetings(created, request);
      const file = path.join(created.meta.dataDir, 'donnees.json');
      const before = fs.readFileSync(file);
      const saved = JSON.parse(JSON.parse(before).store['bdt-v1']);
      const generated = activePlayers(saved).filter(player => !player.attributesV2);
      assert.ok(generated.length > 0);
      assert.ok(generated.every(player => typeof player.nativeAttributesV1 === 'string' && player.nativeAttributesV1.length === 72));
      const source = new Map(saved.clubs[created.club.id].players.map(player => [player.id, player]));
      const model = request('snapshot');
      let detailed = 0;
      for (const player of model.squad) {
        assert.equal(Object.keys(player.attributes).length, 11);
        const original = source.get(player.id);
        assert.ok(original);
        if (original.attributesV2 === undefined) {
          assert.equal(player.attributesV2Estimated, undefined, player.id);
          assert.deepEqual(Object.keys(player.attributesV2).sort(), referenceKeys);
          assert.ok(Object.values(player.attributesV2).every(value => Number.isFinite(value) && value >= 20 && value <= 97));
          assert.equal(player.rating, original.rating);
        } else {
          assert.deepEqual(Object.keys(original.attributesV2).sort(), referenceKeys);
          assert.deepEqual(player.attributesV2, original.attributesV2, player.id);
          assert.equal(player.attributesV2Estimated, undefined);
          detailed++;
        }
      }
      assert.equal(referenceKeys.length, 36);
      assert.equal(detailed, mode === 'fiction' ? 0 : model.squad.length);
      assert.deepEqual(fs.readFileSync(file), before);
      const academy = model.decisions.development.academy;
      assert.ok(academy.length > 0);
      for (const player of academy) {
        assert.equal(player.attributesV2Estimated, undefined, player.id);
        assert.deepEqual(Object.keys(player.attributesV2).sort(), referenceKeys);
      }
      for (const player of model.market) {
        assert.equal(player.attributesV2Estimated, undefined, player.id);
        assert.equal(player.knowledge.owned, false, player.id);
        assert.equal(player.knowledge.stage, 'unobserved', player.id);
        assert.deepEqual(player.attributesV2, {}, player.id);
        assert.equal(player.rating, null, player.id);
        assert.equal(player.potential, null, player.id);
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
        bridge.close();
        // Variation can cap the first prospect: exercise growth on a player with room.
        const developing = saved.development.academy.find(player => player.dev.potential > player.rating + 1);
        assert.ok(developing);
        developing.dev.xp = 0.99;
        for (const player of generated) delete player.nativeAttributesV1;
        const older = JSON.parse(before);
        older.store['bdt-v1'] = JSON.stringify(saved);
        const oldBytes = Buffer.from(JSON.stringify(older));
        fs.writeFileSync(file, oldBytes);
        bridge = createBridge({ dataDir, seed: 93, now: 1700000000000 });
        assert.deepEqual(request('snapshot').squad.map(detail), model.squad.map(detail));
        assert.deepEqual(fs.readFileSync(file), oldBytes);
        request('save');
        const migrated = JSON.parse(JSON.parse(fs.readFileSync(file)).store['bdt-v1']);
        assert.ok(activePlayers(migrated).every(player => player.attributesV2 || player.nativeAttributesV1));
        const exported = request('export').meta.exportText;
        assert.deepEqual(request('import', { text: exported }).squad.map(detail), model.squad.map(detail));
        const byPosition = pos => model.squad.filter(player => player.pos === pos);
        const mean = (players, key) => players.reduce((sum, player) => sum + player.attributesV2[key], 0) / players.length;
        assert.ok(mean(byPosition('Pilier gauche'), 'scrumTechnique') > mean(byPosition('Ailier'), 'scrumTechnique'));
        assert.ok(mean(byPosition('Ailier'), 'topSpeed') > mean(byPosition('Pilier gauche'), 'topSpeed'));
        const prospect = academy.find(player => player.id === developing.id);
        assert.ok(prospect);
        const promoted = request('promote_academy', { playerId: prospect.id, confirmed: true });
        const professional = promoted.squad.find(player => player.id === prospect.id);
        assert.ok(professional);
        assert.deepEqual(professional.attributesV2, prospect.attributesV2);
        const trained = request('train', { mode: 'intense' }).squad.find(player => player.id === prospect.id);
        assert.equal(trained.rating, professional.rating + 1);
        assert.notDeepEqual(trained.attributesV2, professional.attributesV2);
        bridge.close();
        bridge = createBridge({ dataDir, seed: 93, now: 1700000000000 });
        assert.deepEqual(detail(request('snapshot').squad.find(player => player.id === prospect.id)), detail(trained));
        bridge.close();
        const damaged = JSON.parse(fs.readFileSync(file));
        const damagedCareer = JSON.parse(damaged.store['bdt-v1']);
        damagedCareer.clubs[created.club.id].players[0].nativeAttributesV1 += '\n';
        damaged.store['bdt-v1'] = JSON.stringify(damagedCareer);
        const damagedBytes = Buffer.from(JSON.stringify(damaged));
        fs.writeFileSync(file, damagedBytes);
        bridge = createBridge({ dataDir, seed: 93, now: 1700000000000 });
        assert.equal(request('snapshot').meta.recoveryRequired, true);
        assert.deepEqual(fs.readFileSync(file), damagedBytes);
      }
    } finally {
      bridge.close();
      assert.equal(path.dirname(path.resolve(dataDir)), temporaryRoot);
      fs.rmSync(dataDir, { recursive: true, force: true });
    }
  });
}
