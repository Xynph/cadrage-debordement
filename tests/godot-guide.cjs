'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test');
const assert=require('node:assert/strict');
for(const mode of process.env.CD_GUIDE_CASE?[process.env.CD_GUIDE_CASE]:['general','write-error'])test('Coach natif : '+mode+' (profil, interactions et invariance)', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const root=fs.mkdtempSync(path.join(process.env.CD_GUIDE_TEST_ROOT||os.tmpdir(),'cd-guide-'));
 const project=path.resolve(__dirname,'../native/godot');
 assert.ok(fs.existsSync(path.join(project,'assets/clubs.json')),'Exécuter le staging natif avant la recette coach.');
 // A private project enables native TTS at startup without changing the shared project.
 const privateProject=path.join(root,'project');fs.mkdirSync(privateProject);
 for(const entry of fs.readdirSync(project,{withFileTypes:true})){
  if(entry.name==='project.godot')continue;
  if(entry.isDirectory())fs.symlinkSync(path.join(project,entry.name),path.join(privateProject,entry.name),'junction');
  else fs.copyFileSync(path.join(project,entry.name),path.join(privateProject,entry.name));
 }
 fs.symlinkSync(path.resolve(project,'../engine'),path.join(root,'engine'),'junction');
 const config=fs.readFileSync(path.join(project,'project.godot'),'utf8').split(/\r?\n/);
 const audio=config.findIndex(line=>line.trim()==='[audio]');
 if(audio<0)config.push('','[audio]','general/text_to_speech=true');
 else{
  let end=config.findIndex((line,index)=>index>audio&&/^\[/.test(line));if(end<0)end=config.length;
  const setting=config.findIndex((line,index)=>index>audio&&index<end&&/^\s*general\/text_to_speech\s*=/.test(line));
  if(setting<0)config.splice(audio+1,0,'general/text_to_speech=true');else config[setting]='general/text_to_speech=true';
 }
 fs.writeFileSync(path.join(privateProject,'project.godot'),config.join('\n'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_GUIDE_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',privateProject,'--script',path.resolve(__dirname,'godot-guide.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GUIDE_CASE:mode,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(root,'profile'),CD_GUIDE_CAPTURES:root},encoding:'utf8',windowsHide:true,timeout:120000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),output);console.log(output.trim());console.log('Preuves coach : '+root);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
