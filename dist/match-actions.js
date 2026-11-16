'use strict';
// Structured action facts are recorded by the engine, never inferred from prose.
// Optional facts already known to the caller (no draw, no state change): why the ball left play
// or was made dead, the colour of a card, the try's origin and whether it was converted, the tackler of a carry.
const ACTION_CAUSES={touch:['carry-touch','indirect-touch','direct-touch','penalty-touch','50-22','missed-goal-touch','period-end'],ingoal:['held-up','attacking-kick-grounded','ingoal-knock-on','kick-dead','defender-grounded'],'hand-fault':['knock-on','forward-pass'],penalty:['offside','ruck','holding','obstruction','dangerous','scrum','maul','not-release','sealing']};
const ACTION_CARDS=['yellow','red20','red'],ACTION_TRY_ORIGINS=['open','maul','scrum'];
const ACTION_KINDS=['message','carry','turnover','scrum','lineout','setpiece-win','setpiece-loss','kick','kickoff','drop22','goalLine','reception','touch','hand-fault','quick-tap','try','goal','miss','penalty','advantage','card','sub','tactic','break','end','ingoal'];
const ACTION_LABELS={message:'Jeu courant',carry:'Progression',turnover:'Récupération',scrum:'Mêlée',lineout:'Touche','setpiece-win':'Ballon conservé','setpiece-loss':'Ballon récupéré',kick:'Jeu au pied',kickoff:'Renvoi au centre',drop22:'Renvoi aux 22',goalLine:'Renvoi sur la ligne',reception:'Réception',touch:'Sortie en touche','hand-fault':'Faute de main','quick-tap':'Pénalité jouée à la main',try:'Essai',goal:'Pénalité réussie',miss:'Tir manqué',penalty:'Pénalité',advantage:'Avantage',card:'Discipline',sub:'Remplacement',tactic:'Consigne',break:'Mi-temps',end:'Fin du match',ingoal:'En-but'};
const MATCH_PLAYBACK=new WeakMap();
let pauseOnTry=false,pauseOnCard=false;
try{const prefs=JSON.parse(gameStorage.getItem('bdt-match-view'));pauseOnTry=prefs?.try===true;pauseOnCard=prefs?.card===true}catch(e){}
function actionPlayer(l,side,role='carrier'){
 const players=activePlayers(l,side),preferred=players.filter(p=>role==='kicker'?p.fam>=4:role==='receiver'?p.fam>=6:role==='defender'?p.fam>=2&&p.fam<=3:effectiveAttack(l,side)==='conquete'?p.fam<=3:p.fam>=3);
 const pool=preferred.length?preferred:players;return pool.length?pool[(l.minute+side)%pool.length]:null;
}
// Plaqueur d'un temps de jeu (fait `tackler` du journal) : choisi sans tirage, d'après l'état du match.
// Couloir défensif de chaque poste (slot 0 = n° 1) en largeur (0 à 70), celui où court le porteur
// (même table), le gain (court : un avant au contact ; de 10 à 21 m : le couloir, l'arrière garde la
// profondeur ; franchissement de 22 m et plus : la couverture, l'arrière d'abord), les troisièmes
// lignes (plus souvent au plaquage), le demi de mêlée (moins) et la fatigue (un joueur entamé plaque moins).
const DEFENCE_LANES=[33,35,37,30,40,24,46,35,35,28,6,20,50,64,35];
function carryTackler(l,side,carrierId,gain){
 const opp=1-side,on=l.sheets[opp]?.on;if(!Array.isArray(on))return null;
 const active=new Set(activePlayers(l,opp).map(p=>p.id)),at=l.sheets[side].on.indexOf(carrierId),lane=DEFENCE_LANES[at]??35;
 let best=null,score=Infinity;
 on.forEach((id,slot)=>{
  if(id==null||!active.has(id)||slot>14)return;
  const forward=slot<8,condition=Number(matchPlayer(l,opp,id)?.condition);
  let s=Math.abs(DEFENCE_LANES[slot]-lane);
  if(gain>=22)s+=slot===14?-40:slot===10||slot===13?-8:60; // couverture même sans arrière sur le terrain (carton, sortie)
  else if(gain>=10)s+=slot===14?12:forward?4:0;
  else s+=forward?0:60; // gain court : toujours un avant (les ailiers portent plus depuis les essais réalistes : écart de couloir jusqu'à 40)
  if(slot===5||slot===6)s-=3;else if(slot===8)s+=6;
  if(Number.isFinite(condition))s+=Math.max(0,100-condition)*.2;
  if(s<score){score=s;best=id}
 });
 return best;
}
function actionName(l,side,role){return actionPlayer(l,side,role)?.name||S.clubs[l.pair[side]].abbr}

