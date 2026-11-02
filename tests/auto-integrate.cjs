'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {validateEvent,safeFiles,verify}=require('../ci/auto-integrate.cjs');
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
test('workflow privilégié uniquement sur main, sans code PR ni interpolation',()=>{
 const y=fs.readFileSync(path.join(__dirname,'../.github/workflows/auto-integrate.yml'),'utf8');
 assert.match(y,/pull_request_target:/);
 assert.match(y,/types: \[labeled\]/);
 assert.match(y,/^permissions: \{\}$/m);
 assert.match(y,/github\.event\.label\.name == 'cd-integrate'/);
 assert.match(y,/github\.event\.sender\.id == 350229047/);
 assert.match(y,/group: chat-release-gate-main/);
 assert.match(y,/ref: \$\{\{ github.sha \}\}/);
 assert.match(y,/persist-credentials: false/);
 assert(!y.includes('secrets.'));
 assert(!y.includes('id-token:'));
 assert(!y.includes('github.event.pull_request.head.sha }}'));
 for(const action of y.matchAll(/uses: (\S+)/g))assert.match(action[1],/@[0-9a-f]{40}$/);
});
