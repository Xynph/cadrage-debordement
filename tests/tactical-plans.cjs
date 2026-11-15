const assert=require('node:assert/strict');const {engineContext:context,matchContext}=require('./harness.cjs');const T=require('./helpers/tirages.cjs');
{
let t=matchContext(),run=t.run;run('setDefence("pression");beginMatch();pauseMatch();var l=S.live');
assert.equal(run('l.defences[0]'),'pression');assert.equal(run('l.tacticalVersion'),1);
run('l.paused=false;setLiveDefence("prudente")');assert.equal(run('l.defences[0]'),'pression');run('pauseMatch();setLiveDefence("prudente")');assert.equal(run('l.defences[0]'),'prudente');assert.ok(run('displayedAction(l).text.includes("Glissée prudente")'));
const saved=run('JSON.parse(JSON.stringify(S))');const restored=context(saved);assert.equal(restored.run('S.live.defences[0]'),'prudente');restored.close();assert.ok(run('!!createSaveDocument()'));
for(const change of ['bad.live.defences[0]="unknown"','bad.live.tacticalVersion=99','bad.live.tacticalStats[0].advances=999','bad.live.events.find(e=>e.scene.plans).scene.plans.defence[0]="unknown"']){run('var bad=JSON.parse(JSON.stringify(S))');assert.throws(()=>run(change+';validateCareer(bad)'))}
// Rendered positions keep the plans recorded at the action, even after a later change.
run('ballPossession(l,0,50);l.defences[1]="pression";l.tactics[0]="large";addEvent(l,"Action témoin","play",{kind:"carry",team:0});var index=l.events.length-1;var first=JSON.stringify(matchScene(l).players.map(p=>[p.id,p.x,p.y]));l.defences[1]="prudente";l.tactics[0]="conquete";addEvent(l,"Nouvelle consigne","tactic");playback(l).cursor=index');assert.equal(run('JSON.stringify(matchScene(l).players.map(p=>[p.id,p.x,p.y]))'),run('first'));assert.equal(run('matchViewState(l).tactics[0]'),'large');assert.equal(run('matchViewState(l).defences[1]'),'pression');
run('syncMatchPresentation(l);var second=JSON.stringify(matchScene(l).players.map(p=>[p.id,p.x,p.y]))');assert.notEqual(run('second'),run('first'));
// Staff advice cites measured data and offers a choice; rendering never changes a plan.
run('l.minute=40;endFlowPeriod(l);l.weather="Pluie";l.tactics[0]="large";l.defences[0]="pression";l.tacticalStats[0].carries=10;l.tacticalStats[0].advances=3;l.tacticalStats[0].metres=40;l.tacticalStats[0].handErrors=4;l.stats[0].penalties=4;var before=JSON.stringify(S);var staff=halftimeStaff(l)');assert.ok(run('JSON.stringify(S)')===run('before'),'le conseil conserve tout l’état');assert.ok(run('staff.includes("4 fautes de main sous la pluie")'));assert.equal(run('halftimeAdvice(l).suggestions.length'),2);
// Old in-progress games keep the previous physical model until their end.
run('delete l.playbookVersion;delete l.playbooks;delete l.tacticalVersion;delete l.defences;delete l.tacticalStats;delete l.numericalAiVersion;l.managerMemory?.forEach(m=>{delete m.lastCardDiff;delete m.cardBase});var old=JSON.parse(JSON.stringify(S))');const legacy=context(run('old'));assert.equal(legacy.run('tacticalRules(S.live)'),false);assert.equal(legacy.run('S.live.tacticalVersion'),undefined);assert.ok(legacy.run('!!createSaveDocument()'));
// A territory coordinate after a kick may be fractional. Its remaining gain
// to the line must stay exportable and be rounded only for display.
const fractional=matchContext();fractional.run('beginMatch();pauseMatch();var l=S.live;l.tacticalStats[0].carries=1;l.tacticalStats[0].advances=1;l.tacticalStats[0].metres=12.75');assert.ok(fractional.run('!!createSaveDocument()'));assert.ok(fractional.run('tacticalMetrics(l).includes(">13<")'));
t.close();legacy.close();fractional.close();
}
// The same carry opportunity favors a pack built for power under a close plan, and backs built for
// speed/passing under a wide plan. No universal style bonus.
// Règle : l'avantage de la course (teamEdge) classe les plans selon le profil. On le lit directement (aucun tirage),
// puis on le retrouve dans le taux de courses réussies d'un échantillon : le tirage de réussite n'est plus choisi
// pour tomber entre deux probabilités (l'ancien .6 devait rester dans une fenêtre de ±0,04 autour du taux du moteur).
function profil(profile,plan){const x=matchContext();x.run(`var l=createRugbyMatch(nextMatch(),null,true);l.tactics=['${plan}','equilibre'];l.defences=['equilibre','equilibre'];l.weather='Sec';S.clubs.forEach(c=>c.players.forEach(p=>{p.rating=75;p.skillBase=75;p.condition=100;Object.keys(ATTR).forEach(k=>p.skills[k]=75)}));S.clubs[l.pair[0]].players.forEach(p=>{p.skills.power=${profile==='power'?99:20};p.skills.pass=${profile==='backs'?99:20};p.skills.speed=${profile==='backs'?99:20}});ballPossession(l,0,40)`);return x}
const edges={};for(const [p,plan] of [['power','conquete'],['power','large'],['backs','large'],['backs','conquete']]){const probe=profil(p,plan);try{edges[p+plan]=probe.run("teamEdge(l,0,'attack')")}finally{probe.close()}}
assert.ok(edges.powerconquete>edges.powerlarge,'avant puissant : le jeu au près lui donne plus d’avantage que le large');assert.ok(edges.backslarge>edges.backsconquete,'trois-quarts rapides : le large leur donne plus d’avantage que le jeu au près');
// Taux observé : mêmes joueurs, 3 000 courses chacun. Chaque essai repart de la même rencontre (photographie JSON) avec ses propres tirages
// (graine = numéro de l'essai, communs aux deux plans comparés) : la fatigue et l'historique d'une phase ne contaminent pas la suivante.
function tauxAvance(profile,plan,n=3000){const x=profil(profile,plan);x.run(`var __ph=JSON.stringify(l),__a=0,__c=0;for(let i=0;i<${n};i++){var __s=(i*2654435761+12345)>>>0;Math.random=()=>{__s=(Math.imul(__s,1664525)+1013904223)>>>0;return __s/4294967296};l=JSON.parse(__ph);l.possession=0;l.territory=40;advanceCausalPlay(l);const s=l.tacticalStats[0];if(s.carries){__c++;if(s.advances)__a++}}`);const result=[x.run('__a'),x.run('__c')];x.close();return result}
{const [aP,cP]=tauxAvance('power','conquete'),[aL,cL]=tauxAvance('power','large');T.plusGrand('avants : taux d’avance au près > au large',T.zProportions(aP,cP,aL,cL));
 const [bL,dL]=tauxAvance('backs','large'),[bC,dC]=tauxAvance('backs','conquete');T.plusGrand('trois-quarts : taux d’avance au large > au près',T.zProportions(bL,dL,bC,dC))}
