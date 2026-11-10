'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Affichage salaires : trois unités, saisie sans dérive et préférence persistée',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=fs.mkdtempSync(path.join(os.tmpdir(),'oval-salary-format-'));
 const result=spawnSync(godot,['--headless','--path','native/godot','--script',path.resolve(__dirname,'godot-salary-display.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000,env:{...process.env,CD_SALARY_TEST_DIR:output,CD_NODE_EXECUTABLE:process.execPath}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves unités : '+output);if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
