'use strict';
process.env.CD_MODES_HERITES='1'; // Legacy fixtures; production keeps World-only mode.
const {test}=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs'),os=require('node:os'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('atelier manager : trois parcours Godot réels et intentions seules',{skip:!godot&&'SDK Godot requis'},()=>{
 let model=process.env.CD_MANAGER_PLANNING_MODEL;
 if(!model){
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'oval-planner-fixture-')),b=require('../native/engine/worker.cjs').createBridge({dataDir:dir,seed:27,now:1700000000000,dailyCalendar:true});
  try{const r=b.handle({id:1,command:'new_career',payload:{mode:'common',club:29}});assert.equal(r.ok,true,r.error);model=path.join(dir,'model.json');fs.writeFileSync(model,JSON.stringify(r.model));}finally{b.close();}
 }
 const r=spawnSync(godot,['--headless','--path',path.resolve(__dirname,'../native/godot'),'--script',path.join(__dirname,'godot-manager-planning.gd')],{encoding:'utf8',timeout:30000,env:{...process.env,CD_MANAGER_PLANNING_MODEL:model}});
 const log=(r.stdout||'')+(r.stderr||'');console.log(log);assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:|Assertion failed/);
});
