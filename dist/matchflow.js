'use strict';
function flowRules(l){return restartRules(l)&&l.flowVersion===1}
function initializeMatchFlow(l){l.advantageModel=2;l.flowVersion=1;l.flow={period:1,firstEnd:null,fullEnd:null,atBreak:false,ballDead:false,advantage:null,resolvingAward:false};if(QUICK_TAP_RULES)l.quickTapVersion=1}
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
 if(expired&&!l.flow.advantage&&(l.minute>=periodBoundary(l)+4||l.flow.period===2&&margin>=0&&l.minute>periodBoundary(l))){addEvent(l,`${S.clubs[l.pair[l.possession]].abbr} envoie le ballon en touche pour terminer la période.`,'play',{kind:'touch',team:l.possession,cause:'period-end',to:{x:l.territory,y:0}});endFlowPeriod(l);return}
 advanceCausalPlay(l);settleAdvantage(l);
}
function finishRugbyMatch(l){
 if(l.franceContext){if(CDFranceKnockout.finish(l))return;}
 else if(S.phase!=='league'&&l.score[0]===l.score[1]){const prob=clamp(.5+(unit(l,0,'mental')-unit(l,1,'mental'))*.008,.25,.75),side=Math.random()<prob?0:1;l.score[side]+=3;l.stats[side].goals++;l.stats[side].goalAttempts++;addEvent(l,`Prolongation simplifiée : ${S.clubs[l.pair[side]].abbr} passe la pénalité décisive.`,'goal',{kind:'goal',team:side,to:{x:attackingGoal(side),y:35}})}
 l.finished=true;l.paused=false;addEvent(l,'Coup de sifflet final.','end');
}

function eventClock(l,event){if(!flowRules(l)||event.period===undefined)return `${event.min}′`;const n=event.period===1?event.min:40+event.min-l.flow.firstEnd,limit=event.period===1?40:80;return n>limit?`${limit}+${n-limit}′`:`${n}′`}

