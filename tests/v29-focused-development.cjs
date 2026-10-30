'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
function close(a,b){assert.ok(Math.abs(a-b)<1e-8,'Expected '+a+' to equal '+b)}

// Historiques : aucun changement avant choix explicite.
const initial=context();initial.run('start(0);var front=club().players.find(p=>p.fam===0),before=roleNote(front),attributes=JSON.stringify(front.skills)');
assert.equal(initial.run('developmentFocusValue(front)'),'equilibre');
assert.equal(initial.run('roleNote(front)'),initial.run('before'));
assert.equal(initial.run('JSON.stringify(front.skills)'),initial.run('attributes'));
assert.equal(initial.run('developmentFocusOptions(front).includes("goal")'),false);
assert.equal(initial.run('setDevelopmentFocus(front.id,"goal")'),false);
assert.equal(initial.run('setDevelopmentFocus(front.id,"scrum")'),true);
assert.ok(initial.run('playerDevelopmentHTML(front).includes("Objectif individuel")'));
assert.ok(initial.run('formationView().includes("Objectif individuel")'));
assert.equal(initial.run('S.developmentFocusVersion'),1);
assert.equal(initial.run('setDevelopmentFocus("absent","scrum")'),false);

// XP partagée (pas doublée) : 2 XP ciblées = +1 rating, +2 mêlée.
// En équilibre, +2 rating général et aucun bonus spécifique.
const neutral=context(),focused=context();
for(const t of [neutral,focused])t.run('start(0);var p=club().players.find(p=>p.fam===0);p.age=19;p.rating=70;p.skillBase=70;p.skills.scrum=60;p.skills.power=60;p.dev.potential=94;p.dev.xp=0;var oldRating=p.rating,oldScrum=skill(p,"scrum"),oldPower=skill(p,"power")');
focused.run('setDevelopmentFocus(p.id,"scrum")');
neutral.run('growPlayer(p,2)');focused.run('growPlayer(p,2)');
assert.equal(neutral.run('p.rating-oldRating'),2);
assert.equal(focused.run('p.rating-oldRating'),1);
assert.equal(focused.run('focusedBonus(p,"scrum")'),2);
assert.equal(focused.run('skill(p,"scrum")-oldScrum'),3);
assert.equal(focused.run('skill(p,"power")-oldPower'),1);
assert.equal(neutral.run('skill(p,"scrum")-oldScrum'),2);
assert.equal(neutral.run('skill(p,"power")-oldPower'),2);
assert.equal(focused.run('p.dev.xp'),0);
assert.equal(focused.run('p.dev.specialization.xp'),0);
focused.run('setDevelopmentFocus(p.id,"power")');
assert.equal(focused.run('focusedBonus(p,"scrum")'),2);
focused.run('growPlayer(p,10)');
assert.ok(focused.run('focusedBonus(p,"power")<=4'));
assert.ok(focused.run('focusedBonusTotal(p.dev.specialization)<=8'));
assert.equal(focused.run('slotEligible(p,0)'),true);
focused.run('growPlayer(p,200)');
assert.equal(focused.run('p.rating'),focused.run('p.dev.potential'));

// V27 : fatigue. V28 : préparation alignée. Pas de nouveau coefficient pour
// les carrières non spécialisées.
const phys=context();
phys.run('start(0);var p=club().players.find(p=>p.fam===0);setDevelopmentFocus(p.id,"scrum");p.rating=70;p.skillBase=70;p.skills.scrum=65;p.dev.potential=99;p.condition=100;var rested=JSON.parse(JSON.stringify(p)),heavy=JSON.parse(JSON.stringify(p)),aligned=JSON.parse(JSON.stringify(p));rested.physicalLoad={version:1,fatigue:0,plan:"collective"};heavy.physicalLoad={version:1,fatigue:90,plan:"collective"};aligned.physicalLoad={version:1,fatigue:0,plan:"collective"};');
phys.run('S.collectiveFocus="aucune";developmentTraining(rested,"normal",S.club);developmentTraining(heavy,"normal",S.club);S.collectiveFocus="conquete";developmentTraining(aligned,"normal",S.club)');
assert.ok(phys.run('heavy.dev.xp<rested.dev.xp'));
assert.ok(phys.run('aligned.dev.xp>rested.dev.xp'));
assert.ok(phys.run('aligned.dev.specialization.xp>rested.dev.specialization.xp'));
const oldGrowth=context();
oldGrowth.run('start(0);var origin=club().players.find(p=>p.fam===0),a=JSON.parse(JSON.stringify(origin)),b=JSON.parse(JSON.stringify(origin));a.physicalLoad={version:1,fatigue:0,plan:"collective"};b.physicalLoad={version:1,fatigue:100,plan:"collective"};developmentTraining(a,"normal");developmentTraining(b,"normal")');
close(oldGrowth.run('a.dev.xp'),oldGrowth.run('b.dev.xp'));

