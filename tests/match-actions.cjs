const assert=require('node:assert/strict');const {context}=require('./harness.cjs');
function fixture(){const t=context();t.run('start(0);beginMatch();pauseMatch();var l=S.live;l.paused=false;syncMatchPresentation(l)');return t}
let t=fixture(),run=t.run;
// Every subevent has its own position and roster. The model may already be at
// reception, while the viewer must still see the scoring side at the try line.
run('ballPossession(l,0,91);var begin=l.events.length,p=playback(l);p.running=true;scoreTry(l,0,"open");p.running=false;p.cursor=begin');
assert.equal(run('displayedAction(l).type'),'try');assert.equal(run('matchScene(l).ball.x'),100);assert.equal(run('matchScene(l).team'),0);assert.ok(run('matchCommentary(l).includes(displayedAction(l).text)'));assert.equal(run('matchCommentary(l).includes("effectue le renvoi")'),false);
assert.equal(run('matchScene(l).players.find(p=>p.featured).x'),100);assert.equal(run('matchViewState(l).score[0]'),run('displayedAction(l).scene.score[0]'));
run('presentationTick(l)');assert.equal(run('matchScene(l).kind'),'kickoff');assert.equal(run('matchScene(l).ball.x'),50);assert.equal(run('matchScene(l).team'),1);
run('presentationTick(l)');assert.equal(run('matchScene(l).kind'),'reception');assert.equal(run('matchScene(l).ball.x'),run('l.territory'));assert.equal(run('presentationPending(l)'),false);
// Both directions: lineout setup stays at the restart mark and edge, not at
// the post-contest territory. The next visual then moves to the actual outcome.
for(const side of [0,1]){
 run(`ballPossession(l,${side},50);var n=l.events.length;p=playback(l);p.running=true;resolveTouch(l,${side},${side===0?75:25},{penalty:true});p.running=false;p.cursor=n`);
 assert.equal(run('matchScene(l).kind'),'touch');assert.equal(run('matchScene(l).ball.y'),0);
 run('presentationTick(l)');assert.equal(run('matchScene(l).kind'),'lineout');assert.equal(run('matchScene(l).ball.y'),4);assert.equal(run('matchScene(l).ball.x'),side===0?75:25);assert.equal(run('matchScene(l).team'),side);
 run('while(presentationPending(l))presentationTick(l)');
}
// Named carrying comments use the same actor highlighted by the pitch.
run('Math.random=()=>.5;ballPossession(l,0,40);advanceCausalPlay(l)');assert.equal(run('displayedAction(l).scene.kind'),'carry');assert.equal(run('displayedAction(l).text.includes(matchPlayer(l,0,displayedAction(l).scene.actor).name)'),true);
run('commentaryFilter="highlights"');assert.ok(run('matchCommentary(l).includes(displayedAction(l).text)'));
// Old snapshots still show the pre-card players, subsequent card snapshots do not.
run('var prior=l.events.length-1,id=l.sheets[0].on[3];giveMatchCard(l,0,id);var card=l.events.length-1;playback(l).cursor=prior');assert.equal(run('matchScene(l).players.some(p=>p.id===id)'),true);run('playback(l).cursor=card');assert.equal(run('matchScene(l).players.some(p=>p.id===id)'),false);
// User pauses reconcile to the current engine head before management.
run('playback(l).cursor=prior;pauseMatch()');assert.equal(run('presentationPending(l)'),false);assert.equal(run('l.paused'),true);
// Clicking either team's player pauses play. Only own legal changes are offered.
run('openMatchPlayer(1,l.sheets[1].on[8])');assert.ok(run('modal.includes("Joueur adverse")'));assert.equal(run('modal.includes("pitch-sub")'),false);
run('openMatchPlayer(0,l.sheets[0].on[8]);var replacement=eligibleChanges(l,0,8)[0]');assert.ok(run('modal.includes("pitch-sub")'));run('replaceMatchPlayer(8,replacement.id)');assert.equal(run('l.sheets[0].on[8]'),run('replacement.id'));assert.equal(run('matchScene(l).players.some(p=>p.id===replacement.id)'),true);
// Automatic pause waits for the recorded sequence to finish. It does not
// advance the clock while its remaining comments are still being displayed.
t=fixture();run=t.run;run('pauseOnTry=true;var draws=[.5,.99,0,0,0,.5,0,0,.5,.5];Math.random=()=>draws.shift()??.5;ballPossession(l,0,95);presentationTick(l);var minute=l.minute');assert.equal(run('l.events.some(e=>e.type==="try")'),true);assert.equal(run('l.paused'),false);run('while(presentationPending(l))presentationTick(l)');assert.equal(run('l.paused'),true);assert.equal(run('l.minute'),run('minute'));
t=fixture();run=t.run;run('pauseOnCard=true;Math.random=()=>.01;presentationTick(l);while(presentationPending(l))presentationTick(l)');assert.equal(run('l.events.some(e=>e.scene?.incident)'),true);assert.equal(run('l.paused'),true);
// Reload/export retain structured facts; forged geometry and foreign actors fail.
run('var exported=createSaveDocument()');assert.ok(run('validateCareer(JSON.parse(JSON.stringify(exported.state)))'));for(const mutation of ['scene.to.x=101','scene.actor="foreign-player"','scene.on[0][0]=scene.on[0][1]','scene.kind="invented"']){run('var bad=JSON.parse(JSON.stringify(exported.state));var scene=bad.live.events.find(e=>e.scene).scene');assert.throws(()=>run(mutation+';validateCareer(bad)'))}
const restored=context(run('exported.state'));assert.equal(restored.run('matchScene(S.live).event.text'),run('l.events.at(-1).text'));
console.log(JSON.stringify({passed:true,checks:['try before kickoff and reception','shared pitch and commentary action','both-direction lineout marks','named carrier highlight','current action survives highlights filter','historical roster before card','paused management reconciles to head','player click and legal replacement','automatic pauses at sequence boundary','clock held during playback','scene export/reload and hostile data']}));
