'use strict';
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
const { selectTests } = require('./select-tests.cjs');

const SHA = /^[0-9a-f]{40}$/;
const ROOT_DOCS = new Set(['AGENTS.md', 'README.md', 'DEVELOPPEMENT.md']);
const WEB_STYLES = new Set([
  'art-direction-v4', 'finance-v2', 'lnr-career', 'lnr05-evidence-center', 'main-menu-v3',
  'matchday-center', 'matchday-lineup', 'matchday-matchplan', 'premium-editorial',
  'premium-squad', 'premium-v4', 'premium-v49', 'squad-health-center', 'style',
  'ui01-integration', 'ui02-player-components', 'ui03-scout-components',
  'ui04-academy-components', 'v17-unified-pc'
].map(name => 'dist/' + name + '.css'));

function pathCoverage(file) {
  if (ROOT_DOCS.has(file) || /^docs\/.+\.(?:md|txt|png|webp|jpe?g)$/.test(file)) return 'documentation';
  if (WEB_STYLES.has(file) ||
      /^dist\/assets\/(?:club-atlas|editorial)\/(?:[a-z0-9-]+\.webp|manifest\.json)$/.test(file) ||
      /^dist\/assets\/(?:menu-(?:stadium|rugby-ball)[a-z0-9-]*|premium-v4-matchday)\.(?:webp|png|svg)$/.test(file) ||
      /^dist\/fonts\/(?:editorial\/)?[a-zA-Z0-9-]+\.(?:ttf|woff2)$/.test(file)) return 'web';
  if (/^native\/godot\/art\/immersive08\/(?:[a-z0-9-]+\.png|(?:generated-)?manifest\.json)$/.test(file) ||
      /^native\/godot\/(?:ui\/immersive08\/)?fonts\/[a-zA-Z0-9-]+\.ttf$/.test(file)) return 'native-art';
  return 'full';
}

// Fichiers Godot : jeu natif, suites Godot (tests/godot-*, leurs aides), lanceurs et plan des shards Godot,
// préparation du projet. Un changement qui en touche un rend les jobs Godot obligatoires pour « Validation CI ».
const GODOT_PATHS = [
  /^native\/godot\//, /^tests\/godot-/, /^tests\/helpers\/(?:godot-[^/]*|[^/]*\.gd)$/,
  /^ci\/(?:godot-[a-z-]+\.(?:cjs|json)|run-godot-[a-z]+\.(?:sh|cjs)|shard-tests\.cjs|suite-weights\.json|legacy-modes\.cjs)$/,
  /^scripts\/build-godot-prototype\.py$/, /^\.github\/workflows\/tests\.yml$/
];
const touchesGodot = file => GODOT_PATHS.some(pattern => pattern.test(file));

function classify(event, diffs) {
  if (event !== 'pull_request' || !diffs?.length || diffs.some(diff => !diff.length)) return 'full';
  const modes = new Set();
  for (const { file, status, oldMode, newMode } of diffs.flat()) {
    if (newMode !== '100644' ||
        !((status === 'A' && oldMode === '000000') || (status === 'M' && oldMode === newMode))) return 'full';
    if (/[\u0000-\u001f\u007f\\]/.test(file)) return 'full';
    modes.add(pathCoverage(file));
  }
  return modes.size === 1 ? [...modes][0] : 'full';
}

function runGit(...args) {
  const data = execFileSync('git', args, { stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 32 * 1024 * 1024 });
  return new TextDecoder('utf-8', { fatal: true }).decode(data);
}

