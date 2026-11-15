'use strict';
const assert=require('node:assert/strict');
const {engineContext}=require('./harness.cjs');
const {componentContext}=require('./helpers/gestion-domaines.cjs');
const observer=require('../dist/youth-pathways-v72.js');
// Intégration disponible dans le produit World : vrai entraînement et vraie
// promotion d'un adulte, sans activer les compétitions Espoirs historiques.
const world=engineContext();world.start(0);
world.run('var adult=S.development.academy.find(p=>p.age>=18&&p.age<=21),adultId=adult.id,professionalsBefore=club().players.length,wagesBefore=totalWages(),academyBefore=S.development.academy.length;trainWeek();var trainedOnce=JSON.stringify(S);trainWeek()');
assert.ok(world.run('JSON.stringify(S)')===world.run('trainedOnce'),'entraînement World appliqué une seule fois');
assert.equal(world.run('promoteYouth(adultId)'),true,'promotion native World');
assert.equal(world.run('club().players.length-professionalsBefore'),1);
assert.equal(world.run('S.development.academy.length-academyBefore'),-1);
assert.equal(world.run('totalWages()-wagesBefore'),2000);
assert.equal(world.run('player(adultId).contractEnd'),2);
assert.equal(world.run('promoteYouth(adultId)'),false,'aucune promotion doublée');
world.run('save();var worldExport=parseSaveDocument(JSON.stringify(createSaveDocument()))');
assert.equal(world.run('worldExport.state.clubs[S.club].players.filter(p=>p.id===adultId).length'),1,'promotion exportée par le vrai codec World');
world.close();

// Contrat de composants historiques : sept générations15/13 sur copie de
// données World, sans cycle principal, IO ou moteur de match (barrière helper).
const t=componentContext(),run=t.run,p=run('S.development.academy[0].id');
assert.ok(p,'espoir disponible');
assert.equal(run('S.development.academy.length'),15,'15 nouveaux Espoirs la première génération du composant');
assert.equal(run('JSON.stringify(S.development.academy.map(p=>p.pos).sort())===JSON.stringify(POS.slice().sort())'),true,'15 emplacements couverts');
assert.ok(run('CDYouthV72.panel(S).includes("Parcours des Espoirs")'));
const bridge='()=>{componentDocument();return true}';
const initialCash=run('club().cash');
assert.equal(run('CDYouthV72.act(S,"scout",null,null,'+bridge+')'),true);
assert.equal(run('club().cash'),initialCash-35000);
assert.equal(run('CDYouthV72.act(S,"scout",null,null,'+bridge+')'),false,'campagne unique');
assert.equal(run('CDYouthV72.act(S,"mentor",'+JSON.stringify(p)+',"technique",'+bridge+')'),true);
assert.equal(run('CDYouthV72.act(S,"mentor",'+JSON.stringify(p)+',"mental",'+bridge+')'),false,'une décision par semaine');
assert.equal(run('club().cash'),initialCash-43000);
const startRating=run('S.development.academy[0].rating');
// DI de l'observation seulement : ces délégués ne sont pas le moteur principal.
// Les effets réels train/promotion ont été reçus ci-dessus sur World.
let observedTraining=0,observedPromotion=null,persisted='';
const host={S:run('S'),growPlayer:t.ctx.growPlayer,
 trainWeek(){observedTraining++;this.S.trained=true;return 'session-observée';},
 promoteYouth(id){observedPromotion=id;return this.S.development.academy.some(p=>p.id===id);},
 beginDevelopmentSeason(){throw Error('Aucun cycle de carrière dans ce test DI');},
 save(){persisted=JSON.stringify(this.S);return true;}};
assert.equal(observer.install(host),true);
assert.equal(host.trainWeek(),'session-observée');assert.equal(observedTraining,1);
assert.equal(run('S.v72Youth.mentors[0].done'),true,'accompagnement observé');
assert.ok(run('S.development.academy[0].rating')>=startRating);
assert.equal(run('CDYouthV72.training(S,growPlayer,'+bridge+')'),0,'aucun double bonus');
assert.ok(persisted.length>0,'observation sérialisée sans IO');
const restored=run('componentParse(JSON.stringify(componentDocument()))');
assert.equal(restored.state.v72Youth.scouts.length,1,'campagne sérialisée');
assert.equal(restored.state.v72Youth.mentors.length,1,'mentorat sérialisé');
run('S.season++;S.round=0;S.phase="league";S.trained=false;intakeYouth();aiRosterYouthIntake();CDYouthV72.intake(S,()=>{componentDocument();return true})');
assert.equal(run('S.v72Youth.scouts[0].done'),true,'campagne réalisée par le générateur public');
assert.equal(run('S.v72Youth.scouts[0].count'),15);
assert.equal(run('S.development.academy.filter(p=>p.id.startsWith("youth-0-"+S.season+"-")).length'),15,'15 jeunes uniques par génération');
assert.equal(run('JSON.stringify(S.development.academy.filter(p=>p.id.startsWith("youth-0-"+S.season+"-")).map(p=>p.pos).sort())===JSON.stringify(POS.slice().sort())'),true,'15 emplacements de rugby');
assert.equal(run('CDYouthV72.intake(S,()=>true)'),0,'aucune double détection');
const youth=run('S.development.academy.find(x=>x.id.startsWith("youth-0-"+S.season+"-")).id');
assert.equal(host.promoteYouth(youth),true,'observation de la réussite du délégué');
assert.equal(observedPromotion,youth,'identité transmise sans substitution');
assert.equal(run('S.v72Youth.promotions.length'),1,'promotion suivie par install DI');
assert.equal(run('componentParse(JSON.stringify(componentDocument())).state.v72Youth.promotions.length'),1);
// Six générations supplémentaires : seules les API existantes de génération
// sont appelées. Le vieillissement individuel ne joue aucune rencontre senior.
run('for(let i=0;i<6;i++){for(const p of S.development.academy)ageDevelopmentPlayer(p,S.season);S.season++;S.round=0;S.phase="league";S.trained=false;intakeYouth();aiRosterYouthIntake();}');
assert.ok(run('S.development.academy.length')<=75,'capacité du composant75');
assert.equal(run('S.aiRoster.academies.length'),13,'13académies adverses dans le contrat historique');
assert.equal(run('S.aiRoster.academies.every(a=>a.players.length<=75)'),true);
assert.equal(run('S.aiRoster.academies.every(a=>{const ids=new Set([...a.players,...S.clubs[a.clubId].players,...S.economy.freeAgents].map(p=>p.id));return Array.from({length:15},(_,k)=>"youth-"+a.clubId+"-"+S.season+"-"+(300+k)).every(id=>ids.has(id))})'),true,'15jeunes par académie y compris promotions');
assert.equal(run('S.aiRoster.academies.every(a=>new Set(a.players.map(p=>p.id)).size===a.players.length)'),true);
assert.equal(run('new Set(S.development.academy.map(p=>p.id)).size'),run('S.development.academy.length'));
assert.ok(run('componentParse(JSON.stringify(componentDocument())).state.development.academy.length')<=75,'JSON validé après septgénérations');
run('delete S.v72Youth');assert.equal(run('componentParse(JSON.stringify(componentDocument())).state.v72Youth===undefined'),true,'données sans V72');
run('S.live={finished:false}');assert.equal(run('CDYouthV72.act(S,"scout",null,null,'+bridge+')'),false,'match verrouillé dans le composant');
assert.equal(observer.install(host),true,'installation idempotente');
t.close();console.log('V72 PASS : composants septgénérations15/13, observation DI, entraînement/promotion adultes World et vrais exports séparés');
