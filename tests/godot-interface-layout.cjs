'use strict';
// Real scene and worker, physically frozen scripts, disposable profile on E when configured.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-interface-layout : SDK Godot absent.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(process.env.CD_LAYOUT_TEMP||os.tmpdir(),'cd-layout-'));
const source=path.resolve(__dirname,'../native/godot'),project=path.join(dir,'godot');fs.mkdirSync(project,{recursive:true});
for(const name of fs.readdirSync(source)){const p=path.join(source,name);if(fs.statSync(p).isFile())fs.copyFileSync(p,path.join(project,name));}
for(const name of ['ui','guide'])fs.cpSync(path.join(source,name),path.join(project,name),{recursive:true});
fs.copyFileSync(path.join(__dirname,'godot-interface-layout.gd'),path.join(project,'interface-layout-test.gd'));
const manifest={};for(const base of ['','ui','guide'])for(const name of fs.readdirSync(path.join(project,base))){const p=path.join(project,base,name);if(fs.statSync(p).isFile()&&/\.(gd|godot|tscn|json)$/.test(name))manifest[path.join(base,name)]=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}fs.writeFileSync(path.join(dir,'source-manifest.json'),JSON.stringify(manifest,null,2));
for(const name of ['assets','fonts','branding','shaders','.godot'])fs.symlinkSync(path.join(source,name),path.join(project,name),'junction');
fs.symlinkSync(path.resolve(source,'../engine'),path.join(dir,'engine'),'junction');
fs.writeFileSync(path.join(dir,'career.json'),JSON.stringify(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/france-long-career-s6.json.gz')))).checkpoint.save));
const {context}=require('./harness.cjs'),live=context();
live.run('start(0);beginMatch();while(S.live.minute<65&&!S.live.finished){S.live.paused=false;advanceRugby(S.live)};S.live.paused=true;syncMatchPresentation(S.live)');
fs.writeFileSync(path.join(dir,'live.json'),live.run('JSON.stringify(createSaveDocument())'));
for(const name of ['Roaming','Local'])fs.mkdirSync(path.join(dir,'AppData',name),{recursive:true});
fs.mkdirSync(path.join(dir,'tmp'),{recursive:true});
const voiceBefore=Object.fromEntries(fs.readdirSync(path.join(project,'guide/assets/voice')).filter(n=>n.endsWith('.wav')).map(n=>[n,crypto.createHash('sha256').update(fs.readFileSync(path.join(project,'guide/assets/voice',n))).digest('hex')]));
fs.writeFileSync(path.join(dir,'voice-manifest.json'),JSON.stringify(voiceBefore,null,2));
const result=spawnSync(godot,[...(process.env.CD_LAYOUT_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--log-file',path.join(dir,'runtime.log'),'--path',project,'--script',path.join(project,'interface-layout-test.gd')],{env:{...process.env,APPDATA:path.join(dir,'AppData/Roaming'),LOCALAPPDATA:path.join(dir,'AppData/Local'),TEMP:path.join(dir,'tmp'),TMP:path.join(dir,'tmp'),CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'PrototypeGodot'),CD_LAYOUT_ARTIFACTS:dir},windowsHide:true,encoding:'utf8',timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);console.log(output);console.log('Preuves interface : '+dir);if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
for(const [file,hash] of Object.entries(manifest))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(project,file))).digest('hex'),hash,'Copie figée inchangée : '+file);
for(const [file,hash] of Object.entries(voiceBefore))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(project,'guide/assets/voice',file))).digest('hex'),hash,'Audio inchangé : '+file);

