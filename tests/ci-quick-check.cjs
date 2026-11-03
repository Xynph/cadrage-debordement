'use strict';
const assert = require('node:assert/strict');
const quick = require('../ci/quick-check.cjs');
const select = require('../ci/select-tests.cjs');
assert.equal(quick.plan(['docs/notes.md']).suites.length, 0);
assert.deepEqual(quick.plan(['tests/ci-quick-check.cjs']).suites, ['tests/ci-quick-check.cjs']);
assert.equal(quick.plan(['unknown/new-module.js']).suites.length, select.allTests.length);
console.log('quick check tests PASS');
