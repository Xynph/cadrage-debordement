'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../native/engine/worker.cjs');

const depth = {
  'Pilier gauche': 2, 'Talonneur': 2, 'Pilier droit': 2,
  'Deuxième ligne': 4, 'Troisième ligne': 4, 'Numéro 8': 2,
  'Demi de mêlée': 2, 'Demi d’ouverture': 2, 'Ailier': 4, 'Centre': 4, 'Arrière': 2,
};

function seal(document) {
  const raw = JSON.stringify(document.state);
  let h = 2166136261;
  for (let i = 0; i < raw.length; i++) h = Math.imul(h ^ raw.charCodeAt(i), 16777619);
  return JSON.stringify({ ...document, checksum: (h >>> 0).toString(16).padStart(8, '0') });
}

for (const [mode, club] of [['common', 29], ['world-champ', 102]]) {
  test(`Effectifs disjoints de tous les centres · ${mode}`, t => {
    const tmp = path.resolve(os.tmpdir());
    const dataDir = fs.mkdtempSync(path.join(tmp, 'oval-academy-groups-'));
    const options = { dataDir, seed: 827381, now: 1794178800000 };
    let bridge = createBridge(options);
    let id = 0;
    const ask = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
    const ok = (command, payload) => {
      const result = ask(command, payload);
      assert.equal(result.ok, true, `${command}: ${result.error}`);
      return result.model;
    };
    const archive = () => ok('export').meta.exportText;
    t.after(() => {
      bridge.close();
      assert.equal(path.dirname(dataDir), tmp);
      fs.rmSync(dataDir, { recursive: true, force: true });
    });

    const model = ok('new_career', { mode, club });
    const saved = archive();
    const document = JSON.parse(saved);
    const academy = document.state.development.academy;
    assert.equal(document.state.academyGroupPolicy, 2);
    const groups = [academy.filter(p => p.age <= 18), academy.filter(p => p.age >= 19 && p.age <= 21)];
    const centers = [{ clubId: club, players: academy }, ...document.state.aiRoster.academies];
    assert.deepEqual(centers.map(center => center.clubId).sort((a, b) => a - b), document.state.clubs.map(c => c.id));
    const ids = new Set([...document.state.clubs.flatMap(c => c.players), ...document.state.economy.freeAgents].map(p => p.id));
    for (const { clubId, players } of centers) {
      assert.equal(players.length, 60, `centre ${clubId}`);
      for (const group of [players.filter(p => p.age <= 18), players.filter(p => p.age >= 19 && p.age <= 21)]) {
        assert.equal(group.length, 30);
        for (const [position, slots] of Object.entries(depth)) {
          assert.equal(group.filter(p => p.pos === position).length, slots, `${clubId} ${position}`);
        }
      }
      assert.ok(players.every(p => p.appearanceBankVersion === 2 && p.academy && p.contractEnd == null));
      for (const player of players) {
        assert.ok(!ids.has(player.id), player.id);
        ids.add(player.id);
      }
    }
    assert.ok(Array.from({length: 15}, (_, serial) => `youth-${club}-1-${serial}`).every(id => academy.some(p => p.id === id)));
    assert.ok(model.decisions.development.academy.every(p => Object.keys(p.attributesV2).length === 36));
    assert.ok(academy.every(p => !document.state.market.some(q => q.id === p.id)));
    assert.deepEqual(ok('snapshot').decisions.development.academy.map(p => p.id), model.decisions.development.academy.map(p => p.id));
    assert.equal(archive(), saved);
    bridge.close();
    bridge = createBridge(options);
    assert.equal(archive(), saved);

    const idToPromote = groups[1][0].id;
    const promoted = ok('promote_academy', { playerId: idToPromote, confirmed: true });
    assert.equal(promoted.decisions.development.academy.filter(p => p.age >= 19).length, 29, 'la prochaine arrivée est annuelle');
    assert.ok(promoted.squad.some(p => p.id === idToPromote));

    document.state.academyGroupPolicy = 1;
    for (const center of document.state.aiRoster.academies) center.players = [];
    const formerPolicy = ok('import', { text: seal(document) });
    assert.equal(formerPolicy.decisions.development.academy.length, 60);
    assert.equal(JSON.parse(archive()).state.academyGroupPolicy, 1);
    delete document.state.academyGroupPolicy;
    document.state.development.academy = academy.filter(p => /-1-\d{1,2}$/.test(p.id));
    assert.equal(document.state.development.academy.length, 15);
    const legacy = ok('import', { text: seal(document) });
    assert.equal(legacy.decisions.development.academy.length, 15);
    const old = archive();
    assert.equal(JSON.parse(old).state.academyGroupPolicy, undefined);
    bridge.close();
    bridge = createBridge(options);
    assert.equal(archive(), old);
  });
}
