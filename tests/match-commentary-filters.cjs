'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const g=context();
g.run('start(0);beginMatch();pauseMatch()');
const before=g.run('JSON.stringify(S)');
const rng=context();
rng.run('start(0);beginMatch();pauseMatch()');
for(const filter of ['all','highlights','scores','discipline']){
 assert.equal(g.run(`setCommentaryFilter('${filter}')`),true);
 assert.equal(g.run('commentaryFilter'),filter);
 assert.match(g.run('matchCommentary(S.live)'),/Commentaires du match/);
}
assert.equal(g.run("setCommentaryFilter('bogus')"),false);
assert.equal(g.run('commentaryFilter'),'discipline');
assert.equal(g.run('JSON.stringify(S)'),before,'filter is presentation-only');
assert.equal(g.run('Math.random()'),rng.run('Math.random()'),'filter must not consume RNG');
assert.equal(g.run("commentaryVisible({type:'try'},null,'scores')"),true);
assert.equal(g.run("commentaryVisible({type:'penalty'},null,'scores')"),false);
assert.equal(g.run("commentaryVisible({type:'card'},null,'discipline')"),true);
assert.equal(g.run("commentaryVisible({type:'goal'},null,'discipline')"),false);
assert.equal(g.run("commentaryVisible({type:'play'},null,'highlights')"),false);
assert.equal(g.run("commentaryVisible({type:'play'},null,'all')"),true);
g.run('var highlighted={type:"play"}');
assert.equal(g.run("commentaryVisible(highlighted,highlighted,'scores')"),true,'currently displayed action never disappears');
console.log('MATCH COMMENTARY FILTERS PASS: score, discipline, current action, no save/RNG mutation');
