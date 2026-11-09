'use strict';

function factory(D1,D2){
 const firstAnchor='2026-08-31',firstYear=2026,dayMs=86400000,weekMs=7*dayMs;
 const leagues=Object.freeze([D1.competitionId,D1.secondDivision]),promotionId=D1.promotionId;
 const check=(ok,message)=>{if(!ok)throw Error('Saison japonaise : '+message);};
 const d2Keys=D2.clubKeys.slice(),distinct=a=>new Set(a).size===a.length;
 check(D2.schema==='jlo-d2-calendar-v1'&&D2.season===firstYear&&d2Keys.length===8&&distinct(d2Keys)&&D2.regular.length===56,'calendrier D2 invalide.');
 const slotKeys=id=>id===leagues[0]?D1.clubKeys.slice():id===leagues[1]?d2Keys.slice():[];
 const week=(date,anchor)=>Math.floor((Date.parse(date)-Date.parse(anchor))/weekMs);
 const formatted=year=>year+'-'+String((year+1)%100).padStart(2,'0');
 const forYear=(id,year)=>id.replace(/^jlo:2026-27:/,'jlo:'+formatted(year)+':');
 const toReference=id=>typeof id==='string'?id.replace(/^jlo:\d{4}-\d{2}:/,'jlo:2026-27:'):id;
 function shifted(f,year,anchor){
  if(year===firstYear)return f;
  const shift=Date.parse(anchor)-Date.parse(firstAnchor);
  check(Number.isInteger(shift/weekMs)&&shift>0,'ancrage futur invalide.');
  const move=d=>new Date(Date.parse(d)+shift).toISOString().slice(0,10);
  return {...f,id:forYear(f.id,year),season:year,date:move(f.date),kickoffUtc:null,
   ...(f.dateOptions?{dateOptions:f.dateOptions.map(move)}:{}),
   ...(f.dateWindow?{dateWindow:f.dateWindow.map(move)}:{}),dateSource:'simulation-future-calendar'};
 }
 function regular({id,members,year,anchor}){
  const keys=slotKeys(id);
  check(keys.length&&Array.isArray(members)&&members.length===keys.length&&distinct(members),'membres de division incomplets.');
  const clubs=keys.map((key,i)=>({id:members[i],key}));
  const byKey=new Map(clubs.map(c=>[c.key,c.id]));
  const fixtures=id===leagues[0]?D1.calendarFixtures({clubs,datePolicy:D1.regularDatePolicy}):D2.regular.map(f=>{
   const date=f.date??f.dateOptions[0];
   check(byKey.has(f.homeKey)&&byKey.has(f.awayKey)&&f.homeKey!==f.awayKey&&Number.isFinite(Date.parse(date)),'rencontre D2 invalide.');
   return {id:f.id,competitionId:id,season:firstYear,phase:'league',round:f.round,slot:f.slot,week:week(date,firstAnchor),
    homeId:byKey.get(f.homeKey),awayId:byKey.get(f.awayKey),date,dateOptions:f.dateOptions.slice(),
    dateSource:f.date?'published':'simulation-earliest-option',kickoffUtc:f.kickoffUtc};
  });
  return fixtures.map(f=>shifted(f,year,anchor));
 }
 function table({id,members,fixtures,results,season,drawOrder}){
  const games=results.filter(r=>r.competitionId===id&&r.phase==='league'&&r.season===season);
  const eligibleFixtures=fixtures.filter(f=>f.competitionId===id&&f.phase==='league').map(f=>({...f,season}));
  const rows=D1.table(members,games,id,{season,fixtures:eligibleFixtures,drawOrder});
  return rows.map(r=>({...r,clubId:r.id,won:r.w,drawn:r.d,lost:r.l,bonus:r.bp,
   form:games.filter(g=>g.pair.includes(r.id)).slice(-5).map(g=>{
    const side=g.pair.indexOf(r.id),decision=D1.leagueResult(g).outcome[side];
    return decision==='win'?'W':decision==='loss'?'L':'D';
   })}));
 }
 const playoffSeeds=D1.playoffSeeds;
 function referenceKnockouts(results){
  return results.filter(r=>r.competitionId===leagues[0]&&D1.phases.includes(r.phase))
   .map(r=>{const p=r.japanExtra;return {...r,fixtureId:toReference(r.fixtureId),season:firstYear,
    ...(p?{overtime:{start:p.start,end:p.end,regulationScore:p.regulation.score,firstScore:p.firstScore}}:{}),
    ...(r.decision?.shootout?{shootout:r.decision.shootout}:{})};});
 }
 function knockout({year,anchor,seeds,phase,results}){
  return D1.knockoutFixtures({seeds,phase,results:referenceKnockouts(results),datePolicy:D1.playoffDatePolicy}).map(f=>shifted(f,year,anchor));
 }
 function finalRanking(rows,results){return D1.finalRanking(rows,referenceKnockouts(results));}
 function promotion({d1,d2,year,anchor}){
  const pairs=D1.promotionPairs(d1,d2);
  const fixtures=pairs.flatMap(p=>D1.promotionFixtures(p,{firstHomeId:p.lowerId,dates:['2027-05-22','2027-05-29']})
   .map(f=>shifted({...f,round:f.leg-1,dateSource:'simulation-window'},year,anchor)));
  return {pairs:pairs.map(p=>({...p,id:forYear(p.id,year),season:year})),fixtures};
 }
 function promotionDecision(pair,results){
  const prefix=pair.id+':m0';
  const legs=[1,2].map(i=>results.find(r=>r.fixtureId===prefix+i));
  check(!legs[1]||legs[0],'seconde manche de barrage sans première.');
  const canonical={...pair,id:toReference(pair.id),season:firstYear,dateWindow:D1.promotionWindow.slice()};
  return D1.promotionOutcome(canonical,legs.filter(Boolean));
 }
 function move(partition,pairs,outcomes){
  const next=Object.fromEntries(leagues.map(id=>[id,partition[id].slice()]));
  check(pairs.length===outcomes.length,'mouvements de barrage incomplets.');
  pairs.forEach((p,i)=>{
   const r=outcomes[i],d1=next[leagues[0]].indexOf(p.upperId),d2=next[leagues[1]].indexOf(p.lowerId);
   check(d1>=0&&d2>=0&&r&&r.upperNext===(r.promoted?p.lowerId:p.upperId)&&r.lowerNext===(r.promoted?p.upperId:p.lowerId),'mouvement hors des places de barrage.');
   next[leagues[0]][d1]=r.upperNext;next[leagues[1]][d2]=r.lowerNext;
  });
  return next;
 }
 return Object.freeze({leagues,promotionId,phases:D1.phases,slotKeys,regular,table,playoffSeeds,knockout,finalRanking,promotion,promotionDecision,move});
}
module.exports={factory,...factory(require('./league-one-d1.cjs'),require('./jlo-d2-calendar-2026-27-public.json'))};