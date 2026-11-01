'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { aggregate, inspect, validateDispatch, publication, markdown } = require('../ci/delivery-readiness.cjs');
const repo = 'Xynph/cadrage-debordement';
const a = 'a'.repeat(40), b = 'b'.repeat(40), c = 'c'.repeat(40);
const names = ['classification', ...[1,2,3,4,5].map(i => `Suites ${i}/5`), 'Validation CI'];
const jobs = () => names.map(name => ({name, status:'completed', conclusion:'success'}));
const run = (id, sha=b, event='pull_request', workflow_id=10) => ({id, workflow_id, head_sha:sha, event,
  head_branch: event==='pull_request'?'feature':'main', name:'Tests JavaScript', path:'.github/workflows/tests.yml',
  status:'completed', conclusion:'success', created_at:`2026-11-01T00:00:${String(id).padStart(2,'0')}Z`,
  pull_requests:[{number:204}], html_url:`https://github.com/${repo}/actions/runs/${id}`});
const pr = () => ({number:204, state:'open', draft:false, mergeable:true, mergeable_state:'clean',
  base:{ref:'main',sha:a,repo:{full_name:repo}}, head:{sha:b,repo:{full_name:repo}}});
function snapshot() { return {pr:pr(), expected:b, main:a, workflow:{id:10,state:'active'}, behind:0,
  runs:[run(2)], jobs:{2:jobs()}, mainRun:run(1,a,'push'), mainJobs:jobs()}; }
test('bilan lié au HEAD/main et commande propriétaire sans fusion', () => {
  const s=snapshot(), result=aggregate(s);
  assert.equal(result.ready,true); assert.equal(result.command,`/cd-check 204 ${b}`);
  assert.match(markdown(result),/informatif/); assert.match(markdown(result),new RegExp(a));
  assert(!markdown(result).includes('/cd-merge'));
});
for (const [label, mutate] of [
  ['CI absente',s=>s.runs=[]],['en cours',s=>s.runs[0].status='in_progress'],
  ['échec',s=>s.runs[0].conclusion='failure'],['annulée',s=>s.runs[0].conclusion='cancelled'],
  ['autre SHA',s=>s.expected=c],['fork',s=>s.pr.head.repo.full_name='other/repo'],
  ['base obsolète',s=>s.behind=1],['merge incertain',s=>s.pr.mergeable_state='unknown'],
  ['brouillon',s=>s.pr.draft=true],['mauvais workflow',s=>s.runs[0].workflow_id=11],
  ['workflow inactif',s=>s.workflow.state='disabled_manually'],['jobs absents',s=>s.jobs[2]=[]],
  ['job ignoré',s=>s.jobs[2][1].conclusion='skipped'],['job dupliqué',s=>s.jobs[2].push(s.jobs[2][0])],
  ['main rouge',s=>s.mainRun.conclusion='failure'],['main autre SHA',s=>s.mainRun.head_sha=c],
  ['main incomplet',s=>s.mainJobs.pop()],['CI autre PR',s=>s.runs[0].pull_requests=[]],
  ['CI autre événement',s=>s.runs[0].event='workflow_dispatch']
]) test(`refus ${label}`,()=>{const s=snapshot();mutate(s);const r=aggregate(s);assert.equal(r.ready,false);assert.equal(r.command,null);});
test('dernière tentative rouge retenue et workflow auxiliaire bloquant',()=>{
  const s=snapshot();s.runs.push({...run(3),conclusion:'failure'});s.jobs[3]=jobs();assert.equal(aggregate(s).ready,false);
  s.runs=[run(2),{...run(4,b,'pull_request',20),name:'Audit',conclusion:'failure'}];s.jobs[4]=jobs();assert.equal(aggregate(s).ready,false);
});
function fixture(options={}) {
  const s=snapshot(), calls=[];if(options.badMainDate)s.mainRun.updated_at='invalide';let mainReads=0, prReads=0, runListReads=0;
  const api=(p,method='GET')=>{
    calls.push([p,method]);assert.equal(method,'GET');
    if(p==='git/ref/heads/main')return {object:{sha:++mainReads>1&&options.moveMain?c:a}};
    if(p==='pulls/204')return {...pr(),head:{...pr().head,sha:++prReads>1&&options.moveHead?c:b}};
    if(p==='actions/workflows/tests.yml')return s.workflow;
    if(p.startsWith('compare/'))return {behind_by:0,status:'ahead'};
    if(p.startsWith('actions/runs?')){runListReads++;return {workflow_runs:options.pages?Array(100).fill(run(2)):options.rerunDuring&&runListReads>1?[...s.runs,{...run(1),run_attempt:2,updated_at:'2026-11-01T00:01:00Z',conclusion:'failure'}]:s.runs};}
    if(p.startsWith('actions/workflows/tests.yml/runs?'))return {workflow_runs:options.mainRerun?[s.mainRun,{...run(0,a,'push'),run_attempt:2,updated_at:'2026-11-01T00:01:00Z',conclusion:'failure'}]:[s.mainRun]};
    if(p.startsWith('actions/runs/'))return {jobs:jobs()};
    throw Error('unexpected '+p);
  };
  return {calls,api};
}
test('collecte réelle en lecture seule, sans dispatch ni gate --merge',()=>{
 const f=fixture();assert.equal(inspect(204,b,f.api).ready,true);assert(f.calls.every(x=>x[1]==='GET'));
});
for(const option of ['moveMain','moveHead','pages'])test(`collecte refuse ${option}`,()=>{
 const f=fixture({[option]:true});assert.throws(()=>inspect(204,b,f.api));
});
const env={GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_REPOSITORY:repo,GITHUB_REF:'refs/heads/main',
 GITHUB_SHA:a,GITHUB_ACTOR:'Xynph',GITHUB_ACTOR_ID:'350229047',GITHUB_TRIGGERING_ACTOR:'Xynph'};
