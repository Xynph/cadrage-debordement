'use strict';
// Runs inside the native VM. Only explicit commands reach these controllers.
module.exports=function nativeGestion(command,p){
 const requireThat=(ok,message)=>{if(!ok)throw Error(message);};
 if(command==='set_lineup'){
  requireThat(!S.live&&S.phase!=='ended','Composition indisponible.');requireThat(Number.isInteger(p.slot)&&p.slot>=0&&p.slot<23,'Poste invalide.');
  const eligible=(player,slot)=>slot<15?slotEligible(player,slot):benchEligible(player,slot-15),all=[...S.lineup,...S.reserves],candidate=p.playerId===null?null:player(p.playerId);
  requireThat(p.playerId===null||candidate&&!candidate.injury&&eligible(candidate,p.slot),'Joueur absent, blessé ou non qualifié.');
  const previous=p.playerId===null?-1:all.indexOf(p.playerId),out=all[p.slot];
  if(previous>=0&&previous!==p.slot){const old=player(out);all[previous]=old&&!old.injury&&eligible(old,previous)?out:null;}
  all[p.slot]=p.playerId;S.lineup=all.slice(0,15);S.reserves=all.slice(15);return;
 }
 if(command==='set_tactics'){
  requireThat(Object.hasOwn(TACTICS,p.attack)&&Object.hasOwn(DEFENCES,p.defense),'Consigne inconnue.');
  if(S.live){requireThat(tacticalRules(S.live)&&S.live.paused&&!S.live.finished&&!presentationPending(S.live),'Mettez le match en pause pour changer les consignes.');setLiveTactic(p.attack);setLiveDefence(p.defense);}
  else{requireThat(S.phase!=='ended','Saison terminée.');S.tactic=p.attack;setDefence(p.defense);}return;
 }
 if(command==='set_player_load'){requireThat(setPhysicalTraining(p.playerId,p.mode),'Charge indisponible : séance appliquée, joueur absent ou match en cours.');return;}
 if(command==='promote_cover'){
  requireThat(p.confirmed===true,'Confirmez la promotion à 2 500 € par semaine et par joueur.');requireThat(!S.live&&S.phase!=='ended','Promotion indisponible pendant le match ou après la saison.');
  repairSheet();const count=[...S.lineup,...S.reserves].filter(id=>!id).length;
  requireThat(count>0,'La feuille de match est déjà complète.');requireThat(club().players.length+count<=100,'Effectif trop important pour promouvoir ces joueurs.');
  promoteCover();requireThat(sheetErrors().length===0,'La promotion ne permet pas de compléter une feuille qualifiée.');
  return {coverage:{count,weeklySalary:2500,totalWeeklySalary:count*2500,message:`${count} espoir(s) promu(s) : ${count*2500} € de salaire hebdomadaire supplémentaire. Feuille à 23 complète.`}};
 }
 if(command==='recruit'||command==='extend_contract'){
  requireThat(p.confirmed===true,'Confirmez le salaire, la durée et la prime avant cette offre.');requireThat(typeof p.playerId==='string'&&Number.isInteger(p.salary)&&p.salary>=1000&&p.salary<=100000&&[1,2,3].includes(p.years),'Offre invalide.');
  const kind=command==='recruit'?'recruit':'renew',target=talkPlayer(p.playerId,kind);requireThat(target,'Joueur indisponible ou offre périmée.');
  requireThat(club().cash>=contractFee(target,kind),'Trésorerie insuffisante pour la prime.');requireThat(kind!=='recruit'||club().players.length<42,'Effectif complet.');
  requireThat(negotiateContract(p.playerId,kind,p.salary,p.years),'Offre refusée : durée, joueur ou négociation indisponible.');
  const key=talkKey(p.playerId,kind),talk=S.economy.talks[key];
  if(talk.status==='ready')requireThat(confirmContract(key),'Signature devenue indisponible.');
  return {negotiation:{playerId:p.playerId,status:talk.status,message:talk.status==='signed'?'Contrat signé.':talk.message,fee:talk.fee,salary:talk.acceptedSalary,years:talk.years}};
 }
 if(command==='next_season'){requireThat(p.confirmed===true&&S.phase==='ended'&&!S.live,'Confirmez le passage à la saison suivante après la fin des compétitions.');advanceSeason();return;}
 if(command==='substitute'){
  const l=S.live;requireThat(l&&l.paused&&!l.finished&&!presentationPending(l),'Remplacement indisponible : mettez le match en pause.');
  const on=l.sheets[l.userSide].on,explicitSlot=Object.hasOwn(p,'slot');
  requireThat(explicitSlot||typeof p.outId==='string'&&p.outId.length>0,'Précisez le poste du remplacement.');
  const slot=explicitSlot?p.slot:on.indexOf(p.outId);
  requireThat(Number.isInteger(slot)&&slot>=0&&slot<15,'Poste de remplacement invalide.');
  requireThat(!Object.hasOwn(p,'outId')||on[slot]===p.outId,'Le joueur de ce poste a changé.');
  requireThat(eligibleChanges(l,l.userSide,slot).some(x=>x.id===p.inId),'Changement non autorisé pour ces joueurs.');
  requireThat(makeSub(l,l.userSide,slot,p.inId),'Remplacement refusé.');syncMatchPresentation(l);return;
 }
 throw Error('Commande de gestion inconnue.');
};
