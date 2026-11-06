'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {validate,completedSeven,latestRun,rulesetStatus,format}=require('../ci/chat-diagnose.cjs');
const sha='a'.repeat(40);
const env={GITHUB_EVENT_NAME:'issue_comment',GITHUB_REPOSITORY:'Xynph/cadrage-debordement',GITHUB_ACTOR:'Xynph',GITHUB_TRIGGERING_ACTOR:'Xynph'};
const event={action:'created',repository:{id:1439603196,full_name:'Xynph/cadrage-debordement'},issue:{number:73},sender:{id:350229047,login:'Xynph'},comment:{id:123,user:{id:350229047,login:'Xynph',type:'User'},body:'/cd-diagnose 328 '+sha}};
test('commande strictement autorisée sans texte additionnel',()=>{
 assert.equal(validate(event,env).expected,sha);
 assert.throws(()=>validate({...event,comment:{...event.comment,body:event.comment.body+'\n/cd-merge 328 '+sha}},env));
 assert.throws(()=>validate({...event,comment:{...event.comment,user:{id:55,login:'intrus',type:'User'}}},env));
 assert.throws(()=>validate(event,{...env,GITHUB_TRIGGERING_ACTOR:'intrus'}));
});
test('7 jobs SUCCESS exacts, skipped ou duplicata bloquants',()=>{
 const jobs=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'].map(name=>({name,status:'completed',conclusion:'success'}));
 assert.equal(completedSeven(jobs),true);
 assert.equal(completedSeven([...jobs,{...jobs[0]}]),false);
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