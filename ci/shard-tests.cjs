'use strict';
// Ordonnancement déterministe des suites complètes, sans sélection liée au diff.
// Poids (secondes arrondies avec marge de 15 %) : maximum observé sur les
// runs PR #41359113513 et main #41359554302, le 01/11/2026,
// completes par deux suites V63 mesurees le 03/11/2026.
// Seules les suites dépassant 3 s dans au moins un run sont pondérées ;
// les autres et toute nouvelle suite conservent le poids prudent de 1.
// Reprofiler si les suites ou les runtimes changent ; ce n'est pas une promesse de durée.
const fs = require('node:fs');
const path = require('node:path');
const WEIGHTS_SECONDS = Object.freeze({
  // Mesure GitHub Actions PR #41694849000 (03/11/2026), marge prudente.
  'tests/v63-2-stress-native.cjs': 106,
  'tests/v63-1-long-career.cjs': 92,
  'tests/ai-roster-cycle.cjs': 84,
  'tests/world-career.cjs': 72,
  'tests/rugby.cjs': 59,
  'tests/lnr-multiclub-continuity.cjs': 52,
  'tests/lnr05-evidence-long.cjs': 50,
  'tests/lnr-career-long.cjs': 40,
  'tests/lnr05-rotation-audit.cjs': 40,
  'tests/lnr05-multiseason-strategies.cjs': 38,
  'tests/lnr05-fatigue-scenarios.cjs': 37,
  'tests/opposition.cjs': 33,
  'tests/manager-mobility.cjs': 30,
  'tests/lnr-cross-season-recovery.cjs': 26,
  'tests/lnr-save-resume-continuation.cjs': 26,
  'tests/saves.cjs': 21,
  'tests/tactical-plans.cjs': 18,
  'tests/career-resilience.cjs': 17,
  'tests/lnr-save-integrity-guards.cjs': 17,
  'tests/lnr05-rest-policy-audit.cjs': 12,
  'tests/champion-budget-regression.cjs': 6,
  'tests/economy-audit.cjs': 6,
  'tests/v28-collective-preparation.cjs': 6,
  'tests/lnr-save-import-rollback-stress.cjs': 5,
  'tests/v29-focused-development.cjs': 5
});
const lexical = (a, b) => a < b ? -1 : a > b ? 1 : 0;
function allTestFiles() {
  return fs.readdirSync(path.resolve(__dirname, '..', 'tests'), { withFileTypes: true })
    .filter(e => e.isFile() && e.name.endsWith('.cjs') && e.name !== 'harness.cjs')
    .map(e => 'tests/' + e.name).sort(lexical);
}
function planShards(files, weights = WEIGHTS_SECONDS) {
  if (!Array.isArray(files) || files.length === 0) throw Error('Liste des suites absente');
  if (files.some(f => typeof f !== 'string' ||
      !/^tests\/[A-Za-z0-9._-]+\.cjs$/.test(f) || f === 'tests/harness.cjs'))
    throw Error('Chemin de suite invalide');
  if (new Set(files).size !== files.length) throw Error('Suite dupliquée');
  const weight = f => {
    const value = Object.prototype.hasOwnProperty.call(weights, f) ? weights[f] : 1;
    if (!Number.isFinite(value) || value < 1) throw Error('Poids invalide : ' + f);
    return value;
  };
  const ordered = files.slice().sort((a, b) => weight(b) - weight(a) || lexical(a, b));
  const shards = Array.from({ length: 5 }, () => ({ weight: 0, files: [] }));
  for (const file of ordered) {
    let target = 0;
    for (let i = 1; i < shards.length; i++) {
      if (shards[i].weight < shards[target].weight ||
          (shards[i].weight === shards[target].weight &&
           shards[i].files.length < shards[target].files.length)) target = i;
    }
    shards[target].files.push(file);
    shards[target].weight += weight(file);
  }
  return shards.map(g => g.files.sort(lexical));
}
if (require.main === module) {
  if (process.argv.length !== 3 || !/^[1-5]$/.test(process.argv[2])) {
    console.error('Usage : node ci/shard-tests.cjs <1|2|3|4|5>');
    process.exitCode = 2;
  } else {
    try {
      for (const file of planShards(allTestFiles())[Number(process.argv[2]) - 1])
        console.log(file);
    } catch (error) {
      console.error(error.message);
      process.exitCode = 1;
    }
  }
}
module.exports = { allTestFiles, planShards, WEIGHTS_SECONDS };
