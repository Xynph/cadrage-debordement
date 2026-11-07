'use strict';
/** V15: exploratory player-evidence screen, shadow-only synchronized candidate portfolio. */
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const N=require('../tools/rugby-real-v12/native.cjs');
const C=require('../tools/rugby-real-v12/review.cjs');
const A=require('../tools/rugby-real-v12/campaign.cjs');
const root=path.resolve(__dirname,'..');
const master=JSON.parse(fs.readFileSync(path.join(root,'modding/data06/rugby-master-2026-2027.json'),'utf8'));
const tuples=vm.runInNewContext(fs.readFileSync(path.join(root,'dist/lnr-ratings-v12.js'),'utf8')+'\n;LNR_V12_PLAYER_DATA;');
const keys=tuples.attributeKeys,skills=tuples.skillKeys,deep=x=>JSON.parse(JSON.stringify(x));
const avg=x=>x.length?x.reduce((s,v)=>s+v,0)/x.length:null;
const fixed=n=>n===null?null:+n.toFixed(3);
const pctl=(arr,f)=>{const a=arr.slice().sort((x,y)=>x-y);return a[Math.min(a.length-1,Math.max(0,Math.round((a.length-1)*f)))];};
const ACTIVE=deep(master);
for(const p of ACTIVE.players){const t=tuples.players[p.id];assert.ok(t,'active missing '+p.id);
 p.rating=p.ratingV12=t[0];p.potential=t[2];p.attributesV2=Object.fromEntries(keys.map((k,i)=>[k,t[3][i]]));
 p.skills=Object.fromEntries(skills.map((k,i)=>[k,t[4][i]]));p.hiddenTraitsV2=deep(t[6]);}
const core=C.ROLES;
function lineup(lab,club){const s=lab.sheet(club),m=new Map(club.players.map(p=>[p.id,p]));return {all:s.lineup.filter(Boolean).map(id=>m.get(id)),bench:s.bench.filter(Boolean).map(id=>m.get(id))};}
function rosterStats(lab,club){const x=lineup(lab,club),n=x.all.map(p=>lab.note(p));
 return {mean:fixed(avg(n)),benchMean:fixed(avg(x.bench.map(p=>lab.note(p)))),low:pctl(n,.2),high:pctl(n,.8),complete:x.all.length===15&&x.bench.length===8};}
