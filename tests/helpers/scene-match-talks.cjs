'use strict';
const assert=require('node:assert/strict');

// Tests exercising the live engine explicitly pass the optional team talk,
// using its real projected key/phase rather than bypassing production guards.
function skipMatchTalk(model,send){
 const scene=model.clubLife?.matchTalks?.scene;
 if(!scene)return model;
 assert.equal(scene.options.length,6,'A real contextual team talk offers six declarations');
 return send('match_talk_continue',{key:scene.key,phase:scene.phase,skip:true});
}

module.exports={skipMatchTalk};
