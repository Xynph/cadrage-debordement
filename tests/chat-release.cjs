'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validateEvent,fullCI,latestCI,execute}=require('../ci/chat-release.cjs');
const repo='Xynph/cadrage-debordement',owner={id:350229047,login:'Xynph',type:'User'};
const a='a'.repeat(40),b='b'.repeat(40),c='c'.repeat(40);
const event=()=>({action:'created',repository:{full_name:repo,id:1439603196},issue:{number:73},sender:{...owner},comment:{id:123,user:{...owner},body:'/cd-merge 198 '+b}});
const env={GITHUB_EVENT_NAME:'issue_comment',GITHUB_REPOSITORY:repo,GITHUB_ACTOR:'Xynph',GITHUB_TRIGGERING_ACTOR:'Xynph',GITHUB_SHA:a};
const names=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
const jobs=()=>names.map(name=>({name,status:'completed',conclusion:'success'}));
const run=(sha,id,event='push')=>({id,workflow_id:10,head_branch:'main',head_sha:sha,event,name:'Tests JavaScript',status:'completed',conclusion:'success'});
test('commande du propriétaire liée au dépôt, issue et SHA exacts',()=>{
 assert.deepEqual(validateEvent(event(),env),{pr:198,expected:b,mode:'merge',commentId:123});
 const e=event();e.comment.body='/cd-check 198 '+b;assert.equal(validateEvent(e,env).mode,'check');
});
for(const [name,change] of [
 ['autre auteur',e=>e.comment.user.id++],['login usurpé',e=>e.comment.user.login='other'],
 ['bot',e=>e.comment.user.type='Bot'],['autre émetteur',e=>e.sender.id++],
 ['autre issue',e=>e.issue.number=74],['commentaire PR',e=>e.issue.pull_request={}],
 ['autre dépôt',e=>e.repository.id++],['édition',e=>e.action='edited'],
 ['injection shell',e=>e.comment.body+='; echo hacked'],['multiligne',e=>e.comment.body+='\n'],
 ['SHA court',e=>e.comment.body='/cd-merge 198 abc'],['commande citée',e=>e.comment.body='> '+e.comment.body]
])test('refus '+name,()=>{const e=event();change(e);assert.throws(()=>validateEvent(e,env));});
test('événement, acteur et auteur de relance sont vérifiés',()=>{
 for(const patch of [{GITHUB_EVENT_NAME:'workflow_dispatch'},{GITHUB_ACTOR:'other'},{GITHUB_TRIGGERING_ACTOR:'other'}])assert.throws(()=>validateEvent(event(),{...env,...patch}));
});
test('sept jobs complets et même workflow/SHA requis, pas de skipped',()=>{
 assert.equal(fullCI(run(a,1),jobs(),a,10),true);
 for(const patch of [{head_sha:b},{workflow_id:11},{event:'pull_request'},{head_branch:'other'},{status:'in_progress'},{conclusion:'failure'}])assert.equal(fullCI({...run(a,1),...patch},jobs(),a,10),false);
 for(const result of ['skipped','failure','cancelled',null]){const j=jobs();j[1].conclusion=result;assert.equal(fullCI(run(a,1),j,a,10),false);}
 assert.equal(fullCI(run(a,1),jobs().slice(1),a,10),false);
 const j=jobs();j[1].name='Validation CI';assert.equal(fullCI(run(a,1),j,a,10),false);
});
test('une CI récente rouge ne peut être masquée par une ancienne verte',()=>{
 const bad={...run(a,2),conclusion:'failure'};assert.equal(latestCI([run(a,1),bad],a,10).id,2);
});
function fixture(options={}){
 let head=a,dispatched=false;const calls=[],cmd={pr:198,expected:b,mode:'merge',commentId:123};
 const api=(path,method='GET',body)=>{
  calls.push({path,method,body});
  if(path==='issues/comments/123')return {...event().comment,body:options.edited?'edited':event().comment.body,issue_url:'https://api.github.com/repos/'+repo+'/issues/73'};
  if(path==='git/ref/heads/main')return {object:{sha:options.mainChanged?c:head}};
  if(path==='actions/workflows/tests.yml')return {id:10,state:'active'};
  if(path.startsWith('actions/workflows/tests.yml/runs?'))return {workflow_runs:dispatched?[run(a,1),run(options.wrongPostSha?a:b,2,'workflow_dispatch')]:[{...run(a,1),conclusion:options.redMain?'failure':'success'}]};
  if(path==='actions/runs/1/jobs?per_page=100&page=1'||path==='actions/runs/2/jobs?per_page=100&page=1')return {jobs:options.badJobs?jobs().slice(1):jobs()};
  if(path==='pulls/198')return {head:{sha:options.stale?c:b}};
  if(path==='actions/workflows/tests.yml/dispatches'){dispatched=true;return options.directId?{workflow_run_id:2}:null;}
  if(path==='actions/runs/2')return run(options.wrongPostSha?a:b,2,'workflow_dispatch');
  throw Error('Unexpected API '+path);
 };
 return {cmd,calls,deps:{api,snapshot:a,sleep:async()=>{},execGate:(pr,expected,merge)=>{calls.push({gate:true,pr,expected,merge});if(options.gateFailure)throw Error('gate refused');if(merge)head=b;return merge?'Fusion '+b+' : verifier une seule fois le run push main sur ce SHA.':'';},watch:()=>calls.push({watch:true})}};
}
test('parcours complet : gate officiel, dispatch puis CI du SHA de fusion',async()=>{
 const f=fixture();const receipt=await execute(f.cmd,event(),f.deps);assert.equal(receipt.mergedSha,b);assert.equal(receipt.postRun,2);
 assert.deepEqual(f.calls.find(x=>x.gate),{gate:true,pr:198,expected:b,merge:true});
 assert(f.calls.find(x=>x.path?.endsWith('/dispatches')&&x.body.ref==='main'));
});
for(const option of ['redMain','mainChanged','stale','edited','badJobs'])test('aucune fusion si '+option,async()=>{
 const f=fixture({[option]:true});await assert.rejects(()=>execute(f.cmd,event(),f.deps));assert(!f.calls.some(x=>x.gate));
});
test('gate refusé : aucun dispatch ni annonce de succès',async()=>{
 const f=fixture({gateFailure:true});await assert.rejects(()=>execute(f.cmd,event(),f.deps));assert(!f.calls.some(x=>x.method==='POST'));
});
test('reçu REST de dispatch utilisé sans recherche approximative du run',async()=>{
 const f=fixture({directId:true});const result=await execute(f.cmd,event(),f.deps);assert.equal(result.postRun,2);
 assert.equal(f.calls.filter(x=>x.path?.startsWith('actions/workflows/tests.yml/runs?')).length,2);
});
test('CI sur autre SHA : échec même après mutation réussie',async()=>{
 const f=fixture({wrongPostSha:true});await assert.rejects(()=>execute(f.cmd,event(),f.deps));
});
test('cd-check exécute le gate sans merge ni dispatch',async()=>{
 const f=fixture();f.cmd.mode='check';const e=event();e.comment.body='/cd-check 198 '+b;
 const original=f.deps.api;f.deps.api=(p,...args)=>p==='issues/comments/123'?{...e.comment,issue_url:'https://api.github.com/repos/'+repo+'/issues/73'}:original(p,...args);
 const result=await execute(f.cmd,e,f.deps);assert.equal(result.mode,'check');assert.equal(f.calls.find(x=>x.gate).merge,false);assert(!f.calls.some(x=>x.method==='POST'));
});
test('le CLI officiel refuse un nouveau HEAD même si sa propre CI est verte',()=>{
 const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-gate-'));
 try{
  const log=path.join(dir,'calls');
  const pr={state:'open',base:{ref:'main'},head:{sha:c,repo:{full_name:repo}},draft:false,mergeable:true,mergeable_state:'clean'};
  const ci={id:1,name:'Tests JavaScript',event:'pull_request',head_sha:c,status:'completed',conclusion:'success',created_at:'2026-11-01T00:00:00Z'};
  fs.writeFileSync(path.join(dir,'gh'),'#!/usr/bin/env node\nconst fs=require("fs");const args=process.argv.slice(2);fs.appendFileSync('+JSON.stringify(log)+',JSON.stringify(args)+"\\n");const url=args[3];console.log(JSON.stringify(url.endsWith("/merge")?{merged:true,sha:'+JSON.stringify(c)+'}:url.includes("/jobs?")?{jobs:[{name:"Validation CI",status:"completed",conclusion:"success"}]}:url.includes("/runs?")?{workflow_runs:['+JSON.stringify(ci)+']}:'+JSON.stringify(pr)+'));',{mode:0o755});
  const r=spawnSync(process.execPath,[path.resolve(__dirname,'../ci/release-gate.cjs'),'198','--merge'],{env:{...process.env,PATH:dir+path.delimiter+process.env.PATH,CD_EXPECTED_HEAD_SHA:b},encoding:'utf8'});
  assert.equal(r.status,1);assert.match(r.stderr,/SHA attendu/);assert(!fs.readFileSync(log,'utf8').includes('/merge'));
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('workflow privilegie: permissions locales, checkout main fige, pas de commentaire interpole',()=>{
 const fs=require('node:fs'),path=require('node:path');
 const y=fs.readFileSync(path.join(__dirname,'../.github/workflows/chat-release-gate.yml'),'utf8');
 assert.match(y,/^permissions: \{\}$/m);assert.match(y,/pull-requests: read/);
 assert.match(y,/ref: \$\{\{ github.sha \}\}/);assert.match(y,/persist-credentials: false/);
 assert.match(y,/comment.user.id == 350229047/);assert.match(y,/cancel-in-progress: false/);
 assert(!y.includes('pull_request_target'));assert(!y.includes('secrets.'));assert(!y.includes('id-token:'));
 for(const action of y.matchAll(/uses: (\S+)/g))assert.match(action[1],/@[0-9a-f]{40}$/);
 assert(!y.includes('${{ github.event.comment.body }}'));
});
