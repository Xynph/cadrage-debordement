'use strict';
// Real scene and worker, physically frozen scripts, disposable profile on E when configured.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-lineup-layout : SDK Godot absent.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(process.env.CD_LINEUP_TEMP||os.tmpdir(),'cd-lineup-'));
const source=path.resolve(__dirname,'../native/godot'),project=path.join(dir,'godot');fs.mkdirSync(project,{recursive:true});
for(const name of fs.readdirSync(source)){const p=path.join(source,name);if(fs.statSync(p).isFile())fs.copyFileSync(p,path.join(project,name));}
for(const name of ['ui','guide'])fs.cpSync(path.join(source,name),path.join(project,name),{recursive:true});
const manifest={};for(const base of ['','ui','guide'])for(const name of fs.readdirSync(path.join(project,base))){const p=path.join(project,base,name);if(fs.statSync(p).isFile()&&/\.(gd|godot|tscn|json)$/.test(name))manifest[path.join(base,name)]=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}fs.writeFileSync(path.join(dir,'source-manifest.json'),JSON.stringify(manifest,null,2));
for(const name of ['assets','fonts','branding','shaders','.godot'])fs.symlinkSync(path.join(source,name),path.join(project,name),'junction');
fs.symlinkSync(path.resolve(source,'../engine'),path.join(dir,'engine'),'junction');
fs.writeFileSync(path.join(dir,'career.json'),JSON.stringify(JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/france-long-career-s6.json.gz')))).checkpoint.save));
for(const name of ['Roaming','Local'])fs.mkdirSync(path.join(dir,'AppData',name),{recursive:true});
const result=spawnSync(godot,[...(process.env.CD_LINEUP_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--log-file',path.join(dir,'runtime.log'),'--path',project,'--script',path.resolve(__dirname,'godot-lineup-layout.gd')],{env:{...process.env,APPDATA:path.join(dir,'AppData/Roaming'),LOCALAPPDATA:path.join(dir,'AppData/Local'),CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'PrototypeGodot'),CD_LINEUP_ARTIFACTS:dir},windowsHide:true,encoding:'utf8',timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);console.log(output);console.log('Preuves Composition : '+dir);if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
