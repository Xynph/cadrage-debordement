'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Catches a hidden local advice when the general plan already matches, and a
// watch button incorrectly tied to recruitment capacity. Exercises real Godot UI.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process'),{context}=require('./harness.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-playbook-watch-ui : SDK Godot absent (CD_GODOT_EXE/CD_GODOT_EXECUTABLE).');process.exit(0);}
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-playbook-watch-ui-'));
const live=context();
live.run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather="Sec";l.score=[0,0];l.territory=18;l.tactics[0]="conquete";l.defences[0]="prudente";giveMatchCard(l,0,activePlayers(l,0)[4].id,"yellow");syncMatchPresentation(l);l.playbooks[0].zones.sortie.attack="large";S.manager.playbook.zones.sortie.attack="large"');
const full=context();
full.run('start(0);while(professionalPlaces()>0&&S.development.academy.length)promoteYouth(S.development.academy[0].id)');
assert.equal(full.run('professionalPlaces()'),0);
for(const [name,fixture] of [['live',live],['full',full]]){
 const text=fixture.run('JSON.stringify(createSaveDocument())');
 const b=createBridge({dataDir:path.join(root,'validate-'+name),seed:827381,now:1700000000000});
 try{const r=b.handle({id:1,command:'import',payload:{text}});assert.equal(r.ok,true,r.error);
  if(name==='live'){assert.equal(r.model.clubLife.playbook.staffAdvice.suggestions.length,0);assert.equal(r.model.clubLife.playbook.staffAdvice.zoneSuggestions.length,1);}
  else{assert.equal(r.model.clubLife.managerCareer.places,0);assert.equal(r.model.clubLife.managerCareer.recruitmentAvailable,false);}
 }finally{b.close();}
 fs.writeFileSync(path.join(root,name+'.json'),text);
}
const profile=path.join(root,'ui','PrototypeGodot');
const r=spawnSync(godot,['--headless','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-playbook-watch-ui.gd')],{windowsHide:true,encoding:'utf8',timeout:180000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_DATA_DIR:profile,CD_PLAYBOOK_WATCH_ARTIFACTS:root}});
const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves UI C04/C08 : '+root);
if(r.error)throw r.error;
assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
const report=JSON.parse(fs.readFileSync(path.join(root,'report.json'),'utf8'));
const b=createBridge({dataDir:profile});
try{const r=b.handle({id:1,command:'snapshot'});assert.equal(r.ok,true,r.error);assert.deepEqual(r.model.clubLife.managerCareer.watch,[report.watchedId]);assert.equal(r.model.clubLife.managerCareer.places,0);console.log('Reprise du profil réel : suivi conservé à effectif plein PASS.');}finally{b.close();}
