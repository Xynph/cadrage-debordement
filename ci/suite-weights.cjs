'use strict';
// Recalcule les poids de planification des shards (ci/suite-weights.json) à partir des
// journaux GitHub Actions de runs verts. Chaque suite y écrit
//   CD_CPU_PROFILE suite=tests/x.cjs ... wall_s=12.34 ...
// Poids = médiane des durées murales observées × (1 + marge), arrondi, au moins 1 s.
// Usage :
//   node ci/suite-weights.cjs <js|godot> <dossier-de-logs> [run-id...]
// Le dossier contient les journaux bruts des jobs (gh api .../actions/jobs/<id>/logs),
// nommés job-<run>-<job>.log. Le fichier JSON est réécrit en place, section par section.
const fs = require('node:fs');
const path = require('node:path');

const FILE = path.join(__dirname, 'suite-weights.json');
const MARGIN = 0.15;
const PROFILE = /CD_CPU_PROFILE suite=(tests\/[A-Za-z0-9._-]+\.cjs) .*\bwall_s=([0-9]+(?:\.[0-9]+)?)/;

function median(values) {
  const s = values.slice().sort((a, b) => a - b), m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}
function parseLogs(dir) {
  const samples = {}, runs = new Set();
  for (const name of fs.readdirSync(dir).sort()) {
    const match = /^job-([0-9]+)-[0-9]+\.log$/.exec(name);
    if (!match) continue;
    runs.add(match[1]);
    for (const line of fs.readFileSync(path.join(dir, name), 'utf8').split('\n')) {
      // La ligne de commande /usr/bin/time contient aussi le motif : on l'ignore.
      if (line.includes('/usr/bin/time')) continue;
      const m = PROFILE.exec(line);
      if (m) ((samples[m[1]] ??= {})[match[1]] = Number(m[2]));
    }
  }
  return { samples, runs: [...runs].sort() };
}
// Seules les suites présentes dans tests/ sont gardées (des runs de PR peuvent en mesurer
// d'autres, pas encore fusionnées).
function weightsFrom(samples, exists = f => fs.existsSync(path.join(__dirname, '..', f))) {
  const weights = {};
  for (const file of Object.keys(samples).sort().filter(exists)) {
    const value = Math.max(1, Math.round(median(Object.values(samples[file])) * (1 + MARGIN)));
    if (value > 1) weights[file] = value; // 1 s est le poids par défaut des suites absentes
  }
  return weights;
}

if (require.main === module) {
  const [kind, dir] = process.argv.slice(2);
  if (!['js', 'godot'].includes(kind) || !dir || !fs.statSync(dir, { throwIfNoEntry: false })?.isDirectory()) {
    console.error('Usage : node ci/suite-weights.cjs <js|godot> <dossier-de-logs>');
    process.exit(2);
  }
  const { samples, runs } = parseLogs(dir);
  if (!runs.length || !Object.keys(samples).length) {
    console.error('Aucune mesure CD_CPU_PROFILE dans ' + dir);
    process.exit(1);
  }
  const data = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  data[kind] = {
    source: 'médiane des wall_s CD_CPU_PROFILE de runs GitHub verts, +' + Math.round(MARGIN * 100) + ' %',
    runs: runs.map(Number),
    weights: weightsFrom(samples)
  };
  fs.writeFileSync(FILE, JSON.stringify(data, null, 1) + '\n');
  console.log(kind + ' : ' + Object.keys(samples).length + ' suites mesurées sur ' + runs.length + ' runs');
}

module.exports = { median, parseLogs, weightsFrom, MARGIN };
