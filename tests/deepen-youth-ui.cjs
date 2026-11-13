'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
test('suivi daté, aperçu et premier contrat via les vraies routes Godot',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-deepen-youth-'));
 const fixture=require('./deepen-youth-fixture.cjs').prepare(path.join(dir,'fixture-profile'));
 const fixturePath=path.join(dir,'four-weeks.json');
 try{fs.writeFileSync(fixturePath,fixture.call('export').meta.exportText);}finally{fixture.bridge.close();}
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'deepen-youth-ui.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:150000,env:{...process.env,CD_DEEPEN_YOUTH_FIXTURE:fixturePath,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'profile'),XDG_DATA_HOME:path.join(dir,'data'),XDG_CONFIG_HOME:path.join(dir,'config'),XDG_CACHE_HOME:path.join(dir,'cache')}});
 const out=(r.stdout||'')+(r.stderr||'');console.log(out);fs.writeFileSync(path.join(dir,'godot.log'),out);console.log('Preuves : '+dir);if(r.error)throw r.error;assert.equal(r.status,0,out);assert.doesNotMatch(out,/SCRIPT ERROR|Parse Error|ERROR:/);
});