function diffBetween(git, from, to) {
  // Sans détection de renommage, le retrait de la source reste visible.
  const fields = git('diff', '--raw', '-z', '--no-abbrev', '--no-renames',
    '--ignore-submodules=none', '--no-ext-diff', from, to, '--').split('\0');
  if (fields.pop() !== '' || fields.length % 2 !== 0) throw Error('Diff Git incomplet');
  const changes = [];
  for (let i = 0; i < fields.length; i += 2) {
    const entry = /^:([0-7]{6}) ([0-7]{6}) [0-9a-f]{40} [0-9a-f]{40} ([A-Z])$/.exec(fields[i]);
    if (!entry || !fields[i + 1]) throw Error('Entrée de diff Git invalide');
    const [, oldMode, newMode, status] = entry;
    changes.push({ file: fields[i + 1], status, oldMode, newMode });
  }
  return changes;
}

function readDiffs({ event, base, head, before }, git = runGit) {
  try {
    if (event === 'pull_request' && SHA.test(base) && SHA.test(head)) {
      const parents = git('rev-list', '--parents', '-n', '1', 'HEAD').trim().split(' ');
      if (parents.length !== 3 || parents[1] !== base || parents[2] !== head) return null;
      const fork = git('merge-base', '--all', base, head).trim();
      if (!SHA.test(fork)) return null;
      // Un changement de la PR peut déjà être présent dans main. Les deux
      // diffs doivent permettre le même niveau de couverture.
      return [diffBetween(git, base, parents[0]), diffBetween(git, fork, head)];
    }
    if (event === 'push' && SHA.test(before) && !/^0+$/.test(before)) {
      return [diffBetween(git, before, 'HEAD')];
    }
  } catch (error) {
    console.warn('Diff Git indisponible, couverture complète : ' + error.message);
  }
  return null;
}

function suitesForCoverage(coverage, all) {
  if (coverage === 'full') return all;
  const artwork = ['godot-assets', 'godot-immersive08', 'offline', 'premium-editorial'];
  let suites = ['ci-test-coverage', ...artwork].map(name => 'tests/' + name + '.cjs');
  if (coverage === 'web') {
    suites = [...suites, ...selectTests(['dist/style.css'], all), ...[
      'art-direction-v4', 'finance-v2-playable', 'lnr-career', 'lnr05-evidence',
      'main-menu', 'main-menu-v3', 'matchday-center', 'matchday-lineup', 'matchday-matchplan',
      'premium-editorial-matchday', 'premium-manager-office', 'premium-squad', 'squad-health-center',
      'ui01-integration', 'ui01-interface', 'ui02-live-integration', 'ui02-player-components',
      'ui03-scout-components', 'ui04-academy-components', 'v17-unified-pc.test'
    ].map(name => 'tests/' + name + '.cjs')];
  } else if (coverage !== 'native-art') {
    throw Error('Couverture inconnue pour les shards : ' + coverage);
  }
  for (const suite of suites) {
    if (!all.includes(suite)) throw Error('Suite ciblée absente : ' + suite);
  }
  return [...new Set(suites)].sort();
}

if (require.main === module) {
  const { EVENT_NAME, PR_BASE, PR_HEAD, BEFORE, GITHUB_OUTPUT } = process.env;
  const diffs = readDiffs({ event: EVENT_NAME, base: PR_BASE, head: PR_HEAD, before: BEFORE });
  const files = diffs ? diffs.flat().map(change => change.file) : runGit('ls-files', '-z').split('\0');
  for (const file of new Set(files)) {
    if (!/\.(?:js|cjs|mjs)$/.test(file) || !fs.lstatSync(file, { throwIfNoEntry: false })?.isFile()) continue;
    console.log('Syntaxe : ' + JSON.stringify(file));
    execFileSync(process.execPath, ['--check', '--', file], { stdio: 'inherit' });
  }
  const coverage = classify(EVENT_NAME, diffs);
  const godot = files.some(touchesGodot);
  fs.appendFileSync(GITHUB_OUTPUT, 'coverage=' + coverage + '\ngodot=' + godot + '\n');
  console.log('Couverture : ' + coverage + ' · fichiers Godot touchés : ' + godot);
}

module.exports = { classify, touchesGodot, readDiffs, suitesForCoverage };
