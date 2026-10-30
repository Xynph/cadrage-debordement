const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
let t=context(),run=t.run;
run('start(0);beginMatch();pauseMatch();var l=S.live;l.minute=10;ballPossession(l,0,35)');
assert.equal(run('l.advantageModel'),2);
// After two phases, a genuine gain can close the advantage before the old fixed threshold.
run('offerAdvantage(l,"penalty",0,1,35,{force:true});l.flow.advantage.phases=2;ballPossession(l,0,54);settleAdvantage(l)');
assert.equal(run('l.flow.advantage'),null);
// A small gain remains insufficient and the original mark is preserved.
run('offerAdvantage(l,"penalty",0,1,40,{force:true});ballPossession(l,0,48);l.flow.advantage.phases=1;settleAdvantage(l)');
assert.equal(run('l.flow.advantage.at'),40);
run('returnAdvantage(l)');
assert.equal(run('l.flow.advantage'),null);
// A card changes available player numbers and the effectiveness of wide attack.
t=context();run=t.run;
run('start(0);beginMatch();pauseMatch();var l=S.live;l.tactics[0]="large";var sh=l.sheets[1],p=activePlayers(l,1)[4];giveMatchCard(l,1,p.id,"yellow");var modern=teamEdge(l,0,"attack");l.advantageModel=undefined;var legacy=teamEdge(l,0,"attack")');
assert.ok(Math.abs(run('modern-legacy')-.018)<1e-9);
run('l.advantageModel=2');
assert.equal(run('!!createSaveDocument()'),true);
const saved=run('JSON.parse(JSON.stringify(S))');
assert.equal(context(saved).run('S.live.advantageModel'),2);
// An ongoing old match without V19 marker retains its previous calculations.
delete saved.live.advantageModel;
const old=context(saved);
assert.equal(old.run('S.live.advantageModel'),undefined);
assert.equal(old.run('!!createSaveDocument()'),true);
console.log('V19 advantage and numerical superiority checks passed');
