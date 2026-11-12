'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {validate,completedSeven,latestRun,rulesetStatus,rulesetDetails,format}=require('../ci/chat-diagnose.cjs');
const sha='a'.repeat(40);
const env={GITHUB_EVENT_NAME:'issue_comment',GITHUB_REPOSITORY:'Xynph/cadrage-debordement',GITHUB_ACTOR:'Xynph',GITHUB_TRIGGERING_ACTOR:'Xynph'};
const event={action:'created',repository:{id:1439603196,full_name:'Xynph/cadrage-debordement'},issue:{number:73},sender:{id:350229047,login:'Xynph'},comment:{id:123,user:{id:350229047,login:'Xynph',type:'User'},body:'/cd-diagnose 328 '+sha}};
test('commande strictement autorisée sans texte additionnel',()=>{
 assert.equal(validate(event,env).expected,sha);
 assert.throws(()=>validate({...event,comment:{...event.comment,body:event.comment.body+'\n/cd-merge 328 '+sha}},env));
 assert.throws(()=>validate({...event,comment:{...event.comment,user:{id:55,login:'intrus',type:'User'}}},env));
 assert.throws(()=>validate(event,{...env,GITHUB_TRIGGERING_ACTOR:'intrus'}));
});
test('jobs officiels SUCCESS exacts, skipped ou duplicata bloquants ; Godot informatif ignoré',()=>{
 const jobs=require('../ci/ci-jobs.cjs').OFFICIAL_JOBS.map(name=>({name,status:'completed',conclusion:'success'}));
 assert.equal(completedSeven(jobs),true);
 assert.equal(jobs.length,12);
 assert.equal(completedSeven([...jobs,{...jobs[0]}]),false);
 assert.equal(completedSeven([...jobs,{name:'Godot 1/3',status:'completed',conclusion:'failure'}]),true);
 assert.equal(completedSeven(jobs.slice(1)),false);
 assert.equal(completedSeven([...jobs,{name:'Suites 11/10',status:'completed',conclusion:'success'}]),false);
 assert.equal(completedSeven(jobs.map((j,i)=>i===2?{...j,conclusion:'skipped'}:j)),false);
});
test('CI main respecte SHA et événement exacts',()=>{
 const base={workflow_id:1,head_sha:sha,head_branch:'main',event:'workflow_dispatch',id:25};
 assert.equal(latestRun([base],sha,1,['push','workflow_dispatch']).id,25);
 assert.equal(latestRun([base],sha,1,['push']),undefined);
 assert.equal(latestRun([{...base,head_sha:'b'.repeat(40)}],sha,1,['workflow_dispatch']),undefined);
});
test('ruleset non contournable vérifié, pas seulement son identifiant',()=>{
 const r={id:26326518,enforcement:'active',bypass_actors:[],conditions:{ref_name:{include:['~DEFAULT_BRANCH']}},rules:[
  {type:'pull_request'},{type:'deletion'},{type:'non_fast_forward'},
  {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,required_status_checks:[{context:'Validation CI',integration_id:15368}]}}
 ]};
 assert.equal(rulesetStatus(r),true);
 assert.equal(rulesetStatus({...r,bypass_actors:[{actor_id:1}]}),false);
 assert.equal(rulesetStatus({...r,enforcement:'disabled'}),false);
});
test('aucun faux verdict vert sur échec API',()=>{
 assert.match(format(null,new Error('403'), 'https://github.com/example'),/STOP/);
 assert.match(format({valid:false,pr:328,head:sha,main:sha,mergeable:true,mergeable_state:'unstable',ready:true,ruleset:true,mainCI:true,prCI:true,missing:[]},null,'https://github.com/example'),/DIAGNOSTIC STOP/);
});
test('pagination CI bornée au SHA exact pour main et PR',()=>{
 const src=require('node:fs').readFileSync(require('node:path').join(__dirname,'../ci/chat-diagnose.cjs'),'utf8');
 assert.ok(src.includes("runs?branch=main&head_sha='+main"));
 assert.ok(src.includes("runs?event=pull_request&head_sha='+cmd.expected"));
 assert.ok(!src.includes("runs?event=pull_request','workflow_runs'"));
});

test('détail des refus ruleset conserve chaque exigence bloquante',()=>{
 const base={id:26326518,enforcement:'active',bypass_actors:[],conditions:{ref_name:{include:['refs/heads/main']}},rules:[
  {type:'pull_request'},{type:'deletion'},{type:'non_fast_forward'},
  {type:'required_status_checks',parameters:{strict_required_status_checks_policy:true,required_status_checks:[{context:'Validation CI',integration_id:15368}]}}
 ]};
 assert.ok(Object.values(rulesetDetails(base)).every(Boolean));
 const missing={...base,bypass_actors:undefined};
 assert.equal(rulesetDetails(missing).noBypass,false);
 assert.equal(rulesetStatus(missing),false);
 const noStrict={...base,rules:base.rules.map(r=>r.type==='required_status_checks'?{...r,parameters:{...r.parameters,strict_required_status_checks_policy:false}}:r)};
 assert.equal(rulesetDetails(noStrict).strictChecks,false);
 assert.equal(rulesetStatus(noStrict),false);
});
