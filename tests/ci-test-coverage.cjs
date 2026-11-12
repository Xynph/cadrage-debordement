'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { allTestFiles, planShards } = require('../ci/shard-tests.cjs');
const { classify, readDiffs, suitesForCoverage } = require('../ci/test-coverage.cjs');

const modification = file => ({ file, status: 'M', oldMode: '100644', newMode: '100644' });
const coverage = (files, event = 'pull_request') => classify(event, [files.map(modification)]);

test('seules les présentations statiques reconnues et la documentation sont allégées', () => {
  assert.equal(coverage(['docs/reception.md', 'README.md']), 'documentation');
  assert.equal(coverage(['dist/style.css', 'dist/assets/menu-stadium.webp']), 'web');
  assert.equal(coverage(['dist/assets/club-atlas/castres-city.webp', 'dist/assets/club-atlas/manifest.json']), 'web');
  assert.equal(coverage(['native/godot/art/immersive08/stadium.png', 'native/godot/art/immersive08/manifest.json']), 'native-art');
  for (const file of [
    'dist/inconnu.css', 'dist/assets/inconnu.png', 'dist/game.js', 'dist/saves.js',
    'dist/index.html', 'native/godot/ui/immersive08/match_canvas.gd', 'data/competition.json',
    'native/godot/art/regen-bank-v2/catalogue.json', 'docs/regen-bank-v2/player-trait-plan.json', 'docs/script.cjs',
    'tools/animation-pipeline/compare_skin.py', '.github/workflows/tests.yml', 'ci/test-coverage.cjs'
  ]) assert.equal(coverage([file]), 'full', file);
  assert.equal(coverage(['dist/style.css', 'docs/reception.md']), 'full');
  assert.equal(coverage(['dist/style.css', 'native/godot/art/immersive08/stadium.png']), 'full');
  assert.equal(coverage(['dist/style.css', 'dist/saves.js']), 'full');
  assert.equal(coverage(['dist/style.css'], 'push'), 'full');
  assert.equal(coverage(['dist/style.css'], 'workflow_dispatch'), 'full');
  assert.equal(coverage([]), 'full');
  assert.equal(classify('pull_request', null), 'full');
});

test('un lot de management et sauvegardes comme la PR #424 reste complet', () => {
  assert.equal(coverage([
    'docs/deepen-market.md', 'dist/game.js', 'dist/saves.js', 'native/engine/worker.cjs',
    'native/godot/ui/immersive08/match_canvas.gd', 'dist/style.css'
  ]), 'full');
});

test('ajouts réguliers admis, retraits, renommages et changements de mode exhaustifs', () => {
  const image = modification('native/godot/art/immersive08/new-hero.png');
  const assess = change => classify('pull_request', [[change]]);
  assert.equal(assess({ ...image, status: 'A', oldMode: '000000' }), 'native-art');
  assert.equal(assess({ ...image, status: 'D', newMode: '000000' }), 'full');
  assert.equal(assess({ ...image, status: 'R100' }), 'full');
  assert.equal(assess({ ...image, status: 'C100' }), 'full');
  assert.equal(assess({ ...image, newMode: '100755' }), 'full');
  assert.equal(assess({ ...image, newMode: '120000' }), 'full');
});

