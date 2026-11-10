'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { build, knownIds } = require('../scripts/build-player-real-facts.cjs');
const evidence = require('../data/player-real-facts/observations.json');
const published = require('../native/engine/player-real-facts.json');

test('rebuilds the public catalogue from the frozen evidence', () => {
  assert.deepEqual(build(), published);
  assert.equal(knownIds().size, 5878);
  assert.equal(published.players['lnr:2449'].seniorNation, 'FRA');
  assert.equal(published.players['lnr:2449'].flagCode, 'fr');
  assert.ok(published.players['lnr:2449'].seniorCaps > 0);
  assert.ok(Object.values(published.players).some(row => row.seniorCaps === 0 && !row.seniorNation));
  assert.ok(Object.values(published.players).some(row => !Object.hasOwn(row, 'seniorCaps')));
});

test('rejects unknown IDs, duplicated fields and caps from league profiles', () => {
  const base = { ...evidence, observations: [] };
  const league = 'lnr-player-profile';
  const nation = 'nations-championship-fra';
  const buildRows = observations => build({ ...base, observations });
  const height = ['lnr:2449', league, { heightCm: 175 }];

  assert.throws(() => buildRows([['lnr:inconnu', league, { heightCm: 175 }]]), /Observation joueur invalide/);
  assert.throws(() => buildRows([height, height]), /renseigné plusieurs fois/);
  assert.throws(() => buildRows([['lnr:2449', league, { seniorCaps: 65, seniorNation: 'FRA' }]]), /Observation joueur invalide/);
  assert.throws(() => buildRows([['lnr:2449', nation, { seniorCaps: 0, seniorNation: 'FRA' }]]), /Observation joueur invalide/);
});