// Consignes individuelles (docs/consignes-individuelles-20261116.md) : le manager désigne son buteur, un
// buteur de secours, son lanceur en touche et son joueur au pied d'occupation (S.playerRoles). Sans
// désignation, le staff choisit le meilleur à chaque rôle, comme les clubs de l'IA : c'est le calcul
// d'avant, à l'identique. Les désignations sont copiées au coup d'envoi (l.playerRoles) pour les rencontres
// créées avec `playerRolesVersion` ; un match commencé avant garde ses règles. Aucun tirage : la suite des
// tirages ne change pas, seules les probabilités et les distances suivent le joueur choisi.
let PLAYER_ROLES_RULES=1;
const PLAYER_ROLES={buteur:['Buteur','goal'],secours:['Buteur de secours','goal'],lanceur:['Lanceur en touche','lineout'],pied:['Jeu au pied d’occupation','kick']};
// Coefficients de jeu (non mesurés, ordres de grandeur) : touche gagnée par point de « touche » d'écart avec
// le talonneur en jeu, malus d'un lanceur qui n'est pas talonneur, mètres par point de « jeu au pied ».
const PLAYER_ROLE_COEFS={lancer:.004,nonTalonneur:.05,pied:.25};
function playerRolesRules(l){return l.playerRolesVersion===1&&Array.isArray(l.playerRoles)}
// Désignations valides pour une feuille : seulement des joueurs de la feuille (titulaires et remplaçants).
function sanitizePlayerRoles(roles,ids){
 const out={},known=new Set((ids||[]).filter(Boolean));
 if(!roles||typeof roles!=='object')return out;
 for(const key of Object.keys(PLAYER_ROLES)){const id=roles[key];if(typeof id==='string'&&known.has(id))out[key]=id}
 if(out.secours&&out.secours===out.buteur)delete out.secours;
 return out;
}
function initializePlayerRoles(l){
 if(!PLAYER_ROLES_RULES)return;
 l.playerRolesVersion=1;
 l.playerRoles=l.pair.map((ci,side)=>ci===S.club?sanitizePlayerRoles(S.playerRoles,[...l.sheets[side].on,...l.sheets[side].bench]):{});
}
function designatedPlayer(l,side,role){
 if(!playerRolesRules(l))return null;const id=l.playerRoles[side]?.[role];if(!id)return null;
 return activePlayers(l,side).find(p=>p.id===id)||null;
}
// Choix du staff : meilleur buteur en jeu (calcul d'origine), talonneur en jeu au lancer, meilleur
// botteur parmi les arrières au jeu au pied.
function staffRolePlayer(l,side,role){
 const on=activePlayers(l,side);
 // Jugement du staff (docs/jugement-staff-20261116.md) : le staff classe les joueurs d'après sa perception.
 if(staffJudgementRules(l)&&(role==='buteur'||role==='secours'))return judgedBest(l,side,on,'goal');
 if(staffJudgementRules(l)&&role==='pied')return judgedBest(l,side,on.filter(p=>p.fam>=4),'kick');
 if(role==='buteur'||role==='secours')return chooseScorer(S.clubs[l.pair[side]],on.map(p=>p.id));
 if(role==='lanceur'){const id=l.sheets[side].on[1];return on.find(p=>p.id===id&&p.fam===1)||[...on.filter(p=>p.fam===1)].sort((a,b)=>skill(b,'lineout',true)-skill(a,'lineout',true))[0]||null}
 if(role==='pied')return [...on.filter(p=>p.fam>=4)].sort((a,b)=>skill(b,'kick',true)-skill(a,'kick',true))[0]||null;
 return null;
}
// Buteur d'une tentative : le buteur désigné, à défaut le buteur de secours, à défaut le choix du staff.
function goalKicker(l,side){return designatedPlayer(l,side,'buteur')||designatedPlayer(l,side,'secours')||staffRolePlayer(l,side,'buteur')}
// Écart de réussite en touche dû au lanceur désigné (0 sans désignation : calcul d'avant).
function lineoutThrowEdge(l,side){
 const thrower=designatedPlayer(l,side,'lanceur');if(!thrower)return 0;
 const ref=staffRolePlayer(l,side,'lanceur');if(!ref||ref.id===thrower.id)return 0;
 const diff=(skill(thrower,'lineout',true)-skill(ref,'lineout',true))*PLAYER_ROLE_COEFS.lancer;
 return thrower.fam===1?diff:Math.min(0,diff)-PLAYER_ROLE_COEFS.nonTalonneur;
}
// Mètres gagnés ou perdus au pied d'occupation par le botteur désigné (0 sans désignation).
function occupationKickEdge(l,side){
 // Jugement du staff : l'écart se mesure au meilleur botteur réel des arrières, que le staff ne voit qu'à
 // travers sa perception (jamais de gain sur le meilleur réel).
 if(staffJudgementRules(l)){
  const kicker=designatedPlayer(l,side,'pied')||staffRolePlayer(l,side,'pied');if(!kicker)return 0;
  const best=[...activePlayers(l,side).filter(p=>p.fam>=4)].sort((a,b)=>skill(b,'kick',true)-skill(a,'kick',true))[0];
  return best&&best.id!==kicker.id?Math.min(0,skill(kicker,'kick',true)-skill(best,'kick',true))*PLAYER_ROLE_COEFS.pied:0;
 }
 const kicker=designatedPlayer(l,side,'pied');if(!kicker)return 0;
 const ref=staffRolePlayer(l,side,'pied');if(!ref||ref.id===kicker.id)return 0;
 return (skill(kicker,'kick',true)-skill(ref,'kick',true))*PLAYER_ROLE_COEFS.pied;
}
function occupationKicker(l,side){return designatedPlayer(l,side,'pied')||(staffJudgementRules(l)?staffRolePlayer(l,side,'pied'):null)||actionPlayer(l,side,'kicker')}
// Désignations du manager hors match (null : rendre le rôle au staff). Refus : rôle inconnu, joueur hors effectif.
function setPlayerRoles(roles){
 if(!roles||typeof roles!=='object'||Array.isArray(roles))return false;
 const own=club(),next={...(S.playerRoles||{})};
 for(const [key,id] of Object.entries(roles)){
  if(!Object.hasOwn(PLAYER_ROLES,key))return false;
  if(id===null){delete next[key];continue}
  if(typeof id!=='string'||!own.players.some(p=>p.id===id))return false;
  next[key]=id;
 }
 if(next.secours&&next.secours===next.buteur)delete next.secours;
 for(const key of Object.keys(next))if(!own.players.some(p=>p.id===next[key]))delete next[key];
 if(Object.keys(next).length)S.playerRoles=next;else delete S.playerRoles;
 return true;
}
// Jugement du staff, sang-froid et confiance (docs/jugement-staff-20261116.md, décision de Léo du 16/11/2026,
// façon Football Manager) : le staff choisit d'après SA perception des joueurs, pas d'après les vraies
// valeurs. Erreur d'estimation fixe pour chaque couple (membre du staff, joueur, attribut), tirée d'une
// empreinte et non d'un tirage : elle ne change ni d'un match à l'autre ni la suite des tirages, et elle
// diminue avec le niveau du membre concerné (entraîneur des arrières pour le but et le jeu au pied,
// entraîneur des avants pour la touche, à défaut l'adjoint puis l'entraîneur principal). Les clubs de l'IA
// suivent la même règle avec leur propre staff. Règles copiées au coup d'envoi (`staffJudgementVersion`) :
// un match commencé avant garde les siennes.
let STAFF_JUDGEMENT_RULES=1;
// Réglages de jeu (ordres de grandeur, mesurés IA contre IA : voir le document de conception).
const STAFF_JUDGEMENT={
 niveau:{min:45,max:85,defaut:60},
 // Amplitude de l'erreur (points d'attribut) au niveau minimal et au niveau maximal du staff.
 erreur:{faible:10,fort:1.5},
 // Sang-froid (trait caché « grands matchs », 41-80 dans la base, médiane 61) : effet par point d'écart à
 // la médiane sur la réussite au but et en touche dans les moments décisifs ; poids dans le jugement du
 // staff (part des tirs qui tombent dans un moment décisif) ; le staff de l'IA connaît ses joueurs avec
 // une erreur doublée.
 sangFroid:{neutre:61,but:.008,touche:.003,choix:.15,erreurIA:2},
 // Moment décisif : à partir de la 70e minute, au plus 7 points d'écart (un essai transformé).
 decisif:{minute:70,ecart:7},
 // Confiance du buteur (points, bornés) : après chaque tir, elle bouge de la surprise (réussite : gain ×
 // (1 − chance), échec : perte × chance), plus fort dans un moment décisif ; elle revient vers 0 à chaque
 // match du club ; effet par point sur la réussite ; poids dans le jugement du staff (en points de « But »).
 // Un buteur qui réussit ce qu'on attend de lui reste en moyenne à 0.
 confiance:{borne:20,ecart:6,ecartDecisif:10,retour:.75,but:.002,jugement:1/3},
 // Révélation du sang-froid : observations nécessaires et largeur de la fourchette affichée.
 revelation:{paliers:[2,5,10],largeurs:[11,9,5],rapport:3}
};
const SJ_SPECIALITES={avants:/avant|melee|scrum|touche|line.?out|forward|conquete/,arrieres:/arriere|attaque|attack|back|jeu au pied|kick|trois.quarts|3\/4/};
function sjHash(x){let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0}
function sjNorm(x){return String(x||'').normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase()}
function staffJudgementRules(l){return l?.staffJudgementVersion===1}
// Membres du staff qui jugent pour un club : spécialiste (avants, arrières), à défaut l'adjoint, à défaut
// l'entraîneur le mieux noté. Sans carrières du staff : un jugement moyen, propre au club.
function staffJudges(clubId){
 const people=S?.staffCareer?.version===1&&Array.isArray(S.staffCareer.people)?S.staffCareer.people.flat():[];
 const coaches=people.filter(p=>p&&p.clubId===clubId&&(p.role==='coach'||p.role==='assistant')&&Number.isFinite(p.level)&&(p.contractEnd==null||p.contractEnd>=S.season));
 const best=list=>list.sort((a,b)=>b.level-a.level||(a.id<b.id?-1:a.id>b.id?1:0))[0];
 const fallback=best(coaches.filter(p=>p.role==='assistant'))||best([...coaches]);
 const brief=p=>p?{id:p.id,level:p.level,name:p.name,roleLabel:p.roleLabel||null}:{id:'club:'+clubId,level:STAFF_JUDGEMENT.niveau.defaut,name:null,roleLabel:null};
 const out={};for(const [k,re] of Object.entries(SJ_SPECIALITES))out[k]=brief(best(coaches.filter(p=>re.test(sjNorm(p.roleLabel))))||fallback);
 return out;
}
function judgeFor(judges,key){return key==='lineout'||key==='scrum'?judges.avants:judges.arrieres}
function judgementAmplitude(level){const {min,max}=STAFF_JUDGEMENT.niveau,{faible,fort}=STAFF_JUDGEMENT.erreur;return clamp(fort+(faible-fort)*(max-level)/(max-min),fort,faible)}
// Erreur d'estimation (points) : moyenne de deux empreintes, centrée, d'amplitude décroissante avec le niveau.
function judgementError(judge,playerId,key){const h=sjHash(judge.id+'|'+playerId+'|'+key);return judgementAmplitude(judge.level)*(((h&0xffff)/0xffff+(h>>>16)/0xffff)-1)}
// Sang-froid : trait caché « grands matchs » des joueurs de la base ; sinon, valeur fixe tirée de l'identité,
// de même répartition (46-76, médiane 61).
function sangFroid(p){const v=p?.hiddenTraitsV2?.bigMatches;if(Number.isFinite(v))return clamp(v,0,100);const h=sjHash((p?.id||'')+':sang-froid');return 46+h%16+(h>>>8)%16}
function staffJudgementStore(){return S.staffJudgement?.version===1?S.staffJudgement:null}
function staffJudgementEnsure(){if(!staffJudgementStore())S.staffJudgement={version:1,confiance:{},vu:{}};return S.staffJudgement}
// Confiance d'un joueur au but : valeur de la carrière, ou celle du match en cours (tirs déjà pris compris).
function goalConfidence(p,l=null){if(!p)return 0;if(l?.sjConfiance&&Object.hasOwn(l.sjConfiance,p.id))return l.sjConfiance[p.id];return staffJudgementStore()?.confiance?.[p.id]||0}
function confidenceLabel(c){return c>=8?'En pleine confiance':c>=3?'En confiance':c>-3?'Normale':c>-8?'Fragile':'En perte de confiance'}
// Observations du sang-froid par le club du manager : moments décisifs vus, rapports de recrutement.
function sangFroidObservations(p){
 const vu=staffJudgementStore()?.vu?.[p.id]||0,R=STAFF_JUDGEMENT.revelation.rapport;
 const reports=(S.manager?.reports||[]).filter(r=>r.playerId===p.id).length+(S.playerKnowledge?.jobs||[]).filter(j=>j.playerId===p.id&&j.status==='done').length;
 return vu+reports*R;
}
// Fourchette affichée au manager (même mécanique que la connaissance des joueurs : fourchette stable, valeur
// vraie dedans, jamais centrée dessus) ; null tant que le joueur n'a pas été assez vu sous pression.
function sangFroidRange(p){
 if(!p)return null;const n=sangFroidObservations(p),{paliers,largeurs}=STAFF_JUDGEMENT.revelation;let width=null;
 for(let i=paliers.length-1;i>=0;i--)if(n>=paliers[i]){width=largeurs[i];break}
 if(!width)return null;const value=Math.round(sangFroid(p)),key=(S.careerVariation?.seed??S.worldMode?.edition??'monde')+':'+p.id+':sang-froid:'+width;
 if(typeof nativeKnowledge!=='undefined'&&typeof nativeKnowledge.interval==='function')return nativeKnowledge.interval(value,width,key);
 const low=Math.max(0,value-width+1),high=Math.min(101-width,value),choices=[];for(let m=low;m<=high;m++)if(m+(width-1)/2!==value)choices.push(m);
 const min=choices.length?choices[sjHash(key)%choices.length]:low;return {min,max:min+width-1};
}
// Sang-froid perçu par le staff : le club du manager sait ce qu'il a vu (milieu de la fourchette affichée,
// médiane sinon), comme le manager ; un club de l'IA connaît ses joueurs avec l'erreur de son staff, doublée.
function perceivedSangFroid(clubId,judge,p){
 const N=STAFF_JUDGEMENT.sangFroid.neutre;
 if(clubId===S.club){const r=sangFroidRange(p);return r?(r.min+r.max)/2:N}
 return clamp(sangFroid(p)+judgementError(judge,p.id,'sang-froid')*STAFF_JUDGEMENT.sangFroid.erreurIA,0,100);
}
// Valeur d'un joueur à un rôle selon le staff : attribut perçu, et pour le but la confiance (visible de tous)
// et le sang-froid perçu.
function perceivedRoleValue(clubId,judges,p,key,l=null){
 const judge=judgeFor(judges,key);let v=skill(p,key,true)+judgementError(judge,p.id,key);
 if(key==='goal'){const C=STAFF_JUDGEMENT.confiance,F=STAFF_JUDGEMENT.sangFroid;v+=goalConfidence(p,l)*C.jugement+(perceivedSangFroid(clubId,judge,p)-F.neutre)*F.choix}
 return v;
}
// Valeur réelle (mesures et tests) : vraie note, confiance et vrai sang-froid, mêmes poids.
function trueRoleValue(p,key,l=null){let v=skill(p,key,true);if(key==='goal'){const C=STAFF_JUDGEMENT.confiance,F=STAFF_JUDGEMENT.sangFroid;v+=goalConfidence(p,l)*C.jugement+(sangFroid(p)-F.neutre)*F.choix}return v}
function judgedOrder(clubId,judges,players,key,l=null){return [...players].map(p=>[p,perceivedRoleValue(clubId,judges,p,key,l)]).sort((a,b)=>b[1]-a[1]||(String(a[0].id)<String(b[0].id)?-1:1)).map(x=>x[0])}
function judgedBest(l,side,players,key){return judgedOrder(l.pair[side],l.staffJudges[side],players,key,l)[0]||null}
function initializeStaffJudgement(l){
 if(!STAFF_JUDGEMENT_RULES)return;
 l.staffJudgementVersion=1;l.staffJudgementSubs=1;l.staffJudges=l.pair.map(ci=>staffJudges(ci));l.sjConfiance={};l.sjVu={};l.sjDecisif=false;
}
// Moment décisif pour l'équipe `side` (extra : points déjà acquis avant le tir, l'essai pour une transformation).
function decisiveMoment(l,side,extra=0){const D=STAFF_JUDGEMENT.decisif;return staffJudgementRules(l)&&l.minute>=D.minute&&Math.abs(l.score[side]+extra-l.score[1-side])<=D.ecart}
function noteDecisive(l,p){l.sjDecisif=true;if(p)l.sjVu[p.id]=(l.sjVu[p.id]||0)+1}
// Part de la réussite au but propre au buteur : confiance, et sang-froid dans les moments décisifs.
// Retient la tentative pour mettre à jour la confiance une fois le tir tiré (noteGoalKick).
function goalKickPressure(l,side,kicker,conversion){
 if(!staffJudgementRules(l)||!kicker){if(l)l.sjLastKick=null;return 0}
 const decisive=decisiveMoment(l,side,conversion?5:0),C=STAFF_JUDGEMENT.confiance,F=STAFF_JUDGEMENT.sangFroid;
 if(decisive)noteDecisive(l,kicker);
 l.sjLastKick={side,id:kicker.id,decisive};
 return goalConfidence(kicker,l)*C.but+(decisive?(sangFroid(kicker)-F.neutre)*F.but:0);
}
function noteGoalKick(l,side,ok){
 const k=l?.sjLastKick;if(!staffJudgementRules(l)||!k||k.side!==side)return;l.sjLastKick=null;
 const C=STAFF_JUDGEMENT.confiance,start=Object.hasOwn(l.sjConfiance,k.id)?l.sjConfiance[k.id]:decayConfidence(staffJudgementStore()?.confiance?.[k.id]||0);
 const p=Number.isFinite(k.p)?k.p:.75,weight=k.decisive?C.ecartDecisif:C.ecart;
 l.sjConfiance[k.id]=Math.round(clamp(start+weight*((ok?1:0)-p),-C.borne,C.borne)*10)/10;
}
function decayConfidence(c){const v=Math.round(c*STAFF_JUDGEMENT.confiance.retour*10)/10;return Math.abs(v)<.5?0:v}
// Touche décisive : le sang-froid du lanceur pèse sur le lancer (lanceur désigné, sinon choix du staff).
function lineoutPressureEdge(l,side){
 if(!decisiveMoment(l,side))return 0;const thrower=designatedPlayer(l,side,'lanceur')||staffRolePlayer(l,side,'lanceur');if(!thrower)return 0;
 noteDecisive(l,thrower);return (sangFroid(thrower)-STAFF_JUDGEMENT.sangFroid.neutre)*STAFF_JUDGEMENT.sangFroid.touche;
}
// Fin de match : la confiance du match devient celle de la carrière, celle des autres joueurs des deux clubs
// revient d'un cran vers la normale ; les moments décisifs vus par le club du manager révèlent le sang-froid.
function commitStaffJudgement(l){
 if(!staffJudgementRules(l)||l.sjCommitted)return;l.sjCommitted=true;
 const st=staffJudgementEnsure();
 for(const ci of l.pair)for(const p of S.clubs[ci]?.players||[]){if(Object.hasOwn(l.sjConfiance,p.id))continue;const c=st.confiance[p.id];if(c){const v=decayConfidence(c);if(v)st.confiance[p.id]=v;else delete st.confiance[p.id]}}
 for(const [id,c] of Object.entries(l.sjConfiance)){if(c)st.confiance[id]=c;else delete st.confiance[id]}
 if(l.pair.includes(S.club)){
  pruneStaffJudgement();
  if(l.sjDecisif)for(const sh of l.sheets)for(const id of sh.on)if(id)st.vu[id]=Math.min(99,(st.vu[id]||0)+1);
  for(const [id,n] of Object.entries(l.sjVu))st.vu[id]=Math.min(99,(st.vu[id]||0)+n);
 }
}
// Nettoyage (fin de saison, chargement) : seulement les joueurs encore présents dans un effectif.
function pruneStaffJudgement(){
 const st=staffJudgementStore();if(!st)return;const ids=new Set(S.clubs.flatMap(c=>(c.players||[]).map(p=>p.id)));
 for(const map of [st.confiance,st.vu])for(const id of Object.keys(map))if(!ids.has(id))delete map[id];
}
// Lot 2 (composition, remplaçants, match délégué) : le staff du club du manager note chaque joueur à un poste
// d'après sa perception de la note au poste (erreur fixe par couple membre du staff / joueur / famille de poste,
// spécialiste des avants pour les familles 0-3, des arrières sinon), condition comprise comme la vraie note.
// Les clubs de l'IA gardent la vraie note (performance, stabilité des résultats). Les choix explicites du
// manager ne passent jamais par là : seules les places laissées au staff sont concernées.
function staffSheetJudges(c){return STAFF_JUDGEMENT_RULES&&c&&S&&c.id===S.club?staffJudges(c.id):null}
function perceivedFit(judges,p,f=p.fam){return (roleNote(p,f)+judgementError(f<=3?judges.avants:judges.arrieres,p.id,'poste'+f))*(.5+p.condition*.005)}
// Remplacements décidés par le staff en match (match délégué, « faire les changements ») : seulement pour le
// club du manager et les rencontres commencées avec ces règles (`staffJudgementSubs`, copié au coup d'envoi).
function staffSubsFit(l,side){if(!(l?.staffJudgementSubs===1&&l.pair?.[side]===S.club&&l.staffJudges?.[side]))return fitScore;const j=l.staffJudges[side];return (p,f=p.fam)=>perceivedFit(j,p,f)}
// Pour l'interface hors match : choix du staff du club du manager parmi `players` (attribut `key`).
function staffPickOutsideMatch(players,key){if(!STAFF_JUDGEMENT_RULES)return null;return judgedOrder(S.club,staffJudges(S.club),players,key)[0]||null}
// Lecture pour l'interface : pour chaque rôle, choix du staff, joueur désigné et candidats du XV
// (valeur de l'attribut du rôle, condition comprise). Alerte quand le buteur désigné tire nettement moins
// bien que le choix du staff (seuil en points d'attribut).
const PLAYER_ROLE_ALERT=8;
function playerRolesView(){
 const own=club(),xv=S.lineup.map(id=>own.players.find(p=>p.id===id)).filter(Boolean),designated=S.playerRoles||{};
 // Jugement du staff : le choix proposé et son estimation sont ceux du staff (perception), les valeurs
 // affichées restent les vraies valeurs de la fiche ; confiance et sang-froid (fourchette quand il a été vu).
 const judging=!!STAFF_JUDGEMENT_RULES,judges=judging?staffJudges(S.club):null;
 const value=(p,k)=>p?Math.round(skill(p,k,true)):null;
 const brief=(p,k)=>{if(!p)return null;const out={id:p.id,name:p.name,pos:p.pos,value:value(p,k)};if(judging){out.estimation=Math.round(skill(p,k,true)+judgementError(judgeFor(judges,k),p.id,k));if(k==='goal'){const c=goalConfidence(p);out.confiance={value:c,label:confidenceLabel(c)}}out.sangFroid=sangFroidRange(p)}return out};
 const best=(list,k)=>judging?staffPickOutsideMatch(list,k):[...list].sort((a,b)=>skill(b,k,true)-skill(a,k,true))[0]||null;
 const kicker=list=>judging?staffPickOutsideMatch(list,'goal'):chooseScorer(own,list.map(p=>p.id));
 const staffOf=role=>{const k=PLAYER_ROLES[role][1];if(role==='buteur')return kicker(xv);if(role==='secours'){const first=designated.buteur&&S.lineup.includes(designated.buteur)?designated.buteur:kicker(xv)?.id;return kicker(xv.filter(p=>p.id!==first))}if(role==='lanceur')return own.players.find(p=>p.id===S.lineup[1]&&p.fam===1)||[...xv.filter(p=>p.fam===1)].sort((a,b)=>skill(b,k,true)-skill(a,k,true))[0]||null;return best(xv.filter(p=>p.fam>=4),k)};
 const roles=Object.entries(PLAYER_ROLES).map(([id,[label,k]])=>{const chosen=own.players.find(p=>p.id===designated[id])||null;return {id,label,attribute:k,attributeLabel:ATTR[k]||k,staff:brief(staffOf(id),k),chosen:brief(chosen,k),inLineup:!!chosen&&S.lineup.includes(chosen.id),candidates:[...xv].sort((a,b)=>skill(b,k,true)-skill(a,k,true)||String(a.id).localeCompare(String(b.id))).map(p=>brief(p,k))}});
 const buteur=roles.find(r=>r.id==='buteur'),alerte=buteur.chosen&&buteur.staff&&buteur.inLineup&&buteur.staff.value-buteur.chosen.value>=PLAYER_ROLE_ALERT?{playerId:buteur.chosen.id,name:buteur.chosen.name,value:buteur.chosen.value,staffName:buteur.staff.name,staffValue:buteur.staff.value}:null;
 const avis=judging?Object.fromEntries(Object.entries(judges).map(([k,j])=>[k,j.name?{name:j.name,roleLabel:j.roleLabel}:null])):null;
 return {editable:!S.live&&S.phase!=='ended',roles,alerte,...(avis?{avis}:{})};
}
// Buteur proposé par le staff pour la feuille du manager (projection `kicker`).
function staffKickerId(){const own=club();if(S.playerRoles?.buteur&&S.lineup.includes(S.playerRoles.buteur))return S.playerRoles.buteur;if(!STAFF_JUDGEMENT_RULES)return chooseScorer(own,S.lineup)?.id||null;return staffPickOutsideMatch(S.lineup.map(id=>own.players.find(p=>p.id===id)).filter(Boolean),'goal')?.id||null}
function captureMatchAction(l,type,meta={}){
 if(l.userSide<0)return undefined;
 const prior=l.events.at(-1)?.scene,kind=meta.kind||(['turnover','try','goal','penalty','advantage','card','sub','tactic','break','end'].includes(type)?type:'message');
 const team=meta.team??l.possession;
 const neutral=['message','card','sub','tactic','break','end','advantage'].includes(kind);
 const base={x:neutral&&prior?prior.to.x:l.territory,y:prior?.to.y??35};
 const from={...(meta.from||base)},to={...(meta.to||from)};
 return {v:1,kind,team,...(meta.move?{move:meta.move}:{}),...(ACTION_CAUSES[kind]?.includes(meta.cause)?{cause:meta.cause}:{}),...(kind==='card'&&ACTION_CARDS.includes(meta.card)?{card:meta.card}:{}),...(kind==='try'&&ACTION_TRY_ORIGINS.includes(meta.origin)&&typeof meta.conversion==='boolean'?{origin:meta.origin,conversion:meta.conversion}:{}),...(kind==='carry'&&meta.tackler!=null?{tackler:meta.tackler}:{}),style:effectiveAttack(l,team),...(tacticalRules(l)?{plans:{attack:[0,1].map(side=>effectiveAttack(l,side)),defence:[0,1].map(side=>effectiveDefence(l,side))}}:{}),incident:meta.incident===true,possession:meta.possession??l.possession,actor:meta.actor??null,from,to,score:[...l.score],tries:[...l.tries],on:l.sheets.map((sh,side)=>{const active=new Set(activePlayers(l,side).map(p=>p.id));return sh.on.map(id=>active.has(id)?id:null)}),period:l.flow?.period||(l.minute>40?2:1)};
}
function playback(l){l=l.visualSource||l;let p=MATCH_PLAYBACK.get(l);if(!p){p={cursor:l.events.length-1,stop:false};MATCH_PLAYBACK.set(l,p)}return p}
function presentationPending(l){l=l.visualSource||l;return playback(l).cursor<l.events.length-1}
function displayedAction(l){l=l.visualSource||l;return l.events[playback(l).cursor]||null}
function syncMatchPresentation(l){l=l.visualSource||l;MATCH_PLAYBACK.set(l,{cursor:l.events.length-1,stop:false})}
function matchViewState(l){
 const p=playback(l),e=displayedAction(l),s=e?.scene;if(!s||!presentationPending(l))return l;
 const flow=l.flow?{...l.flow,period:s.period,atBreak:false}:undefined;
 return {...l,...(s.plans?{tactics:s.plans.attack,defences:s.plans.defence}:{}),visualSource:l,minute:e.min,score:s.score,tries:s.tries,possession:s.possession,territory:s.to.x,paused:false,finished:false,...(flow?{flow}:{})};
}
function presentationTick(l){
 const p=playback(l);let changed=false;
 if(presentationPending(l))p.cursor++;
 else{
  if(l.paused||l.finished)return;
  changed=true;const before=l.events.length;p.running=true;try{advanceRugby(l)}finally{p.running=false}
  p.cursor=l.events.length>before?before:l.events.length-1;
  p.stop=l.events.slice(before).some(e=>pauseOnTry&&e.type==='try'||pauseOnCard&&e.type==='card'&&e.scene?.incident);
 }
 if(!presentationPending(l)&&p.stop&&!l.finished){l.paused=true;p.stop=false;changed=true;}
 if(!presentationPending(l)&&(l.paused||l.finished))clearInterval(timer);
 if(changed)save();render();
}
function setAutoPause(kind,enabled){if(kind==='try')pauseOnTry=!!enabled;if(kind==='card')pauseOnCard=!!enabled;try{gameStorage.setItem('bdt-match-view',JSON.stringify({try:pauseOnTry,card:pauseOnCard}))}catch(e){}render()}
function autoPauseControls(){return `<fieldset class="auto-pause"><legend>Pause après la séquence</legend><label><input type="checkbox" ${pauseOnTry?'checked':''} onchange="setAutoPause('try',this.checked)"> Essai</label><label><input type="checkbox" ${pauseOnCard?'checked':''} onchange="setAutoPause('card',this.checked)"> Carton</label></fieldset>`}
function openMatchPlayer(side,id){
 const l=S.live;if(!l||![0,1].includes(side))return;
 const p=matchPlayer(l,side,id);if(!p)return;
 pauseMatch();syncMatchPresentation(l);
 const slot=l.sheets[side].on.indexOf(id),active=activePlayers(l,side).some(p=>p.id===id),mine=side===l.userSide;
 const choices=mine&&active&&slot>=0&&!l.finished?eligibleChanges(l,side,slot):[];
 modal=`<div class="modalback"><section class="modal playerdetail" role="dialog" aria-modal="true" aria-label="Joueur sur le terrain"><div class="row" style="margin-top:0"><span class="tag">${S.clubs[l.pair[side]].abbr} · ${p.pos}</span><button class="small" onclick="closeModal()">Fermer ×</button></div><h2>${visualEscape(p.name)}</h2><p>Condition : <strong>${Math.round(p.condition)}%</strong> · Note au poste : <strong>${roleNote(p)}</strong><br>Minutes jouées : ${Math.round(l.sheets[side].minutes[id]||0)}</p><div class="attributes">${Object.entries(ATTR).map(([key,label])=>`<div class="row"><span>${label}</span><strong>${Math.round(skill(p,key))}</strong></div>`).join('')}</div>${choices.length?`<label for="pitch-sub">Faire entrer à sa place</label><select id="pitch-sub" onchange="if(this.value)replaceMatchPlayer(${slot},this.value)"><option value="">Choisir un remplaçant…</option>${choices.map(c=>`<option value="${c.id}">${visualEscape(c.name)} · ${Math.round(c.condition)}%</option>`).join('')}</select>`:`<p class="help">${!mine?'Joueur adverse.':!active?'Ce joueur n’est plus présent sur le terrain.':l.finished?'Le match est terminé.':'Aucun remplacement disponible à ce poste.'}</p>`}<p class="help">${l.finished?'Le match est terminé.':'Le match reste en pause après fermeture.'}</p></section></div>`;render();
}
function replaceMatchPlayer(slot,id){const l=S.live;if(!l?.paused||l.finished)return;if(makeSub(l,l.userSide,slot,id)){modal=null;syncMatchPresentation(l);save();render();toast('Remplacement effectué.')}else toast('Ce remplacement n’est plus disponible.')}
