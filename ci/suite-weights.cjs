'use strict';
// Recalcule les poids de planification des shards (ci/suite-weights.json) à partir des
// journaux GitHub Actions de runs verts. Chaque suite y écrit
//   CD_CPU_PROFILE suite=tests/x.cjs ... wall_s=12.34 ...
// Poids = médiane des durées murales observées × (1 + marge), arrondi, au moins 1 s.
// Section « memory » : mémoire de pointe (max_rss_kb) maximale observée × (1 + marge), en Mo,
// pour les suites d'au moins MEMORY_DEFAULT_MB ; ci/run-shard-suites.sh s'en sert pour ne
// jamais dépasser le budget mémoire d'un runner (16 Go) en lançant 4 suites à la fois.
// Usage :
//   node ci/suite-weights.cjs <js|godot|memory> <dossier-de-logs> [--garder]
// --garder : conserve le poids existant des suites que ces journaux ne mesurent pas (budget
// d'une suite ajoutée depuis, sans durée dans les runs de référence) ; sert à réintégrer une
// suite migrée en carrière Monde : après migration, relancer avec les journaux des runs de
// référence (js.runs) pour lui donner son poids mesuré au lieu du défaut de 1 s.
// Le dossier contient les journaux bruts des jobs (gh api .../actions/jobs/<id>/logs),
// nommés job-<run>-<job>.log. Le fichier JSON est réécrit en place, section par section.
const fs = require('node:fs');
const { legacySuites } = require('./legacy-modes.cjs');
const path = require('node:path');

const FILE = path.join(__dirname, 'suite-weights.json');
const MARGIN = 0.15;
const PROFILE = /CD_CPU_PROFILE suite=(tests\/[A-Za-z0-9._-]+\.cjs) .*\bwall_s=([0-9]+(?:\.[0-9]+)?)/;
const RSS = /CD_CPU_PROFILE suite=(tests\/[A-Za-z0-9._-]+\.cjs) .*\bmax_rss_kb=([0-9]+)/;
const MEMORY_MARGIN = 0.10;
const MEMORY_DEFAULT_MB = 1024;
const MEMORY_BUDGET_MB = 12288;

// Suite présente dans tests/ et hors ancien mode de carrière (ensemble calculé une seule fois).
let legacyCache;
function ciSuite(f) {
  legacyCache ??= legacySuites();
  return fs.existsSync(path.join(__dirname, '..', f)) && !legacyCache.has(f);
}
function median(values) {
  const s = values.slice().sort((a, b) => a - b), m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}
function parseLogs(dir, pattern = PROFILE) {
  const samples = {}, runs = new Set();
  for (const name of fs.readdirSync(dir).sort()) {
    const match = /^job-([0-9]+)-[0-9]+\.log$/.exec(name);
    if (!match) continue;
    runs.add(match[1]);
    for (const line of fs.readFileSync(path.join(dir, name), 'utf8').split('\n')) {
      // La ligne de commande /usr/bin/time contient aussi le motif : on l'ignore.
      if (line.includes('/usr/bin/time')) continue;
      const m = pattern.exec(line);
      if (m) ((samples[m[1]] ??= {})[match[1]] = Number(m[2]));
    }
  }
  return { samples, runs: [...runs].sort() };
}
// Seules les suites présentes dans tests/ sont gardées (des runs de PR peuvent en mesurer
// d'autres, pas encore fusionnées), hors suites à ancien mode de carrière (exclues de la CI).
function weightsFrom(samples, exists = ciSuite) {
  const weights = {};
  for (const file of Object.keys(samples).sort().filter(exists)) {
    const value = Math.max(1, Math.round(median(Object.values(samples[file])) * (1 + MARGIN)));
    if (value > 1) weights[file] = value; // 1 s est le poids par défaut des suites absentes
  }
  return weights;
}
// Mémoire de pointe en Mo : maximum observé (et non médiane) × (1 + marge), arrondi au
// multiple de 64 Mo supérieur ; suites sous le défaut omises (elles prennent le défaut).
function memoryFrom(samples, exists = ciSuite) {
  const suites = {};
  for (const file of Object.keys(samples).sort().filter(exists)) {
    const mb = Math.ceil(Math.max(...Object.values(samples[file])) / 1024 * (1 + MEMORY_MARGIN) / 64) * 64;
    if (mb > MEMORY_DEFAULT_MB) suites[file] = mb;
  }
  return suites;
}

if (require.main === module) {
  const [kind, dir, option] = process.argv.slice(2);
  const keep = option === '--garder';
  if (!['js', 'godot', 'memory'].includes(kind) || !dir || !fs.statSync(dir, { throwIfNoEntry: false })?.isDirectory()) {
    console.error('Usage : node ci/suite-weights.cjs <js|godot|memory> <dossier-de-logs> [--garder]');
    process.exit(2);
  }
  const { samples, runs } = parseLogs(dir, kind === 'memory' ? RSS : PROFILE);
  if (!runs.length || !Object.keys(samples).length) {
    console.error('Aucune mesure CD_CPU_PROFILE dans ' + dir);
    process.exit(1);
  }
  const data = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  if (kind === 'memory') data.memory = {
    source: 'maximum des max_rss_kb CD_CPU_PROFILE de runs GitHub, +' + Math.round(MEMORY_MARGIN * 100) + ' %, en Mo',
    runs: runs.map(Number),
    default_mb: MEMORY_DEFAULT_MB,
    budget_mb: MEMORY_BUDGET_MB,
    suites: memoryFrom(samples)
  };
  else {
    const weights = weightsFrom(samples);
    if (keep) for (const [file, seconds] of Object.entries(data[kind]?.weights || {}))
      if (!(file in samples) && ciSuite(file)) weights[file] = seconds;
    data[kind] = {
      source: keep && data[kind]?.source || 'médiane des wall_s CD_CPU_PROFILE de runs GitHub verts, +' + Math.round(MARGIN * 100) + ' %',
      runs: runs.map(Number),
      weights: Object.fromEntries(Object.keys(weights).sort().map(f => [f, weights[f]]))
    };
  }
  fs.writeFileSync(FILE, JSON.stringify(data, null, 2) + '\n');
  console.log(kind + ' : ' + Object.keys(samples).length + ' suites mesurées sur ' + runs.length + ' runs');
}

module.exports = { median, parseLogs, weightsFrom, memoryFrom, MARGIN, RSS, MEMORY_DEFAULT_MB, MEMORY_BUDGET_MB };
