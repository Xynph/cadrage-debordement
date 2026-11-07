'use strict';
// Offline calibration only: native match engine, unchanged team data and fixtures.
const fs=require('node:fs');
const C=require('./review.cjs'),N=require('./native.cjs'),A=require('./campaign.cjs');
function mean(a){return a.reduce((s,v)=>s+v,0)/a.length;}
function inspect(lab,club){const sh=lab.sheet(club);if(sh.lineup.filter(Boolean).length!==15||sh.bench.filter(Boolean).length!==8)throw Error('Incomplete 15+8: '+club.slug);
const idx=new Map(club.players.map(p=>[p.id,p]));
return {lineup:sh.lineup.map(id=>({id,role:idx.get(id).pos,note:lab.note(idx.get(id))})),bench:sh.bench.map(id=>({id,role:idx.get(id).pos,note:lab.note(idx.get(id))})),
startingMean:mean(sh.lineup.map(id=>lab.note(idx.get(id)))),benchMean:mean(sh.bench.map(id=>lab.note(idx.get(id))))};}
function delta(before,after){const initial=new Map(before.lineup.map(x=>[x.role,(before.lineup.filter(y=>y.role===x.role)).map(y=>y.note)]));
return {startingMeanChange:Math.round((after.startingMean-before.startingMean)*100)/100,benchMeanChange:Math.round((after.benchMean-before.benchMean)*100)/100,
retainedStarters:after.lineup.filter(x=>before.lineup.some(y=>y.id===x.id)).length,
replacementStarters:after.lineup.filter(x=>!before.lineup.some(y=>y.id===x.id)).map(x=>({id:x.id,role:x.role,note:x.note})),
leftBench:after.bench.filter(x=>!before.bench.some(y=>y.id===x.id)).map(x=>({id:x.id,role:x.role,note:x.note}))};}
function run({seeds=64}={}){
if(!Number.isInteger(seeds)||seeds<2||seeds>128)throw Error('Invalid seeds');
const master=require('../../modding/data06/rugby-master-2026-2027.json');
const proposed=C.apply(master,require('../../data/scouting/review-v12/candidate.json'));
const reference=N.laboratory(proposed),select=(league)=>reference.clubs.filter(c=>c.league===league).filter(c=>{let s=reference.sheet(c);return s.lineup.filter(Boolean).length===15&&s.bench.filter(Boolean).length===8}).sort((a,b)=>reference.quality(a)-reference.quality(b)||a.slug.localeCompare(b.slug));
const top=select('top14'),pro=select('prod2'),strong=top.at(-1),middle=top[Math.floor(top.length/2)],weak=top[0],promoted=pro.at(-1),proMiddle=pro[Math.floor(pro.length/2)];
const incoming=N.recruit(promoted,reference.clubs.filter(c=>c.league==='top14'),5,reference);
const leaving=N.depart(weak,5,reference);
if(incoming.moves.length!==5||leaving.moves.length!==5)throw Error('Movement count differs from requested five');
const build=(lab)=>{const find=slug=>lab.clubs.find(c=>c.slug===slug);
const base=find(promoted.slug),lostBase=find(weak.slug),topDonors=lab.clubs.filter(c=>c.league==='top14');
const joined={...base,players:[...base.players,...incoming.moves.map(m=>topDonors.find(c=>c.slug===m.donor).players.find(p=>p.id===m.playerId))]};
const lost={...lostBase,players:lostBase.players.filter(p=>!leaving.moves.some(m=>m.playerId===p.id))};
return {promoted:base,joined,topStrong:find(strong.slug),topMid:find(middle.slug),topWeak:lostBase,proMid:find(proMiddle.slug),lost};};
const ref=build(reference),before={promoted:inspect(reference,ref.promoted),joined:inspect(reference,ref.joined),topStrong:inspect(reference,ref.topStrong),topMid:inspect(reference,ref.topMid),topWeak:inspect(reference,ref.topWeak),proMid:inspect(reference,ref.proMid),lost:inspect(reference,ref.lost)};
const variants=[];
for(const coefficient of [.004,.008,.012]){
const lab=N.laboratory(proposed,'projected',{qualityCoefficient:coefficient}),club=build(lab);
const scenarios={promoted_strong:[club.promoted,club.topStrong],promoted_mid:[club.promoted,club.topMid],promoted_recruited_mid:[club.joined,club.topMid],relegated_keep_mid:[club.topWeak,club.proMid],relegated_lose5_mid:[club.lost,club.proMid]};
const results={};
for(const [name,[a,b]] of Object.entries(scenarios)){
inspect(lab,a);inspect(lab,b);
const rows=[];for(let i=0;i<seeds;i++)for(const home of [0,1]){const r=lab.match(a,b,A.seed(i),{home});rows.push({seed:A.seed(i),home,...r});}
results[name]=A.summarize(rows);
}
variants.push({coefficient,scenarios:results});
}
return {schema:'rugby-real-v12-calibration',source:'real createRugbyMatch/advanceRugby/applyMatchInjuries; tacticalEdge override in isolated harness only',seeds,matchCount:variants.length*5*seeds*2,
selection:{promoted:promoted.slug,topStrong:strong.slug,topMid:middle.slug,topWeak:weak.slug,proMid:proMiddle.slug,incoming:incoming.moves,leaving:leaving.moves},
rosters:before,change:{recruited:delta(before.promoted,before.joined),departures:delta(before.topWeak,before.lost)},variants};
}
if(require.main===module){const out=process.argv[2]||'/tmp/v12-calibration.json',seeds=Number(process.argv[3]||64);const report=run({seeds});fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({out,matchCount:report.matchCount,change:report.change,variants:report.variants.map(v=>({coefficient:v.coefficient,results:Object.fromEntries(Object.entries(v.scenarios).map(([k,x])=>[k,{winPct:x.winPct,margin:x.margin,tries:x.tries,fatigue:x.fatigue}]))}))}));}
module.exports={run,inspect,delta};