test('dispatch privilégié : main et propriétaire exacts',()=>{
 assert.equal(validateDispatch(env,a),true);
 for(const patch of [{GITHUB_REF:'refs/heads/feature'},{GITHUB_SHA:b},{GITHUB_ACTOR:'other'},
 {GITHUB_ACTOR_ID:'1'},{GITHUB_TRIGGERING_ACTOR:'other'},{GITHUB_EVENT_NAME:'issue_comment'},
 {GITHUB_REPOSITORY:'other/repo'}])assert.throws(()=>validateDispatch({...env,...patch},a));
});
test('publication double opt-in et verdict non vert toujours sans commande',()=>{
 const good=aggregate(snapshot());
 assert.throws(()=>publication(good,{...env,CD_PUBLISH:'true',CD_PUBLISH_ENABLED:'false'},a));
 assert.throws(()=>publication(good,{...env,CD_PUBLISH:'false',CD_PUBLISH_ENABLED:'true'},a));
 assert.throws(()=>publication(good,{...env,CD_PUBLISH:'true',CD_PUBLISH_ENABLED:'true'},c));
 const body=publication(good,{...env,CD_PUBLISH:'true',CD_PUBLISH_ENABLED:'true'},a);
 assert.match(body,/PASSATION/);assert.match(body,/commande à publier par le propriétaire/);
 const s=snapshot();s.mainRun.conclusion='failure';assert(!markdown(aggregate(s)).includes('/cd-check'));
});
test('workflow : pas de déclenchement automatique ou de code PR privilégié',()=>{
 const y=fs.readFileSync(path.resolve(__dirname,'../.github/workflows/delivery-readiness.yml'),'utf8');
 assert.match(y,/workflow_dispatch:/);assert.match(y,/^permissions: \{\}$/m);
 assert(!y.includes('pull_request_target'));assert(!y.includes('workflow_run:'));assert(!y.includes('issue_comment:'));
 assert(!y.includes('contents: write'));assert(!y.includes('actions: write'));assert(!y.includes('pull-requests: write'));
 assert.match(y,/persist-credentials: false/);assert.match(y,/CD_DELIVERY_PUBLISH/);
 for(const action of y.matchAll(/uses: (\S+)/g))assert.match(action[1],/@[0-9a-f]{40}$/);
 for(const line of y.split('\n').filter(line=>/^\s*run:/.test(line))) { assert(!line.includes('${{')); }
});
test('un nouveau run non associé ne laisse pas réutiliser un ancien succès',()=>{
 const s=snapshot();s.runs.push({...run(3),pull_requests:[],conclusion:'failure'});s.jobs[3]=jobs();
 assert.equal(aggregate(s).ready,false);
});
test('relance rouge plus récente d’un ancien ID : ancien succès non réutilisé',()=>{
 const s=snapshot();s.runs.push({...run(1),run_attempt:2,updated_at:'2026-11-01T00:01:00Z',conclusion:'failure'});
 s.jobs[1]=jobs();assert.equal(aggregate(s).ready,false);
});
test('égalité de date : une tentative en cours prévaut sur un succès',()=>{
 const s=snapshot();s.runs.push({...run(1),run_attempt:2,updated_at:s.runs[0].created_at,status:'in_progress',conclusion:null});
 s.jobs[1]=jobs();assert.equal(aggregate(s).ready,false);
});

test('relance rouge de main au même SHA : bilan bloqué',()=>{
 const f=fixture({mainRerun:true});assert.equal(inspect(204,b,f.api).ready,false);
});

test('relance pendant la relecture : preuve devenue périmée refusée',()=>{
 const f=fixture({rerunDuring:true});assert.throws(()=>inspect(204,b,f.api),/CI PR modifiée/);
});
test('un ancien échec réellement antérieur ne bloque pas un succès plus récent',()=>{
 const s=snapshot();s.runs.push({...run(1),updated_at:'2026-10-31T23:00:00Z',conclusion:'failure'});
 s.jobs[1]=jobs();assert.equal(aggregate(s).ready,true);
});
test('date CI invalide : aucune sélection devinée',()=>{
 const s=snapshot();s.runs[0].updated_at='date-invalide';assert.throws(()=>aggregate(s),/Date de tentative/);
});

test('main unique à date invalide : bilan refusé',()=>{
 const f=fixture({badMainDate:true});assert.throws(()=>inspect(204,b,f.api),/Date de tentative/);
});
