const assert=require('node:assert/strict');
const {engineContext:context,matchContext}=require('./harness.cjs');
const value=(t,expr)=>t.run(expr);
const approx=(actual,expected,tolerance=.000001)=>assert.ok(Math.abs(actual-expected)<tolerance,'Expected '+actual+' ≈ '+expected);

(()=>{
// Choix humain explicite, coûts par poste et absence d'effet rétroactif.
const normal=context(),special=context();
for(const t of [normal,special])t.run('start(0)');
assert.equal(value(special,'S.collectivePrepVersion'),1);
assert.equal(value(special,'S.collectiveFocus'),'aucune');
assert.ok(value(special,'collectivePreparationCard().includes("Conquête")'));
assert.equal(value(special,'setCollectiveFocus("non-valide")'),false);
assert.equal(value(special,'setCollectiveFocus("conquete")'),true);
special.run('var front=club().players.find(p=>p.fam<=3&&!p.injury).id;var rear=club().players.find(p=>p.fam>=4&&!p.injury).id');
normal.run('var front=club().players.find(p=>p.fam<=3&&!p.injury).id;var rear=club().players.find(p=>p.fam>=4&&!p.injury).id');
const pre=v=>v.run('JSON.stringify(club().players.map(p=>[p.id,p.condition,p.rating]))');
assert.equal(pre(normal),pre(special),'Choosing a focus does not train or change ratings');
normal.run('trainWeek()');special.run('trainWeek()');
approx(value(special,'physicalLoadValue(player(front))')-value(normal,'physicalLoadValue(player(front))'),4);
approx(value(special,'physicalLoadValue(player(rear))')-value(normal,'physicalLoadValue(player(rear))'),0);
approx(value(special,'player(front).condition'),value(normal,'player(front).condition'));
assert.equal(value(special,'setCollectiveFocus("pied")'),false);
const savedAfterTraining=value(special,'JSON.stringify(club().players.map(p=>p.physicalLoad))');
special.run('trainWeek()');
assert.equal(value(special,'JSON.stringify(club().players.map(p=>p.physicalLoad))'),savedAfterTraining,'No duplicate cost when training is repeated');
assert.equal(value(special,'collectiveFocusForClub(2)'), 'pied');
normal.close();special.close();

})();

(()=>{
// Intelligence des clubs adverses : sélection sans hasard et même coût de charge.
const ai=context();ai.run('start(0);var aiPlayer=S.clubs[2].players.find(p=>p.fam>=4&&!p.injury);var aiInitial=physicalLoadValue(aiPlayer);trainWeek()');
assert.equal(value(ai,'physicalLoadValue(aiPlayer)-aiInitial'),4,'AI also pays the preparation load');
ai.close();

})();

