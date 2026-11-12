'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');
function signed(doc){let h=2166136261;const text=JSON.stringify(doc.state);for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
test('vraie carrière : intentions seules, refus atomique, export/import et reprise',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'oval-planning-'));let b,n=0;
 const open=()=>createBridge({dataDir:root,seed:27,now:1700000000000,dailyCalendar:true});
 const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 const state=()=>JSON.parse(good('export').meta.exportText).state;
 try{
  b=open();let m=settleClubMeetings(good('new_career',{mode:'common',club:29}),good);
  assert.equal(m.managerPlanning.fixtures.length,3);const base=state();
  const context=m.managerPlanning.context,fixtureId=m.managerPlanning.fixtures[0].id;
  const player=m.managerPlanning.players.find(p=>p.eligible.includes(0));assert.ok(player);
  m=good('manager_plan_lineup',{context,fixtureId,slot:0,playerId:player.id});assert.equal(m.managerPlanning.fixtures[0].slots[0],player.id);
  const draft=state();delete draft.managerPlanning;assert.deepEqual(draft,base,'aucune décision sportive, financière ou croissance changée');
  const file=path.join(m.meta.dataDir,'donnees.json'),before=fs.readFileSync(file);
  assert.equal(b.handle({id:++n,command:'manager_plan_lineup',payload:{context,fixtureId:'absente',slot:0,playerId:player.id}}).ok,false);assert.deepEqual(fs.readFileSync(file),before);
  const candidate=m.market[0];assert.ok(candidate);m=good('manager_plan_scenario',{context,operations:[{kind:'recruit',playerId:candidate.id,years:2,salary:3000,fee:5000}]});
  assert.equal(m.managerPlanning.scenario.upFront,5000);assert.equal(m.squad.some(p=>p.id===candidate.id),false);
  m=good('manager_plan_goal',{context,metric:'lineouts',target:80});assert.equal(m.managerPlanning.goal.value,null);
  const saved=good('export').meta.exportText;good('shutdown');b.close();b=open();m=good('snapshot');assert.equal(m.managerPlanning.fixtures[0].slots[0],player.id);assert.equal(good('export').meta.exportText,saved);
  const hostile=JSON.parse(saved);hostile.state.managerPlanning.lineups[0].slots[1]=player.id;
  assert.equal(b.handle({id:++n,command:'import',payload:{text:signed(hostile)}}).ok,false);assert.equal(good('export').meta.exportText,saved);
  const unqualified=m.managerPlanning.players.find(p=>!p.eligible.includes(0));assert.ok(unqualified);
  const wrongPosition=JSON.parse(saved);wrongPosition.state.managerPlanning.lineups[0].slots[0]=unqualified.id;
  assert.equal(b.handle({id:++n,command:'import',payload:{text:signed(wrongPosition)}}).ok,false,'un import signé reste soumis aux qualifications');
  good('import',{text:saved});m=good('snapshot');assert.equal(m.managerPlanning.goal.metric,'lineouts');
  const output=process.env.CD_MANAGER_PLANNING_MODEL;if(output)fs.writeFileSync(output,JSON.stringify(m));
 }finally{b?.close();}
});
