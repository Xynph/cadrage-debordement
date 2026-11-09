'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {summarize,distribution,markdown,SEEDS,POLICIES}=require('../ci/progression-summary.cjs');
const hash=x=>crypto.createHash('sha256').update(String(x)).digest('hex');
function arm(seed,id){
 const labels=['initial','end-S1','opening-S2','end-S2','opening-S3'],phases=['initial','end','opening','end','opening'],seasons=[1,1,2,2,3];
 const observations=labels.map((label,i)=>{const players=[{id:'player:a',age:20+Math.floor(i/2),rating:50+i,note:49+i,potential:70},{id:'player:b',age:30+Math.floor(i/2),rating:60,note:59,potential:60}];return {label,phase:phases[i],season:seasons[i],week:i%2?46:0,club:{id:0,division:'elite',rank:i?4:1,unresolvedTie:false,leagueSize:14,points:i?40:0,played:i%2?26:0,cash:100+i*10,debt:null,weeklyWages:4000,professionals:2},quality:{rating:{q25:50+i,median:50+i,q75:60},age:{q25:20+Math.floor(i/2),median:20+Math.floor(i/2),q75:30+Math.floor(i/2)},xvMeanNote:i?60:59,sheetValid:true},players,cohortRecords:players.map(p=>({...p,status:'own'}))};});
 return {schema:'progression-multiseed-audit-v1',status:'completed',passed:true,reopened:true,seed,preregisteredSeeds:[...SEEDS],policy:{id,hash:hash('policies'),profile:{id,maxActions:16}},sources:{commit:'a'.repeat(40),digest:hash('engine'),runnerHash:hash('runner'),policiesHash:hash('policies')},initialHash:hash('initial:'+seed),initialProfileHash:hash('private:'+seed),requestedSeasons:2,completedSeasons:2,observations,annual:[1,2].map(season=>({season,openingLabel:season===1?'initial':'opening-S2',closingLabel:'end-S'+season,transitionLabel:'opening-S'+(season+1),results:791,fixtures:791})),financialPeriods:[1,2].map((season,i)=>({season,cashOpening:100+i*20,cashClosing:110+i*20,cashAfterManagement:110+i*20,cashAfterTransition:120+i*20,minCash:100+i*20,negativeWeeks:0,longestNegativeStreak:0,ledgerEntries:3,unexplainedCash:0,categories:{wages:-10,sponsorship:20,gate:0,maintenance:0,victoryBonus:0,financing:10,contractFees:0,transfers:0,investments:0,other:0}})),policySummary:{policy:id,sourceHash:hash('policies'),blocked:false,signed:0,actualFees:0},actions:[{kind:'harness',command:'new_career',ok:true},{kind:'policy',command:'train',ok:true},{kind:'policy',command:'extend_contract',ok:false}],restarts:['end-S1','end-S2','opening-S3'].map(label=>({label,publicExact:true,privateExact:true,stateHash:hash('state:'+label),profileHash:hash('profile:'+label)}))};
}
const matrix=()=>SEEDS.flatMap(seed=>POLICIES.map(id=>arm(seed,id)));
const copy=x=>structuredClone(x);
function freeze(x){if(x&&typeof x==='object'){Object.values(x).forEach(freeze);Object.freeze(x);}return x;}
test('complete fixed matrix remains descriptive, reproducible and nonmutating',()=>{
 const reports=freeze(matrix()),before=JSON.stringify(reports),s=summarize(reports);assert.equal(s.completedPairs,3);assert.equal(s.playedSeasons,2);assert.equal(s.transitions,2);assert.equal(s.interpretation.winnerDeclared,false);assert.equal(s.interpretation.statisticalProof,false);assert.deepEqual(s.preregisteredSeeds,[827381,318,52602]);assert.equal(JSON.stringify(reports),before);assert.equal(JSON.stringify(summarize(reports)),JSON.stringify(s));assert.match(markdown(s),/Aucun vainqueur/);
 assert.equal(s.trajectories[0].actions.policyAccepted,1);assert.equal(s.trajectories[0].actions.policyRefused,1);assert.equal(s.distributions[0].pairedDebtDelta.n,0);assert.equal(s.distributions[0].pairedDebtDelta.median,null);
});
test('missing, duplicated, cherry-picked or incomplete arms are rejected',()=>{
 assert.throws(()=>summarize(matrix().slice(1)),/six/);const dup=matrix();dup[1]=copy(dup[0]);assert.throws(()=>summarize(dup),/duplicate/);
 for(const alter of [r=>r.status='running',r=>r.passed=false,r=>r.seed=42,r=>r.preregisteredSeeds.reverse(),r=>r.observations.pop(),r=>r.annual[1].results--,r=>r.financialPeriods.pop(),r=>r.restarts.pop(),r=>r.restarts[0].privateExact=false,r=>r.observations[1].week=45]){const r=matrix();alter(r[0]);assert.throws(()=>summarize(r));}
});
test('source, method, policy or paired initial-state mismatches never aggregate',()=>{
 for(const alter of [r=>r.sources.digest=hash('other-engine'),r=>r.sources.runnerHash=hash('changed-runner'),r=>r.policy.hash=hash('bad-signature'),r=>r.policy.profile.maxActions=1,r=>r.initialHash=hash('other-state'),r=>r.initialProfileHash=hash('other-private'),r=>r.observations[0].club.cash++]){const r=matrix();alter(r[1]);assert.throws(()=>summarize(r));}
});
test('division change blocks cross-division rank and points conclusions',()=>{
 const r=matrix();r[1].observations[3].club.division='accession';r[1].observations[3].club.leagueSize=16;
 const s=summarize(r),capture=s.pairs[0].captures[3];assert.equal(capture.sport.comparable,false);assert.equal(capture.sport.rankDelta,null);assert.equal(capture.sport.pointsDelta,null);assert.equal(s.distributions[3].sportByDivision[0].rankDelta.n,2,'one incomparable seed is excluded with explicit cohort size');
});
test('unresolved ties do not become resolved rank comparisons',()=>{const r=matrix();r[1].observations[3].club.unresolvedTie=true;const s=summarize(r);assert.equal(s.pairs[0].captures[3].sport.rankComparable,false);assert.equal(s.pairs[0].captures[3].sport.rankDelta,null);assert.equal(s.pairs[0].captures[3].sport.pointsDelta,0);assert.equal(s.distributions[3].sportByDivision[0].rankDelta.n,2);});
test('retained players, entrants and missing former players are separated without zero imputation',()=>{
 const r=matrix(),o=r[1].observations[4];o.players[1]={id:'entrant',age:21,rating:80,note:78,potential:90};o.cohortRecords[1]={id:'player:b',status:'untracked',age:null,rating:null};o.quality.rating={q25:54,median:54,q75:80};o.quality.age={q25:21,median:21,q75:22};
 const s=summarize(r),row=s.trajectories.find(t=>t.seed===SEEDS[0]&&t.policy==='attentive').playerProgress.at(-1),all=row.groups[0];assert.equal(row.entrants,1);assert.equal(all.retained,1);assert.equal(all.leftOwnRoster,1);assert.equal(all.trackedRatingChange.n,1);assert.equal(all.trackedRatingChange.missing,1);assert.equal(all.statusCounts.untracked,1);assert.equal(all.retainedRatingChange.median,4);assert.equal(s.pairs[0].captures.at(-1).pairedInitialCohort[0].pairedObservedRatingDifference.n,1);assert.equal(s.pairs[0].captures.at(-1).pairedInitialCohort[0].onlyMinimalRetained,1);
 const impossible=copy(r);impossible[1].observations[4].cohortRecords[1].rating=0;assert.throws(()=>summarize(impossible),/must stay unknown/);
 const duplicate=matrix();duplicate[0].observations[3].cohortRecords[1].id='player:a';assert.throws(()=>summarize(duplicate),/cohort/);
});
test('financing, unknown debt and unexplained cash do not become operating performance',()=>{
 const s=summarize(matrix());assert.equal(s.interpretation.cashIsProfit,false);assert.equal(s.trajectories[0].financialPeriods[0].categories.financing,10);assert.equal(s.trajectories[0].clubAtCaptures[0].debt,null);
 const inconsistent=matrix();inconsistent[0].financialPeriods[0].unexplainedCash=1;assert.throws(()=>summarize(inconsistent),/conservation/);
 const wrongCount=matrix();wrongCount[0].financialPeriods[0].negativeWeeks=47;assert.throws(()=>summarize(wrongCount),/negative weeks/);
});
test('distributions expose divergence and unknown samples without selecting a winning seed',()=>{
 assert.deepEqual(distribution([-20,5,90]),{n:3,missing:0,values:[-20,5,90],min:-20,median:5,max:90});assert.equal(distribution([null,null,null]).median,null);assert.equal(distribution([null,1,null]).n,1);assert.throws(()=>distribution([undefined]));
});