(()=>{
// État figé pour deux équipes, la fatigue réduit exactement le bonus du moteur.
const prepared=matchContext();prepared.run('setCollectiveFocus("conquete");trainWeek();var game=createRugbyMatch(nextMatch()),ownSide=game.pair.indexOf(S.club),otherSide=1-ownSide;');
assert.equal(value(prepared,'game.collectivePrepVersion'),1);
assert.equal(value(prepared,'game.collectivePreparation.focus[ownSide]'),'conquete');
assert.equal(value(prepared,'game.collectivePreparation.focus[otherSide]'),value(prepared,'collectiveFocusForClub(game.pair[otherSide])'));
assert.equal(value(prepared,'collectiveFocusForClub(1)'),'defence','la politique du club1 reste couverte');
assert.equal(value(prepared,'game.collectivePreparation.season'),1);
const potency=value(prepared,'game.collectivePreparation.power[ownSide]');
assert.ok(potency>=.55&&potency<=1);
approx(value(prepared,'collectivePreparationBonus(game,ownSide,"conquete")'),.04*potency);
approx(value(prepared,'collectivePreparationBonus(game,ownSide,"pied")'),0);
prepared.run('var frozen=JSON.stringify(game.collectivePreparation);S.collectiveFocus="pied"');
assert.equal(value(prepared,'JSON.stringify(game.collectivePreparation)'),value(prepared,'frozen'));
prepared.run('S.clubs[0].players.forEach(p=>{ensurePhysicalLoad(p).fatigue=100});');
assert.equal(value(prepared,'JSON.stringify(game.collectivePreparation)'),value(prepared,'frozen'),'No retroactive recalculation from player fatigue');
(()=>{
const fresh=matchContext(),tired=matchContext();fresh.run('S.collectiveFocus="pied";trainWeek();var l=createRugbyMatch(nextMatch()),ownSide=l.pair.indexOf(S.club),otherSide=1-ownSide');
tired.run('S.collectiveFocus="pied";club().players.forEach(p=>{ensurePhysicalLoad(p).fatigue=100});trainWeek();var l=createRugbyMatch(nextMatch()),ownSide=l.pair.indexOf(S.club),otherSide=1-ownSide');
assert.ok(value(fresh,'collectivePreparationBonus(l,ownSide,"pied")')>value(tired,'collectivePreparationBonus(l,ownSide,"pied")'));
fresh.close();tired.close();

})();

(()=>{
// Conquête : même événement et même tirage aléatoire, 82 % échoue sans préparation,
// mais passe avec +4 points (conservation des mêlées/touches disputées).
const scrumNone=matchContext(),scrumPrep=matchContext();
for(const [t,focus] of [[scrumNone,'aucune'],[scrumPrep,'conquete']]){
 t.run('S.collectiveFocus='+JSON.stringify(focus)+';trainWeek();var l=createRugbyMatch(nextMatch()),ownSide=l.pair.indexOf(S.club),otherSide=1-ownSide;delete l.restartVersion;l.collectivePreparation.focus[otherSide]="aucune";Math.random=()=>.82;unit=()=>75;setPieceEffects=()=>({win:0,gain:0,finish:0,move:Object.keys(SCRUM_MOVES)[0]});contestSetPiece(l,ownSide,"scrum")');
}
assert.equal(value(scrumNone,'l.stats[ownSide].scrumsWon'),0);
assert.equal(value(scrumPrep,'l.stats[ownSide].scrumsWon'),1);
scrumNone.close();scrumPrep.close();

})();

(()=>{
// Organisation défensive : réduit l'avancée adverse, sans modifier les qualités ni les lois.
const defense=matchContext();
defense.run('S.collectiveFocus="defence";trainWeek();var l=createRugbyMatch(nextMatch()),ownSide=l.pair.indexOf(S.club),otherSide=1-ownSide;var withPrep=teamEdge(l,otherSide,"attack");var bonus=collectivePreparationBonus(l,ownSide,"defence");l.collectivePreparation.focus[ownSide]="aucune";var withoutPrep=teamEdge(l,otherSide,"attack")');
approx(value(defense,'withoutPrep-withPrep'),value(defense,'bonus'));
assert.equal(value(defense,'l.collectivePreparation.focus[otherSide]'),value(defense,'collectiveFocusForClub(l.pair[otherSide])'));
defense.close();

})();

(()=>{
// Jeu au pied : le gain en mètres change effectivement, pour le même lancer.
const kickNone=matchContext(),kickPrep=matchContext();
for(const [t,focus] of [[kickNone,'aucune'],[kickPrep,'pied']]){
 t.run('S.collectiveFocus='+JSON.stringify(focus)+';trainWeek();var l=createRugbyMatch(nextMatch()),ownSide=l.pair.indexOf(S.club),otherSide=1-ownSide;l.territory=50;l.possession=ownSide;Math.random=()=>.90;kickOpenPlay(l,ownSide)');
}
const added=(value(kickPrep,'l.territory')-value(kickNone,'l.territory'))*value(kickPrep,'ownSide===0?1:-1');
approx(added,value(kickPrep,'collectivePreparationBonus(l,ownSide,"pied")'));
assert.ok(added>0&&added<=3);
kickNone.close();kickPrep.close();

})();

// Sauvegarde, export portable et rapport : état identique à l'import.
prepared.run('S.live=game');
const data=prepared.run('JSON.stringify(S)');
assert.ok(prepared.run('!!createSaveDocument()'));
const imported=context(JSON.parse(data));
assert.equal(value(imported,'JSON.stringify(S.live)'),value(prepared,'JSON.stringify(S.live)'));
assert.equal(value(imported,'S.live.collectivePreparation.focus[S.live.pair.indexOf(S.club)]'),'conquete');
imported.close();prepared.close();
})();

