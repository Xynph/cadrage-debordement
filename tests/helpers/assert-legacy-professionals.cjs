'use strict';

const assert = require('node:assert/strict');
const { context } = require('../france-harness.cjs');

let projector;

function assertLegacyProfessionals(actual, legacy) {
  // Derive the expected youth potentials and permanent attributes. Keep the
  // catalogue, history, and prior player IDs intact.
  projector ??= context();
  projector.ctx.legacyComparison = JSON.stringify(legacy);
  projector.run('S=JSON.parse(legacyComparison)');
  projector.run('normalizeAcademyPotential(S)');
  projector.prepareNativeProjection();
  const expected = projector.state();
  const clubs = actual.clubs.map((club, index) => {
    const original = expected.clubs[index];
    const originalIds = new Set(original.players.map(player => player.id));
    const reserves = club.players.filter(player => !originalIds.has(player.id));
    assert.equal(reserves.length, legacy.live ? 0 : Math.max(0, 40 - original.players.length));
    for (const player of reserves) {
      assert.match(player.id, new RegExp(`^depth-${club.id}-${legacy.season}-[1-9]\\d*$`));
      assert.match(player.nativeAttributesV1, /^\d{72}$/);
    }
    return { ...club, players: club.players.filter(player => originalIds.has(player.id)) };
  });
  assert.deepEqual({ ...actual, clubs }, expected);
}

module.exports = { assertLegacyProfessionals };
