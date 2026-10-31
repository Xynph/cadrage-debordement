'use strict';

// V28 — préparation originale du rugby à XV. Coefficients fictifs à calibrer, non issus de FM27.
const COLLECTIVE_FOCI={
 aucune:['Préserver les organismes','Aucune charge additionnelle ni bonus temporaire.'],
 conquete:['Conquête','Préparer la mêlée et la touche : rétention légèrement accrue.'],
 defence:['Organisation défensive','Renforcer la couverture et les lectures défensives.'],
 pied:['Jeu au pied','Améliorer le gain territorial des coups de pied en jeu courant.']
};
const COLLECTIVE_EFFECTS={conquete:.04,defence:.025,pied:3};
function collectiveFocusForClub(ci){
 if(S.collectivePrepVersion!==1)return 'aucune';
 if(ci===S.club)return COLLECTIVE_FOCI[S.collectiveFocus]?S.collectiveFocus:'aucune';
 const style=managerStyle(ci);
 return style==='conquete'?'conquete':style==='occupation'?'pied':'defence';
}
function collectiveSpecialist(p,focus){return focus==='conquete'?p.fam<=3:focus==='pied'?p.fam>=4:focus==='defence'}
function applyCollectiveTrainingCost(p,ci){
 const focus=collectiveFocusForClub(ci);
 if(p.injury||focus==='aucune'||!collectiveSpecialist(p,focus))return 0;
 const state=ensurePhysicalLoad(p),before=state.fatigue;
 state.fatigue=clamp(state.fatigue+4,0,100);
 return state.fatigue-before;
}
function collectiveStrength(l,side,focus){
 const c=S.clubs[l.pair[side]],ids=l.sheets[side].initial;
 const relevant=ids.map(id=>c.players.find(p=>p.id===id)).filter(p=>p&&collectiveSpecialist(p,focus));
 const fatigue=mean(relevant.map(p=>physicalLoadValue(p)));
 return Math.round(clamp(1-fatigue/160,.55,1)*100)/100;
}
function initializeCollectivePreparation(l){
 if(S.collectivePrepVersion!==1)return;
 const focus=l.pair.map(ci=>collectiveFocusForClub(ci));
 l.collectivePrepVersion=1;
 l.collectivePreparation={v:1,season:S.season,round:S.round,focus,power:focus.map((f,side)=>collectiveStrength(l,side,f))};
}
function collectivePreparationBonus(l,side,focus){
 const cp=l?.collectivePreparation;
 if(l?.collectivePrepVersion!==1||cp?.v!==1||![0,1].includes(side)||cp.focus[side]!==focus)return 0;
 return (COLLECTIVE_EFFECTS[focus]||0)*cp.power[side];
}
function setCollectiveFocus(focus){
 if(!S||S.live||S.trained||S.phase==='ended'||S.collectivePrepVersion!==1||!Object.prototype.hasOwnProperty.call(COLLECTIVE_FOCI,focus))return false;
 S.collectiveFocus=focus;save();render();return true;
}
function collectiveAdvice(){
 const d=matchDossier();if(!d)return {focus:'aucune',reason:'Aucune rencontre à préparer.'};
 const load=mean(starters().map(p=>physicalLoadValue(p)));
 if(load>=65)return {focus:'aucune',reason:'Charge cumulée élevée dans le XV : préserver les organismes peut être prioritaire.'};
 const focus=d.advice.attack==='conquete'?'conquete':d.advice.attack==='occupation'?'pied':'defence';
 const reason=focus==='conquete'?'Le rapport de forces favorise le travail de la conquête.':focus==='pied'?'Le jeu d’occupation et les qualités au pied ressortent du dossier adverse.':'Renforcer la couverture défensive offre un compromis général.';
 return {focus,reason};
}
/* UI-05 : le panneau de préparation est déjà chargé dans l'écran Tactiques jouable.
   Seul le rendu est changé ; coefficients et commandes natives V28 inchangés. */
