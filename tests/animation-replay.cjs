'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { fixtureScript, record } = require('../tools/animation-replay/export-fixture.cjs');

const data = record();
assert.deepEqual(data.phases.map(phase => phase.kind), ['carry', 'try', 'kickoff', 'reception']);
assert.deepEqual(data.phases.map(phase => phase.score.join('-')), ['0-0', '7-0', '7-0', '7-0']);
assert.deepEqual(data.phases[2].ball, { x: 50, y: 35 });
for (const phase of data.phases) {
  assert.equal(new Set(phase.players.map(player => player.id)).size, 30);
  assert.ok(phase.commentary.length > 0);
}
const fixture = path.resolve(__dirname, '../tools/animation-replay/fixture.js');
assert.equal(fs.readFileSync(fixture, 'utf8').replaceAll('\r\n', '\n'), fixtureScript());
console.log('Ralenti : quatre instantanés du moteur, trente joueurs, commentaire et score reproductibles.');
