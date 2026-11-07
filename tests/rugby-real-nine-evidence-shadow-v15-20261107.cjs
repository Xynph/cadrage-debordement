'use strict';
/**
 * V15 focused audit. Hypotheses on copies only; never modifies dist/lnr or master.
 * SOURCE: 2023-26 public LNR career records, not an independent technical rating.
 */
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const C=require('../tools/rugby-real-v12/review.cjs');
const N=require('../tools/rugby-real-v12/native.cjs');
const A=require('../tools/rugby-real-v12/campaign.cjs');
const {context}=require('./harness.cjs');
const root=path.resolve(__dirname,'..');
const clone=x=>JSON.parse(JSON.stringify(x)),mean=a=>a.length?a.reduce((s,v)=>s+v,0)/a.length:null;
const round=x=>x===null?null:+x.toFixed(3);
const ids=['lnr:1444','lnr:184','lnr:429','lnr:1426','lnr:1793','lnr:862','lnr:11840','lnr:2168','lnr:555'];
const master=JSON.parse(fs.readFileSync(path.join(root,'modding/data06/rugby-master-2026-2027.json'),'utf8'));
const tupleSource=fs.readFileSync(path.join(root,'dist/lnr-ratings-v12.js'),'utf8');
const tuples=vm.runInNewContext(tupleSource+'\n;LNR_V12_PLAYER_DATA;');
const attr=tuples.attributeKeys,skills=tuples.skillKeys;
const originals=clone(master);
for(const p of originals.players){const t=tuples.players[p.id];assert.ok(t);
 p.rating=p.ratingV12=t[0];p.potential=t[2];p.attributesV2=Object.fromEntries(attr.map((k,i)=>[k,t[3][i]]));
 p.skills=Object.fromEntries(skills.map((k,i)=>[k,t[4][i]]));p.hiddenTraitsV2=clone(t[6]);}
const ev=C.buildEvidence(master,
 require('../data/scouting/review-v12/season-evidence.json'),
 require('../data/scouting/review-v12/extra-evidence.json'),
 require('../data/scouting/review-v12/career-evidence.json'));