test('diff Git complet des parents réels, y compris un chemin déjà corrigé dans main', t => {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-ci-diff-'));
  t.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', ['-c', 'user.name=CI', '-c', 'user.email=ci@example.test',
    '-c', 'commit.gpgsign=false', ...args], { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  const write = (file, content) => {
    fs.mkdirSync(path.dirname(path.join(cwd, file)), { recursive: true });
    fs.writeFileSync(path.join(cwd, file), content);
  };
  const commit = title => {
    git('add', '--all');
    git('commit', '-m', title);
    return git('rev-parse', 'HEAD').trim();
  };
  git('init', '-b', 'main');
  write('dist/style.css', 'body { color: red }\n');
  write('dist/saves.js', 'const version = 1;\n');
  write('docs/réception du jeu.md', '# Réception\n');
  const fork = commit('base commune');
  git('switch', '-c', 'pr');
  write('docs/réception du jeu.md', '# Réception mise à jour\n');
  let head = commit('documentation');
  git('switch', 'main');
  git('merge', '--no-ff', '--no-edit', 'pr');
  let diffs = readDiffs({ event: 'pull_request', base: fork, head }, git);
  assert.equal(classify('pull_request', diffs), 'documentation');
  assert.equal(diffs[0][0].file, 'docs/réception du jeu.md');
  assert.equal(readDiffs({ event: 'pull_request', base: head, head: fork }, git), null);

  git('switch', '-c', 'style', fork);
  write('dist/style.css', 'body { color: blue }\n');
  head = commit('style');
  git('switch', '-c', 'test-style', fork);
  git('merge', '--no-ff', '--no-edit', 'style');
  diffs = readDiffs({ event: 'pull_request', base: fork, head }, git);
  assert.equal(classify('pull_request', diffs), 'web');

  git('switch', 'style');
  write('dist/saves.js', 'const version = 2;\n');
  head = commit('save');
  git('switch', '-c', 'target', fork);
  write('dist/saves.js', 'const version = 2;\n');
  const base = commit('save aussi dans main');
  git('merge', '--no-ff', '--no-edit', 'style');
  diffs = readDiffs({ event: 'pull_request', base, head }, git);
  assert.deepEqual(diffs[0].map(change => change.file), ['dist/style.css']);
  assert.equal(classify('pull_request', diffs), 'full');
  assert.equal(classify('push', readDiffs({ event: 'push', before: base }, git)), 'full');

  const cli = path.join(__dirname, '../ci/test-coverage.cjs');
  const output = path.join(cwd, '.git', 'coverage-output.txt');
  const classifyCheckout = (event, env) => {
    fs.writeFileSync(output, '');
    execFileSync(process.execPath, [cli], {
      cwd, env: { ...process.env, EVENT_NAME: event, GITHUB_OUTPUT: output, ...env }
    });
    return fs.readFileSync(output, 'utf8');
  };
  assert.equal(classifyCheckout('pull_request', { PR_BASE: base, PR_HEAD: head }), 'coverage=full\n');
  assert.equal(classifyCheckout('push', { BEFORE: base }), 'coverage=full\n');
  assert.equal(classifyCheckout('workflow_dispatch', {}), 'coverage=full\n');

  git('switch', '-c', 'renamed', fork);
  git('mv', 'docs/réception du jeu.md', 'docs/rapport.md');
  head = commit('renommage documentaire');
  git('switch', '-c', 'target-rename', fork);
  git('merge', '--no-ff', '--no-edit', 'renamed');
  diffs = readDiffs({ event: 'pull_request', base: fork, head }, git);
  assert.equal(classify('pull_request', diffs), 'full');
  assert.deepEqual(diffs[0].map(change => change.status).sort(), ['A', 'D']);
});

test('chaque profil utile est réparti sans perte et le complet découvre toutes les suites', () => {
  const all = allTestFiles();
  assert.deepEqual(suitesForCoverage('full', all), all);
  assert.ok(all.includes('tests/v60-press-relations.cjs'));
  assert.ok(all.includes('tests/v61-board-calendar.cjs'));
  for (const [profile, mandatory] of [
    ['web', ['offline', 'main-menu-v3', 'godot-assets', 'ui01-integration']],
    ['native-art', ['godot-immersive08', 'godot-assets']]
  ]) {
    const selected = suitesForCoverage(profile, all);
    assert.ok(selected.length < all.length / 4, profile);
    const plan = planShards(selected);
    assert.deepEqual(plan.flat().sort(), selected.slice().sort(), profile);
    // Moins de suites que de shards : seuls les derniers shards peuvent rester vides.
    assert.ok(plan.filter(shard => shard.length > 0).length === Math.min(plan.length, selected.length), profile);
    for (const test of mandatory) assert.ok(selected.includes('tests/' + test + '.cjs'), test);
    assert.ok(!selected.includes('tests/native-academy-integrated-long.cjs'), profile);
  }
  assert.throws(() => suitesForCoverage('unknown', all), /couverture/i);
  assert.throws(() => suitesForCoverage('web', all.filter(file => file !== 'tests/offline.cjs')), /absente/i);
});
