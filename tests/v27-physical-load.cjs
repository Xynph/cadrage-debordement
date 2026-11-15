const assert=require('node:assert/strict');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {engineContext:context,matchContext}=require('./harness.cjs');
const equal=(got,want)=>assert.deepEqual(JSON.parse(JSON.stringify(got)),want);

(()=>{
// A separate persistent workload, with no change to the former rating/condition on load.
const t=context(),run=t.run;
run('start(0)');
assert.equal(run('S.physicalLoadVersion'),1);
run('var picked=club().players.slice(0,3).map(p=>p.id);for(var i=0;i<3;i++){var p=player(picked[i]);p.condition=70;p.physicalLoad={version:1,fatigue:50,plan:["repos","normal","intense"][i]}}');
equal(JSON.parse(run('JSON.stringify(picked.map(id=>physicalTrainingOutcome(player(id),physicalModeFor(player(id),S.club))))')),[{fatigue:30,condition:97},{fatigue:40,condition:86},{fatigue:56,condition:73}]);
assert.equal(run('setPhysicalTraining(picked[0],"nope")'),false);
assert.equal(run('setPhysicalTraining("not-a-player","repos")'),false);
assert.equal(run('setPhysicalTraining(picked[0],"repos")'),true);
run('trainWeek()');
equal(JSON.parse(run('JSON.stringify(picked.map(id=>({fatigue:physicalLoadValue(player(id)),condition:player(id).condition})))')),[{fatigue:30,condition:97},{fatigue:40,condition:86},{fatigue:56,condition:73}]);
const once=run('JSON.stringify(picked.map(id=>player(id)))');
run('trainWeek()');
assert.equal(run('JSON.stringify(picked.map(id=>player(id)))'),once,'Repeated trainWeek cannot grant free recovery or XP');
assert.equal(run('setPhysicalTraining(picked[0],"intense")'),false,'No retroactive choice after the session');
assert.equal(run('physicalPlan(player(picked[0]))'),'repos');
assert.equal(run('physicalLoadPreviewText(player(picked[0]))'),'Séance déjà appliquée');
assert.equal(run('squadTable().includes("Charge de")'),true);
assert.equal(run('tactics().includes("Définissez un mode collectif")'),true);t.close();

})();

(()=>{
// Human/AI pay the same per-minute match-load coefficients; no double application.
const m=matchContext(),match=m.run;
match('var fixture=createRugbyMatch(nextMatch()),ownSide=fixture.pair.indexOf(S.club),otherSide=1-ownSide,otherClub=fixture.pair[otherSide];var own=fixture.sheets[ownSide].initial[0],other=fixture.sheets[otherSide].initial[0];fixture.sheets[ownSide].minutes[own]=80;fixture.sheets[otherSide].minutes[other]=40;var unused=fixture.sheets[ownSide].bench[0];for(const c of S.clubs)for(const p of c.players)ensurePhysicalLoad(p).fatigue=0');
assert.equal(match('fixture.physicalLoadVersion'),1);
assert.equal(match('recordPhysicalMatchLoad(fixture)'),true);
assert.equal(match('physicalLoadValue(player(own))'),18);
assert.equal(match('physicalLoadValue(S.clubs[otherClub].players.find(p=>p.id===other))'),9);
assert.equal(match('physicalLoadValue(player(unused))'),0);
assert.equal(match('recordPhysicalMatchLoad(fixture)'),false);
assert.equal(match('physicalLoadValue(player(own))'),18);
match('var prior=player(own).condition;var oldFixture=createRugbyMatch(nextMatch());delete oldFixture.physicalLoadVersion;oldFixture.sheets[ownSide].minutes[oldFixture.sheets[ownSide].initial[0]]=80;');
assert.equal(match('recordPhysicalMatchLoad(oldFixture)'),false,'A match started under the old physical model is not retrofitted');
assert.equal(match('player(own).condition===prior'),true);

// AI rest is decided by the same fatigue thresholds and recovery function.
m.run('var ai=S.clubs[2].players[0];ai.condition=80;ai.physicalLoad={version:1,fatigue:70,plan:"collective"}');
assert.equal(match('physicalModeFor(ai,2)'),'repos');
match('trainWeek()');
assert.equal(match('physicalLoadValue(ai)'),50);
assert.equal(match('ai.condition'),100);


const exportText=match('JSON.stringify(createSaveDocument())');
assert.equal(match('parseSaveDocument('+JSON.stringify(exportText)+').state.physicalLoadVersion'),1);
const invalid=JSON.parse(exportText);
invalid.state.clubs[0].players.find(p=>p.physicalLoad).physicalLoad.fatigue=101;
invalid.checksum=match('saveChecksum('+JSON.stringify(invalid.state)+')');
assert.throws(()=>match('parseSaveDocument('+JSON.stringify(JSON.stringify(invalid))+')'),'Invalid workload must fail even with a valid checksum');

m.close();

})();

