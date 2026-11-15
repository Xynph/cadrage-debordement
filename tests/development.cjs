const assert=require('node:assert/strict');const {engineContext:context}=require('./harness.cjs');const {annualWorldDataContext}=require('./helpers/gestion-domaines.cjs');let t=context(),run=t.run;run('start(0)');const initialCheckpoint=t.checkpoint();t.deferSaves();
assert.equal(run('S.development.academy.length'),60);assert.equal(run('S.clubs.every(c=>c.players.every(p=>p.dev.potential>=p.rating&&p.dev.potential<=99))'),true);run('setupDevelopment();setupDevelopment();intakeYouth()');assert.equal(run('S.development.academy.length'),60);
// Promotion moves a real prospect; wages start only after promotion and cannot be duplicated.
run('var prospect=S.development.academy[0],before=totalWages();promoteYouth(prospect.id)');assert.equal(run('S.development.academy.length'),59);assert.equal(run('totalWages()-before'),2000);assert.ok(run('player(prospect.id)'));assert.equal(run('promoteYouth(prospect.id)'),false);assert.equal(run('prospect.contractEnd'),2);
// Training, playing time and potential are independent, observable factors.
run('var learner=academyPlayer(0,10,1,99);learner.age=18;learner.dev.potential=90;var reserve=JSON.parse(JSON.stringify(learner));reserve.id="reserved-copy";club().players.push(learner,reserve);for(var i=0;i<29;i++){developmentTraining(learner,"normal");developmentTraining(reserve,"normal");recordDevelopmentMatch({pair:[0,1],sheets:[{used:[learner.id],minutes:{[learner.id]:60}},{used:[],minutes:{}}]})}');assert.ok(run('learner.rating>reserve.rating'));assert.equal(run('learner.dev.minutes'),1740);assert.equal(run('reserve.dev.minutes'),0);assert.equal(run('learner.dev.appearances'),29);
run('learner.dev.potential=learner.rating+2;growPlayer(learner,10000)');assert.equal(run('learner.rating'),run('learner.dev.potential'));assert.equal(run('learner.dev.xp'),0);
// Injury and recovery training cannot increase rating, while age slows growth.
run('var recovering=JSON.parse(JSON.stringify(reserve));recovering.dev.xp=0;recovering.injury=2;developmentTraining(recovering,"intense")');assert.equal(run('recovering.dev.xp'),0);run('recovering.injury=0;developmentTraining(recovering,"repos")');assert.equal(run('recovering.dev.xp'),0);assert.equal(run('ageGrowth({age:18})>ageGrowth({age:29})'),true);assert.equal(run('ageGrowth({age:35})'),0);
// Match experience follows actual minutes once, respecting migration baselines.
run('var tracked=club().players[1];tracked.dev.minutes=0;tracked.dev.appearances=0;var fixture={pair:[0,1],sheets:[{used:[tracked.id],minutes:{[tracked.id]:70}},{used:[],minutes:{}}],devBaseline:[{[tracked.id]:40},{}]};recordDevelopmentMatch(fixture);recordDevelopmentMatch(fixture)');assert.equal(run('tracked.dev.minutes'),30);assert.equal(run('tracked.dev.appearances'),1);
// Migration de données Monde privées de développement : les fonctions historiques
// restent isolées du validateur de carrière complète, puis la vraie sauvegarde est rechargée.
(()=>{
const historical=context();historical.start(0);historical.deferSaves();historical.toMatch();
historical.run('beginMatch();while(S.live.minute<40)advanceRugby(S.live);pauseMatch()');
const healthy=historical.state(),legacy=structuredClone(healthy);void historical.store;
delete legacy.development;legacy.clubs.forEach(c=>c.players.forEach(p=>delete p.dev));legacy.market.forEach(p=>delete p.dev);
const ratings=JSON.stringify(legacy.clubs.map(c=>c.players.map(p=>[p.id,p.age,p.rating,p.salary,p.contractEnd])));
historical.ctx.legacyText=JSON.stringify(legacy);historical.ctx.healthyText=JSON.stringify(healthy);
try{
 historical.run('S=JSON.parse(legacyText);setupDevelopment(true)');
 assert.ok(historical.store['bdt-backup-development']);
 assert.equal(historical.run('S.live.minute'),40);
 assert.equal(historical.run('club().cash'),legacy.clubs[0].cash);
 assert.ok(historical.run('JSON.stringify(S.clubs.map(c=>c.players.map(p=>[p.id,p.age,p.rating,p.salary,p.contractEnd])))')===ratings);
 assert.equal(historical.run('JSON.stringify(S.live.devBaseline)'),JSON.stringify(legacy.live.sheets.map(sheet=>sheet.minutes)));
}finally{historical.run('S=JSON.parse(healthyText);save()');historical.close();}
const m=context(healthy);assert.equal(m.run('S.live.minute'),40);assert.ok(m.run('JSON.stringify(S.clubs.map(c=>c.players.map(p=>[p.id,p.age,p.rating,p.salary,p.contractEnd])))')===ratings);m.close();
})();
console.log('Développement : migration à40min reçue');
// Decline, history and retirements happen once at season close, before contract expiry.
t.restore(initialCheckpoint);run('var old=academyPlayer(0,10,1,7777);club().players.push(old);old.age=33;old.dev.retireAge=40;old.dev.seasonStart=old.rating;var previous=old.rating,ageBefore=old.age;rollDevelopmentYear();rollDevelopmentYear()');assert.equal(run('old.age'),34);assert.equal(run('old.rating'),run('previous-1'));assert.equal(run('old.dev.history.length'),1);assert.equal(run('old.dev.history[0].season'),1);
t.restore(initialCheckpoint);t.deferSaves();console.log('Développement : avant la vraie clôture de saison');t.season();run('[...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents,...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players)].forEach(p=>p.dev.retireAge=Math.max(p.dev.retireAge,p.age+2));var retiring=club().players[0];retiring.dev.retireAge=retiring.age+1;retiring.contractEnd=3;var oldWages=totalWages();nextSeason()');assert.ok(run('modal.includes("retraite")'));assert.equal(run('S.season'),1);assert.equal(run('negotiateContract(retiring.id,"renew",20000,3)'),false);run('rollDevelopmentYear()');assert.equal(run('player(retiring.id)'),undefined);assert.equal(run('oldWages-totalWages()'),run('retiring.salary'));assert.equal(run('S.economy.freeAgents.some(p=>p.id===retiring.id)'),false);assert.equal(run('S.development.retired.some(p=>p.id===retiring.id)'),true);
// Intégration actuelle : la commande transactionnelle inclut les centres natifs.
run('save()');t.command('next_season',{confirmed:true});assert.equal(run('S.season'),2);assert.equal(run('S.worldMode.week'),0);assert.equal(run('sheetErrors().length'),0);assert.equal(run('S.clubs.length'),116);assert.equal(run('new Set(S.clubs.flatMap(c=>c.players.map(p=>p.id))).size===S.clubs.flatMap(c=>c.players).length'),true);assert.equal(run('S.academyIntake.season'),2);assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));console.log('Développement : intersaison transactionnelle et export reçus');
// A live fixture locks youth promotions as well as transfers.
t.restore(initialCheckpoint);t.deferSaves();t.toMatch();run('var id=S.development.academy[0].id;var youthBeforeLive=S.development.academy.length;beginMatch();pauseMatch()');assert.equal(run('promoteYouth(id)'),false);assert.equal(run('S.development.academy.length'),run('youthBeforeLive'));
// Dix cycles annuels de COMPOSANTS sur copie intégrale des116clubs : aucune
// simulation senior/nationale, aucun trainWeek ni pipeline principal recopié.
// Les politiques de séance, blessure et minutes sont reçues par les cas précédents.
t.close();t=null;run=null;const cycles=annualWorldDataContext(13),cycle=cycles.run;
assert.equal(cycle('S.clubs.length'),116);assert.equal(cycle('S.worldMode.version'),5);
for(let year=0;year<10;year++){
 console.log('Développement : cycle de composants116 '+(year+1)+' / 10');
 for(let week=0;week<29;week++)cycle('for(const c of S.clubs)for(const p of c.players)developmentTraining(p,"normal",c.id);for(const p of S.development.academy)developmentTraining(p,"normal",S.club)');
 // Chaque appel est l’API de données existante. season/phase sont des entrées
 // du composant uniquement ; le calendrier World copié n’est jamais simulé.
 cycle('S.phase="ended";rollDevelopmentYear();settleContracts();S.season++;S.round=0;S.phase="league";intakeYouth();aiRosterYouthIntake();CDNativeAcademyGroups.afterSeason(S,S.club);CDNativeAcademyGroups.settleIntake(S);nativeProfessionalDepth.fill(S);autoLineup()');
 assert.equal(cycle('S.season'),year+2);assert.equal(cycle('sheetErrors().length'),0);
 assert.equal(cycle('S.clubs.every(c=>{var s=buildSheet(c);return [...s.lineup,...s.bench].filter(Boolean).length===23})'),true);
 assert.equal(cycle('S.clubs.every(c=>c.players.every(p=>Number.isFinite(p.rating)&&p.rating<=p.dev.potential&&p.dev.potential<=99&&p.age<p.dev.retireAge))'),true);
 assert.equal(cycle('S.development.academy.length<=75'),true);
 assert.equal(cycle('new Set(S.clubs.flatMap(c=>c.players.map(p=>p.id))).size===S.clubs.flatMap(c=>c.players).length'),true);
 assert.equal(cycle('Number.isFinite(futureWages())'),true);
 cycle('CDNativeAcademyGroups.validate(S);validatePopulationPolicy(S);for(const p of [...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents,...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players)])validatePlayerPopulation(p,S)');
}
assert.ok(cycle('S.development.retired.length>0'));cycles.close();
console.log(JSON.stringify({passed:true,annualComponentCycles:10,clubs:116,sessionsPerCycle:29,nativeWorldInterseasons:1,checks:['potential ceilings','actual minutes and appearances','idempotent experience','training and injury effects','prospect promotion and wages','cohort uniqueness','legacy live-save migration','decline and history','retirement removal and payroll','retirement contract limits','AI renewal and positional cover','transactional native interseason and current academy intake']}));
