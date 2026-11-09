'use strict';
// Descriptive aggregation of the preregistered paired matrix, never a strategy score.
const assert=require('node:assert/strict');
const SEEDS=Object.freeze([827381,318,52602]),POLICIES=Object.freeze(['minimal','attentive']);
const LABELS=Object.freeze(['initial','end-S1','opening-S2','end-S2','opening-S3']);
const PHASES=['initial','end','opening','end','opening'],SEASONS=[1,1,2,2,3];
const HASH=/^[a-f0-9]{64}$/,COMMIT=/^[a-f0-9]{40}$/;
const finite=x=>typeof x==='number'&&Number.isFinite(x),known=x=>x===null||finite(x);
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
function distribution(values){
 assert(Array.isArray(values)&&values.every(known),'numeric values or explicit null required');
 const ordered=values.filter(finite).sort((a,b)=>a-b),n=ordered.length;
 return {n,missing:values.length-n,values:values.slice(),min:n?ordered[0]:null,median:n?(ordered[Math.floor((n-1)/2)]+ordered[Math.ceil((n-1)/2)])/2:null,max:n?ordered.at(-1):null};
}
const delta=(a,b)=>finite(a)&&finite(b)?b-a:null;
const band=age=>!finite(age)?'unknown':age<=23?'initial-23-or-younger':age<=29?'initial-24-29':'initial-30-or-older';
function sourceQuantiles(values){const a=values.filter(finite).sort((x,y)=>x-y),at=q=>a.length?a[Math.max(0,Math.ceil(a.length*q)-1)]:null;return {q25:at(.25),median:at(.5),q75:at(.75)};}
function validate(r){
 assert(r&&r.schema==='progression-multiseed-audit-v1','unsupported individual report');
 assert(same(r.preregisteredSeeds,SEEDS),'seed preregistration differs');
 assert(r.status==='completed'&&r.passed===true&&r.reopened===true,'failed, partial or unreopened arm');
 assert(SEEDS.includes(r.seed)&&POLICIES.includes(r.policy?.id),'arm outside preregistered matrix');
 assert(HASH.test(r.policy.hash)&&r.policy.profile&&typeof r.policy.profile==='object','policy receipt missing');
 assert(COMMIT.test(r.sources?.commit)&&['digest','runnerHash','policiesHash'].every(k=>HASH.test(r.sources[k])),'source receipt missing');
 assert(r.policy.hash===r.sources.policiesHash,'policy signature differs from source receipt');
 assert(HASH.test(r.initialHash)&&HASH.test(r.initialProfileHash),'initial receipts missing');
 assert(r.requestedSeasons===2&&r.completedSeasons===2,'two complete played seasons required');
 assert(Array.isArray(r.observations)&&same(r.observations.map(o=>o.label),LABELS),'missing or reordered observations');
 const initialIds=r.observations[0].players?.map(p=>p.id);
 assert(r.observations[0].club?.id===0,'preregistered initial club differs');
 assert(Array.isArray(initialIds)&&initialIds.length>0&&new Set(initialIds).size===initialIds.length,'initial player cohort missing or duplicated');
 r.observations.forEach((o,i)=>{
  assert(o.season===SEASONS[i]&&o.phase===PHASES[i]&&o.week===[0,46,0,46,0][i],'observation endpoint mismatch');
  assert(o.club&&Number.isSafeInteger(o.club.id)&&typeof o.club.division==='string'&&o.club.division.length,'club/division missing');
  assert(typeof o.club.unresolvedTie==='boolean','unresolved sporting tie flag missing');
  for(const key of ['rank','leagueSize','points','played','cash','debt','weeklyWages'])assert(Object.hasOwn(o.club,key)&&known(o.club[key]),'missing club metric '+key);
  if(o.club.rank!==null)assert(Number.isInteger(o.club.rank)&&Number.isInteger(o.club.leagueSize)&&o.club.rank>=1&&o.club.rank<=o.club.leagueSize,'invalid sporting rank');
  assert(o.quality&&known(o.quality.xvMeanNote)&&typeof o.quality.sheetValid==='boolean','missing XV/23 observation');
  for(const key of ['rating','age']){
   assert(o.quality[key]&&['q25','median','q75'].every(k=>known(o.quality[key][k])),'missing roster distribution');
   const q=o.quality[key];if([q.q25,q.median,q.q75].every(finite))assert(q.q25<=q.median&&q.median<=q.q75,'contradictory roster quantiles');
  }
  assert(Array.isArray(o.players)&&o.players.length===o.club.professionals&&new Set(o.players.map(p=>p.id)).size===o.players.length,'roster snapshot missing or duplicated');
  for(const key of ['rating','age'])assert(same({q25:o.quality[key].q25,median:o.quality[key].median,q75:o.quality[key].q75},sourceQuantiles(o.players.map(p=>p[key]))),'roster source quantiles contradict players');
  for(const p of o.players)assert(typeof p.id==='string'&&p.id.length&&['age','rating','note','potential'].every(k=>Object.hasOwn(p,k)&&known(p[k])),'missing player observation');
  assert(Array.isArray(o.cohortRecords)&&o.cohortRecords.length===initialIds.length&&new Set(o.cohortRecords.map(p=>p.id)).size===initialIds.length&&o.cohortRecords.every(p=>initialIds.includes(p.id)),'initial cohort tracking incomplete');
  for(const p of o.cohortRecords){
   const own=o.players.find(x=>x.id===p.id);
   assert((p.status==='own')===!!own,'cohort ownership contradicts roster');
   if(own)assert(p.rating===own.rating&&p.age===own.age,'cohort observation contradicts own player');
   if(['retired','untracked'].includes(p.status))assert(p.rating===null,'missing/retired cohort rating must stay unknown');
   assert(['own','other-professional','free-agent','academy','market','retired','untracked'].includes(p.status)&&known(p.rating)&&known(p.age),'unknown cohort status or missing observation');
  }
 });
 assert(Array.isArray(r.annual)&&r.annual.length===2,'annual campaign truncated');
 r.annual.forEach((a,i)=>assert(a.season===i+1&&a.openingLabel===(i?'opening-S2':'initial')&&a.closingLabel==='end-S'+(i+1)&&a.transitionLabel==='opening-S'+(i+2)&&Number.isInteger(a.results)&&a.results>0&&a.results===a.fixtures,'season not fully played'));
 assert(Array.isArray(r.financialPeriods)&&r.financialPeriods.length===2,'financial periods missing');
 r.financialPeriods.forEach((f,i)=>{
  assert(f.season===i+1,'financial season mismatch');
  assert(f.cashOpening===r.observations[i*2].club.cash&&f.cashClosing===r.observations[i*2+1].club.cash&&f.cashAfterTransition===r.observations[i*2+2].club.cash,'financial endpoints contradict observations');
  for(const k of ['cashOpening','cashClosing','cashAfterManagement','cashAfterTransition','minCash','negativeWeeks','longestNegativeStreak','ledgerEntries','unexplainedCash'])assert(Object.hasOwn(f,k)&&known(f[k]),'missing financial metric '+k);
  for(const k of ['negativeWeeks','longestNegativeStreak','ledgerEntries'])assert(f[k]===null||(Number.isSafeInteger(f[k])&&f[k]>=0),'invalid financial count');
  assert(f.negativeWeeks===null||f.negativeWeeks<=46,'negative weeks exceed observed season');
  if(f.longestNegativeStreak!==null&&f.negativeWeeks!==null)assert(f.longestNegativeStreak<=f.negativeWeeks,'negative streak exceeds negative weeks');
  assert(f.categories&&['wages','sponsorship','gate','maintenance','victoryBonus','financing','contractFees','transfers','investments','other'].every(k=>Object.hasOwn(f.categories,k)&&known(f.categories[k])),'financial categories truncated');
  if(Object.values(f.categories).every(finite)&&finite(f.unexplainedCash)&&finite(f.cashOpening)&&finite(f.cashAfterTransition))assert(Math.abs(Object.values(f.categories).reduce((a,b)=>a+b,0)+f.unexplainedCash-(f.cashAfterTransition-f.cashOpening))<1e-6,'financial conservation mismatch');
  if(finite(f.minCash))for(const k of ['cashOpening','cashClosing','cashAfterManagement','cashAfterTransition'])if(finite(f[k]))assert(f.minCash<=f[k],'cash minimum contradicts checkpoint');
 });
 assert(Array.isArray(r.actions)&&r.actions.length>0&&r.actions.every(a=>typeof a.command==='string'&&typeof a.ok==='boolean'&&['policy','harness'].includes(a.kind)),'action receipts missing');
 const signed=r.actions.filter(a=>a.kind==='policy'&&a.ok&&a.command==='extend_contract'&&a.negotiation?.status==='signed');
 for(const a of signed)assert(finite(a.negotiation.fee)&&a.negotiation.fee>=0,'signed contract fee missing');
 assert(r.policySummary&&r.policySummary.policy===r.policy.id&&r.policySummary.sourceHash===r.policy.hash&&r.policySummary.blocked===false,'policy completion receipt missing');
 assert(r.policySummary.signed===signed.length&&finite(r.policySummary.actualFees)&&Math.abs(r.policySummary.actualFees-signed.reduce((n,a)=>n+a.negotiation.fee,0))<1e-6,'signed outcomes contradict policy receipt');
 assert(Array.isArray(r.restarts)&&same(r.restarts.map(x=>x.label),['end-S1','end-S2','opening-S3']),'restart coverage missing');
 for(const x of r.restarts)assert(x.publicExact===true&&x.privateExact===true&&HASH.test(x.stateHash)&&HASH.test(x.profileHash),'restart integrity failure');
}
function playerProgress(initial,endpoint){
 const own=new Map(endpoint.players.map(p=>[p.id,p])),tracked=new Map(endpoint.cohortRecords.map(p=>[p.id,p])),initialIds=new Set(initial.players.map(p=>p.id));
 const groups=['all','initial-23-or-younger','initial-24-29','initial-30-or-older','unknown'].map(ageBand=>{
  const cohort=initial.players.filter(p=>ageBand==='all'||band(p.age)===ageBand),retained=cohort.filter(p=>own.has(p.id));
  const changes=(rows,get)=>rows.map(p=>delta(p.rating,get(p)?.rating));
  const located=cohort.filter(p=>tracked.get(p.id)?.status!=='untracked'),statusCounts={};
  for(const p of cohort){const status=tracked.get(p.id)?.status??'untracked';statusCounts[status]=(statusCounts[status]||0)+1;}
  return {initialAgeBand:ageBand,initial:cohort.length,retained:retained.length,leftOwnRoster:cohort.length-retained.length,located:located.length,statusCounts,
   retainedRatingChange:distribution(changes(retained,p=>own.get(p.id))),trackedRatingChange:distribution(changes(cohort,p=>tracked.get(p.id))),
   retainedNoteChange:distribution(retained.map(p=>delta(p.note,own.get(p.id)?.note))),
   caveat:'Retained players are a survivor subset; tracked ratings exclude unknown observations, never impute zero.'};
 });
 return {groups,entrants:endpoint.players.filter(p=>!initialIds.has(p.id)).length,ownRosterRating:distribution(endpoint.players.map(p=>p.rating))};
}
function pairedCohort(initial,a,b){
 const aa=new Map(a.cohortRecords.map(p=>[p.id,p])),bb=new Map(b.cohortRecords.map(p=>[p.id,p]));
 return ['all','initial-23-or-younger','initial-24-29','initial-30-or-older','unknown'].map(ageBand=>{
  const cohort=initial.players.filter(p=>ageBand==='all'||band(p.age)===ageBand);
  return {initialAgeBand:ageBand,initial:cohort.length,retainedBoth:cohort.filter(p=>aa.get(p.id)?.status==='own'&&bb.get(p.id)?.status==='own').length,
   onlyMinimalRetained:cohort.filter(p=>aa.get(p.id)?.status==='own'&&bb.get(p.id)?.status!=='own').length,
   onlyAttentiveRetained:cohort.filter(p=>bb.get(p.id)?.status==='own'&&aa.get(p.id)?.status!=='own').length,
   pairedObservedRatingDifference:distribution(cohort.map(p=>delta(aa.get(p.id)?.rating,bb.get(p.id)?.rating))),
   caveat:'Comparison uses only initial IDs with ratings observed in both arms; unknown/retired values remain missing, not zero.'};
 });
}
function summarize(reports){
 assert(Array.isArray(reports)&&reports.length===SEEDS.length*POLICIES.length,'all six preregistered arms required');
 reports.forEach(validate);
 const keyed=new Map();for(const r of reports){const key=r.seed+':'+r.policy.id;assert(!keyed.has(key),'duplicate seed-policy arm');keyed.set(key,r);}
 for(const seed of SEEDS)for(const policy of POLICIES)assert(keyed.has(seed+':'+policy),'missing seed-policy arm');
 const source=reports[0].sources;
 assert(reports.every(r=>same(r.sources,source)),'source or method hashes differ');
 for(const policy of POLICIES){const arms=SEEDS.map(seed=>keyed.get(seed+':'+policy));assert(arms.every(r=>same(r.policy,arms[0].policy)),'policy profile/hash differs across seeds');}
 const arms=SEEDS.flatMap(seed=>POLICIES.map(policy=>keyed.get(seed+':'+policy)));
 const pairs=SEEDS.map(seed=>{
  const [a,b]=POLICIES.map(policy=>keyed.get(seed+':'+policy));
  assert(a.initialHash===b.initialHash&&a.initialProfileHash===b.initialProfileHash,'initial paired states differ');
  assert(same(a.observations[0],b.observations[0]),'initial paired observations differ');
  const captures=LABELS.map((label,i)=>{
   const x=a.observations[i],y=b.observations[i],sameClub=x.club.id===y.club.id,sameLeague=sameClub&&x.club.division===y.club.division&&x.club.leagueSize===y.club.leagueSize,rankComparable=sameLeague&&!x.club.unresolvedTie&&!y.club.unresolvedTie;
   return {label,season:x.season,sameClub,pairedInitialCohort:pairedCohort(a.observations[0],x,y),sport:{comparable:sameLeague,rankComparable,unresolvedTie:[x.club.unresolvedTie,y.club.unresolvedTie],divisions:[x.club.division,y.club.division],leagueSizes:[x.club.leagueSize,y.club.leagueSize],
    rankDelta:rankComparable?delta(x.club.rank,y.club.rank):null,pointsDelta:sameLeague?delta(x.club.points,y.club.points):null,
    note:'Rank/points compared only within the same division and league size; unresolved ranks have no numeric delta, no overall winner.'},
    economy:{comparable:sameClub,cashDelta:sameClub?delta(x.club.cash,y.club.cash):null,debtDelta:sameClub?delta(x.club.debt,y.club.debt):null,weeklyWagesDelta:sameClub?delta(x.club.weeklyWages,y.club.weeklyWages):null},
    quality:{comparable:sameClub,xvMeanNoteDelta:sameClub?delta(x.quality.xvMeanNote,y.quality.xvMeanNote):null,rosterMedianRatingDelta:sameClub?delta(distribution(x.players.map(p=>p.rating)).median,distribution(y.players.map(p=>p.rating)).median):null,sheetValid:[x.quality.sheetValid,y.quality.sheetValid]}};
  });
  return {seed,initialStateEqual:true,initialHash:a.initialHash,initialProfileHash:a.initialProfileHash,captures};
 });
 const trajectories=arms.map(r=>({seed:r.seed,policy:r.policy.id,clubAtCaptures:r.observations.map(o=>({label:o.label,...o.club,quality:{xvMeanNote:o.quality.xvMeanNote,sheetValid:o.quality.sheetValid,sourceRatingQuantiles:{q25:o.quality.rating.q25,p50NearestRank:o.quality.rating.median,q75:o.quality.rating.q75},sourceAgeQuantiles:{q25:o.quality.age.q25,p50NearestRank:o.quality.age.median,q75:o.quality.age.q75},rosterRating:distribution(o.players.map(p=>p.rating)),rosterAge:distribution(o.players.map(p=>p.age))}})),
  playerProgress:r.observations.slice(1).map(o=>({label:o.label,...playerProgress(r.observations[0],o)})),
  actions:{signedContracts:r.actions.filter(a=>a.kind==='policy'&&a.ok&&a.command==='extend_contract'&&a.negotiation?.status==='signed').length,signedFees:r.actions.filter(a=>a.kind==='policy'&&a.ok&&a.command==='extend_contract'&&a.negotiation?.status==='signed').reduce((n,a)=>n+a.negotiation.fee,0),negotiationCounters:r.actions.filter(a=>a.kind==='policy'&&a.ok&&a.command==='extend_contract'&&a.negotiation?.status==='counter').length,accepted:r.actions.filter(a=>a.ok).length,refused:r.actions.filter(a=>!a.ok).length,policyAccepted:r.actions.filter(a=>a.kind==='policy'&&a.ok).length,policyRefused:r.actions.filter(a=>a.kind==='policy'&&!a.ok).length,byCommand:[...new Set(r.actions.filter(a=>a.kind==='policy').map(a=>a.command))].sort().map(command=>({command,accepted:r.actions.filter(a=>a.kind==='policy'&&a.command===command&&a.ok).length,refused:r.actions.filter(a=>a.kind==='policy'&&a.command===command&&!a.ok).length})),note:'Accepted API requests are not automatically effective interventions or causal improvements.'},
  financialPeriods:r.financialPeriods.map(f=>({season:f.season,recoveryAssessment:f.negativeWeeks===0?'not-exercised':'not-established-by-these-summary-fields',cashOpening:f.cashOpening,cashClosing:f.cashClosing,cashAfterManagement:f.cashAfterManagement,cashAfterTransition:f.cashAfterTransition,minCash:f.minCash,negativeWeeks:f.negativeWeeks,longestNegativeStreak:f.longestNegativeStreak,unexplainedCash:f.unexplainedCash,categories:{...f.categories},ledgerEntries:f.ledgerEntries})),
  restarts:r.restarts.map(x=>({label:x.label,publicExact:x.publicExact,privateExact:x.privateExact}))}));
 const distributions=LABELS.map((label,i)=>({label,pairedCashDelta:distribution(pairs.map(p=>p.captures[i].economy.cashDelta)),pairedDebtDelta:distribution(pairs.map(p=>p.captures[i].economy.debtDelta)),pairedWeeklyWagesDelta:distribution(pairs.map(p=>p.captures[i].economy.weeklyWagesDelta)),pairedXvMeanNoteDelta:distribution(pairs.map(p=>p.captures[i].quality.xvMeanNoteDelta)),pairedRosterMedianRatingDelta:distribution(pairs.map(p=>p.captures[i].quality.rosterMedianRatingDelta)),sportByDivision:[...new Set(pairs.filter(p=>p.captures[i].sport.comparable).map(p=>p.captures[i].sport.divisions[0]+':'+p.captures[i].sport.leagueSizes[0]))].sort().map(key=>{const selected=pairs.filter(p=>p.captures[i].sport.comparable&&p.captures[i].sport.divisions[0]+':'+p.captures[i].sport.leagueSizes[0]===key);return {division:key,seeds:selected.map(p=>p.seed),rankDelta:distribution(selected.map(p=>p.captures[i].sport.rankDelta)),pointsDelta:distribution(selected.map(p=>p.captures[i].sport.pointsDelta))};})}));
 return {schema:'progression-summary-v1',status:'complete-matrix',preregisteredSeeds:SEEDS.slice(),policies:POLICIES.map(id=>({...keyed.get(SEEDS[0]+':'+id).policy})),sources:{...source},requestedSeasons:2,playedSeasons:2,transitions:2,completedPairs:3,arms:6,pairs,trajectories,distributions,
  interpretation:{sourceRosterQuantiles:'Original nearest-rank source quantiles retained as p50NearestRank; validated against raw player records, never treated as the standard median',summaryDistributions:'median is arithmetic mean of the two central values for even samples',deltaDirection:POLICIES[1]+' minus '+POLICIES[0],cashIsProfit:false,winnerDeclared:false,statisticalProof:false,limitations:['Three preregistered seeds only; no significance test or universal strategy ranking.','Cash, debt, payroll, sport and player quality are separate outcomes.','Opening S3 is a transition endpoint, not a third played season.','Player retention creates survivor bias; entrants and missing observations stay separate.','Financing and unexplained ledger flows do not become operating performance.']}};
}
function markdown(s){
 const fmt=x=>x===null?'inconnu':String(x),final=t=>t.clubAtCaptures.at(-1),progress=t=>t.playerProgress.at(-1).groups[0];
 const rows=s.distributions.map(d=>'| '+d.label+' | '+fmt(d.pairedCashDelta.median)+' ['+fmt(d.pairedCashDelta.min)+' ; '+fmt(d.pairedCashDelta.max)+'] | '+d.pairedCashDelta.n+' | '+fmt(d.pairedXvMeanNoteDelta.median)+' | '+d.pairedXvMeanNoteDelta.n+' |');
 const sport=s.pairs.flatMap(p=>['end-S1','end-S2'].map(label=>{const c=p.captures.find(x=>x.label===label),values=POLICIES.map(id=>s.trajectories.find(t=>t.seed===p.seed&&t.policy===id).clubAtCaptures.find(o=>o.label===label));return '| '+p.seed+' | '+label+' | '+values.map(v=>v.division+' '+fmt(v.rank)+'/'+fmt(v.leagueSize)+' · '+fmt(v.points)+' pts').join(' | ')+' | '+(c.sport.comparable?(c.sport.rankComparable?'même division':'rang non départagé ; points comparables'):'comparaison de rang/points non applicable')+' |';}));
 const economy=s.trajectories.map(t=>{const c=final(t);return '| '+t.seed+' | '+t.policy+' | '+fmt(c.cash)+' | '+fmt(c.debt)+' | '+fmt(c.weeklyWages)+' | '+fmt(distribution(t.financialPeriods.map(f=>f.minCash)).min)+' | '+fmt(t.financialPeriods.every(f=>finite(f.negativeWeeks))?t.financialPeriods.reduce((n,f)=>n+f.negativeWeeks,0):null)+' | '+t.actions.policyAccepted+'/'+t.actions.policyRefused+' | '+t.actions.signedContracts+' / '+t.actions.negotiationCounters+' | '+fmt(t.actions.signedFees)+' |';});
 const players=s.trajectories.map(t=>{const p=progress(t);return '| '+t.seed+' | '+t.policy+' | '+p.retained+'/'+p.initial+' | '+t.playerProgress.at(-1).entrants+' | '+p.trackedRatingChange.n+'/'+p.initial+' | '+fmt(p.retainedRatingChange.median)+' | '+fmt(p.trackedRatingChange.median)+' |';});
 return '# Lecture descriptive des politiques de progression\n\n'+s.completedPairs+' paires complètes, trois graines préannoncées, deux saisons jouées et deux transitions par bras. Différences : attentive moins minimal. Aucun vainqueur ni preuve statistique.\n\n| Capture | Δ trésorerie, médiane [min ; max] | n connu | Δ notes naturelles du XV, médiane | n connu |\n| --- | --- | ---: | --- | ---: |\n'+rows.join('\n')+
 '\n\n| Graine | Clôture | minimal : division, rang, points | attentive : division, rang, points | Portée |\n| --- | --- | --- | --- | --- |\n'+sport.join('\n')+
 '\n\n| Graine | Politique | Cash ouverture S3 | Dette connue | Salaires hebdomadaires | Minimum cash observé | Semaines négatives | Requêtes politique acceptées/refusées | Signatures/contre-offres | Primes réellement signées |\n| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |\n'+economy.join('\n')+
 '\n\n| Graine | Politique | Retenus/cohorte initiale | Entrants | Ratings suivis connus/cohorte | Δ rating médian des retenus | Δ rating médian suivi |\n| --- | --- | --- | ---: | --- | ---: | ---: |\n'+players.join('\n')+
 '\n\nLe cash est un stock, pas un bénéfice. Le JSON sépare financements, flux inconnus, dette et salaires. Les rangs et points sont stratifiés par division et taille de ligue. La note du XV est la moyenne des notes naturelles des quinze titulaires, pas une force optimale ou au poste joué. Les variations individuelles distinguent cohortes initiales, survivants, entrants et inconnus ; les ratings des mêmes IDs connus dans les deux bras sont aussi appariés. Les acceptations API restent distinctes des refus et ne prouvent pas un effet causal. En l’absence de période négative, le redressement financier n’a pas été exercé.\n';
}

if(require.main===module){try{const fs=require('node:fs'),args=process.argv.slice(2),asMarkdown=args[0]==='--markdown',files=asMarkdown?args.slice(1):args;assert(files.length===6,'six report files required');const s=summarize(files.map(f=>JSON.parse(fs.readFileSync(f,'utf8'))));process.stdout.write(asMarkdown?markdown(s):JSON.stringify(s,null,2)+'\n');}catch{process.stderr.write('Rapports de progression incomplets ou incohérents ; synthèse refusée.\n');process.exitCode=1;}}
module.exports={summarize,validateIndividual:validate,distribution,markdown,SEEDS,POLICIES};
