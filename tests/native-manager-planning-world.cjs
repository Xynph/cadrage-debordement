'use strict';
process.env.CD_MODES_HERITES='0';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
test('mode Monde seul : trois intentions sans décision sportive ou financière',()=>{
 const b=createBridge({dataDir:fs.mkdtempSync(path.join(os.tmpdir(),'cd-planning-world-')),seed:27,now:1794178800000});let id=0;
 const go=(command,payload={})=>{const r=b.handle({id:++id,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 try{
  assert.equal(b.handle({id:++id,command:'new_career',payload:{mode:'common',club:0}}).ok,false,'le test conserve le verrou Monde de production');
  let m=settleClubMeetings(go('new_career',{mode:'world-champ',club:0}),go);
  assert.ok(m.managerPlanning.available);assert.ok(m.managerPlanning.fixtures.length>0);
  const context=m.managerPlanning.context,fixtureId=m.managerPlanning.fixtures[0].id;
  const player=m.managerPlanning.players.find(p=>p.eligible.includes(0));assert.ok(player);
  const before=JSON.parse(go('export').meta.exportText).state;
  m=go('manager_plan_lineup',{context,fixtureId,slot:0,playerId:player.id});
  assert.equal(m.managerPlanning.fixtures[0].slots[0],player.id);
  m=go('manager_plan_scenario',{context,operations:[{kind:'renew',playerId:player.id,years:2,salary:3000,fee:0}]});
  assert.equal(m.managerPlanning.scenario.operations[0].available,true);
  m=go('manager_plan_goal',{context,metric:'lineouts',target:80});
  assert.equal(m.managerPlanning.goal.metric,'lineouts');
  const after=JSON.parse(go('export').meta.exportText).state;
  delete before.managerPlanning;delete after.managerPlanning;
  assert.deepEqual(after,before,'une intention ne change ni sélection réelle, ni économie, ni progression');
 }finally{b.close();}
});
