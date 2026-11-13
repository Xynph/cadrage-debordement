'use strict';
process.env.CD_MODES_HERITES='0'; // Exercise the production World-only mode.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
test('Bureau : réexamen daté et ouverture du bon suivi sans mutation',{
 skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis',
},()=>{
 const output=fs.mkdtempSync(path.join(os.tmpdir(),'cd-office-youth-review-'));
 const captures=process.env.CD_OFFICE_REVIEW_CAPTURE_DIR;
 if(captures)fs.mkdirSync(captures,{recursive:true});
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[
  ...(captures?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed']:['--headless']),
  '--audio-driver','Dummy','--max-fps','120','--path','native/godot',
  '--log-file',path.join(output,'engine.log'),
  '--script',path.resolve(__dirname,'office-youth-review-reminders.gd'),
 ],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:180000,
  env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',
   CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(output,'profile')}});
 const log=(result.stdout||'')+(result.stderr||'');
 fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());
 console.log('Preuves : '+output);
 if(result.error)throw result.error;
 assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
