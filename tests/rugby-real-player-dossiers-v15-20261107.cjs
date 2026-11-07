'use strict';
/** V15: full dossiers, independent-evidence audit and non-destructive sensitivity. */
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const C=require('../tools/rugby-real-v12/review.cjs'),N=require('../tools/rugby-real-v12/native.cjs'),A=require('../tools/rugby-real-v12/campaign.cjs');
const root=path.resolve(__dirname,'..'),clone=x=>JSON.parse(JSON.stringify(x));
const master=JSON.parse(fs.readFileSync(path.join(root,'modding/data06/rugby-master-2026-2027.json'),'utf8'));
const raw=fs.readFileSync(path.join(root,'dist/lnr-ratings-v12.js'),'utf8');
const source=vm.runInNewContext(raw+'\n;LNR_V12_PLAYER_DATA;');
const attrs=source.attributeKeys,skills=source.skillKeys;
const evidence=C.buildEvidence(master,require('../data/scouting/review-v12/season-evidence.json'),require('../data/scouting/review-v12/extra-evidence.json'),require('../data/scouting/review-v12/career-evidence.json'));
const active=clone(master);
for(const p of active.players){
 const t=source.players[p.id];assert.ok(t);
 p.rating=p.ratingV12=t[0];p.potential=t[2];
 p.attributesV2=Object.fromEntries(attrs.map((k,i)=>[k,t[3][i]]));
 p.skills=Object.fromEntries(skills.map((k,i)=>[k,t[4][i]]));
 p.hiddenTraitsV2=clone(t[6]);
}
const mean=a=>a.length?a.reduce((s,n)=>s+n,0)/a.length:null;
const round=n=>n===null?null:+n.toFixed(3);
const pctl=(a,f)=>{const v=a.slice().sort((x,y)=>x-y);return v[Math.round((v.length-1)*f)];};
const roster=(lab,c)=>{const sh=lab.sheet(c),m=new Map(c.players.map(p=>[p.id,p]));return {starters:sh.lineup.filter(Boolean).map(id=>m.get(id)),bench:sh.bench.filter(Boolean).map(id=>m.get(id))};};
const complete=(lab,c)=>{const s=roster(lab,c);return s.starters.length===15&&s.bench.length===8;};
function inspect(lab){
 const byId=new Map(lab.clubs.flatMap(c=>c.players.map(p=>[p.id,{c,p}])));
 const groups=new Map();
 for(const p of active.players){const k=p.league+'|'+p.gameplayPosition;if(!groups.has(k))groups.set(k,[]);groups.get(k).push(p);}
 const rows=[];
 for(const p of active.players){
  const e=evidence.byId.get(p.id),entry=byId.get(p.id),role=p.gameplayPosition,note=lab.note(entry.p);
  const peers=groups.get(p.league+'|'+role),median=pctl(peers.map(q=>lab.note(byId.get(q.id).p)),.5);
  const keys=C.ROLES[role],primary=mean(keys.map(k=>p.attributesV2[k]));
  const peerPrimary=pctl(peers.map(q=>mean(keys.map(k=>q.attributesV2[k]))),.5);
  const usage=e.usage?.stats,valid=Number.isFinite(usage?.minutes)&&Number.isFinite(usage?.matches)&&usage.matches>0;
  const older=e.history.filter(h=>h.season!=='2025-2026'&&Number.isFinite(h.stats.minutes)&&h.stats.minutes>=800);
  const regularSeasons=e.history.filter(h=>Number.isFinite(h.stats.minutes)&&h.stats.minutes>=800);
  const strongTry=e.attack&&e.attack.stats.minutes>=600&&e.attack.stats.tries*80/e.attack.stats.minutes>=.28;
  const strongKick=e.kicking&&e.kicking.attempted>=30&&e.kicking.made/e.kicking.attempted>=.78;
  const strongDef=e.observations.some(o=>o.stats.matches>=5&&o.stats.tacklesMade/o.stats.matches>=8);
  const honours=e.honours.length>0,six=e.assessments.some(a=>a.observedPerformanceRating>=7.5);
  const flagged=valid&&usage.minutes>=900&&usage.matches>=12&&usage.minutes/usage.matches>=45&&note<=median-2&&primary>=peerPrimary-4&&(regularSeasons.length>=2||strongTry||strongKick||strongDef||honours||six);
  if(!flagged)continue;
  const sh=roster(lab,entry.c);
  const tier=sh.starters.some(q=>q.id===p.id)?'starter':sh.bench.some(q=>q.id===p.id)?'bench':'depth';
  const sameRole=entry.c.players.filter(q=>q.id!==p.id&&q.pos===entry.p.pos).map(q=>({id:q.id,name:q.name,roleNote:lab.note(q),tier:sh.starters.some(z=>z.id===q.id)?'starter':sh.bench.some(z=>z.id===q.id)?'bench':'depth'})).sort((a,b)=>b.roleNote-a.roleNote);
  const seasons=e.history.map(h=>({season:h.season,competition:h.competition,historicalClub:h.historicalClub,matches:h.stats.matches,minutes:h.stats.minutes,tries:h.stats.tries,points:h.stats.points,source:h.sourceUrl})).sort((a,b)=>a.season.localeCompare(b.season));
  const historicalSources=[...new Set(e.history.map(h=>h.sourceUrl))];
  const urls=[...new Set([e.usage?.sourceUrl,e.attack?.sourceUrl,e.kicking?.sourceUrl,...e.honours.map(h=>h.sourceUrl),...e.assessments.map(a=>a.sourceUrl),...historicalSources].filter(Boolean))];
  const signals={priorSeason800:older.length,regularSeasons:regularSeasons.length,triesPer80:strongTry?round(e.attack.stats.tries*80/e.attack.stats.minutes):null,goalKicking:strongKick?{made:e.kicking.made,attempted:e.kicking.attempted}:null,
   defensiveObservation:!!strongDef,officialHonours:honours,sixNationsAssessment:six};
  // "Different LNR rankings" from the SAME 2025-26 sample are NOT independent validation.
  const distinctProvenance=[...new Set(urls.map(u=>new URL(u).hostname))];
  const temporalRep=older.length>=1,externalAnchor=honours||six||strongDef;
  const confidence=temporalRep&&(externalAnchor||strongTry||strongKick)?'multi-season-corroborated':
   temporalRep?'multi-season-usage-only':externalAnchor?'external-qualitative-only':'single-season-or-overlap';
  const eligibility=confidence==='multi-season-corroborated'&&note<=median-2;
  rows.push({id:p.id,name:p.realName,club:entry.c.slug,league:p.league,role,age:p.ageApprox,note,median,medianGap:median-note,
   primary:round(primary),peerPrimary:round(peerPrimary),tier,usage:valid?{matches:usage.matches,minutes:usage.minutes,minutesPerMatch:round(usage.minutes/usage.matches),tries:usage.tries??null,points:usage.points??null}:null,
   seasons,signals,competition:sameRole.slice(0,8),competitionCount:sameRole.length,provenance:urls,distinctProvenance,
   confidence,eligibility,skillSource:'active 2026 V12 runtime'});
 }
 rows.sort((a,b)=>b.medianGap-a.medianGap||(b.usage?.minutes||0)-(a.usage?.minutes||0)||a.id.localeCompare(b.id));
 return rows;
}
function scenario(club,changes){
 const c=clone(club),p=c.players.find(x=>x.id===changes.id);assert.ok(p);
 const activeP=active.players.find(x=>x.id===changes.id),before=C.project({...p,gameplayPosition:activeP.gameplayPosition});
 const keys=C.ROLES[activeP.gameplayPosition];
 const a={};for(const k of attrs){const dose=changes.dose&&keys.includes(k)?changes.dose:0;
  const old=p.attributesV2[k];p.attributesV2[k]=Math.max(20,Math.min(97,old+dose));a[k]=round(p.attributesV2[k]-old);}
 const after=C.project({...p,gameplayPosition:activeP.gameplayPosition}),s={};
 for(const k of skills){const d=round(after[k]-before[k]);p.skills[k]=Math.max(20,Math.min(97,round(p.skills[k]+d)));s[k]=d;}
 return {club:c,deltaAttributes:a,deltaSkills:s};
}
function played(lab,a,b,seeds=12){
 const v=[];for(let i=0;i<seeds;i++){const seed=A.seed(i+81);let margin=0;
  for(const home of [0,1]){const r=lab.match(a,b,seed,{home});margin+=r.score[0]-r.score[1];}
  v.push(margin/2);
 }return v;
}
function difference(x,y){
 const d=x.map((v,i)=>v-y[i]),m=mean(d);
 const sd=Math.sqrt(d.reduce((s,v)=>s+(v-m)**2,0)/(d.length-1));
 return {pairedSeeds:d.length,meanMarginDelta:round(m),ci95:[round(m-1.96*sd/Math.sqrt(d.length)),round(m+1.96*sd/Math.sqrt(d.length))]};
}
test('36 named dossiers: competing 2026 players, 2023-26 history, provenance overlap and evidence quality',()=>{
 const lab=N.laboratory(active),dossiers=inspect(lab);
 assert.equal(active.players.length,1592);assert.equal(dossiers.length,36,'V15 source screen cohort must remain traceable');
 for(const d of dossiers){assert.ok(d.name&&d.club&&d.role);assert.ok(Array.isArray(d.seasons));assert.ok(d.provenance.length);assert.ok(d.competition.every(c=>c.id!==d.id));}
 console.log('RUGBY_REAL_V15_36_NAMED_DOSSIERS '+JSON.stringify({
  count:dossiers.length,confidenceDistribution:Object.fromEntries([...new Set(dossiers.map(d=>d.confidence))].map(k=>[k,dossiers.filter(d=>d.confidence===k).length])),
  multiSeason:dossiers.filter(d=>d.signals.priorSeason800).length,withCompetition:dossiers.filter(d=>d.competitionCount>0).length,
  dossierRows:dossiers,
  caution:'A second ranking from the same season is not independent corroboration. No official historical table position, injury history, team selection or skill-level statistic is inferred.'}));
});
test('36 complete 36-attribute/11-skill shadow plans; stricter shortlisting and paired native match checks',{timeout:420000},()=>{
 const lab=N.laboratory(active),dossiers=inspect(lab),snap=JSON.stringify(source.players),byClub=new Map(lab.clubs.map(c=>[c.slug,c]));
 const counterfactuals=[],priority=[];
 for(const d of dossiers){
  const club=byClub.get(d.club),before=roster(lab,club),base=lab.note(club.players.find(p=>p.id===d.id));
  const plans=[];
  for(const dose of [0,2,4]){
   const t=scenario(club,{id:d.id,dose}),r=roster(lab,t.club),candidate=t.club.players.find(p=>p.id===d.id);
   assert.equal(Object.keys(t.deltaAttributes).length,36);assert.equal(Object.keys(t.deltaSkills).length,11);
   plans.push({dose,deltaAttributes:t.deltaAttributes,deltaSkills:t.deltaSkills,
    noteBefore:base,noteAfter:lab.note(candidate),wasStarter:before.starters.some(x=>x.id===d.id),starter:r.starters.some(x=>x.id===d.id),
    bench:r.bench.some(x=>x.id===d.id),xvBefore:round(mean(before.starters.map(p=>lab.note(p)))),xvAfter:round(mean(r.starters.map(p=>lab.note(p))))});
  }
  counterfactuals.push({id:d.id,name:d.name,club:d.club,confidence:d.confidence,eligible:d.eligibility,plans});
  if(d.eligibility&&complete(lab,club))priority.push(d);
 }
 priority.sort((a,b)=>b.signals.priorSeason800-a.signals.priorSeason800||b.medianGap-a.medianGap||a.id.localeCompare(b.id));
 const matches=[];
 for(const d of priority.slice(0,6)){
  const c=byClub.get(d.club),opponents=lab.clubs.filter(x=>x.league===d.league&&x.slug!==d.club&&complete(lab,x))
   .sort((a,b)=>Math.abs(lab.quality(a)-lab.quality(c))-Math.abs(lab.quality(b)-lab.quality(c)));
  const rival=opponents[0];if(!rival)continue;
  const baseline=played(lab,c,rival),results=[];
  for(const dose of [2,4]){
   const candidate=scenario(c,{id:d.id,dose});
   results.push({dose,score:difference(played(lab,candidate.club,rival),baseline),
    lineupState:roster(lab,candidate.club).starters.some(p=>p.id===d.id)?'starter':roster(lab,candidate.club).bench.some(p=>p.id===d.id)?'bench':'depth'});
  }
  matches.push({id:d.id,name:d.name,club:d.club,rival:rival.slug,results});
 }
 assert.equal(JSON.stringify(source.players),snap,'active V12 tuple source never mutates');
 console.log('RUGBY_REAL_V15_36_CANDIDATE_PLANS '+JSON.stringify({fullPlans:counterfactuals.length,
  eachPlanContains36AttributesAnd11Skills:true,nonDestructive:true,
  priorityCount:priority.length,matchedPlayers:matches.length,pairedMatches:matches.length*3*12*2,
  plans:counterfactuals.map(x=>({id:x.id,name:x.name,club:x.club,confidence:x.confidence,eligible:x.eligible,
   scenarios:x.plans.map(p=>({dose:p.dose,changedAttributes:Object.entries(p.deltaAttributes).filter(([,v])=>v!==0),
    changedSkills:Object.entries(p.deltaSkills).filter(([,v])=>v!==0),noteBefore:p.noteBefore,noteAfter:p.noteAfter,
    starter:p.starter,bench:p.bench,xvBefore:p.xvBefore,xvAfter:p.xvAfter}))})),
  matchPairs:matches,
  verdict:'All doses are exploratory copies, never proposed production changes; qualitative evidence does not identify which precise attribute should move.'}));
});