'use strict';
const fs = require('node:fs');
// Liste exhaustive. Toute entrée incertaine déclenche les sept parcours.
const GROUPS = Object.freeze({
  ui01: Object.freeze(['tests/ui01-browser.py','tests/ui01-contrast.py','tests/main-menu-v3-browser.py']),
  ui02: Object.freeze(['tests/ui02-live-browser.py']),
  centers: Object.freeze(['tests/ui-native-centers-browser.py']),
  premium: Object.freeze(['tests/premium-v4-browser.py','tests/art-direction-v4-browser.py'])
});
const ORDER = Object.freeze(['ui01','ui02','centers','premium']);
const ALL = Object.freeze(ORDER.flatMap(key => GROUPS[key]));
function selectBrowserTests(event, changedPaths) {
  if (event === 'push') return [...GROUPS.ui01]; // Reproduction du seul trigger push historique UI01.
  if (event !== 'pull_request' || !Array.isArray(changedPaths) || changedPaths.length === 0) return [...ALL];
  const groups = new Set();
  for (const raw of changedPaths) {
    if (typeof raw !== 'string' || !raw.trim() || raw.includes('\0')) return [...ALL];
    const file = raw.trim();
    if (file === 'dist/index.html' || file === 'ci/ui-browser-selector.cjs' ||
        file === 'tests/ci-ui-browser-selector.cjs' || file === '.github/workflows/ui-browser-consolidated.yml') return [...ALL];
    if (file === '.github/workflows/ui01-integration.yml') {groups.add('ui01');continue;}
    if (file === '.github/workflows/ui02-browser.yml') {groups.add('ui02');continue;}
    if (file === '.github/workflows/ui-native-centers-browser.yml') {groups.add('centers');continue;}
    if (file === '.github/workflows/premium-v4.yml') {groups.add('premium');continue;}
    if (file.startsWith('dist/')) {
      groups.add('premium'); // Ancien filtre dist/** : sauvegardes Premium toujours couvertes.
      if (file === 'dist/style.css' || file === 'dist/game.js' ||
          file.startsWith('dist/ui') || file.startsWith('dist/main-menu') ||
          file.startsWith('dist/assets/menu-stadium') ||
          ['dist/manager-squad.js','dist/match-preparation.js','dist/match-cockpit.js'].includes(file)) groups.add('ui01');
      if (file === 'dist/manager-squad.js' || /^dist\/ui02-.*\.(js|css)$/.test(file)) groups.add('ui02');
      if (file === 'dist/game.js' || file === 'dist/ui-native-centers.js' ||
          file.startsWith('dist/ui03-') || file.startsWith('dist/ui04-')) groups.add('centers');
      continue;
    }
    if (file.startsWith('tests/main-menu') || file.startsWith('tests/ui01') || file === 'tests/harness.cjs') {groups.add('ui01');continue;}
    if (file.startsWith('tests/ui02-')) {groups.add('ui02');continue;}
    if (file.startsWith('tests/ui-native-centers')) {groups.add('centers');continue;}
    if (file === 'tests/premium-v4-browser.py' || file === 'tests/art-direction-v4-browser.py') {groups.add('premium');continue;}
    if (file === 'DEVELOPPEMENT.md' || file === 'README.md' || file === 'AGENTS.md' || file.startsWith('docs/')) continue;
    return [...ALL]; // Les inconnues imposent la couverture complète.
  }
  return groups.size ? ORDER.filter(key => groups.has(key)).flatMap(key => GROUPS[key]) : [...ALL];
}
if (require.main === module) {
  try {
    const args=process.argv.slice(2);
    if (args.length !== 3 || args[0] !== '--event' ||
        !['pull_request','push','workflow_dispatch'].includes(args[1])) throw Error('Usage: --event TYPE --all|--files=CHEMIN');
    let names=null;
    if (args[2] === '--all') names=null;
    else if (args[2].startsWith('--files=')) names=fs.readFileSync(args[2].slice(8),'utf8').split(/\r?\n/).filter(Boolean);
    else throw Error('Sélection invalide');
    process.stdout.write(selectBrowserTests(args[1],names).join('\n')+'\n');
  } catch(e) {console.error(e.message);process.exitCode=1;}
}
module.exports={GROUPS,ORDER,ALL,selectBrowserTests};