// Centre de formation et promotion : focus conservé, contrat inchangé.
const academy=context();academy.run('start(0);var youth=S.development.academy[0],rating=youth.rating,salary=youth.salary,pos=youth.pos,choice=developmentFocusRecommendation(youth)');
assert.equal(academy.run('setDevelopmentFocus(youth.id,choice)'),true);
assert.equal(academy.run('youth.rating'),academy.run('rating'));
assert.equal(academy.run('youth.salary'),academy.run('salary'));
assert.equal(academy.run('youth.pos'),academy.run('pos'));
academy.run('for(let i=0;i<24;i++)developmentTraining(youth,"normal")');
assert.ok(academy.run('focusedBonusTotal(youth.dev.specialization)>0'));
assert.equal(academy.run('youth.dev.minutes'),0);
academy.run('var youthId=youth.id;promoteYouth(youthId)');
assert.equal(academy.run('player(youthId).dev.specialization.focus'),academy.run('choice'));
assert.equal(academy.run('player(youthId).contractEnd'),2);
academy.run('S.trained=true');
assert.equal(academy.run('setDevelopmentFocus(youthId,"equilibre")'),false);
academy.run('S.trained=false;beginMatch();pauseMatch()');
assert.equal(academy.run('setDevelopmentFocus(youthId,"equilibre")'),false);

// Minutes réellement jouées ; idempotence ; ancien match avec XP générale.
const minutes=context();
minutes.run('start(0);var p=club().players.find(p=>p.fam===0);p.age=19;p.dev.potential=99;setDevelopmentFocus(p.id,"scrum");var fixture={pair:[0,1],developmentFocusVersion:1,sheets:[{used:[p.id],minutes:{[p.id]:70}},{used:[],minutes:{}}],devBaseline:[{[p.id]:40},{}]};recordDevelopmentMatch(fixture)');
assert.equal(minutes.run('p.dev.minutes'),30);
assert.equal(minutes.run('p.dev.appearances'),1);
assert.ok(minutes.run('p.dev.specialization.xp>0'));
const observed=minutes.run('JSON.stringify(p.dev)');
minutes.run('recordDevelopmentMatch(fixture)');
assert.equal(minutes.run('JSON.stringify(p.dev)'),observed);
minutes.run('var oldP=JSON.parse(JSON.stringify(p));oldP.id="legacy-copy";oldP.dev.xp=0;oldP.dev.specialization.xp=0;club().players.push(oldP);var oldFixture={pair:[0,1],sheets:[{used:[oldP.id],minutes:{[oldP.id]:80}},{used:[],minutes:{}}]};recordDevelopmentMatch(oldFixture)');
assert.equal(minutes.run('oldP.dev.specialization.xp'),0);
assert.ok(minutes.run('oldP.dev.xp>0'));

