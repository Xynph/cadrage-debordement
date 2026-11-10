'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./native-reference-harness.cjs');
test('a complete fictional season uses actual training, human and AI matches and one annual review',()=>{
 const h=context({seed:917});h.run('start(0,"fiction");');
 let cycles=0;
 while(h.run('S.phase!=="ended"')&&cycles++<40){
  h.run(`autoLineup();trainWeek();if(sheetErrors().length)promoteCover();if(nextMatch()){beginMatch();if(!S.live)throw Error('No match '+S.round+' '+JSON.stringify(sheetErrors()));for(var i=0;!S.live.finished&&i<180;i++){S.live.paused=false;advanceRugby(S.live);}if(!S.live.finished)throw Error('Match unfinished');}finishRound();`);
 }
 assert.equal(h.run('S.phase'), 'ended');assert.ok(cycles>=26);
 assert.ok(h.run('S.potentialEvolution.records.flat().some(r=>r[7]>=8)'), 'real appearances accumulated');
 const seed=h.randomState();h.run('var seasonBefore=S.season;advanceSeason();validateCareer(S);');
 assert.equal(h.run('S.season'),2);
 assert.ok(h.run('S.potentialEvolution.records.flat().some(r=>r[12]===1)'), 'annual hook reviews existing evidence');
 assert.ok(h.run('S.clubs.every(c=>c.players.every(p=>p.dev.potential>=p.rating&&p.dev.potential<=99))'));
 assert.ok(h.randomState().calls>seed.calls,'normal new-season intake still has its original RNG');
 const before=h.run('JSON.stringify(S.potentialEvolution)');h.run('for(const c of S.clubs)for(const p of c.players)nativePotentialEvolution.project(S,p.id);');
 assert.equal(h.run('JSON.stringify(S.potentialEvolution)'),before,'read-only public trends');
 if(process.env.CD_POTENTIAL_SEASON_EXPORT)require('node:fs').writeFileSync(process.env.CD_POTENTIAL_SEASON_EXPORT,h.run('JSON.stringify(createSaveDocument())'));
 console.log('Complete season:',cycles,'rounds; annual development reviewed');
});
test('real yellow and red front-row cards keep the individual sanction after the player leaves the field',()=>{
 const h=context({seed:917});h.run('start(0,"fiction");beginMatch();var originalMatchState=JSON.stringify(S);');
 for(const kind of ['yellow','red20','red']){
  h.run(`S=JSON.parse(originalMatchState);var live=S.live,side=live.userSide,actor=live.sheets[side].on[0];giveMatchCard(live,side,actor,'${kind}');`);
  assert.equal(h.run('live.sheets[side].on.includes(actor)'),false);
  assert.equal(h.run('live.potentialEvidence.rows.find(r=>r[0]===actor)[2]'),-1.5);
  h.run('prepareFrontRows(live);validateCareer(S);');
 }
});
