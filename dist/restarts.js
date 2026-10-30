'use strict';
// Atomic match sequences, pinned to the 2025 laws. The clock/advantage engine
// remains separate; each restart has a cause, beneficiary and longitudinal mark.
const RESTART_AUTH=new WeakMap();
const RESTART_CAUSES={scrum:['knock-on','forward-pass','kick-dead-option','defender-grounded'],lineout:['carry-touch','indirect-touch','direct-touch','penalty-touch','50-22','missed-goal-touch'],kickoff:['start','second-half','score'],drop22:['missed-goal-dead','kick-dead'],goalLine:['held-up','attacking-kick-grounded','ingoal-knock-on']};
function restartRules(l){return l.restartVersion===1}
function ownGoal(side){return side===0?0:100}
function attackingGoal(side){return ownGoal(1-side)}
function ownHalf(side,at){return side===0?at<50:at>50}
function own22(side,at){return side===0?at<=22:at>=78}
function ballPossession(l,side,at=l.territory){l.possession=side;l.territory=at;if(restartRules(l))l.kickContext={team:side,halfEligible:ownHalf(side,at),twentyTwoEligible:own22(side,at)}}
function initializeRestarts(l){l.restartVersion=1;l.restartLog=[];l.firstKickoff=l.possession;ballPossession(l,l.possession);addEvent(l,`Coup d’envoi. Météo : ${l.weather.toLowerCase()}.`);performKickRestart(l,'kickoff',l.firstKickoff,'start',1-l.firstKickoff)}
function registerRestart(l,kind,team,at,cause,by,origin=l.territory){
 if(!restartRules(l)||l.finished||!Number.isFinite(origin)||origin<0||origin>100||!RESTART_CAUSES[kind]?.includes(cause)||![0,1].includes(team)||![0,1].includes(by)||!Number.isFinite(at)||at<0||at>100)return null;
 if(team!==(['penalty-touch','50-22'].includes(cause)?by:1-by))return null;
 if(!flowBeforeRestart(l,kind,cause,at))return null;
 const r={kind,team,at,cause,by,origin,minute:l.minute};l.restartLog.push(r);if(l.restartLog.length>300)l.restartLog.shift();return r;
}
function grantSetPiece(l,kind,team,at,cause,by,origin=l.territory){
 if(!['scrum','lineout'].includes(kind))return false;
 const mark=clamp(at,5,95),r=registerRestart(l,kind,team,mark,cause,by,origin);if(!r)return false;
 l.territory=mark;l.possession=team;addEvent(l,`${S.clubs[l.pair[team]].abbr} prépare ${kind==='scrum'?'la mêlée, introduction à suivre':'la touche, lancer à suivre'}.`,'setup',{kind,team,from:{x:mark,y:kind==='lineout'?4:35},to:{x:mark,y:kind==='lineout'?4:35}});RESTART_AUTH.set(l,r);
 try{contestSetPiece(l,team,kind,cause==='penalty-touch')}finally{RESTART_AUTH.delete(l)}
 ballPossession(l,l.possession,l.territory);return true;
}
function authorizeSetPiece(l,team,kind){const r=RESTART_AUTH.get(l);if(!r||r.kind!==kind||r.team!==team)return false;RESTART_AUTH.delete(l);return true}
function performKickRestart(l,kind,team,cause,by){
 const at=kind==='kickoff'?50:kind==='drop22'?(team===0?22:78):ownGoal(team);
 if(!registerRestart(l,kind,team,at,cause,by))return false;
 const name=kind==='kickoff'?(cause==='start'?'coup d’envoi':cause==='second-half'?'coup d’envoi de la seconde période':'renvoi au centre'):kind==='drop22'?'renvoi aux 22 mètres':'drop de renvoi sur la ligne d’essai';
 const policy=kickoffPolicy(l,team,kind),kicker=actionPlayer(l,team,'kicker');addEvent(l,`${kicker?.name||S.clubs[l.pair[team]].abbr} (${S.clubs[l.pair[team]].abbr}) effectue le ${name}${cause==='score'?' après les points encaissés':''}${policy.choice!=='normal'?' · '+KICKOFF_MOVES[policy.choice][0].toLowerCase():''}.`,'restart',{kind,team,actor:kicker?.id||null,from:{x:at,y:35},to:{x:at,y:35},possession:team,move:policy.choice});
 const distance=policy.distance?rand(...policy.distance):kind==='kickoff'?rand(15,25):kind==='drop22'?rand(20,32):rand(18,30),landing=clamp(at+(team===0?1:-1)*distance,1,99);
 const retain=Math.random()<clamp(.12+policy.retain+(unit(l,team,'kick')-unit(l,1-team,'mental'))*.002,.05,.22);
 ballPossession(l,retain?team:1-team,landing);const receiver=actionPlayer(l,l.possession,'receiver');addEvent(l,`${receiver?.name||S.clubs[l.pair[l.possession]].abbr} (${S.clubs[l.pair[l.possession]].abbr}) récupère le ballon à la réception.`,'play',{kind:'reception',team:l.possession,actor:receiver?.id||null,from:{x:at,y:35},to:{x:landing,y:35}});return true;
}
function handFault(l,offender,forward=false){
 tacticalCount(l,offender,'handErrors');const at=l.territory;if(flowRules(l)&&offerAdvantage(l,'scrum',1-offender,offender,at))return true;addEvent(l,`${S.clubs[l.pair[offender]].abbr} commet ${forward?'une passe en avant':'un en-avant'} : introduction adverse.`,'play',{kind:'hand-fault',team:offender});
 return grantSetPiece(l,'scrum',1-offender,at,forward?'forward-pass':'knock-on',offender);
}
function resolveTouch(l,actor,exit,{direct=false,penalty=false,carried=false}={}){
 const origin=l.territory,context=l.kickContext;
 const fifty=!penalty&&!carried&&!direct&&ownHalf(actor,origin)&&(actor===0?exit>=78:exit<=22)&&context?.team===actor&&context.halfEligible;
 const gain=penalty||!direct||own22(actor,origin)&&context?.team===actor&&context.twentyTwoEligible;
 const mark=gain?exit:(actor===0?Math.min(origin,exit):Math.max(origin,exit));
 const team=penalty||fifty?actor:1-actor,cause=penalty?'penalty-touch':fifty?'50-22':carried?'carry-touch':direct?'direct-touch':'indirect-touch';
 addEvent(l,`${S.clubs[l.pair[actor]].abbr} ${penalty?'trouve la pénaltouche et conserve le lancer':fifty?'réussit un 50:22 et conserve le lancer':carried?'est poussé en touche':direct&&!gain?'botte directement en touche sans gain de terrain':'envoie le ballon en touche'}.`,'play',{kind:'touch',team:actor,from:{x:origin,y:35},to:{x:exit,y:0}});
 return grantSetPiece(l,'lineout',team,mark,cause,actor,origin);
}
function resolveInGoal(l,actor,scenario,kickOrigin=l.territory){
 const defender=1-actor;
 if(scenario==='defender-grounded'){addEvent(l,`${S.clubs[l.pair[actor]].abbr} a rentré le ballon dans son propre en-but et l’y rend mort : mêlée adverse à cinq mètres.`,'play',{kind:'ingoal',team:actor,to:{x:ownGoal(actor),y:35}});return grantSetPiece(l,'scrum',1-actor,ownGoal(actor)+(actor===0?5:-5),'defender-grounded',actor,kickOrigin)}
 if(['held-up','attacking-kick-grounded','ingoal-knock-on'].includes(scenario)){
  addEvent(l,scenario==='held-up'?'Le porteur attaquant est tenu dans l’en-but sans pouvoir aplatir.':scenario==='ingoal-knock-on'?'En-avant de l’attaque dans l’en-but.':'Le coup de pied de l’attaque est aplati par la défense dans son en-but.','play',{kind:'ingoal',team:actor,to:{x:attackingGoal(actor),y:35}});
  return performKickRestart(l,'goalLine',defender,scenario,actor);
 }
 if(scenario==='kick-dead'){
  addEvent(l,`${S.clubs[l.pair[actor]].abbr} botte le ballon au-delà de l’en-but adverse.`,'play',{kind:'ingoal',team:actor,from:{x:kickOrigin,y:35},to:{x:attackingGoal(actor),y:35}});
  const distanceFromOwnGoal=Math.abs(kickOrigin-ownGoal(defender));
  if(distanceFromOwnGoal>=30){addEvent(l,`${S.clubs[l.pair[defender]].abbr} choisit la mêlée à l’endroit du coup de pied.`);return grantSetPiece(l,'scrum',defender,kickOrigin,'kick-dead-option',actor,kickOrigin)}
  return performKickRestart(l,'drop22',defender,'kick-dead',actor);
 }
 return false;
}
function missedGoal(l,side){
 const outcome=Math.random();
 if(outcome<.6){addEvent(l,'Le tir au but manqué devient mort au-delà de la ligne d’essai.','play',{kind:'miss',team:side,to:{x:attackingGoal(side),y:35}});return performKickRestart(l,'drop22',1-side,'missed-goal-dead',side)}
 if(outcome<.8){const at=side===0?95:5;addEvent(l,'Le tir au but manqué sort en touche : lancer à la défense.','play',{kind:'touch',team:side,to:{x:at,y:0}});return grantSetPiece(l,'lineout',1-side,at,'missed-goal-touch',side)}
 const landing=side===0?rand(82,97):rand(3,18);ballPossession(l,1-side,landing);addEvent(l,`${S.clubs[l.pair[1-side]].abbr} récupère le tir manqué resté dans le champ de jeu.`,'play',{kind:'reception',team:1-side,actor:actionPlayer(l,1-side,'receiver')?.id||null,to:{x:landing,y:35}});return true;
}
function kickOpenPlay(l,side){
 tacticalCount(l,side,'kicks');
 const dir=side===0?1:-1,origin=l.territory,distance=clamp(12+(unit(l,side,'kick',p=>p.fam>=4)-60)*.5+rand(-8,10)+collectivePreparationBonus(l,side,'pied')-(l.weather==='Vent'?9:0),3,45),landing=origin+dir*distance;
 const outcome=Math.random();
 if(landing<=0||landing>=100)return resolveInGoal(l,side,outcome<.5?'attacking-kick-grounded':'kick-dead',origin);
 if(outcome<.23)return resolveTouch(l,side,landing,{direct:true});
 if(outcome<.58)return resolveTouch(l,side,landing);
 ballPossession(l,1-side,landing);addEvent(l,`${actionName(l,side,'kicker')} (${S.clubs[l.pair[side]].abbr}) gagne ${Math.round(distance)} mètres au pied ; ${actionName(l,1-side,'receiver')} réceptionne pour ${S.clubs[l.pair[1-side]].abbr}.`,'play',{kind:'kick',team:side,actor:actionPlayer(l,side,'kicker')?.id||null,from:{x:origin,y:35},to:{x:landing,y:35}});return true;
}
function advanceCausalPlay(l){
 const side=l.possession,opp=1-side,origin=l.territory,roll=Math.random(),penaltyProb=clamp(.12+(70-unit(l,opp,'discipline'))*.002+tacticalPenaltyAdjustment(l,opp),tacticalRules(l)?.04:.06,tacticalRules(l)?.28:.23),handProb=handFaultProbability(l,side);
 if(roll<penaltyProb)return awardPenalty(l,side);
 if(roll<penaltyProb+handProb)return handFault(l,side);
 if(roll<penaltyProb+handProb+.12)return resolveTouch(l,side,l.territory,{carried:true});
 if((tacticalRules(l)||effectiveAttack(l,side)==='occupation')&&Math.random()<openKickProbability(l,side))return kickOpenPlay(l,side);
 tacticalCount(l,side,'carries');const edge=teamEdge(l,side,'attack'),success=Math.random()<clamp(.49+edge,.18,.84);
 if(success){
  l.territory=clamp(l.territory+(side===0?1:-1)*carryGain(l,side),1,99);tacticalCount(l,side,'advances');const metres=Math.abs(l.territory-origin);tacticalCount(l,side,'metres',metres);if(metres>=22)tacticalCount(l,side,'longGains');
  // The completed carrying sequence includes a tackle/ruck, resetting kick eligibility.
  l.kickContext={team:side,halfEligible:ownHalf(side,l.territory),twentyTwoEligible:own22(side,l.territory)};
  const danger=side===0?l.territory>74:l.territory<26;
  if(danger&&Math.random()<clamp(.36+edge+tacticalFinishAdjustment(l,side),tacticalRules(l)?.12:.16,tacticalRules(l)?.78:.75)){
   const finish=Math.random();if(finish<.08)return resolveInGoal(l,side,'held-up');if(finish<.12)return resolveInGoal(l,side,'ingoal-knock-on');
   return scoreTry(l,side,'open',origin);
  }
  const plan=effectiveAttack(l,side)==='conquete'?' au près':effectiveAttack(l,side)==='large'?' sur une séquence de jeu au large':'';const carrier=actionPlayer(l,side),gain=Math.round(Math.abs(l.territory-origin));const phrases=[`${carrier?.name||S.clubs[l.pair[side]].abbr} porte le ballon et gagne ${gain} mètres`,`${carrier?.name||S.clubs[l.pair[side]].abbr} avance de ${gain} mètres avant le plaquage`,`${S.clubs[l.pair[side]].abbr} progresse de ${gain} mètres par ${carrier?.name||'son porteur'}`];addEvent(l,`${phrases[l.minute%phrases.length]}${plan}${danger?' dans les 22 adverses':''}.`,'play',{kind:'carry',team:side,actor:carrier?.id||null,from:{x:origin,y:35},to:{x:l.territory,y:35}});
 }else if(Math.random()<failedCarryError(l,side))return handFault(l,side);
 else{tacticalCount(l,opp,'recoveries');ballPossession(l,opp);addEvent(l,`${actionName(l,opp,'defender')} récupère le ballon après le plaquage pour ${S.clubs[l.pair[opp]].abbr}.`,'turnover',{kind:'turnover',team:opp,actor:actionPlayer(l,opp,'defender')?.id||null})}
}
