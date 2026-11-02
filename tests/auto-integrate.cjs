'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {validateEvent,validateDispatch,safeFiles,verify}=require('../ci/auto-integrate.cjs');
const {validateRequest}=require('../ci/auto-integrate-request.cjs');
const {execute}=require('../ci/chat-release.cjs');
const REPO='Xynph/cadrage-debordement',SHA='a'.repeat(40),MAIN='b'.repeat(40);
function e(){return {action:'labeled',repository:{full_name:REPO,id:1439603196},label:{name:'cd-integrate'},sender:{id:350229047,login:'Xynph',type:'User'},pull_request:{number:241,base:{ref:'main',repo:{full_name:REPO}},head:{sha:SHA,repo:{full_name:REPO}}}};}
const env={GITHUB_EVENT_NAME:'pull_request_target',GITHUB_REPOSITORY:REPO,GITHUB_ACTOR:'Xynph',GITHUB_TRIGGERING_ACTOR:'Xynph',GITHUB_SHA:MAIN};
test('activation uniquement par étiquette propriétaire, base et tête immuables',()=>{
 assert.deepEqual(validateEvent(e(),env),{pr:241,expected:SHA,base:MAIN,mode:'merge'});
});
for(const [description,modify] of [
 ['action edited',x=>x.action='edited'],['autre étiquette',x=>x.label.name='ready'],
 ['autre dépôt',x=>x.repository.id++],['autre compte',x=>x.sender.id++],
 ['compte bot',x=>x.sender.type='Bot'],['autre base',x=>x.pull_request.base.ref='develop'],
 ['fork',x=>x.pull_request.head.repo.full_name='external/fork'],
 ['SHA tronqué',x=>x.pull_request.head.sha='123'],['numéro invalide',x=>x.pull_request.number=0]
]){
 test('refuse '+description,()=>{const x=e();modify(x);assert.throws(()=>validateEvent(x,env));});
}
for(const [description,patch] of [
 ['événement issue_comment',{GITHUB_EVENT_NAME:'issue_comment'}],
 ['acteur externe',{GITHUB_ACTOR:'other'}],['relance externe',{GITHUB_TRIGGERING_ACTOR:'other'}],
 ['snapshot sans SHA',{GITHUB_SHA:'main'}]
]){
 test('refuse '+description,()=>assert.throws(()=>validateEvent(e(),{...env,...patch})));
}
test('seuls petits fichiers UI JavaScript ou tests sont autorisés',()=>{
 assert.equal(safeFiles([{filename:'dist/manager-mobility.js',status:'modified'},{filename:'tests/v58-native-dashboard.cjs',status:'added'}]),true);
 for(const file of ['AGENTS.md','DEVELOPPEMENT.md','ci/chat-release.cjs','dist/rugby.js','dist/saves.js','dist/world-career.js','.github/workflows/tests.yml','modding/data06/rugby-master-2026-2027.json','dist/index.html','tests/chat-release.cjs']){
   assert.equal(safeFiles([{filename:file,status:'modified'}]),false,file);
 }
 assert.equal(safeFiles([{filename:'dist/manager-mobility.js',status:'removed'}]),false);
 assert.equal(safeFiles([{filename:'dist/manager-mobility.js',previous_filename:'dist/saves.js',status:'renamed'}]),false);
 assert.throws(()=>safeFiles([]));
 assert.throws(()=>safeFiles(Array.from({length:100},()=>({filename:'tests/x.cjs',status:'modified'}))));
});
function sample(options={}){
 const cmd={pr:241,expected:SHA,base:MAIN,mode:'merge'},calls=[];
 const pr={number:241,state:'open',draft:false,head:{sha:options.stale?'c'.repeat(40):SHA,repo:{full_name:REPO}},base:{ref:'main',sha:options.mainChanged?'c'.repeat(40):MAIN,repo:{full_name:REPO}},labels:options.noLabel?[]:[{name:'cd-integrate'}]};
 const api=url=>{
   calls.push(url);
   if(url==='pulls/241')return pr;
   if(url==='pulls/241/files?per_page=100')return [{filename:options.sensitive?'dist/saves.js':'dist/manager-mobility.js',status:'modified'}];
   throw Error('unattested api '+url);
 };
 return {cmd,api,calls};
}
test('précontrôle relit PR HEAD, base, label et chemins dans GitHub',()=>{
 const x=sample();assert.equal(verify(x.cmd,x.api),true);
 assert.deepEqual(x.calls,['pulls/241','pulls/241/files?per_page=100']);
});
for(const option of ['stale','mainChanged','noLabel','sensitive'])test('aucune voie rapide si '+option,()=>{
 const x=sample({[option]:true});assert.throws(()=>verify(x.cmd,x.api));
});
test('execute refuse un contexte sans commentaire non expressément autorisé',async()=>{
 const cmd={pr:241,expected:SHA,mode:'merge'},calls=[];
 await assert.rejects(()=>execute(cmd,e(),{api:(url)=>{calls.push(url);throw Error('no api needed')},snapshot:MAIN,autoAuthorized:false}),/non autorisée/);
 assert.deepEqual(calls,[]);
});
test('demande étiquetée liée au main et au run original',()=>{
 const x=sample();
 const api=url=>url==='git/ref/heads/main'?{object:{sha:MAIN}}:x.api(url);
 assert.deepEqual(validateRequest(e(),{...env,GITHUB_RUN_ID:'456'},api),{pr:'241',sha:SHA,source_run:'456'});
 assert.throws(()=>validateRequest(e(),{...env,GITHUB_RUN_ID:'456'},url=>
   url==='git/ref/heads/main'?{object:{sha:'c'.repeat(40)}}:x.api(url)));
});
const dispatched={inputs:{pr:'241',sha:SHA,source_run:'456'}};
const dispatchEnv={GITHUB_EVENT_NAME:'workflow_dispatch',GITHUB_REPOSITORY:REPO,GITHUB_REF:'refs/heads/main',GITHUB_SHA:MAIN};
const source=()=>({event:'pull_request_target',path:'.github/workflows/auto-integrate-request.yml',
 actor:{id:350229047,login:'Xynph',type:'User'},status:'completed',conclusion:'success',
 head_sha:SHA,pull_requests:[{number:241}]});
