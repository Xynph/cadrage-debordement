'use strict';
/**
 * V15: active (not V12 candidate) 1592-player database, native match engine.
 * All recruitment/departure/rotation cases are read-only laboratory rosters.
 */
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const N=require('../tools/rugby-real-v12/native.cjs');
const A=require('../tools/rugby-real-v12/campaign.cjs');
const root=path.resolve(__dirname,'..');
const base=JSON.parse(fs.readFileSync(path.join(root,'modding/data06/rugby-master-2026-2027.json'),'utf8'));
const active=vm.runInNewContext(fs.readFileSync(path.join(root,'dist/lnr-ratings-v12.js'),'utf8')+'\n;LNR_V12_PLAYER_DATA;');
const srckeys=['scrum','lineout','tackle','speed','pass','kick','goal','mental','discipline','stamina','power'];
const copy=x=>JSON.parse(JSON.stringify(x));
const mean=x=>x.reduce((s,v)=>s+v,0)/x.length;
const rd=n=>Math.round(n*100)/100;
const live=copy(base);
for(const p of live.players){
 const t=active.players[p.id];assert.ok(t,'Missing active player '+p.id);
 assert.equal(t[5],p.gameplayPosition,'Role mismatch '+p.id);
 p.rating=t[0];p.ratingV12=t[0];p.attributesV2=Object.fromEntries(active.attributeKeys.map((k,i)=>[k,t[3][i]]));
 p.skills=Object.fromEntries(srckeys.map((k,i)=>[k,t[4][i]]));
 p.hiddenTraitsV2=copy(t[6]);p.potential=t[2];
}
function full(lab,c){const s=lab.sheet(c);return s.lineup.filter(Boolean).length===15&&s.bench.filter(Boolean).length===8;}
function sheetStats(lab,c){
 const s=lab.sheet(c),players=new Map(c.players.map(p=>[p.id,p]));
 const starters=s.lineup.filter(Boolean).map(id=>players.get(id));
 const bench=s.bench.filter(Boolean).map(id=>players.get(id));
 return {ids:s.lineup.filter(Boolean),mean:rd(mean(starters.map(lab.note))),bench:rd(mean(bench.map(lab.note))),
  min:Math.min(...starters.map(lab.note)),max:Math.max(...starters.map(lab.note)),
  age:rd(mean(starters.map(p=>p.age)))};
}
function simpleMoves(lab,baseClub,donors,n,{diverse=true}={}){
 const c=copy(baseClub),used=new Set(c.players.map(p=>p.id)),roles=new Set(),moves=[];
 for(let j=0;j<n;j++){
  const oldLine=lab.sheet(c).lineup.filter(Boolean).map(id=>c.players.find(p=>p.id===id));
  const opts=[];
  for(const old of oldLine){
   for(const donor of donors)for(const p of donor.players){
    if(used.has(p.id)||p.pos!==old.pos||donor.slug===baseClub.slug)continue;
    if(diverse&&roles.has(old.pos))continue;
    const gain=lab.note(p)-lab.note(old);
    if(gain>=2)opts.push({p,old,donor:donor.slug,gain,role:old.pos});
   }
  }
  opts.sort((a,b)=>b.gain-a.gain||a.p.id.localeCompare(b.p.id));
  if(!opts.length)break;
  const chosen=opts[0];used.add(chosen.p.id);roles.add(chosen.role);
  c.players.push(copy(chosen.p));
  moves.push({id:chosen.p.id,replaces:chosen.old.id,donor:chosen.donor,role:chosen.role,gain:chosen.gain});
 }
 return {club:c,moves};
}
function cut(lab,c,n,type){
 const out=copy(c),s=lab.sheet(c),idx=new Map(c.players.map(p=>[p.id,p]));
 const starters=s.lineup.filter(Boolean).map(id=>idx.get(id));
 const bench=s.bench.filter(Boolean).map(id=>idx.get(id));
 const ordered=(type==='bench'?bench:starters).sort((a,b)=>type==='bench'?lab.note(a)-lab.note(b):lab.note(b)-lab.note(a));
 const removed=ordered.slice(0,n);
 out.players=out.players.filter(p=>!removed.some(x=>x.id===p.id));
 return {club:out,removed:removed.map(p=>({id:p.id,role:p.pos,note:lab.note(p)}))};
}
function matchPair(lab,a,b,seeds=10,opts={}){
 assert.ok(full(lab,a)&&full(lab,b),'23 player minimum required');
 assert.ok(!a.players.some(x=>b.players.some(y=>x.id===y.id)),'overlap in opposition');
 const rows=[];
 for(let i=0;i<seeds;i++)for(const home of [0,1]){
  const r=lab.match(a,b,A.seed(i),{home,...opts});
  rows.push({seed:A.seed(i),home,...r});
 }
 return A.summarize(rows);
}
test('Active 1592 runtime scores, role-sorted complete teams and actual depth',()=>{
 assert.equal(live.players.length,1592);
 const ids=new Set(live.players.map(p=>p.id));assert.equal(ids.size,1592);
 for(const p of live.players){
  const t=active.players[p.id];assert.equal(p.rating,t[0]);
  assert.equal(p.attributesV2.topSpeed,t[3][active.attributeKeys.indexOf('topSpeed')]);
  assert.equal(p.skills.speed,t[4][3]);
 }
 const lab=N.laboratory(live,'legacy');
 const rank={};
 for(const league of ['top14','prod2']){
  const cs=lab.clubs.filter(c=>c.league===league),ready=cs.filter(c=>full(lab,c));
  rank[league]=ready.map(c=>({club:c.slug,players:c.players.length,q:rd(lab.quality(c)),...sheetStats(lab,c)}))
   .sort((a,b)=>a.q-b.q||a.club.localeCompare(b.club));
 }
 const av={top14:rd(mean(rank.top14.map(x=>x.q))),prod2:rd(mean(rank.prod2.map(x=>x.q)))};
 assert.ok(rank.top14.length>=8&&rank.prod2.length>=8);
 assert.ok(av.top14>av.prod2,'active 1592 gap expected');
 console.log('RUGBY_REAL_ACTIVE_ROSTER_AUDIT '+JSON.stringify({players:1592,activeTop14:805,activeProD2:787,
  complete:{top14:rank.top14.length,prod2:rank.prod2.length},teamMeans:av,
  teamQualityGap:rd(av.top14-av.prod2),rank}));
});
test('Native paired games: 2/5 recruits, 2/5 losses and rotation vs 3 opponents', {timeout:420000},()=>{
 const lab=N.laboratory(live,'legacy');
 const rank=league=>lab.clubs.filter(c=>c.league===league&&full(lab,c))
   .sort((a,b)=>lab.quality(a)-lab.quality(b)||a.slug.localeCompare(b.slug));
 const top=rank('top14'),pro=rank('prod2'),donors=top.slice(2,-1);
 const promoted=pro.at(-1),middle=top[Math.floor(top.length/2)],strong=top.at(-1),
  weak=top[0],proMid=pro[Math.floor(pro.length/2)];
 assert.ok(donors.length>=3);
 const recruit2=simpleMoves(lab,promoted,donors,2);
 const recruit5=simpleMoves(lab,promoted,donors,5);
 const cut2=cut(lab,weak,2,'starter'),cut5=cut(lab,weak,5,'starter');
 const bench5=cut(lab,weak,5,'bench');
 assert.equal(recruit2.moves.length,2);assert.equal(recruit5.moves.length,5);
 assert.equal(cut2.removed.length,2);assert.equal(cut5.removed.length,5);
 assert.equal(bench5.removed.length,5);
 const scenarios=[
  ['promoted_vs_weak',promoted,weak],['promoted_vs_mid',promoted,middle],['promoted_vs_strong',promoted,strong],
  ['recruited2_vs_mid',recruit2.club,middle],['recruited5_vs_mid',recruit5.club,middle],
  ['recruited5_vs_strong',recruit5.club,strong],
  ['relegated_vs_pro_mid',weak,proMid],['lost2_vs_pro_mid',cut2.club,proMid],
  ['lost5_vs_pro_mid',cut5.club,proMid],['benchcut5_vs_pro_mid',bench5.club,proMid]
 ];
 const metrics={};for(const [name,a,b] of scenarios)metrics[name]=matchPair(lab,a,b,12);
 const quality={promoted:sheetStats(lab,promoted),recruited2:sheetStats(lab,recruit2.club),
  recruited5:sheetStats(lab,recruit5.club),weak:sheetStats(lab,weak),
  lost2:sheetStats(lab,cut2.club),lost5:sheetStats(lab,cut5.club),
  benchcut5:sheetStats(lab,bench5.club)};
 assert.ok(quality.recruited5.mean>quality.promoted.mean);
 assert.ok(quality.lost5.mean<quality.weak.mean);
 const diff=(a,b)=>rd(metrics[a].margin-metrics[b].margin);
 const effects={
  recruitment2Margin:diff('recruited2_vs_mid','promoted_vs_mid'),
  recruitment5Margin:diff('recruited5_vs_mid','promoted_vs_mid'),
  loss2Margin:diff('lost2_vs_pro_mid','relegated_vs_pro_mid'),
  loss5Margin:diff('lost5_vs_pro_mid','relegated_vs_pro_mid'),
  benchLoss5Margin:diff('benchcut5_vs_pro_mid','relegated_vs_pro_mid')
 };
 console.log('RUGBY_REAL_ACTIVE_MOVEMENT_QA '+JSON.stringify({
  seeds:12,matches:scenarios.length*24,referenceClub:{promoted:promoted.slug,weak:weak.slug,
   mid:middle.slug,strong:strong.slug,proMid:proMid.slug},
  moves:{recruit2:recruit2.moves,recruit5:recruit5.moves,cut2:cut2.removed,
   cut5:cut5.removed,benchCut:bench5.removed},quality,effects,
  metrics:Object.fromEntries(Object.entries(metrics).map(([k,v])=>[k,{winPct:v.winPct,margin:v.margin,win95:v.win95,
   fatigue:v.fatigue,injuries:v.injuries}])),
  reminder:'Active V12 source tuple ratings and skills, hypothetical role-correct laboratory transfers, not an interdivision career'
 }));
});
