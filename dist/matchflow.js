'use strict';
function flowRules(l){return restartRules(l)&&l.flowVersion===1}
function initializeMatchFlow(l){l.advantageModel=2;l.flowVersion=1;l.flow={period:1,firstEnd:null,fullEnd:null,atBreak:false,ballDead:false,advantage:null,resolvingAward:false}}
function periodBoundary(l){return l.flow.period===1?40:l.flow.fullEnd}
function atHalftime(l){return flowRules(l)?l.flow.atBreak:l.minute===40&&l.paused&&!l.finished}
function matchMinute(l){if(!flowRules(l)||l.flow.period===1)return l.minute;return 40+l.minute-l.flow.firstEnd}
function matchClock(l){const n=matchMinute(l),limit=flowRules(l)&&l.flow.period===1?40:80;return n>limit?`${limit}+${n-limit}′`:`${n}′`}
function endFlowPeriod(l){
 if(l.finished||l.flow.atBreak)return;
 l.flow.advantage=null;l.flow.ballDead=true;
 if(l.flow.period===1){l.flow.firstEnd=l.minute;l.flow.atBreak=true;l.halftime=true;l.paused=true;addEvent(l,'Mi-temps : le ballon est mort après la fin du temps réglementaire.','break')}
 else finishRugbyMatch(l);
}
function resumeFlowHalf(l){
 if(!flowRules(l)||!l.flow.atBreak)return;
 l.flow.period=2;l.flow.atBreak=false;l.flow.fullEnd=l.minute+40;l.flow.ballDead=false;
 performKickRestart(l,'kickoff',1-l.firstKickoff,'second-half',l.firstKickoff);
}
function clearAdvantage(l,message='Avantage terminé : bénéfice réel obtenu.'){
 if(!l.flow.advantage)return;l.flow.advantage=null;addEvent(l,message,'advantage');
}
// Referee policy for this simulation, not a prescribed number of metres/phases in law.
function advantageReal(l,at=l.territory){
 const a=l.flow.advantage;if(!a)return false;
 const gain=(a.team===0?1:-1)*(at-a.at);
 // A clear territorial gain after sustained possession can be a real benefit; the thresholds are simulation parameters.
 if(l.advantageModel===2&&a.phases>=2&&l.possession===a.team&&gain>=(a.kind==='penalty'?18:8))return true;
 return gain>=(a.kind==='penalty'?25:12)||a.kind==='scrum'&&a.phases>=2&&l.possession===a.team&&gain>0;
}
function returnAdvantage(l){
 const a=l.flow.advantage;if(!a)return false;
 l.flow.advantage=null;addEvent(l,`Aucun avantage obtenu : retour à ${a.kind==='penalty'?'la pénalité':'la mêlée'} pour ${S.clubs[l.pair[a.team]].abbr}.`,'advantage',{team:a.team,to:{x:a.at,y:35}});
 ballPossession(l,a.team,a.at);l.flow.resolvingAward=true;
 try{if(a.kind==='penalty')executePenaltyChoice(l,a.team);else grantSetPiece(l,'scrum',a.team,a.at,'knock-on',a.offender,a.at)}finally{l.flow.resolvingAward=false}
 return true;
}
function offerAdvantage(l,kind,team,offender,at,{force=false,unsafe=false}={}){
 if(!flowRules(l)||l.flow.resolvingAward)return false;
 const prior=l.flow.advantage;
 if(prior){
  if(team!==prior.team){returnAdvantage(l);return true}
  if(kind==='penalty'){
   const further=(team===0?1:-1)*(at-prior.at)>0;
   if(prior.kind==='scrum'||further){prior.kind='penalty';prior.at=at;prior.offender=offender}
   addEvent(l,'Nouvelle faute : le bénéfice de la sanction la plus favorable est conservé.','advantage');
  }
  if(unsafe)returnAdvantage(l);else ballPossession(l,team,at);
  return true;
 }
 if(unsafe||!force&&Math.random()>.55)return false;
 l.flow.advantage={kind,team,offender,at,started:l.minute,phases:0};
 ballPossession(l,team,at);addEvent(l,`Avantage ${kind==='penalty'?'sur pénalité':'sur en-avant'} pour ${S.clubs[l.pair[team]].abbr}.`,'advantage');return true;
}
function settleAdvantage(l){
 const a=l.flow.advantage;if(!a||l.finished||l.flow.atBreak)return;
 a.phases++;
 if(l.possession!==a.team)return returnAdvantage(l);
 if(advantageReal(l))return clearAdvantage(l);
 if(a.phases>=3)return returnAdvantage(l);
}
function flowBeforeRestart(l,kind,cause,at){
 if(!flowRules(l))return !l.finished;if(l.finished||l.flow.atBreak)return false;
 if(l.flow.advantage&&!l.flow.resolvingAward){
  if(advantageReal(l,at))clearAdvantage(l);else{returnAdvantage(l);return false}
 }
 if(l.minute>=periodBoundary(l)&&!(l.flow.resolvingAward&&kind==='scrum'&&cause==='knock-on')&&cause!=='penalty-touch'&&!['start','second-half'].includes(cause)){endFlowPeriod(l);return false}
 l.flow.ballDead=false;return true;
}
function flowScored(l,side){
 if(!flowRules(l))return false;
 const a=l.flow.advantage;
 if(a&&a.team===side)clearAdvantage(l,'Essai ou points obtenus : avantage terminé.');
 if(l.minute>=periodBoundary(l)){endFlowPeriod(l);return true}return false;
}
function beforeTryUnderAdvantage(l,side){if(flowRules(l)&&l.flow.advantage&&l.flow.advantage.team!==side){returnAdvantage(l);return false}return true}
function advanceFlowPlay(l){
 if(l.flow.advantage&&l.possession!==l.flow.advantage.team){returnAdvantage(l);return}
 const expired=l.minute>=periodBoundary(l),margin=l.score[l.possession]-l.score[1-l.possession];
 // A coach may legally kick the ball out to close a period; this is a tactical
 // decision, not an automatic referee whistle while the ball remains in play.
 if(expired&&!l.flow.advantage&&(l.minute>=periodBoundary(l)+4||l.flow.period===2&&margin>=0&&l.minute>periodBoundary(l))){addEvent(l,`${S.clubs[l.pair[l.possession]].abbr} envoie le ballon en touche pour terminer la période.`,'play',{kind:'touch',team:l.possession,to:{x:l.territory,y:0}});endFlowPeriod(l);return}
 advanceCausalPlay(l);settleAdvantage(l);
}
function finishRugbyMatch(l){
 if(S.phase!=='league'&&l.score[0]===l.score[1]){const prob=clamp(.5+(unit(l,0,'mental')-unit(l,1,'mental'))*.008,.25,.75),side=Math.random()<prob?0:1;l.score[side]+=3;l.stats[side].goals++;l.stats[side].goalAttempts++;addEvent(l,`Prolongation simplifiée : ${S.clubs[l.pair[side]].abbr} passe la pénalité décisive.`,'goal',{kind:'goal',team:side,to:{x:attackingGoal(side),y:35}})}
 l.finished=true;l.paused=false;addEvent(l,'Coup de sifflet final.','end');
}

function eventClock(l,event){if(!flowRules(l)||event.period===undefined)return `${event.min}′`;const n=event.period===1?event.min:40+event.min-l.flow.firstEnd,limit=event.period===1?40:80;return n>limit?`${limit}+${n-limit}′`:`${n}′`}
