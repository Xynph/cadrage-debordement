'use strict';
// Source unique des noms de jobs du workflow « Tests JavaScript » (.github/workflows/tests.yml).
// Les outils de livraison (gates, diagnostics, métriques) importent ces constantes au lieu
// de recopier la liste : changer le nombre de shards ne demande qu'une modification ici et
// dans la matrice du workflow (tests/ci-report.cjs vérifie que les deux concordent).
// Sept runners × trois suites au plus (ci/run-shard-suites.sh, budget mémoire
// ci/suite-weights.json « memory ») : même couverture qu'avec dix runners × deux suites,
// sept places au lieu de dix sur les 20 jobs simultanés du dépôt public.
// Les 4 vCPU d'un runner GitHub sont 2 cœurs physiques (SMT) : mesuré sur le run
// 43326802384, quatre suites à la fois doublent la durée murale (médiane × 2,07) et font
// expirer les délais vm internes (finish_round 15 s). Les suites « exclusives »
// (ci/shard-tests.cjs isExclusive : ≥ EXCLUSIVE_WEIGHT s ou machine virtuelle node:vm)
// gardent donc un cœur physique : tant qu'une d'elles tourne, au plus EXCLUSIVE_CAP
// suites au total. La troisième place ne sert qu'aux suites légères.
// 19/11/2026 : dix runners (poids recalculés sur 8 runs verts du jour) ; pic simulé ~17 min contre ~24 à sept.
const SHARD_COUNT = 10;
const SHARD_PARALLEL = 3;
const PHYSICAL_CORES = 2;
const EXCLUSIVE_CAP = PHYSICAL_CORES;
const EXCLUSIVE_WEIGHT = 30;
// Jobs Godot : SDK 4.7.2 installé en CI, suites natives sous xvfb. Bloquants (14/11) : « Validation CI »
// en dépend dans le workflow ; sautés (donc sans effet) quand aucun fichier Godot ne change.
// 19/11/2026 : cinq jobs Godot. 26/11/2026 : six (les suites durent 218 min au total, 44 min par job à cinq, au bord du délai de 45 min ; 36 min à six).
// 28/11/2026 : sept (poids remesurés sur les batteries du 27-28/11 : 267 min au total, 44 min par job à six, au bord de la
// coupure de 45 min, des jobs coupés ce jour-là ; 38 min à sept). 10 lots JS + 7 Godot + classification = 18 jobs sur 20.
const GODOT_SHARD_COUNT = 7;
// Mode rapide (PR prête sans étiquette `batterie-complete`, 19/11/2026) : suites dont le poids ne dépasse pas
// RAPIDE_MAX_S, plus les suites modifiées par la PR quel que soit leur poids. La batterie complète tourne
// chaque heure sur main (schedule).
const RAPIDE_MAX_S = 60;
// Côté Godot (suites en série, démarrage du moteur compris) : 20 s ; une suite Godot sans mesure (30 s par défaut) en est exclue.
const RAPIDE_GODOT_MAX_S = 20;

const shardJob = (shard, count = SHARD_COUNT) => 'Suites ' + shard + '/' + count;
const SHARD_JOBS = Object.freeze(Array.from({ length: SHARD_COUNT }, (_, i) => shardJob(i + 1)));
// Nom affiché par GitHub quand la matrice entière est sautée (PR purement documentaire).
const SHARD_JOB_SKIPPED = 'Suites ${{ matrix.shard }}/' + SHARD_COUNT;
const OFFICIAL_JOBS = Object.freeze(['classification', ...SHARD_JOBS, 'Validation CI']);
const GODOT_JOBS = Object.freeze(Array.from({ length: GODOT_SHARD_COUNT },
  (_, i) => 'Godot ' + (i + 1) + '/' + GODOT_SHARD_COUNT));
const GODOT_JOB_SKIPPED = 'Godot ${{ matrix.shard }}/' + GODOT_SHARD_COUNT;
// Jobs hors des listes exactes des gates : leur verdict est déjà porté par « Validation CI » (qui dépend d'eux),
// et ils sont sautés sur une PR sans fichier Godot, donc absents de la liste officielle.
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
  SHARD_COUNT, SHARD_PARALLEL, PHYSICAL_CORES, RAPIDE_MAX_S, RAPIDE_GODOT_MAX_S, EXCLUSIVE_CAP, EXCLUSIVE_WEIGHT, GODOT_SHARD_COUNT, SHARD_JOBS, SHARD_JOB_SKIPPED, OFFICIAL_JOBS,
  GODOT_JOBS, GODOT_JOB_SKIPPED, isInformativeJob, officialJobs, shardSeries, shardJob
};
