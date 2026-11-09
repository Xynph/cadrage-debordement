'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Carrières staff et vivier : interactions réelles dans Godot',{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-lifecycle-ui-'));
 const legacy=require('./native-reference-harness.cjs').context();
 legacy.run('var v2Setup=aiRosterSetup;aiRosterSetup=function(){var result=v2Setup();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result};CDCommonCareer.start(1)');
 const legacyFile=path.join(directory,'legacy.json');fs.writeFileSync(legacyFile,legacy.run('JSON.stringify(createSaveDocument())'));
 const graphics=process.env.CD_LIFECYCLE_GRAPHICS==='1';
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--audio-driver','Dummy']:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-lifecycle.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_LIFECYCLE_CAPTURES:directory,CD_LIFECYCLE_LEGACY:legacyFile},encoding:'utf8',windowsHide:true,timeout:180000});
 const text=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),text);console.log(text.trim());console.log('Preuves lifecycle : '+directory);if(r.error)throw r.error;assert.equal(r.status,0,text);assert.doesNotMatch(text,/SCRIPT ERROR|Parse Error|ERROR:/);
});
