'use strict';
// Liste fermée des tests Chromium Matchday : chaque script reste réellement exécuté
// si ses dépendances changent. En cas d'ambiguïté, exécuter les trois.
const fs = require('node:fs');
const SUITES = Object.freeze([
  "tests/matchday-center-browser.py",
  "tests/matchday-lineup-browser.py",
  "tests/matchday-matchplan-browser.py"
]);
function selectBrowserTests(changedPaths) {
  if (!Array.isArray(changedPaths) || changedPaths.length === 0) return [...SUITES];
  const selected = new Set();
  for (const raw of changedPaths) {
    if (typeof raw !== 'string') return [...SUITES];
    const file = raw.trim();
    if (!file || file === 'dist/index.html' || file === 'dist/game.js' ||
        file.startsWith('dist/matchday-center.') ||
        file === 'ci/matchday-browser-selector.cjs' ||
        file === 'tests/ci-matchday-browser-selector.cjs' ||
        /^\.github\/workflows\/matchday-.*\.yml$/.test(file)) {
      return [...SUITES];
    }
    if (file.startsWith('dist/matchday-lineup.') ||
        file.startsWith('tests/matchday-lineup')) {
      selected.add(SUITES[1]);
      selected.add(SUITES[2]); // Le plan s'appuie sur la composition.
      continue;
    }
    if (file.startsWith('dist/matchday-matchplan.') ||
        file.startsWith('tests/matchday-matchplan')) {
      selected.add(SUITES[2]);
      continue;
    }
    if (file.startsWith('tests/matchday-center')) {
      selected.add(SUITES[0]);
      continue;
    }
    // Fichier ou suppression non catégorisable : aucun raccourci permis.
    return [...SUITES];
  }
  return selected.size ? SUITES.filter(suite => selected.has(suite)) : [...SUITES];
}
if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    let selected;
    if (args.length === 1 && args[0] === '--all') selected = [...SUITES];
    else if (args.length === 2 && args[0] === '--files') {
      const list = fs.readFileSync(args[1], 'utf8').split(/\r?\n/).filter(Boolean);
      selected = selectBrowserTests(list);
    } else throw Error('Usage : node ci/matchday-browser-selector.cjs --all | --files fichier');
    process.stdout.write(selected.join('\n') + '\n');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
module.exports = { SUITES, selectBrowserTests };
