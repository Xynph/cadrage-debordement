'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),{context}=require('./harness.cjs');
assert.ok(fs.existsSync(path.resolve(__dirname,'../native/godot/match_action_review.gd')),'Le lecteur événementiel doit exister');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-action-review : SDK Godot requis (CD_GODOT_EXE).');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-action-review-'));
const source=context();source.run('start(0);beginMatch();while(S.live.minute<55&&!S.live.finished){S.live.paused=false;advanceRugby(S.live)};S.live.paused=true;syncMatchPresentation(S.live)');
fs.writeFileSync(path.join(directory,'live.json'),source.run('JSON.stringify(createSaveDocument())'));
for(const name of ['data','cache','config'])fs.mkdirSync(path.join(directory,name),{recursive:true});
const result=spawnSync(godot,[...(process.env.CD_ACTION_REVIEW_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-action-review.gd')],{env:{...process.env,XDG_DATA_HOME:path.join(directory,'data'),XDG_CACHE_HOME:path.join(directory,'cache'),XDG_CONFIG_HOME:path.join(directory,'config'),CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_ACTION_REVIEW_ARTIFACTS:directory},encoding:'utf8',timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves relecture : '+directory);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
