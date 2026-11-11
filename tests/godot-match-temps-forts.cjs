'use strict';
// Vraie interface + vrai moteur : avec CD_MATCH_TEMPS_FORTS=1, le direct enchaîne
// temps fort → écran intermédiaire → temps fort ; sans la variable, la régie n'existe pas.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),{context}=require('./harness.cjs');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-match-temps-forts : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).');process.exit(0);}
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-match-temps-forts-'));
const source=context();
source.run('start(0);beginMatch()');
fs.writeFileSync(path.join(directory,'live.json'),source.run('JSON.stringify(createSaveDocument())'));
function run(mode){
 const data=path.join(directory,mode,'PrototypeGodot');
 const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:data,CD_MATCH_TEMPS_FORTS_ARTIFACTS:directory,CD_MATCH_TEMPS_FORTS_MODE:mode,CD_GODOT_SEED:'11'}; // même graine, même match
 delete env.CD_MATCH_TEMPS_FORTS;delete env.CD_MATCH_TEMPS_FORTS_NIVEAU;delete env.CD_MATCH_TEMPS_FORTS_HORLOGE;delete env.CD_MATCH_TEMPS_FORTS_VITESSE;delete env.CD_MATCH_GESTES;
 if(mode==='actif')Object.assign(env,{CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_MATCH_TEMPS_FORTS_VITESSE:'4'});
 // Temps forts et gestes ensemble, à vitesse de jeu : vingt minutes de match sans que rien ne se fige.
 if(mode==='gestes')Object.assign(env,{CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_GESTES:'1',CD_MATCH_TEMPS_FORTS_HORLOGE:'eclair',CD_GODOT_SEED:'7'});
 const result=spawnSync(godot,['--headless','--max-fps','60','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-temps-forts.gd')],{env,encoding:'utf8',windowsHide:true,timeout:600000});
 const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(directory,'godot-'+mode+'.log'),output);console.log(output);
 if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 return JSON.parse(fs.readFileSync(path.join(directory,'report-'+mode+'.json'),'utf8'));
}
const sans=run('inactif');
assert.deepEqual(sans.failures,[]);assert.ok(sans.checks>=4);
const avec=run('actif');
assert.deepEqual(avec.failures,[]);assert.ok(avec.checks>=25,'contrôles : '+avec.checks);
const ordre=avec.suivi.map(e=>e.evenement);
const premier=ordre.indexOf('temps_fort'),entre=ordre.indexOf('intermediaire',premier+1),second=ordre.indexOf('temps_fort',entre+1);
assert.ok(premier>=0&&entre>premier&&second>entre,'temps fort → écran intermédiaire → temps fort : '+ordre.join(', '));
const gestes=run('gestes');
assert.deepEqual(gestes.failures,[]);assert.ok(gestes.checks>=10,'contrôles avec les gestes : '+gestes.checks);
assert.ok(gestes.suivi.filter(e=>e.evenement==='temps_fort').length>=4&&!gestes.suivi.some(e=>e.evenement==='echeance'),'temps forts et gestes : '+JSON.stringify(gestes.suivi.map(e=>e.evenement)));
console.log('Preuves temps forts : '+directory+' · '+avec.checks+' contrôles · '+ordre.filter(e=>e==='temps_fort').length+' temps forts joués');
