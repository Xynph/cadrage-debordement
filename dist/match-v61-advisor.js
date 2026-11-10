'use strict';
// V61 : aide a la decision issue exclusivement des statistiques natives du match.
// Aucune simulation, aucun tirage RNG et aucune ecriture en sauvegarde au rendu.
const MATCH_ADVICE_MIN_OBSERVATIONS=10;
function matchV61Advice(view){
 const l=view?.visualSource||view;
 if(!l||!Array.isArray(l.stats)||!Array.isArray(l.score)||!Array.isArray(l.tactics)||!Number.isInteger(l.userSide)||l.userSide<0||l.userSide>1)return null;
 const side=l.userSide,other=1-side,own=l.stats[side]||{},opp=l.stats[other]||{};
 const value=(entry,key)=>Number.isFinite(entry[key])?Math.max(0,entry[key]):0;
 const ratio=key=>{const a=value(own,key),b=value(opp,key);return a+b>0?Math.round(100*a/(a+b)):null};
 // Each play observation increments possession once and records territory at the same time.
 const observations=value(own,'possession')+value(opp,'possession');
 const ready=observations>=MATCH_ADVICE_MIN_OBSERVATIONS;
 const possession=ready?ratio('possession'):null,occupation=ready?ratio('territory'):null;
 const margin=(Number(l.score[side])||0)-(Number(l.score[other])||0);
 const minute=Number.isFinite(l.minute)?l.minute:0;
 const penaltyGap=value(own,'penalties')-value(opp,'penalties');
 let attack=typeof l.tactics[side]==='string'?l.tactics[side]:'equilibre';
 let attackReason=ready?'Les indicateurs ne justifient pas de changement offensif prioritaire.':
  'Pas assez d’observations pour interpréter la possession et l’occupation. Conservez la consigne en place.';
 if(margin<=-7&&minute>=50){attack='large';attackReason='Retard de '+(-margin)+' points apres la 50e minute : tenter davantage de franchissements, avec un risque de faute de main accru.'}
 else if(occupation!==null&&occupation<43&&minute<70){attack='occupation';attackReason='Occupation de '+occupation+' % : rechercher du terrain au pied, au prix de possessions rendues.'}
 else if(possession!==null&&possession<42){attack='conquete';attackReason='Possession de '+possession+' % : chercher des sequences plus courtes et la conservation.'}
 const defenceAvailable=typeof tacticalRules==='function'&&tacticalRules(l)&&Array.isArray(l.defences);
 let defence=defenceAvailable?l.defences[side]:'equilibre',defenceReason='Aucun signal défensif prioritaire. Conservez la consigne en place.';
 if(penaltyGap>=3){defence='prudente';defenceReason=penaltyGap+' penalites de plus que l\'adversaire : limiter les risques en defense.'}
 else if(margin<=-7&&minute>=55){defence='pression';defenceReason='Retard en fin de rencontre : une montee plus agressive peut creer des erreurs, avec un risque accru.'}
 else if(margin>=7&&minute>=65){defence='prudente';defenceReason='Avance de '+margin+' points en fin de rencontre : proteger la profondeur et maitriser la depense physique.'}
 const canAct=!!l.paused&&!l.finished&&!(typeof presentationPending==='function'&&presentationPending(l));
 return {attack,attackReason,defence,defenceReason,canAct,defenceAvailable,margin,minute,possession,occupation,penaltyGap,
  attackChanged:l.tactics[side]!==attack,defenceChanged:defenceAvailable&&l.defences[side]!==defence};
}
function applyMatchV61Advice(kind,key){
 const l=typeof S!=='undefined'&&S?.live,advice=matchV61Advice(l);
 if(!advice||!advice.canAct)return false;
 if(kind==='attack'&&key===advice.attack&&advice.attackChanged&&Object.prototype.hasOwnProperty.call(TACTICS,key)){
  setLiveTactic(key);return true;
 }
 if(kind==='defence'&&advice.defenceAvailable&&key===advice.defence&&advice.defenceChanged&&Object.prototype.hasOwnProperty.call(DEFENCES,key)){
  setLiveDefence(key);return true;
 }
 return false;
}
function matchV61AdviceHtml(view){
 const a=matchV61Advice(view);
 if(!a)return '<section class="card v61-advisor" aria-label="Assistant tactique"><h2>Assistant tactique</h2><p>Analyse indisponible pour cette rencontre.</p></section>';
 const escape=typeof visualEscape==='function'?visualEscape:s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const action=(kind,key,changed,available)=>available&&changed
  ?'<button class="small" '+(!a.canAct?'disabled ':'')+'onclick="applyMatchV61Advice(\''+kind+'\',\''+key+'\')">Appliquer '+(kind==='attack'?'en attaque':'en defense')+'</button>'
  :'<span class="v61-advisor-state">'+(!available?'Non disponible sur cet ancien match':'Consigne deja en place')+'</span>';
 const hasProposal=a.attackChanged||a.defenceChanged;
 const subtitle=!hasProposal?'Aucun changement prioritaire':a.canAct?'Match en pause : propositions applicables':'Mettre en pause pour appliquer une consigne';
 return '<section class="card v61-advisor" aria-label="Assistant tactique V61"><div class="v40-panel-heading"><h2>Conseiller du bord de terrain</h2><small>'+subtitle+'</small></div>'+
 '<p class="v40-data-note">Analyse deterministe du score et des compteurs du moteur. Conseils indicatifs, jamais appliques automatiquement.</p>'+
 '<div class="v61-advisor-grid"><div class="v61-advisor-choice"><h3>Attaque : '+escape(TACTICS[a.attack]?.[0]??TACTICS.equilibre[0])+'</h3><p>'+escape(a.attackReason)+'</p>'+action('attack',a.attack,a.attackChanged,true)+'</div>'+
 '<div class="v61-advisor-choice"><h3>Defense : '+escape(DEFENCES[a.defence]?.[0]??DEFENCES.equilibre[0])+'</h3><p>'+escape(a.defenceReason)+'</p>'+action('defence',a.defence,a.defenceChanged,a.defenceAvailable)+'</div></div>'+
 '<small class="v40-data-note">Score : '+(a.margin>0?'+':'')+a.margin+' · Possession : '+(a.possession===null?'non mesuree':a.possession+' %')+
 ' · Occupation : '+(a.occupation===null?'non mesuree':a.occupation+' %')+'. Les regles de remplacement, le moteur et les sauvegardes restent inchanges.</small></section>';
}
if(typeof module!=='undefined')module.exports={matchV61Advice,applyMatchV61Advice,matchV61AdviceHtml};
