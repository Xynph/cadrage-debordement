'use strict';
const assert=require('node:assert/strict'),{context}=require('./france-harness.cjs');
for(const phase of ['final','league'])for(const winner of [14,0]){
 const h=context();h.run("start(0,'france');S.morale=70;S.trust=60;S.clubs[14].morale=70;worldClub(0).consecutiveLosses=2;worldClub(14).consecutiveLosses=2;");
 h.ctx.input={pair:[0,14],score:[0,0],tries:[0,0],phase,winner,neutral:true};h.run('var r=input,ai=S.clubs[14],cash=ai.cash,wage=ai.players.reduce((n,p)=>n+p.salary,0),upkeep=worldUpkeep(worldClub(14).facilities);worldWeeklyEconomy([r]);');
 const human=phase==='league'?0:winner===0?1:-1,computer=-human;
 assert.equal(h.run('ai.cash-cash'),h.run('160000-wage-upkeep')+(computer>0?80000:0),'prime IA utilise le vainqueur du départage');
 h.run('var won=CDFranceCareer.recordOwnOutcome(r);financeWeek(null,won);updateOppositionMorale(r);worldRecordResult({...r,franceContext:{phase:r.phase,round:0}});');
 assert.equal(h.run('S.morale'),70+(human>0?6:human<0?-5:1));assert.equal(h.run('S.trust'),60+(human>0?3:human<0?-2:0));
 assert.equal(h.run('S.clubs[14].morale'),70+(computer>0?6:computer<0?-5:1));
 assert.equal(h.run('worldClub(0).consecutiveLosses'),human<0?3:0);assert.equal(h.run('worldClub(14).consecutiveLosses'),computer<0?3:0);
 assert.equal(h.run('S.ledger.filter(x=>x.title.includes("Prime de victoire")).reduce((n,x)=>n+x.amount,0)'),human>0?80000:0);
 assert.equal(h.run('S.economy.moodLog[0].cause'),human>0?'victory':human<0?'loss':'draw');
 assert.ok(h.run('S.news.some(x=>x.startsWith('+JSON.stringify(human>0?'Victoire':human<0?'Défaite':'Match nul')+'))'));
 assert.deepEqual(JSON.parse(h.run('JSON.stringify(r.score)')),[0,0],'score de rugby conservé');
}
console.log('Départages France : primes humain/IA, moral, confiance, défaites et vrais nuls PASS');
