'use strict';
const fs=require('node:fs'),C=require('./review.cjs'),N=require('./native.cjs'),A=require('./campaign.cjs'),D=require('./depth.cjs'),K=require('./calibration.cjs');
const round=x=>Math.round(x*100)/100;
function run({seeds=64,variants=['baseline','mild','pronounced']}={}){
 if(!Number.isInteger(seeds)||seeds<2||seeds>128)throw Error('Invalid seeds');
 if(!Array.isArray(variants)||variants.length<2||new Set(variants).size!==variants.length||variants.some(v=>!['baseline','mild','pronounced'].includes(v)))throw Error('Invalid variants');
 const master=require('../../modding/data06/rugby-master-2026-2027.json');
 const untouched=JSON.stringify(master),candidate=C.apply(master,require('../../data/scouting/review-v12/candidate.json'));
 const baseline=N.laboratory(candidate),complete=c=>{const s=baseline.sheet(c);return s.lineup.filter(Boolean).length===15&&s.bench.filter(Boolean).length===8};
 const pick=league=>baseline.clubs.filter(c=>c.league===league&&complete(c)).sort((a,b)=>baseline.quality(a)-baseline.quality(b)||a.slug.localeCompare(b.slug));
 const top=pick('top14'),pro=pick('prod2'),refs={promoted:pro.at(-1),topStrong:top.at(-1),topMid:top[Math.floor(top.length/2)],topWeak:top[0],proMid:pro[Math.floor(pro.length/2)]};
 const recruits=N.recruit(refs.promoted,baseline.clubs.filter(c=>c.league==='top14'),5,baseline).moves;
 const departures=N.depart(refs.topWeak,5,baseline).moves;
 if(recruits.length!==5||departures.length!==5)throw Error('Five fixed movements expected');
 const scenarios=['promoted_strong','promoted_mid','promoted_recruited_mid','relegated_keep_mid','relegated_lose5_mid'];
 const reports=[],tierAudits={};
 for(const variant of variants){
  const snapshot=variant==='baseline'?{master:candidate,changes:[],audit:[]}:D.build(candidate,variant);
  const lab=N.laboratory(snapshot.master,'projected',{qualityCoefficient:.008});
  const find=name=>lab.clubs.find(c=>c.slug===refs[name].slug);
  const topDonors=lab.clubs.filter(c=>c.league==='top14'),promoted=find('promoted'),rel=find('topWeak');
  const signed={...promoted,players:[...promoted.players,...recruits.map(m=>topDonors.find(c=>c.slug===m.donor).players.find(p=>p.id===m.playerId))]};
  const lost={...rel,players:rel.players.filter(p=>!departures.some(m=>m.playerId===p.id))};
  const teams={
   promoted_strong:[promoted,find('topStrong')],promoted_mid:[promoted,find('topMid')],
   promoted_recruited_mid:[signed,find('topMid')],
   relegated_keep_mid:[rel,find('proMid')],relegated_lose5_mid:[lost,find('proMid')]
  };
  const inspected=Object.fromEntries(Object.entries({promoted,signed,relegated:rel,lost,strong:find('topStrong'),topMid:find('topMid')}).map(([k,v])=>[k,K.inspect(lab,v)]));
  const summary={};
  for(const name of scenarios){
   const [a,b]=teams[name],s1=lab.sheet(a),s2=lab.sheet(b);
   for(const s of [s1,s2])if(s.lineup.filter(Boolean).length!==15||s.bench.filter(Boolean).length!==8)throw Error('Incomplete 15+8 '+variant+' '+name);
   if(a.players.some(p=>b.players.some(q=>q.id===p.id)))throw Error('Overlapping players');
   const rows=[];for(let i=0;i<seeds;i++)for(const home of [0,1])rows.push({seed:A.seed(i),home,...lab.match(a,b,A.seed(i),{home})});
   summary[name]=A.summarize(rows);
  }
  reports.push({variant,coeff:.008,roster:inspected,rosterDiff:{recruits:K.delta(inspected.promoted,inspected.signed),departures:K.delta(inspected.relegated,inspected.lost)},summary});
  if(variant!=='baseline')tierAudits[variant]={clubs:snapshot.audit,changeCounts:Object.fromEntries(['star','starter','bench','rotation'].map(t=>[t,snapshot.changes.filter(p=>p.tier===t).length])),
    roleAbilityMeanDelta:Object.fromEntries(['star','starter','bench','rotation'].map(t=>{const a=snapshot.changes.filter(p=>p.tier===t);return [t,round(C.mean(a.map(p=>p.newRating-p.oldRating)))];}))};
 }
 if(JSON.stringify(master)!==untouched)throw Error('Master mutated');
 return {schema:'rugby-real-v12-depth-campaign',seeds,matchCount:reports.length*scenarios.length*seeds*2,
    engine:'createRugbyMatch -> advanceRugby -> applyMatchInjuries (harness, no parallel engine)',
    coefficient:.008,selection:Object.fromEntries(Object.entries(refs).map(([k,v])=>[k,v.slug])),
    fixedRecruits:recruits,fixedDepartures:departures,variants:reports,tierAudits,
    limitations:['Every status tier is game-design estimate frozen before the transfers','Incomplete 15+8 clubs excluded in scenario reference','No true two-division senior season or budget/recruitment negotiation','Coefficient .008 experimental harness only','Potential and hidden traits unchanged','Same seeded paired runs, not real promotion probabilities']};
}
if(require.main===module){const out=process.argv[2]||'/tmp/v12-depth.json',n=Number(process.argv[3]||64),report=run({seeds:n});fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({out,matches:report.matchCount,tiers:report.tierAudits,variants:report.variants.map(v=>({variant:v.variant,rosterDiff:v.rosterDiff,results:Object.fromEntries(Object.entries(v.summary).map(([key,s])=>[key,{winPct:s.winPct,margin:s.margin,tries:s.tries,fatigue:s.fatigue,penalties:s.penalties}]))}))}));}
module.exports={run};
