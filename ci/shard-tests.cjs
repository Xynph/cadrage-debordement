'use strict';
// Répartition complète et déterministe : toutes les suites sont conservées.
// Poids de planification (secondes) : ci/suite-weights.json, recalculé par
// ci/suite-weights.cjs à partir des CD_CPU_PROFILE wall_s de runs GitHub verts
// (médiane + 15 %). Section « js » pour les shards « Suites i/N », section « godot »
// pour les jobs Godot (suites qui pilotent le SDK via CD_GODOT_EXE/CD_GODOT_EXECUTABLE).
// Le pic simulé ne constitue pas une mesure de gain réel ; reprofiler régulièrement.
const fs = require('node:fs');
const path = require('node:path');
const { SHARD_COUNT, GODOT_SHARD_COUNT } = require('./ci-jobs.cjs');

const PROFILE = JSON.parse(fs.readFileSync(path.join(__dirname, 'suite-weights.json'), 'utf8'));
const WEIGHTS_SECONDS = Object.freeze({ ...PROFILE.js.weights });
const GODOT_WEIGHTS_SECONDS = Object.freeze({ ...PROFILE.godot.weights });
// Une suite Godot inconnue démarre au moins un moteur : poids par défaut plus élevé.
const DEFAULT_WEIGHT = 1;
const GODOT_DEFAULT_WEIGHT = 30;
const MAX_SHARDS = 64;
const GODOT_SDK = /\bprocess\.env\.CD_GODOT_EXE(?:CUTABLE)?\b/;