function stats(lab){
 const divisions={};for(const league of ['top14','prod2']){const clubs=lab.clubs.filter(c=>c.league===league);
  const rows=clubs.map(c=>({slug:c.slug,league,roster:c.players.length,...rosterStats(lab,c)}));
  const full=rows.filter(c=>c.complete),m=avg(full.map(c=>c.mean));
  divisions[league]={full:full.length,total:rows.length,mean:fixed(m),
   min:fixed(Math.min(...full.map(c=>c.mean))),max:fixed(Math.max(...full.map(c=>c.mean))),
   sd:fixed(Math.sqrt(avg(full.map(c=>(c.mean-m)**2)))),rows};
 }return divisions;
}
function evidenceScreen(lab){
 const m=new Map(ACTIVE.players.map(p=>[p.id,p]));
 const clubById=new Map(lab.clubs.flatMap(c=>c.players.map(p=>[p.id,{slug:c.slug,league:c.league}])));
 const peer=new Map();
 for(const p of ACTIVE.players){const k=p.league+'|'+p.gameplayPosition;if(!peer.has(k))peer.set(k,[]);peer.get(k).push(p);}
 const baseline=[];
 for(const p of ACTIVE.players){const cl=clubById.get(p.id);assert.ok(cl);
  const group=peer.get(p.league+'|'+p.gameplayPosition),memo=group.map(q=>lab.note(q));
  const note=lab.note(p),median=pctl(memo,.5),p25=pctl(memo,.25),p75=pctl(memo,.75);
  const usage=p.performance2025_2026||null;
  const minutes=usage?.minutes,matches=usage?.matches,tries=usage?.tries,points=usage?.points;
  const valid=Number.isFinite(minutes)&&Number.isFinite(matches)&&matches>0&&minutes>=0;
  const workload=valid?minutes/matches:null;
  const primary=core[p.gameplayPosition],roleMean=avg(primary.map(k=>p.attributesV2[k]));
  const rolePeerMedian=pctl(group.map(q=>avg(primary.map(k=>q.attributesV2[k]))),.5);
  const selected=lineup(lab,lab.clubs.find(c=>c.slug===cl.slug));
  const squadState=selected.all.some(x=>x.id===p.id)?'starter':selected.bench.some(x=>x.id===p.id)?'bench':'depth';
  const positive=valid&&minutes>=1050&&matches>=16&&workload>=50&&note<=p25-2&&roleMean>=rolePeerMedian-3;
  const negative=valid&&minutes<=350&&matches<=10&&note>=p75+2&&squadState==='depth';
  const coverage=[valid?'minutes-and-matches':'missing-usage',Number.isFinite(tries)?'tries-observed':'no-tries',
   Number.isFinite(points)?'points-observed':'no-points'].filter(Boolean);
  const score=positive?(median-note)+(minutes/400)+(roleMean-rolePeerMedian)/4:negative?(note-median)+Math.max(0,350-minutes)/200:0;
  baseline.push({id:p.id,club:cl.slug,league:cl.league,role:p.gameplayPosition,age:p.ageApprox,
   note,median,p25,p75,primaryMean:fixed(roleMean),peerPrimaryMedian:fixed(rolePeerMedian),
   usage:valid?{matches,minutes,minutesPerMatch:fixed(workload),tries,points}:null,
   squadState,positive,negative,score:fixed(score),coverage});
 }
 const up=baseline.filter(x=>x.positive).sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id));
 const down=baseline.filter(x=>x.negative).sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id));
 return {baseline,up,down,coverage:baseline.filter(x=>x.usage).length};
}
function selectScreened(rows,count=6){
 const selected=[],seen=new Set();
 for(const x of rows){if(seen.has(x.club))continue;selected.push(x);seen.add(x.club);if(selected.length===count)break;}
 return selected;
}
function portfolio(players,plans){
 const cloned=deep(players),idMap=new Map(cloned.players.map(p=>[p.id,p])),edits=[];
 for(const spec of plans){const p=idMap.get(spec.id);if(!p)throw Error('Missing plan '+spec.id);
  const before=C.project(p),orig=deep(p),changed={};
  for(const k of core[p.gameplayPosition]){const next=Math.max(20,Math.min(97,p.attributesV2[k]+spec.delta));
   changed[k]=next-p.attributesV2[k];p.attributesV2[k]=next;}
  const after=C.project(p);
  for(const k of skills)p.skills[k]=Math.max(20,Math.min(97,+(p.skills[k]+after[k]-before[k]).toFixed(2)));
  edits.push({id:p.id,role:p.gameplayPosition,league:p.league,club:spec.club,change:spec.delta,
   beforeRating:orig.rating,afterRating:p.rating,attributeChanges:changed,
   beforeSkills:orig.skills,afterSkills:deep(p.skills)});
 }
 return {cloned,edits};
}
function game(lab,a,b,seeds=16){
 const rows=[];for(let i=0;i<seeds;i++)for(let home=0;home<2;home++){
  const r=lab.match(a,b,A.seed(i),{home});
  rows.push((r.score[0]-r.score[1]));}
 return Array.from({length:seeds},(_,i)=>(rows[i*2]+rows[i*2+1])/2);
}
function effect(a,b){
 const diff=a.map((x,i)=>x-b[i]),m=avg(diff),s=Math.sqrt(diff.reduce((s,v)=>s+(v-m)**2,0)/(diff.length-1)),ci=1.96*s/Math.sqrt(diff.length);
 return {marginDelta:fixed(m),ci95:[fixed(m-ci),fixed(m+ci)],seedPairs:diff.length};}
