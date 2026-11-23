'use strict';
// Fragilité physique (revue FM27, fenêtre blessure ; décision de Léo du 22/11/2026) : une valeur par joueur, de 0
// (très solide) à 100 (très fragile), qui augmente ou baisse réellement son risque de blessure.
//  - vrais joueurs : la résistance aux blessures cachée des bases (hiddenTraitsV2.injuryResistance, 50 à 76) ramenée
//    sur 0-100 : fragilité = (76 − résistance) × 100 / 26 ;
//  - joueurs créés (sans cette résistance) : tirée une fois par empreinte stable de l'identifiant, sur la même
//    échelle de résistance (50 à 76), et enregistrée sur le joueur (p.fragilite) ; les carrières déjà commencées la
//    reçoivent au premier chargement (observe(), après chaque commande).
// Effet (modéré et lisible) : risque × (1 + (fragilité − 50) × 0,005), soit de −25 % (fragilité 0) à +25 %
// (fragilité 100). Appliqué aux trois tirages de blessure (après match dans dist/rugby.js, séance intensive dans
// dist/game.js, choix du blessé d'un incident de match dans incidents-match.cjs) et au tirage de rechute du courrier
// (club-mail.cjs). Fonctions globales de la VM : valeurFragilite(p), facteurFragilite(p).
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const RES_MIN=50,RES_MAX=76,PENTE=.005;
 const fini=x=>typeof x==='number'&&Number.isFinite(x);
 const borne=(x,a,b)=>Math.max(a,Math.min(b,x));
 function empreinte(text){let h=0x811c9dc5;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;return h>>>0;}
 const depuisResistance=r=>Math.round(borne((RES_MAX-r)*100/(RES_MAX-RES_MIN),0,100));
 // Résistance réelle des bases, sinon null.
 const resistance=p=>fini(p?.hiddenTraitsV2?.injuryResistance)?p.hiddenTraitsV2.injuryResistance:null;
 // Tirage d'un joueur créé : résistance uniforme 50-76 par empreinte de l'identifiant.
 const tirage=p=>depuisResistance(RES_MIN+empreinte('fragilite|'+String(p?.id??''))%(RES_MAX-RES_MIN+1));
 function valeur(p){
  if(!p)return 50;
  const r=resistance(p);
  if(r!==null)return depuisResistance(r);
  if(Number.isInteger(p.fragilite)&&p.fragilite>=0&&p.fragilite<=100)return p.fragilite;
  return tirage(p);
 }
 const facteur=p=>1+(valeur(p)-50)*PENTE;
 // Tous les joueurs de la carrière : clubs, joueurs libres, marché.
 function* joueurs(s){
  for(const c of Object.values(s?.clubs||{}))for(const p of c?.players||[])yield p;
  for(const p of s?.economy?.freeAgents||[])yield p;
  for(const p of Array.isArray(s?.market)?s.market:[])yield p;
 }
 // Enregistre la fragilité des joueurs créés qui ne l'ont pas encore (création, ancienne sauvegarde).
 function observe(){
  if(typeof S==='undefined'||!S)return 0;
  let n=0;
  for(const p of joueurs(S)){
   if(!p||typeof p!=='object'||resistance(p)!==null)continue;
   if(!(Number.isInteger(p.fragilite)&&p.fragilite>=0&&p.fragilite<=100)){p.fragilite=tirage(p);n++;}
  }
  return n;
 }
 function validate(s){
  for(const p of joueurs(s))if(p&&p.fragilite!==undefined&&!(Number.isInteger(p.fragilite)&&p.fragilite>=0&&p.fragilite<=100))throw Error('Fragilité de joueur invalide.');
  return true;
 }
 function installHooks(){
  globalThis.valeurFragilite=valeur;
  globalThis.facteurFragilite=facteur;
  return true;
 }
 return {project(){return null;},validate,execute(){throw Error('Aucune commande de fragilité.');},installHooks,observe,valeur,facteur,RULES:Object.freeze({RES_MIN,RES_MAX,PENTE})};
}
module.exports={files,commands,factory};
