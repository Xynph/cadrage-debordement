'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
test('Carnet du coach : vraie application Godot, notes et refus disque', {skip:!godot&&'SDK Godot absent : réception non exécutée'},()=>{
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-coach-notes06-app-'));
const r=spawnSync(godot,['--headless','--log-file',path.join(root,'engine.log'),'--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-coach-notes06-app.gd')],{encoding:'utf8',windowsHide:true,timeout:60000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(root,'PrototypeGodot'),APPDATA:path.join(root,'appdata'),LOCALAPPDATA:path.join(root,'localappdata')}});
const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves vraie app carnet headless : '+root);if(r.error)throw r.error;assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
