'use strict';
// Arbitrage fin (19/11/2026, docs/rugby-rules-reference.md § « Arbitrage fin ») : chaque pénalité sifflée reçoit une
// cause détaillée et une famille (touche, mêlée, ruck, maul, jeu courant), et une partie des touches perdues devient un
// lancer pas droit (loi 18). Raffinement seulement : l'incident, sa fréquence, son drapeau `serious` et la décision de
// carton (rugby.js) restent ceux tirés avant ; la cause détaillée est choisie sans tirage (empreinte de la minute et des
// compteurs du match), pour ne rien décaler dans la suite du match. Rencontres créées avec `arbitrageVersion` seulement :
// les autres gardent textes et statistiques d'avant.
let ARBITRAGE_RULES=1;
function initializeArbitrage(l){
 if(!ARBITRAGE_RULES)return;
 l.arbitrageVersion=1;
 for(const st of l.stats)Object.assign(st,arbitrageStatsVides());
}
function arbitrageRules(l){return l?.arbitrageVersion===1&&typeof revisedRules==='function'&&revisedRules(l)}
// « de BOR », « d’AFN » : élision devant une voyelle.
function arbitrageDe(a){return /^[AEIOUYÉÈ]/i.test(a)?'d’'+a:'de '+a}
const ARBITRAGE_FAMILLES=Object.freeze({touche:'touche',melee:'mêlée',ruck:'ruck',maul:'maul',jeu:'jeu courant'});
// Causes détaillées : famille et commentaires (a = équipe fautive, b = équipe qui obtient la pénalité, r = « fautes
// répétées »). Lois World Rugby 2025 : 15 (ruck), 16 (maul), 18 (touche), 19 (mêlée), 9 et 10 (jeu déloyal, hors-jeu).
const ARBITRAGE_CAUSES=Object.freeze({
 'ruck-offside':{famille:'ruck',textes:[
  (a,b,r)=>`Hors-jeu au ruck ${arbitrageDe(a)}${r}, pénalité pour ${b}.`,
  (a,b,r)=>`${a} quitte la ligne avant que le ballon sorte du ruck${r} : hors-jeu, pénalité pour ${b}.`,
  (a,b,r)=>`L’arbitre siffle un hors-jeu ${arbitrageDe(a)} au regroupement${r}. Pénalité pour ${b}.`]},
 offside:{famille:'jeu',textes:[
  (a,b,r)=>`Hors-jeu ${arbitrageDe(a)} dans le jeu courant${r}, pénalité pour ${b}.`,
  (a,b,r)=>`${a} joue en position de hors-jeu${r} : pénalité pour ${b}.`]},
 'ruck-side-entry':{famille:'ruck',textes:[
  (a,b,r)=>`Entrée sur le côté du ruck pour ${a}${r}. Pénalité pour ${b}.`,
  (a,b,r)=>`${a} rentre dans le ruck par le côté, pas par la porte${r} : pénalité pour ${b}.`]},
 'ruck-hands':{famille:'ruck',textes:[
  (a,b,r)=>`Mains au sol dans le ruck pour ${a}${r} : pénalité pour ${b}.`,
  (a,b,r)=>`Un joueur ${arbitrageDe(a)} joue le ballon à la main dans le ruck${r}. Pénalité pour ${b}.`]},
 holding:{famille:'ruck',textes:[
  (a,b,r)=>`${a} garde les mains sur le ballon une fois le ruck formé${r}. Pénalité pour ${b}.`,
  (a,b,r)=>`Ballon tenu au sol par ${a}${r} : pénalité pour ${b}.`]},
 'not-release':{famille:'ruck',textes:[
  (a,b,r)=>`Le porteur ${arbitrageDe(a)} ne libère pas le ballon au sol${r}. Pénalité pour ${b}.`,
  (a,b,r)=>`Ballon non libéré par ${a} après le plaquage${r} : pénalité pour ${b}.`]},
 sealing:{famille:'ruck',textes:[
  (a,b,r)=>`Scellement du ballon par ${a} dans le ruck${r} : pénalité pour ${b}.`,
  (a,b,r)=>`Un soutien ${arbitrageDe(a)} se couche sur le ballon au ruck${r}. Pénalité pour ${b}.`]},
 obstruction:{famille:'jeu',textes:[
  (a,b,r)=>`Obstruction ${arbitrageDe(a)} sur un joueur sans ballon${r}. Pénalité pour ${b}.`,
  (a,b,r)=>`${a} gêne un adversaire qui n’a pas le ballon${r} : obstruction, pénalité pour ${b}.`]},
 dangerous:{famille:'jeu',textes:[
  (a,b,r)=>`Plaquage dangereux ${arbitrageDe(a)}${r}. Pénalité pour ${b}.`,
  (a,b,r)=>`Geste dangereux ${arbitrageDe(a)} au plaquage${r} : pénalité pour ${b}.`]},
 scrum:{famille:'melee',textes:[
  (a,b,r)=>`Faute ${arbitrageDe(a)} en mêlée${r}, pénalité pour ${b}.`,
  (a,b,r)=>`La mêlée s’écroule côté ${a}${r} : pénalité pour ${b}.`,
  (a,b,r)=>`${a} ne pousse pas droit en mêlée${r}. Pénalité pour ${b}.`]},
 'lineout-obstruction':{famille:'touche',textes:[
  (a,b,r)=>`Obstruction dans l’alignement ${arbitrageDe(a)}${r} : pénalité pour ${b}.`,
  (a,b,r)=>`${a} gêne un sauteur dans l’alignement${r}. Pénalité pour ${b}.`]},
 'maul-collapse':{famille:'maul',textes:[
  (a,b,r)=>`Écroulement du maul par ${a}${r}. Pénalité pour ${b}.`,
  (a,b,r)=>`${a} fait tomber le ballon porté${r} : pénalité pour ${b}.`]},
 'maul-entry':{famille:'maul',textes:[
  (a,b,r)=>`Entrée illégale dans le maul pour ${a}${r} : pénalité pour ${b}.`,
  (a,b,r)=>`${a} rejoint le ballon porté par le côté${r}. Pénalité pour ${b}.`]}
});
// Part des touches perdues qui sont des lancers pas droits (une sur cinq), sans changer le taux de touches perdues.
const ARBITRAGE_LANCER={part:5};
function arbitrageStatsVides(){return {penaltyFamilies:Object.fromEntries(Object.keys(ARBITRAGE_FAMILLES).map(k=>[k,0])),penaltyCauses:{},lineoutNotStraight:0}}
function arbitrageEmpreinte(l,camp){return Math.abs(l.minute*31+(l.stats[camp]?.penalties||0)*17+(l.stats[camp]?.lineouts||0)*11+camp*7+l.events.length*13)}
// Cause détaillée d'un incident déjà tiré (rugby.js, awardPenalty) : jamais un tirage de plus.
function arbitrageCause(l,foul,incident,options={}){
 const h=arbitrageEmpreinte(l,foul);
 switch(incident.id){
  case 'offside':return h%3<2?'ruck-offside':'offside';
  case 'ruck':return h%2?'ruck-hands':'ruck-side-entry';
  // Faute en touche ou sur ballon porté (penaliteConquete) : l'équipe qui lance n'écroule pas son propre maul.
  case 'maul':{const lanceur=options.lanceur===foul;if(lanceur)return h%2?'maul-entry':'lineout-obstruction';const k=h%10;return k<4?'lineout-obstruction':k<7?'maul-collapse':'maul-entry'}
  default:return ARBITRAGE_CAUSES[incident.id]?incident.id:null;
 }
}
// Pénalité détaillée : compte la cause et sa famille pour l'équipe fautive et rend le commentaire.
function arbitrageFaute(l,foul,side,incident,repeated,options={}){
 if(!arbitrageRules(l))return null;
 const id=arbitrageCause(l,foul,incident,options),cause=ARBITRAGE_CAUSES[id];if(!cause)return null;
 const st=l.stats[foul];
 if(!st.penaltyFamilies)Object.assign(st,arbitrageStatsVides());
 st.penaltyFamilies[cause.famille]++;st.penaltyCauses[id]=(st.penaltyCauses[id]||0)+1;
 const texte=cause.textes[(l.minute+st.penalties)%cause.textes.length](S.clubs[l.pair[foul]].abbr,S.clubs[l.pair[side]].abbr,repeated?' (fautes répétées)':'');
 return {id,famille:cause.famille,texte};
}
// Touche perdue (rugby.js, contestSetPiece) : une sur cinq, sans tirage, est un lancer pas droit. Loi 18 : l'adversaire
// choisit alors une touche ou une mêlée ; le moteur ne rejoue pas de phase de plus (fréquence des pénalités de mêlée
// inchangée) et rend simplement le ballon à l'équipe adverse. Rend vrai si le commentaire est écrit ici.
function arbitrageLancer(l,side,at){
 if(!arbitrageRules(l))return false;
 const opp=1-side,st=l.stats[side];
 if(arbitrageEmpreinte(l,side)%ARBITRAGE_LANCER.part)return false;
 st.lineoutNotStraight=(st.lineoutNotStraight||0)+1;
 const a=S.clubs[l.pair[side]].abbr,b=S.clubs[l.pair[opp]].abbr;
 const textes=[`Lancer pas droit ${arbitrageDe(a)} : ${b} récupère l’introduction.`,`Le lancer ${arbitrageDe(a)} n’est pas droit : ballon rendu à ${b}, qui avait le choix entre touche et mêlée.`,`Lancer pas droit ${arbitrageDe(a)}, l’arbitre rend le ballon à ${b}.`];
 addEvent(l,textes[(l.minute+st.lineouts)%textes.length],'turnover',{kind:'setpiece-loss',team:opp,from:{x:at,y:4},to:{x:at,y:15},actor:null,detail:'not-straight'});
 return true;
}
// Détail accepté sur une scène d'action (match-actions.js, saves.js).
function arbitrageDetailValide(kind,detail){return kind==='penalty'?Object.hasOwn(ARBITRAGE_CAUSES,detail):kind==='setpiece-loss'&&detail==='not-straight'}
// Validation de sauvegarde des compteurs ajoutés à `l.stats[camp]` (saves.js).
function arbitrageStatsValides(st){
 if(st.penaltyFamilies===undefined&&st.penaltyCauses===undefined&&st.lineoutNotStraight===undefined)return true;
 const f=st.penaltyFamilies,c=st.penaltyCauses;
 if(!f||typeof f!=='object'||Array.isArray(f)||!c||typeof c!=='object'||Array.isArray(c))return false;
 if(Object.keys(f).length!==Object.keys(ARBITRAGE_FAMILLES).length||!Object.keys(ARBITRAGE_FAMILLES).every(k=>Number.isInteger(f[k])&&f[k]>=0))return false;
 if(!Object.entries(c).every(([k,n])=>Object.hasOwn(ARBITRAGE_CAUSES,k)&&Number.isInteger(n)&&n>0))return false;
 const total=Object.values(f).reduce((n,v)=>n+v,0);
 if(Object.values(c).reduce((n,v)=>n+v,0)!==total||total>st.penalties)return false;
 for(const k of Object.keys(ARBITRAGE_FAMILLES))if(Object.entries(c).filter(([id])=>ARBITRAGE_CAUSES[id].famille===k).reduce((n,[,v])=>n+v,0)!==f[k])return false;
 return Number.isInteger(st.lineoutNotStraight)&&st.lineoutNotStraight>=0&&st.lineoutNotStraight<=st.lineouts-st.lineoutsWon;
}
// Ligne courte pour l'écran de statistiques : « 3 ruck · 2 touche · 1 maul » (familles les plus fréquentes d'abord).
function arbitrageResume(st){
 const f=st?.penaltyFamilies;if(!f)return '';
 const rangs=Object.keys(ARBITRAGE_FAMILLES).filter(k=>f[k]>0).sort((x,y)=>f[y]-f[x]);
 return rangs.length?rangs.map(k=>f[k]+' '+ARBITRAGE_FAMILLES[k]).join(' · '):'aucune';
}
