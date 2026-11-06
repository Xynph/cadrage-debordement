'use strict';
const fs=require('node:fs'),path=require('node:path');
const C=require('./calibration.cjs'),N=require('./native.cjs');
const ROOT=path.resolve(__dirname,'../..');
const MASTER=path.join(ROOT,'modding/data06/rugby-master-2026-2027.json');
function seed(i){return parseInt(C.hash('CD-V11-holdout-'+i).slice(0,8),16);}
function interval(w,n){const z=1.96,p=w/n,d=1+z*z/n,c=(p+z*z/(2*n))/d,e=z*Math.sqrt(p*(1-p)/n+z*z/(4*n*n))/d;return [C.round(100*(c-e)),C.round(100*(c+e))];}
function clusterInterval(rows){
 const groups=new Map();for(const r of rows){if(!groups.has(r.seed))groups.set(r.seed,[]);groups.get(r.seed).push(Number(r.score[0]>r.score[1]));}
 const values=[...groups.values()].map(a=>C.mean(a)),n=values.length,p=C.mean(values);if(n<2)throw Error('At least two seed clusters required');
 const variance=values.reduce((s,x)=>s+(x-p)**2,0)/(n-1),e=1.96*Math.sqrt(variance/n);return [C.round(100*Math.max(0,p-e)),C.round(100*Math.min(1,p+e))];
}
function summarize(rows){
 const n=rows.length,wins=rows.filter(r=>r.score[0]>r.score[1]).length,draws=rows.filter(r=>r.score[0]===r.score[1]).length;
 const avg=f=>C.round(C.mean(rows.map(f)));
 return {matches:n,wins,draws,winPct:C.round(wins/n*100),winIntervalMethod:'seed-cluster normal 95%, clipped 0-100; exploratory sample',win95:clusterInterval(rows),drawPct:C.round(draws/n*100),margin:avg(r=>r.score[0]-r.score[1]),
  score:[avg(r=>r.score[0]),avg(r=>r.score[1])],tries:[avg(r=>r.tries[0]),avg(r=>r.tries[1])],
  penalties:[avg(r=>r.stats[0].penalties),avg(r=>r.stats[1].penalties)],yellows:[avg(r=>r.stats[0].yellows),avg(r=>r.stats[1].yellows)],reds:[avg(r=>r.reds[0]),avg(r=>r.reds[1])],
  fatigue:[avg(r=>r.conditionLoss[0]),avg(r=>r.conditionLoss[1])],injuries:[avg(r=>r.injuries[0]),avg(r=>r.injuries[1])],
  metres:[avg(r=>r.tacticalStats[0].metres),avg(r=>r.tacticalStats[1].metres)],duration:avg(r=>r.duration)};
}
function campaign({seeds=64,out=null,progress=()=>{},onlyVersion=null}={}){
 if(!Number.isInteger(seeds)||seeds<2||seeds>300)throw Error('Invalid seed count');
 const bytes=fs.readFileSync(MASTER),master=JSON.parse(bytes),candidate=C.consolidate(master),proposed=C.apply(master,candidate);
 const versions={legacy:{master,mode:'legacy',label:'11 historical master skills; offline input, NOT current LNR runtime'},baseline:{master,mode:'projected',label:'36 baseline attributes through candidate projection'},candidate:{master:proposed,mode:'projected',label:'36 consolidated attributes through same candidate projection'}};
 const reference=N.laboratory(master),rank=lg=>reference.clubs.filter(c=>c.league===lg).map(c=>({slug:c.slug,q:reference.quality(c)})).sort((a,b)=>a.q-b.q||a.slug.localeCompare(b.slug));
 versions.responseCandidate={master:proposed,mode:'projected',qualityCoefficient:.008,label:'Same consolidated inputs; isolated x2 native tacticalEdge skill differential proposal'};
 const t=rank('top14'),p=rank('prod2'),pick={topWeak:t[0].slug,topMid:t[Math.floor(t.length/2)].slug,topPeer:t[Math.floor(t.length/2)-1].slug,topStrong:t.at(-1).slug,proWeak:p[0].slug,proMid:p[Math.floor(p.length/2)].slug,proPeer:p[Math.floor(p.length/2)-1].slug,proBest:p.at(-1).slug};
 const referenceRecruitment=N.recruit(reference.clubs.find(c=>c.slug===pick.proBest),reference.clubs.filter(c=>c.league==='top14'),5,reference);
 const referenceDeparture=N.depart(reference.clubs.find(c=>c.slug===pick.topWeak),5,reference);
 const report={schema:'rugby-real-v11-native-campaign',sourceBase:'3014774ab4ca13d1d325756ed89f2bb029b1b99c',masterSha256:C.hash(bytes.toString()),node:process.version,
  method:'Unmodified createRugbyMatch -> advanceRugby -> applyMatchInjuries, tests/harness.cjs. Both AI classic, morale 75, fresh condition 100 except stated fatigue scenario. Same independent seeds, both home/away at every seed. No league bonus.',
  seeds:Array.from({length:seeds},(_,i)=>seed(i)),referenceRanking:{top14:t,prod2:p},selected:pick,candidate:candidate.summary,roleAudit:candidate.roleAudit,versions:{},totalMatches:0,
  limitations:['Offline controlled rosters; no 2-division senior career exists on main','Champion and relegated labels are roster-quality proxies, not historical champions or natural relegations','No native salary/fee claim for controlled recruits; all salaries held neutral at 5000','Position certainty still limited by master estimated roles','Hidden traits and potential retained; not newly wired into match engine','Win and paired-margin intervals are clustered by seed; exploratory design goals are not historical frequencies']};
 for(const [version,config] of Object.entries(versions)){
  if(onlyVersion&&onlyVersion!==version)continue;
  const lab=N.laboratory(config.master,config.mode,{qualityCoefficient:config.qualityCoefficient||.004}),club=slug=>lab.clubs.find(c=>c.slug===slug),top=lab.clubs.filter(c=>c.league==='top14');
  const base=club(pick.proBest),rel=club(pick.topWeak);
  const recruits={moves:referenceRecruitment.moves,club:{...base,players:[...base.players,...referenceRecruitment.moves.map(m=>top.find(c=>c.slug===m.donor).players.find(p=>p.id===m.playerId))]}};
  const lost={moves:referenceDeparture.moves,club:{...rel,players:rel.players.filter(p=>!referenceDeparture.moves.some(m=>m.playerId===p.id))}};
  const recruited=n=>({...base,players:[...base.players,...recruits.moves.slice(0,n).map(m=>recruits.club.players.find(p=>p.id===m.playerId))]});
  const scenarios={top14_peer:[club(pick.topMid),club(pick.topPeer)],prod2_peer:[club(pick.proMid),club(pick.proPeer)],
   prod2_mid_top14_mid:[club(pick.proMid),club(pick.topMid)],promoted0_weak:[base,club(pick.topWeak)],promoted0_mid:[base,club(pick.topMid)],promoted0_strong:[base,club(pick.topStrong)],
   relegated_keep_weak:[rel,club(pick.proWeak)],relegated_keep_mid:[rel,club(pick.proMid)],relegated_keep_best:[rel,base],
   promoted2_mid:[recruited(2),club(pick.topMid)],promoted3_mid:[recruited(3),club(pick.topMid)],promoted5_mid:[recruited(5),club(pick.topMid)],relegated_lose5_mid:[lost.club,club(pick.proMid)]};
  if(version==='candidate'||version==='responseCandidate'){
   scenarios.promoted_tired_mid=[base,club(pick.topMid),{condition:70}];
   for(const tactic of ['equilibre','conquete','large','occupation'])scenarios['promoted_'+tactic+'_mid']=[base,club(pick.topMid),{tactic}];
   for(const defence of ['pression','prudente'])scenarios['promoted_defence_'+defence]=[base,club(pick.topMid),{defence}];
  }
  const results={};
  for(const [name,[a,b,options={}]] of Object.entries(scenarios)){
   const rows=[];for(let i=0;i<seeds;i++)for(const home of [0,1]){
    const r=lab.match(a,b,seed(i),{...options,home});
    rows.push({seed:seed(i),home,...r});
   }
   results[name]={teams:[a.slug,b.slug],options,summary:summarize(rows),rows};report.totalMatches+=rows.length;progress({version,scenario:name,...results[name].summary});
  }
  report.versions[version]={label:config.label,recruits:recruits.moves,lost:lost.moves,results};
 }
 function comparison(a,b){return Object.fromEntries(Object.keys(a||{}).map(k=>{
  const margin=b[k].rows.map((r,i)=>r.score[0]-r.score[1]-(a[k].rows[i].score[0]-a[k].rows[i].score[1]));
  const avg=C.mean(margin),sd=Math.sqrt(C.mean(margin.map(x=>(x-avg)**2)));
  // Home/away pairs share RNG; uncertainty clustered by seed, not 2N independent games.
  const cluster=Array.from({length:seeds},(_,i)=>(margin[2*i]+margin[2*i+1])/2),cm=C.mean(cluster),cs=Math.sqrt(cluster.reduce((n,x)=>n+(x-cm)**2,0)/(seeds-1));
  return [k,{winPctChange:C.round(b[k].summary.winPct-a[k].summary.winPct),marginChange:C.round(avg),marginChange95:[C.round(cm-1.96*cs/Math.sqrt(seeds)),C.round(cm+1.96*cs/Math.sqrt(seeds))],sd:C.round(sd)}];
 }));}
 report.pairedComparison={};
 for(const [name,from,to] of [['dataOnly','baseline','candidate'],['responseOnly','candidate','responseCandidate'],['combined','baseline','responseCandidate']]){if(report.versions[from]&&report.versions[to])report.pairedComparison[name]=comparison(report.versions[from].results,report.versions[to].results);}
 const b=(report.versions.responseCandidate||report.versions.candidate||Object.values(report.versions)[0]).results;
 const s=k=>b[k].summary;
 report.designTargets={kind:'Exploratory game-design goals; NOT official historical statistics',
  averagePromotedWinAtMost30:s('prod2_mid_top14_mid').winPct<=30,
  bestPromotedVsStrongAtMost25:s('promoted0_strong').winPct<=25,
  bestPromotedVsWeakAtLeast15:s('promoted0_weak').winPct>=15,
  fiveRecruitsImproveMargin:s('promoted5_mid').margin>s('promoted0_mid').margin,
  relegatedAdvantageNotGuaranteed:s('relegated_keep_mid').winPct>50&&s('relegated_keep_mid').winPct<95,
  departuresReduceMargin:s('relegated_lose5_mid').margin<s('relegated_keep_mid').margin};
 if(!fs.readFileSync(MASTER).equals(bytes))throw Error('Master mutated');
 if(out)fs.writeFileSync(out,JSON.stringify(report)+'\n');
 return report;
}
if(require.main===module){const out=process.argv[2]||'/tmp/rugby-real-v11-report.json',seeds=Number(process.argv[3]||64);const r=campaign({out,seeds,onlyVersion:process.argv[4]||null,progress:x=>console.log(JSON.stringify(x))});console.log(JSON.stringify({out,matches:r.totalMatches,targets:r.designTargets}));}
module.exports={campaign,summarize,seed,clusterInterval};