(()=>{
// Eight-round deterministic rotation comparison (our fictional coefficients, not FM27 data).
const series=matchContext(),sr=series.run;
sr('var seasonFixture=createRugbyMatch(nextMatch()),ownSide=seasonFixture.pair.indexOf(S.club);var workId=seasonFixture.sheets[ownSide].initial[0],rotateId=seasonFixture.sheets[ownSide].initial[1]');
for(let round=0;round<8;round++){
 sr('applyPhysicalTraining(player(workId),"normal");applyPhysicalTraining(player(rotateId),'+JSON.stringify(round%2===0?'repos':'normal')+');var loadGame=createRugbyMatch(nextMatch());loadGame.sheets[ownSide].minutes[workId]=80;loadGame.sheets[ownSide].minutes[rotateId]='+String(round%2===0?0:80)+';recordPhysicalMatchLoad(loadGame)');
}
const fullSeries=sr('physicalLoadValue(player(workId))'),rotatedSeries=sr('physicalLoadValue(player(rotateId))');
assert.ok(fullSeries>rotatedSeries,'Giving regular match rest must reduce cumulative load');
assert.ok(fullSeries>=0&&fullSeries<=100&&rotatedSeries>=0&&rotatedSeries<=100);series.close();

})();

(()=>{
// Old exports (including an in-progress match) remain valid; schema migration is forward-only.
const before=context(),legacy=before.run;
before.start(0);before.deferSaves();before.toMatch();legacy('beginMatch()');
const state=JSON.parse(legacy('JSON.stringify(S)'));before.close();
delete state.physicalLoadVersion;delete state.live.physicalLoadVersion;
for(const c of state.clubs)for(const p of c.players)delete p.physicalLoad;
const fitness=state.clubs[0].players.map(p=>p.condition);
const reloaded=context(state);
assert.equal(reloaded.run('S.physicalLoadVersion'),1);
assert.equal(reloaded.run('S.live.physicalLoadVersion'),undefined);
equal(JSON.parse(reloaded.run('JSON.stringify(club().players.map(p=>p.condition))')),fitness);
assert.equal(reloaded.run('createSaveDocument().state.live.physicalLoadVersion'),undefined);reloaded.close();
})();

(()=>{
// At season reset, workload is reset and the selected training policy stays explicit.
const next=context(),nextRun=next.run;
nextRun('start(0);var seasonPlayer=[...club().players].sort((a,b)=>a.age-b.age)[0];var seasonId=seasonPlayer.id;seasonPlayer.contractEnd=S.season+2;seasonPlayer.physicalLoad={version:1,fatigue:88,plan:"repos"};');
next.deferSaves();next.season();nextRun('player(seasonId).physicalLoad.fatigue=88;save()');const reset=next.command('next_season',{confirmed:true});settleClubMeetings(reset,(command,payload)=>next.command(command,payload));
assert.equal(nextRun('physicalLoadValue(player(seasonId))'),0);
assert.equal(nextRun('physicalPlan(player(seasonId))'),'repos');assert.ok(nextRun('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));next.close();
})();
console.log(JSON.stringify({passed:true,cases:['training modes','unique weekly application','planning guard','match minutes','AI recovery','old live saves','validated exports','season rollover']}));
