'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validateEvent,fullCI,latestCI,latestPushCI,execute}=require('../ci/chat-release.cjs');
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
  if(path.startsWith('actions/workflows/tests.yml/runs?'))return {workflow_runs:options.pushPost&&head===b?[run(a,1),{...run(b,2,'push'),conclusion:options.redPush?'failure':'success'}]:dispatched?[run(a,1),run(options.wrongPostSha?a:b,2,'workflow_dispatch')]:[{...run(a,1),conclusion:options.redMain?'failure':'success'}]};
  if(path==='actions/runs/1/jobs?per_page=100&page=1'||path==='actions/runs/2/jobs?per_page=100&page=1')return {jobs:options.badJobs?jobs().slice(1):jobs()};
  if(path==='pulls/198')return {head:{sha:options.stale?c:b}};
  if(path==='actions/workflows/tests.yml/dispatches'){dispatched=true;return options.directId?{workflow_run_id:2}:null;}
  if(path==='actions/runs/2')return options.pushPost?{...run(b,2,'push'),conclusion:options.redPush?'failure':'success'}:run(options.wrongPostSha?a:b,2,'workflow_dispatch');
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
 assert(f.calls.filter(x=>x.path?.startsWith('actions/workflows/tests.yml/runs?')).length>=2);
});
test('sélection push : SHA, workflow et event exacts et plus récent',()=>{
 assert.equal(latestPushCI([run(b,2,'workflow_dispatch'),run(a,3,'push'),run(b,4,'push'),run(b,5,'push')],b,10).id,5);
 assert.equal(latestPushCI([run(a,3,'push')],b,10),undefined);
 assert.equal(latestPushCI([{...run(b,8,'push'),workflow_id:11}],b,10),undefined);
});
test('réutilise la CI push post-fusion verte sans lancer de deuxième CI',async()=>{
 const f=fixture({pushPost:true});const result=await execute(f.cmd,event(),f.deps);
 assert.equal(result.postRun,2);
 assert(!f.calls.some(x=>x.path==='actions/workflows/tests.yml/dispatches'));
 assert(f.calls.some(x=>x.watch));
});
test('une CI push post-fusion rouge bloque la livraison et interdit un dispatch masquant',async()=>{
 const f=fixture({pushPost:true,redPush:true});
 await assert.rejects(()=>execute(f.cmd,event(),f.deps),/CI post-fusion/);
 assert(!f.calls.some(x=>x.path==='actions/workflows/tests.yml/dispatches'));
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
  const preload=path.join(dir,'fake-gh.cjs');
  fs.writeFileSync(preload,`const fs=require('node:fs');
require('node:child_process').execFileSync=(file,args)=>{
 if(file!=='gh')throw Error('Exécutable inattendu dans le test : '+file);
 fs.appendFileSync(${JSON.stringify(log)},JSON.stringify(args)+'\\n');
 const url=args[3];
 return JSON.stringify(url.endsWith('/merge')?{merged:true,sha:${JSON.stringify(c)}}:url.includes('/jobs?')?{jobs:[{name:'Validation CI',status:'completed',conclusion:'success'}]}:url.includes('/runs?')?{workflow_runs:[${JSON.stringify(ci)}]}:${JSON.stringify(pr)});
};`);
  const r=spawnSync(process.execPath,['--require',preload,path.resolve(__dirname,'../ci/release-gate.cjs'),'198','--merge'],{env:{...process.env,CD_EXPECTED_HEAD_SHA:b},encoding:'utf8'});
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

const REPAIR_HEAD='59aeb359c9966a892ac8994e636af38f12fe0bbd';
const REPAIR_MAIN='f189d09f317b73d4e9e3d54ee694e6c4c2c9262b';
const REPAIR_RUN=41427301234;
function repairFixture(options={}){
 const calls=[];
 const e=event();e.comment.body='/cd-repair-check 212 '+REPAIR_HEAD+' '+REPAIR_MAIN+' '+REPAIR_RUN;
 const cmd=validateEvent(e,env);
 const failed=jobs().map(j=>({...j}));
 for(const name of ['Suites 1/5','Validation CI'])failed.find(x=>x.name===name).conclusion='failure';
 if(options.wrongFailure)failed.find(x=>x.name==='classification').conclusion='failure';
 if(options.skippedShard)failed.find(x=>x.name==='Suites 2/5').conclusion='skipped';
 if(options.extraJob)failed.push({name:'extra',status:'completed',conclusion:'success'});
 const badRun={...run(REPAIR_MAIN,options.wrongRun?REPAIR_RUN-1:REPAIR_RUN,'workflow_dispatch'),conclusion:'failure'};
 const api=(url)=>{
  calls.push(url);
  if(url==='issues/comments/123')return {...e.comment,issue_url:'https://api.github.com/repos/'+repo+'/issues/73'};
  if(url==='git/ref/heads/main')return {object:{sha:options.movedMain?c:REPAIR_MAIN}};
  if(url==='actions/workflows/tests.yml')return {id:10,state:'active'};
  if(url.startsWith('actions/workflows/tests.yml/runs?'))return {workflow_runs:[badRun]};
  if(url==='actions/runs/'+badRun.id+'/jobs?per_page=100&page=1')return {jobs:failed};
  if(url==='pulls/212')return {head:{sha:options.wrongHead?c:REPAIR_HEAD},base:{ref:'main',sha:REPAIR_MAIN}};
  if(url==='pulls/212/files?per_page=100')return [{filename:options.wrongFile?'ci/chat-release.cjs':'tests/governance-exclusive.test.cjs',status:'modified'}];
  throw Error('Unexpected API '+url);
 };
 const deps={api,snapshot:REPAIR_MAIN,execGate:(pr,sha,merge)=>{calls.push('gate');assert.equal(pr,212);assert.equal(sha,REPAIR_HEAD);assert.equal(merge,false);return 'ready:true';}};
 return {e,cmd,calls,deps};
}
test('réparation explicite : commande propriétaire au SHA verrouillé',()=>{
 const f=repairFixture();assert.equal(f.cmd.pr,212);assert.equal(f.cmd.mode,'repair-check');
 assert.equal(f.cmd.expected,REPAIR_HEAD);assert.equal(f.cmd.repairMain,REPAIR_MAIN);assert.equal(f.cmd.failedRun,REPAIR_RUN);
});
test('réparation vérifiée en lecture seule malgré main rouge précis',async()=>{
 const f=repairFixture();
 const x=await execute(f.cmd,f.e,f.deps);
 assert.equal(x.mode,'repair-check');
 assert(f.calls.includes('gate'));
 assert(!f.calls.some(x=>x.includes('dispatches')));
});
for(const option of ['wrongRun','wrongFailure','wrongHead','wrongFile','movedMain','skippedShard','extraJob'])
 test('réparation refuse '+option,async()=>{
  const f=repairFixture({[option]:true});
  await assert.rejects(()=>execute(f.cmd,f.e,f.deps));
  assert(!f.calls.includes('gate'));
 });
test('les commandes ordinaires ne profitent jamais de la réparation',async()=>{
 const f=repairFixture();
 f.e.comment.body='/cd-check 212 '+REPAIR_HEAD;
 f.cmd=validateEvent(f.e,env);
 await assert.rejects(()=>execute(f.cmd,f.e,f.deps));
 assert(!f.calls.includes('gate'));
});
test('une autre PR ne peut obtenir un traitement de réparation',async()=>{
 const f=repairFixture();
 f.e.comment.body='/cd-repair-check 213 '+REPAIR_HEAD+' '+REPAIR_MAIN+' '+REPAIR_RUN;
 f.cmd=validateEvent(f.e,env);
 await assert.rejects(()=>execute(f.cmd,f.e,f.deps));
 assert(!f.calls.includes('gate'));
});
test('workflow Chat garde le même rôle privilégié et reconnaît seulement la nouvelle famille de commandes',()=>{
 const fs=require('node:fs'),path=require('node:path');
 const y=fs.readFileSync(path.resolve(__dirname,'../.github/workflows/chat-release-gate.yml'),'utf8');
 assert.match(y,/startsWith\(github.event.comment.body, '\/cd-repair-check '/);
 assert.match(y,/startsWith\(github.event.comment.body, '\/cd-repair-merge '/);
 assert.match(y,/group: chat-release-gate-main/);
 assert.match(y,/^permissions: \{\}$/m);
 assert(!y.includes('pull_request_target'));
});

test('commande de récupération refuse l’absence de SHA main ou run',()=>{
 const e=event();e.comment.body='/cd-repair-check 212 '+REPAIR_HEAD;
 assert.throws(()=>validateEvent(e,env));
});
test('commande de récupération refuse un run nommé différent du dernier',async()=>{
 const f=repairFixture();
 f.e.comment.body='/cd-repair-check 212 '+REPAIR_HEAD+' '+REPAIR_MAIN+' '+(REPAIR_RUN+1);
 f.cmd=validateEvent(f.e,env);
 await assert.rejects(()=>execute(f.cmd,f.e,f.deps));
 assert(!f.calls.includes('gate'));
});
