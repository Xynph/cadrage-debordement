'use strict';
const assert=require('node:assert/strict');
const {rulesetAuthEnv,rulesetDetails,rulesetStatus}=require('../ci/chat-diagnose.cjs');
const base={
  id:26326518,enforcement:'active',conditions:{ref_name:{include:['refs/heads/main']}},
  rules:[
    {type:'pull_request'},{type:'deletion'},{type:'non_fast_forward'},
    {type:'required_status_checks',parameters:{
      strict_required_status_checks_policy:true,
      required_status_checks:[{context:'Validation CI',integration_id:15368}]
    }}
  ]
};
assert.throws(()=>rulesetAuthEnv({GH_TOKEN:'limited'}),/Jeton GitHub App ruleset absent/);
assert.throws(()=>rulesetAuthEnv({GH_TOKEN:'limited',CD_RULESET_TOKEN:''}),/Jeton GitHub App ruleset absent/);
const auth=rulesetAuthEnv({GH_TOKEN:'limited',CD_RULESET_TOKEN:'ephemeral',OTHER:'preserved'});
assert.equal(auth.GH_TOKEN,'ephemeral');
assert.equal(auth.OTHER,'preserved');
assert.equal(rulesetDetails(base).noBypass,false,'hidden property MUST fail');
assert.equal(rulesetStatus(base),false);
assert.equal(rulesetStatus({...base,bypass_actors:[{actor_type:'User',actor_id:1}]}),false);
assert.equal(rulesetStatus({...base,bypass_actors:[]}),true);
assert.equal(rulesetStatus({...base,bypass_actors:[],enforcement:'disabled'}),false);
console.log('chat diagnose auth: 7 assertions PASS');
