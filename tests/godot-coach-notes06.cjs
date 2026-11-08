'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const view=path.resolve(__dirname,'../native/godot/ui/coach_notes_view.gd');assert.ok(fs.existsSync(view),'Popup du carnet encore absente');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;assert.ok(godot,'Godot requis');
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-coach-notes06-ui-'));
const {createBridge}=require('../native/engine/worker.cjs'),b=createBridge({dataDir:root,seed:506,now:1700000000000});let model;
try{let r=b.handle({id:1,command:'new_career',payload:{mode:'fiction',club:0}});assert.equal(r.ok,true,r.error);r=b.handle({id:2,command:'coach_note_save',payload:{context:r.model.clubLife.coachNotebook.context,target:'career',text:'Projet de formation 😀\nSans promesse de résultat.'}});assert.equal(r.ok,true,r.error);model=r.model;}finally{b.close();}
model.clubLife.coachNotebook.entries.push({target:'missing:old-player',id:null,name:null,pos:null,available:false,text:'Ancien dossier — garder la note.',season:1,week:0,club:0});
fs.writeFileSync(path.join(root,'model.json'),JSON.stringify(model));
const r=spawnSync(godot,['--headless','--log-file',path.join(root,'engine.log'),'--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-coach-notes06.gd')],{encoding:'utf8',windowsHide:true,timeout:60000,env:{...process.env,CD_COACH_NOTES06_ROOT:root}});
const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves carnet headless : '+root);if(r.error)throw r.error;assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
