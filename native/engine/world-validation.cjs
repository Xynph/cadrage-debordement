'use strict';
// Strict rules for this edition only. The shared save reader still validates
// the complete rugby, economic and player state before these checks.
module.exports=function worldValidation(){
 const check=(ok,why)=>saveCheck(ok,'Monde international : '+why),eq=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
 const keys=(o,k)=>saveObject(o)&&Object.keys(o).length===k.length&&k.every(x=>Object.hasOwn(o,x));
 function score(r){
  check(Array.isArray(r.stats)&&r.stats.length===2,'statistiques de résultat absentes.');
  for(let i=0;i<2;i++){
   const x=r.stats[i];check(['goals','goalAttempts','conversions','conversionAttempts'].every(k=>saveInt(x[k],0,1000))&&x.goals<=x.goalAttempts&&x.conversions<=x.conversionAttempts&&x.conversionAttempts===r.tries[i]&&r.score[i]===r.tries[i]*5+x.conversions*2+x.goals*3,'score incompatible avec les actions du moteur.');
  }
 }
 function shootout(r,live){
  const q=r.decision.shootout;
  check(keys(q,['kickers','end','first','score','attempts'])&&saveInt(q.first,0,1)&&saveInt(q.end,0,1)&&saveArray(q.kickers,2)&&q.kickers.length===2&&q.kickers.every(x=>saveArray(x,3)&&x.length===3&&x.every(saveId))&&new Set(q.kickers.flat()).size===6,'buteurs invalides.');
  check(saveArray(q.attempts,2000)&&q.attempts.length>0,'séquence de tirs invalide.');
  if(live)for(let i=0;i<2;i++)check(q.kickers[i].every(id=>live.sheets[i].on.includes(id)&&!live.sheets[i].cards.some(c=>c.id===id&&c.until>live.minute)),'buteur inéligible en fin de match.');
  const tally=[0,0],taken=[0,0];let winner=null;
  for(const [index,a]of q.attempts.entries()){
   const round=Math.floor(index/2),side=index%2?1-q.first:q.first,location=round<6?round+1:4;
   check(winner===null&&keys(a,['side','playerId','location','made'])&&a.side===side&&a.location===location&&a.playerId===q.kickers[side][round%3]&&typeof a.made==='boolean','ordre des tirs invalide.');
   taken[side]++;if(a.made)tally[side]++;
   if(round<6){if(tally[0]>tally[1]+6-taken[1])winner=0;if(tally[1]>tally[0]+6-taken[0])winner=1;}
   else if(index%2&&tally[0]!==tally[1])winner=tally[0]>tally[1]?0:1;
  }
  check(winner!==null&&eq(tally,q.score)&&r.winner===r.pair[winner],'résultat des tirs incohérent.');
 }
 function result(r,f,live=null){
  const japan=typeof CDWorldJapanMatch!=='undefined'&&CDWorldJapanMatch.isFixture(f);
  check(r.japanExtra===undefined||japan,'preuve Japon hors de sa compétition.');
  if(japan)return CDWorldJapanMatch.validateResult(r,f,live);
  if(f.competitionId==='srp')return CDWorldSRPMatch.validateResult(r,f,live);
  check(r.srpExtra===undefined,'preuve Pacific hors de sa compétition.');
  score(r);const knockout=!['league','pool'].includes(f.phase)&&!(f.competitionId==='jlo-d1-d2'&&f.phase==='promotion'),d=r.decision;
  const duration=live?live.minute:r.duration;
  check(saveInt(duration,80,240)&&['Sec','Vent','Pluie'].includes(r.weather),'durée ou météo invalide.');
  if(!knockout){check(r.winner===undefined&&d===undefined&&live?.knockout===undefined,'départage hors phase finale.');return;}
  check(saveObject(d)&&typeof d.extraTime==='boolean'&&saveArray(d.redCards,2)&&d.redCards.length===2&&d.redCards.every(n=>saveInt(n,0,23))&&r.pair.includes(r.winner),'décision éliminatoire incomplète.');
  check(keys(d,d.method==='shootout'?['method','extraTime','redCards','shootout']:['method','extraTime','redCards']),'métadonnées de décision non reconnues.');
  check(d.extraTime?duration>=100:r.score[0]!==r.score[1],'départage sans prolongation.');
  const computed=CDWorldCompetitions.knockoutWinner({...r,duration,afterExtraTime:d.extraTime,penalties:r.stats.map(x=>x.goals),drops:r.stats.map(x=>x.drops||0),redCards:d.redCards},f.competitionId);
  check(computed.winner===r.winner&&computed.method===d.method,'vainqueur ou critère incohérent.');
  if(d.method==='shootout')shootout(r,live);
  if(live)check(d.extraTime===!!live.knockout&&eq(d.redCards,live.sheets.map(sh=>sh.redCards.length)),'décision incompatible avec les feuilles.');
 }
 function live(l,f){
  check(!!f&&eq(l.worldContext,f)&&eq(l.pair,[f.homeId,f.awayId])&&l.franceContext===undefined,'match en cours hors calendrier.');
  const japan=typeof CDWorldJapanMatch!=='undefined'&&CDWorldJapanMatch.isFixture(f);
  check(l.japanExtra===undefined||japan,'preuve Japon hors de sa compétition.');
  if(japan)return CDWorldJapanMatch.validateLive(l,f);
  if(f.competitionId==='jlo-d1-d2'&&f.phase==='promotion')check(l.knockout===undefined,'prolongation interdite dans une manche de barrage Japon.');
  if(f.competitionId==='srp')return CDWorldSRPMatch.validateLive(l,f);
  check(l.srpExtra===undefined,'preuve Pacific hors de sa compétition.');
  if(l.knockout){const k=l.knockout;check(!['league','pool'].includes(f.phase)&&keys(k,['version','period','regulationEnd','firstEnd'])&&k.version===1&&[1,2].includes(k.period)&&saveInt(k.regulationEnd,l.flow.firstEnd+40,l.minute)&&(k.period===1?k.firstEnd===null:saveInt(k.firstEnd,k.regulationEnd+10,l.minute)),'prolongation incohérente.');
   check(l.restartLog.filter(r=>r.cause==='extra-first').length===1&&l.restartLog.filter(r=>r.cause==='extra-second').length===(k.period===2?1:0),'reprises de prolongation absentes.');
   if(l.finished)check(k.period===2&&l.minute>=k.firstEnd+10,'prolongation inachevée.');
  }
  if(l.finished)result(l,f,l);else check(l.winner===undefined&&l.decision===undefined,'décision avant la fin du match.');
 }
 function draw(d,ids){
  check(keys(d,['clubIds','order','ranks'])&&eq(d.clubIds,ids)&&Array.isArray(d.order)&&d.order.length===ids.length&&new Set(d.order).size===ids.length&&d.order.every(id=>ids.includes(id))&&eq(d.ranks,Object.fromEntries(d.order.map((id,i)=>[id,i+1]))),'tirage modifié.');
 }
 return Object.freeze({result,live,draw,keys});
};
