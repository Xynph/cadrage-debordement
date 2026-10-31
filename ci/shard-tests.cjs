'use strict';
// Ordonnancement déterministe des suites complètes, sans sélection liée au diff.
// Poids prudents = maximum arrondi de deux mesures : main #41195460951 et PR V2 #41196473550.
const fs = require('node:fs');
const path = require('node:path');
const WEIGHTS_SECONDS = Object.freeze({
  'tests/world-career.cjs': 66,
  'tests/ai-roster-cycle.cjs': 81,
  'tests/rugby.cjs': 51,
  'tests/opposition.cjs': 31,
  'tests/manager-mobility.cjs': 29,
  'tests/career-resilience.cjs': 17,
  'tests/tactical-plans.cjs': 16,
  'tests/saves.cjs': 18,
  'tests/v28-collective-preparation.cjs': 6,
  'tests/champion-budget-regression.cjs': 5,
  'tests/economy-audit.cjs': 6,
  'tests/v29-focused-development.cjs': 4,
  'tests/matchflow.cjs': 4,
  'tests/development.cjs': 3,
  'tests/frontrow.cjs': 3,
  'tests/v33-contract-renewals.cjs': 3,
  'tests/preparation.cjs': 3,
  'tests/manager.cjs': 2,
  'tests/v30-recruitment-intelligence.cjs': 2,
  'tests/ui01-integration.cjs': 2,
  'tests/v35-salary-demand.cjs': 3,
  'tests/v34-counteroffers.cjs': 2,
  'tests/v37-relations.cjs': 2
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
    for (let i = 1; i < 3; i++) {
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
