'use strict';
// International knockout resolution on the actual match clock and eligible XV.
module.exports=function worldKnockout(){
 function usesFullUrcShootout(editionVersion,f){
  return editionVersion===5&&f.competitionId==='urc'&&['quarter','semi','final'].includes(f.phase);
 }
 function finish(l,editionVersion){
  if(['league','pool'].includes(l.worldContext.phase))return false;
  if(!l.knockout&&l.score[0]===l.score[1]){l.knockout={version:1,period:1,regulationEnd:l.minute,firstEnd:null};l.flow.fullEnd=l.minute+10;l.flow.ballDead=false;addEvent(l,'Prolongation : deux périodes de dix minutes.','break');performKickRestart(l,'kickoff',l.firstKickoff,'extra-first',1-l.firstKickoff);return true;}
  if(l.knockout?.period===1){l.knockout.period=2;l.knockout.firstEnd=l.minute;l.flow.fullEnd=l.minute+10;l.flow.ballDead=false;addEvent(l,'Changement de camp : seconde période de prolongation.','break');performKickRestart(l,'kickoff',1-l.firstKickoff,'extra-second',l.firstKickoff);return true;}
  let side=l.score[0]>l.score[1]?0:l.score[1]>l.score[0]?1:null,method='score';
  const criteria=['elite','accession','access','access-nationale'].includes(l.worldContext.competitionId)?[['tries',l.tries],['penalties',l.stats.map(s=>s.goals)],['drops',l.stats.map(s=>s.drops||0)],['redCards',l.sheets.map(s=>-s.redCards.length)]]:[['tries',l.tries]];
  if(side===null)for(const [key,values] of criteria){if(values[0]!==values[1]){side=values[0]>values[1]?0:1;method=key;break;}}
  let shootout=null;
  if(side===null){
   const fullSeries=usesFullUrcShootout(editionVersion,l.worldContext);
   const kickers=[0,1].map(i=>activePlayers(l,i).slice().sort((a,b)=>skill(b,'goal')-skill(a,'goal')||a.id.localeCompare(b.id)).slice(0,3));
   if(kickers.some(a=>a.length<3))throw Error('Trois buteurs éligibles requis pour les tirs au but.');
   shootout={kickers:kickers.map(a=>a.map(p=>p.id)),end:rand(0,1),first:rand(0,1),score:[0,0],attempts:[]};
   // URC v5 uses the 2025/26 fallback: all six initial pairs before a verdict.
   // Other profiles retain the original early-stop behavior.
   for(let round=0;side===null;round++){
    if(round>=1000)throw Error('Épreuve de tirs au but sans décision après 1000 tours.');
    const location=round<6?round+1:4,depth=location<=3?22:40,offset=[2,3,5,6].includes(location)?20:0,distance=Math.hypot(depth,offset),angle=Math.atan2(offset,depth);
    for(const i of [shootout.first,1-shootout.first]){
     const p=kickers[i][round%3],chance=clamp(.23+skill(p,'goal',true)*.006-Math.max(0,distance-25)*.005-angle*.13+(unit(l,i,'mental')-70)*.001-(l.weather==='Vent'?.16:l.weather==='Pluie'?.06:0),.22,.93),made=Math.random()<chance;
     shootout.attempts.push({side:i,playerId:p.id,location,made});
     if(made)shootout.score[i]++;
     if(!fullSeries&&round<6){
      const remaining=[0,1].map(side=>6-shootout.attempts.filter(a=>a.side===side).length);
      if(shootout.score[i]>shootout.score[1-i]+remaining[1-i]){side=i;break;}
      if(shootout.score[1-i]>shootout.score[i]+remaining[i]){side=1-i;break;}
     }
    }
    const delta=shootout.score[0]-shootout.score[1];
    const decided=fullSeries?round>=5&&delta!==0:Math.abs(delta)>Math.max(0,5-round);
    if(decided)side=delta>0?0:1;
   }
   method='shootout';
  }
  l.winner=l.pair[side];l.decision={method,extraTime:!!l.knockout,redCards:l.sheets.map(s=>s.redCards.length),...(shootout?{shootout}:{})};
  if(method!=='score')addEvent(l,`${S.clubs[l.winner].abbr} se qualifie au départage (${method==='shootout'?'tirs au but':method}).`,'end');
  return false;
 }
 return Object.freeze({finish,usesFullUrcShootout});
};
