'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Soundscape natif : préférences atomiques, bus et déduplication sous Dummy explicite',{skip:!godot&&'SDK Godot requis'},()=>{
 const base=process.env.CD_SOUNDS_PROOF||os.tmpdir();fs.mkdirSync(base,{recursive:true});
 const proof=fs.mkdtempSync(path.join(base,'cd-soundscape06-é '));
 const source=require('./harness.cjs').context();source.run('start(0);beginMatch();while(S.live.minute<80&&!S.live.finished){S.live.paused=false;advanceRugby(S.live)}');
 const events=JSON.parse(source.run('JSON.stringify(S.live.events)'));
 assert.ok(events.some(e=>['try','goal','miss'].includes(e.scene?.kind)),'Vraie fixture avec réaction disponible');
 fs.writeFileSync(path.join(proof,'engine-events.json'),JSON.stringify(events));
 const {normalize}=require('../dist/match3d/scene-adapter.js');
 fs.writeFileSync(path.join(proof,'engine-keys.json'),JSON.stringify(events.map(e=>normalize({key:e,kind:e.scene?.kind,players:[],ball:e.scene?.to,origin:e.scene?.from}).key)));
 const readonly=path.join(proof,'readonly');fs.mkdirSync(readonly,{recursive:true});
 const target=path.join(readonly,'sound.json');fs.writeFileSync(target,JSON.stringify({version:1,interface_volume:35,stadium_volume:25}));
 fs.chmodSync(target,0o444);
 let run;
 try{run=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-soundscape06.gd')],{
  env:{...process.env,CD_SOUNDS_PROOF:proof,CD_NODE_EXECUTABLE:process.execPath,CD_SOUNDS_READONLY:process.platform==='win32'?'1':'0'},encoding:'utf8',windowsHide:true,timeout:60000});}
 finally{fs.chmodSync(target,0o666);}
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(proof,'godot.log'),output);console.log(output);console.log('Preuves Dummy : '+proof);
 if(run.error)throw run.error;assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
});
