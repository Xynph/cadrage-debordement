'use strict';
// Fictional simulation policies. These coefficients are not rugby law or real-life odds.
const DEFENCES={equilibre:['Équilibrée','Un compromis entre pression, couverture et dépense physique.'],pression:['Montée agressive','Freine les attaques et provoque des erreurs, mais fatigue davantage et expose aux grands gains si la ligne est battue. Plus de risque de pénalité.'],prudente:['Glissée prudente','Cède plus facilement les premiers mètres, mais réduit les grands gains et protège la profondeur. Dépense physique et risque de pénalité réduits.']};
const ATTACK_EFFECTS={equilibre:{gain:[12,25],error:0,load:.40,finish:0},conquete:{gain:[8,18],error:-.045,load:.46,finish:-.015},large:{gain:[14,29],error:.065,load:.53,finish:.025},occupation:{gain:[10,21],error:0,load:.34,finish:0}};
const TACTICAL_STAT_KEYS=['carries','advances','metres','handErrors','kicks','recoveries','longGains'];
function tacticalRules(l){return l.tacticalVersion===1&&l.restartVersion===1&&l.balanceVersion===2}
function emptyTacticalStats(){return Object.fromEntries(TACTICAL_STAT_KEYS.map(k=>[k,0]))}
function chooseDefence(l,side){
 const avg=mean(activePlayers(l,side).map(p=>p.condition));
 if(difficultyLevel(l)==='expert'&&matchMinute(l)>=60){const margin=l.score[side]-l.score[1-side];if(margin>=7)return 'prudente';if(margin<=-7&&avg>65)return 'pression'}
 if(avg<68)return 'prudente';
 if(difficultyLevel(l)!=='decouverte'&&unit(l,side,'speed')>76&&unit(l,side,'tackle')>74&&avg>82)return 'pression';return 'equilibre';
}
function initializeTacticalPlans(l){l.tacticalVersion=1;l.defences=['equilibre','equilibre'];l.tacticalStats=[emptyTacticalStats(),emptyTacticalStats()];for(let side=0;side<2;side++)l.defences[side]=side===l.userSide?(S.defence||'equilibre'):chooseDefence(l,side)}
function defensivePlan(l,side){return tacticalRules(l)?effectiveDefence(l,side):'equilibre'}
function tacticalEdge(l,side){
 const opp=1-side,a=effectiveAttack(l,side),d=defensivePlan(l,opp),backs=p=>p.fam>=4,forwards=p=>p.fam<=3;
 const attack=a==='large'?unit(l,side,'pass',backs)*.5+unit(l,side,'speed',backs)*.4+unit(l,side,'power')*.1:a==='conquete'?unit(l,side,'power',forwards)*.7+unit(l,side,'pass')*.15+unit(l,side,'speed')*.15:unit(l,side,'pass')*.4+unit(l,side,'speed')*.35+unit(l,side,'power')*.25;
 const defence=d==='pression'?unit(l,opp,'tackle')*.6+unit(l,opp,'speed')*.25+unit(l,opp,'mental')*.15:d==='prudente'?unit(l,opp,'tackle')*.6+unit(l,opp,'mental')*.3+unit(l,opp,'speed')*.1:unit(l,opp,'tackle')*.72+unit(l,opp,'mental')*.28;
 const pressure=d==='pression'?-.045:d==='prudente'?.025:0;
 return (attack-defence)*.004+pressure+(l.weather==='Pluie'&&a==='large'?-.075:0)+(l.weather==='Vent'&&a==='occupation'?-.025:0);
}
function tacticalPenaltyAdjustment(l,defender){return !tacticalRules(l)?0:defensivePlan(l,defender)==='pression'?.045:defensivePlan(l,defender)==='prudente'?-.02:0}
function handFaultProbability(l,side){if(!tacticalRules(l))return .12;const a=effectiveAttack(l,side),d=defensivePlan(l,1-side);return clamp(.12+ATTACK_EFFECTS[a].error+(l.weather==='Pluie'&&a==='large'?.04:0)+(d==='pression'?.02:d==='prudente'?-.01:0)+clamp((70-unit(l,side,'pass'))*.0015,-.045,.045),.04,.28)}
function failedCarryError(l,side){const base=l.weather==='Pluie'?.55:.3;return tacticalRules(l)?clamp(base+ATTACK_EFFECTS[effectiveAttack(l,side)].error,.1,.8):base}
function carryGain(l,side){if(!tacticalRules(l))return rand(12,25);const range=ATTACK_EFFECTS[effectiveAttack(l,side)].gain,d=defensivePlan(l,1-side),shift=d==='pression'?4:d==='prudente'?-4:0;return rand(Math.max(3,range[0]+shift),range[1]+shift)}
function tacticalFinishAdjustment(l,side){return !tacticalRules(l)?0:ATTACK_EFFECTS[effectiveAttack(l,side)].finish+(defensivePlan(l,1-side)==='pression'?.04:defensivePlan(l,1-side)==='prudente'?-.055:0)}
function openKickProbability(l,side){if(!tacticalRules(l))return l.tactics[side]==='occupation'?.5:0;const distance=Math.abs(attackingGoal(side)-l.territory),style=effectiveAttack(l,side);if(style==='occupation')return distance>50?.65:distance>22?.35:.08;return distance>50?(style==='conquete'?.04:style==='large'?.06:.08):distance>22?.025:.01}
function tacticalLoad(l,side){if(!tacticalRules(l))return l.tactics[side]==='large'?.49:l.tactics[side]==='conquete'?.44:.39;return l.possession===side?ATTACK_EFFECTS[effectiveAttack(l,side)].load:defensivePlan(l,side)==='pression'?.53:defensivePlan(l,side)==='prudente'?.31:.37}
function tacticalCount(l,side,key,n=1){if(tacticalRules(l))l.tacticalStats[side][key]+=n}
function adaptDefence(l,side){if(!tacticalRules(l))return;const next=chooseDefence(l,side);if(next===l.defences[side])return;l.defences[side]=next;addEvent(l,`${S.clubs[l.pair[side]].abbr} choisit une défense ${DEFENCES[next][0].toLowerCase()} selon le score et la fraîcheur.`,'tactic',{team:side})}
function setDefence(plan){if(S.live||!Object.keys(DEFENCES).includes(plan))return;S.defence=plan;save();render()}
function setLiveDefence(plan){const l=S.live;if(!l||!tacticalRules(l)||!l.paused||l.finished||presentationPending(l)||!Object.keys(DEFENCES).includes(plan))return;l.defences[l.userSide]=plan;S.defence=plan;addEvent(l,`Votre défense : ${DEFENCES[plan][0]}. ${DEFENCES[plan][1]}`,'tactic',{team:l.userSide});syncMatchPresentation(l);save();render()}
function defencePreparation(){return `<div class="card"><div class="cardtitle"><h2>02 / Organisation défensive</h2><span class="tag">PROCHAIN MATCH</span></div><div class="options defence-options">${Object.entries(DEFENCES).map(([key,[title,desc]])=>`<button class="option ${(S.defence||'equilibre')===key?'selected':''}" onclick="setDefence('${key}')">${title}<small>${desc}</small></button>`).join('')}</div><p class="help">Ces choix modifient la réussite adverse, les mètres concédés, les risques de pénalité et la fatigue. Le même calcul s’applique aux adversaires.</p></div>`}
function liveDefenceControls(l){if(!tacticalRules(l))return '<p class="help">Cette rencontre conserve son ancien moteur tactique. Les nouvelles consignes défensives seront disponibles au prochain match.</p>';const side=l.userSide;return `<label class="eyebrow" for="live-defence">VOTRE DÉFENSE</label><select id="live-defence" ${!l.paused||l.finished?'disabled':''} onchange="setLiveDefence(this.value)">${Object.entries(DEFENCES).map(([key,[title]])=>`<option value="${key}" ${l.defences[side]===key?'selected':''}>${title}</option>`).join('')}</select><p class="help">${DEFENCES[l.defences[side]][1]}</p><p class="help">Défense adverse : <strong>${DEFENCES[l.defences[1-side]][0]}</strong>.</p>`}
function tacticalMetrics(l){if(!l.tacticalStats)return '';const a=l.tacticalStats[0],b=l.tacticalStats[1];return `<div class="matchstats"><div class="statcomparison"><b>${S.clubs[l.pair[0]].abbr}</b><span>JEU COURANT</span><b>${S.clubs[l.pair[1]].abbr}</b></div>${[['Progressions réussies',`${a.advances} / ${a.carries}`,`${b.advances} / ${b.carries}`],['Mètres gagnés en portant',Math.round(a.metres),Math.round(b.metres)],['Fautes de main',a.handErrors,b.handErrors],['Coups de pied en jeu',a.kicks,b.kicks],['Récupérations après plaquage',a.recoveries,b.recoveries]].map(([label,x,y])=>`<div class="statcomparison"><strong>${x}</strong><span>${label}</span><strong>${y}</strong></div>`).join('')}</div>`}
function halftimeAdvice(l){
 const side=l.userSide,other=1-side,a=l.tacticalStats?.[side],b=l.tacticalStats?.[other];if(!a||!b)return null;
 const tired=activePlayers(l,side).filter(p=>p.condition<70).sort((a,b)=>a.condition-b.condition).slice(0,3),notes=[],suggestions=[];
 notes.push(`${a.advances} progressions réussies sur ${a.carries} tentatives, pour ${Math.round(a.metres)} mètres gagnés en portant le ballon. ${a.handErrors} faute(s) de main.`);
 notes.push(`En face : ${b.advances} progressions sur ${b.carries}, ${Math.round(b.metres)} mètres gagnés. Votre équipe a concédé ${l.stats[side].penalties} pénalité(s).`);
 if(l.tactics[side]==='large'&&l.weather==='Pluie'&&a.handErrors>=2)suggestions.push({kind:'attack',value:'conquete',reason:`${a.handErrors} fautes de main sous la pluie : rapprocher le jeu réduit le risque de manipulation, avec des gains plus courts.`});
 else if(a.carries>=5&&a.advances/a.carries<.4){const next=unit(l,side,'power',p=>p.fam<=3)>=unit(l,side,'pass',p=>p.fam>=4)?'conquete':'large';if(next!==l.tactics[side])suggestions.push({kind:'attack',value:next,reason:`Seulement ${a.advances} attaques progressent sur ${a.carries}. Essayez un plan adapté aux qualités des joueurs présents.`})}
 if(l.defences[side]==='pression'&&(l.stats[side].penalties>=3||mean(activePlayers(l,side).map(p=>p.condition))<72))suggestions.push({kind:'defence',value:'prudente',reason:'Réduire la pression aiderait à limiter la dépense physique et le risque de pénalité ; vous accepterez davantage de petites avancées adverses.'});
 if(!suggestions.length)notes.push('Pas de changement tactique évident à recommander sur ces seules données. Le score et la fraîcheur restent à surveiller.');
 return {notes,suggestions,tired};
}
function halftimeStaff(l){if(!atHalftime(l)||!tacticalRules(l))return '';const advice=halftimeAdvice(l);return `<section class="card halftime-staff" aria-label="Bilan du staff à la mi-temps"><div class="cardtitle"><h2>Le point du staff</h2><span class="tag">MI-TEMPS</span></div>${advice.notes.map(n=>`<p>${n}</p>`).join('')}${advice.suggestions.map(s=>`<div class="staff-suggestion"><p>${s.reason}</p><button class="small" onclick="${s.kind==='attack'?'setLiveTactic':'setLiveDefence'}('${s.value}')">${s.kind==='attack'?TACTICS[s.value][0]:DEFENCES[s.value][0]} →</button></div>`).join('')}<div class="staff-fitness"><strong>La fraîcheur</strong>${advice.tired.length?advice.tired.map(p=>`<button class="small" onclick="openMatchPlayer(${l.userSide},'${p.id}')">${visualEscape(p.name)} · ${Math.round(p.condition)}% →</button>`).join(''):'<span>Aucun joueur présent sous 70% de condition.</span>'}</div><p class="help">Constats sur cette mi-temps ; les recommandations ne garantissent pas le résultat.</p></section>`}

 
// V21: conseils calculés à la lecture, jamais appliqués sans confirmation.
// Le différentiel vient des joueurs effectivement actifs, pas des compteurs de cartons.
function numericalStaffAdvice(l){
 if(!l||l.finished||l.userSide<0||l.numericalAiVersion!==1||!tacticalRules(l))return null;
 const side=l.userSide,ours=activePlayers(l,side),theirs=activePlayers(l,1-side);
 const difference=ours.length-theirs.length;
 if(difference===0)return null;
 const margin=l.score[side]-l.score[1-side],remaining=Math.max(0,80-matchMinute(l));
 const fitness=ours.length?mean(ours.map(p=>p.condition)):0;
 const pack=unit(l,side,'power',p=>p.fam<=3);
 const backs=(unit(l,side,'pass',p=>p.fam>=4)+unit(l,side,'speed',p=>p.fam>=4))/2;
 const urgent=margin<=-5&&remaining<=15;
 let attack,defence,attackWhy,defenceWhy;
 if(difference<0){
  attack=urgent&&l.weather!=='Pluie'&&backs>=67?'large':
   l.weather==='Pluie'||difference<=-2||margin>=5||pack<backs-12?'occupation':'conquete';
  defence='prudente';
  attackWhy=attack==='large'?'En retard près du terme, tenter la largeur avec les arrières disponibles : choix risqué en sous-nombre.':
   attack==='occupation'?'Privilégier le territoire et limiter les séquences de passes en sous-nombre, selon la météo et les joueurs présents.':
   'S’appuyer sur la puissance des avants disponibles pour conserver le ballon sans trop étirer le dispositif.';
  defenceWhy='Protéger la profondeur en sous-nombre, au prix de petites avancées adverses.';
 }else{
  attack=l.weather==='Pluie'||pack>backs+10?'conquete':'large';
  defence=margin>=7||fitness<65?'prudente':difference>=2&&fitness>=75?'pression':'equilibre';
  attackWhy=attack==='large'?'Exploiter les espaces laissés par les défenseurs moins nombreux avec la vitesse et les passes des arrières.':
   'Sous la pluie ou avec un pack plus performant, privilégier le jeu au près malgré la supériorité numérique.';
  defenceWhy=defence==='pression'?'La fraîcheur du groupe permet de monter plus vite, au risque de concéder des brèches et des pénalités.':
   defence==='prudente'?'Préserver l’avance ou les joueurs fatigués en limitant les risques défensifs.':
   'Garder une défense équilibrée sans surexposer la ligne malgré le joueur supplémentaire.';
 }
 const short=difference<0?side:1-side,sh=l.sheets[short];
 const yellows=(sh.cards||[]).filter(c=>c.until>l.minute).map(c=>c.until-l.minute);
 const replaceable=(sh.redCards||[]).filter(c=>!c.filled&&c.until!==null&&c.until>l.minute).map(c=>c.until-l.minute);
 let clockNote='';
 if(yellows.length)clockNote='Carton jaune : fin d’exclusion dans '+Math.min(...yellows)+' minute(s) de jeu au plus tôt.';
 else if(replaceable.length)clockNote='Rouge remplaçable : remplacement envisageable dans '+Math.min(...replaceable)+' minute(s) de jeu au plus tôt, si un joueur éligible est disponible.';
 else if((sh.redCards||[]).some(c=>c.until===null))clockNote='Rouge définitif : aucun remplacement autorisé pour cette exclusion.';
 const scoreNote=margin>0?'vous menez de '+margin+' point(s)':margin<0?'vous êtes menés de '+(-margin)+' point(s)':'le score est à égalité';
 const recommended=[
  {kind:'attack',value:attack,reason:attackWhy},
  {kind:'defence',value:defence,reason:defenceWhy}
 ];
 const suggestions=recommended.filter(s=>s.value!==(s.kind==='attack'?l.tactics[side]:l.defences[side]));
 // Le plan général peut déjà correspondre au conseil, sans que les zones
 // locales le suivent : le manager doit voir ces conflits même sans conseil global.
 const localZones=playbookRules(l)?l.playbooks[side].zones:null;
 const zoneSuggestions=localZones?recommended.filter(s=>Object.values(localZones).some(z=>z[s.kind]!=='inherit'&&z[s.kind]!==s.value)):[];
 return {ours:ours.length,theirs:theirs.length,difference,remaining,scoreNote,weather:l.weather,clockNote,suggestions,zoneSuggestions};
}
// V22: aperçus contrefactuels en lecture seule fondés sur les coefficients du moteur.
// Pas de simulation aléatoire, de prévision de résultat ni de changement de consigne.
function numericalAdviceModel(l,kind,plan){
 if(!tacticalRules(l))return null;
 const side=l.userSide,shadow=Object.create(l);
 shadow.tactics=[...l.tactics];shadow.defences=[...l.defences];
 if(kind==='attack'){
  if(!Object.hasOwn(TACTICS,plan))return null;
  shadow.tactics[side]=plan;shadow.possession=side;
  const actual=effectiveAttack(shadow,side),range=ATTACK_EFFECTS[actual].gain;
  const defence=defensivePlan(shadow,1-side),shift=defence==='pression'?4:defence==='prudente'?-4:0;
  return {actual,minimum:Math.max(3,range[0]+shift),maximum:range[1]+shift,
   handling:handFaultProbability(shadow,side),kicking:openKickProbability(shadow,side),
   fatigue:tacticalLoad(shadow,side)};
 }
 if(kind==='defence'){
  if(!Object.hasOwn(DEFENCES,plan))return null;
  shadow.defences[side]=plan;shadow.possession=1-side;
  const actual=effectiveDefence(shadow,side);
  return {actual,penalty:tacticalPenaltyAdjustment(shadow,side),
   fatigue:tacticalLoad(shadow,side),
   cover:actual==='prudente'?'Profondeur mieux protégée':
         actual==='pression'?'Plus de grands gains possibles si la montée est battue':
         'Compromis de couverture'};
 }
 return null;
}
function numericalAdviceComparison(l,suggestion){
 if(!suggestion||!['attack','defence'].includes(suggestion.kind))return '';
 const side=l.userSide,oldPlan=suggestion.kind==='attack'?l.tactics[side]:l.defences[side];
 const current=numericalAdviceModel(l,suggestion.kind,oldPlan);
 const proposed=numericalAdviceModel(l,suggestion.kind,suggestion.value);
 if(!current||!proposed)return '';
 const percent=x=>(x*100).toFixed(1).replace('.',',')+' %';
 const index=x=>x.toFixed(2).replace('.',',');
 const points=x=>(x>0?'+':x<0?'−':'')+Math.abs(x*100).toFixed(1).replace('.',',')+' point(s)';
 const zone=playbookRules(l)?l.playbooks[side].zones[fieldZone(side,l.territory)]:null;
 const override=zone&&zone[suggestion.kind]!=='inherit';
 const same=current.actual===proposed.actual;
 const rows=suggestion.kind==='attack'?
  [['Mètres par progression réussie',current.minimum+'–'+current.maximum+' m',proposed.minimum+'–'+proposed.maximum+' m'],
   ['Risque de faute de main par séquence',percent(current.handling),percent(proposed.handling)],
   ['Propension au jeu au pied dans cette zone',percent(current.kicking),percent(proposed.kicking)],
   ['Indice de dépense offensive',index(current.fatigue),index(proposed.fatigue)]]:
  [['Risque de pénalité : ajustement du moteur',points(current.penalty),points(proposed.penalty)],
   ['Indice de dépense défensive',index(current.fatigue),index(proposed.fatigue)],
   ['Couverture de la profondeur',current.cover,proposed.cover]];
 const oldLabel=suggestion.kind==='attack'?TACTICS[oldPlan][0]:DEFENCES[oldPlan][0];
 const newLabel=suggestion.kind==='attack'?TACTICS[suggestion.value][0]:DEFENCES[suggestion.value][0];
 return '<div class="advice-comparison" aria-label="Comparaison tactique entre la consigne actuelle et celle du staff">'
 +'<p class="help">Comparaison dans la zone actuelle : <strong>'+oldLabel+'</strong> → <strong>'+newLabel+'</strong>.</p>'
 +rows.map(([label,currentValue,proposedValue])=>'<div class="advice-comparison-row"><span>'+label+'</span><span>'+currentValue+' → <strong>'+proposedValue+'</strong></span></div>').join('')
 +(override?'<p class="help">Le carnet de jeu impose déjà un plan local dans cette zone : les effets affichés restent identiques tant que cette priorité est active.</p>':'')
 +(same&&!override?'<p class="help">Dans cette zone, le moteur conserve les mêmes effets pour ces deux choix.</p>':'')
 +'<p class="help">Valeurs et indices du moteur fictif, à situation de jeu identique : ce ne sont ni des statistiques réelles ni des prédictions de score. Une autre zone, la possession ou les qualités des joueurs peuvent changer les effets.</p>'
 +'</div>';
}
// V23 : identifier par zone les priorités locales qui neutralisent le conseil.
function numericalAdviceZoneControls(l,suggestion){
 if(!playbookRules(l)||!suggestion||!['attack','defence'].includes(suggestion.kind))return '';
 const side=l.userSide,zones=l.playbooks[side].zones;
 const options=suggestion.kind==='attack'?TACTICS:DEFENCES;
 const conflicts=Object.entries(FIELD_ZONES).filter(([zone])=>{
  const local=zones[zone][suggestion.kind];
  return local!=='inherit'&&local!==suggestion.value;
 });
 if(!conflicts.length)return '';
 const here=fieldZone(side,l.territory);
 const canApply=l.paused&&!l.finished&&!presentationPending(l);
 return `<div class="advice-local-zones" aria-label="Consignes locales prioritaires">
 <p class="help"><strong>Priorité du carnet de jeu :</strong> les zones suivantes remplacent le plan principal. Le conseil du staff ne s’y applique pas automatiquement.</p>`
 +conflicts.map(([zone,title])=>{
  const current=zones[zone][suggestion.kind],action=suggestion.kind==='attack'?'attaque':'défense';
  return `<div class="advice-local-zone"><div><strong>${title}${zone===here?' · zone actuelle':''}</strong>
   <p class="help">${action[0].toUpperCase()+action.slice(1)} locale : ${options[current][0]} ; le staff conseille ${options[suggestion.value][0]}. Cette priorité locale neutralise le conseil dans cette zone.</p></div>
   <button class="small" onclick="applyNumericalZoneAdvice('${suggestion.kind}','${zone}','${suggestion.value}')" ${canApply?'':'disabled'}>Adapter cette zone</button></div>`;
 }).join('')
 +`<p class="help">Chaque bouton modifie uniquement la consigne locale indiquée, après votre clic. Le plan principal et les autres zones ne changent pas.</p></div>`;
}
// V24 : comparaison simultanée et sans mutation des quatre zones du terrain.
// Les points repères sont au milieu de chaque secteur depuis notre propre en-but.
const FOUR_ZONE_SAMPLE={sortie:12,construction:36,pression:64,marque:90};
function fourZoneTacticalPreview(l){
 if(!l||!playbookRules(l)||![0,1].includes(l.userSide))return [];
 const side=l.userSide;
 return Object.entries(FIELD_ZONES).map(([zone,label])=>{
  const own=FOUR_ZONE_SAMPLE[zone],territory=side===0?own:100-own;
  const sample=Object.create(l);sample.territory=territory;
  const attack=numericalAdviceModel(sample,'attack',l.tactics[side]);
  const defence=numericalAdviceModel(sample,'defence',l.defences[side]);
  if(!attack||!defence)return null;
  const local=l.playbooks[side].zones[zone];
  return {zone,label,own,territory,current:fieldZone(side,l.territory)===zone,
   attack,defence,attackLocal:local.attack!=='inherit',defenceLocal:local.defence!=='inherit'};
 }).filter(Boolean);
}
function fourZoneTacticalPanel(l){
 const zones=fourZoneTacticalPreview(l);if(zones.length!==4)return '';
 const percent=n=>(n*100).toFixed(1).replace('.',',')+' %';
 const index=n=>n.toFixed(2).replace('.',',');
 const points=n=>(n>0?'+':n<0?'−':'')+Math.abs(n*100).toFixed(1).replace('.',',')+' pt';
 return `<div class="four-zone-preview" aria-label="Comparaison tactique des quatre zones">
 <h3>Votre plan sur les quatre zones</h3>
 <p class="help">Aperçu comparatif en lecture seule, calculé à 12, 36, 64 et 90 m de votre en-but. Une consigne locale prioritaire est signalée. Les chiffres proviennent du moteur fictif, sans prédire le résultat.</p>
 <div class="four-zone-scroll"><table><thead><tr><th scope="col">Zone</th><th scope="col">Attaque</th><th scope="col">Défense</th></tr></thead><tbody>
 ${zones.map(z=>`<tr class="${z.current?'four-zone-current':''}">
  <th scope="row">${z.label}${z.current?' · ballon ici':''}<small>Repère : ${z.own} m depuis votre en-but</small></th>
  <td><strong>${TACTICS[z.attack.actual][0]}</strong> <small>${z.attackLocal?'Consigne locale':'Plan général'}</small>
   <span>Gain si progression réussie : ${z.attack.minimum}–${z.attack.maximum} m</span>
   <span>Faute de main / séquence : ${percent(z.attack.handling)}</span>
   <span>Jeu au pied : ${percent(z.attack.kicking)}</span>
   <span>Indice de fatigue offensive : ${index(z.attack.fatigue)}</span></td>
  <td><strong>${DEFENCES[z.defence.actual][0]}</strong> <small>${z.defenceLocal?'Consigne locale':'Plan général'}</small>
   <span>Risque de pénalité, ajustement : ${points(z.defence.penalty)}</span>
   <span>Couverture : ${z.defence.cover}</span>
   <span>Indice de fatigue défensive : ${index(z.defence.fatigue)}</span></td>
 </tr>`).join('')}</tbody></table></div>
 <p class="help">Les valeurs correspondent à quatre situations représentatives indépendantes : vous attaquez avec le ballon, ou vous défendez face à la possession adverse. Elles peuvent varier selon le territoire exact, la météo et les joueurs. Modifier une tactique exige toujours une action explicite dans le carnet de jeu.</p>
 </div>`;
}
function numericalAdvicePanel(l){
 const advice=numericalStaffAdvice(l);if(!advice)return '';
 const canApply=l.paused&&!presentationPending(l),text=advice.difference<0?'INFÉRIORITÉ':'SUPÉRIORITÉ';
 return `<section class="card numerical-advice" aria-label="Conseils tactiques en déséquilibre numérique">
  <div class="cardtitle"><h2>Le conseil du staff</h2><span class="tag">${text} · ${advice.ours} CONTRE ${advice.theirs}</span></div>
  <p>Sur le terrain : <strong>${advice.ours} contre ${advice.theirs}</strong> · ${advice.scoreNote} · ${advice.weather} · ${advice.remaining} min restantes au temps réglementaire.</p>
  ${advice.clockNote?`<p class="help">${advice.clockNote}</p>`:''}
  ${advice.suggestions.length?advice.suggestions.map(s=>`<div class="staff-suggestion">
   <div><strong>${s.kind==='attack'?'Attaque':'Défense'} : ${s.kind==='attack'?TACTICS[s.value][0]:DEFENCES[s.value][0]}</strong><p>${s.reason}</p>${numericalAdviceComparison(l,s)}${numericalAdviceZoneControls(l,s)}</div>
   <button class="small" onclick="applyNumericalAdvice('${s.kind}','${s.value}')" ${canApply?'':'disabled'}>Appliquer cette consigne</button>
  </div>`).join(''):'<p class="help">Vos consignes générales correspondent déjà aux recommandations du staff.</p>'}
  ${(advice.zoneSuggestions||[]).filter(s=>!advice.suggestions.some(a=>a.kind===s.kind)).map(s=>`<div class="staff-suggestion"><div><strong>${s.kind==='attack'?'Attaque':'Défense'} : votre plan principal correspond au conseil du staff.</strong>${numericalAdviceZoneControls(l,s)}</div></div>`).join('')}
  <p class="help">${canApply?'À vous de choisir.':'Mettez le match en pause pour appliquer une recommandation.'} Les consignes par zone du carnet de jeu restent prioritaires. Aucun ajustement automatique.</p>
 </section>`;
}
function applyNumericalAdvice(kind,value){
 const l=S?.live;
 if(!l||!l.paused||l.finished||presentationPending(l))return false;
 const advice=numericalStaffAdvice(l);
 if(!advice||!advice.suggestions.some(s=>s.kind===kind&&s.value===value))return false;
 if(kind==='attack')setLiveTactic(value);
 else if(kind==='defence')setLiveDefence(value);
 else return false;
 return true;
}
