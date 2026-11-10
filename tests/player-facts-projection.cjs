'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const createFacts = require('../native/engine/player-facts.cjs');

const facts = createFacts({ players: {
  known: { nationality: 'Australie', flagCode: 'au', seniorNation: 'FRA', seniorCaps: 22, heightCm: 189, weightKg: 108 },
  uncapped: { nationality: 'France', flagCode: 'fr', seniorCaps: 0, eligibilityNations: ['FRA'] },
}}, { unknown: 'JPN' }, { 4: 'ENG' });

test('La fiche sépare l’origine de la sélection et ajoute les caps de la partie', () => {
  const profile = facts.project('known', { nation: 'FRA', career: 3 });
  assert.equal(profile.flagCode, 'au');
  assert.equal(profile.seniorFlagCode, 'fr');
  assert.equal(profile.seniorCaps, 25);
  assert.equal(profile.heightCm, 189);
  assert.equal(profile.weightKg, 108);
  assert.equal(profile.capsSource, 'documented');
  assert.equal(facts.eligible('known', 'AUS'), false);
  assert.equal(facts.eligible('known', 'FRA'), true);
});

test('Les données manquantes gardent un zéro et une origine stable', () => {
  const profile = facts.project('unknown');
  assert.equal(profile.seniorCaps, 0);
  assert.equal(profile.capsSource, 'game-default');
  assert.equal(profile.nationalitySource, 'simulated');
  assert.ok(profile.nationality && profile.flagCode);
  assert.equal(profile.heightCm, null);
  assert.deepEqual(facts.project('unknown'), profile);
  assert.deepEqual(facts.project('depth-4-1-12'), facts.project('depth-4-1-12'));
  assert.equal(facts.project('uncapped').capsSource, 'documented');
  assert.equal(facts.project('uncapped').seniorCaps, 0);
  assert.equal(facts.project('uncapped').seniorNation, null);
});