const UI05_COLLECTIVE_STYLE=String.raw`
<style>
.ui05-collective{--u5-line:var(--ui01-border,#36475c);--u5-accent:var(--ui01-accent,#9380ec);--u5-soft:var(--ui01-soft,#18273a);--u5-ink:var(--ui01-text,#e8effa);--u5-muted:var(--ui01-meta,#b0bccc);color:var(--u5-ink);min-width:0}
.ui05-collective *{box-sizing:border-box}
.ui05-collective .ui05-hero{display:flex;justify-content:space-between;align-items:flex-start;gap:14px;margin:2px 0 16px}
.ui05-collective .ui05-hero h2{margin:0;font-size:clamp(18px,2.2vw,24px);font-weight:850;letter-spacing:-.02em}
.ui05-collective .ui05-kicker{font-size:10px!important;color:var(--u5-accent)!important;letter-spacing:.12em;font-weight:900;margin:0 0 6px!important}
.ui05-collective .ui05-hero .tag{flex-shrink:0}
.ui05-collective .ui05-summary{display:grid;grid-template-columns:1.3fr 1fr 1fr;gap:1px;background:var(--u5-line);border:1px solid var(--u5-line);border-radius:4px;overflow:hidden;margin-bottom:15px}
.ui05-collective .ui05-metric{padding:12px 14px;background:var(--u5-soft);min-width:0;display:grid;gap:4px}
.ui05-collective .ui05-metric span{font-size:10px;color:var(--u5-muted);font-weight:750}
.ui05-collective .ui05-metric strong{font-size:15px;font-weight:850}
.ui05-collective .ui05-lead{font-size:12px;line-height:1.5;color:var(--u5-muted);margin:0 0 13px}
.ui05-collective .ui05-choices{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:11px}
.ui05-collective .ui05-option{display:grid;align-content:start;text-align:left;gap:7px;background:var(--u5-soft);color:var(--u5-ink);border:1px solid var(--u5-line);border-radius:4px;padding:14px;min-height:155px}
.ui05-collective .ui05-option[aria-pressed="true"]{border-color:var(--u5-accent);box-shadow:inset 0 3px var(--u5-accent)}
.ui05-collective .ui05-option strong{font-size:14px}
.ui05-collective .ui05-option small{font-size:11px;line-height:1.45;color:var(--u5-muted)}
.ui05-collective .ui05-pill{font-size:10px;font-weight:850;color:var(--u5-accent)}
.ui05-collective .ui05-option-detail{display:flex;flex-wrap:wrap;gap:7px;margin-top:auto}
.ui05-collective .ui05-option-detail span{font-size:10px;background:color-mix(in srgb,var(--u5-accent) 12%,transparent);border:1px solid var(--u5-line);border-radius:3px;padding:4px 6px}
.ui05-collective .ui05-notes{margin-top:14px;padding:13px;background:var(--u5-soft);border-left:3px solid var(--u5-accent)}
.ui05-collective .ui05-notes p{margin:0 0 8px;font-size:11px;line-height:1.5;color:var(--u5-muted)}
.ui05-collective .ui05-notes p:last-child{margin-bottom:0}
.ui05-collective button:focus-visible{outline:3px solid var(--u5-accent);outline-offset:3px}
:root[data-cd-theme="tribune"] .ui05-collective{--u5-line:#ccd6df;--u5-accent:#6044b0;--u5-soft:#edf2f7;--u5-ink:#172a39;--u5-muted:#4c6474}
@media(max-width:830px){.ui05-collective .ui05-summary{grid-template-columns:1fr 1fr}.ui05-collective .ui05-metric:first-child{grid-column:1/-1}}
@media(max-width:580px){.ui05-collective .ui05-choices{grid-template-columns:1fr}.ui05-collective .ui05-option{min-height:0}.ui05-collective .ui05-hero{flex-wrap:wrap}}
@media(prefers-reduced-motion:reduce){.ui05-collective *{animation:none!important;transition:none!important}}
</style>
`;
function collectivePreparationCard(){
 if(!S||S.phase==='ended')return '';
 const advice=collectiveAdvice();
 const selected=Object.prototype.hasOwnProperty.call(COLLECTIVE_FOCI,S.collectiveFocus)?S.collectiveFocus:'aucune';
 const locked=!!(S.live||S.trained||S.collectivePrepVersion!==1);
 const fifteen=starters(),fatigue=mean(fifteen.map(p=>physicalLoadValue(p)));
 const chosen=COLLECTIVE_FOCI[selected][0],recommended=COLLECTIVE_FOCI[advice.focus][0];
 const stats=Object.entries(COLLECTIVE_FOCI).map(([key,[name,description]])=>{
  const people=key==='aucune'?[]:fifteen.filter(p=>!p.injury&&collectiveSpecialist(p,key));
  const loads=people.map(p=>physicalLoadValue(p));
  const average=loads.length?Math.round(mean(loads)):null;
  const maximum=key==='conquete'?'+'+Math.round(COLLECTIVE_EFFECTS.conquete*100)+' points de conservation':
   key==='defence'?'−'+(COLLECTIVE_EFFECTS.defence*100).toLocaleString('fr-FR',{maximumFractionDigits:1})+' points d’avancée adverse':
   key==='pied'?'+'+COLLECTIVE_EFFECTS.pied+' m au dégagement':'Aucun bonus spécifique';
  const badge=key===selected?'PRÉPARATION CHOISIE':key===advice.focus?'CONSEIL DU STAFF':'ALTERNATIVE';
  return '<button type="button" class="option ui05-option'+(key===selected?' selected':'')+'" aria-pressed="'+(key===selected)+
   '" onclick="setCollectiveFocus(\''+key+'\')"'+(locked?' disabled':'')+'>'+
   '<span class="ui05-pill">'+badge+'</span><strong>'+name+'</strong>'+
   '<small>'+description+'</small><span class="ui05-option-detail">'+
   '<span>'+people.length+' joueur(s) concerné(s)'+(key==='aucune'?' · 0 charge':' · +4 charge / séance')+'</span>'+
   '<span>Charge actuelle '+(average===null?'—':average+'/100')+'</span>'+
   '<span>'+maximum+' max.</span></span></button>';
 }).join('');
 return UI05_COLLECTIVE_STYLE+
  '<section class="card collective-preparation ui05-collective" aria-label="Préparation collective rugby">'+
  '<div class="ui05-hero"><div><p class="ui05-kicker">TACTIQUES / PRÉPARATION</p>'+
  '<h2>04 / Préparation collective rugby</h2></div><span class="tag">PROCHAIN MATCH</span></div>'+
  '<div class="ui05-summary" aria-label="Bilan de la préparation">'+
  '<div class="ui05-metric"><span>PRÉPARATION RETENUE</span><strong>'+chosen+'</strong></div>'+
  '<div class="ui05-metric"><span>CONSEIL DU STAFF</span><strong>'+recommended+'</strong></div>'+
  '<div class="ui05-metric"><span>CHARGE MOYENNE DU XV ACTUEL</span><strong>'+
  (Number.isFinite(fatigue)?Math.round(fatigue)+'/100':'—')+'</strong></div></div>'+
  '<p class="ui05-lead">Choisissez le travail prioritaire du prochain match. Les effectifs et charges ci-dessous sont ceux du XV actuellement retenu, avant la prochaine séance ; ils peuvent changer.</p>'+
  '<div class="ui05-choices" role="group" aria-label="Choix de préparation collective">'+stats+'</div>'+
  '<div class="ui05-notes"><p><strong>Conseil du staff :</strong> '+advice.reason+
  ' Vous restez décisionnaire.</p>'+
  '<p><strong>Effets natifs V28 :</strong> une séance spécifique par échéance, figée au coup d’envoi ; +4 points de charge cumulée pour chaque joueur concerné. Bonus fictifs maximaux : conquête +4 points de probabilité de conservation ; défense −2,5 points de probabilité d’avancée adverse ; pied jusqu’à +3 mètres au dégagement en jeu. Les effets décroissent avec la fatigue et ne garantissent aucun résultat.</p>'+
  (locked?'<p role="status">Choix verrouillé pendant le match ou après l’entraînement de la semaine.</p>':'')+
  '</div></section>';
}
function collectiveMatchSummary(r,side){
 const cp=r?.collectivePreparation;if(!cp||cp.v!==1)return '';
 const focus=cp.focus[side],coefficient=COLLECTIVE_EFFECTS[focus]||0;
 const effect=focus==='aucune'?'Aucun bonus spécifique.':focus==='pied'?'Gain fictif sur coup de pied en jeu : +'+(coefficient*cp.power[side]).toFixed(1)+' m.':'Ajustement fictif du moteur : '+(coefficient*cp.power[side]*100).toFixed(2)+' points de probabilité.';
 return '<p class="help"><strong>Préparation collective au coup d’envoi :</strong> '+COLLECTIVE_FOCI[focus][0]+' · efficacité '+(cp.power[side]*100).toFixed(0)+' %. '+effect+' Il s’agit d’un effet de modèle, pas d’une explication certaine du score.</p>';
}

