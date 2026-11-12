'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Réception immersive : accès réels au staff, jeunes, atelier et analyses Monde',{skip:!godot&&'SDK Godot requis'},()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-reception-ui-')),source=path.resolve(__dirname,'../native/godot'),base=source,project=path.join(dir,'native/godot'),engine=path.join(dir,'native/engine');
 assert.ok(fs.existsSync(path.join(base,'assets/clubs.json')),'Staging requis avec build-godot-prototype.py --stage-only');
 fs.mkdirSync(project,{recursive:true});
 for(const entry of fs.readdirSync(base,{withFileTypes:true})){
  const from=path.join(base,entry.name),to=path.join(project,entry.name);
  if(entry.isFile())fs.copyFileSync(from,to);
  else if(['ui','guide','audio'].includes(entry.name))fs.cpSync(from,to,{recursive:true});
  else if(entry.name!=='.godot')fs.symlinkSync(from,to,'junction');
 }
 fs.cpSync(path.resolve(source,'../engine'),engine,{recursive:true});
 fs.symlinkSync(path.resolve(source,'../../dist'),path.join(dir,'dist'),'junction');
 fs.copyFileSync(path.join(__dirname,'godot-immersive-reception.gd'),path.join(project,'reception-test.gd'));
 // The copied harness resolves its relative preload beside itself.
 fs.mkdirSync(path.join(project, 'helpers'), { recursive: true });
 fs.copyFileSync(path.join(__dirname, 'helpers/contextual_flow.gd'), path.join(project, 'helpers/contextual_flow.gd'));
 const env={...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:dir+'-profile',CD_RECEPTION_UI_ARTIFACTS:dir,XDG_DATA_HOME:path.join(dir,'xdg-data'),XDG_CONFIG_HOME:path.join(dir,'xdg-config'),XDG_CACHE_HOME:path.join(dir,'xdg-cache')};
 for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'])fs.mkdirSync(env[key],{recursive:true});
 const imported=spawnSync(godot,['--headless','--editor','--path',project,'--import'],{env,encoding:'utf8',timeout:90000});
 fs.writeFileSync(path.join(dir,'import.log'),(imported.stdout||'')+(imported.stderr||''));
 if(imported.error)throw imported.error;assert.equal(imported.status,0,'Import Godot du projet jetable');
 const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--log-file',path.join(dir,'runtime.log'),'--path',project,'--script',path.join(project,'reception-test.gd')],{env,encoding:'utf8',timeout:90000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);console.log(output.trim());console.log('Preuves réception : '+dir);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);
 const report=JSON.parse(fs.readFileSync(path.join(dir,'report.json'),'utf8'));assert.deepEqual(report.failures,[]);assert.ok(report.checks>=15);
});
