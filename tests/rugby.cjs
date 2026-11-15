const assert=require('node:assert/strict');
const {engineContext:context,matchContext}=require('./harness.cjs');
let t=matchContext(),run=t.run;
assert.equal(run('S.version'),2);assert.equal(run('sheetErrors().length'),0);assert.equal(run('new Set([...S.lineup,...S.reserves]).size'),23);
assert.equal(run('nativePositionAptitudes.project(player(S.lineup[0])).qualifiedFrontRowPositions.includes(1)'),true);assert.equal(run('nativePositionAptitudes.project(player(S.lineup[2])).qualifiedFrontRowPositions.includes(3)'),true);assert.equal(run('nativePositionAptitudes.project(player(S.reserves[0])).qualifiedFrontRowPositions.includes(2)'),true);assert.equal(run('nativePositionAptitudes.project(player(S.reserves[1])).qualifiedFrontRowPositions.includes(1)'),true);assert.equal(run('nativePositionAptitudes.project(player(S.reserves[2])).qualifiedFrontRowPositions.includes(3)'),true);
assert.equal(run('S.clubs.every(c=>c.players.every(p=>Object.keys(p.skills).length===11))'),true);
run('beginMatch();pauseMatch()');assert.equal(run('S.live.minute'),0);run('tick()');assert.equal(run('S.live.minute'),0);
// Non-matchday players cannot enter; tactical returns have their own quota.
run('var l=S.live,side=l.userSide,benchId=l.sheets[side].bench[0],slot=1,oldId=l.sheets[side].on[slot]');
assert.equal(run('makeSub(l,side,slot,club().players.find(p=>![...S.lineup,...S.reserves].includes(p.id)&&p.fam===1)?.id)'),false);
assert.equal(run('makeSub(l,side,slot,benchId)'),true);assert.equal(run('makeSub(l,side,slot,oldId)'),true);assert.equal(run('new Set(l.sheets[side].on).size'),15);
run('continueMatch();fastForward()');assert.ok(run('S.live.minute>=40'));assert.equal(run('atHalftime(S.live)'),true);
run('setLiveTactic("occupation")');assert.equal(run('S.live.tactics[S.live.userSide]'),'occupation');
// Eight distinct bench players may enter; a non-nominated extra cannot enter.
let limits=matchContext();limits.run('beginMatch();pauseMatch();var ls=S.live,ss=ls.sheets[ls.userSide];for(var id of [...ss.bench]){var p=player(id);var slot=ss.on.findIndex((out,i)=>slotEligible(p,i));if(slot>=0)makeSub(ls,ls.userSide,slot,id)}');assert.equal(limits.run('ss.subs'),8);limits.run('var extra=club().players.find(p=>!ss.used.includes(p.id)&&ss.on.some((_,i)=>slotEligible(p,i)));var extraSlot=ss.on.findIndex((_,i)=>slotEligible(extra,i));if(extra)ss.bench.push(extra.id)');assert.ok(limits.run('extra'));assert.equal(limits.run('makeSub(ls,ls.userSide,extraSlot,extra.id)'),false);
// Restore exactly, including live score, bench and individual fatigue.
let before=run('JSON.stringify(S)'),week=run('S.round');const playedBefore=JSON.parse(run('JSON.stringify(S.clubs.map(c=>c.played))'));let loaded=context(JSON.parse(before));assert.equal(loaded.run('JSON.stringify(S)'),before);loaded.run('continueMatch();while(!S.live.finished){if(S.live.paused)continueMatch();else tick()}');assert.ok(loaded.run('S.live.minute>=80'));assert.equal(loaded.run('S.live.flow.period'),2);loaded.run('finishRound()');assert.equal(loaded.run('S.round'),week+1);assert.ok(loaded.run('S.lastReport.analysis.length'));loaded.ctx.playedBefore=playedBefore;loaded.ctx.testWeek=week;assert.equal(loaded.run('S.clubs.every(c=>c.played===playedBefore[c.id]+S.history.filter(r=>r.week===testWeek&&r.phase==="league"&&r.pair.includes(c.id)&&r.competitionId===CDWorldCareer.leagueId(S,c.id)).length)'),true);loaded.close();limits.close();loaded=null;limits=null;
// Invariants and yellow-card return.
run('l.minute=10;l.sheets[side].cards=[{id:l.sheets[side].on[3],until:20}];l.paused=false');assert.equal(run('activePlayers(l,side).length'),14);run('l.minute=19;advanceRugby(l)');assert.equal(run('activePlayers(l,side).length'),15);
// Structural constraints, duplicate selection, and emergency cover.
run('start(13);var originalId=S.lineup[0];chooseSheet(2,originalId)');assert.equal(run('nativePositionAptitudes.project(player(S.lineup[2])).qualifiedFrontRowPositions.includes(3)'),true);run('club().players.filter(p=>p.fam<=1).forEach(p=>p.injury=3);autoLineup()');assert.ok(run('sheetErrors().length')>0);run('promoteCover()');assert.equal(run('sheetErrors().length'),0);
// Ancien format de fichier sur une vraie progression World : aucun mode ancien.
// La semaine et les points proviennent des sept semaines réellement jouées.
{
const migration=context();migration.start(13);migration.deferSaves();migration.week(7);
let legacy=migration.state(),points=legacy.clubs[0].points;
legacy.version=1;legacy.clubs.forEach(c=>c.players.forEach(p=>{delete p.skills;delete p.skillBase}));delete legacy.reserves;
let mig=context(legacy);assert.equal(mig.run('S.round'),7);assert.equal(mig.run('S.clubs[0].points'),points);assert.ok(mig.store['bdt-backup-v1']);assert.equal(mig.run('sheetErrors().length'),0);assert.equal(mig.run('S.worldMode.version'),5);mig.close();mig=null;
migration.toMatch();legacy=migration.state();legacy.version=1;delete legacy.reserves;
legacy.live={pair:migration.run('nextMatch()'),minute:40,score:[12,7],tries:[0,1],events:[{min:40,text:'Mi-temps'}],finished:false,opponentTactic:'large',used:legacy.lineup};
let ml=context(legacy);assert.equal(ml.run('S.live.minute'),40);assert.equal(ml.run('S.live.score.join("-")'),'12-7');assert.equal(ml.run('S.live.paused'),true);assert.equal(ml.run('S.live.engine'),2);assert.equal(ml.run('S.worldMode.version'),5);ml.close();migration.close();
}
// Equal opponents remain competitive and higher skills have a measurable effect.
run('start(0);toMatch()');const cleanExperiment=t.checkpoint();
const restoreExperiment=()=>{const seed=t.seed();t.restore(cleanExperiment);t.setSeed(seed);assert.equal(run('validateCareer(S);true'),true);};
run('var sampleIds=nextMatch().slice();for(const [side,id]of sampleIds.entries())for(const p of S.clubs[id].players){p.rating=p.skillBase=side===0?82:66;p.condition=100;p.injury=0;Object.keys(ATTR).forEach(k=>p.skills[k]=p.rating)}var simulationClubs=Object.fromEntries(sampleIds.map(id=>[id,JSON.stringify(S.clubs[id])])),untouched=JSON.stringify(S.clubs.filter(c=>!sampleIds.includes(c.id)))');let scores=[],wins=0;for(let i=0;i<250;i++){run('for(const id of sampleIds)S.clubs[id]=JSON.parse(simulationClubs[id]);sampleIds.map(id=>S.clubs[id]).forEach(c=>c.players.forEach(p=>{p.condition=100;p.injury=0}))');let r=run('simulate(nextMatch())');scores.push(r.score[0]+r.score[1]);wins+=r.score[0]>r.score[1];assert.ok(r.score.every(n=>Number.isFinite(n)&&n>=0));assert.ok(r.tries.every((n,j)=>n*5<=r.score[j]));assert.equal(r.stats[0].possession+r.stats[1].possession,r.duration);assert.ok(r.stats.every(s=>s.lineoutsWon<=s.lineouts&&s.scrumsWon<=s.scrums));}
assert.equal(run('JSON.stringify(S.clubs.filter(c=>!sampleIds.includes(c.id)))'),run('untouched'),'les114autresclubs restent inchangés sur250matchs');
assert.ok(wins>155,`Strong side wins ${wins}/250`);let avg=scores.reduce((s,n)=>s+n,0)/scores.length;assert.ok(avg>33&&avg<75,`Average ${avg}`);
// Player attributes change actual match outcomes: finishing and endurance.
// Les états sportifs contrôlés ne sont pas des carrières à exporter : restaurer
// le vrai point World avant toute nouvelle création, en conservant le RNG courant.
restoreExperiment();
run('start(0);toMatch();var experiment=createRugbyMatch(nextMatch());experiment.weather="Sec";S.clubs[0].players.forEach(p=>{p.condition=100;p.skills.goal=20;p.skillBase=p.rating});var lowConversions=0;for(var n=0;n<300;n++)scoreTry(experiment,0,"open");lowConversions=experiment.stats[0].conversions');
run('experiment=createRugbyMatch(nextMatch());experiment.weather="Sec";S.clubs[0].players.forEach(p=>p.skills.goal=99);for(var n=0;n<300;n++)scoreTry(experiment,0,"open")');assert.ok(run('experiment.stats[0].conversions-lowConversions')>55,'Better goalkicking must convert more tries');
restoreExperiment();
run('start(0);toMatch();S.clubs[0].players.forEach(p=>{p.skills.stamina=20;p.skillBase=p.rating;p.condition=100});experiment=createRugbyMatch(nextMatch());for(var n=0;n<10;n++)advanceRugby(experiment);var tired=mean(activePlayers(experiment,0).map(p=>p.condition));S.clubs[0].players.forEach(p=>{p.skills.stamina=99;p.condition=100});experiment=createRugbyMatch(nextMatch());for(var n=0;n<10;n++)advanceRugby(experiment)');assert.ok(run('mean(activePlayers(experiment,0).map(p=>p.condition))-tired')>1,'Endurance must preserve condition');
restoreExperiment();
// Deux saisons World complètes : les rencontres régulières et toutes les phases finales utilisent le vrai moteur selon le réglage déclaré.
for(let ci of [0,13]){run(`start(${ci})`);t.deferSaves();const weeks=run('CDWorldCareer.sizing(S).rounds');for(let n=0;n<weeks;n++){if(run('nextMatch()')){run('repairSheet();if(sheetErrors().length)promoteCover();beginMatch();if(!S.live){promoteCover();beginMatch()}');assert.ok(run('S.live'),JSON.stringify(run('({round:S.round,phase:S.phase,errors:sheetErrors(),unique:new Set([...S.lineup,...S.reserves]).size})')));run('while(!S.live.finished){if(S.live.paused)continueMatch();else tick()}')}else run('trainWeek()');run('finishRound()')};assert.equal(run('S.phase'),'ended');assert.equal(run('S.history.length'),run('S.worldMode.fixtures.length'));assert.equal(run('S.clubs.every(c=>c.played===S.worldMode.fixtures.filter(f=>f.phase==="league"&&f.competitionId===CDWorldCareer.leagueId(S,c.id)&&(f.homeId===c.id||f.awayId===c.id)).length)'),true);assert.equal(run('S.clubs.reduce((s,c)=>s+c.pf-c.pa,0)'),0);run('advanceSeason()');assert.equal(run('S.season'),2);assert.equal(run('S.round'),0);assert.equal(run('sheetErrors().length'),0)}
t.close();console.log(JSON.stringify({passed:true,simulationSample:250,averageCombinedScore:avg,strongSideWinRate:wins/250,seasons:2,checks:['23-player eligibility','front-row specialists','substitution limits','tactical re-entry','yellow card expiry','live save restoration','v1 migration incl halftime','training injury cover','same engine AI and live','league and playoffs']}));