// Lecture des faits et conseils de jeu fictifs ; aucun bonus au moteur.
const DOSSIER_DOMAINS=[
 {key:'scrum',label:'Mêlée',slot:0,skills:['scrum'],families:[0,1,2]},
 {key:'lineout',label:'Touche',slot:1,skills:['lineout'],families:[1,2]},
 {key:'power',label:'Puissance des avants',slot:5,skills:['power'],families:[0,1,2,3]},
 {key:'backs',label:'Passe et vitesse',slot:9,skills:['pass','speed'],families:[4,5,6,7,8]},
 {key:'kick',label:'Occupation au pied',slot:9,skills:['kick'],families:[4,5,8]},
 {key:'discipline',label:'Discipline',slot:6,skills:['discipline'],families:[0,1,2,3,4,5,6,7,8]}
];
function dossierMetrics(c,ids){
 const players=ids.map(id=>c.players.find(p=>p.id===id)).filter(Boolean);
 const out=Object.fromEntries(DOSSIER_DOMAINS.map(d=>[d.key,mean(players.filter(p=>d.families.includes(p.fam)).map(p=>mean(d.skills.map(k=>skill(p,k,true)))))]));
 return {...out,fitness:mean(players.map(p=>p.condition)),tackle:mean(players.map(p=>skill(p,'tackle',true))),speed:mean(players.map(p=>skill(p,'speed',true)))};
}
function dossierRecent(ci){return S.history.filter(r=>r.pair.includes(ci)).slice(-5).reverse().map(r=>{const side=r.pair.indexOf(ci);return {round:r.round,phase:r.phase,pair:r.pair,score:r.score,side,opponent:r.pair[1-side],result:r.score[side]>r.score[1-side]?'V':r.score[side]===r.score[1-side]?'N':'D',stats:r.stats?.[side]||null}})}
function dossierAdvice(own,opponent){
 const packEdge=own.power-opponent.power,backEdge=own.backs-opponent.backs;
 let attack='equilibre',attackReason='Aucun avantage net ne ressort : conserver plusieurs solutions limite la dépendance à un seul secteur.';
 if(packEdge>=backEdge+2&&own.power>=own.backs-4){attack='conquete';attackReason=`Écart de puissance des avants ${signedDossier(packEdge)}, contre ${signedDossier(backEdge)} en passe/vitesse. Le près exploite davantage la puissance et réduit les fautes de main, avec des gains plus courts.`}
 else if(backEdge>=packEdge&&own.backs>=70){attack='large';attackReason=`Passe et vitesse estimées à ${Math.round(own.backs)}/100, contre ${Math.round(opponent.backs)} en face. Le large recherche des gains plus longs ; il augmente fatigue et fautes de main, surtout sous la pluie.`}
 else if(own.kick>=70&&own.kick>=opponent.kick){attack='occupation';attackReason=`Votre occupation au pied est estimée à ${Math.round(own.kick)}/100, contre ${Math.round(opponent.kick)} en face. Chercher du terrain rend souvent le ballon ; le vent peut dégrader ce choix.`}
 let defence='equilibre',defenceReason='Garder un compromis entre couverture, pression et fraîcheur ; aucun signal ne justifie une option plus extrême.';
 if(opponent.backs>=opponent.power+4||own.fitness<78){defence='prudente';defenceReason=`Condition du XV : ${Math.round(own.fitness)}%. Passe/vitesse adverse : ${Math.round(opponent.backs)}, puissance adverse : ${Math.round(opponent.power)}. La glissée protège les grands espaces et économise l’équipe, en concédant plus de petites avancées.`}
 else if(own.tackle>=75&&own.speed>=75&&own.fitness>=84&&own.discipline>=72){defence='pression';defenceReason=`Plaquage ${Math.round(own.tackle)}, vitesse ${Math.round(own.speed)}, discipline ${Math.round(own.discipline)} et condition ${Math.round(own.fitness)}%. La montée peut freiner l’adversaire, avec plus de fatigue, de pénalités et de grands gains si elle est battue.`}
 return {attack,defence,attackReason,defenceReason};
}
function signedDossier(n){return (n>=0?'+':'')+Math.round(n)}
function matchDossier(){
 const pair=nextMatch();if(!pair)return null;
 const opponent=S.clubs[pair.find(ci=>ci!==S.club)],projection=managerSheet(opponent,club(),'Sec',S.difficulty||'classique'),own=dossierMetrics(club(),S.lineup),other=dossierMetrics(opponent,projection.lineup),recent=dossierRecent(opponent.id);
 const candidates=projection.lineup.map(id=>opponent.players.find(p=>p.id===id)).filter(Boolean);
 const kicker=chooseScorer(opponent,projection.lineup),leader=[...candidates].sort((a,b)=>roleNote(b)-roleNote(a))[0],runner=[...candidates].filter(p=>p.fam>=4).sort((a,b)=>skill(b,'speed',true)-skill(a,'speed',true))[0];
 const threats=[...new Map([[leader,'Référence au poste'],[kicker,'Buteur pressenti'],[runner,'Vitesse à surveiller']].filter(([p])=>p).map(([p,role])=>[p.id,{id:p.id,name:p.name,pos:p.pos,note:roleNote(p),fitness:p.condition,role}])).values()];
 return {pair,opponent,projection,own,other,recent,threats,advice:dossierAdvice(own,other)};
}
function adoptDossierPlan(){if(S.live)return;const d=matchDossier();if(!d)return;S.tactic=d.advice.attack;S.defence=d.advice.defence;save();render();toast('Plan principal adopté. Les consignes personnalisées par zone restent prioritaires.')}
function prepareSquad(tab='sheet'){if(S.live||!['sheet','depth','table'].includes(tab))return;squadTab=tab;nav('team')}
function compareDossierPosition(slot){if(S.live||!Number.isInteger(slot)||slot<0||slot>14)return;squadTab='table';squadFamily=String(slot);compareIds=depthAt(slot).filter(p=>!p.injury).slice(0,2).map(p=>p.id);nav('team')}
function dossierObservedHTML(recent){
 const games=recent.filter(r=>r.stats),sum=key=>games.reduce((n,r)=>n+r.stats[key],0),scrums=sum('scrums'),lineouts=sum('lineouts');
 return `<p class="help">${games.length} rencontre(s) avec statistiques archivées sur ${recent.length} résultat(s). ${scrums?`Mêlées conservées : ${sum('scrumsWon')} / ${scrums}.`:'Aucune mêlée documentée.'} ${lineouts?`Touches conservées : ${sum('lineoutsWon')} / ${lineouts}.`:'Aucune touche documentée.'} ${games.length?`Pénalités concédées : ${sum('penalties')}.`:''}</p>`;
}
function oppositionDossierHTML(){
 const d=matchDossier();if(!d)return '';
 const adopted=S.tactic===d.advice.attack&&(S.defence||'equilibre')===d.advice.defence;
 return `<section class="card opponent-dossier" aria-label="Rapport sur le prochain adversaire"><div class="cardtitle"><div><span class="eyebrow">DOSSIER ADVERSAIRE</span><h2>${visualEscape(d.opponent.name)}</h2></div>${badge(d.opponent.id)}</div><p>Tendance du staff : <strong>${TACTICS[managerStyle(d.opponent.id)][0]}</strong> · Moral ${Math.round(clubMorale(d.opponent.id))}/100.</p><h3>Les faits récents</h3>${d.recent.length?`<div class="dossier-results">${d.recent.map(r=>`<div><span class="form ${r.result}">${r.result}</span><span>${r.phase==='league'?'J'+(r.round+1):({barrage:'Barrage',semi:'Demi-finale',final:'Finale'})[r.phase]} · ${visualEscape(S.clubs[r.opponent].abbr)}</span><strong>${r.score[r.side]} – ${r.score[1-r.side]}</strong></div>`).join('')}</div>`:'<p>Pas encore de résultat cette saison. Le rapport repose sur les qualités de l’effectif.</p>'}${dossierObservedHTML(d.recent)}<h3>Le rapport de forces estimé</h3><p class="help">Votre XV sélectionné face à une projection adverse sur terrain sec, avant le coup d’envoi. Les notes tiennent compte de la condition actuelle. La météo, l’entraînement et les choix adverses peuvent modifier ce tableau. Les cases vides de votre XV ne sont pas remplacées dans cette estimation.</p><div class="tablewrap"><table class="dossier-table"><thead><tr><th>SECTEUR</th><th>VOUS</th><th>ADVERSAIRE</th><th>PRÉPARER</th></tr></thead><tbody>${DOSSIER_DOMAINS.map(k=>`<tr><td>${k.label}</td><td>${Math.round(d.own[k.key])}</td><td>${Math.round(d.other[k.key])}</td><td><button class="small" aria-label="Comparer vos options : ${k.label}" onclick="compareDossierPosition(${k.slot})">Comparer →</button></td></tr>`).join('')}</tbody></table></div><h3>Les joueurs à surveiller</h3><div class="dossier-threats">${d.threats.map(p=>`<article><small>${p.role}</small><strong>${visualEscape(p.name)}</strong><span>${p.pos} · ${p.note}/100 · condition ${Math.round(p.fitness)}%</span></article>`).join('')}</div><p class="help">Joueurs pressentis dans une projection, pas une feuille adverse confirmée. Les informations de l’effectif sont connues dans cette version.</p></section><section class="card dossier-advice" aria-label="Préparer votre plan de match"><div class="cardtitle"><h2>Le conseil du staff</h2><span class="tag">À VOTRE CHOIX</span></div><h3>${TACTICS[d.advice.attack][0]}</h3><p>${d.advice.attackReason}</p><h3>${DEFENCES[d.advice.defence][0]}</h3><p>${d.advice.defenceReason}</p><button class="primary" onclick="adoptDossierPlan()">${adopted?'Plan principal déjà adopté':'Adopter ce plan principal'}</button><p class="help">Ce bouton règle votre attaque et votre défense principales. Les zones personnalisées restent prioritaires. Aucun changement automatique des 23, aucun bonus de résultat. À réévaluer selon la météo au coup d’envoi.</p><div class="matchactions"><button onclick="prepareSquad('sheet')">Composer les 23 →</button><button onclick="prepareSquad('depth')">Couverture des postes →</button><button onclick="nav('plans')">Vérifier les consignes par zone →</button></div>${sheetErrors().length?'<p class="notice">La feuille est incomplète : complétez les postes pour fiabiliser les conseils.</p>':''}</section>`;
}
function emptyPlanUsage(){return {v:1,minutes:0,zones:Object.fromEntries(Object.keys(FIELD_ZONES).map(k=>[k,0])),attack:Object.fromEntries(Object.keys(TACTICS).map(k=>[k,{phases:0,carries:0,advances:0,metres:0,handErrors:0,kicks:0}])),defence:Object.fromEntries(Object.keys(DEFENCES).map(k=>[k,{phases:0,oppCarries:0,oppAdvances:0,oppMetres:0,penalties:0}]))}}
function initializePreparation(l,preview=null){
 if(l.userSide<0)return;const d=preview||matchDossier();if(!d||d.pair.join()!==l.pair.join())return;
 l.preparation={v:1,season:S.season,round:S.round,opponent:l.pair[1-l.userSide],attack:l.tactics[l.userSide],defence:l.defences[l.userSide],recommendedAttack:d.advice.attack,recommendedDefence:d.advice.defence,observed:d.recent.length,playbook:JSON.parse(JSON.stringify(l.playbooks[l.userSide]))};l.planUsage=emptyPlanUsage();
}
function beginPlanObservation(l){if(!l.planUsage||!tacticalRules(l)||l.userSide<0)return null;const side=l.userSide;return {side,attack:effectiveAttack(l,side),defence:effectiveDefence(l,side),zone:fieldZone(side,l.territory),possession:l.possession,own:{...l.tacticalStats[side]},other:{...l.tacticalStats[1-side]},penalties:l.stats[side].penalties}}
function finishPlanObservation(l,before){
 if(!before)return;const u=l.planUsage,side=before.side;u.minutes++;u.zones[before.zone]++;
 if(before.possession===side){const a=u.attack[before.attack];a.phases++;for(const key of ['carries','advances','metres','handErrors','kicks'])a[key]+=l.tacticalStats[side][key]-before.own[key]}
 else{const d=u.defence[before.defence],other=l.tacticalStats[1-side];d.phases++;d.oppCarries+=other.carries-before.other.carries;d.oppAdvances+=other.advances-before.other.advances;d.oppMetres+=other.metres-before.other.metres;d.penalties+=l.stats[side].penalties-before.penalties}
}
function debriefNotes(r,side){
 const own=r.tacticalStats?.[side],opp=r.tacticalStats?.[1-side];if(!own||!opp)return ['Les compteurs détaillés ne sont pas disponibles pour cette ancienne rencontre.'];
 const notes=[`${own.advances} progressions sur ${own.carries}, ${Math.round(own.metres)} mètres portés, ${own.kicks} coups de pied en jeu et ${own.handErrors} fautes de main.`, `L’adversaire a progressé ${opp.advances} fois sur ${opp.carries} pour ${Math.round(opp.metres)} mètres. Vous avez concédé ${r.stats[side].penalties} pénalité(s).`];
 if(own.carries<5)notes.push('Peu de portées observées : échantillon trop faible pour juger le rendement offensif.');
 else if(own.advances/own.carries<.4)notes.push('Moins de 40% des portées ont avancé. Comparez les qualités alignées et les plans utilisés avant de reconduire ce projet.');
 if(r.weather==='Pluie'&&own.handErrors>=3)notes.push('Les fautes de main sous la pluie invitent à reconsidérer la prise de risque au large.');
 if(r.planUsage?.defence.pression.phases>0&&r.stats[side].penalties>=4)notes.push('Vous avez utilisé la montée agressive et concédé au moins quatre pénalités au total. Surveillez ce compromis ; ces chiffres ne prouvent pas que la montée a causé chaque faute.');
 return notes;
}
function matchDebrief(r){
 if(!r)return '';const side=r.pair.indexOf(S.club);if(side<0)return '';const p=r.preparation,u=r.planUsage;
 return `<section class="card match-debrief" aria-label="Bilan de votre plan de match"><div class="cardtitle"><h2>Vos choix, les faits du match</h2><span class="tag">BILAN</span></div>${collectiveMatchSummary(r,side)}${p?`<p><strong>Au coup d’envoi :</strong> ${TACTICS[p.attack][0]} · ${DEFENCES[p.defence][0]}. Conseil de préparation du staff : ${TACTICS[p.recommendedAttack][0]} · ${DEFENCES[p.recommendedDefence][0]}.</p><p class="help">${p.observed} résultat(s) adverse(s) disponible(s) lors de la préparation. Ce bilan garde les choix initiaux, même si vos préférences ont changé depuis.</p>`:'<p class="help">Ancienne rencontre : le plan initial n’a pas été enregistré.</p>'}${debriefNotes(r,side).map(n=>`<p>${n}</p>`).join('')}${u?`<h3>Les attaques réellement utilisées</h3><div class="tablewrap"><table><thead><tr><th>PLAN</th><th>PHASES</th><th>PROGRESSIONS</th><th>MÈTRES</th><th>ERREURS</th><th>PIED EN JEU</th></tr></thead><tbody>${Object.entries(u.attack).filter(([,a])=>a.phases).map(([k,a])=>`<tr><td>${TACTICS[k][0]}</td><td>${a.phases}</td><td>${a.advances} / ${a.carries}</td><td>${Math.round(a.metres)}</td><td>${a.handErrors}</td><td>${a.kicks}</td></tr>`).join('')||'<tr><td colspan="6">Aucune phase commencée en possession.</td></tr>'}</tbody></table></div><h3>Les organisations sans ballon</h3><div class="tablewrap"><table><thead><tr><th>DÉFENSE</th><th>PHASES</th><th>PROGRESSIONS ADVERSES</th><th>MÈTRES CONCÉDÉS</th><th>PÉNALITÉS</th></tr></thead><tbody>${Object.entries(u.defence).filter(([,d])=>d.phases).map(([k,d])=>`<tr><td>${DEFENCES[k][0]}</td><td>${d.phases}</td><td>${d.oppAdvances} / ${d.oppCarries}</td><td>${Math.round(d.oppMetres)}</td><td>${d.penalties}</td></tr>`).join('')||'<tr><td colspan="5">Aucune phase commencée sans ballon.</td></tr>'}</tbody></table></div><p class="help">${Object.entries(u.zones).map(([k,n])=>`${FIELD_ZONES[k]} : ${n}`).join(' · ')}.</p><p class="help">Attribution au plan effectif et à la zone au début de chaque minute simulée, y compris les consignes locales et changements en pause. Une phase peut contenir un changement de possession. Ces observations ne permettent pas d’isoler une causalité ni de comparer équitablement des plans utilisés dans des situations différentes.</p>`:'<p class="help">Le suivi des plans par phase débute avec les nouveaux matchs de la version 15.</p>'}</section>`;
}
