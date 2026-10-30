const assert=require('node:assert/strict');const {context}=require('./harness.cjs');
function fixture(){const t=context();t.run('start(0);beginMatch();pauseMatch();var l=S.live,side=l.userSide,sh=l.sheets[side];Math.random=()=>.99');return t}
function expire(run,minute){run(`l.minute=${minute};sh.cards=sh.cards.filter(c=>c.until>l.minute);resolveFrontExpiries(l,side)`)}
function valid(run){assert.equal(run('!!createSaveDocument()'),true)}
// Every specialist position can receive a card; cover is installed at the next scrum only.
for(const slot of [0,1,2]){
 const t=fixture(),run=t.run;run(`var original=sh.on[${slot}];l.minute=10`);
 assert.equal(run('giveMatchCard(l,side,original)'),true);assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('sh.front.held.length'),0);valid(run);
 run('prepareFrontRows(l)');assert.equal(run(`slotEligible(matchPlayer(l,side,sh.on[${slot}]),${slot})`),true);assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('sh.front.held.length'),1);assert.equal(run('sh.tacticalReturns'),0);valid(run);
 run('var donor=sh.front.held[0],specialist=sh.on['+slot+'];l.paused=false;for(var i=0;i<10;i++)advanceRugby(l)');
 assert.equal(run('l.minute'),20);assert.equal(run(`sh.on[${slot}]===original`),true);assert.equal(run('sh.on[donor.slot]===donor.id'),true);assert.equal(run('activePlayers(l,side).length'),15);assert.equal(run('sh.minutes[original]||0'),0);assert.equal(run('sh.minutes[specialist]'),10);assert.equal(run('sh.minutes[donor.id]||0'),0);valid(run);
}
// A specialist already tactically replaced can cover even with all four returns consumed.
let t=fixture(),run=t.run;
run('var first=sh.on[0],reserve=sh.bench.find(id=>slotEligible(player(id),0));makeSub(l,side,0,reserve);makeSub(l,side,0,first);makeSub(l,side,1,sh.bench.find(id=>slotEligible(player(id),1)));for(var i=0;i<3;i++)makeSub(l,side,1,sh.bench.find(id=>slotEligible(player(id),1)));l.minute=10;giveMatchCard(l,side,first);prepareFrontRows(l)');
assert.equal(run('sh.tacticalReturns'),4);assert.equal(run('sh.on[0]===reserve'),true);valid(run);expire(run,20);assert.equal(run('sh.tacticalReturns'),4);assert.equal(run('activePlayers(l,side).length'),15);valid(run);
// The nominated player cannot come back early during a temporary exclusion, even at another eligible position.
t=fixture();run=t.run;run('sh.on.forEach(id=>player(id).condition=100);var donorId=sh.on[11];player(donorId).condition=12;l.minute=10;giveMatchCard(l,side,sh.on[0]);prepareFrontRows(l)');
assert.equal(run('sh.front.held[0].id===donorId'),true);assert.equal(run('makeSub(l,side,12,donorId)'),false);valid(run);
// Two suspended specialists at the same post: 12 players, uncontested, no shove, turnover or scrum-generated try.
t=fixture();run=t.run;run('var a=sh.on[0];l.minute=10;giveMatchCard(l,side,a);prepareFrontRows(l);var b=sh.on[0];l.minute=12;giveMatchCard(l,side,b);prepareFrontRows(l);l.territory=90;l.possession=side;var score=l.score.join(),won=l.stats[side].scrumsWon;grantSetPiece(l,"scrum",side,l.territory,"knock-on",1-side)');
assert.equal(run('activePlayers(l,side).length'),12);assert.equal(run('sh.front.uncontested'),true);assert.equal(run('l.uncontestedScrums[side]'),1);assert.equal(run('uncontestedParticipants(l,side).length'),8);assert.equal(run('uncontestedParticipants(l,1-side).length'),8);assert.equal(run('new Set(uncontestedParticipants(l,side)).size'),8);assert.equal(run('l.possession'),run('side'));assert.equal(run('l.score.join()'),run('score'));assert.equal(run('l.territory'),90);assert.equal(run('l.stats[side].scrumsWon'),run('won+1'));valid(run);
// Reload/import preserve held players and exclusion clocks; no tactical quota is reset.
const before=run('JSON.parse(JSON.stringify(S))'),loaded=context(before);assert.equal(loaded.run('JSON.stringify(S)'),JSON.stringify(before));
const portable=run('JSON.stringify(createSaveDocument())'),imported=context();imported.run(`pendingSave=parseSaveDocument(${JSON.stringify(portable)});confirmSaveImport()`);assert.equal(imported.run('S.live.sheets[S.live.userSide].front.uncontested'),true);assert.equal(imported.run('activePlayers(S.live,S.live.userSide).length'),12);
expire(run,20);assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('sh.front.uncontested'),false);valid(run);expire(run,22);assert.equal(run('activePlayers(l,side).length'),15);assert.equal(run('sh.front.held.length'),0);valid(run);
// Two 20-minute red cards: 12 before expiry, 13 after the first, 14 after both, since no qualified prop remains.
t=fixture();run=t.run;run('var a=sh.on[0];l.minute=10;giveMatchCard(l,side,a,"red20");prepareFrontRows(l);var b=sh.on[0];l.minute=12;giveMatchCard(l,side,b,"red20");prepareFrontRows(l)');assert.equal(run('activePlayers(l,side).length'),12);valid(run);
expire(run,30);assert.equal(run('activePlayers(l,side).length'),13);valid(run);expire(run,32);assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('sh.front.uncontested'),true);assert.equal(run('sh.redCards.every(c=>c.filled)'),true);assert.equal(run('sh.on.includes(a)||sh.on.includes(b)'),false);valid(run);
// A permanent red retains the reduction; the nominated player may return through an ordinary legal replacement.
t=fixture();run=t.run;run('sh.on.forEach(id=>player(id).condition=100);var a=sh.on[0],donorId=sh.on[11];player(donorId).condition=12;l.minute=10;giveMatchCard(l,side,a,"red");prepareFrontRows(l)');
assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('sh.on[0]!==a'),true);assert.equal(run('makeSub(l,side,12,donorId)'),true);assert.equal(run('sh.tacticalReturns'),1);expire(run,40);assert.equal(run('activePlayers(l,side).length'),14);valid(run);
// If the nominated player already returned elsewhere, an expired red fills the actual vacancy using another eligible player.
t=fixture();run=t.run;run('sh.on.forEach(id=>player(id).condition=100);var a=sh.on[0],donorId=sh.on[11];player(donorId).condition=12;l.minute=10;giveMatchCard(l,side,a,"red20");prepareFrontRows(l);makeSub(l,side,12,donorId)');expire(run,30);assert.equal(run('activePlayers(l,side).length'),15);assert.equal(run('sh.redCards[0].filled'),true);assert.equal(run('sh.on[0]===a'),false);assert.equal(run('sh.tacticalReturns'),1);valid(run);
// Both sides may be affected; a restored qualified row does not force the other side out of uncontested scrums.
t=fixture();run=t.run;run('var other=1-side,os=l.sheets[other];l.minute=10;giveMatchCard(l,side,sh.on[0]);giveMatchCard(l,other,os.on[1]);prepareFrontRows(l)');assert.equal(run('activePlayers(l,side).length'),14);assert.equal(run('activePlayers(l,other).length'),14);valid(run);
// Front-row eligibility and hostile structural changes remain checked even with a recomputed checksum.
const baseline=run('JSON.parse(JSON.stringify(createSaveDocument()))');
for(const mutate of [
 d=>d.state.live.frontRowVersion=99,
 d=>d.state.live.sheets[0].front.held[0].caseIndex=99,
 d=>d.state.live.sheets[0].front.held[0].slot=2,
 d=>d.state.live.sheets[0].front.exclusions[0].id=d.state.live.sheets[0].initial[8],
 d=>d.state.live.sheets[0].front.held[0].id=d.state.live.sheets[0].on[8],
]){const doc=JSON.parse(JSON.stringify(baseline));mutate(doc);assert.throws(()=>run(`var bad=JSON.parse(${JSON.stringify(JSON.stringify(doc))});bad.checksum=saveChecksum(bad.state);parseSaveDocument(JSON.stringify(bad))`))}
// A version-seven fixture is not upgraded partway through a match.
t=fixture();run=t.run;run('delete l.flowVersion;delete l.flow;delete l.playbookVersion;delete l.playbooks;delete l.tacticalVersion;delete l.defences;delete l.tacticalStats;delete l.restartVersion;delete l.restartLog;delete l.kickContext;delete l.firstKickoff;delete l.frontRowVersion;delete l.uncontestedScrums;for(var sheet of l.sheets)delete sheet.front;l.minute=27;l.score=[12,9];var old=JSON.stringify(S)');const legacy=context(run('JSON.parse(old)'));assert.equal(legacy.run('JSON.stringify(S)'),run('old'));assert.equal(legacy.run('giveMatchCard(S.live,S.live.userSide,S.live.sheets[S.live.userSide].on[0])'),false);assert.equal(legacy.run('!!createSaveDocument()'),true);
console.log(JSON.stringify({passed:true,checks:['all three specialist roles','next-scrum timing','ten actual playing minutes','cover outside tactical quota','temporary nominated-player lock','uncontested 8-a-side consequences','12-13-14 red-card matrix','return to contested scrums','nominated player already reused','both teams','reload/import during carence','hostile front-row data','version-seven fixture preserved']}));