// Ancienne carrière V28 à la pause : aucune note ou minute réécrite.
const source=context();source.run('start(0);beginMatch();pauseMatch()');
const legacy=JSON.parse(source.run('JSON.stringify(S)'));
delete legacy.developmentFocusVersion;delete legacy.live.developmentFocusVersion;
for(const c of legacy.clubs)for(const p of c.players)delete p.dev.specialization;
for(const p of legacy.market)if(p.dev)delete p.dev.specialization;
for(const p of legacy.economy.freeAgents)if(p.dev)delete p.dev.specialization;
for(const p of legacy.development.academy)delete p.dev.specialization;
const scores=legacy.clubs.map(c=>c.players.map(p=>[p.id,p.rating,p.skillBase,p.skills,p.pos]));
const restored=context(legacy);
assert.equal(restored.run('S.developmentFocusVersion'),1);
assert.equal(restored.run('S.live.developmentFocusVersion'),undefined);
assert.equal(restored.run('S.live.minute'),legacy.live.minute);
assert.deepEqual(JSON.parse(restored.run('JSON.stringify(S.live.score)')),legacy.live.score);
assert.deepEqual(JSON.parse(restored.run('JSON.stringify(S.clubs.map(c=>c.players.map(p=>[p.id,p.rating,p.skillBase,p.skills,p.pos])))')),scores);
const textSave=restored.run('JSON.stringify(createSaveDocument())');
assert.equal(restored.run('parseSaveDocument('+JSON.stringify(textSave)+').state.live.developmentFocusVersion'),undefined);

// Sauvegardes malveillantes rejetées, avec checksum validé à l'import.
const invalid=context();invalid.run('start(0);var p=club().players.find(p=>p.fam===0);setDevelopmentFocus(p.id,"scrum");var pid=p.id');
for(const mutation of [
 'bad.clubs[0].players.find(p=>p.id===pid).dev.specialization.focus="goal"',
 'bad.clubs[0].players.find(p=>p.id===pid).dev.specialization.xp=3',
 'bad.clubs[0].players.find(p=>p.id===pid).dev.specialization.bonuses.scrum=40',
 'bad.clubs[0].players.find(p=>p.id===pid).dev.specialization.bonuses.constructor=1',
 'bad.developmentFocusVersion=999'
]){
 invalid.run('var bad=JSON.parse(JSON.stringify(S))');
 assert.throws(()=>invalid.run(mutation+';validateCareer(bad)'),mutation);
}
const current=invalid.run('JSON.stringify(createSaveDocument())');
assert.equal(invalid.run('parseSaveDocument('+JSON.stringify(current)+').state.developmentFocusVersion'),1);

// Calibration : six saisons d'entraînement, mêmes joueurs/graines, avec ou sans
// spécialisation. L'éligibilité rugby et les plafonds sont invariants.
function multiSeason(focus){
 const t=context();
 t.run('start(0);var p=club().players.find(p=>p.fam===0);p.age=19;p.rating=58;p.skillBase=58;p.skills.scrum=60;p.dev.potential=92;p.dev.retireAge=44;var id=p.id;p.contractEnd=99');
 if(focus!=='equilibre')t.run('setDevelopmentFocus(id,'+JSON.stringify(focus)+')');
 const years=[];
 for(let i=0;i<6;i++){
  t.run('for(let w=0;w<26;w++){S.trained=false;trainWeek()}');
  years.push(JSON.parse(t.run('JSON.stringify({season:S.season,age:player(id).age,rating:player(id).rating,scrum:skill(player(id),"scrum"),bonus:focusedBonus(player(id),"scrum")})')));
  t.run('S.phase="ended";advanceSeason()');
  assert.equal(t.run('S.season'),i+2);
  assert.equal(t.run('S.clubs.every(c=>c.players.every(p=>p.dev.potential>=p.rating&&p.age<p.dev.retireAge))'),true);
  assert.equal(t.run('S.development.academy.every(p=>p.age<=21)'),true);
  assert.ok(t.run('!!createSaveDocument()'));
 }
 return years;
}
const years={balanced:multiSeason('equilibre'),specialized:multiSeason('scrum')};
const b=years.balanced.at(-1),s=years.specialized.at(-1);
assert.ok(b.rating>=s.rating,'General progression is stronger when balanced');
assert.ok(s.bonus>0&&s.bonus<=4);
assert.ok(s.scrum>b.scrum,'Focusing scrum must strengthen that attribute despite slower general growth');
assert.ok(years.specialized.every(v=>v.bonus<=4));
console.log(JSON.stringify({passed:true,seasons:6,years,checks:['position guard','explicit choice','single XP pool','role-specific effect','fatigue V27','preparation V28','academy/promotion','minutes and idempotence','old live career','hostile save','six-season comparison']}));