// Pénalité jouée vite à la main (loi 20 : l'équipe qui bénéficie de la pénalité peut la
// jouer d'un coup de pied au point de la faute, puis courir ou passer). Troisième choix à côté
// du tir au but et de la pénaltouche, pour les rencontres créées avec `quickTapVersion` (les
// matchs commencés avant gardent leurs règles). La décision ne consomme aucun tirage : sans
// pénalité jouée à la main, la suite des tirages est celle d'avant. Coefficients choisis pour
// le jeu (ordres de grandeur : minorité des pénalités, surtout près de la ligne quand on est
// mené), non mesurés.
let QUICK_TAP_RULES=1;
function quickTapRules(l){return flowRules(l)&&l.quickTapVersion===1}
// Le demi de mêlée joue la pénalité ; à défaut, le premier troisième ligne en jeu.
function quickTapper(l,side){const on=activePlayers(l,side),id=l.sheets[side].on[8];return on.find(p=>p.id===id)||on.find(p=>p.fam===4)||on.find(p=>p.fam===3)||on[0]||null}
// Porteur après la pénalité jouée : un avant près de la ligne, sinon un joueur lancé (troisième ligne, centre, ailier).
function quickTapCarrier(l,side,near){const on=activePlayers(l,side).filter(p=>p.id!==quickTapper(l,side)?.id),pool=on.filter(p=>near?p.fam>=1&&p.fam<=3:p.fam===3||p.fam===6||p.fam===7);const list=pool.length?pool:on;return list.length?list[(l.minute+side*3)%list.length]:null}
// Probabilité de jouer vite selon le contexte. Repère déterministe (minute, pénalités) : aucun tirage.
function quickTapWeight(l,side,distance){
 if(distance<=0||distance>=97)return 0;
 const tapper=quickTapper(l,side);if(!tapper)return 0;
 const minute=matchMinute(l),diff=l.score[side]-l.score[1-side];
 let w=distance<=6?.3:distance<=12?.22:distance<=22?.12:distance<=50?.1:.05;
 // Mené : plus souvent, surtout en fin de match près de la ligne quand trois points ne suffisent pas.
 if(diff<0)w*=minute>=60?(diff<-3?(distance<=12?2.6:1.9):1.4):1.25;
 else if(diff>0&&minute>=60)w*=diff>7?.3:.5;
 // Une pénalité facile à trois points, à score serré : on prend les points le plus souvent.
 if(distance<=30&&diff>=-3&&wantsPosts(l,side,distance))w*=distance<=12&&diff<0?.7:.4;
 const plan=effectiveAttack(l,side);w*=plan==='large'?1.45:plan==='conquete'?.65:plan==='occupation'?.5:1;
 // Profil de ceux qui décident : vivacité du demi, sang-froid de l'ouvreur.
 const ouvreur=activePlayers(l,side).find(p=>p.id===l.sheets[side].on[9]);
 w*=clamp(.6+((skill(tapper,'speed',true)+skill(tapper,'mental',true))/2-55)*.012+((ouvreur?skill(ouvreur,'mental',true):60)-60)*.006,.55,1.5);
 if(l.weather==='Pluie')w*=.75;
 // Supériorité numérique : on accélère le jeu.
 w*=1+clamp((activePlayers(l,side).length-activePlayers(l,1-side).length)*.15,-.3,.45);
 return clamp(w,0,.6);
}
function wantsQuickTap(l,side,distance){
 const policy=l.penaltyPolicies?.[side]||'auto';
 // Un carton arrête le jeu : la pénalité ne peut pas être jouée vite (choix de simulation).
 if(l.events.at(-1)?.type==='card')return false;
 if(policy==='main')return distance>0&&!!quickTapper(l,side);
 if(policy!=='auto')return false;
 const repere=((l.minute*37+l.stats[1-side].penalties*53+side*11+l.score[side]*7)%100)/100;
 return repere<quickTapWeight(l,side,distance);
}
// La pénalité jouée à la main : jeu courant rapide contre une défense pas encore replacée à
// dix mètres. Issues : percée (parfois l'essai), gain ordinaire, ou ballon perdu (gratté,
// tenu dans l'en-but, en-avant).
function playQuickTap(l,side){
 const opp=1-side,dir=side===0?1:-1,origin=l.territory,distance=side===0?100-origin:origin,near=distance<=12;
 const tapper=quickTapper(l,side),abbr=S.clubs[l.pair[side]].abbr,y=l.events.at(-1)?.scene?.to?.y??35;
 l.quickTaps=l.quickTaps||[0,0];l.quickTaps[side]++;
 addEvent(l,`${tapper?.name||abbr} (${abbr}) joue vite la pénalité à la main.`,'play',{kind:'quick-tap',team:side,actor:tapper?.id||null,from:{x:origin,y},to:{x:origin,y},possession:side});
 tacticalCount(l,side,'carries');
 const edge=teamEdge(l,side,'attack'),defence=effectiveDefence(l,opp);
 // Défense mal replacée : l'écart entre la vivacité du demi et l'organisation adverse.
 const surprise=clamp(((tapper?skill(tapper,'speed',true):60)-unit(l,opp,'mental'))*.004,-.06,.08)+(defence==='pression'?.02:defence==='prudente'?-.03:0);
 const lose=(why)=>{
  l.quickTapLog?.push({side,minute:l.minute,issue:why});
  if(why==='en-avant')return handFault(l,side);
  if(why==='tenu')return resolveInGoal(l,side,'held-up');
  tacticalCount(l,opp,'recoveries');ballPossession(l,opp);
  addEvent(l,`${actionName(l,opp,'defender')} récupère le ballon sur la pénalité jouée vite pour ${S.clubs[l.pair[opp]].abbr}.`,'turnover',{kind:'turnover',team:opp,actor:actionPlayer(l,opp,'defender')?.id||null});
 };
 const roll=Math.random();
 if(near){
  const pTry=clamp(.32+edge+surprise+(unit(l,side,'power',p=>p.fam<=3)-unit(l,opp,'tackle'))*.003,.16,.55),pLoss=clamp(.27-edge*.5-surprise,.14,.4);
  if(roll<pTry){l.quickTapLog?.push({side,minute:l.minute,issue:'essai'});return scoreTry(l,side,'open',origin)}
  if(roll<pTry+pLoss){const r=Math.random();return lose(r<.3?'tenu':r<.75?'gratte':'en-avant')}
  const carrier=quickTapCarrier(l,side,true),gain=clamp(rand(1,4),1,Math.max(1,distance-1));
  l.territory=clamp(origin+dir*gain,1,99);
  l.quickTapLog?.push({side,minute:l.minute,issue:'gain'});
 }else{
  const pBreak=clamp(.15+edge+surprise,.07,.32),pLoss=clamp(.2-edge*.5-surprise+(l.weather==='Pluie'?.04:0),.1,.33);
  if(roll<pBreak+pLoss&&roll>=pBreak){const r=Math.random();return lose(r<.55?'gratte':'en-avant')}
  const breakthrough=roll<pBreak,gain=breakthrough?rand(22,38):rand(5,14);
  l.territory=clamp(origin+dir*gain,1,99);
  const danger=side===0?l.territory>74:l.territory<26;
  if(breakthrough&&danger&&Math.random()<clamp(.36+edge,.16,.75)){l.quickTapLog?.push({side,minute:l.minute,issue:'essai'});return scoreTry(l,side,'open',origin)}
  l.quickTapLog?.push({side,minute:l.minute,issue:breakthrough?'percee':'gain'});
 }
 const metres=Math.abs(l.territory-origin);tacticalCount(l,side,'advances');tacticalCount(l,side,'metres',metres);if(metres>=22)tacticalCount(l,side,'longGains');
 l.kickContext={team:side,halfEligible:ownHalf(side,l.territory),twentyTwoEligible:own22(side,l.territory)};
 const carrier=quickTapCarrier(l,side,near),gain=Math.round(metres),danger=side===0?l.territory>74:l.territory<26;
 addEvent(l,`${carrier?.name||abbr} prend la défense de vitesse et gagne ${gain} mètre${gain>1?'s':''}${danger?' dans les 22 adverses':''}.`,'play',{kind:'carry',team:side,actor:carrier?.id||null,tackler:carrier?carryTackler(l,side,carrier.id,gain):null,from:{x:origin,y},to:{x:l.territory,y},possession:side});
}
