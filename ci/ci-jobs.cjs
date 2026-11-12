'use strict';
// Source unique des noms de jobs du workflow « Tests JavaScript » (.github/workflows/tests.yml).
// Les outils de livraison (gates, diagnostics, métriques) importent ces constantes au lieu
// de recopier la liste : changer le nombre de shards ne demande qu'une modification ici et
// dans la matrice du workflow (tests/ci-report.cjs vérifie que les deux concordent).
// Cinq runners × quatre suites en parallèle (ci/run-shard-suites.sh, budget mémoire
// ci/suite-weights.json « memory ») : même couverture qu'avec dix runners × deux suites,
// deux fois moins de places sur les 20 jobs simultanés du dépôt public.
const SHARD_COUNT = 5;
const SHARD_PARALLEL = 4;
// Jobs Godot : SDK 4.7.2 installé en CI, suites natives sous xvfb. Non bloquants pour
// l'instant (continue-on-error, hors des dépendances de « Validation CI »).
const GODOT_SHARD_COUNT = 3;

const shardJob = (shard, count = SHARD_COUNT) => 'Suites ' + shard + '/' + count;
const SHARD_JOBS = Object.freeze(Array.from({ length: SHARD_COUNT }, (_, i) => shardJob(i + 1)));
// Nom affiché par GitHub quand la matrice entière est sautée (PR purement documentaire).
const SHARD_JOB_SKIPPED = 'Suites ${{ matrix.shard }}/' + SHARD_COUNT;
const OFFICIAL_JOBS = Object.freeze(['classification', ...SHARD_JOBS, 'Validation CI']);
const GODOT_JOBS = Object.freeze(Array.from({ length: GODOT_SHARD_COUNT },
  (_, i) => 'Godot ' + (i + 1) + '/' + GODOT_SHARD_COUNT));
const GODOT_JOB_SKIPPED = 'Godot ${{ matrix.shard }}/' + GODOT_SHARD_COUNT;
// Jobs informatifs : jamais requis par les gates, ignorés par les décomptes officiels.
const INFORMATIVE_JOB = /^Godot (?:[1-9][0-9]*|\$\{\{ matrix\.shard \}\})\/[1-9][0-9]*$/;

function isInformativeJob(job) {
  return typeof job?.name === 'string' && INFORMATIVE_JOB.test(job.name);
}
// Jobs du verdict officiel : tout sauf les jobs informatifs (un job inconnu reste compté,
// donc refusé par les contrôles de liste exacte).
function officialJobs(jobs) {
  return Array.isArray(jobs) ? jobs.filter(job => !isInformativeJob(job)) : jobs;
}
// Shards « Suites i/N » d'un run, quel que soit N (comparaisons avant/après un changement
// du nombre de shards). Renvoie null si la série est incomplète ou incohérente.
function shardSeries(jobs) {
  const shards = (jobs || []).filter(j => /^Suites [1-9][0-9]*\/[1-9][0-9]*$/.test(j?.name));
  if (!shards.length) return null;
  const count = Number(shards[0].name.split('/')[1]);
  const names = shards.map(j => j.name).sort();
  const expected = Array.from({ length: count }, (_, i) => shardJob(i + 1, count)).sort();
  if (names.length !== count || names.some((n, i) => n !== expected[i])) return null;
  return { count, jobs: shards };
}

module.exports = {
  SHARD_COUNT, SHARD_PARALLEL, GODOT_SHARD_COUNT, SHARD_JOBS, SHARD_JOB_SKIPPED, OFFICIAL_JOBS,
  GODOT_JOBS, GODOT_JOB_SKIPPED, isInformativeJob, officialJobs, shardSeries, shardJob
};
