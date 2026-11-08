'use strict';
const fs=require('node:fs'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
test('Gabi contextuel : premières visites, événements factuels et profil séparé', {skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const content=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../native/godot/guide/dialogues.json'),'utf8'));
 const clips=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../native/godot/guide/assets/voice/manifest.json'),'utf8')).clips;
 const fragments=content.pages.flatMap(p=>p.fragments);
 for(const fragment of fragments){
  assert.ok(fragment.text.length<=181);
  const exact=clips.some(c=>c.id===fragment.id&&c.text===fragment.text);
  assert.equal(fragment.audioStatus==='pending',!exact,'Une réécriture exige un nouvel audio : '+fragment.id);
 }
	const base=process.env.CD_GUIDE_TEST_ROOT||require('node:os').tmpdir();
 fs.mkdirSync(base,{recursive:true});const directory=fs.mkdtempSync(path.join(base,'cd-guide-context-'));
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-guide-context.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot')},encoding:'utf8',windowsHide:true,timeout:150000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output.trim());console.log('Preuves contexte : '+directory);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
