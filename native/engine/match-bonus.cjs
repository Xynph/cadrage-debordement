'use strict';
// Dilemme du bonus en fin de match (18/11/2026, mesure : scripts/mesure-bonus-fin-de-match.cjs).
//
// Le barème vient des fonctions mêmes des classements (CDWorldCareer.matchBonus : Top 14 / Pro D2, PREM, URC,
// coupes d'Europe, Super Rugby, Japon, Championship, Nationale) : `regle` le lit en sondant l'évaluateur, sans
// recopier les seuils. Hors phase de classement (élimination directe, barrage, amical), aucune règle : rien n'est
// affiché ni décidé.
//
// - `projection` (direct de l'écran 2D, match-direct.cjs) : règle courte, état du bonus offensif et défensif vu de
//   notre camp, et à partir de la 65e minute une situation de manager avec deux consignes existantes
//   (set_tactics {attack, defense} et set_penalty_policy).
// - `installHooks` (moteur) : les clubs IA tranchent le même dilemme à la 65e, 70e et 75e minute (selon le score,
//   le temps restant et leur place au classement) et l'appliquent par les mêmes consignes.
// La factory est autonome : elle est sérialisée dans la machine du moteur (worker.cjs).
function factory(){
 // Minute (montrée) à partir de laquelle la situation devient un dilemme de manager.
 const MINUTE_DILEMME=65;
 // Revues de l'IA (minute du match) : une décision toutes les cinq minutes de la fin de match.
 const REVUES_IA=Object.freeze([65,70,75]);
 // Essais au plus à aller chercher pour parler de bonus offensif (au-delà, ce n'est plus un dilemme).
 const ESSAIS_MAX=2;
 // Points au plus à refaire pour revenir dans le bonus défensif (trois pénalités).
 const POINTS_MAX=9;
 // Consignes proposées : uniquement les commandes existantes (TACTICS, DEFENCES, PENALTY_POLICIES). Étalonnées par
 // scripts/mesure-bonus-fin-de-match.cjs (XV identiques, 60e → fin) : l'attaque au large marque plus d'essais et va
 // plus souvent au bonus offensif, mais perd plus de ballons et concède plus d'essais (ballon de contre) ; le jeu au
 // près avec défense prudente et points pris fait l'inverse. Bonus défensif en poche : « tout pour la victoire » gagne
 // plus souvent mais perd plus souvent le point. Limite constatée : les pénalités tentées rapportent moins que la
 // pénaltouche en fin de match (le bonus défensif vient surtout des essais), à examiner avec la hiérarchie des pénalités.
 const CONSIGNES=Object.freeze({
  viser:Object.freeze({label:'Viser le bonus',attack:'large',defense:'equilibre',penalty:'touch',aide:'Jeu au large, pénaltouche : plus d’essais, mais plus de ballons perdus et de contres.'}),
  securiser:Object.freeze({label:'Sécuriser',attack:'conquete',defense:'prudente',penalty:'points',aide:'Jeu au près, défense prudente, on prend les points : moins de ballons perdus et d’essais encaissés, moins d’essais marqués.'}),
  defensif:Object.freeze({label:'Aller chercher le bonus défensif',attack:'conquete',defense:'prudente',penalty:'points',aide:'Jeu au près, défense prudente, pénalités tentées : on refait les points qui manquent sans se découvrir.'}),
  victoire:Object.freeze({label:'Tout pour la victoire',attack:'large',defense:'prudente',penalty:'touch',aide:'Jeu au large, pénaltouche : tout pour l’essai, au risque de perdre des ballons et le point de bonus.'}),
  garder:Object.freeze({label:'Garder le bonus défensif',attack:'conquete',defense:'prudente',penalty:'points',aide:'Jeu au près, défense prudente, pénalités tentées : on protège le point de bonus.'})
 });
 const OPTIONS=Object.freeze({offensif:['viser','securiser'],defensif:['defensif','victoire'],tenu:['victoire','garder']});
 const pluriel=(n,mot)=>n+' '+mot+(n>1?'s':'');

 // Barème d'un évaluateur (score, essais) → [{bo, bd}, {bo, bd}] : seuil d'essais (écart ou nombre marqué),
 // victoire exigée ou non, écart maximal de la défaite bonifiée. null si l'évaluateur n'accorde aucun bonus.
 function regle(evaluer){
  if(typeof evaluer!=='function')return null;
  const bo=(score,essais)=>{try{return !!evaluer(score,essais)?.[0]?.bo}catch{return false}};
  const bd=(score,essais)=>{try{return !!evaluer(score,essais)?.[0]?.bd}catch{return false}};
  let n=0;for(let k=1;k<=8&&!n;k++)if(bo([5*k,0],[k,0]))n=k;
  let ecart=0;for(let d=1;d<=20&&bd([0,d],[0,0]);d++)ecart=d;
  const offensif=n?{type:bo([5*n+20,5],[n,1])?'essais':'ecart',n,victoire:!bo([5*n,5*n+10],[n,0])}:null;
  const defensif=ecart?{ecart}:null;
  return offensif||defensif?{offensif,defensif}:null;
 }
 function libelle(r){
  if(!r)return '';
  const o=r.offensif,parts=[];
  if(o)parts.push((o.victoire?'victoire avec ':'')+pluriel(o.n,'essai')+(o.type==='ecart'?' d’écart':' marqués'));
  if(r.defensif)parts.push('défaite de '+r.defensif.ecart+' pts ou moins');
  return parts.join(' · ');
 }
 function acquis(r,score,essais,u){
  const o=r?.offensif;if(!o)return false;const v=1-u;
  return (o.type==='ecart'?essais[u]-essais[v]>=o.n:essais[u]>=o.n)&&(!o.victoire||score[u]>score[v]);
 }
 // Essais (non transformés) qui manquent pour le bonus offensif ; null au-delà de six.
 function manque(r,score,essais,u){
  for(let k=0;k<=6;k++){
   const s=score.slice(),t=essais.slice();s[u]+=5*k;t[u]+=k;
   if(acquis(r,s,t,u))return k;
  }
  return null;
 }
 // Actions de marque encore possibles (une toutes les cinq minutes, au moins la dernière) : choix de jeu prudent.
 const possibles=minute=>minute>=80?1:1+Math.floor(Math.max(0,80-minute)/5);
 function etat(r,score,essais,u,minute){
  const v=1-u,e=score[u]-score[v];
  let offensif=null,defensif=null;
  if(r?.offensif){
   const k=manque(r,score,essais,u),hors=k===null||k>possibles(minute);
   offensif={acquis:k===0,manque:k,horsDePortee:k!==0&&hors,
    texte:k===0?'Bonus offensif acquis':hors?'Bonus offensif hors de portée':'Bonus offensif à '+pluriel(k,'essai')};
  }
  if(r?.defensif&&e<0){
   const L=r.defensif.ecart,tenu=-e<=L;
   defensif={statut:tenu?'tenu':'perdu',manque:tenu?0:-e-L,texte:tenu?'Bonus défensif tenu':'Bonus défensif à '+pluriel(-e-L,'point')};
  }else if(r?.defensif)defensif={statut:'sans-objet',manque:null,texte:''};
  return {ecart:e,offensif,defensif};
 }
 // Situation de manager (65e minute et au-delà) : null s'il n'y a pas de vrai dilemme de bonus.
 function situation(r,score,essais,u,minute,fini=false){
  if(!r||fini||!(minute>=MINUTE_DILEMME))return null;
  const st=etat(r,score,essais,u,minute),e=st.ecart,v=1-u,quand=' à la '+minute+'e';
  let cle=null,texte='';
  if(e>0&&st.offensif&&!st.offensif.acquis&&!st.offensif.horsDePortee&&st.offensif.manque<=ESSAIS_MAX){
   const o=r.offensif,d=essais[u]-essais[v];
   const ou=o.type==='ecart'?(d>0?pluriel(d,'essai')+' d’écart':'à '+pluriel(st.offensif.manque,'essai')+' du bonus'):pluriel(essais[u],'essai')+' marqué'+(essais[u]>1?'s':'');
   cle='offensif';texte='+'+e+quand+', '+ou+' : viser le bonus offensif ou sécuriser la victoire ?';
  }else if(e<0&&st.defensif?.statut==='perdu'&&st.defensif.manque<=POINTS_MAX&&Math.ceil(st.defensif.manque/3)<=possibles(minute)){
   cle='defensif';texte='−'+(-e)+quand+' : revenir à '+r.defensif.ecart+' points pour le bonus défensif ?';
  }else if(e<0&&st.defensif?.statut==='tenu'){
   cle='tenu';texte='−'+(-e)+quand+', bonus défensif en poche : tenter la victoire ou garder le point ?';
  }
  if(!cle)return null;
  return {cle,texte,consignes:OPTIONS[cle].map(id=>({id,...CONSIGNES[id]}))};
 }
 // Choix d'un club IA : `enjeu` = club proche d'une ligne du classement (qualification, dernière place), pour qui
 // chaque point compte ; `reste` = minutes à jouer.
 function decisionIA(sit,{ecart,manque:k,reste,enjeu}){
  if(!sit)return null;
  if(sit.cle==='offensif')return ecart>=8||ecart>=4&&k===1&&enjeu?'viser':'securiser';
  if(sit.cle==='defensif')return -ecart<=7&&reste>=8?'victoire':'defensif';
  if(sit.cle==='tenu')return -ecart<=3||reste>=12&&!enjeu?'victoire':'garder';
  return null;
 }
 // Projection du direct, vue de notre camp (`camp`), sur le journal montré (score, essais, minute).
 function projection(r,{score,essais,camp,minute,fini}){
  if(!r||(camp!==0&&camp!==1))return null;
  const s=[score?.[0]|0,score?.[1]|0],t=[essais?.[0]|0,essais?.[1]|0],m=Number(minute)||0,st=etat(r,s,t,camp,m);
  return {version:1,regle:libelle(r),offensif:st.offensif,defensif:st.defensif,situation:situation(r,s,t,camp,m,fini===true)};
 }

 // --- Moteur (machine du moteur seulement) ---------------------------------------------------------
 const REGLES=new Map();
 function regleDuMatch(l){
  const f=l?.worldContext;
  if(!f||typeof CDWorldCareer==='undefined'||typeof CDWorldCareer.matchBonus!=='function')return null;
  const cle=f.competitionId+'|'+f.phase;
  if(!REGLES.has(cle)){let r=null;try{r=regle(CDWorldCareer.matchBonus(S,f));}catch{r=null;}REGLES.set(cle,r);}
  return REGLES.get(cle);
 }
 // Club proche d'une ligne : à deux places de la dernière place qualificative, ou dans les deux dernières places.
 function enjeuClassement(l,side){
  try{
   const id=l.worldContext.competitionId,rows=CDWorldCareer.rows(S,id),club=l.pair[side],i=rows.findIndex(r=>r.clubId===club);
   if(i<0||!rows.some(r=>(r.played|0)>0))return false;
   const rang=i+1,q=CDWorldCareer.qualifyingPlaces(S,id)|0;
   return rang>=rows.length-1||q>0&&rang>=q-1&&rang<=q+2;
  }catch{return false;}
 }
 const PHRASES_IA=Object.freeze({viser:'vise le bonus offensif',securiser:'sécurise sa victoire',defensif:'va chercher le bonus défensif',victoire:'joue la victoire jusqu’au bout',garder:'protège son bonus défensif'});
 function deciderIA(l,side){
  if(!l||l.finished||side===l.userSide||![0,1].includes(side))return null;
  if(typeof tacticalRules==='function'&&!tacticalRules(l))return null;
  if(typeof difficultyLevel==='function'&&difficultyLevel(l)==='decouverte')return null;
  const minute=typeof matchMinute==='function'?matchMinute(l):l.minute;
  if(!REVUES_IA.includes(minute))return null;
  const r=regleDuMatch(l);if(!r)return null;
  const sit=situation(r,l.score,l.tries,side,minute,false);if(!sit)return null;
  const id=decisionIA(sit,{ecart:l.score[side]-l.score[1-side],manque:manque(r,l.score,l.tries,side),reste:Math.max(0,80-minute),enjeu:enjeuClassement(l,side)});
  const c=CONSIGNES[id];if(!c)return null;
  l.penaltyPolicies=l.penaltyPolicies||['auto','auto'];
  const change=l.tactics[side]!==c.attack||(l.defences?.[side]||'equilibre')!==c.defense||l.penaltyPolicies[side]!==c.penalty;
  l.tactics[side]=c.attack;if(l.defences)l.defences[side]=c.defense;l.penaltyPolicies[side]=c.penalty;
  if(change&&typeof addEvent==='function')addEvent(l,`${S.clubs[l.pair[side]].abbr} ${PHRASES_IA[id]}.`,'tactic',{team:side});
  return id;
 }
 // Branche la décision de fin de match des clubs IA après leur revue habituelle (adaptManager, chaque minute).
 function installHooks(){
  if(typeof adaptManager!=='function'||adaptManager.bonusFinDeMatch)return false;
  const base=adaptManager;
  const branche=function(l,side){const r=base.apply(this,arguments);deciderIA(l,side);return r;};
  branche.bonusFinDeMatch=true;
  adaptManager=branche;
  return true;
 }
 return {MINUTE_DILEMME,REVUES_IA,CONSIGNES,OPTIONS,regle,libelle,acquis,manque,etat,situation,decisionIA,projection,regleDuMatch,enjeuClassement,deciderIA,installHooks};
}
module.exports={factory,...factory()};
