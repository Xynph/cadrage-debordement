'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP godot-decision-feedback : SDK Godot absent ; aucune réception native exécutée.');process.exit(0);}
assert.ok(fs.existsSync(path.join(__dirname,'../native/godot/ui/decision_feedback.gd')),'Contrôleur des vrais effets de décision à implémenter');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-decision-feedback-')),bridge=createBridge({dataDir:path.join(root,'profile'),seed:827381,now:1700000000000});
let id=0,model=null;const cases=[];
function act(command,payload={},expected=true,receipt=true){const before=model;const reply=bridge.handle({id:++id,command,payload});assert.equal(reply.ok,expected,reply.error);model=reply.model;cases.push({command,payload,before,after:model,ok:reply.ok,error:reply.error,receipt:expected&&receipt});return model;}
const baseline=(command,payload={})=>{const reply=bridge.handle({id:++id,command,payload});assert.equal(reply.ok,true,command+': '+reply.error);return model=reply.model;};
try{
 act('new_career',{club:0,mode:'common'});model=settleClubMeetings(model,baseline);
 const context=model.clubLife.clubSupport.context;
 act('staff_meeting',{context,plan:model.clubLife.clubSupport.meeting.options[0].key});
 const signedPlayer=model.squad.find(p=>p.renewal.available);assert.ok(signedPlayer);
 act('extend_contract',{playerId:signedPlayer.id,salary:1000,years:signedPlayer.renewal.minYears,confirmed:true});
 assert.equal(model.meta.negotiation.status,'counter','Vraie contre-offre du worker');
 act('extend_contract',{playerId:signedPlayer.id,salary:model.meta.negotiation.salary,years:model.meta.negotiation.years,confirmed:true});
 assert.equal(model.meta.negotiation.status,'signed','Vraie signature du worker');
 act('train',{mode:'normal'});act('train',{mode:'normal'},true,false);
 act('set_tactics',{attack:model.tactics.attack,defense:model.tactics.defense},true,false);
 act('snapshot',{},true,false);act('export',{},true,false);act('invalid_command',{},false);act('import',{text:'invalid'},false);
 // Une erreur disque réelle est annulée transactionnellement par le worker.
 const profileFile=path.join(root,'profile','PrototypeGodot','donnees.json');
 refuseSavePublication(profileFile,()=>act('set_tactics',{attack:model.tactics.attacks.find(o=>o.id!==model.tactics.attack).id,defense:model.tactics.defense},false));
 act('new_career',{club:0,mode:'common'});
 // This real conference is a receipt case: publish it before other decisions.
 const press=model.clubLife.press;act('press_conference',{context:press.context,answers:press.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});
 model=settleClubMeetings(model,baseline);
 for(let i=0;i<12;i++)act('set_tactics',{attack:model.tactics.attacks[(i+1)%model.tactics.attacks.length].id,defense:model.tactics.defense});
 const ctx=model.clubLife.clubSupport.context;
 const briefing=model.clubLife.clubSupport.briefing;
 act('strategic_briefing',{context:ctx,fixture:briefing.fixture,plan:'pack'});
 act('strategic_briefing',{context:ctx,fixture:briefing.fixture,plan:'pack'},true,false);
 const loadPlayer=model.squad.find(p=>p.loadPlan!=='repos');assert.ok(loadPlayer);act('set_player_load',{playerId:loadPlayer.id,mode:'repos'});
 const young=model.decisions.development.academy.find(p=>p.development.available&&p.development.options.length>1);assert.ok(young);act('set_development_focus',{playerId:young.id,focus:young.development.options.find(o=>o.id!==young.development.focus).id});
 if(model.decisions.training.collective.available)act('set_collective_focus',{focus:model.decisions.training.collective.options.find(o=>o.id!==model.decisions.training.collective.selected).id});
 const strategyCtx=model.clubLife.clubStrategy.context;
 act('club_academy_investment',{context:strategyCtx,amount:4000,confirmed:true});
 const facility=model.clubLife.clubStrategy.finance.facility;if(facility.affordable)act('club_facility_upgrade',{context:strategyCtx,level:facility.level,cost:facility.cost,confirmed:true});
 act('club_sponsor_sign',{context:strategyCtx,key:model.clubLife.clubStrategy.sponsors.find(s=>s.available).id,confirmed:true});
 const relContext=model.clubLife.relationships.context;
 if(!model.clubLife.relationships.active)act('relationship_activate',{context:relContext});
 const speaker=model.clubLife.relationships.players.find(p=>p.conversationAvailable);assert.ok(speaker);act('relationship_conversation',{context:relContext,playerId:speaker.id,choice:'rassurer'});
 const event=model.clubLife.relationships.event;if(event&&event.available)act('locker_room_decision',{context:relContext,eventKey:event.key,choice:event.choices[0].id});
 const quote=model.clubLife.clubSupport.agents.players.flatMap(p=>p.quotes).find(q=>q.policy==='equilibre'&&q.affordable);assert.ok(quote);
 act('agent_negotiate',{context:ctx,id:quote.id,years:quote.years,policy:quote.policy});
 const talk=model.clubLife.clubSupport.agents.talks.find(t=>t.id===quote.id);assert.equal(talk.status,'ready');
 act('agent_confirm',{context:ctx,key:talk.key,wage:talk.acceptedSalary,years:talk.years,fee:talk.fee,confirmed:true});
 act('training_plan',{context:ctx,plan:'proteger'});
 act('import',{text:bridge.handle({id:++id,command:'export'}).model.meta.exportText});
 const fixture=path.join(root,'cases.json');fs.writeFileSync(fixture,JSON.stringify(cases));
 const disk=path.join(root,'profile','PrototypeGodot','donnees.json'),bytes=fs.readFileSync(disk),exportBefore=bridge.handle({id:++id,command:'export'}).model.meta.exportText;
 const project=path.join(root,'project');fs.cpSync(path.join(__dirname,'../native/godot'),project,{recursive:true,filter:p=>!p.split(path.sep).includes('.godot')});
 if(process.env.CD_FEEDBACK_GRAPHICS==='1'){
  const settings=path.join(project,'project.godot');fs.writeFileSync(settings,fs.readFileSync(settings,'utf8').replace('window/size/viewport_width=1440','window/size/viewport_width=1280').replace('window/size/viewport_height=900','window/size/viewport_height=720'));
 }
 // L'import éditeur de Godot 4.7.2 plante par intermittence sur les machines GitHub chargées (signal 11 dans
 // preload_reimporting_scene, run 43262510105) : un plantage du moteur (statut nul, signal) est rejoué une fois ;
 // une erreur d'import ordinaire (statut non nul, ERROR:/Parse Error) reste fatale ci-dessous.
 let imported;
 for(let attempt=0;attempt<2;attempt++){
  imported=spawnSync(godot,['--headless','--editor','--import','--path',project],{encoding:'utf8',windowsHide:true,timeout:90000});
  if(!(imported.status===null&&imported.signal&&!imported.error))break;
  console.log('Import Godot interrompu par le signal '+imported.signal+' : nouvel essai');
 }
 const importLog=(imported.stdout||'')+(imported.stderr||'');fs.writeFileSync(path.join(root,'import.log'),importLog);if(imported.error)throw imported.error;assert.equal(imported.status,0,importLog);assert.doesNotMatch(require('./helpers/godot-import-log.cjs').importLogErrors(importLog),/SCRIPT ERROR|Parse Error|ERROR:/);
 const run=spawnSync(godot,[...(process.env.CD_FEEDBACK_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-decision-feedback.gd')],{encoding:'utf8',windowsHide:true,timeout:120000,env:{...process.env,CD_FEEDBACK_CASES:fixture,CD_FEEDBACK_ARTIFACTS:root,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_FEEDBACK_WORKER:path.resolve(__dirname,'../native/engine/worker.cjs'),CD_GODOT_DATA_DIR:path.join(root,'main-profile')}});
 const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves décisions : '+root);if(run.error)throw run.error;
 assert.equal(run.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.equal(bridge.handle({id:++id,command:'export'}).model.meta.exportText,exportBefore,'Consultation sans modification S/RNG');assert.deepEqual(fs.readFileSync(disk),bytes,'Consultation sans écriture de carrière');
}finally{bridge.close();}