test('accepted counteroffers do not become signed contracts or actual fees',()=>{
 const r=matrix();r[1].actions.push({kind:'policy',command:'extend_contract',ok:true,negotiation:{status:'counter',fee:1000}});r[1].actions.push({kind:'policy',command:'extend_contract',ok:true,negotiation:{status:'signed',fee:500}});r[1].policySummary.signed=1;r[1].policySummary.actualFees=500;const s=summarize(r),a=s.trajectories[1].actions;assert.equal(a.negotiationCounters,1);assert.equal(a.signedContracts,1);assert.equal(a.signedFees,500);r[1].policySummary.actualFees=1500;assert.throws(()=>summarize(r),/signed outcomes/);
});
test('legitimate sub-micro currency rounding does not falsify financial conservation',()=>{const r=matrix();r[0].financialPeriods[0].unexplainedCash=1e-8;assert.doesNotThrow(()=>summarize(r));r[0].financialPeriods[0].unexplainedCash=0.01;assert.throws(()=>summarize(r),/conservation/);});

test('source nearest-rank quantiles are validated and distinguished from descriptive distribution medians',()=>{const r=matrix();const s=summarize(r);assert.equal(s.trajectories[0].clubAtCaptures[0].quality.sourceRatingQuantiles.p50NearestRank,50);assert.equal(s.trajectories[0].playerProgress[0].ownRosterRating.median,55.5);assert.match(s.interpretation.sourceRosterQuantiles,/nearest-rank/);r[0].observations[1].quality.rating.median=55.5;assert.throws(()=>summarize(r),/quantiles/);});

