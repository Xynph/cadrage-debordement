'use strict';
// SDK qualification is separate from the Node shards: a missing SDK fails.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const scope = process.env.CD_GODOT_SDK_SCOPE || 'full';
if (!['full', 'followup'].includes(scope)) throw Error('Invalid SDK scope: ' + scope);
const config = {...require('./godot-sdk.json'),
  ...(scope === 'followup' ? require('./godot-sdk-followup.json') : {})};
const executable = process.env.CD_GODOT_EXECUTABLE;
if (!executable || !fs.statSync(executable, {throwIfNoEntry: false})?.isFile()) {
  throw Error('This qualification requires the real Godot SDK; skipping is forbidden.');
}
const version = spawnSync(executable, ['--version'], {encoding: 'utf8', timeout: 10000});
if (version.status !== 0 || !version.stdout.startsWith('4.7.2.stable.')) {
  throw Error('Unexpected Godot SDK version: ' + version.stdout);
}
// Mode Monde uniquement : une recette qui porte CD_MODES_HERITES (ancien mode de carrière) n'est jamais lancée.
const {legacySuites} = require('./legacy-modes.cjs');
const legacy = legacySuites();
for (const suite of config.suites.filter(suite => legacy.has(suite))) console.log('::notice::Recette exclue (ancien mode de carrière) : ' + suite);
config.suites = config.suites.filter(suite => !legacy.has(suite));
if (!config.suites.length || new Set(config.suites).size !== config.suites.length) {
  throw Error('The SDK qualification list must be nonempty and unique.');
}
const entries = [];
for (const suite of config.suites) {
  if (!/^tests\/[a-z0-9-]+\.cjs$/.test(suite) || !fs.existsSync(path.join(root, suite))) {
    throw Error('Invalid SDK suite: ' + suite);
  }
  const variants = config.suiteCases?.[suite] || [{id: 'default', env: {}}];
  if (!variants.length || new Set(variants.map(v => v.id)).size !== variants.length) {
    throw Error('SDK cases must be nonempty and unique: ' + suite);
  }
  for (const variant of variants) {
    if (!/^[a-z0-9-]+$/.test(variant.id) || !variant.env ||
        Object.entries(variant.env).some(([key, value]) => !/^CD_[A-Z0-9_]+$/.test(key) || typeof value !== 'string')) {
      throw Error('Invalid SDK case: ' + suite);
    }
    entries.push({suite, variant: variant.id, env: variant.env});
  }
}
const results = [];
for (const {suite, variant, env} of entries) {
  console.log('::group::Real SDK: ' + suite + ' / ' + variant);
  const started = Date.now();
  const result = spawnSync(process.execPath, [suite], {
    cwd: root, encoding: 'utf8', timeout: 300000, maxBuffer: 32 * 1024 * 1024,
    // Mode Monde uniquement : pas de CD_MODES_HERITES par défaut (les suites qui le portent sont exclues).
    env: {...process.env, ...(config.suiteEnvironment?.[suite] || {}), ...env,
      CD_GODOT_EXECUTABLE: executable, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath},
  });
  const output = (result.stdout || '') + (result.stderr || '');
  process.stdout.write(output);
  // Terminal colour sequences end in a letter; strip them before word checks.
  const plainOutput = output.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, '');
  const passed = !result.error && result.status === 0 && !/\bSKIP\b|SCRIPT ERROR|Parse Error|\bERROR:|\bFAIL\s*:/m.test(plainOutput);
  const record = {suite, variant, passed, status: result.status, milliseconds: Date.now() - started,
    error: result.error?.message || null};
  results.push(record);
  console.log('SDK_RESULT ' + JSON.stringify(record));
  console.log('::endgroup::');
}
if (process.env.GITHUB_STEP_SUMMARY) {
  const lines = ['## Godot SDK réel ' + config.version + ' / ' + scope, '',
    'Ces suites ont reçu un SDK réel ; tout SKIP est un échec. Audio muet et profils de test jetables.', '',
    '| Suite | Verdict | Durée |', '| --- | --- | --- |',
    ...results.map(r => `| ${r.suite} / ${r.variant} | ${r.passed ? 'PASS' : 'ÉCHEC'} | ${(r.milliseconds / 1000).toFixed(1)} s |`), ''];
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, lines.join('\n'));
}
if (results.some(r => !r.passed)) process.exitCode = 1;
