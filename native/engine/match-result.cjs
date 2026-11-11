'use strict';
// Serialized into the career VM. Confirming a daily result keeps the live
// evidence until the actual weekly close; historical weekly careers close now.
module.exports=function nativeConfirmMatchResult(){
 if(S.franceCalendar!==undefined){
  S.franceCalendar=nativeFranceCalendar.confirm(S);view='dashboard';
 }else if(S.worldMode?.day!==undefined){
  if(S.worldMode.resultConfirmed)throw Error('Le résultat est déjà confirmé.');
  if(!S.live?.finished)throw Error('Terminez le match avant de valider le résultat.');
  S.worldMode.resultConfirmed=true;view='dashboard';
 }else{
  if(!(S.phase!=='ended'&&(S.live?.finished||!S.live&&!nextMatch())))throw Error('Terminez le match avant de valider la journée.');
  finishRound();
 }
 return !S.live||S.franceCalendar?.resultConfirmed===true||S.worldMode?.resultConfirmed===true;
};
