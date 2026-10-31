'use strict';
const assert=require('node:assert/strict');const {verdict}=require('../ci/dual-merge-policy.cjs');
const repo='Xynph/cadrage-debordement';
function good(){return {repo,enabled:true,mainSha:'b'.repeat(40),mainProtection:{required_status_checks:{strict:true,contexts:['Validation CI']},enforce_admins:{enabled:true}},pr:{state:'open',draft:false,base:{ref:'main',sha:'b'.repeat(40)},mergeable:true,mergeable_state:'clean',head:{sha:'h'.repeat(40),repo:{full_name:repo}}},run:{event:'pull_request',head_sha:'h'.repeat(40),status:'completed',conclusion:'success',name:'Tests JavaScript'},validationJob:{name:'Validation CI',status:'completed',conclusion:'success'}}}
let count=0;function test(name,fn){fn();count++;console.log('PASS '+name)}
test('autorise quand protections et CI completes',()=>assert.equal(verdict(good()).allowed,true));
for(const [name,mutate] of [
['activation absente',x=>x.enabled=false],
['depot incorrect',x=>x.repo='autre/depot'],
['protection manquante',x=>x.mainProtection=null],
['checks non stricts',x=>x.mainProtection.required_status_checks.strict=false],
['validation non requise',x=>x.mainProtection.required_status_checks.contexts=['Tests JavaScript']],
['administrateur sans protections',x=>x.mainProtection.enforce_admins.enabled=false],
['PR brouillon',x=>x.pr.draft=true],
['base incorrecte',x=>x.pr.base.ref='develop'],
['SHA main modifie',x=>x.mainSha='c'.repeat(40)],
['SHA CI stale',x=>x.run.head_sha='z'.repeat(40)],
['CI echouee',x=>x.run.conclusion='failure'],
['validation echouee',x=>x.validationJob.conclusion='failure'],
['non fusionnable',x=>x.pr.mergeable_state='dirty'],
['repo source externe',x=>x.pr.head.repo.full_name='outsider/fork']]){
 test(name,()=>{const x=good();mutate(x);assert.equal(verdict(x).allowed,false)})
}
console.log('COORDINATION DUAL MERGE PASS '+count);
