'use strict';
// Atomic match sequences, pinned to the 2025 laws. The clock/advantage engine
// remains separate; each restart has a cause, beneficiary and longitudinal mark.
const RESTART_AUTH=new WeakMap();
const RESTART_CAUSES={scrum:['knock-on','forward-pass','kick-dead-option','defender-grounded','penalty-scrum','unplayable'],lineout:['carry-touch','indirect-touch','direct-touch','penalty-touch','50-22','missed-goal-touch'],kickoff:['start','second-half','score','extra-first','extra-second'],drop22:['missed-goal-dead','kick-dead'],goalLine:['held-up','attacking-kick-grounded','ingoal-knock-on']};
function restartRules(l){return l.restartVersion===1}
function ownGoal(side){return side===0?0:100}
function attackingGoal(side){return ownGoal(1-side)}
function ownHalf(side,at){return side===0?at<50:at>50}
function own22(side,at){return side===0?at<=22:at>=78}
function ballPossession(l,side,at=l.territory){l.possession=side;l.territory=at;if(restartRules(l))l.kickContext={team:side,halfEligible:ownHalf(side,at),twentyTwoEligible:own22(side,at)}}
function initializeRestarts(l){l.restartVersion=1;l.restartLog=[];l.firstKickoff=l.possession;ballPossession(l,l.possession);addEvent(l,`Coup d’envoi. Météo : ${meteoLibelle(l)}.`);performKickRestart(l,'kickoff',l.firstKickoff,'start',1-l.firstKickoff)}
function registerRestart(l,kind,team,at,cause,by,origin=l.territory){
 if(['extra-first','extra-second'].includes(cause)&&!l.franceContext&&!l.worldContext)return null;
 if(!restartRules(l)||l.finished||!Number.isFinite(origin)||origin<0||origin>100||!RESTART_CAUSES[kind]?.includes(cause)||![0,1].includes(team)||![0,1].includes(by)||!Number.isFinite(at)||at<0||at>100)return null;
 if(team!==(['penalty-touch','50-22'].includes(cause)?by:1-by))return null;
 if(!flowBeforeRestart(l,kind,cause,at,by))return null;
 const r={kind,team,at,cause,by,origin,minute:l.minute};l.restartLog.push(r);if(l.restartLog.length>300)l.restartLog.shift();return r;
}
function grantSetPiece(l,kind,team,at,cause,by,origin=l.territory){
 if(!['scrum','lineout'].includes(kind))return false;
 const mark=clamp(at,5,95),r=registerRestart(l,kind,team,mark,cause,by,origin);if(!r)return false;
 l.territory=mark;l.possession=team;addEvent(l,`${S.clubs[l.pair[team]].abbr} prépare ${kind==='scrum'?'la mêlée, introduction à suivre':'la touche, lancer à suivre'}.`,'setup',{kind,team,from:{x:mark,y:kind==='lineout'?4:35},to:{x:mark,y:kind==='lineout'?4:35}});
 if(coupFrancConquete(l,team,kind))return true;
 RESTART_AUTH.set(l,r);
 try{contestSetPiece(l,team,kind,cause==='penalty-touch')}finally{RESTART_AUTH.delete(l)}
 ballPossession(l,l.possession,l.territory);return true;
}
function authorizeSetPiece(l,team,kind){const r=RESTART_AUTH.get(l);if(!r||r.kind!==kind||r.team!==team)return false;RESTART_AUTH.delete(l);return true}
function performKickRestart(l,kind,team,cause,by){
 const at=kind==='kickoff'?50:kind==='drop22'?(team===0?22:78):ownGoal(team);
 if(!registerRestart(l,kind,team,at,cause,by))return false;
 const name=kind==='kickoff'?(cause==='start'?'coup d’envoi':cause==='second-half'?'coup d’envoi de la seconde période':'renvoi au centre'):kind==='drop22'?'renvoi aux 22 mètres':'drop de renvoi sur la ligne d’essai';
 const policy=kickoffPolicy(l,team,kind),kicker=actionPlayer(l,team,'kicker');addEvent(l,`${kicker?.name||S.clubs[l.pair[team]].abbr} (${S.clubs[l.pair[team]].abbr}) effectue le ${name}${cause==='score'?' après les points encaissés':''}${policy.choice!=='normal'?' · '+KICKOFF_MOVES[policy.choice][0].toLowerCase():''}.`,'restart',{kind,team,actor:kicker?.id||null,from:{x:at,y:35},to:{x:at,y:35},possession:team,move:policy.choice});
 const pr=l.pilotage&&typeof pilotageRenvoi==='function'?pilotageRenvoi(l,team):{distance:1,garde:0};
 const distance=Math.round((policy.distance?rand(...policy.distance):kind==='kickoff'?rand(15,25):kind==='drop22'?rand(20,32):rand(18,30))*pr.distance)+(policy.extra||0),landing=clamp(at+(team===0?1:-1)*distance,1,99);
 const retain=Math.random()<clamp(.12+policy.retain+pr.garde+(unit(l,team,'kick')-unit(l,1-team,'mental'))*.002,pr.garde<0?.03:.05,(pr.garde>0?.36:.22)+(policy.plafond||0));
 ballPossession(l,retain?team:1-team,landing);let receiver=actionPlayer(l,l.possession,'receiver');
 // Ballon repris par l'équipe qui botte : un partenaire qui a suivi le coup de pied, jamais le botteur lui-même
 // (il botte du centre, le ballon tombe 15 à 25 m plus loin ; le chorégraphe ne peut pas mettre en scène un botteur receveur).
 if(retain&&kicker&&receiver?.id===kicker.id){const others=activePlayers(l,team).filter(p=>p.id!==kicker.id),chasers=others.filter(p=>p.fam>=6),pool=chasers.length?chasers:others;if(pool.length)receiver=pool[(l.minute+team)%pool.length];}
 addEvent(l,retain?`Renvoi court : ${receiver?.name||S.clubs[l.pair[l.possession]].abbr} (${S.clubs[l.pair[l.possession]].abbr}) reprend le ballon pour l’équipe qui l’a botté.`:`${receiver?.name||S.clubs[l.pair[l.possession]].abbr} (${S.clubs[l.pair[l.possession]].abbr}) récupère le ballon à la réception.`,'play',{kind:'reception',team:l.possession,actor:receiver?.id||null,from:{x:at,y:35},to:{x:landing,y:35}});return true;
}
function handFault(l,offender,forward=false){
 // Le récit de la faute précède toujours l'avantage : « X commet un en-avant », puis « Avantage sur en-avant pour Y ».
 // En-avant juste après un coup de pied pris par l'équipe fautive (chandelle relâchée, ballon ramassé puis échappé) : le
 // receveur nommé au coup de pied commet la faute, à l'écran comme dans le récit. Aucun tirage. Une faute de main juste
 // à la réception est toujours un en-avant du receveur, jamais une passe en avant (tirage de l'appelant ignoré).
 const ab=S.clubs[l.pair[offender]].abbr,porteur=actionPlayer(l,offender),recu=kickReceivedBy(l,offender);if(recu)forward=false;
 const qui=recu?`${recu.name} (${ab}) commet un en-avant à la réception`:`${ab} commet ${forward?'une passe en avant':'un en-avant'}`,actor=recu?recu.id:porteur?.id||null;
 const narrate=()=>addEvent(l,`${qui}.`,'play',{kind:'hand-fault',team:offender,cause:forward?'forward-pass':'knock-on',actor});
 tacticalCount(l,offender,'handErrors');const at=l.territory;if(flowRules(l)&&offerAdvantage(l,'scrum',1-offender,offender,at,{narrate,passe:forward}))return true;addEvent(l,`${qui} : introduction adverse.`,'play',{kind:'hand-fault',team:offender,cause:forward?'forward-pass':'knock-on',actor});
 return grantSetPiece(l,'scrum',1-offender,at,forward?'forward-pass':'knock-on',offender);
}
// Receveur adverse du coup de pied qui vient d'être raconté (même minute, rien de joué entre les deux), sinon null.
function kickReceivedBy(l,side){
 for(let i=l.events.length-1;i>=0;i--){
  const e=l.events[i];if(['sub','tactic','message'].includes(e.type))continue;
  const s=e.scene;if(e.min!==l.minute||s?.kind!=='kick'||s.team===side||s.possession!==side||s.receiver==null)return null;
  return activePlayers(l,side).find(p=>String(p.id)===String(s.receiver))||null;
 }
 return null;
}
// Lois manquantes (docs/lois-manquantes-20261126.md) : coups francs, passes en avant, essais de pénalité, drops.
// Coup franc (loi 20, 2025) : jeu rapide à la main ou coup de pied ; ni tir au but (pas de drop avant que le ballon soit
// mort ou joué par l'adversaire), ni mêlée (loi 20.3 : l'option mêlée n'existe que sur pénalité) ; touche directe :
// lancer adverse, gain de terrain seulement depuis ses 22 ; pas de 50:22. Fautes techniques de conquête : loi 19
// (engagement anticipé, introduction, talonnage, mêlée formée en 30 s) et loi 18 (couloir, sauteur soutenu avant le
// lancer, alignement formé en 30 s). Passe en avant (loi 11) : mêlée adverse, avantage possible. Essai de pénalité
// (loi 8) : faute qui empêche un essai probable, 7 points sans transformation, carton jaune du fautif. Drop (loi 8) :
// 3 points, par l'ouvreur, surtout en fin de match serré. Fréquences : réglages de simulation calés sur la mesure (réel
// élite par match : coups francs 3-5, passes en avant 2-4, essais de pénalité 0,07-0,15, drops tentés ~0,2).
// coupFranc : par mêlée / touche formée ; passeAvant : part des fautes de main ; essaiPenalite : à `distance` m au plus de
// la ligne, faute de mêlée ou de ballon porté (conquete) ou dans le jeu ; drop : zone (m de la ligne), base par action,
// fin (dès `minute`, mené de `ecart` points au plus ou à égalité), reussite à 22 m pour un botteur de 70, perte par mètre.
let LOIS_RULES=1;
var LOIS={coupFranc:{melee:.17,touche:.09},passeAvant:.16,injouable:.25,essaiPenalite:{distance:7,conquete:.3,jeu:.08},
 drop:{zone:[14,35],base:.012,fin:.35,minute:72,ecart:3,plie:{mene:7,avance:14},reussite:.6,parMetre:.012}};
