'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
const output=process.env.CD_SMALL_CONTRACT_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'small-window-contracts-'));
function run(shared){
 const destination=path.join(output,shared?'shared':'contracts');fs.mkdirSync(destination,{recursive:true});
 const graphics=process.env.CD_SMALL_CONTRACT_GRAPHICS==='1';
 const args=[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed']:['--headless']),'--audio-driver','Dummy','--max-fps','30','--path','native/godot','--script',path.resolve(__dirname,'small-window-contracts.gd')];
 const result=spawnSync('flock',['/tmp/rg27-godot-sdk.lock','timeout','90',godot,...args],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:600000,env:{...process.env,CD_SMALL_CONTRACT_OUTPUT:destination,CD_SMALL_CONTRACT_SHARED:shared?'1':'0',CD_SMALL_CONTRACT_ONLY_SHARED:shared?'1':'0',CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'small-contract-profile-'))}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(destination,'godot.log'),log);
 console.log('Preuves petits écrans : '+destination);
 if(result.error)throw result.error;
 assert.equal(result.status,0,log);
 assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
 const report=JSON.parse(fs.readFileSync(path.join(destination,'report.json'),'utf8'));
 assert.deepEqual(report.failures,[]);
 assert.equal(report.reports.length,shared?0:10);
 assert.equal(report.shared_reports.length,shared?27:0);
 if(graphics){assert.equal(report.display,'X11');assert.equal(fs.readdirSync(destination).filter(name=>name.endsWith('.png')).length,shared?27:10);}
}
test('Contract dialogs fit supported windows and essential controls remain reachable',{skip:!godot&&'SDK Godot requis'},()=>run(false));
test('Shared dialog fitting preserves confirmations, file pickers, preferences and resizing',{skip:(!godot&&'SDK Godot requis')||(process.env.CD_SMALL_CONTRACT_SHARED==='0'&&'contrats seuls demandés')},()=>run(true));