const lexical = (a, b) => a < b ? -1 : a > b ? 1 : 0;
function testsDir() { return path.resolve(__dirname, '..', 'tests'); }
function allTestFiles() {
  return fs.readdirSync(testsDir(), { withFileTypes: true })
    .filter(e => e.isFile() && e.name.endsWith('.cjs') && e.name !== 'harness.cjs')
    .map(e => 'tests/' + e.name).sort(lexical);
}
// Suites qui lancent réellement le moteur : leur source lit process.env.CD_GODOT_EXE ou
// process.env.CD_GODOT_EXECUTABLE. Les autres tests/godot-*.cjs (manifestes, effectifs, imports)
// sont du JavaScript pur et restent couverts par les shards « Suites ».
function godotTestFiles(files = allTestFiles(), read = f => fs.readFileSync(path.join(testsDir(), path.basename(f)), 'utf8')) {
  return files.filter(f => GODOT_SDK.test(read(f))).sort(lexical);
}
function shardCount(value) {
  const text = String(value);
  if (!/^[1-9][0-9]*$/.test(text) || Number(text) > MAX_SHARDS) throw Error('Nombre de shards invalide : ' + text);
  return Number(text);
}
// Glouton LPT : suites triées par poids décroissant, chacune au shard le moins chargé
// (égalité : le moins de suites, puis le plus petit indice). Moins de suites que de
// shards : les derniers shards restent vides (couvertures ciblées web/native-art).
function planShards(files, weights = WEIGHTS_SECONDS, count = SHARD_COUNT, fallback = DEFAULT_WEIGHT) {
  count = shardCount(count);
  if (!Array.isArray(files) || files.length === 0) throw Error('Liste des suites absente');
  if (files.some(f => typeof f !== 'string' ||
      !/^tests\/[A-Za-z0-9._-]+\.cjs$/.test(f) || f === 'tests/harness.cjs'))
    throw Error('Chemin de suite invalide');
  if (new Set(files).size !== files.length) throw Error('Suite dupliquée');
  const weight = f => {
    const value = Object.prototype.hasOwnProperty.call(weights, f) ? weights[f] : fallback;
    if (!Number.isFinite(value) || value < 1) throw Error('Poids invalide : ' + f);
    return value;
  };
  const ordered = files.slice().sort((a, b) => weight(b) - weight(a) || lexical(a, b));
  const shards = Array.from({ length: count }, () => ({ weight: 0, files: [] }));
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
function planLoads(groups, weights = WEIGHTS_SECONDS, fallback = DEFAULT_WEIGHT) {
  return groups.map(g => g.reduce((sum, f) =>
    sum + (Object.prototype.hasOwnProperty.call(weights, f) ? weights[f] : fallback), 0));
}
// Suites d'un shard pour une couverture donnée. « godot » : suites SDK, poids godot.
function suitesForShard(shard, coverage = 'full', count, files = allTestFiles()) {
  const godot = coverage === 'godot';
  count = shardCount(count ?? (godot ? GODOT_SHARD_COUNT : SHARD_COUNT));
  shard = shardCount(shard);
  if (shard > count) throw Error('Shard ' + shard + ' hors de 1..' + count);
  const suites = godot ? godotTestFiles(files) : require('./test-coverage.cjs').suitesForCoverage(coverage, files);
  const plan = godot ? planShards(suites, GODOT_WEIGHTS_SECONDS, count, GODOT_DEFAULT_WEIGHT) : planShards(suites, WEIGHTS_SECONDS, count);
  // Couverture complète : chaque shard doit recevoir au moins une suite.
  if (coverage === 'full' && plan.some(g => g.length === 0)) throw Error('Il faut au moins une suite par shard');
  return plan[shard - 1];
}

// Réservations mémoire (Mo) : section « memory » de ci/suite-weights.json (ci/suite-weights.cjs).
const MEMORY = Object.freeze({
  defaultMb: PROFILE.memory?.default_mb ?? 1024,
  budgetMb: PROFILE.memory?.budget_mb ?? 12288,
  suites: Object.freeze({ ...(PROFILE.memory?.suites || {}) })
});
const memoryOf = f => MEMORY.suites[f] ?? MEMORY.defaultMb;
// Simulation de l'ordonnanceur de ci/run-shard-suites.sh pour une liste de suites : au plus
// « parallel » suites, somme des réservations ≤ budget (une suite trop grosse tourne seule),
// la première suite de la liste (poids décroissant) qui tient démarre. Renvoie la durée
// murale et le pic de mémoire réservée. Estimation : la contention CPU n'est pas modélisée.
function simulateShard(files, duration, parallel, { memory = memoryOf, budget = MEMORY.budgetMb, weights = WEIGHTS_SECONDS } = {}) {
  const weight = f => Object.prototype.hasOwnProperty.call(weights, f) ? weights[f] : DEFAULT_WEIGHT;
  const pending = files.slice().sort((a, b) => weight(b) - weight(a) || lexical(a, b));
  let now = 0, used = 0, peak = 0;
  const running = [];
  while (pending.length || running.length) {
    while (pending.length && running.length < parallel) {
      const k = pending.findIndex(f => used + memory(f) <= budget || running.length === 0);
      if (k < 0) break;
      const [f] = pending.splice(k, 1);
      running.push({ end: now + duration(f), mb: memory(f) });
      used += memory(f);
      peak = Math.max(peak, used);
    }
    running.sort((a, b) => a.end - b.end);
    const done = running.shift();
    now = done.end;
    used -= done.mb;
  }
  return { wall: now, peakMb: peak };
}

const USAGE = 'Usage : node ci/shard-tests.cjs <shard> [full|web|native-art|godot] [nombre-de-shards]\n' +
  '  shard : 1..N ; N par défaut ' + SHARD_COUNT + ' (godot : ' + GODOT_SHARD_COUNT + '), au plus ' + MAX_SHARDS + '.';
if (require.main === module) {
  const [, , shard, coverage = 'full', count] = process.argv;
  if (process.argv.length > 5 || !shard || !/^[1-9][0-9]*$/.test(shard) ||
      (count !== undefined && !/^[1-9][0-9]*$/.test(count))) {
    console.error(USAGE);
    process.exitCode = 2;
  } else {
    try {
      // Ordre d'exécution : poids décroissant (les plus longues démarrent en premier
      // quand ci/run-shard-suites.sh lance plusieurs suites en parallèle).
      const weights = coverage === 'godot' ? GODOT_WEIGHTS_SECONDS : WEIGHTS_SECONDS;
      const fallback = coverage === 'godot' ? GODOT_DEFAULT_WEIGHT : DEFAULT_WEIGHT;
      const weight = f => Object.prototype.hasOwnProperty.call(weights, f) ? weights[f] : fallback;
      for (const file of suitesForShard(shard, coverage, count).sort((a, b) => weight(b) - weight(a) || lexical(a, b)))
        console.log(file);
    } catch (error) {
      console.error(error.message);
      process.exitCode = 1;
    }
  }
}
module.exports = {
  allTestFiles, godotTestFiles, planShards, planLoads, suitesForShard, shardCount, simulateShard, memoryOf, MEMORY,
  WEIGHTS_SECONDS, GODOT_WEIGHTS_SECONDS, DEFAULT_WEIGHT, GODOT_DEFAULT_WEIGHT, MAX_SHARDS
};
