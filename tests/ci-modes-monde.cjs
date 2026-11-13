'use strict';
// Mode Monde uniquement (décision de Léo, 13/11/2026) : aucune suite exécutée par la CI ne crée une carrière
// hors du mode Monde (world-champ). Une suite qui en a encore besoin porte en tête le drapeau des anciens
// modes et est exclue de toute exécution (shards JS, suites Godot, sélection de développement, workflows).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { legacyFiles, legacySuites, legacyCreations, filterLegacy } = require('../ci/legacy-modes.cjs');
const { allTestFiles, testFilesOnDisk, legacyTestFiles, godotTestFiles, planShards, suitesForShard } = require('../ci/shard-tests.cjs');
const { selectTests, allTests } = require('../ci/select-tests.cjs');

const root = path.resolve(__dirname, '..');
const FLAG = 'CD_MODES_' + 'HERITES';
const legacy = legacySuites();
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const walk = dir => fs.readdirSync(path.join(root, dir), { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? walk(path.join(dir, entry.name)) : /\.c?js$/.test(entry.name) ? [path.join(dir, entry.name).split(path.sep).join('/')] : []);

test('toute suite ou aide exécutée qui crée une carrière hors world-champ porte le drapeau et est exclue', () => {
  const offenders = [];
  for (const file of walk('tests')) {
    if (legacy.has(file)) continue;
    const found = legacyCreations(file);
    if (found.length) offenders.push(file + ' : ' + found.join(', '));
  }
  assert.deepEqual(offenders, [], 'Carrière hors mode Monde dans une suite exécutée : migrer vers world-champ (club 0) ou marquer\n' +
    'la suite en tête avec process.env.' + FLAG + "='1' (elle sera exclue de la CI)\n" + offenders.join('\n'));
});

test('le drapeau, direct ou hérité par un module chargé, exclut la suite de la liste exécutée', () => {
  const onDisk = testFilesOnDisk(), executed = allTestFiles(), excluded = legacyTestFiles();
  assert.deepEqual([...executed, ...excluded].sort(), onDisk);
  assert.ok(excluded.length > 0 && executed.length > 0);
  for (const file of onDisk) {
    const marked = read(file).includes(FLAG);
    if (marked) assert.ok(excluded.includes(file), file + ' porte le drapeau mais reste exécutée');
    else if (excluded.includes(file)) assert.match(legacyFiles().get(file), /^via /, file);
  }
  for (const file of executed) assert.ok(!read(file).includes(FLAG), file);
  // Chargé par chemin construit (path.join) : un module qui charge le harnais des anciens modes sans le
  // nommer en dur hérite du drapeau. Les suites migrées chargent tests/monde-harness.cjs de la même façon.
  assert.equal(legacyFiles().get('tests/france-harness.cjs'), 'drapeau');
  const constructed = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-legacy-path-'));
  try {
    // Chemin assemblé ici pour que cette suite ne charge pas elle-même le harnais.
    const parts = ['tests', 'france-harness.cjs'].map(part => JSON.stringify(part)).join(',');
    fs.writeFileSync(path.join(constructed, 'construit.cjs'), "const path=require('node:path');require(path.join(repo," + parts + '));');
    assert.deepEqual([...legacyFiles(constructed).values()], ['via tests/france-harness.cjs']);
  } finally { fs.rmSync(constructed, { recursive: true, force: true }); }
  assert.ok(!legacy.has('tests/monde-harness.cjs') && executed.includes('tests/japan-match.cjs'));
  // Le moteur et les outils de CI parlent du drapeau sans tourner dans un ancien mode : jamais « hérités ».
  for (const file of ['ci/legacy-modes.cjs', 'ci/shard-tests.cjs', 'ci/select-tests.cjs', 'native/engine/worker.cjs'])
    assert.ok(!legacy.has(file), file);
  assert.ok(executed.includes('tests/ci-modes-monde.cjs'));
});

test('shards JS, jobs Godot et sélection de développement ne contiennent aucune suite exclue', () => {
  const executed = new Set(allTestFiles());
  const full = planShards(allTestFiles()).flat();
  assert.deepEqual(full.slice().sort(), [...executed].sort());
  for (const shard of [1, 4, 7]) for (const file of suitesForShard(shard, 'full')) assert.ok(!legacy.has(file), file);
  for (const shard of [1, 2, 3]) for (const file of suitesForShard(shard, 'godot')) assert.ok(!legacy.has(file), file);
  assert.ok(godotTestFiles().every(file => executed.has(file)));
  assert.ok(allTests.every(file => !legacy.has(file)));
  // Un changement de test exclu ne déclenche rien ; une dépendance exclue n'impose pas la couverture totale.
  const some = legacyTestFiles()[0];
  assert.deepEqual(selectTests([some]), []);
  for (const file of selectTests(['dist/saves.js', 'dist/game.js', 'dist/rugby.js'])) assert.ok(!legacy.has(file), file);
  assert.deepEqual(filterLegacy([some, 'tests/ci-modes-monde.cjs']), { kept: ['tests/ci-modes-monde.cjs'], excluded: [some] });
});

test('manifestes SDK, poids, listes de débogage et workflows ne nomment aucune suite exclue', () => {
  const weights = require('../ci/suite-weights.json');
  for (const section of [weights.js.weights, weights.godot.weights, weights.memory.suites])
    for (const suite of Object.keys(section)) assert.ok(!legacy.has(suite), 'poids d\'une suite exclue : ' + suite);
  for (const manifest of ['ci/godot-sdk.json', 'ci/godot-sdk-followup.json']) {
    for (const suite of JSON.parse(read(manifest)).suites) assert.ok(!legacy.has(suite), manifest + ' : ' + suite);
  }
  for (const line of read('ci/debug-suites.txt').split('\n').map(l => l.trim()).filter(Boolean))
    assert.ok(line === 'ALL' || !legacy.has(line), 'ci/debug-suites.txt : ' + line);
  const named = [];
  for (const entry of fs.readdirSync(path.join(root, '.github/workflows'))) {
    const text = read('.github/workflows/' + entry);
    for (const match of text.matchAll(/\btests\/[A-Za-z0-9._-]+\.cjs\b/g)) {
      // Les commentaires qui expliquent l'exclusion ne comptent pas : seules les commandes comptent.
      const line = text.slice(text.lastIndexOf('\n', match.index) + 1, text.indexOf('\n', match.index));
      if (/^\s*#/.test(line)) continue;
      if (legacy.has(match[0])) named.push(entry + ' : ' + match[0]);
    }
  }
  assert.deepEqual(named, [], 'Workflow qui exécute une suite à ancien mode de carrière');
});

test('les lanceurs Godot n\'exportent plus le drapeau et écartent les suites exclues', () => {
  const shell = read('ci/run-godot-suites.sh'), sdk = read('ci/run-godot-sdk.cjs');
  assert.ok(!new RegExp('^\\s*export\\s+' + FLAG, 'm').test(shell), 'export global du drapeau');
  assert.ok(!new RegExp(FLAG + '\\s*[:=]\\s*[\'"]?1').test(sdk), 'drapeau par défaut du lanceur SDK');
  assert.match(shell, /legacy-modes\.cjs" filter/);
  assert.match(read('ci/run-shard-suites.sh'), /legacy-modes\.cjs" filter/);
  assert.match(sdk, /legacy-modes\.cjs/);
  // Filtre en ligne de commande : une liste mêlant suites exécutées et exclues ne garde que les premières.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-modes-'));
  try {
    const list = path.join(dir, 'liste.txt');
    const excluded = legacyTestFiles()[0];
    fs.writeFileSync(list, excluded + '\ntests/ci-modes-monde.cjs\n');
    const run = spawnSync(process.execPath, [path.join(root, 'ci/legacy-modes.cjs'), 'filter', list], { encoding: 'utf8' });
    assert.equal(run.status, 0);
    assert.equal(run.stdout, 'tests/ci-modes-monde.cjs\n');
    assert.match(run.stderr, new RegExp(excluded.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
    assert.equal(spawnSync(process.execPath, [path.join(root, 'ci/legacy-modes.cjs'), 'is', excluded]).status, 0);
    assert.equal(spawnSync(process.execPath, [path.join(root, 'ci/legacy-modes.cjs'), 'is', 'tests/ci-modes-monde.cjs']).status, 1);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('la règle du mode Monde uniquement figure dans AGENTS.md', () => {
  const text = read('AGENTS.md').replace(/\s+/g, ' ');
  assert.ok(text.includes('Mode Monde uniquement (décision de Léo, 13/11/2026)'));
  assert.ok(text.includes('tout nouveau test crée une carrière world-champ'));
  assert.ok(text.includes('marqués ' + FLAG + ' sont exclus de la CI'));
});
