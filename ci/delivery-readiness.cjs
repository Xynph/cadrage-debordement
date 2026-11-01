'use strict';
// Bilan informatif uniquement. Aucune fusion, aucun dispatch, aucun code de PR exécuté.
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const {decide} = require('./release-gate.cjs');
const {fullCI, latestCI} = require('./chat-release.cjs');
const REPO = 'Xynph/cadrage-debordement';
const SHA = /^[0-9a-f]{40}$/;
const JOBS = ['classification', ...[1,2,3,4,5].map(i => `Suites ${i}/5`), 'Validation CI'];
function need(value, message) { if (!value) throw Error(message); }
function completeJobs(jobs) {
  return Array.isArray(jobs) && jobs.length === JOBS.length && JOBS.every(name =>
    jobs.filter(j => j.name === name && j.status === 'completed' && j.conclusion === 'success').length === 1);
}
function latestRuns(runs, sha) {
  const selected = new Map();
  for (const r of runs) {
    if (r.head_sha !== sha || r.event !== 'pull_request') continue;
    need(Number.isSafeInteger(r.id) && Number.isSafeInteger(r.workflow_id), 'Identité de run absente');
    if (!selected.has(r.workflow_id) || selected.get(r.workflow_id).id < r.id) selected.set(r.workflow_id, r);
  }
  return [...selected.values()].sort((a,b) => a.workflow_id - b.workflow_id);
}
function aggregate(s) {
  const reasons = [];
  const reject = (condition, reason) => { if (!condition) reasons.push(reason); };
  reject(SHA.test(s.expected) && s.pr?.head?.sha === s.expected, 'HEAD différent du SHA attendu');
  reject(SHA.test(s.main), 'SHA main invalide');
  reject(s.pr?.head?.repo?.full_name === REPO && s.pr?.base?.repo?.full_name === REPO, 'Dépôt de PR invalide');
  reject(s.behind === 0, 'Branche obsolète ou comparaison inconnue');
  reject(s.workflow?.state === 'active', 'Workflow principal inactif');
  const runs = latestRuns(s.runs, s.expected);
  const official = runs.find(r => r.workflow_id === s.workflow.id && r.path === '.github/workflows/tests.yml');
  const gate = decide(s.pr, official ? [official] : [], official ? s.jobs[official.id] : []);
  reject(gate.ready, 'Gate officiel : ' + gate.reason);
  reject(!!official && completeJobs(s.jobs[official.id]), 'CI PR complète 7/7 absente');
  reject(fullCI(s.mainRun, s.mainJobs, s.main, s.workflow.id), 'CI main complète 7/7 absente');
  for (const r of runs) {
    reject(r.pull_requests?.some(p => p.number === s.pr.number), 'Association CI/PR absente ou incertaine');
    const jobs = s.jobs[r.id] || [];
    reject(r.status === 'completed' && r.conclusion === 'success' && jobs.length > 0 &&
      jobs.every(j => j.status === 'completed' && j.conclusion === 'success'), `CI ${r.workflow_id} non entièrement verte`);
  }
  const ready = reasons.length === 0;
  return {ready, pr:s.pr.number, sha:s.expected, main:s.main, reasons,
    command:ready ? `/cd-check ${s.pr.number} ${s.expected}` : null,
    mainRun:s.mainRun?.id || null,
    runs:runs.map(r => ({id:r.id, workflowId:r.workflow_id, status:r.status, conclusion:r.conclusion,
      jobs:(s.jobs[r.id] || []).map(j => ({name:j.name, status:j.status, conclusion:j.conclusion}))}))};
}
function paged(api, endpoint, key) {
  const out = [];
  for (let page=1; page<=10; page++) {
    const response = api(`${endpoint}${endpoint.includes('?')?'&':'?'}per_page=100&page=${page}`);
    const batch = response?.[key];
    need(Array.isArray(batch), 'Réponse API incomplète : ' + key);
    out.push(...batch);
    if (batch.length < 100) return out;
  }
  throw Error('Pagination excessive : bilan refusé plutôt que tronqué');
}
function fingerprint(runs) {
  return JSON.stringify(runs.map(r => [r.id,r.workflow_id,r.head_sha,r.status,r.conclusion,r.run_attempt || 1]).sort((a,b)=>a[0]-b[0]));
}
function inspect(number, expected, api) {
  need(Number.isSafeInteger(number) && number > 0 && SHA.test(expected), 'PR et SHA40 requis');
  const main = api('git/ref/heads/main').object.sha;
  const pr = api(`pulls/${number}`);
  need(pr.number === number, 'Numéro PR incohérent');
  need(pr.head?.sha === expected, 'HEAD a changé');
  const workflow = api('actions/workflows/tests.yml');
  const behind = api(`compare/${main}...${expected}`).behind_by;
  const getRuns = () => paged(api, `actions/runs?event=pull_request&head_sha=${expected}`, 'workflow_runs');
  const getMain = () => paged(api, 'actions/workflows/tests.yml/runs?branch=main', 'workflow_runs');
  const runs = getRuns(), mainRuns = getMain();
  const selected = latestRuns(runs, expected);
  const mainRun = latestCI(mainRuns, main, workflow.id);
  const jobs = {};
  for (const r of selected) jobs[r.id] = paged(api, `actions/runs/${r.id}/jobs?filter=latest`, 'jobs');
  const mainJobs = mainRun ? paged(api, `actions/runs/${mainRun.id}/jobs?filter=latest`, 'jobs') : [];
  const result = aggregate({pr,expected,main,workflow,behind,runs,jobs,mainRun,mainJobs});
  need(fingerprint(selected) === fingerprint(latestRuns(getRuns(), expected)), 'CI PR modifiée pendant le bilan');
  need(fingerprint(mainRun?[mainRun]:[]) === fingerprint([latestCI(getMain(),main,workflow.id)].filter(Boolean)), 'CI main modifiée pendant le bilan');
  const fresh = api(`pulls/${number}`);
  need(fresh.head?.sha === expected && fresh.state === pr.state && fresh.draft === pr.draft &&
    fresh.mergeable === pr.mergeable && fresh.mergeable_state === pr.mergeable_state &&
    fresh.base?.ref === pr.base.ref && fresh.base?.sha === pr.base.sha &&
    fresh.head?.repo?.full_name === pr.head.repo.full_name, 'PR modifiée pendant le bilan');
  need(api('git/ref/heads/main').object.sha === main, 'main modifié pendant le bilan');
  return result;
}
function validateDispatch(env, main) {
  need(env.GITHUB_EVENT_NAME === 'workflow_dispatch' && env.GITHUB_REPOSITORY === REPO &&
    env.GITHUB_REF === 'refs/heads/main' && env.GITHUB_SHA === main &&
    env.GITHUB_ACTOR === 'Xynph' && env.GITHUB_ACTOR_ID === '350229047' &&
    env.GITHUB_TRIGGERING_ACTOR === 'Xynph', 'Dispatch réservé au propriétaire sur le main courant');
  return true;
}
function markdown(r) {
  // Les noms de jobs sont des métadonnées non fiables ; encoder plutôt qu'interpréter du Markdown.
  const safe = v => String(v ?? 'inconnu').replace(/[&<>|`\r\n]/g, c => `&#${c.charCodeAt(0)};`);
  const url = id => `https://github.com/${REPO}/actions/runs/${id}`;
  return `### PASSATION — bilan de livraison informatif — PR #${r.pr}\n\n` +
    `HEAD : \`${r.sha}\` ; main : \`${r.main}\`.\n\n` +
    `État observé : **${r.ready?'précontrôle satisfait':'bloqué'}**. Aucune fusion effectuée.\n\n` +
    `CI main : ${r.mainRun ? url(r.mainRun) : 'absente'}.\n\n` +
    r.runs.map(run => `- ${url(run.id)} : ${safe(run.status)}/${safe(run.conclusion)} ; ` +
      `${run.jobs.filter(j=>j.status==='completed'&&j.conclusion==='success').length}/${run.jobs.length} jobs verts.`).join('\n') +
    '\n\n' + r.reasons.map(x=>'- '+safe(x)).join('\n') +
    (r.command ? `\n\nSimulation — commande à publier par le propriétaire après relecture des SHA :\n\n\`/cd-check ${r.pr} ${r.sha}\`\n` : '\n\nAucune commande proposée tant que le bilan est bloqué.\n') +
    '\nCe bilan ne remplace ni Validation CI, ni le gate officiel, ni l’autorisation explicite de Léo pour une fusion. ' +
    'Il couvre les workflows PR observés sur ce SHA, sans certifier les protections serveur ni les contrôles externes.\n';
}
function publication(result, env, currentMain) {
  validateDispatch(env, currentMain);
  need(result.main === currentMain && env.CD_PUBLISH === 'true' && env.CD_PUBLISH_ENABLED === 'true',
    'Publication interdite sans double opt-in et main identique');
  return markdown(result);
}
function api(endpoint, method='GET', body) {
  // Surface réseau fermée : GET ou commentaire #73, jamais merge, dispatch ou update ref.
  need(method === 'GET' || (method === 'POST' && endpoint === 'issues/73/comments'), 'Mutation interdite');
  const args = ['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10',`repos/${REPO}/${endpoint}`];
  if (body) args.push('--input','-');
  return JSON.parse(execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,timeout:30000,maxBuffer:8*1024*1024}));
}
function main(argv=process.argv.slice(2), env=process.env) {
  need(argv.length===2 && /^[1-9][0-9]*$/.test(argv[0]) && SHA.test(argv[1]), 'Usage : node ci/delivery-readiness.cjs PR SHA40');
  // Même le job de publication recharge les preuves : aucun artefact de PR n’est consommé.
  if (env.GITHUB_ACTIONS === 'true') validateDispatch(env, api('git/ref/heads/main').object.sha);
  const result = inspect(Number(argv[0]),argv[1],api);
  const output = markdown(result);
  if (env.GITHUB_STEP_SUMMARY) fs.appendFileSync(env.GITHUB_STEP_SUMMARY,output);
  console.log(output);
  if (env.CD_PUBLISH === 'true') {
    const body = publication(result,env,api('git/ref/heads/main').object.sha);
    api('issues/73/comments','POST',{body});
  }
  if (!result.ready) process.exitCode=1;
}
if (require.main===module) {try {main();} catch(e) {console.error(e.message);process.exitCode=1;}}
module.exports = {aggregate,inspect,validateDispatch,publication,markdown};
