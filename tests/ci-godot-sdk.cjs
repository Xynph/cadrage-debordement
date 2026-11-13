'use strict';
// Controller unit tests only: no real Godot, game, profile or child is launched.
const fs = require('node:fs'), vm = require('node:vm');
const path = require('node:path'), assert = require('node:assert/strict');
const source = fs.readFileSync(path.join(__dirname, '../ci/run-godot-sdk.cjs'), 'utf8');
function run({missing = false, version = '4.7.2.stable.official.ed1daf0bf',
  output = 'PASS fixture\n', status = 0, error = null, variants, scope = 'full', suites = ['tests/probe.cjs']} = {}) {
  const config = {version: '4.7.2-stable', suites};
  if (variants) config.suiteCases = {'tests/probe.cjs': variants};
  let calls = 0, thrown = null;
  const processStub = {env: missing ? {} : {CD_GODOT_EXECUTABLE: '/qa/godot', CD_GODOT_SDK_SCOPE: scope},
    execPath: process.execPath, stdout: {write() {}}};
  try {
    vm.runInNewContext(source, {
      __dirname: path.resolve(__dirname, '../ci'), process: processStub,
      console: {log() {}}, require(id) {
        if (id === 'node:fs') return {statSync: () => ({isFile: () => true}), existsSync: () => true};
        if (id === 'node:path') return path;
        if (id === './legacy-modes.cjs') return require('../ci/legacy-modes.cjs');
        if (id === './godot-sdk.json') return config;
        if (id === './godot-sdk-followup.json') return {suites: ['tests/new-a.cjs', 'tests/new-b.cjs'], suiteCases: {}, suiteEnvironment: {}};
        if (id === 'node:child_process') return {spawnSync(_executable, args) {
          if (args[0] === '--version') return {status: 0, stdout: version};
          calls++;
          return {status, stdout: output, stderr: '', error};
        }};
        throw Error('Unexpected dependency ' + id);
      },
    }, {timeout: 1000});
  } catch (e) { thrown = e; }
  return {failed: !!thrown || processStub.exitCode === 1, calls};
}
const rejected = [
  {scope: 'invalid'}, {missing: true}, {version: '4.6.stable'}, {output: 'SKIP SDK absent'},
  {output: 'ok 1 # SKIP absent'}, {output: '\x1b[33mSKIP SDK absent\x1b[0m'},
  {output: 'SCRIPT ERROR: invalid'}, {output: 'Parse Error: invalid'},
  {output: '\x1b[31mERROR: resource missing\x1b[0m'},
  {output: 'CONTEXTUAL FAIL: rejected'}, {status: 1},
  {status: null, error: Error('timeout')}, {variants: []},
];
for (const item of rejected) assert.equal(run(item).failed, true, JSON.stringify(item));
assert.deepEqual(run(), {failed: false, calls: 1});
assert.deepEqual(run({variants: [
  {id: 'layout', env: {CD_GUIDE_LAYOUT_CASE: 'layout'}},
  {id: 'dock', env: {CD_GUIDE_LAYOUT_CASE: 'dock'}},
]}), {failed: false, calls: 2}, 'Every explicit case must be executed');
assert.deepEqual(run({scope: 'followup'}), {failed: false, calls: 2}, 'Followup executes its manifest without default suites');
// Mode Monde uniquement : une recette qui porte le drapeau des anciens modes n'est jamais lancée, et le lanceur
// ne l'exporte pas par défaut.
assert.deepEqual(run({suites: ['tests/godot-engine.cjs', 'tests/probe.cjs']}), {failed: false, calls: 1}, 'Legacy-mode suite is excluded');
assert.ok(!new RegExp('CD_MODES_' + 'HERITES\\s*:').test(source), 'No default legacy-modes flag for the suites');
console.log(JSON.stringify({controllerUnit: true, cases: rejected.length + 4,
  passed: true, realGodotExecuted: false}));