(()=>{
// Ancien match V27 : la sauvegarde charge l'état sans lui appliquer une préparation V28.
const previous=context();
previous.start(0);previous.deferSaves();previous.toMatch();previous.run('beginMatch();pauseMatch();delete S.collectivePrepVersion;delete S.collectiveFocus;delete S.live.collectivePrepVersion;delete S.live.collectivePreparation;var legacy=JSON.parse(JSON.stringify(S));var score=JSON.stringify(S.live.score),minute=S.live.minute');
const historic=context(JSON.parse(previous.run('JSON.stringify(legacy)')));
assert.equal(value(historic,'S.collectivePrepVersion'),1);
assert.equal(value(historic,'S.collectiveFocus'),'aucune');
assert.equal(value(historic,'S.live.collectivePreparation'),undefined);
assert.equal(value(historic,'collectivePreparationBonus(S.live,0,"defence")'),0);
assert.equal(value(historic,'S.live.minute'),value(previous,'minute'));
assert.equal(value(historic,'JSON.stringify(S.live.score)'),value(previous,'score'));
assert.ok(value(historic,'!!createSaveDocument()'));
previous.close();historic.close();
})();

(()=>{
// Un import falsifié est rejeté même avec checksum recalculé.
const checks=context();checks.start(0);checks.deferSaves();checks.toMatch();checks.run('S.collectiveFocus="pied";beginMatch();pauseMatch();var valid=createSaveDocument();');
for(const mutate of ['bad.live.collectivePreparation.focus[0]="illegal"','bad.live.collectivePreparation.power[1]=500','bad.live.collectivePreparation.v=2','bad.collectiveFocus="unknown"']){
 checks.run('var bad=JSON.parse(JSON.stringify(valid.state))');
 assert.throws(()=>checks.run(mutate+';validateCareer(bad)'),mutate);
}
checks.run('var l=S.live;while(!l.finished){l.paused=false;advanceRugby(l)}captureReport()');
assert.ok(value(checks,'!!S.lastReport.collectivePreparation'));
assert.ok(value(checks,'matchDebrief(S.lastReport).includes("Préparation collective")'));
assert.ok(value(checks,'!!createSaveDocument()'));
checks.run('finishRound()');
assert.ok(value(checks,'!!createSaveDocument()'));
checks.close();

})();

// Relevé de calibration reproductible : bornes contrôlées, sans promettre de victoire.
const sample={};
for(const focus of ['aucune','conquete','defence','pied']){
 const t=matchContext();t.run('S.collectiveFocus='+JSON.stringify(focus)+';trainWeek();var l=createRugbyMatch(nextMatch()),ownSide=l.pair.indexOf(S.club),otherSide=1-ownSide');
 const entries=['conquete','defence','pied'].map(kind=>t.run('collectivePreparationBonus(l,ownSide,'+JSON.stringify(kind)+')'));
 sample[focus]={conquete:entries[0],defence:entries[1],pied:entries[2],power:t.run('l.collectivePreparation.power[ownSide]')};
 assert.ok(entries.every(n=>n>=0&&n<=(focus==='pied'?3:.05)));t.close();
}
assert.equal(sample.aucune.conquete+sample.aucune.defence+sample.aucune.pied,0);
assert.ok(sample.conquete.conquete>0&&sample.defence.defence>0&&sample.pied.pied>0);

 // Relevé de calibration exploratoire : 20 matchs consécutifs par politique, même graine de départ.
 // Ce relevé est une mesure du jeu, pas une statistique sportive ou un équilibre démontré.
function simulatePolicy(focus){
 const t=matchContext();t.run('S.collectiveFocus='+JSON.stringify(focus));
 const report={matches:0,points:0,scrums:0,scrumsWon:0,lineouts:0,lineoutsWon:0};
 for(let i=0;i<20;i++){
  t.toMatch();t.run('trainWeek();beginMatch();var ownSide=S.live.pair.indexOf(S.club);while(!S.live.finished){S.live.paused=false;advanceRugby(S.live)}var simulated=JSON.parse(JSON.stringify(S.live));finishRound()');
  const r=JSON.parse(t.run('JSON.stringify(simulated)')),stats=r.stats[t.run('ownSide')];
  report.matches++;report.points+=r.score[t.run('ownSide')];report.scrums+=stats.scrums;report.scrumsWon+=stats.scrumsWon;
  report.lineouts+=stats.lineouts;report.lineoutsWon+=stats.lineoutsWon;
 }
 assert.ok(report.scrumsWon<=report.scrums&&report.lineoutsWon<=report.lineouts);
 t.close();return {...report,meanPoints:Math.round(report.points/report.matches*100)/100};
}
const exploratory={};
for(const focus of ['aucune','conquete','defence','pied'])exploratory[focus]=simulatePolicy(focus);
console.log(JSON.stringify({passed:true,comparisons:sample,exploratory,cases:['explicit decisions and idempotent cost','AI physical fairness','frozen snapshot','fatigue-dependent intensity','scrum result before/after','defensive edge','open-play kick distance','portable report','legacy running match','hostile snapshots']}));