test('dispatch autorisé seulement après un run de sélection propriétaire terminé',()=>{
 const cmd=validateDispatch(dispatched,dispatchEnv,()=>source());
 assert.deepEqual(cmd,{pr:241,expected:SHA,base:MAIN,mode:'merge'});
});
for(const [description,patch] of [
 ['run rouge',{conclusion:'failure'}],['run encore en cours',{status:'in_progress'}],
 ['autre workflow',{path:'.github/workflows/unsafe.yml'}],['autre acteur',{actor:{id:99,login:'other',type:'User'}}],
 ['mauvais SHA',{head_sha:'c'.repeat(40)}],['PR absente',{pull_requests:[]}],
 ['autre événement',{event:'workflow_dispatch'}]
])test('dispatch refuse '+description,()=>{
 assert.throws(()=>validateDispatch(dispatched,dispatchEnv,()=>({...source(),...patch})));
});
test('dispatch refuse un SHA invalide et une branche non-main',()=>{
 assert.throws(()=>validateDispatch({inputs:{...dispatched.inputs,sha:'wrong'}},dispatchEnv,()=>source()));
 assert.throws(()=>validateDispatch(dispatched,{...dispatchEnv,GITHUB_REF:'refs/heads/feature'},()=>source()));
});
test('deux workflows privilégiés isolés, concurrence unique, aucun code de PR',()=>{
 const first=fs.readFileSync(path.join(__dirname,'../.github/workflows/auto-integrate-request.yml'),'utf8');
 const second=fs.readFileSync(path.join(__dirname,'../.github/workflows/auto-integrate.yml'),'utf8');
 assert.match(first,/pull_request_target:/);
 assert.match(first,/types: \[labeled\]/);
 assert.match(first,/github\.event\.label\.name == 'cd-integrate'/);
 assert.match(first,/github\.event\.sender\.id == 350229047/);
 assert.match(first,/run: node ci\/auto-integrate-request\.cjs/);
 assert.match(second,/workflow_dispatch:/);
 assert(!second.includes('pull_request_target:'));
 assert.match(second,/run: node ci\/auto-integrate\.cjs/);
 for(const y of [first,second]){
   assert.match(y,/^permissions: \{\}$/m);
   assert.match(y,/group: chat-release-gate-main/);
   assert.match(y,/ref: \$\{\{ github.sha \}\}/);
   assert.match(y,/persist-credentials: false/);
   assert(!y.includes('secrets.'));
   assert(!y.includes('id-token:'));
   assert(!y.includes('github.event.pull_request.head.sha }}'));
   for(const action of y.matchAll(/uses: (\S+)/g))assert.match(action[1],/@[0-9a-f]{40}$/);
 }
});
