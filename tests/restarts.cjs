const assert=require('node:assert/strict');const {context}=require('./harness.cjs');
function fixture(){const t=context();t.run('start(0);beginMatch();pauseMatch();var l=S.live;delete l.flowVersion;delete l.flow;Math.random=()=>.99');return t}
function valid(run){assert.equal(run('!!createSaveDocument()'),true)}
let t=fixture(),run=t.run;
assert.equal(run('l.restartVersion'),1);assert.equal(run('l.restartLog[0].cause'),'start');assert.equal(run('l.restartLog[0].team'),run('l.firstKickoff'));
// A set piece cannot materialize without a cause, nor benefit the offending team.
run('var before=JSON.stringify(l)');assert.equal(run('contestSetPiece(l,0,"scrum")'),false);assert.equal(run('JSON.stringify(l)'),run('before'));
assert.equal(run('grantSetPiece(l,"scrum",0,40,"unknown",1)'),false);assert.equal(run('grantSetPiece(l,"scrum",0,40,"knock-on",0)'),false);assert.equal(run('JSON.stringify(l)'),run('before'));
for(const side of [0,1]){
 // Involuntary hand offences award the opposing introduction at the nearest legal mark.
 run(`ballPossession(l,${side},${side===0?99:1});handFault(l,${side})`);
 assert.equal(run('l.restartLog.at(-1).kind'),'scrum');assert.equal(run('l.restartLog.at(-1).team'),1-side);assert.equal(run('l.restartLog.at(-1).at'),side===0?95:5);valid(run);
 run(`ballPossession(l,${side},48);handFault(l,${side},true)`);assert.equal(run('l.restartLog.at(-1).cause'),'forward-pass');
 // Penalty touch keeps the throw; carrying the ball out never does.
 run(`ballPossession(l,${side},50);resolveTouch(l,${side},${side===0?75:25},{penalty:true,direct:true})`);
 assert.equal(run('l.restartLog.at(-1).cause'),'penalty-touch');assert.equal(run('l.restartLog.at(-1).team'),side);valid(run);
 run(`ballPossession(l,${side},60);resolveTouch(l,${side},60,{carried:true})`);assert.equal(run('l.restartLog.at(-1).team'),1-side);
 // Direct touch outside the 22, or after bringing the ball back, gives no territorial gain.
 run(`ballPossession(l,${side},${side===0?30:70});resolveTouch(l,${side},${side===0?65:35},{direct:true})`);assert.equal(run('l.restartLog.at(-1).at'),side===0?30:70);
 run(`ballPossession(l,${side},${side===0?15:85});l.kickContext.twentyTwoEligible=false;resolveTouch(l,${side},${side===0?55:45},{direct:true})`);assert.equal(run('l.restartLog.at(-1).at'),side===0?15:85);
 run(`ballPossession(l,${side},${side===0?15:85});resolveTouch(l,${side},${side===0?55:45},{direct:true})`);assert.equal(run('l.restartLog.at(-1).at'),side===0?55:45);assert.equal(run('l.restartLog.at(-1).team'),1-side);
 // A legal 50:22 retains the throw. Direct kicks or a brought-back ball do not qualify.
 run(`ballPossession(l,${side},${side===0?40:60});resolveTouch(l,${side},${side===0?85:15})`);assert.equal(run('l.restartLog.at(-1).cause'),'50-22');assert.equal(run('l.restartLog.at(-1).team'),side);valid(run);
 run(`ballPossession(l,${side},${side===0?40:60});l.kickContext.halfEligible=false;resolveTouch(l,${side},${side===0?85:15})`);assert.equal(run('l.restartLog.at(-1).cause'),'indirect-touch');assert.equal(run('l.restartLog.at(-1).team'),1-side);
 // Held-up attackers / attacking knock-ons in goal restart from the defending try line.
 for(const scenario of ['held-up','ingoal-knock-on','attacking-kick-grounded']){
  run(`ballPossession(l,${side},${side===0?95:5});resolveInGoal(l,${side},${JSON.stringify(scenario)})`);assert.equal(run('l.restartLog.at(-1).kind'),'goalLine');assert.equal(run('l.restartLog.at(-1).team'),1-side);assert.equal(run('l.restartLog.at(-1).at'),side===0?100:0);valid(run);
 }
 // A defender taking the ball into their own in-goal gives the attack a five-metre scrum.
 run(`ballPossession(l,${side},${side===0?1:99});resolveInGoal(l,${side},"defender-grounded")`);assert.equal(run('l.restartLog.at(-1).kind'),'scrum');assert.equal(run('l.restartLog.at(-1).at'),side===0?5:95);assert.equal(run('l.restartLog.at(-1).team'),1-side);
 // A kick through in-goal offers a return scrum or 22 drop-out; the chosen options are legal.
 run(`ballPossession(l,${side},50);resolveInGoal(l,${side},"kick-dead",50)`);assert.equal(run('l.restartLog.at(-1).cause'),'kick-dead-option');assert.equal(run('l.restartLog.at(-1).at'),50);
 run(`ballPossession(l,${side},${side===0?90:10});resolveInGoal(l,${side},"kick-dead",${side===0?90:10})`);assert.equal(run('l.restartLog.at(-1).kind'),'drop22');
}
// After a try or successful penalty, it is the team conceding the points that kicks off.
t=fixture();run=t.run;run('l.minute=10;ballPossession(l,0,95);scoreTry(l,0,"open")');assert.equal(run('l.restartLog.at(-1).cause'),'score');assert.equal(run('l.restartLog.at(-1).team'),1);assert.equal(run('l.restartLog.at(-1).at'),50);valid(run);
run('ballPossession(l,1,20);l.penaltyPolicies[1]="points";Math.random=()=>0;awardPenalty(l,1)');assert.equal(run('l.restartLog.at(-1).team'),0);assert.equal(run('l.restartLog.at(-1).cause'),'score');valid(run);
// Missed penalties: dead gives 22; touch gives defensive throw; a live rebound stays in play.
for(const [random,expected] of [[.1,'drop22'],[.7,'lineout'],[.99,null]]){
 run(`Math.random=()=>${random};ballPossession(l,0,65);var count=l.restartLog.length;missedGoal(l,0)`);
 if(expected){assert.equal(run('l.restartLog.at(-1).kind'),expected);assert.equal(run('l.restartLog.at(-1).team'),1)}else{assert.equal(run('l.restartLog.length'),run('count'));assert.equal(run('l.possession'),1);assert.notEqual(run('l.territory'),50)}valid(run);
}
// Restarts and kick eligibility survive exact reload and portable import.
const before=run('JSON.parse(JSON.stringify(S))'),loaded=context(before);assert.equal(loaded.run('JSON.stringify(S)'),JSON.stringify(before));const portable=run('JSON.stringify(createSaveDocument())'),imported=context();imported.run(`pendingSave=parseSaveDocument(${JSON.stringify(portable)});confirmSaveImport()`);assert.equal(imported.run('S.live.restartLog.length'),run('l.restartLog.length'));
// The second-half kicker is opposite to the first-half kicker.
t=fixture();run=t.run;run('l.minute=40;l.halftime=true;l.paused=false;advanceRugby(l)');assert.equal(run('l.restartLog.find(r=>r.cause==="second-half").team'),run('1-l.firstKickoff'));valid(run);
// Hostile facts and unsupported restart versions are rejected even with a recalculated checksum.
const doc=run('JSON.parse(JSON.stringify(createSaveDocument()))');
for(const change of [d=>d.state.live.restartVersion=99,d=>d.state.live.kickContext.team=1-d.state.live.possession,d=>d.state.live.restartLog[0].team=1-d.state.live.restartLog[0].team,d=>d.state.live.restartLog[0].at=22,d=>d.state.live.restartLog[0].cause='invented']){const bad=JSON.parse(JSON.stringify(doc));change(bad);assert.throws(()=>run(`var bad=JSON.parse(${JSON.stringify(JSON.stringify(bad))});bad.checksum=saveChecksum(bad.state);parseSaveDocument(JSON.stringify(bad))`))}
// Version-eight fixtures remain under their existing phase behavior without mid-match migration.
t=fixture();run=t.run;run('delete l.playbookVersion;delete l.playbooks;delete l.tacticalVersion;delete l.defences;delete l.tacticalStats;delete l.numericalAiVersion;l.managerMemory?.forEach(m=>{delete m.lastCardDiff;delete m.cardBase});delete l.restartVersion;delete l.restartLog;delete l.firstKickoff;delete l.kickContext;l.minute=27;l.score=[10,7];var before=JSON.stringify(S)');const old=context(run('JSON.parse(before)'));assert.equal(old.run('JSON.stringify(S)'),run('before'));assert.equal(old.run('!!createSaveDocument()'),true);
console.log(JSON.stringify({passed:true,checks:['causal set-piece gate','opposing scrum introduction','penalty versus carrying touch','direct touch and brought-back ball','50:22 conditions both directions','in-goal restarts','dead-kick options','score kick-off team','missed-goal outcomes','second-half kick-off','reload/import','hostile restart facts','version-eight fixture preserved']}));
