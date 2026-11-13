'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const sdk=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!sdk||!fs.existsSync(sdk)){console.log('SKIP godot-decision-preview06 : SDK absent, aucune réception exécutée.');process.exit(0);}
assert.ok(fs.existsSync(path.join(__dirname,'../native/godot/ui/decision_preview.gd')),'Présentation des engagements avant confirmation absente');
const {createBridge}=require('../native/engine/worker.cjs');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'cd-decision-preview06-'));
let seq=0;const bridge=createBridge({dataDir:path.join(scratch,'profile'),seed:62511,now:1700000000000});
const call=(command,payload={})=>{const r=bridge.handle({id:++seq,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
try{
 const before=call('new_career',{mode:'common',club:0});const exact=call('export').meta.exportText;
 const strategy=before.clubLife.clubStrategy;
 const cases=[];
 for(const amount of [0,12000]) cases.push({command:'club_academy_investment',payload:{amount},model:before,amount:0,direction:'debit',recurring:amount});
 const project=strategy.board.projectOptions.find(x=>x.cost>0);
 cases.push({command:'club_board_project',payload:{kind:project.id},model:before,amount:project.cost,direction:'debit'});
 const sponsor=strategy.sponsors.find(x=>x.signing>0);
 cases.push({command:'club_sponsor_sign',payload:{key:sponsor.id},model:before,amount:sponsor.signing,direction:'credit',recurring:sponsor.weekly});
 for(const [command,key] of [['club_fans_campaign','campaigns'],['club_fans_community','community'],['club_fans_service','services']]){
  const option=strategy.fans[key].find(x=>x.cost>0);cases.push({command,payload:{key:option.id},model:before,amount:option.cost,direction:'debit'});
 }
 cases.push({command:'club_facility_upgrade',payload:{},model:{},empty:true});
 cases.push({command:'club_board_project',payload:{kind:'unknown'},model:before,empty:true});
 cases.push({command:'club_sponsor_sign',payload:{key:'unknown'},model:before,empty:true});
 cases.push({command:'club_fans_service',payload:{key:'unknown'},model:before,empty:true});
 cases.push({command:'train',payload:{},model:before,empty:true});
 assert.equal(call('export').meta.exportText,exact,'Préparer les devis ne modifie pas la carrière');
 fs.writeFileSync(path.join(scratch,'cases.json'),JSON.stringify(cases));
 const run=spawnSync(sdk,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-decision-preview06.gd')],{env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(scratch,'unused'),CD_DECISION_PREVIEW06:scratch,APPDATA:path.join(scratch,'Roaming'),LOCALAPPDATA:path.join(scratch,'Local')},encoding:'utf8',timeout:90000,windowsHide:true});
 const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(scratch,'runtime.log'),log);console.log(log);console.log('Preuves : '+scratch);
 if(run.error)throw run.error;assert.equal(run.status,0);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
}finally{bridge.close();}
