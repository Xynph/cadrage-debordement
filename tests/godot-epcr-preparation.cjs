'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Préparation EPCR : vrai worker, choix clavier, refus, redimensionnement et carrière intacte',{skip:!godot&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-epcr-ui-')),source=path.resolve(__dirname,'../native/godot'),project=path.join(dir,'godot');
 assert.ok(fs.existsSync(path.join(source,'assets/clubs.json')),'Staging requis : python3 scripts/build-godot-prototype.py --stage-only --node /chemin/node');
 fs.mkdirSync(project);
 for(const entry of fs.readdirSync(source,{withFileTypes:true})){
  const from=path.join(source,entry.name),to=path.join(project,entry.name);
  if(entry.isFile())fs.copyFileSync(from,to);
  else if(['ui','guide','audio'].includes(entry.name))fs.cpSync(from,to,{recursive:true});
  else fs.symlinkSync(from,to,'junction');
 }
 fs.symlinkSync(path.resolve(source,'../engine'),path.join(dir,'engine'),'junction');
 fs.copyFileSync(path.join(__dirname,'godot-epcr-preparation.gd'),path.join(project,'epcr-preparation-test.gd'));
 const env={...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(dir,'profile'),CD_EPCR_UI_ARTIFACTS:dir};
 // A source checkout may have no imported assets yet. Import only the disposable project.
 if(!fs.existsSync(path.join(project,'.godot'))){
  const imported=spawnSync(godot,['--headless','--editor','--path',project,'--import'],{env,encoding:'utf8',timeout:90000});
  fs.writeFileSync(path.join(dir,'import.log'),(imported.stdout||'')+(imported.stderr||''));
  if(imported.error)throw imported.error;assert.equal(imported.status,0,'Import Godot du projet jetable');
 }
 const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--log-file',path.join(dir,'runtime.log'),'--path',project,'--script',path.join(project,'epcr-preparation-test.gd')],{env,encoding:'utf8',timeout:90000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);
 console.log(output.trim());console.log('Preuves préparation EPCR : '+dir);
 if(result.error)throw result.error;
 assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
 const report=JSON.parse(fs.readFileSync(path.join(dir,'report.json'),'utf8'));assert.deepEqual(report.failures,[]);assert.ok(report.checks>=30);
});
