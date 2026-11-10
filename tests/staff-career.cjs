'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm');
const {factory}=require('../native/engine/staff-career.cjs');
function fixture(){
 const S={season:1,round:0,phase:'league',club:0,commonDatabase:{id:'fixture'},clubs:[{id:0,name:'Club zéro',cash:100000},{id:1,name:'Club un',cash:100000}]};
 const teams=[{id:0,members:[{id:'staff:zero',name:'Coach témoin',role:'Entraîneur',age:63}]},{id:1,members:[{id:'staff:un',name:'Analyste témoin',role:'Analyste'}]}];
 const ctx=vm.createContext({S,nativeStaffCareerSources:{fixture:teams}}),run=text=>vm.runInContext(text,ctx);
 run('const CDStaffCareer=('+factory.toString()+')();');
 const execute=(command,payload)=>{ctx.command=command;ctx.payload=payload;return JSON.parse(run('JSON.stringify(CDStaffCareer.execute(command,payload))'));};
 const model=()=>JSON.parse(run('JSON.stringify(CDStaffCareer.project())'));
 const context=()=>({season:ctx.S.season,week:ctx.S.round,club:0});
 return {ctx,run,execute,model,context,teams};
}
test('Activation explicite, sources intactes, âges estimés/publiés et absence de coût',()=>{
 const h=fixture(),source=JSON.stringify(h.teams),before=JSON.stringify(h.ctx.S);
 assert.equal(h.run('CDStaffCareer.validate(S)'),true);assert.equal(h.model().active,false);
 assert.equal(JSON.stringify(h.ctx.S),before);
 h.execute('staff_career_enable',{context:h.context(),confirmed:true});
 const m=h.model();assert.equal(m.active,true);assert.equal(m.costs.salary,0);
 const reference=m.teams[0].members.find(p=>p.sourceStaffId==='staff:zero');
 assert.equal(reference.ageBasis,'published-derived');assert.equal(reference.age,63);assert.equal(reference.appearanceAge,63);
 assert(m.teams[1].members.some(p=>p.ageBasis==='estimated'));
 assert.equal(JSON.stringify(h.teams),source);assert.equal(h.ctx.S.clubs[0].cash,100000);
 assert.throws(()=>h.execute('staff_career_enable',{context:h.context(),confirmed:true}),/déjà actif/);
});
test('Vraies commandes du domaine : recrutement, renouvellement, libération et refus contexte périmé',()=>{
 const h=fixture();h.execute('staff_career_enable',{context:h.context(),confirmed:true});
 const candidate=h.model().candidates[0];
 h.execute('staff_hire',{context:h.context(),candidateId:candidate.id,years:1,confirmed:true});
 assert(h.model().teams[0].members.some(p=>p.id===candidate.id));
 assert(!h.model().candidates.some(p=>p.id===candidate.id));
 h.execute('staff_renew',{context:h.context(),staffId:candidate.id,years:3,confirmed:true});
 assert.equal(h.model().teams[0].members.find(p=>p.id===candidate.id).contractEnd,3);
 const before=JSON.stringify(h.ctx.S);
 assert.throws(()=>h.execute('staff_release',{context:{...h.context(),week:1},staffId:candidate.id,confirmed:true}),/périmé/);
 assert.equal(JSON.stringify(h.ctx.S),before);
 h.execute('staff_release',{context:h.context(),staffId:candidate.id,confirmed:true});
 assert(h.model().candidates.some(p=>p.id===candidate.id));assert.equal(h.ctx.S.clubs[0].cash,100000);
});
test('Vieillissement, retraite et renouvellement IA sont idempotents et les visages initiaux restent fixes',()=>{
 const h=fixture();h.run('CDStaffCareer.initialize(S)');
 const original=h.model().teams[0].members.find(p=>p.sourceStaffId==='staff:zero');
 for(let completed=1;completed<=18;completed++){
  h.ctx.S.season=completed+1;h.ctx.completed=completed;
  assert.equal(h.run('CDStaffCareer.advance(S,completed)'),true);
  const state=JSON.stringify(h.ctx.S);assert.equal(h.run('CDStaffCareer.advance(S,completed)'),false);assert.equal(JSON.stringify(h.ctx.S),state);
  assert.equal(h.run('CDStaffCareer.validate(S)'),true);
 }
 const m=h.model();assert(!m.teams.flatMap(t=>t.members).some(p=>p.id===original.id));
 assert(m.retired.some(p=>p.id===original.id&&p.appearanceAge===63));
 assert(m.teams[1].members.length>=5);assert(m.history.some(p=>p.kind==='ai-renewal'));
 assert(h.ctx.S.staffCareer.people.flat().length<100);assert(JSON.stringify(h.ctx.S.staffCareer).length<180000);
 assert.equal(h.ctx.S.clubs[1].cash,100000);
});
test('Reconversion dédoublonnée : source joueur et visage exacts, aucun médecin ni diplôme déduit',()=>{
 const h=fixture();h.run('CDStaffCareer.initialize(S)');let found=null;
 for(let n=0;n<100&&!found;n++){
  const p={id:'player:test:'+n,name:'Ancien joueur '+n,age:38,rating:78,fam:5,skills:{mental:75},dev:{careerMinutes:3000}};
  h.ctx.player=p;
  if(h.run('CDStaffCareer.captureRetirement(S,player,0)'))found=p;
 }
 assert(found);h.ctx.player=found;
 assert.equal(h.run('CDStaffCareer.captureRetirement(S,player,0)'),false);
 const converted=h.model().candidates.find(p=>p.sourcePlayerId===found.id);
 assert(converted);assert.equal(converted.appearanceId,found.id);assert.equal(converted.identity.id,found.id);
 assert.notEqual(converted.id,found.id);assert.notEqual(converted.role,'medical');assert.equal(converted.ageBasis,'player-career');
 h.ctx.S.season=2;h.run('CDStaffCareer.advance(S,1)');
 const survived=h.model().teams.flatMap(t=>t.members).concat(h.model().candidates).find(p=>p.id===converted.id);
 assert(survived);assert.equal(survived.age,38,'pas de double vieillissement à la reconversion');assert.equal(survived.appearanceAge,38);
 const serialized=JSON.stringify(h.ctx.S);h.ctx.S=JSON.parse(serialized);
 assert.equal(h.run('CDStaffCareer.validate(S)'),true);assert.equal(JSON.stringify(h.ctx.S),serialized);
 h.ctx.S.staffCareer.people.flat().find(p=>p.id===converted.id).appearanceId='different';
 assert.throws(()=>h.run('CDStaffCareer.validate(S)'),/visage/);
});
test('Registre complet : texte compatible sauvegarde, pages bornées et annuaire immuable',()=>{
 const staff=require('../native/engine/staff.cjs');
 const database='rugby-world-2026-11-09-champ-v5',teams=staff.forDatabase(database).registry.clubs;
 const before=JSON.stringify(teams),S={season:1,round:0,phase:'league',club:0,commonDatabase:{id:database},clubs:teams.map(c=>({id:c.id,name:'Club '+c.id,cash:100000}))};
 const ctx=vm.createContext({S,nativeStaffCareerSources:{[database]:teams}});
 vm.runInContext('const CDStaffCareer=('+factory.toString()+')();CDStaffCareer.initialize(S);',ctx);
 const saved=JSON.stringify(ctx.S.staffCareer),state=JSON.parse(saved);
 assert(state.people.length>1);assert(state.people.every(page=>page.length<=256));
 assert(state.people.flat().length>=2157);
 for(const p of state.people.flat())assert(!/[<>"`&\u0000-\u001f]/.test(p.name+p.roleLabel));
 assert.equal(JSON.stringify(teams),before);assert(saved.length<3000000);
 console.log(JSON.stringify({staffRegistrySmoke:true,people:state.people.flat().length,pages:state.people.length,bytes:Buffer.byteLength(saved)}));
});
test('Import : une horloge individuelle gelée ou une transition globale manquante sont refusées',()=>{
 const h=fixture();h.run('CDStaffCareer.initialize(S);S.season=2;CDStaffCareer.advance(S,1)');
 const good=JSON.stringify(h.ctx.S);
 const p=h.ctx.S.staffCareer.people.flat()[0];p.age--;p.ageSeason--;
 assert.throws(()=>h.run('CDStaffCareer.validate(S)'),/horloge/);
 h.ctx.S=JSON.parse(good);h.ctx.S.staffCareer.lastAdvancedSeason=0;
 assert.throws(()=>h.run('CDStaffCareer.validate(S)'),/horloge/);
 h.ctx.S=JSON.parse(good);assert.equal(h.run('CDStaffCareer.validate(S)'),true);
});
test('Un nom de joueur hérité avec guillemets ou esperluette ne bloque pas la retraite',()=>{
 const h=fixture();h.run('CDStaffCareer.initialize(S)');let converted=false;
 for(let n=0;n<100&&!converted;n++){
  h.ctx.player={id:'player:quoted:'+n,name:'Ancien "Joueur" & coach',age:38,rating:78,fam:5,skills:{mental:75},dev:{careerMinutes:3000}};
  const original=JSON.stringify(h.ctx.player);
  converted=h.run('CDStaffCareer.captureRetirement(S,player,0)');
  assert.equal(JSON.stringify(h.ctx.player),original,'aucun nettoyage du joueur source');
 }
 assert(converted);assert(h.model().candidates.some(p=>p.sourcePlayerId&&p.name.includes(' et ')));
 assert.equal(h.run('CDStaffCareer.validate(S)'),true);
});
test('Fiction et France sans catalogue : quinze fonctions fictives sans référence officielle inventée',()=>{
 for(const count of [14,30]){
  const S={season:1,round:0,phase:'league',club:0,clubs:Array.from({length:count},(_,id)=>({id,name:'Club '+id,cash:10000}))};
  if(count===30)S.franceMode={week:0};
  const ctx=vm.createContext({S});vm.runInContext('const CDStaffCareer=('+factory.toString()+')();',ctx);
  assert.equal(vm.runInContext('CDStaffCareer.project().canEnable',ctx),true);
  assert.equal(vm.runInContext('CDStaffCareer.project().active',ctx),false);
  assert.equal(vm.runInContext('CDStaffCareer.initialize(S)',ctx),true);
  const model=JSON.parse(vm.runInContext('JSON.stringify(CDStaffCareer.project())',ctx));
  assert.equal(model.teams.length,count);assert(model.teams.every(t=>t.members.length>=15));
  const completion=require('../native/engine/staff-completion.cjs');assert(model.teams.every(t=>Object.entries(completion.MINIMUM).every(([key,n])=>completion.coverage(t.members)[key]>=n)));
  assert(model.teams.every(t=>t.members.every(p=>p.sourceKind==='generated'&&p.sourceStaffId===null)));
  assert.equal(vm.runInContext('CDStaffCareer.validate(S)',ctx),true);
 }
});
test('Import : cibles IA exactes dérivées des références, sans inflation ni perte de rôles',()=>{
 const h=fixture();
 h.teams[1].members.push({id:'staff:analyst-two',name:'Autre analyste',role:'Analyste'},
  {id:'staff:historical-scout',name:'Ancien recruteur',role:'Recruteur',historical:true});
 h.run('CDStaffCareer.initialize(S);Math.random=()=>{throw Error("Validation consumed RNG")};');
 const good=JSON.stringify(h.ctx.S),sources=JSON.stringify(h.teams);
 const target=h.ctx.S.staffCareer.targets.find(t=>t.clubId===1);
 assert.equal(target.roles.analyst,2);assert.equal(target.roles.scout,1);
 for(const [club,role,value] of [[1,'scout',100],[1,'analyst',1],[1,'medical',1],[0,'coach',2]]){
  h.ctx.S=JSON.parse(good);h.ctx.S.staffCareer.targets.find(t=>t.clubId===club).roles[role]=value;
  const before=JSON.stringify(h.ctx.S);
  assert.throws(()=>h.run('CDStaffCareer.validate(S)'),/objectifs de rôles/);
  assert.equal(JSON.stringify(h.ctx.S),before,'refus sans modification de carrière');
 }
 h.ctx.S=JSON.parse(good);assert.equal(h.run('CDStaffCareer.validate(S)'),true);
 assert.equal(JSON.stringify(h.ctx.S),good);assert.equal(JSON.stringify(h.teams),sources);
 h.ctx.S.staffCareer.targets.reverse();assert.equal(h.run('CDStaffCareer.validate(S)'),true,'ordre sans effet sur les cibles légitimes');
 delete h.ctx.S.staffCareer;const legacy=JSON.stringify(h.ctx.S);
 assert.equal(h.run('CDStaffCareer.validate(S)'),true);assert.equal(JSON.stringify(h.ctx.S),legacy,'ancienne sauvegarde sans activation inchangée');
});