test('paired roster median uses the standard reading of raw ratings, not the source lower p50',()=>{const r=matrix(),o=r[1].observations[1];o.players[1].rating=66;o.cohortRecords[1].rating=66;o.quality.rating.q75=66;const s=summarize(r);assert.equal(s.pairs[0].captures[1].quality.rosterMedianRatingDelta,3);assert.equal(s.trajectories[0].clubAtCaptures[1].quality.sourceRatingQuantiles.p50NearestRank,51);assert.equal(s.trajectories[1].clubAtCaptures[1].quality.sourceRatingQuantiles.p50NearestRank,51);assert.equal(s.trajectories[1].clubAtCaptures[1].quality.rosterRating.median,58.5);});
test('CLI rejects truncated JSON and prints only a complete six-arm synthesis',()=>{
 const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process'),dir=fs.mkdtempSync(path.join(os.tmpdir(),'progression-summary-'));
 try{const files=matrix().map((r,i)=>{const f=path.join(dir,'arm-'+i+'.json');fs.writeFileSync(f,JSON.stringify(r));return f;}),script=require.resolve('../ci/progression-summary.cjs');
 const good=spawnSync(process.execPath,[script,...files],{encoding:'utf8'});assert.equal(good.status,0,good.stderr);assert.equal(JSON.parse(good.stdout).completedPairs,3);
 const readable=spawnSync(process.execPath,[script,'--markdown',...files],{encoding:'utf8'});assert.equal(readable.status,0);assert.match(readable.stdout,/Aucun vainqueur/);
 fs.writeFileSync(files[3],'{"schema":');const bad=spawnSync(process.execPath,[script,...files],{encoding:'utf8'});assert.equal(bad.status,1);assert.equal(bad.stdout,'');assert.equal(bad.stderr.includes(dir),false);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
