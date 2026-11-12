'use strict';
// Real UI + worker: browsing must leave the export, RNG and profile bytes intact.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),{context}=require('./harness.cjs');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-journal : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-journal-'));
const source=context();
source.run('start(0);beginMatch();while(S.live.minute<65&&!S.live.finished){S.live.paused=false;advanceRugby(S.live)};S.live.paused=true;syncMatchPresentation(S.live)');
fs.writeFileSync(path.join(directory,'live.json'),source.run('JSON.stringify(createSaveDocument())'));
for(const [name,club,minute] of [['short',0,25],['other',1,50]]){const c=context();c.run(`start(${club});beginMatch();while(S.live.minute<${minute}&&!S.live.finished){S.live.paused=false;advanceRugby(S.live)};S.live.paused=true;syncMatchPresentation(S.live)`);fs.writeFileSync(path.join(directory,name+'.json'),c.run('JSON.stringify(createSaveDocument())'));}
// Direct d'origine (CD_MATCH_TEMPS_FORTS=0) : ce test vérifie le journal au fil des pas du direct.
// En temps forts, le journal ouvert suit l'image montrée : voir tests/godot-match-temps-forts.
const result=spawnSync(godot,[...(process.env.CD_MATCH_JOURNAL_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-journal.gd')],{env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_MATCH_JOURNAL_ARTIFACTS:directory,CD_MATCH_TEMPS_FORTS:'0'},encoding:'utf8',windowsHide:true,timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves journal : '+directory);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
