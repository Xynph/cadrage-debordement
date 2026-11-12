'use strict';
const assert=require('node:assert/strict');
const {parseEvent,assess}=require('../ci/pr-preflight.cjs');
const SHA='a'.repeat(40),MAIN='b'.repeat(40);
const event={action:'created',repository:{id:1439603196,full_name:'Xynph/cadrage-debordement'},issue:{number:73},sender:{id:350229047,login:'Xynph'},comment:{id:42,user:{id:350229047,login:'Xynph'},body:'/cd-preflight 336 '+SHA}};
const env={GITHUB_EVENT_NAME:'issue_comment',GITHUB_REPOSITORY:'Xynph/cadrage-debordement',GITHUB_ACTOR:'Xynph',GITHUB_TRIGGERING_ACTOR:'Xynph'};
assert.deepEqual(parseEvent(event,env),{number:336,expected:SHA,commentId:42});
assert.throws(()=>parseEvent({...event,comment:{...event.comment,body:'/cd-merge 336 '+SHA}},env));
assert.throws(()=>parseEvent(event,{...env,GITHUB_ACTOR:'attacker'}));
assert.throws(()=>parseEvent({...event,issue:{number:74}},env));
assert.throws(()=>parseEvent({...event,sender:{id:1,login:'Xynph'}},env));
const names=require('../ci/ci-jobs.cjs').OFFICIAL_JOBS;
function fixture(){return {pr:{number:336,state:'open',base:{ref:'main',sha:MAIN},head:{sha:SHA,repo:{full_name:'Xynph/cadrage-debordement'}},mergeable:true,mergeable_state:'clean',draft:true},expected:SHA,main:MAIN,runs:[{id:99,event:'pull_request',name:'Tests JavaScript',head_sha:SHA,status:'completed',conclusion:'success'}],jobs:names.map(name=>({name,status:'completed',conclusion:'success'})),files:['ci/a.cjs'],otherFiles:[],comments:[{id:12,user:{login:'Xynph'},body:'RÉSERVATION PR #336 : ci/a.cjs'}]};}
let a=assess(fixture());assert.equal(a.technicalPass,true);assert.equal(a.authorizedToMerge,false);assert.equal(a.ruleSet.attested,false);
let f=fixture();f.pr.mergeable_state='unstable';assert.equal(assess(f).technicalPass,false);
f=fixture();f.pr.head.sha='c'.repeat(40);assert.equal(assess(f).technicalPass,false);
f=fixture();f.jobs.pop();assert.equal(assess(f).technicalPass,false);
f=fixture();f.otherFiles=[{pr:337,path:'ci/a.cjs'}];assert.equal(assess(f).technicalPass,false);
f=fixture();f.comments=[];assert.equal(assess(f).technicalPass,false);
f=fixture();f.pr.base.sha='c'.repeat(40);assert.equal(assess(f).technicalPass,false);
console.log('pr-preflight: 12 assertions/scénarios PASS');


// Régression end-to-end de l'entrée issue_comment : main() doit transmettre
// l'objet événement à run() avant de lire le HEAD main.
{
 const vm=require('node:vm'),fs=require('node:fs');
 const source=fs.readFileSync(require.resolve('../ci/pr-preflight.cjs'),'utf8');
 const invoked=[],messages=[];
 const fakeFs={
  readFileSync:()=>JSON.stringify(event),
  appendFileSync:(_path,body)=>messages.push(body)
 };
 const fakeExec=(_binary,args)=>{
  const path=args.find(x=>String(x).startsWith('repos/Xynph/cadrage-debordement/'));
  invoked.push(path);
  if(path==='repos/Xynph/cadrage-debordement/issues/comments/42')
   return JSON.stringify({body:event.comment.body,user:{id:350229047},issue_url:'https://api.github.com/repos/Xynph/cadrage-debordement/issues/73'});
  if(path==='repos/Xynph/cadrage-debordement/git/ref/heads/main')
   throw Error('MOCK_AFTER_EVENT_VALIDATION');
  if(path==='repos/Xynph/cadrage-debordement/issues/73/comments')
   return JSON.stringify({id:99});
  throw Error('Unexpected GitHub request: '+path);
 };
 const moduleShim={exports:{}};
 function fakeRequire(id){
  if(id==='node:fs')return fakeFs;
  if(id==='node:child_process')return {execFileSync:fakeExec};
  if(id==='./ci-jobs.cjs')return require('../ci/ci-jobs.cjs');
  throw Error('Unexpected import: '+id);
 }
 fakeRequire.main=moduleShim; // démarre réellement main(), comme node ci/pr-preflight.cjs
 const processShim={env:{...env,GITHUB_EVENT_PATH:'mock-event.json',GITHUB_STEP_SUMMARY:'mock-summary.md'},exitCode:0};
 vm.runInNewContext(source,{module:moduleShim,require:fakeRequire,process:processShim,console},{filename:'ci/pr-preflight.cjs'});
 assert.ok(invoked.includes('repos/Xynph/cadrage-debordement/issues/comments/42'));
 assert.ok(invoked.includes('repos/Xynph/cadrage-debordement/git/ref/heads/main'),
  'run(cmd,event) doit atteindre la lecture de main après validation de event.comment');
 assert.ok(messages[0].includes('MOCK_AFTER_EVENT_VALIDATION'));
 assert.ok(!messages[0].includes("Cannot read properties of undefined"));
 assert.equal(processShim.exitCode,1,'Une erreur GitHub doit rester STOP');
}
console.log('pr-preflight: regression issue_comment -> run(cmd,event) PASS');
