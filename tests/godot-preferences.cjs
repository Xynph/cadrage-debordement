'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const {Worker,isMainThread,workerData}=require('node:worker_threads');
if(!isMainThread){
  let samples=0,missing=0,invalid=0,readErrors=0;const until=Date.now()+100000;
  const target=path.join(workerData,'atomic','interface.json');
  const start=path.join(workerData,'monitor-start'),stop=path.join(workerData,'monitor-stop');
  while(!fs.existsSync(start)&&!fs.existsSync(stop)&&Date.now()<until)Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,1);
  while(!fs.existsSync(stop)&&Date.now()<until){
    samples++;
    try{const value=JSON.parse(fs.readFileSync(target,'utf8'));if(![20,80].includes(value.volume)||value.version!==1)invalid++;}
    catch(error){if(error.code==='ENOENT')missing++;else if(error instanceof SyntaxError)invalid++;else readErrors++;}
  }
  fs.writeFileSync(path.join(workerData,'monitor-report.json'),JSON.stringify({samples,missing,invalid,readErrors}));
  process.exit(0);
}
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-preferences : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-preferences-'));
if(process.platform==='win32'){
  fs.mkdirSync(path.join(directory,'read-only'));
  fs.writeFileSync(path.join(directory,'read-only','interface.json'),JSON.stringify({version:1,volume:25,reduced_motion:false,quality:'balanced',camera:'tv'}));
  fs.chmodSync(path.join(directory,'read-only','interface.json'),0o444);
}
const monitor=new Worker(__filename,{workerData:directory});
const result=spawnSync(godot,[...(process.env.CD_PREFERENCES_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-preferences.gd')],{env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(directory,'career'),CD_PREFERENCES_TEST_DIR:directory},encoding:'utf8',windowsHide:true,timeout:120000});
const output=(result.stdout||'')+(result.stderr||'');
if(process.platform==='win32')fs.chmodSync(path.join(directory,'read-only','interface.json'),0o666);
fs.writeFileSync(path.join(directory,'monitor-stop'),'stop');
const until=Date.now()+5000;
while(!fs.existsSync(path.join(directory,'monitor-report.json'))&&Date.now()<until)Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,5);
monitor.unref();
fs.writeFileSync(path.join(directory,'godot.log'),output);console.log(output);console.log('Preuves préférences : '+directory);
if(result.error)throw result.error;
assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
const sample=JSON.parse(fs.readFileSync(path.join(directory,'monitor-report.json'),'utf8'));
console.log('Lectures concurrentes : '+JSON.stringify(sample));
assert.ok(sample.samples>0,'Lecteur concurrent réellement exécuté');assert.equal(sample.missing,0,'Le fichier doit rester présent pendant chaque remplacement');assert.equal(sample.invalid,0,'Le lecteur ne doit voir que des documents entiers');
assert.equal(sample.readErrors,0,'La lecture reste disponible pendant chaque remplacement');
