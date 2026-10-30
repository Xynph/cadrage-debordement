const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
function fixture(){const t=context();t.run('start(0);beginMatch();pauseMatch();var l=S.live,side=l.userSide,sh=l.sheets[side]');return t}
let t=fixture(),run=t.run;
assert.equal(run('l.rulesProfile'),'fr-pro-2025');
// Four returns, even if unused bench players remain. An incoming substitute may leave again.
run('var original=sh.on[1],replacement=sh.bench.find(id=>slotEligible(player(id),1));makeSub(l,side,1,replacement)');
for(let n=1;n<=4;n++){assert.equal(run('makeSub(l,side,1,sh.bench.find(id=>slotEligible(player(id),1)))'),true);assert.equal(run('sh.tacticalReturns'),n)}
assert.equal(run('sh.bench.filter(id=>!sh.used.includes(id)).length'),7);
assert.equal(run('makeSub(l,side,1,sh.bench.find(id=>slotEligible(player(id),1)))'),false);
assert.equal(run('sh.subs'),5);assert.equal(run('!!createSaveDocument()'),true);
// Counter and current bench survive reload and portable import without gaining a fifth return.
const snapshot=run('JSON.parse(JSON.stringify(S))'),restored=context(snapshot);
assert.equal(restored.run('S.live.sheets[S.live.userSide].tacticalReturns'),4);
assert.equal(restored.run('makeSub(S.live,S.live.userSide,1,S.live.sheets[S.live.userSide].bench.find(id=>slotEligible(player(id),1)))'),false);
const portable=run('JSON.stringify(createSaveDocument())'),imported=context();
imported.run(`pendingSave=parseSaveDocument(${JSON.stringify(portable)});confirmSaveImport()`);
assert.equal(imported.run('S.live.sheets[S.live.userSide].tacticalReturns'),4);
// All eight initial substitutes plus four returns are legal; total permutations is not capped at eight.
t=fixture();run=t.run;
run('for(var id of [...sh.bench]){var slot=sh.on.findIndex((_,i)=>slotEligible(player(id),i));makeSub(l,side,slot,id)}');
assert.equal(run('sh.subs'),8);for(let n=0;n<4;n++)assert.equal(run('makeSub(l,side,1,sh.bench.find(id=>slotEligible(player(id),1)))'),true);
assert.equal(run('sh.subs'),12);assert.equal(run('!!createSaveDocument()'),true);
// Ten playing minutes of exclusion, not nine; the half-time break consumes no playing time.
t=fixture();run=t.run;
run('l.minute=35;var punished=sh.on[3];giveMatchCard(l,side,punished);var penaltyStart=sh.minutes[punished]||0;l.paused=false');
run('while(l.minute<40)advanceRugby(l);if(!l.paused)endFlowPeriod(l)');assert.equal(run('l.paused'),true);run('advanceRugby(l)');assert.equal(run('l.minute'),40);
run('l.paused=false;while(l.minute<45){l.paused=false;advanceRugby(l)}');
assert.equal(run('sh.minutes[punished]||0'),run('penaltyStart'));assert.equal(run('activePlayers(l,side).some(p=>p.id===punished)'),true);
run('advanceRugby(l)');assert.equal(run('sh.minutes[punished]'),run('penaltyStart+1'));
// Second yellow: player never returns. Team can replace at +20 with a previously used player even after all four returns.
t=fixture();run=t.run;
run('var original=sh.on[1],replacement=sh.bench.find(id=>slotEligible(player(id),1));makeSub(l,side,1,replacement);for(var i=0;i<4;i++)makeSub(l,side,1,sh.bench.find(id=>slotEligible(player(id),1)));var punished=sh.on[3];l.minute=10;giveMatchCard(l,side,punished);l.minute=20;sh.cards=[];giveMatchCard(l,side,punished);var slot=3,candidate=sh.bench.find(id=>slotEligible(player(id),slot));');
assert.equal(run('sh.sentOff.includes(punished)'),true);assert.equal(run('sh.redCards[0].until'),40);
assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('makeSub(l,side,slot,candidate)'),false);
run('l.minute=39');assert.equal(run('makeSub(l,side,slot,candidate)'),false);
run('l.minute=40');assert.equal(run('makeSub(l,side,slot,candidate)'),true);assert.equal(run('sh.tacticalReturns'),4);
assert.equal(run('activePlayers(l,side).length'),15);assert.equal(run('makeSub(l,side,slot,punished)'),false);
assert.equal(run('!!createSaveDocument()'),true);
// Replacing a red card with an already-used player does not use the tactical quota.
t=fixture();run=t.run;
run('var out=sh.on[3],incoming=sh.bench.find(id=>slotEligible(player(id),3));makeSub(l,side,3,incoming);l.minute=12;giveMatchCard(l,side,incoming,"red20");l.minute=32');
assert.equal(run('makeSub(l,side,3,out)'),true);assert.equal(run('sh.tacticalReturns'),0);assert.equal(run('!!createSaveDocument()'),true);
// A permanent red may never be filled, including long after twenty minutes.
t=fixture();run=t.run;run('var punished=sh.on[3];giveMatchCard(l,side,punished,"red");l.minute=70;var candidate=sh.bench.find(id=>slotEligible(player(id),3))');
assert.equal(run('makeSub(l,side,3,candidate)'),false);assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('!!createSaveDocument()'),true);
// AI fills an eligible red-card vacancy irrespective of its tactical substitution pace.
t=fixture();run=t.run;run('var ai=1-side,as=l.sheets[ai],punished=as.on[3];l.minute=5;giveMatchCard(l,ai,punished,"red20");l.minute=24;restoreRedReplacements(l,ai)');
assert.equal(run('as.on[3]'),null);run('l.minute=25;restoreRedReplacements(l,ai)');assert.ok(run('as.on[3]'));assert.equal(run('as.tacticalReturns'),0);assert.equal(run('!!createSaveDocument()'),true);
// Imported counters, nominations, bench/field duplicates, red-card state and unsupported rules cannot bypass validation.
const doc=run('JSON.parse(JSON.stringify(createSaveDocument()))');
for(const change of [
 d=>d.state.live.rulesProfile='future',
 d=>d.state.live.sheets[0].tacticalReturns=5,
 d=>d.state.live.sheets[0].nominated[0]=d.state.live.sheets[0].nominated[1],
 d=>d.state.live.sheets[0].bench[0]=d.state.live.sheets[0].on[0],
 d=>d.state.live.sheets[1].redCards[0].filled=false,
 d=>d.state.live.subs[0].returning=!d.state.live.subs[0].returning,
]){const bad=JSON.parse(JSON.stringify(doc));change(bad);assert.throws(()=>run(`var hostile=JSON.parse(${JSON.stringify(JSON.stringify(bad))});hostile.checksum=saveChecksum(hostile.state);parseSaveDocument(JSON.stringify(hostile))`))}
// Old live snapshots remain under their original rule, with unchanged score, minute and fatigue.
t=fixture();run=t.run;run('delete l.flowVersion;delete l.flow;delete l.playbookVersion;delete l.playbooks;delete l.tacticalVersion;delete l.defences;delete l.tacticalStats;delete l.restartVersion;delete l.restartLog;delete l.kickContext;delete l.firstKickoff;delete l.rulesProfile;for(var sh of l.sheets){delete sh.nominated;delete sh.tacticalReturns;delete sh.redCards}l.minute=27;l.score=[10,7];var before=JSON.stringify(S)');
const legacy=context(run('JSON.parse(before)'));assert.equal(legacy.run('JSON.stringify(S)'),run('before'));
legacy.run('var l=S.live,sh=l.sheets[l.userSide],old=sh.on[1],incoming=sh.bench[0];makeSub(l,l.userSide,1,incoming)');
assert.equal(legacy.run('makeSub(l,l.userSide,1,old)'),false);assert.equal(legacy.run('!!createSaveDocument()'),true);
console.log(JSON.stringify({passed:true,checks:['four returns independent of unused bench','twelve tactical changes','quota reload/import','ten actual playing minutes and halftime','second yellow and twenty-minute boundary','red replacement outside tactical quota','permanent red','AI restoration','hostile rule snapshots','legacy live fixture preservation']}));