function loisRules(l){return !!LOIS_RULES&&typeof penalitesRules==='function'&&penalitesRules(l)}
function passeEnAvant(l){return loisRules(l)&&Math.random()<LOIS.passeAvant}
const COUP_FRANC_MOTIFS={scrum:['engagement anticipé en mêlée','introduction pas droite','talonnage avant l’introduction','mêlée pas formée dans les 30 secondes'],lineout:['couloir fermé dans l’alignement','sauteur soutenu avant le lancer','alignement pas formé dans les 30 secondes']};
// Coup franc sur faute technique, tiré quand la mêlée ou la touche est prête (avant la pénalité de conquête).
// Temps écoulé (sirène) : aucun coup franc, avant tout tirage ; la mêlée ou la touche due après la sirène reste la
// dernière action annoncée, disputée puis close comme avant les lois manquantes (sinon un coup franc joué vite relançait
// la période après « dernière action avant le changement de camp »).
function coupFrancConquete(l,team,kind){
 if(!loisRules(l)||l.restartLog?.some(r=>r.kind==='kickoff'&&r.minute===l.minute))return false;
 if(typeof periodBoundary==='function'&&flowRules(l)&&l.minute>=periodBoundary(l))return false;
 if(kind==='scrum'&&l.sheets.some(sh=>sh.front?.uncontested))return false;
 if(Math.random()>=LOIS.coupFranc[kind==='scrum'?'melee':'touche'])return false;
 const side=Math.random()<.5?team:1-team,motifs=COUP_FRANC_MOTIFS[kind],motif=motifs[(l.minute+coupFrancRang(l))%motifs.length];
 // Mêlée ou touche formée puis arrêtée sur le coup franc : comptée comme jouée (comme une pénalité de conquête).
 l.stats[team][kind==='scrum'?'scrums':'lineouts']++;
 addEvent(l,`Coup franc pour ${S.clubs[l.pair[side]].abbr} : ${motif} (${S.clubs[l.pair[1-side]].abbr}).`,'play',{kind:'message',team:side,loi:'coup-franc'});
 // Mêlée ou touche accordée et jouée en coup franc : la suite (touche, coup de pied, fin de période à la sirène) ne
 // la fait jamais passer pour refusée (sinon une pénalité « mêlée » retomberait en pénaltouche après le sifflet).
 jouerCoupFranc(l,side);return true;
}
// Motif sans tirage, lu dans l'état du moteur (mêlées et touches jouées) et jamais dans le journal : le découpage des
// longues courses (MATCH_COURSES_DECOUPEES) ajoute des faits au journal sans changer le jeu, le motif doit rester le même.
function coupFrancRang(l){return l.stats.reduce((n,s)=>n+(s.scrums||0)+(s.lineouts||0),0)}
// Taper ou jouer vite suit le plan de jeu au pied du bénéficiaire (pilotage : jeu au pied, relance, rythme, fin de match,
// consignes individuelles « Jouer au pied »), comme le jeu au pied courant (openKickProbability) ; sans pilotage
// (IA contre IA), facteur 1 : mêmes probabilités et mêmes tirages.
function jouerCoupFranc(l,side){
 const at=l.territory,dir=side===0?1:-1,ab=S.clubs[l.pair[side]].abbr,d=Math.abs(at-ownGoal(side));
 const pied=typeof pilotageKick==='function'&&l.pilotage?pilotageKick(l,side):1;
 ballPossession(l,side,at);
 if(d<=22&&Math.random()<clamp(.85*pied,.3,.97)){
  // Dégagement en touche depuis ses 22 : gain de terrain, lancer adverse.
  l.kickContext={team:side,halfEligible:false,twentyTwoEligible:true};tacticalCount(l,side,'kicks');
  return resolveTouch(l,side,clamp(at+dir*rand(18,32),5,95),{direct:true,kicker:occupationKicker(l,side)});
 }
 if(d>22&&d<50&&Math.random()<clamp(.45*pied,.1,.85)){l.kickContext={team:side,halfEligible:false,twentyTwoEligible:false};return kickOpenPlay(l,side)}
 // Jeu rapide à la main : le demi de mêlée joue le coup franc, un partenaire avance (défense repliée à dix mètres).
 const tapper=quickTapper(l,side),carrier=actionPlayer(l,side)||tapper,g=rand(2,7),to=clamp(at+dir*g,1,99);
 tacticalCount(l,side,'carries');l.territory=to;l.kickContext={team:side,halfEligible:ownHalf(side,to),twentyTwoEligible:own22(side,to)};
 addEvent(l,`${tapper?.name||ab} (${ab}) joue vite le coup franc ; ${carrier?.name||ab} avance de ${g} mètres.`,'play',{kind:'carry',team:side,actor:carrier?.id||null,tackler:carrier?carryTackler(l,side,carrier.id,g):null,loi:'coup-franc-joue',from:{x:at,y:35},to:{x:to,y:35}});
 return true;
}
// Faute qui empêche un essai probable (loi 8) : près de la ligne, surtout en mêlée ou sur ballon porté.
function essaiPenaliteProbable(l,side,incident){
 if(!loisRules(l))return false;const E=LOIS.essaiPenalite;
 if(Math.abs(attackingGoal(side)-l.territory)>E.distance)return false;
 return Math.random()<(['scrum','maul'].includes(incident?.id)?E.conquete:E.jeu);
}
function accorderEssaiPenalite(l,side,incident){
 const depart=Array.isArray(l.essaisPoss)&&l.essaisPoss[0]===side?l.essaisPoss[1]:l.territory;
 l.tries[side]++;(l.essaisDetail||(l.essaisDetail=[])).push([Math.max(0,Math.round(l.minute)||0),side,incident?.id==='maul'?'b':incident?.id==='scrum'?'m':'j',Math.round(side===0?100-clamp(depart,0,100):clamp(depart,0,100))]);
 // Compte du moteur (score = essais × 5 + transformations × 2 + buts × 3, contrôlé à la sauvegarde) : les 2 points
 // accordés sans tir figurent comme une transformation, comptée à part (penaltyTries) et retirée partout où le joueur voit
 // les transformations (statistiques du match, conseil, multiplex) ; aucun buteur n'est crédité (fiche de stats).
 l.score[side]+=7;l.stats[side].conversionAttempts++;l.stats[side].conversions++;l.stats[side].penaltyTries=(l.stats[side].penaltyTries||0)+1;
 addEvent(l,`${S.clubs[l.pair[side]].abbr} · Essai de pénalité : 7 points, sans transformation. ${l.score.join(' – ')}.`,'try',{kind:'message',team:side,loi:'essai-penalite'});
 if(restartRules(l)){chronoArret(l,'penalite');if(!flowScored(l,side)&&(flowRules(l)||l.minute<80))relancer(l,'kickoff',1-side,'score',side)}
 return true;
}
// Porteur arrêté et ballon qui ne ressort pas du maul formé autour de lui (loi 16) : mêlée pour l'équipe qui n'avait pas
// le ballon au début du maul. Part des ballons perdus au contact (injouable).
function ballonInjouable(l,side){
 if(!loisRules(l)||l.flow?.advantage||Math.random()>=LOIS.injouable)return false;
 const opp=1-side,carrier=actionPlayer(l,side);
 addEvent(l,`${carrier?.name||S.clubs[l.pair[side]].abbr} (${S.clubs[l.pair[side]].abbr}) est pris dans un maul arrêté, ballon injouable : mêlée pour ${S.clubs[l.pair[opp]].abbr}.`,'play',{kind:'message',team:opp,loi:'injouable'});
 grantSetPiece(l,'scrum',opp,l.territory,'unplayable',side);return true;
}
// Drop de l'ouvreur (n° 10, sinon le botteur d'occupation) à portée, hors avantage.
// Sans tirage : l'action peut-elle commencer par un drop ? (aussi lu par tests/helpers/tirages.cjs).
// Garde-fou, avant tout tirage : pas de drop dans un match plié (mené de plus de `plie.mene` points en seconde période,
// ou plus de `plie.avance` points d'avance) ; la fin de match serrée (`fin`) n'est jamais pliée.
function dropPossible(l,side){
 if(!loisRules(l)||l.flow?.advantage)return false;const D=LOIS.drop,d=Math.round(Math.abs(attackingGoal(side)-l.territory));
 const ecart=l.score[side]-l.score[1-side],seconde=(l.flow?.period??((Number(l.minute)||0)>=40?2:1))>=2;
 if(ecart>D.plie.avance||seconde&&ecart<-D.plie.mene)return false;
 return d>=D.zone[0]&&d<=D.zone[1]}
