'use strict';
// Four real weekly commands/matches; no injected career state or projected model.
const assert=require('node:assert/strict');
const {createBridge}=require('../native/engine/worker.cjs');
function prepare(dataDir){
 const bridge=createBridge({dataDir,seed:41,now:1700000000000});let id=0;
 const request=(command,payload={})=>bridge.handle({id:++id,command,payload});
 const call=(command,payload={})=>{const r=request(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 try{
  let model=call('new_career',{mode:'common',club:0});
  model=call('academy_activate',{...model.clubLife.academyPathways.context,confirmed:true});
  model=call('youth_development_enable',{context:model.clubLife.youthDevelopment.context,confirmed:true});
  const player=model.clubLife.youthDevelopment.players.filter(p=>p.stage==='academy'&&p.age>=18).sort((a,b)=>a.rating-b.rating)[0];assert.ok(player);
  model=call('promote_academy',{playerId:player.id,confirmed:true});
  model=call('youth_development_plan',{context:model.clubLife.youthDevelopment.context,playerId:player.id,plan:'integration',focus:player.defaultFocus,confirmed:true});
  for(let week=0;week<4;week++){
   model=call('train',{mode:'repos'});
   if(model.next){if(!model.selection.valid)model=call('auto_lineup');model=call('begin_match');model=call('delegate');}
   model=call('finish_round');
  }
  const tracked=model.clubLife.youthDevelopment.players.find(p=>p.id===player.id);
  assert.equal(tracked.review.recent.available,true);assert.equal(tracked.review.recent.weeks,4);assert.equal(tracked.review.recommendation.key,'loan');
  return {bridge,call,request,model,player:tracked};
 }catch(error){bridge.close();throw error;}
}
module.exports={prepare};
