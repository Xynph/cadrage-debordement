'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process'),{test}=require('node:test'),assert=require('node:assert/strict');
for(const scenario of process.env.CD_GUIDE_LAYOUT_CASE?[process.env.CD_GUIDE_LAYOUT_CASE]:['layout','dock'])
for(const mode of process.env.CD_GUIDE_LAYOUT_MODE?[process.env.CD_GUIDE_LAYOUT_MODE]:['stretch','native'])test('Gabi compact : '+scenario+' / '+mode,{skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis'},()=>{
 const directory=fs.mkdtempSync(path.join(process.env.CD_GUIDE_TEST_ROOT||os.tmpdir(),'cd-guide-layout-'+mode+'-'));
 const source=path.resolve(__dirname,'../native/godot'),project=path.join(directory,'project');fs.mkdirSync(project);
 for(const entry of fs.readdirSync(source,{withFileTypes:true})){
  if(entry.name==='project.godot')continue;
  if(entry.isDirectory()){
   if(['guide','ui'].includes(entry.name)){
    const target=path.join(project,entry.name);fs.mkdirSync(target);
    for(const child of fs.readdirSync(path.join(source,entry.name),{withFileTypes:true})){
     const from=path.join(source,entry.name,child.name),to=path.join(target,child.name);
     if(child.isDirectory()&&child.name==='assets')fs.symlinkSync(from,to,'junction');else fs.cpSync(from,to,{recursive:true});
    }
   }else fs.symlinkSync(path.join(source,entry.name),path.join(project,entry.name),'junction');
  }
  else fs.copyFileSync(path.join(source,entry.name),path.join(project,entry.name));
 }
 fs.symlinkSync(path.resolve(source,'../engine'),path.join(directory,'engine'),'junction');
 const config=fs.readFileSync(path.join(source,'project.godot'),'utf8');
 fs.writeFileSync(path.join(project,'project.godot'),config.replace(/window\/stretch\/mode="[^"]*"/,'window/stretch/mode="'+(mode==='native'?'disabled':'canvas_items')+'"'));
 const harness=path.join(directory,'harness.gd');fs.copyFileSync(path.resolve(__dirname,'godot-guide-layout.gd'),harness);
 // The copied harness resolves its relative preload beside itself.
 fs.mkdirSync(path.join(directory, 'helpers'), { recursive: true });
 fs.copyFileSync(path.join(__dirname, 'helpers/contextual_flow.gd'), path.join(directory, 'helpers/contextual_flow.gd'));
 const crypto=require('node:crypto'),snapshot={};
 for(const relative of ['main.gd','guide/coach_guide.gd','guide/dialogues.json','guide/guide_speech.gd','project.godot'])snapshot[relative]=crypto.createHash('sha256').update(fs.readFileSync(path.join(project,relative))).digest('hex');
 snapshot['harness.gd']=crypto.createHash('sha256').update(fs.readFileSync(harness)).digest('hex');snapshot['helpers/contextual_flow.gd']=crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,'helpers/contextual_flow.gd'))).digest('hex');fs.writeFileSync(path.join(directory,'source-manifest.json'),JSON.stringify(snapshot,null,2));
 const r=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_GUIDE_GRAPHICS==='1'?[]:['--headless']),'--log-file',path.join(directory,'godot-engine.log'),'--audio-driver','Dummy','--max-fps','60','--path',project,'--script',harness],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'PrototypeGodot'),CD_GUIDE_CAPTURES:directory,CD_GUIDE_LAYOUT_MODE:mode,CD_GUIDE_LAYOUT_CASE:scenario},encoding:'utf8',windowsHide:true,timeout:150000});
 const output=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output.trim());console.log('Preuves layout : '+directory);
 if(r.error)throw r.error;assert.equal(r.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