function dropTente(l,side){
 if(!dropPossible(l,side))return false;
 const D=LOIS.drop,goal=attackingGoal(side),at=l.territory,d=Math.round(Math.abs(goal-at));
 const ecart=l.score[side]-l.score[1-side],fin=(Number(l.minute)||0)>=D.minute&&ecart<=0&&ecart>=-D.ecart;
 if(Math.random()>=(fin?D.fin:D.base))return false;
 const id=l.sheets[side]?.on?.[9],k=(id!=null?activePlayers(l,side).find(p=>p.id===id):null)||occupationKicker(l,side),ab=S.clubs[l.pair[side]].abbr,nom=k?.name||ab;
 const pluie=meteoActive(l)?meteoNiveau(l,'pluie'):l.weather==='Pluie'?1:0,note=k?(skill(k,'kick',true)+skill(k,'goal',true))/2:60;
 const ok=Math.random()<clamp(D.reussite+(note-70)*.008-Math.max(0,d-22)*D.parMetre-pluie*.08+goalConditions(l,side)*.5,.1,.8);
 // Drop compté avec les buts (score = essais × 5 + transformations × 2 + buts × 3, contrôlé à la sauvegarde), et à part
 // (dropAttempts, drops) pour le retirer de la ligne « Tirs de pénalité » affichée au joueur.
 tacticalCount(l,side,'kicks');l.stats[side].goalAttempts++;l.stats[side].dropAttempts=(l.stats[side].dropAttempts||0)+1;
 addEvent(l,`${nom} (${ab}) tente le drop à ${d} mètres.`,'play',{kind:'message',team:side,loi:'drop-tente'});
 if(!ok){addEvent(l,`Le drop de ${nom} passe à côté des poteaux.`,'play',{kind:'message',team:side,loi:'drop-rate'});missedGoal(l,side);return true}
 l.score[side]+=3;l.stats[side].goals++;l.stats[side].drops=(l.stats[side].drops||0)+1;
 addEvent(l,`${ab} · Drop réussi par ${nom}. ${l.score.join(' – ')}.`,'goal',{kind:'message',team:side,actor:k?.id||null,loi:'drop-reussi'});
 if(restartRules(l)){chronoArret(l,'penalite');if(!flowScored(l,side)&&(flowRules(l)||l.minute<80))relancer(l,'kickoff',1-side,'score',side)}
 return true;
}
function resolveTouch(l,actor,exit,{direct=false,penalty=false,carried=false,kicker=null,court=false,vise=false}={}){
 const origin=l.territory,context=l.kickContext;
 const fifty=!penalty&&!carried&&!direct&&ownHalf(actor,origin)&&(actor===0?exit>=78:exit<=22)&&context?.team===actor&&context.halfEligible;
 const gain=penalty||!direct||own22(actor,origin)&&context?.team===actor&&context.twentyTwoEligible;
 const mark=gain?exit:(actor===0?Math.min(origin,exit):Math.max(origin,exit));
 const team=penalty||fifty?actor:1-actor,cause=penalty?'penalty-touch':fifty?'50-22':carried?'carry-touch':direct?'direct-touch':'indirect-touch';
 // Coup de pied de jeu en touche (jeu au pied réaliste) : le botteur est nommé, le fait porte son id (match 2D/3D, fiche de stats).
 if(kicker&&!penalty&&!carried){const ab=S.clubs[l.pair[actor]].abbr,m=Math.max(1,Math.round(Math.abs(exit-origin)));addEvent(l,`${kicker.name} (${ab}) ${vise&&!fifty?(direct?`vise les 22 adverses mais botte directement en touche${gain?`, ${m} mètres gagnés`:' sans gain de terrain'}`:`vise les 22 adverses, le ballon sort trop tôt, ${m} mètres gagnés`):fifty?`réussit un 50:22 : le ballon rebondit en touche dans les 22 adverses, ${ab} conserve le lancer`:direct&&!gain?'botte directement en touche sans gain de terrain':court?`trouve une touche courte, ${m>1?m+' mètres gagnés':'1 mètre gagné'}`:own22(actor,origin)?`dégage en touche, ${m} mètres gagnés`:m<10?`trouve la touche à ${Math.round(Math.abs(attackingGoal(actor)-exit))} mètres de la ligne adverse`:`trouve la touche${direct?'':' après rebond'}, ${m} mètres gagnés`}.`,'play',{kind:'touch',team:actor,cause,actor:kicker.id,from:{x:origin,y:35},to:{x:exit,y:0}});return grantSetPiece(l,'lineout',team,mark,cause,actor,origin)}
 addEvent(l,`${S.clubs[l.pair[actor]].abbr} ${penalty?'trouve la pénaltouche et conserve le lancer':fifty?'réussit un 50:22 et conserve le lancer':carried?'est poussé en touche':direct&&!gain?'botte directement en touche sans gain de terrain':'envoie le ballon en touche'}.`,'play',{kind:'touch',team:actor,cause,from:{x:origin,y:35},to:{x:exit,y:0}});
 return grantSetPiece(l,'lineout',team,mark,cause,actor,origin);
}
function resolveInGoal(l,actor,scenario,kickOrigin=l.territory,depuis=null){
 const defender=1-actor;
 if(scenario==='defender-grounded'){addEvent(l,`${S.clubs[l.pair[actor]].abbr} a rentré le ballon dans son propre en-but et l’y rend mort : mêlée adverse à cinq mètres.`,'play',{kind:'ingoal',team:actor,cause:scenario,to:{x:ownGoal(actor),y:35}});return grantSetPiece(l,'scrum',1-actor,ownGoal(actor)+(actor===0?5:-5),'defender-grounded',actor,kickOrigin)}
 if(['held-up','attacking-kick-grounded','ingoal-knock-on'].includes(scenario)){
  {const ab=S.clubs[l.pair[actor]].abbr; // L'équipe qui attaque est nommée : le bandeau 3D et l'écran 2D lisent ce texte (détection de la cause : match-highlights.cjs).
  addEvent(l,scenario==='held-up'?`Le porteur attaquant de ${ab} est tenu dans l’en-but sans pouvoir aplatir.`:scenario==='ingoal-knock-on'?`En-avant de l’attaque de ${ab} dans l’en-but.`:`Le coup de pied de l’attaque de ${ab} est aplati par la défense dans son en-but.`,'play',{kind:'ingoal',team:actor,cause:scenario,...(depuis===null?{}:{from:{x:depuis,y:35}}),to:{x:attackingGoal(actor),y:35}});}
  return performKickRestart(l,'goalLine',defender,scenario,actor);
 }
 if(scenario==='kick-dead'){
  addEvent(l,`${S.clubs[l.pair[actor]].abbr} botte le ballon au-delà de l’en-but adverse.`,'play',{kind:'ingoal',team:actor,cause:scenario,from:{x:kickOrigin,y:35},to:{x:attackingGoal(actor),y:35}});
  const distanceFromOwnGoal=Math.abs(kickOrigin-ownGoal(defender));
  if(distanceFromOwnGoal>=(jeuPiedRules(l)?50:30)){addEvent(l,`${S.clubs[l.pair[defender]].abbr} choisit la mêlée à l’endroit du coup de pied.`);return grantSetPiece(l,'scrum',defender,kickOrigin,'kick-dead-option',actor,kickOrigin)}
  return performKickRestart(l,'drop22',defender,'kick-dead',actor);
 }
 return false;
}
function missedGoal(l,side){
 const outcome=Math.random();
 if(outcome<.6){addEvent(l,'Le tir au but manqué devient mort au-delà de la ligne d’essai.','play',{kind:'miss',team:side,to:{x:attackingGoal(side),y:35}});return relancer(l,'drop22',1-side,'missed-goal-dead',side)}
 if(outcome<.8){const at=side===0?95:5;addEvent(l,'Le tir au but manqué sort en touche : lancer à la défense.','play',{kind:'touch',team:side,cause:'missed-goal-touch',to:{x:at,y:0}});return grantSetPiece(l,'lineout',1-side,at,'missed-goal-touch',side)}
 const landing=side===0?rand(82,97):rand(3,18);ballPossession(l,1-side,landing);addEvent(l,`${S.clubs[l.pair[1-side]].abbr} récupère le tir manqué resté dans le champ de jeu.`,'play',{kind:'reception',team:1-side,actor:actionPlayer(l,1-side,'receiver')?.id||null,to:{x:landing,y:35}});return true;
}
function kickOpenPlay(l,side){
 tacticalCount(l,side,'kicks');
 if(jeuPiedRules(l))return jeuAuPied(l,side);
 // Occupation (ATTACK_EFFECTS.occupation) : coup de pied long et disputé, récupéré une fois sur quatre par le camp qui botte.
 const occ=tacticalRules(l)&&effectiveAttack(l,side)==='occupation'?ATTACK_EFFECTS.occupation:null;
 const dir=side===0?1:-1,origin=l.territory,distance=clamp(12+(unit(l,side,'kick',p=>p.fam>=4)-60)*.5+rand(-8,10)+collectivePreparationBonus(l,side,'pied')+occupationKickEdge(l,side)+(occ?.kickBonus||0)-(meteoActive(l)?ventMetres(l,side)+(Math.random()*2-1)*METEO_MATCH.piedAlea.vent*l.meteo.vent:l.weather==='Vent'?9:0),3,occ?.kickMax||45),landing=origin+dir*distance;
 const outcome=Math.random();
 if(landing<=0||landing>=100)return resolveInGoal(l,side,outcome<.5?'attacking-kick-grounded':'kick-dead',origin);
 if(outcome<.23)return resolveTouch(l,side,landing,{direct:true});
 if(outcome<.58)return resolveTouch(l,side,landing);
 if(occ&&Math.random()<occ.recup){ballPossession(l,side,landing);addEvent(l,`${S.clubs[l.pair[side]].abbr} met la pression sous la chandelle et récupère son coup de pied.`,'play',{kind:'kick',team:side,actor:occupationKicker(l,side)?.id||null,from:{x:origin,y:35},to:{x:landing,y:35}});return true;}
 ballPossession(l,1-side,landing);const botteur=occupationKicker(l,side);addEvent(l,`${botteur?.name||S.clubs[l.pair[side]].abbr} (${S.clubs[l.pair[side]].abbr}) gagne ${Math.round(distance)} mètres au pied ; ${actionName(l,1-side,'receiver')} réceptionne pour ${S.clubs[l.pair[1-side]].abbr}.`,'play',{kind:'kick',team:side,actor:botteur?.id||null,from:{x:origin,y:35},to:{x:landing,y:35}});return true;
}
// Jeu au pied réaliste (JEU_PIED, dist/tactical-plans.js ; docs/jeu-au-pied-20261125.md). Le type dépend de la zone,
// du plan de jeu et de la pluie ; la longueur et l'issue du botteur (jeu au pied, préparation, vent). Les lois restent
// celles de resolveTouch / resolveInGoal : gain en touche directe seulement depuis ses 22 (ballon non rentré), 50:22
// seulement après rebond depuis son camp, ballon aplati par la défense dans son en-but : renvoi sur la ligne d'essai.
function jeuAuPiedType(l,side){
 const w={...JEU_PIED.types[jeuPiedZone(l,side)]},style=effectiveAttack(l,side),pluie=meteoActive(l)?meteoNiveau(l,'pluie'):l.weather==='Pluie'?1:0;
 if(style==='occupation'){w.long*=1.4;w.chandelle*=1.2}else if(style==='large')w.rasant*=1.4;
 if(pluie){w.chandelle*=1+.3*pluie;w.rasant*=Math.max(.4,1-.2*pluie)}
 const total=Object.values(w).reduce((a,b)=>a+b,0);let r=Math.random()*total;
 for(const [k,v] of Object.entries(w))if(v>0&&(r-=v)<0)return k;
 return 'touche';
}
function jeuAuPiedBotteur(l,side,type){
 // Chandelle depuis son camp : le demi de mêlée (n° 9) derrière le regroupement ; sinon le botteur d'occupation.
 if(type==='chandelle'&&ownHalf(side,l.territory)){const id=l.sheets?.[side]?.on?.[8],p=id!=null?activePlayers(l,side).find(x=>x.id===id):null;if(p)return p}
 return occupationKicker(l,side);
}
function jeuAuPiedChasseur(l,side,botteur){const others=activePlayers(l,side).filter(p=>p.id!==botteur?.id),pool=others.filter(p=>p.fam>=5);return (pool.length?pool:others)[(l.minute+side)%Math.max(1,(pool.length?pool:others).length)]||null}
function jeuAuPied(l,side){
 const J=JEU_PIED,dir=side===0?1:-1,origin=l.territory,opp=1-side,ab=S.clubs[l.pair[side]].abbr,abo=S.clubs[l.pair[opp]].abbr,goal=attackingGoal(side);
 const type=jeuAuPiedType(l,side),botteur=jeuAuPiedBotteur(l,side,type),nom=botteur?.name||ab;
 const q=J.qualite*clamp(((botteur?skill(botteur,'kick',true):unit(l,side,'kick',p=>p.fam>=4))-60)/40,-1,1);
 const pluie=meteoActive(l)?meteoNiveau(l,'pluie'):l.weather==='Pluie'?1:0;
 const vent=meteoActive(l)?ventMetres(l,side)+(Math.random()*2-1)*METEO_MATCH.piedAlea.vent*l.meteo.vent:l.weather==='Vent'?9:0;
 const plus=collectivePreparationBonus(l,side,'pied')+occupationKickEdge(l,side),occ=effectiveAttack(l,side)==='occupation';
 const dedans=x=>side===0?x>=100:x<=0,dans22=x=>side===0?x>=78:x<=22;
 // Joueur qui prend le ballon (receveur adverse ou partenaire qui reprend) : placé au point de chute (match 2D/3D).
 const fait=(texte,landing,qui=null)=>addEvent(l,texte,'play',{kind:'kick',team:side,actor:botteur?.id||null,...(qui?{receiver:qui.id}:{}),from:{x:origin,y:35},to:{x:landing,y:35}});
 const reception=(landing,debut)=>{ballPossession(l,opp,landing);const r=actionPlayer(l,opp,'receiver');fait(`${debut} ; ${r?.name||abo} réceptionne pour ${abo}.`,landing,r);return true};
 const metres=x=>Math.round(Math.abs(x-origin));
 if(type==='touche'){
  const half=ownHalf(side,origin),own=own22(side,origin);
  // 50:22 : tentative depuis son camp, le ballon doit rebondir avant de sortir dans les 22 adverses.
  // Ratée : sortie directe (touche adverse, sans gain hors de ses 22), sortie avant les 22 adverses, ou ballon rendu.
  const C=J.cinquante,tente=typeof C.tente==='number'?C.tente:C.tente[own?'own22':'ownHalf'];
  if(half&&Math.random()<tente*(1+q*.5)){
   const exit=goal-dir*rand(4,18);
   if(Math.random()<clamp(C.reussite+q*.15-pluie*.05,.1,.7))return resolveTouch(l,side,exit,{kicker:botteur});
   const rate=Math.random();
   if(rate<(C.directe||0))return resolveTouch(l,side,clamp(origin+dir*rand(30,45),5,95),{direct:true,kicker:botteur,vise:true});
   if(rate<(C.directe||0)+(C.courte||0))return resolveTouch(l,side,clamp(goal-dir*rand(24,34),5,95),{kicker:botteur,vise:true});
   const landing=clamp(goal-dir*rand(3,15),1,99);return reception(landing,`${nom} (${ab}) vise le 50:22 mais le ballon reste dans le champ`);
  }
  const dist=clamp((rand(22,38)+q*8)*J.longueur+plus-vent,10,58);
  if(Math.random()<clamp(J.touche+q*.12-pluie*.03,.45,.9)){
   const direct=Math.random()<(own?J.directe22:J.directeHors22);let exit=origin+dir*dist;
   if(!dans22(origin+dir*0)&&dans22(exit))exit=goal-dir*23;
   return resolveTouch(l,side,clamp(exit,5,95),{direct,kicker:botteur});
  }
  const landing=origin+dir*(dist+rand(0,8));
  if(dedans(landing))return resolveInGoal(l,side,Math.random()<.5?'attacking-kick-grounded':'kick-dead',origin);
  return reception(clamp(landing,1,99),`${nom} (${ab}) cherche la touche, le ballon reste dans le champ après ${metres(landing)} mètres`);
 }
 if(type==='long'){
  const dist=clamp((rand(34,52)+q*8)*J.longueur+plus-vent+(occ?ATTACK_EFFECTS.occupation.kickBonus*.4:0),15,65),landing=origin+dir*dist;
  // Ballon qui roule après le rebond : il peut finir dans l'en-but (aplati par la défense ou mort).
  if(dedans(landing+dir*rand(0,14)))return resolveInGoal(l,side,Math.random()<.4?'attacking-kick-grounded':'kick-dead',origin);
  if(Math.random()<.07)return resolveTouch(l,side,clamp(landing+dir*rand(0,6),5,95),{kicker:botteur});
  return reception(clamp(landing,1,99),`${nom} (${ab}) tape long dans le camp adverse, ${metres(landing)} mètres`);
 }
 if(type==='chandelle'){
  const landing=origin+dir*clamp(rand(12,24)+q*3+plus-vent*.5,6,33);
  if(dedans(landing))return resolveInGoal(l,side,'attacking-kick-grounded',origin);
  const at=clamp(landing,1,99),r=Math.random(),pr=clamp(J.recup.chandelle+q*.08+(unit(l,side,'speed',p=>p.fam>=5)-unit(l,opp,'mental',p=>p.fam>=5))*.003*J.qualite+(occ?.05:0),.12,.45);
  if(r<pr){ballPossession(l,side,at);const c=jeuAuPiedChasseur(l,side,botteur);fait(`${nom} (${ab}) tape une chandelle ; ${c?.name||ab} la reprend à la retombée, ${metres(at)} mètres plus loin.`,at,c);return true}
  if(r<pr+J.enAvant+pluie*.03){ballPossession(l,opp,at);const rec=actionPlayer(l,opp,'receiver');fait(`${nom} (${ab}) tape une chandelle ; ${rec?.name||abo} (${abo}) la relâche sous la pression.`,at,rec);return handFault(l,opp)}
  return reception(at,`${nom} (${ab}) tape une chandelle de ${metres(at)} mètres, contestée`);
 }
 if(type==='croise'){
  // Coup de pied croisé vers l'aile (camp adverse) : capté par l'ailier, sinon par la défense, parfois directement en touche.
  const landing=origin+dir*clamp(rand(10,24)+q*3+plus-vent*.5,6,30),at=dedans(landing)?clamp(goal-dir*rand(2,6),1,99):clamp(landing,1,99);
  const r=Math.random(),pr=clamp(J.recup.croise+q*.1+(occ?.03:0)-pluie*.05,.1,.5);
  if(r<pr){ballPossession(l,side,at);const c=jeuAuPiedChasseur(l,side,botteur);fait(`${nom} (${ab}) tape un coup de pied croisé ; ${c?.name||ab} le capte sur l’aile, ${metres(at)} mètres plus loin.`,at,c);return true}
  if(r<pr+J.croiseTouche)return resolveTouch(l,side,clamp(at,5,95),{direct:true,kicker:botteur});
  return reception(at,`${nom} (${ab}) tente le coup de pied croisé, capté par la défense`);
 }
 // Rasant ou par-dessus dans le dos de la défense (camp adverse).
 const dessus=Math.random()<(dans22(origin)?.55:.4),landing=origin+dir*clamp((dessus?rand(10,22):rand(8,20))+q*2+plus,5,31);
 const pr=clamp(J.recup.rasant+q*.1+(occ?.03:0)-pluie*.04,.12,.5),geste=dessus?'tape par-dessus la défense':'glisse un coup de pied rasant';
 if(dedans(landing)){
  if(Math.random()<pr*.7){const at=clamp(goal-dir*rand(2,5),1,99);ballPossession(l,side,at);const c=jeuAuPiedChasseur(l,side,botteur);fait(`${nom} (${ab}) ${geste} ; ${c?.name||ab} récupère juste avant l’en-but.`,at,c);return true}
  // La défense ramasse le ballon devant sa ligne (ancienne remise à zéro du « poussé en touche ») ; sinon, il file dans l'en-but.
  if(Math.random()<J.enButDefense)return reception(clamp(goal-dir*rand(2,6),1,99),`${nom} (${ab}) ${geste}, la défense couvre devant sa ligne`);
  return resolveInGoal(l,side,Math.random()<.7?'attacking-kick-grounded':'kick-dead',origin);
 }
 const at=clamp(landing,1,99);
 if(Math.random()<pr){ballPossession(l,side,at);const c=jeuAuPiedChasseur(l,side,botteur);fait(`${nom} (${ab}) ${geste} ; ${c?.name||ab} récupère le ballon, ${metres(at)} mètres plus loin.`,at,c);return true}
 return reception(at,`${nom} (${ab}) ${geste}, ${metres(at)} mètres`);
}
// Coup de pied raté ou perdu : reprend la part de l'ancien « poussé en touche » (ballon rendu à l'adversaire sans gain
// de terrain notable, au hasard, quel que soit le niveau). Formes réalistes (JEU_PIED.perdus) : dans son camp, touche trouvée
// mais courte, dégagement contré, trop court ou rendu au milieu, chandelle du n° 9 trop longue, dégagement capté puis relancé
// par l'adversaire ; dans le camp adverse, rasant ou par-dessus ramassé, chandelle captée, croisé capté, ballon mort dans
// l'en-but. La touche directe sans gain (lancer adverse à hauteur du coup de pied), rare au haut niveau, garde une petite part.
// Equipe menée à portée en fin de match dans son camp (elle ne dégage plus) : le porteur est poussé en touche.
function jeuAuPiedPerdu(l,side){
 const zone=jeuPiedZone(l,side);
 if(!jeuPiedScore(l,side,zone))return resolveTouch(l,side,l.territory,{carried:true});
 tacticalCount(l,side,'kicks');
 const J=JEU_PIED,dir=side===0?1:-1,origin=l.territory,opp=1-side,ab=S.clubs[l.pair[side]].abbr,abo=S.clubs[l.pair[opp]].abbr,goal=attackingGoal(side);
 const camp=zone==='own22'||zone==='ownHalf',k=jeuAuPiedTire(camp?J.perdus[zone]:{...J.perdus.adverse,...(zone==='opp22'?{touche:0}:{})});
 const botteur=camp?jeuAuPiedBotteur(l,side,k==='chandelle'?'chandelle':'touche'):occupationKicker(l,side),nom=botteur?.name||ab;
 const devant=m=>clamp(Math.abs(goal-origin)>m+3?origin+dir*m:goal-dir*3,1,99),M=J.perduMetres;
 const fait=(at,texte,qui=null,suite={})=>addEvent(l,texte,'play',{kind:'kick',team:side,actor:botteur?.id||null,...(qui?{receiver:qui.id}:{}),from:{x:origin,y:35},to:{x:at,y:35},...suite});
 const recoit=(at,texte)=>{ballPossession(l,opp,at);const r=actionPlayer(l,opp,'receiver');fait(at,`${texte} ; ${r?.name||abo} récupère pour ${abo}.`,r);return true};
 if(camp){
  if(k==='touche')return resolveTouch(l,side,devant(rand(...M.touche)),{kicker:botteur,court:true});
  if(k==='directe')return resolveTouch(l,side,clamp(origin+dir*rand(15,30),5,95),{direct:true,kicker:botteur});
  if(k==='contre')return recoit(clamp(origin-dir*rand(1,4),1,99),`${nom} (${ab}) voit son dégagement contré`);
  if(k==='chandelle')return recoit(devant(rand(...M.chandelle)),`${nom} (${ab}) tape une chandelle trop longue, sans pression`);
  if(k==='relance'){
   // Dégagement capté puis relancé : le receveur remonte le terrain, la possession change près du point de départ.
   const landing=devant(rand(...M.relance)),at=devant(rand(...M.camp)),r=actionPlayer(l,opp,'receiver');
   // Le fait dit déjà le ballon chez le receveur (image : il capte au point de chute) : sans cela, bandeau et ligne d'état
   // donnaient le ballon au botteur pendant la réception (tests/match-bandeau-possession.cjs). Possession du match inchangée ici.
   fait(landing,`${nom} (${ab}) dégage dans le champ ; ${r?.name||abo} capte pour ${abo}.`,r,{possession:opp});ballPossession(l,opp,at);
   const g=Math.round(Math.abs(landing-at));
   if(g>=1)addEvent(l,`${r?.name||abo} (${abo}) relance et remonte ${g} mètres.`,'play',{kind:'carry',team:opp,actor:r?.id||null,tackler:r?carryTackler(l,opp,r.id,g):null,from:{x:landing,y:35},to:{x:at,y:35}});
   return true;
  }
  return recoit(devant(rand(...M.camp)),`${nom} (${ab}) manque son dégagement, rendu au milieu du terrain`);
 }
 if(k==='directe')return resolveTouch(l,side,origin,{direct:true,kicker:botteur});
 if(k==='touche')return resolveTouch(l,side,devant(rand(...M.touche)),{kicker:botteur});
 if(k==='rasant')return recoit(devant(rand(...M.adverse)),`${nom} (${ab}) ${Math.random()<.5?'glisse un rasant':'tape par-dessus la défense'}, trop long`);
 if(k==='chandelle')return recoit(devant(rand(...M.adverse)),`${nom} (${ab}) tape une chandelle d’attaque, captée par la défense`);
 if(k==='croise')return recoit(devant(rand(...M.adverse)),`${nom} (${ab}) tente le coup de pied croisé, capté par la défense`);
 // Trop long : ballon mort au-delà de l'en-but (renvoi aux 22 m de la défense) ou aplati par la défense (renvoi sur sa ligne).
 return resolveInGoal(l,side,Math.random()<.7?'kick-dead':'attacking-kick-grounded',origin);
}
function jeuAuPiedTire(w){let r=Math.random()*Object.values(w).reduce((a,b)=>a+b,0);for(const [k,v] of Object.entries(w))if(v>0&&(r-=v)<0)return k;return Object.keys(w)[0]}
// Découpage des longues courses (docs/match-courses-20261112.md) : quand une course réussie
// mène à un essai (ou à un ballon tenu ou échappé dans l'en-but), le journal écrit la course
// telle que le moteur l'écrit quand elle n'aboutit pas (origine → point atteint, porteur
// `actionPlayer`), puis 0 à 2 temps de jeu de soutien jusqu'à quelques mètres de la ligne,
// avant le fait final. Présentation seule : aucun tirage, issue, score, essais et statistiques
// du moteur inchangés. `MATCH_COURSES_DECOUPEES=false` (CD_MATCH_COURSES=0 dans le worker)
// rend l'ancien journal (un seul fait de l'origine à la ligne).
var MATCH_COURSES_DECOUPEES=true;
function courseDecoupee(l,side,origin,finisseur){
 const dir=side===0?1:-1,club=S.clubs[l.pair[side]].abbr,arrivee=l.territory;
 const plan=effectiveAttack(l,side)==='conquete'?' au près':effectiveAttack(l,side)==='large'?' sur une séquence de jeu au large':'';
 const carrier=actionPlayer(l,side),gain=Math.round(Math.abs(arrivee-origin));
 const phrases=[`${carrier?.name||club} porte le ballon et gagne ${gain} mètres`,`${carrier?.name||club} avance de ${gain} mètres avant le plaquage`,`${club} progresse de ${gain} mètres par ${carrier?.name||'son porteur'}`];
 if(gain>=1)addEvent(l,`${phrases[l.minute%phrases.length]}${plan} dans les 22 adverses.`,'play',{kind:'carry',team:side,actor:carrier?.id||null,tackler:carrier?carryTackler(l,side,carrier.id,gain):null,from:{x:origin,y:35},to:{x:arrivee,y:35}});
 const reste=Math.abs(attackingGoal(side)-arrivee),n=reste>18?2:reste>9?1:0,pas=reste/(n+1);
 const pool=activePlayers(l,side).filter(p=>p.id!==finisseur?.id&&p.id!==carrier?.id);
 let x=arrivee,precedent=carrier;
 for(let k=0;k<n;k++){
  const options=pool.filter(p=>p.id!==precedent?.id),sup=options.length?options[(l.minute+side+2*k+1)%options.length]:null;
  const nx=Math.round(x+dir*pas),m=Math.round(Math.abs(nx-x)),nom=sup?.name||club;
  const textes=[`Soutien de ${nom}, qui relance et gagne ${m} mètres`,`${nom} prend le relais après le regroupement et gagne ${m} mètres`,`Passe pour ${nom}, qui avance de ${m} mètres`];
  addEvent(l,`${textes[(l.minute+k)%textes.length]}${Math.abs(attackingGoal(side)-nx)<=10?' : la ligne est tout près':''}.`,'play',{kind:'carry',team:side,actor:sup?.id||null,tackler:sup?carryTackler(l,side,sup.id,m):null,from:{x,y:35},to:{x:nx,y:35}});
  x=nx;precedent=sup;
 }
 return x;
}
function advanceCausalPlay(l){
 // Séquence de pénaltouche (défense regroupée, dist/tactical-plans.js) : finie dès que l'autre camp joue le ballon.
 if(l.suitePenaltouche&&l.suitePenaltouche.side!==l.possession)delete l.suitePenaltouche;
 const side=l.possession,opp=1-side,origin=l.territory,roll=Math.random(),penalites=penalitesRules(l),penaltyProb=clamp(.12+(penalites?PENALITES.jeu:0)+(70-unit(l,opp,'discipline'))*.002+tacticalPenaltyAdjustment(l,opp),tacticalRules(l)?.04:.06,tacticalRules(l)?.28:.23)*derbyFouls(l)*(typeof pilotageFoul==='function'?pilotageFoul(l,opp,'jeu'):1),handProb=handFaultProbability(l,side);
 if(roll<penaltyProb)return awardPenalty(l,side);
 if(roll<penaltyProb+handProb)return handFault(l,side,passeEnAvant(l));
 // Lois manquantes : drop tenté par l'ouvreur (surtout en fin de match serré), avant le reste de l'action.
 if(dropTente(l,side))return true;
 // Jeu au pied réaliste : l'ancienne part du « poussé en touche » (12 % par action) devient surtout un coup de pied
 // raté ou perdu (jeuAuPiedPerdu), même probabilité, même effet de terrain ; le vrai poussé en touche devient rare.
 // Consignes « Garder » / « Relancer » (pilotageGarde) : une part des coups de pied perdus devient un porteur poussé en touche.
 const garde=l.pilotage&&typeof pilotageGarde==='function'?pilotageGarde(l,side):1,perdu0=jeuPiedPerdu(l,side),pousse=poussEnTouche(l,side)+perdu0*(1-garde),perdu=perdu0*garde;
 if(roll<penaltyProb+handProb+pousse)return resolveTouch(l,side,l.territory,{carried:true});
 if(roll<penaltyProb+handProb+pousse+perdu)return jeuAuPiedPerdu(l,side);
 // Pénalités réalistes : faute de l'attaquant au sol (ballon non libéré, scellement), plus rare chez les joueurs disciplinés.
 if(penalites&&roll<penaltyProb+handProb+pousse+perdu+clamp(PENALITES.attaque+(70-unit(l,side,'discipline'))*.001,.02,.08)*(typeof pilotageFoul==='function'?pilotageFoul(l,side,'attaque'):1))return awardPenalty(l,opp,{phase:'attaque',incident:roll*1000%2<1?'not-release':'sealing'});
 if((tacticalRules(l)||effectiveAttack(l,side)==='occupation')&&Math.random()<openKickProbability(l,side))return kickOpenPlay(l,side);
 tacticalCount(l,side,'carries');const edge=teamEdge(l,side,'attack'),essais=essaisRules(l),niveau=essais?(ESSAIS.ecart-1)*tacticalEdge(l,side):0,success=Math.random()<(essais?clamp(ESSAIS.porte+ouvertureJeu(l)+edge+niveau,.2,.9):clamp(.49+edge,.18,.84));
 if(success){
  l.territory=clamp(l.territory+(side===0?1:-1)*carryGain(l,side),1,99);tacticalCount(l,side,'advances');const metres=Math.abs(l.territory-origin);tacticalCount(l,side,'metres',metres);if(metres>=22)tacticalCount(l,side,'longGains');
  // The completed carrying sequence includes a tackle/ruck, resetting kick eligibility.
  l.kickContext={team:side,halfEligible:ownHalf(side,l.territory),twentyTwoEligible:own22(side,l.territory)};
  const danger=side===0?l.territory>74:l.territory<26;
  if(danger&&Math.random()<(essais?clamp(ESSAIS.finition+ouvertureJeu(l)+edge+niveau+tacticalFinishAdjustment(l,side)-(typeof defenseRegroupee==='function'?DEFENSE_REGROUPEE.finition*defenseRegroupee(l,side):0),.15,.85):clamp(.36+edge+tacticalFinishAdjustment(l,side),tacticalRules(l)?.12:.16,tacticalRules(l)?.78:.75))){
   const finish=Math.random();
   if(MATCH_COURSES_DECOUPEES){
    if(finish<.12)return resolveInGoal(l,side,finish<.08?'held-up':'ingoal-knock-on',l.territory,courseDecoupee(l,side,origin,null));
    return scoreTry(l,side,'open',origin,scorer=>courseDecoupee(l,side,origin,scorer));
   }
   if(finish<.08)return resolveInGoal(l,side,'held-up');if(finish<.12)return resolveInGoal(l,side,'ingoal-knock-on');
   return scoreTry(l,side,'open',origin);
  }
  const plan=effectiveAttack(l,side)==='conquete'?' au près':effectiveAttack(l,side)==='large'?' sur une séquence de jeu au large':'';const carrier=actionPlayer(l,side),gain=Math.round(Math.abs(l.territory-origin));const phrases=[`${carrier?.name||S.clubs[l.pair[side]].abbr} porte le ballon et gagne ${gain} mètres`,`${carrier?.name||S.clubs[l.pair[side]].abbr} avance de ${gain} mètres avant le plaquage`,`${S.clubs[l.pair[side]].abbr} progresse de ${gain} mètres par ${carrier?.name||'son porteur'}`];addEvent(l,`${phrases[l.minute%phrases.length]}${plan}${danger?' dans les 22 adverses':''}.`,'play',{kind:'carry',team:side,actor:carrier?.id||null,tackler:carrier?carryTackler(l,side,carrier.id,gain):null,from:{x:origin,y:35},to:{x:l.territory,y:35}});
 }else if(Math.random()<failedCarryError(l,side))return handFault(l,side,passeEnAvant(l));
 else if(ballonInjouable(l,side))return true;
 else{tacticalCount(l,opp,'recoveries');noterContre(l,side);const stopped=actionName(l,side,'carrier'),contre=recupereALinstant(l,side);ballPossession(l,opp);addEvent(l,`${contre?'Ballon aussitôt rendu : ':''}${stopped} (${S.clubs[l.pair[side]].abbr}) ${contre?'relance tout de suite mais ':''}est arrêté net : ${actionName(l,opp,'defender')} récupère le ballon après le plaquage pour ${S.clubs[l.pair[opp]].abbr}.`,'turnover',{kind:'turnover',team:opp,actor:actionPlayer(l,opp,'defender')?.id||null})}
}
// Ballon que `side` vient de récupérer (plaquage, mêlée ou touche adverse, même minute, rien de joué depuis) : la course
// arrêtée qui le rend aussitôt est racontée comme une relance immédiate, pas comme une seconde récupération sortie de
// nulle part (audit du 25/11, anomalie 9). Lecture du journal seule, aucun tirage.
function recupereALinstant(l,side){
 for(let i=l.events.length-1;i>=0;i--){
  const e=l.events[i];if(['sub','tactic','message','card'].includes(e.type))continue;
  return e.type==='turnover'&&e.min===l.minute&&e.scene?.team===side;
 }
 return false;
}
