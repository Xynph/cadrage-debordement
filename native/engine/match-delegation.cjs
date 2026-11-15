'use strict';
// Match délégué : l'adjoint gère le banc (demande de Léo, 14 novembre 2026 : « Toulouse perd
// beaucoup en matchs délégués »).
//
// Le moteur (dist/opposition.js) ne fait les remplacements (`manageSubstitutions`), l'observation
// de l'attaque adverse (`opponentDefensiveScout`) et les révisions de plan à la mi-temps et à
// l'heure de jeu (`adaptManager`) que pour l'équipe sans manager (`side !== l.userSide`). En
// direct, c'est voulu : le joueur décide. Mais un match délégué (`delegate`, « simuler sans
// moi ») était joué jusqu'au bout SANS AUCUN remplacement ni ajustement du côté du joueur :
// quinze titulaires 80 minutes, fatigue en fin de match (condition moyenne ~70 % contre ~80 %
// pour l'adversaire, qui fait 6 à 8 changements), et cette fatigue se reportait sur la semaine
// suivante. Le même club géré par l'IA, lui, fait tourner son banc.
//
// Pendant la seule commande `delegate` (le worker appelle `setActive(true)` puis `false`),
// l'adjoint applique au club du joueur exactement les décisions d'un entraîneur IA du même niveau
// (`l.aiLevel`, réglage « niveau adverse ») après chaque minute jouée. La feuille et la consigne de
// départ restent celles du joueur. Rien n'est écrit dans la sauvegarde ; le direct est inchangé.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 let actif=false,installe=false;
 function adjoint(l){
  const side=l.userSide;if(!(side===0||side===1)||l.finished)return;
  // Les fonctions du moteur ignorent le côté du manager : on le masque le temps de leur appel.
  l.userSide=-1;
  try{adaptManager(l,side);aiSubs(l,side);}finally{l.userSide=side;}
 }
 function installHooks(){
  if(installe||typeof advanceRugby!=='function'||typeof aiSubs!=='function'||typeof adaptManager!=='function')return true;
  installe=true;
  const avance=advanceRugby;
  advanceRugby=function(l){
   const result=avance.apply(this,arguments);
   if(actif&&l&&typeof S!=='undefined'&&S&&l===S.live&&l.userSide>=0&&!l.finished)adjoint(l);
   return result;
  };
  Object.assign(advanceRugby,avance);
  return true;
 }
 function setActive(value){if(typeof value!=='boolean')throw Error('Délégation : drapeau invalide.');actif=value;}
 return {project(){return null;},validate(){return true;},execute(){throw Error('Délégation : aucune commande.');},installHooks,setActive,clearTransient(){actif=false;}};
}
module.exports={files,commands,factory};
