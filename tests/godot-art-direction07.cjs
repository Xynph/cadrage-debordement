'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Frozen real scene, real worker and disposable Windows profile. No mock model.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-art-direction07 : SDK Godot absent.');process.exit(0);}
const base=process.env.CD_ART07_TEMP||os.tmpdir();fs.mkdirSync(base,{recursive:true});
const dir=fs.mkdtempSync(path.join(base,'cd-art07-')),source=path.resolve(__dirname,'../native/godot'),project=path.join(dir,'godot');fs.mkdirSync(project,{recursive:true});
for(const name of fs.readdirSync(source)){const p=path.join(source,name);if(fs.statSync(p).isFile())fs.copyFileSync(p,path.join(project,name));}
for(const name of ['ui','guide','audio'])fs.cpSync(path.join(source,name),path.join(project,name),{recursive:true});
fs.copyFileSync(path.join(__dirname,'godot-art-direction07.gd'),path.join(project,'art07-test.gd'));
// The copied harness resolves its relative preload beside itself.
fs.mkdirSync(path.join(project, 'helpers'), { recursive: true });
fs.copyFileSync(path.join(__dirname, 'helpers/contextual_flow.gd'), path.join(project, 'helpers/contextual_flow.gd'));
const manifest={};for(const base of ['','ui','guide','audio','helpers'])for(const name of fs.readdirSync(path.join(project,base))){const p=path.join(project,base,name);if(fs.statSync(p).isFile()&&/\.(gd|godot|tscn|json)$/.test(name))manifest[path.join(base,name)]=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}
fs.writeFileSync(path.join(dir,'source-manifest.json'),JSON.stringify(manifest,null,2));
for(const name of ['art','assets','fonts','branding','shaders','.godot'])fs.symlinkSync(path.join(source,name),path.join(project,name),'junction');
fs.symlinkSync(path.resolve(source,'../engine'),path.join(dir,'engine'),'junction');
fs.writeFileSync(path.join(dir,'career.json'),JSON.stringify(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/france-long-career-s6.json.gz')))).checkpoint.save));
for(const name of ['Roaming','Local'])fs.mkdirSync(path.join(dir,'AppData',name),{recursive:true});fs.mkdirSync(path.join(dir,'tmp'),{recursive:true});
const result=spawnSync(godot,[...(process.env.CD_ART07_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--log-file',path.join(dir,'runtime.log'),'--path',project,'--script',path.join(project,'art07-test.gd')],{env:{...process.env,APPDATA:path.join(dir,'AppData/Roaming'),LOCALAPPDATA:path.join(dir,'AppData/Local'),TEMP:path.join(dir,'tmp'),TMP:path.join(dir,'tmp'),CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'PrototypeGodot'),CD_ART07_ARTIFACTS:dir},windowsHide:true,encoding:'utf8',timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);console.log(output);console.log('Preuves direction menus : '+dir);if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
for(const [file,hash] of Object.entries(manifest))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(project,file))).digest('hex'),hash,'Copie figée inchangée : '+file);