test('Screen EVERY active 2026 player for independent 2025-26 usage, same-role peers and team depth',()=>{
 const lab=N.laboratory(ACTIVE,'legacy'),scr=evidenceScreen(lab);
 assert.equal(scr.baseline.length,1592);
 const leagues=stats(lab);
 const byDiv={};
 for(const div of ['top14','prod2']){
  const rows=scr.baseline.filter(x=>x.league===div);
  byDiv[div]={players:rows.length,usageRows:rows.filter(x=>x.usage).length,
   potentialUnder:scr.up.filter(x=>x.league===div).length,
   potentialOver:scr.down.filter(x=>x.league===div).length};
 }
 console.log('RUGBY_REAL_V15_EVIDENCE_SCREEN '+JSON.stringify({
  total:1592,with202526MinutesAndMatches:scr.coverage,division:byDiv,
  candidates:{up:scr.up.length,down:scr.down.length},
  prioritized:{up:scr.up.slice(0,24),down:scr.down.slice(0,24)},
  clubDispersion:leagues,
  verdict:'Screen is not ground truth; minutes and game attributes are partly dependent on role/availability.'
 }));
});
test('Individual evidence-based ±2 shadow calibration: club dispersion and native paired games',{timeout:360000},()=>{
 const lab=N.laboratory(ACTIVE,'legacy'),scr=evidenceScreen(lab);
 const proposals=[...selectScreened(scr.up,6).map(x=>({...x,delta:2,direction:'up'})),
  ...selectScreened(scr.down,6).map(x=>({...x,delta:-2,direction:'down'}))];
 const ids=new Set(proposals.map(p=>p.id));assert.equal(ids.size,proposals.length);
 const shadow=portfolio(ACTIVE,proposals),cal=N.laboratory(shadow.cloned,'legacy');
 const before=stats(lab),after=stats(cal);
 const cases=[];
 const clubChanges=[...new Set(proposals.map(x=>x.club))];
 for(const slug of clubChanges.slice(0,6)){
  const a=lab.clubs.find(c=>c.slug===slug),a2=cal.clubs.find(c=>c.slug===slug);
  if(!a||!a2||!rosterStats(lab,a).complete||!rosterStats(cal,a2).complete)continue;
  const opponents=lab.clubs.filter(c=>c.league===a.league&&c.slug!==a.slug&&rosterStats(lab,c).complete)
   .sort((x,y)=>Math.abs(lab.quality(x)-lab.quality(a))-Math.abs(lab.quality(y)-lab.quality(a)));
  const b=opponents[0],b2=cal.clubs.find(c=>c.slug===b.slug);
  const original=game(lab,a,b,16),candidate=game(cal,a2,b2,16);
  cases.push({club:slug,opponent:b.slug,direction:proposals.filter(x=>x.club===slug).map(x=>x.direction),
   xvBefore:rosterStats(lab,a).mean,xvAfter:rosterStats(cal,a2).mean,effect:effect(candidate,original)});
 }
 console.log('RUGBY_REAL_V15_EVIDENCE_SHADOW '+JSON.stringify({candidateCount:proposals.length,
  proposalRows:proposals.map(({id,role,club,league,note,median,usage,squadState,delta,score,coverage})=>
   ({id,role,club,league,note,median,usage,squadState,delta,score,coverage})),
  edits:shadow.edits.map(({id,role,club,change})=>({id,role,club,change})),
  dispersion:Object.fromEntries(['top14','prod2'].map(k=>[k,{before:before[k].sd,after:after[k].sd,
   gapBefore:before[k].mean,gapAfter:after[k].mean}])),
  pairs:cases,pairedMatches:cases.length*32,
  caveat:'Hypothesis testing, not individual player corrections. 2025-26 usage influenced by injuries, selection, position and club; all edits on copies.'
 }));
 assert.equal(master.players.length,1592);
});
