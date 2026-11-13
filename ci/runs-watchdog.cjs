'use strict';
// Chien de garde des exécutions GitHub Actions bloquées (13/11/2026).
// Constat : des exécutions restent « queued » des heures alors que des places sont libres
// (bug côté GitHub). Elles bloquent le groupe de concurrence de leur PR : rien ne repart.
// Règle : une exécution « queued » depuis plus de STUCK_MINUTES, alors qu'au moins
// FREE_SLOTS places sont libres, est annulée puis relancée (même SHA, même événement).
// Une exécution sans job (fantôme) ne s'annule pas côté GitHub et n'occupe rien : ignorée.
// Usage : node ci/runs-watchdog.cjs [--dry-run]   (GH_TOKEN, GITHUB_REPOSITORY)
const {execFileSync} = require('node:child_process');

const STUCK_MINUTES = 45;
const CAPACITY = 40;   // GitHub Pro : 40 jobs hébergés simultanés
const FREE_SLOTS = 8;  // marge : on ne juge « bloquée » que si la file n'est pas pleine
const MAX_ACTIONS = 10;

function decide(runs, jobsInProgress, now, options = {}) {
  const stuck = options.stuckMinutes ?? STUCK_MINUTES, capacity = options.capacity ?? CAPACITY;
  if (capacity - jobsInProgress < (options.freeSlots ?? FREE_SLOTS)) return [];
  return runs
    .filter(r => r.status === 'queued' && r.jobCount > 0 && r.event !== 'workflow_dispatch' &&
      (now - Date.parse(r.created_at)) / 60000 >= stuck)
    .sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at))
    .slice(0, options.maxActions ?? MAX_ACTIONS)
    .map(r => r.id);
}

function newerExists(runs, run) {
  return runs.some(r => r.id !== run.id && r.workflow_id === run.workflow_id && r.head_branch === run.head_branch &&
    Date.parse(r.created_at) > Date.parse(run.created_at));
}

function gh(args) {
  return execFileSync('gh', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
}
function api(path, method = 'GET') {
  const out = gh(['api', '-X', method, path]);
  return out.trim() ? JSON.parse(out) : {};
}
function sleep(ms) { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms); }

function main() {
  const repo = process.env.GITHUB_REPOSITORY, dry = process.argv.includes('--dry-run');
  if (!repo) throw Error('GITHUB_REPOSITORY manquant');
  const list = status => api(`repos/${repo}/actions/runs?status=${status}&per_page=100`).workflow_runs || [];
  let inProgress = 0;
  for (const r of list('in_progress'))
    inProgress += (api(`repos/${repo}/actions/runs/${r.id}/jobs?per_page=100`).jobs || [])
      .filter(j => j.status === 'in_progress').length;
  const queued = list('queued').map(r => ({...r,
    jobCount: api(`repos/${repo}/actions/runs/${r.id}/jobs?per_page=1`).total_count || 0}));
  const pending = list('pending');
  const ids = decide(queued, inProgress, Date.now());
  console.log(`Jobs en cours : ${inProgress}/${CAPACITY} ; exécutions en file : ${queued.length} ; bloquées : ${ids.length}`);
  const summary = [`## Chien de garde CI`, ``, `- Jobs en cours : ${inProgress}/${CAPACITY}`, `- En file : ${queued.length}`, `- Relancées : ${ids.length}${dry ? ' (simulation)' : ''}`];
  for (const id of ids) {
    const run = queued.find(r => r.id === id);
    summary.push(`- ${run.name} · ${run.event} · ${run.head_branch} · créée ${run.created_at} · [${id}](${run.html_url})`);
    if (dry) continue;
    try {
      // Annulation normale, puis forcée : les exécutions bloquées refusent souvent la première
      // (constat 13/11 : 11 jobs terminés, 1 resté « queued », annulation sans effet).
      const done = () => api(`repos/${repo}/actions/runs/${id}`).status === 'completed';
      api(`repos/${repo}/actions/runs/${id}/cancel`, 'POST');
      for (let i = 0; i < 4 && !done(); i++) sleep(5000);
      if (!done()) { api(`repos/${repo}/actions/runs/${id}/force-cancel`, 'POST'); for (let i = 0; i < 4 && !done(); i++) sleep(5000); }
      // Relance seulement si aucune exécution plus récente du même workflow n'attend déjà
      // sur la même branche (elle prend le relais dès que le groupe est libéré).
      if (newerExists(queued.concat(pending), run)) { console.log(`Annulée (une exécution plus récente prend le relais) : ${id}`); continue; }
      api(`repos/${repo}/actions/runs/${id}/rerun`, 'POST');
      console.log(`Relancée : ${id} (${run.name}, ${run.head_branch})`);
    } catch (e) {
      console.log(`::warning::Relance impossible pour ${id} : ${String(e.stderr || e.message).slice(0, 200)}`);
    }
  }
  if (process.env.GITHUB_STEP_SUMMARY) require('node:fs').appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary.join('\n') + '\n');
}

module.exports = {decide, newerExists, STUCK_MINUTES, CAPACITY, FREE_SLOTS};
if (require.main === module) main();
