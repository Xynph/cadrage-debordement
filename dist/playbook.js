'use strict';
let playbookZone='sortie';
const FIELD_ZONES={sortie:'Vos 22 mètres',construction:'Vos 22 → milieu',pression:'Milieu → leurs 22',marque:'Leurs 22 mètres'};
const SCRUM_MOVES={equilibre:['Sortie équilibrée','Conserver les compromis habituels.'],securiser:['Sécuriser la sortie','Plus de conservation, moins de mètres et de possibilités d’essai direct.'],pousser:['Pousser puis jouer','Plus de mètres si la mêlée est gagnée, mais une conservation moins sûre.']};
const LINEOUT_MOVES={equilibre:['Lancer équilibré','Le compromis habituel entre conservation et avancée.'],courte:['Touche courte','Conservation plus sûre, gain de terrain réduit.'],fond:['Fond de touche','Davantage de mètres et de possibilités derrière, avec un lancer moins sûr.'],maul:['Ballon porté','Installer la puissance des avants, en acceptant une conservation un peu moins sûre.']};
const KICKOFF_MOVES={normal:['Renvoi standard','Distance et contest habituels.'],court:['Renvoi court','10 à 14 mètres : plus de chances de reprendre le ballon, mais moins de territoire gagné.'],long:['Renvoi long','25 à 35 mètres : plus de territoire, moins de chances de récupérer immédiatement.']};
function defaultPlaybook(){return {zones:Object.fromEntries(Object.keys(FIELD_ZONES).map(key=>[key,{attack:'inherit',defence:'inherit'}])),scrum:'equilibre',lineout:'equilibre',kickoff:'normal'}}
function playbookRules(l){return tacticalRules(l)&&l.playbookVersion===1}
function fieldZone(side,at){const own=side===0?at:100-at;return own<=22?'sortie':own<50?'construction':own<78?'pression':'marque'}
function effectiveAttack(l,side,at=l.territory){const choice=playbookRules(l)?l.playbooks[side].zones[fieldZone(side,at)].attack:'inherit';return choice==='inherit'?l.tactics[side]:choice}
function effectiveDefence(l,side,at=l.territory){const choice=playbookRules(l)?l.playbooks[side].zones[fieldZone(side,at)].defence:'inherit';return choice==='inherit'?(l.defences?.[side]||'equilibre'):choice}
function initializePlaybooks(l){l.playbookVersion=1;l.playbooks=l.pair.map((ci,side)=>JSON.parse(JSON.stringify(side===l.userSide&&S.manager?S.manager.playbook:defaultPlaybook())))}
function setPlaybookChoice(key,value){const l=S.live;if(l&&(!playbookRules(l)||!l.paused||l.finished||presentationPending(l)))return;if(!S.manager)return;
 let target;if(key==='attack'||key==='defence'){if(!Object.hasOwn(FIELD_ZONES,playbookZone))return;const allowed=key==='attack'?TACTICS:DEFENCES;if(value!=='inherit'&&!Object.keys(allowed).includes(value))return;target=S.manager.playbook.zones[playbookZone];target[key]=value;if(l)l.playbooks[l.userSide].zones[playbookZone][key]=value}
 else{const options={scrum:SCRUM_MOVES,lineout:LINEOUT_MOVES,kickoff:KICKOFF_MOVES};if(!options[key]||!Object.keys(options[key]).includes(value))return;S.manager.playbook[key]=value;if(l)l.playbooks[l.userSide][key]=value}
 if(l){addEvent(l,`Votre plan de jeu est ajusté : ${key==='attack'?'attaque dans '+FIELD_ZONES[playbookZone].toLowerCase():key==='defence'?'défense dans '+FIELD_ZONES[playbookZone].toLowerCase():key==='scrum'?'mêlées':key==='lineout'?'touches':'renvois'}.`,'tactic',{team:l.userSide});syncMatchPresentation(l)}save();render();
}
// V23 : une confirmation par zone, sans changer la tactique générale.
// Revalider à chaque clic la recommandation et les règles de pause pour empêcher
// qu'un bouton affiché avant un événement ne modifie une autre situation.
function applyNumericalZoneAdvice(kind,zone,value){
 const l=S?.live;
 if(!l||l.finished||!l.paused||presentationPending(l)||!playbookRules(l)
  ||!S.manager||!Object.hasOwn(FIELD_ZONES,zone)
  ||!['attack','defence'].includes(kind))return false;
 const allowed=kind==='attack'?TACTICS:DEFENCES;
 if(!Object.hasOwn(allowed,value))return false;
 const advice=numericalStaffAdvice(l);
 if(!advice||![...advice.suggestions,...(advice.zoneSuggestions||[])].some(s=>s.kind===kind&&s.value===value))return false;
 const local=l.playbooks?.[l.userSide]?.zones?.[zone];
 const career=S.manager.playbook?.zones?.[zone];
 if(!local||!career||local[kind]==='inherit'||local[kind]===value)return false;
 local[kind]=value;
 career[kind]=value;
 addEvent(l,`Votre consigne locale de ${kind==='attack'?'attaque':'défense'} dans ${FIELD_ZONES[zone].toLowerCase()} : ${allowed[value][0]}.`,'tactic',{team:l.userSide});
 syncMatchPresentation(l);
 save();
 render();
 return true;
}
function setPieceEffects(l,side,kind){if(!playbookRules(l))return {win:0,gain:0,finish:0,move:'equilibre'};const move=l.playbooks[side][kind];const table=kind==='scrum'?{equilibre:[0,0,0],securiser:[.025,-2,-.03],pousser:[-.04,4,.04]}:{equilibre:[0,0,0],courte:[.04,-3,-.03],fond:[-.05,5,.04],maul:[-.025,2,.05]};const [win,gain,finish]=table[move];return {win,gain,finish,move}}
function kickoffPolicy(l,side,kind){const choice=kind==='kickoff'&&playbookRules(l)?l.playbooks[side].kickoff:'normal';return {choice,distance:choice==='court'?[10,14]:choice==='long'?[25,35]:null,retain:choice==='court'?.12:choice==='long'?-.05:0}}
function playbookPanel(l=null){if(l&&!playbookRules(l))return '';const p=l?l.playbooks[l.userSide]:S.manager.playbook,disabled=l&&(!l.paused||l.finished),z=p.zones[playbookZone];return `<section class="card playbook-panel" aria-label="Consignes par zone et phases arrêtées"><div class="cardtitle"><h2>Le carnet de jeu</h2><span class="tag">${l?'EN PAUSE':'PROCHAIN MATCH'}</span></div><p class="help">Les zones sont orientées depuis votre propre en-but. Une consigne locale remplace le plan principal dans cette zone.</p><div class="zone-tabs">${Object.entries(FIELD_ZONES).map(([key,title])=>`<button class="small ${playbookZone===key?'dark':''}" onclick="playbookZone='${key}';render()">${title}</button>`).join('')}</div><div class="playbook-selects">${[['attack','Attaque de la zone',TACTICS],['defence','Défense de la zone',DEFENCES]].map(([key,title,options])=>`<label>${title}<select aria-label="${title}" ${disabled?'disabled':''} onchange="setPlaybookChoice('${key}',this.value)"><option value="inherit">Suivre le plan principal</option>${Object.entries(options).map(([value,[name]])=>`<option value="${value}" ${z[key]===value?'selected':''}>${name}</option>`).join('')}</select></label>`).join('')}</div><p class="help">${z.attack==='inherit'?'Attaque : plan principal.':TACTICS[z.attack][1]} ${z.defence==='inherit'?'Défense : plan principal.':DEFENCES[z.defence][1]}</p><h3>Les phases arrêtées</h3><div class="playbook-selects">${[['scrum','Sur vos mêlées',SCRUM_MOVES],['lineout','Sur vos touches',LINEOUT_MOVES],['kickoff','Vos renvois au centre',KICKOFF_MOVES]].map(([key,title,options])=>`<label>${title}<select aria-label="${title}" ${disabled?'disabled':''} onchange="setPlaybookChoice('${key}',this.value)">${Object.entries(options).map(([value,[name]])=>`<option value="${value}" ${p[key]===value?'selected':''}>${name}</option>`).join('')}</select><small>${options[p[key]][1]}</small></label>`).join('')}</div><p class="help">Les procédures réglementaires restent prioritaires : aucun effet de poussée sur une mêlée non disputée. Les placements 2D restent schématiques.</p>${l?fourZoneTacticalPanel(l):''}</section>`}
function playbookView(){return heading('VOTRE IDENTITÉ RUGBY','Le plan de jeu.','Adaptez votre approche aux zones du terrain et préparez les phases arrêtées.')+playbookPanel()+`<div class="notice">Ces choix s’appliquent au prochain match. En rencontre, vous pouvez les ajuster dans les consignes pendant une pause.</div><button class="primary" style="margin-top:18px" onclick="nav('match')">Préparer la rencontre →</button>`}
