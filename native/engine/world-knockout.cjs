'use strict';
// International knockout resolution on the actual match clock and eligible XV.
module.exports=function worldKnockout(){
 // Libellés du critère de départage (décision affichée et journal du match).
 const METHODS=Object.freeze({tries:'au nombre d’essais marqués',penalties:'au nombre de pénalités réussies',drops:'au nombre de drops réussis',redCards:'au nombre d’exclusions (moins de cartons rouges)',shootout:'aux tirs au but'});
 const scoreText=l=>`${S.clubs[l.pair[0]].abbr} ${l.score[0]} – ${l.score[1]} ${S.clubs[l.pair[1]].abbr}`;
 function usesFullUrcShootout(editionVersion,f){
  return editionVersion===5&&f.competitionId==='urc'&&['quarter','semi','final'].includes(f.phase);
 }
 // Fin de la seconde prolongation, annoncée avant la décision (texte seul).
 function extraTimeEnd(l){
  if(l.knockout?.period===2)addEvent(l,`Fin de la prolongation : ${scoreText(l)}.`,'play');
 }
 // Commentaire tir par tir d'une séance déjà jouée : n'ajoute que des faits du journal, après coup, à partir de la
 // preuve (`attempts` : {side, playerId, made} dans l'ordre des tirs). Aucun tirage. `series` : nombre de tours de
 // la série initiale (les suivants sont en mort subite). Au-delà de 40 tirs, la suite est résumée (journal borné).
 function commentShootout(l,attempts,series=null){
  if(!Array.isArray(attempts)||!attempts.length)return;
  const abbr=side=>S.clubs[l.pair[side]].abbr,score=[0,0],max=40;
  addEvent(l,`Séance de tirs au but : ${abbr(attempts[0].side)} ouvre la séance.`,'play');
  const taken=[0,0];
  attempts.forEach((a,index)=>{
   taken[a.side]++;if(a.made)score[a.side]++;
   if(index>=max)return;
   const round=taken[a.side],name=matchPlayer(l,a.side,a.playerId)?.name||'Le buteur';
   const sudden=Number.isFinite(series)&&round>series?'Mort subite, tir ':'Tir ';
   addEvent(l,`${sudden}${round} — ${name} (${abbr(a.side)}) : ${a.made?'réussi':'manqué'}, ${score[0]} – ${score[1]}.`,'play');
  });
  if(attempts.length>max)addEvent(l,`Après ${attempts.length} tirs, la séance s’achève sur ${score[0]} – ${score[1]}.`,'play');
 }
 function finish(l,editionVersion){
  if(['league','pool'].includes(l.worldContext.phase))return false;
  if(!l.knockout&&l.score[0]===l.score[1]){l.knockout={version:1,period:1,regulationEnd:l.minute,firstEnd:null};l.flow.fullEnd=l.minute+10;l.flow.ballDead=false;addEvent(l,`Prolongation : égalité ${scoreText(l)} au terme du temps réglementaire, deux périodes de dix minutes.`,'break');performKickRestart(l,'kickoff',l.firstKickoff,'extra-first',1-l.firstKickoff);return true;}
  if(l.knockout?.period===1){l.knockout.period=2;l.knockout.firstEnd=l.minute;l.flow.fullEnd=l.minute+10;l.flow.ballDead=false;addEvent(l,`Changement de camp : fin de la première prolongation (${scoreText(l)}), seconde période de dix minutes.`,'break');performKickRestart(l,'kickoff',1-l.firstKickoff,'extra-second',l.firstKickoff);return true;}
  extraTimeEnd(l);
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
     const p=kickers[i][round%3],chance=clamp(.23+skill(p,'goal',fitArrete(l))*.006-Math.max(0,distance-25)*.005-angle*.13+(unit(l,i,'mental')-70)*.001-(l.weather==='Vent'?.16:l.weather==='Pluie'?.06:0),.22,.93),made=Math.random()<chance;
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
   commentShootout(l,shootout.attempts,6);
  }
  l.winner=l.pair[side];l.decision={method,extraTime:!!l.knockout,redCards:l.sheets.map(s=>s.redCards.length),...(shootout?{shootout}:{})};
  if(method!=='score')addEvent(l,`${S.clubs[l.winner].abbr} se qualifie ${METHODS[method]||'au départage'}${shootout?` (${shootout.score[0]} – ${shootout.score[1]})`:''}.`,'end');
  return false;
 }
 return Object.freeze({finish,usesFullUrcShootout,commentShootout,extraTimeEnd,METHODS});
};
