'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const V68=require('../dist/medical-decisions-v68.js');
function state(){return {club:0,season:1,round:3,phase:'league',trained:false,live:null,
 clubs:[{players:[
  {id:'a',name:'Capitaine',pos:'Pilier',injury:3,condition:65,physicalLoad:{version:1,fatigue:40,plan:'repos'}},
  {id:'b',name:'Deuxième ligne',injury:1,condition:78,physicalLoad:{version:1,fatigue:20,plan:'repos'}},
  {id:'c',name:'Valide',injury:0,condition:90,physicalLoad:{version:1,fatigue:10,plan:'normal'}}
 ]}]};}
test('V68 : choix médical persistant, sans toucher aux semaines ni au moteur',()=>{
 const s=state();let saves=0;
 assert.equal(V68.choose(s,'a','prudent',{save(){saves++;return true}}),true);
 assert.equal(saves,1);assert.equal(s.clubs[0].players[0].injury,3);
 assert.equal(s.clubs[0].players[0].medicalV68.protocol,'prudent');
 assert.equal(JSON.parse(JSON.stringify(s)).clubs[0].players[0].medicalV68.version,1);
});
test('V68 : blessé requis et garde d’état',()=>{
 for(const k of ['trained','live','phase']){const s=state();
  s[k]=k==='trained'?true:k==='live'?{}:'ended';
  assert.equal(V68.choose(s,'a','prudent',{save:()=>true}),false);
 }
 assert.equal(V68.choose(state(),'c','accelere',{save:()=>true}),false);
 assert.equal(V68.choose(state(),'a','inconnu',{save:()=>true}),false);
});
test('V68 : refus de sauvegarde sans altérer la carrière',()=>{
 const s=state(),before=JSON.stringify(s);
 assert.equal(V68.choose(s,'a','prudent',{save:()=>false}),false);
 assert.equal(JSON.stringify(s),before);
});
test('V68 : une seule séance, effets prudents et naissance du choix de reprise',()=>{
 const s=state(),p=s.clubs[0].players;
 V68.choose(s,'a','prudent',{save:()=>true});
 const before=new Map(p.map(x=>[x.id,{injury:x.injury,protocol:V68.treatment(x)}]));
 p[0].injury=2;p[1].injury=0;s.trained=true;
 const reports=V68.completeTraining(s,before);
 assert.equal(reports.length,2);assert.equal(p[0].condition,73);
 assert.equal(p[0].physicalLoad.fatigue,30);assert.equal(p[1].medicalV68.stage,'reprise');
 assert.equal(p[2].medicalV68,undefined);
 assert.equal(V68.completeTraining(s,new Map()).length,0);
});
test('V68 : protocole accéléré borné et risque déterministe',()=>{
 const s=state(),p=s.clubs[0].players[0];
 const before=new Map([['a',{injury:3,protocol:'accelere'}]]);
 p.injury=2;
 const report=V68.completeTraining(s,before);
 assert.ok([1,2,3].includes(p.injury));assert.ok(['aucun','contretemps','gain de temps'].includes(report[0].incident));
 assert.equal(p.condition,60);assert.equal(p.physicalLoad.fatigue,52);
 assert.equal(V68.risk(s,p,'soins'),V68.risk(s,p,'soins'));
});
test('V68 : reprise progressive réellement appliquée et persistée',()=>{
 const s=state(),p=s.clubs[0].players[1];p.injury=0;p.medicalV68={version:1,protocol:'standard',stage:'reprise'};
 let saves=0;
 assert.equal(V68.returnToPlay(s,'b','progressif',{save(){saves++;return true}}),true);
 assert.equal(saves,1);assert.equal(p.medicalV68.stage,'progressif');
 assert.equal(p.physicalLoad.plan,'repos');assert.equal(p.condition,86);
 assert.equal(V68.returnToPlay(s,'b','complet',{save:()=>true}),false);
});
test('V68 : retour immédiat avec pénalité et risque borné',()=>{
 const s=state(),p=s.clubs[0].players[1];p.injury=0;p.medicalV68={version:1,protocol:'prudent',stage:'reprise'};
 assert.equal(V68.returnToPlay(s,'b','complet',{save:()=>true}),true);
 assert.equal(p.medicalV68.stage,'termine');assert.equal(p.condition,71);
 assert.equal(p.physicalLoad.fatigue,32);assert.ok([0,1].includes(p.injury));
});
test('V68 : rollback intégral du retour sur sauvegarde refusée',()=>{
 const s=state(),p=s.clubs[0].players[1];p.injury=0;p.medicalV68={version:1,protocol:'standard',stage:'reprise'};
 const before=JSON.stringify(s);
 assert.equal(V68.returnToPlay(s,'b','progressif',{save:()=>false}),false);
 assert.equal(JSON.stringify(s),before);
});
test('V68 : HTML échappé, commandes indisponibles après séance',()=>{
 const s=state();s.clubs[0].players[0].name='<img src=x onerror=alert(1)>';s.trained=true;
 const html=V68.panel(s);assert.match(html,/&lt;img/);
 assert.doesNotMatch(html,/<img /);assert.match(html,/disabled/);
});
test('V68 : installation idempotente, réutilisation de la séance native et affichage santé',()=>{
 const s=state();let saves=0,trainings=0;
 const root={S:s,squadTab:'health',managerTeamView(){return 'Effectif';},
  trainWeek(){trainings++;s.trained=true;s.clubs[0].players[0].injury--;s.clubs[0].players[1].injury--;},
  save(){saves++;},render(){}};
 assert.equal(V68.install(root),true);assert.equal(V68.install(root),true);
 assert.equal((root.managerTeamView().match(/Cellule médicale · V68/g)||[]).length,1);
 V68.choose(s,'a','prudent',{save:()=>true});
 root.trainWeek();root.trainWeek();
 assert.equal(trainings,1);assert.equal(s.clubs[0].players[0].injury,2);
 assert.equal(s.clubs[0].players[0].condition,73);
 assert.equal(s.clubs[0].players[1].medicalV68.stage,'reprise');
 assert.equal(saves,0);
});

test('V68 : ancienne sauvegarde sans champ médical inchangée à la consultation',()=>{
 const s=state(),serialized=JSON.stringify(s),legacy=JSON.parse(serialized);
 assert.equal(legacy.clubs[0].players[0].medicalV68,undefined);
 assert.equal(V68.treatment(legacy.clubs[0].players[0]),'standard');
 assert.match(V68.panel(legacy),/Suivi standard/);
 assert.equal(JSON.stringify(legacy),serialized);
});
test('V68 : round-trip sauvegarde d’un protocole et absence de rechute implicite',()=>{
 const s=state();
 assert.equal(V68.choose(s,'a','prudent',{save:()=>true}),true);
 const restored=JSON.parse(JSON.stringify(s));
 assert.equal(V68.treatment(restored.clubs[0].players[0]),'prudent');
 assert.equal(restored.clubs[0].players[0].injury,3);
 assert.equal(restored.clubs[0].players[1].medicalV68,undefined);
});
