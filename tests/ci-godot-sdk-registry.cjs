'use strict';
// Registry contracts only: these assertions never start Godot or a career.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { allTests } = require('../ci/select-tests.cjs');
const config = require('../ci/godot-sdk-followup.json');
const root = path.resolve(__dirname, '..');
const required = [
  'godot-entity-navigation', 'godot-entity-projections', 'godot-finance-ledger-links',
  'godot-management-reading-flow', 'godot-management-reading-links', 'godot-prospect-profile',
  'godot-reader-history', 'godot-relationships-memory', 'godot-training-identity-links',
  'godot-navigation', 'godot-gestion-carnet', 'godot-staff-fictional-labels',
  'rg27-night-navigation', 'godot-world-entity-targets',
  'godot-national-reading-links', 'godot-profile-reading', 'godot-observed-training-consequences',
  'godot-effective-training-receipt',
  'godot-analysis-club-links',
  'godot-analysis-club-graphics',
].map(name => 'tests/' + name + '.cjs');

test('SDK registry groups cover every declared wrapper exactly once', () => {
  assert.deepEqual(Object.keys(config.groups).sort(), ['layouts', 'parcours', 'portraits-staff']);
  assert.equal(new Set(config.suites).size, config.suites.length);
  const grouped = Object.values(config.groups).flat();
  assert.equal(new Set(grouped).size, grouped.length);
  assert.deepEqual([...grouped].sort(), [...config.suites].sort());
  for (const suite of config.suites) {
    assert.match(suite, /^tests\/[a-z0-9-]+\.cjs$/);
    assert.ok(fs.statSync(path.join(root, suite)).isFile(), suite);
  }
  for (const suite of required) assert.ok(config.suites.includes(suite), suite);
});

test('All declared SDK variants have explicit, unique selectors', () => {
  for (const [suite, variants] of Object.entries(config.suiteCases)) {
    assert.ok(config.suites.includes(suite), suite);
    assert.ok(variants.length > 0, suite);
    assert.equal(new Set(variants.map(variant => variant.id)).size, variants.length, suite);
    for (const variant of variants) {
      assert.match(variant.id, /^[a-z0-9-]+$/);
      for (const [key, value] of Object.entries(variant.env)) {
        assert.match(key, /^CD_[A-Z0-9_]+$/);
        assert.equal(typeof value, 'string');
      }
    }
  }
});

test('Night navigation includes all seven rendered cases', () => {
  const suite = 'tests/rg27-night-navigation.cjs';
  const cases = ['reading', 'nation', 'guards', 'prospects', 'staff', 'quote', 'report'];
  assert.deepEqual(config.suiteCases[suite], cases.map(id => ({ id, env: { CD_NIGHT_NAV_CASE: id } })));
  assert.equal(config.suiteEnvironment[suite].CD_NIGHT_NAV_GRAPHICS, '1');
});

test('The report checkpoint preparer is a helper, never an automatic suite', () => {
  assert.ok(fs.existsSync(path.join(root, 'tests/rg27-night-helpers/report-prepare.cjs')));
  assert.ok(!fs.existsSync(path.join(root, 'tests/rg27-night-report-prepare.cjs')));
  assert.ok(!config.suites.some(suite => /report-prepare|night-helpers/.test(suite)));
  assert.ok(!allTests.some(suite => /report-prepare|night-helpers/.test(suite)));
});

test('Effective training cases are collected through public commands in SDK qualification', () => {
  const suite = 'tests/godot-effective-training-receipt.cjs';
  const reuse = 'CD_EFFECTIVE_TRAINING_REUSE_CASES';
  assert.ok(config.groups.parcours.includes(suite));
  assert.equal(config.suiteEnvironment[suite][reuse], '');
  for (const variant of config.suiteCases[suite] || []) assert.ok(!variant.env[reuse]);
});

test('Analysis graphics qualification uses a public career and explicit graphics opt-in', () => {
  const suite = 'tests/godot-analysis-club-graphics.cjs';
  assert.ok(config.groups['portraits-staff'].includes(suite));
  assert.equal(config.suiteEnvironment[suite].CD_ANALYSIS_CLUB_GRAPHICS, '1');
  assert.equal(config.suiteEnvironment[suite].CD_ANALYSIS_CLUB_GRAPHICS_SOURCE, '');
  for (const variant of config.suiteCases[suite] || []) {
    assert.ok(!variant.env.CD_ANALYSIS_CLUB_GRAPHICS_SOURCE);
  }
});