// Controlled repeated games: identical players, alternating tested side,
// same seeds per case, no AI plan/substitution changes. These are fictional
// engine measurements, not estimated real-world rugby probabilities.
// Les comparaisons sont des écarts en écarts types (T.Z = 4) sur des taux par course ou des moyennes par match, jamais des
// marges absolues (« +100 erreurs ») qui dépendent du volume de jeu et donc du recalage des taux de course et de faute.
const sim=matchContext();sim.run('S.clubs.forEach(c=>c.players.forEach(p=>{p.rating=75;p.skillBase=75;p.condition=100;p.injury=0;Object.keys(ATTR).forEach(k=>p.skills[k]=75)}));var sampleIds=nextMatch().slice(),baseline=Object.fromEntries(sampleIds.map(id=>[id,JSON.stringify(S.clubs[id])])),untouched=JSON.stringify(S.clubs.filter(c=>!sampleIds.includes(c.id)));adaptManager=()=>{};manageSubstitutions=()=>{}');
function sample(attack,defence,weather='Sec',games=80){
 const out={games,carries:0,advances:0,metres:0,handErrors:0,kicks:0,longGains:0,points:0,wins:0,defenderPenalties:0,defenderCondition:0,penaltiesByGame:[],conditionByGame:[]};
 for(let i=0;i<out.games;i++){
  const side=i%2;
  sim.run(`for(const id of sampleIds)S.clubs[id]=JSON.parse(baseline[id]);var sampleSeed=${(i+1)*19073};Math.random=()=>{sampleSeed=(Math.imul(sampleSeed,1664525)+1013904223)>>>0;return sampleSeed/4294967296};var game=createRugbyMatch(nextMatch(),null,true);game.tactics=['equilibre','equilibre'];game.defences=['equilibre','equilibre'];game.tactics[${side}]=${JSON.stringify(attack)};game.defences[${1-side}]=${JSON.stringify(defence)};game.weather=${JSON.stringify(weather)};while(!game.finished){game.paused=false;advanceRugby(game)}`);
  const stats=sim.run(`game.tacticalStats[${side}]`);for(const key of ['carries','advances','metres','handErrors','kicks','longGains'])out[key]+=stats[key];
  const pen=sim.run(`game.stats[${1-side}].penalties`),cond=sim.run(`mean(activePlayers(game,${1-side}).map(p=>p.condition))`);
  out.points+=sim.run(`game.score[${side}]`);out.wins+=sim.run(`game.score[${side}]>game.score[${1-side}]`);out.defenderPenalties+=pen;out.defenderCondition+=cond;out.penaltiesByGame.push(pen);out.conditionByGame.push(cond);
 }
 return out;
}
const balanced=sample('equilibre','equilibre'),wide=sample('large','equilibre'),close=sample('conquete','equilibre'),kicking=sample('occupation','equilibre'),wetWide=sample('large','equilibre','Pluie'),wetClose=sample('conquete','equilibre','Pluie'),rush=sample('equilibre','pression','Sec',180),drift=sample('equilibre','prudente','Sec',180);
// Les gains par course réussie sont des moyennes : on compare les rapports (le recalage de la distance d'une course les déplace ensemble).
assert.ok(wide.metres/wide.advances>close.metres/close.advances*1.1,'Wide play must gain more per successful carry');
T.plusGrand('Wet wide play must cause more handling errors (par course)',T.zProportions(wetWide.handErrors,wetWide.carries,wetClose.handErrors,wetClose.carries));
assert.ok(kicking.kicks>balanced.kicks*1.4,'Occupation must actually kick more');
// « Rush must stop more initial advances » se lit sur la phase de jeu (mêmes joueurs, mêmes tirages, seule la défense change) :
// sur un match entier, la fatigue plus forte de la défense qui monte vite rend l'avance du camp attaquant à peu près égale (z ≈ 1), et l'ancien
// test ne tenait que parce que deux taux voisins se classaient dans le bon sens.
function avanceContre(defence,n=6000){const x=profil('backs','equilibre');x.run(`l.defences=['equilibre','${defence}']`);x.run(`var __ph=JSON.stringify(l),__a=0,__c=0;for(let i=0;i<${n};i++){var __s=(i*2654435761+12345)>>>0;Math.random=()=>{__s=(Math.imul(__s,1664525)+1013904223)>>>0;return __s/4294967296};l=JSON.parse(__ph);l.possession=0;l.territory=40;advanceCausalPlay(l);const s=l.tacticalStats[0];if(s.carries){__c++;if(s.advances)__a++}}`);const result=[x.run('__a'),x.run('__c')];x.close();return result}
{const [aD,cD]=avanceContre('prudente'),[aR,cR]=avanceContre('pression');T.plusGrand('Rush must stop more initial advances (par phase de jeu)',T.zProportions(aD,cD,aR,cR))}
T.plusGrand('A beaten rush must expose longer gains',T.zProportions(rush.longGains,rush.carries,drift.longGains,drift.carries));
T.plusGrand('Rush pressure must carry discipline risk',T.zMoyennes(rush.penaltiesByGame,drift.penaltiesByGame));
T.plusGrand('Rush must consume more fitness',T.zMoyennes(drift.conditionByGame,rush.conditionByGame));
function brief(s){return {games:s.games,advanceRate:+(s.advances/s.carries).toFixed(3),metresPerAdvance:+(s.metres/s.advances).toFixed(2),errorsPerGame:+(s.handErrors/s.games).toFixed(2),kicksPerGame:+(s.kicks/s.games).toFixed(2),pointsPerGame:+(s.points/s.games).toFixed(2),winRate:s.wins/s.games,defenderPenaltiesPerGame:+(s.defenderPenalties/s.games).toFixed(2),defenderFinalCondition:+(s.defenderCondition/s.games).toFixed(2)}}
console.log(JSON.stringify({passed:true,games:640+200,attack:{balanced:brief(balanced),wide:brief(wide),close:brief(close),kicking:brief(kicking),wetWide:brief(wetWide),wetClose:brief(wetClose)},defence:{rush:brief(rush),drift:brief(drift)},checks:['independent attack/defence choices','paused changes only','portable plans and hostile data','frozen action formations','measured halftime advice','legacy match preservation','840 controlled comparisons','gain/error/kick/pressure/penalty/fitness tradeoffs']}));

assert.equal(sim.run('JSON.stringify(S.clubs.filter(c=>!sampleIds.includes(c.id)))'),sim.run('untouched'),'les114autresclubs restent inchangés pendant les840comparaisons');sim.close();