const byId=new Map(originals.players.map(p=>[p.id,p]));
const hypothesis={
 'lnr:1444':['receiving','positioning'],
 'lnr:184':['ballCarry','workRate'],
 'lnr:429':['ballCarry','positioning'],
 'lnr:1426':['receiving','positioning'],
 'lnr:1793':['receiving','positioning'],
 'lnr:862':['ballCarry','workRate'],
 'lnr:11840':['ballCarry','workRate'],
 'lnr:2168':['ballCarry','positioning'],
 'lnr:555':['workRate','positioning']
};
function roster(lab,club){
 const sheet=lab.sheet(club),m=new Map(club.players.map(p=>[p.id,p]));
 return {xv:sheet.lineup.filter(Boolean).map(id=>m.get(id)),bench:sheet.bench.filter(Boolean).map(id=>m.get(id))};
}
const complete=(lab,c)=>{const x=roster(lab,c);return x.xv.length===15&&x.bench.length===8;};
function dossier(lab,p){
 const c=lab.clubs.find(c=>c.slug===p.club),inGame=c.players.find(x=>x.id===p.id),e=ev.byId.get(p.id),r=roster(lab,c);
 const peers=c.players.filter(q=>q.id!==p.id&&byId.get(q.id)?.gameplayPosition===p.gameplayPosition)
  .map(q=>({id:q.id,name:q.name,note:lab.note(q),tier:r.xv.some(v=>v.id===q.id)?'XV':r.bench.some(v=>v.id===q.id)?'bench':'depth'}))
  .sort((a,b)=>b.note-a.note);
 const seasons=e.history.map(x=>({season:x.season,competition:x.competition,club:x.historicalClub,
  minutes:x.stats.minutes??null,matches:x.stats.matches??null,tries:x.stats.tries??null,source:x.sourceUrl}))
  .sort((a,b)=>a.season.localeCompare(b.season)||a.competition.localeCompare(b.competition));
 const usage=e.usage?.stats;
 const prior=seasons.filter(s=>s.season!=='2025-2026'&&s.minutes>=800);
 const last=seasons.filter(s=>s.season==='2025-2026');
 const tries2025=last.reduce((sum,s)=>sum+(s.tries||0),0),minutes2025=last.reduce((sum,s)=>sum+(s.minutes||0),0);
 const teamQuality=round(mean(r.xv.map(x=>lab.note(x))));
 return {id:p.id,name:p.realName,club:p.club,league:p.league,role:p.gameplayPosition,age:p.ageApprox,
  nativeNote:lab.note(inGame),baselineRating:p.rating,tier:r.xv.some(v=>v.id===p.id)?'XV':r.bench.some(v=>v.id===p.id)?'bench':'depth',
  teamXV:teamQuality,usage202526:usage?{matches:usage.matches,minutes:usage.minutes,tries:usage.tries??null}:null,
  seasonHistory:seasons,priorRegularSeasons:prior.length,tryRatePer80:minutes2025?round(80*tries2025/minutes2025):null,
  sameExactPositionPeers:peers,sourceDomains:[...new Set(seasons.map(s=>new URL(s.source).hostname))],
  evidenceLimits:['Same LNR player page across seasons is temporal replication, not a second editorial source',
    'Minutes and tries cannot reveal scrum/defence/passing/physical attributes',
    '2025-26 PRO D2 exposure is not a TOP14-level performance anchor when division changed']};
}
function shadow(c,p,dose){
 const out=clone(c),target=out.players.find(x=>x.id===p.id);assert.ok(target);
 const prior=C.project({...target,gameplayPosition:p.gameplayPosition});
 const deltas=Object.fromEntries(attr.map(k=>[k,0]));
 for(const key of hypothesis[p.id]){const v=Math.min(97,target.attributesV2[key]+dose);
  deltas[key]=v-target.attributesV2[key];target.attributesV2[key]=v;}
 const next=C.project({...target,gameplayPosition:p.gameplayPosition});
 const skillDeltas={};
 for(const key of skills){const delta=round(next[key]-prior[key]);const orig=target.skills[key];
  target.skills[key]=Math.max(20,Math.min(97,round(orig+delta)));
  skillDeltas[key]=round(target.skills[key]-orig);}
 assert.equal(Object.keys(deltas).length,36);assert.equal(Object.keys(skillDeltas).length,11);
 return {club:out,changedAttrs:Object.entries(deltas).filter(([,v])=>v!==0),
  changedSkills:Object.entries(skillDeltas).filter(([,v])=>v!==0),
  fullAttributeDeltas:deltas,fullSkillDeltas:skillDeltas};
}
function games(lab,a,b,n=16){
 const rows=[];for(let i=0;i<n;i++){
  const seed=A.seed(i+170),home=lab.match(a,b,seed,{home:0}),away=lab.match(a,b,seed,{home:1});
  rows.push(((home.score[0]-home.score[1])+(away.score[0]-away.score[1]))/2);
 }return rows;
}
function paired(c,t){
 const dif=c.map((n,i)=>n-t[i]),m=mean(dif),v=dif.reduce((s,n)=>s+(n-m)**2,0)/(dif.length-1);
 return {deltaMargin:round(m),ci95:[round(m-1.96*Math.sqrt(v/dif.length)),round(m+1.96*Math.sqrt(v/dif.length))],
  pairedSeeds:dif.length};
}
test('Nine multi-season dossiers: correct exact-position rivals, LNR history and source caveats',()=>{
 assert.equal(new Set(ids).size,9);
 const lab=N.laboratory(originals,'legacy');
 const d=ids.map(id=>dossier(lab,byId.get(id)));
 for(const item of d){
  assert.ok(item.priorRegularSeasons>=1);
  assert.ok(item.seasonHistory.some(s=>s.season==='2025-2026'));
  assert.ok(item.sameExactPositionPeers.every(peer=>byId.get(peer.id).gameplayPosition===item.role));
  assert.ok(item.seasonHistory.every(s=>s.source.startsWith('https://')));
 }
 console.log('RUGBY_REAL_V15_NINE_DOSSIERS '+JSON.stringify({count:d.length,
  noIndependentDomainAssertion:true,
  dossier:d.map(x=>({...x,seasonHistory:x.seasonHistory.map(s=>({season:s.season,competition:s.competition,
   club:s.club,minutes:s.minutes,matches:s.matches,tries:s.tries})),evidenceLimits:undefined})),
  limitations:['Official LNR data cover time and scoring, not individual physical/mental grades',
   'Two historical rows from the same URL are not independent sources']}));
});
test('Nine restrained player-specific hypotheses: 36-to-11 shadow projection and paired native matches',{timeout:840000},()=>{
 const lab=N.laboratory(originals,'legacy'),before=JSON.stringify(tuples.players);
 const records=[],opponentCount=2,seeds=16;
 for(const id of ids){
  const p=byId.get(id),c=lab.clubs.find(x=>x.slug===p.club);
  const opponents=lab.clubs.filter(x=>x.league===c.league&&x.slug!==c.slug&&complete(lab,x))
   .sort((a,b)=>Math.abs(lab.quality(a)-lab.quality(c))-Math.abs(lab.quality(b)-lab.quality(c))||a.slug.localeCompare(b.slug))
   .slice(0,opponentCount);
  assert.equal(opponents.length,opponentCount);
  const initial=roster(lab,c),baselineNote=lab.note(c.players.find(x=>x.id===id));
  const scenarios=[1,2].map(dose=>{
   const changed=shadow(c,p,dose),r=roster(lab,changed.club);
   const afterNote=lab.note(changed.club.players.find(x=>x.id===id));
   return {dose,changedAttrs:changed.changedAttrs,changedSkills:changed.changedSkills,
    deltaRoleNote:afterNote-baselineNote,deltaXV:round(mean(r.xv.map(x=>lab.note(x)))-mean(initial.xv.map(x=>lab.note(x)))),
    tier:r.xv.some(q=>q.id===id)?'XV':r.bench.some(q=>q.id===id)?'bench':'depth',
    matches:opponents.map(o=>({opponent:o.slug,...paired(games(lab,changed.club,o,seeds),games(lab,c,o,seeds))}))};
  });
  records.push({id,name:p.realName,club:p.club,role:p.gameplayPosition,originalNote:baselineNote,
   initialTier:initial.xv.some(q=>q.id===id)?'XV':initial.bench.some(q=>q.id===id)?'bench':'depth',
   hypotheses:hypothesis[id],scenarios});
 }
 assert.equal(JSON.stringify(tuples.players),before);
 console.log('RUGBY_REAL_V15_NINE_PAIRED '+JSON.stringify({profiles:9,opponentsPerProfile:opponentCount,
  doseCount:3,seedPairs:seeds,actualNativeMatches:ids.length*opponentCount*3*seeds*2,
  candidateChangesAreNonDestructive:true,activeDatasetChanges:0,
  summary:records,
  warning:'Small hand-specified hypotheses, NOT empirically identified attributes. Intervals exploratory; never interpret 0 score effect as a validated rating.'}));
});
test('Top14 native six-season rotation for nine candidates: persistence without mutating engine or saves',{timeout:330000},()=>{
 const dist=path.join(root,'dist'),files=['lnr-v11-aging.js','lnr-ratings-v12.js','lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'];
 const boot=()=>{const g=context();for(const f of files)vm.runInContext(fs.readFileSync(path.join(dist,f),'utf8'),g.ctx,{filename:f});return g;};
 let g=boot();g.run("start(0,'lnr')");
 const rows=[],original=JSON.stringify(tuples.players);
 const snap=season=>JSON.parse(g.run("JSON.stringify(S.clubs.map(c=>({slug:c.slug,players:c.players.filter(p=>p.lnrRatingsVersion===1).map(p=>({id:p.id,roleNote:roleNote(p),rating:p.rating})),sheet:buildSheet(c)})))"))
  .flatMap(c=>ids.filter(id=>c.players.some(p=>p.id===id)).map(id=>{
   const p=c.players.find(q=>q.id===id);return {id,club:c.slug,roleNote:p.roleNote,
    tier:c.sheet.lineup.includes(id)?'XV':c.sheet.bench.includes(id)?'bench':'depth'};}))
  .map(x=>({...x,season}));
 rows.push(...snap(1));
 const summaries=[];
 for(let year=1;year<=6;year++){
  for(let round=0;round<26;round++)g.run('finishRound()');
  let guard=0;while(g.run("S.phase")!=='ended'){assert.ok(++guard<=4);g.run('finishRound()');}
  g.run('advanceSeason()');rows.push(...snap(year+1));
  const clubs=JSON.parse(g.run("JSON.stringify(S.clubs.map(c=>({n:c.name,roster:c.players.length,sheet:buildSheet(c)})))"));
  summaries.push({season:year+1,players:clubs.reduce((n,c)=>n+c.roster,0),
   completeXV:clubs.filter(c=>c.sheet.lineup.filter(Boolean).length===15).length,
   completeBench:clubs.filter(c=>c.sheet.bench.filter(Boolean).length===8).length});
 }
 assert.equal(JSON.stringify(tuples.players),original);
 console.log('RUGBY_REAL_V15_NINE_NATIVE_ROTATION '+JSON.stringify({
  seasons:6,cohort:ids,bySeason:Array.from({length:7},(_,i)=>({season:i+1,present:rows.filter(r=>r.season===i+1).length,
   XV:rows.filter(r=>r.season===i+1&&r.tier==='XV').length,bench:rows.filter(r=>r.season===i+1&&r.tier==='bench').length})),
  players:ids.map(id=>({id,trajectory:rows.filter(r=>r.id===id)})),teamIntegrity:summaries,
  limitation:'Only TOP14 active in original career; outcomes do not apply shadow attribute changes. No save schema or model changed.'}));
});