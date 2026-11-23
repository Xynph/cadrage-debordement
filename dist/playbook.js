'use strict';
let playbookZone='sortie';
// Combinaisons de phases arrêtées branchées au match (23/11/2026) ; 0 = rencontres créées avec l'ancien carnet.
let COMBI_RULES=1;
const FIELD_ZONES={sortie:'Tes 22 mètres',construction:'Tes 22 → milieu',pression:'Milieu → leurs 22',marque:'Leurs 22 mètres'};
const SCRUM_MOVES={equilibre:['Sortie équilibrée','Conserver les compromis habituels.'],securiser:['Sécuriser la sortie','Plus de conservation, moins de mètres et de possibilités d’essai direct.'],pousser:['Pousser puis jouer','Plus de mètres si la mêlée est gagnée, mais une conservation moins sûre.']};
const LINEOUT_MOVES={equilibre:['Lancer équilibré','Le compromis habituel entre conservation et avancée.'],courte:['Touche courte','Conservation plus sûre, gain de terrain réduit.'],fond:['Fond de touche','Davantage de mètres et de possibilités derrière, avec un lancer moins sûr.'],maul:['Ballon porté','Installer la puissance des avants, en acceptant une conservation un peu moins sûre.']};
const KICKOFF_MOVES={normal:['Renvoi standard','Distance et contest habituels.'],court:['Renvoi court','10 à 14 mètres : plus de chances de reprendre le ballon, mais moins de territoire gagné.'],long:['Renvoi long','18 à 26 mètres : plus de territoire, moins de chances de récupérer immédiatement.']};
function defaultPlaybook(){return {zones:Object.fromEntries(Object.keys(FIELD_ZONES).map(key=>[key,{attack:'inherit',defence:'inherit'}])),scrum:'equilibre',lineout:'equilibre',kickoff:'normal'}}
function playbookRules(l){return tacticalRules(l)&&l.playbookVersion===1}
function fieldZone(side,at){const own=side===0?at:100-at;return own<=22?'sortie':own<50?'construction':own<78?'pression':'marque'}
function effectiveAttack(l,side,at=l.territory){const choice=playbookRules(l)?l.playbooks[side].zones[fieldZone(side,at)].attack:'inherit';return choice==='inherit'?l.tactics[side]:choice}
function effectiveDefence(l,side,at=l.territory){const choice=playbookRules(l)?l.playbooks[side].zones[fieldZone(side,at)].defence:'inherit';return choice==='inherit'?(l.defences?.[side]||'equilibre'):choice}
function initializePlaybooks(l){l.playbookVersion=1;if(COMBI_RULES)l.combiVersion=1;l.playbooks=l.pair.map((ci,side)=>JSON.parse(JSON.stringify(side===l.userSide&&S.manager?S.manager.playbook:defaultPlaybook())))}
function setPlaybookChoice(key,value){const l=S.live;if(l&&(!playbookRules(l)||!l.paused||l.finished||presentationPending(l)))return;if(!S.manager)return;
 let target;if(key==='attack'||key==='defence'){if(!Object.hasOwn(FIELD_ZONES,playbookZone))return;const allowed=key==='attack'?TACTICS:DEFENCES;if(value!=='inherit'&&!Object.keys(allowed).includes(value))return;target=S.manager.playbook.zones[playbookZone];target[key]=value;if(l)l.playbooks[l.userSide].zones[playbookZone][key]=value}
 else{const options={scrum:SCRUM_MOVES,lineout:LINEOUT_MOVES,kickoff:KICKOFF_MOVES};if(!options[key]||!Object.keys(options[key]).includes(value))return;S.manager.playbook[key]=value;combiDepuisAncienChoix(S.manager.playbook,key,value);if(l){l.playbooks[l.userSide][key]=value;combiDepuisAncienChoix(l.playbooks[l.userSide],key,value)}}
 if(l){addEvent(l,`Ton plan de jeu est ajusté : ${key==='attack'?'attaque dans '+FIELD_ZONES[playbookZone].toLowerCase():key==='defence'?'défense dans '+FIELD_ZONES[playbookZone].toLowerCase():key==='scrum'?'mêlées':key==='lineout'?'touches':'renvois'}.`,'tactic',{team:l.userSide});syncMatchPresentation(l)}save();render();
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
 addEvent(l,`Ta consigne locale de ${kind==='attack'?'attaque':'défense'} dans ${FIELD_ZONES[zone].toLowerCase()} : ${allowed[value][0]}.`,'tactic',{team:l.userSide});
 syncMatchPresentation(l);
 save();
 render();
 return true;
}
// Combinaisons de phases arrêtées (Tactique › Phases arrêtées, idée FM27 n° 21, choix de Léo du 23/11/2026).
// Touche, mêlée, pénalité et renvoi, en attaque et en défense : plusieurs combinaisons enregistrées par phase dans
// `manager.playbook.combos`, une active. Chaque choix (pivot) a un premier choix neutre (effet nul) : un carnet sans
// combinaisons (clubs gérés par l'ordinateur, anciennes sauvegardes) joue exactement comme avant, sans tirage de plus.
// Effets additifs de simulation, modestes : [conservation, mètres après conquête gagnée, essai près de la ligne].
// Rencontres créées avec `combiVersion: 1` seulement (les autres gardent l'ancien carnet scrum/lineout/kickoff).
const COMBI_CLES=['lineout_attaque','scrum_attaque','penalty_attaque','kickoff_attaque','lineout_defense','scrum_defense','penalty_defense','kickoff_defense'];
const COMBI_PENALITE=[['staff','Selon le score'],['poteaux','Au but'],['touche','Pénaltouche'],['melee','Mêlée'],['main','Jouer vite']];
const COMBI_PIVOTS={
 lineout_attaque:[['alignement','Alignement',[['7','7 joueurs',[0,0,0]],['5','5 joueurs',[.015,0,-.03]],['4','4 joueurs',[.03,-1,-.03]]]],
  ['cible','Sauteur visé',[['milieu','Milieu',[0,0,0]],['devant','Devant',[.04,-1,-.02]],['fond','Fond',[-.05,1,.03]]]],
  ['suite','Puis',[['deploye','Jeu déployé',[0,0,0]],['maul','Ballon porté',[-.03,1,.03]],['ras','Au ras du 9',[0,-1,.05]]]]],
 scrum_attaque:[['sortie','Sortie',[['equilibre','Équilibrée',[0,0,0]],['pousser','Pousser',[-.05,2,.03]],['vite','Jouer vite',[.03,-1,-.02]],['huit','8 qui part',[-.02,1,.02]]]],
  ['cote','Côté',[['ouvert','Ouvert',[0,0,0]],['ferme','Fermé',[0,-1,.04]]]]],
 penalty_attaque:[['pres','Dans leurs 22',COMBI_PENALITE],['portee','À portée',COMBI_PENALITE],['loin','Loin',COMBI_PENALITE]],
 kickoff_attaque:[['renvoi','Renvoi',[['normal','Standard'],['court','Court'],['long','Long']]]],
 lineout_defense:[['contre','Contre',[['lire','Lire le lancer'],['devant','Devant'],['fond','Fond'],['maul','Contrer le maul']]]],
 scrum_defense:[['poussee','Sur leur introduction',[['stable','Rester stable'],['pousser','Pousser']]]],
 penalty_defense:[['repli','Repli',[['normal','Normal'],['vite','Repli rapide'],['mur','Mur contre le maul']]]],
 kickoff_defense:[['reception','Réception',[['standard','Standard'],['avants','Avants devant'],['profonde','Profonde']]]],
};
// Combinaisons proposées au départ (la première d'une phase d'attaque reprend l'ancien choix du carnet).
const COMBI_DEPART={
 lineout_attaque:[['Maul des 22',{alignement:'7',cible:'milieu',suite:'maul'}],['Touche courte',{alignement:'4',cible:'devant',suite:'deploye'}],['Fond pour le 12',{alignement:'5',cible:'fond',suite:'deploye'}]],
 scrum_attaque:[['Mêlée poussée',{sortie:'pousser',cote:'ferme'}],['Sortie vite',{sortie:'vite',cote:'ouvert'}],['8 qui part',{sortie:'huit',cote:'ferme'}]],
 penalty_attaque:[['Les points',{pres:'poteaux',portee:'poteaux',loin:'touche'}],['Pénaltouche',{pres:'touche',portee:'touche',loin:'touche'}],['Mêlée près de la ligne',{pres:'melee',portee:'poteaux',loin:'touche'}]],
 kickoff_attaque:[['Renvoi court',{renvoi:'court'}],['Renvoi long',{renvoi:'long'}]],
 lineout_defense:[['Contre devant',{contre:'devant'}],['Contrer le maul',{contre:'maul'}]],
 scrum_defense:[['Pousser sur leur introduction',{poussee:'pousser'}]],
 penalty_defense:[['Repli rapide',{repli:'vite'}],['Mur contre le maul',{repli:'mur'}]],
 kickoff_defense:[['Avants devant',{reception:'avants'}],['Réception profonde',{reception:'profonde'}]],
};
const COMBI_MAX=8;
function combiRules(l){return playbookRules(l)&&l.combiVersion===1}
function combiNeutre(cle){return Object.fromEntries(COMBI_PIVOTS[cle].map(([k,,o])=>[k,o[0][0]]))}
function combiOption(cle,pivot,valeur){return COMBI_PIVOTS[cle]?.find(p=>p[0]===pivot)?.[2].find(o=>o[0]===valeur)||null}
// Choix tirés de l'ancien carnet (scrum / lineout / kickoff) pour une phase d'attaque.
function combiDepuisCarnet(p,cle){const c=combiNeutre(cle);if(cle==='lineout_attaque'){if(p?.lineout==='maul')c.suite='maul';else if(p?.lineout==='courte')c.cible='devant';else if(p?.lineout==='fond')c.cible='fond'}else if(cle==='scrum_attaque'){if(p?.scrum==='pousser')c.sortie='pousser';else if(p?.scrum==='securiser')c.sortie='vite'}else if(cle==='kickoff_attaque'&&KICKOFF_MOVES[p?.kickoff])c.renvoi=p.kickoff;return c}
// Ancien choix du carnet correspondant à une combinaison (affichage du carnet, textes du direct, origine des essais).
function combiVersCarnet(cle,c){if(cle==='lineout_attaque')return c.suite==='maul'?'maul':c.cible==='devant'?'courte':c.cible==='fond'?'fond':'equilibre';if(cle==='scrum_attaque')return c.sortie==='pousser'?'pousser':c.sortie==='vite'?'securiser':'equilibre';return c.renvoi||'normal'}
// Liste projetée (enregistrée, sinon proposée sans rien écrire).
function combiListe(p,cle){const e=p?.combos?.[cle];if(e)return e;const neutre=cle.endsWith('_attaque')?combiDepuisCarnet(p,cle):combiNeutre(cle);return {active:0,liste:[{nom:cle.endsWith('_attaque')&&cle!=='penalty_attaque'?'Standard':cle==='penalty_attaque'?'Selon le score':'Standard',choix:neutre},...COMBI_DEPART[cle].map(([nom,choix])=>({nom,choix:{...combiNeutre(cle),...choix}}))]}}
// Choix actifs d'un camp pour une phase (neutres si le carnet n'a pas de combinaisons).
function combiChoix(p,cle){if(!p?.combos?.[cle])return cle.endsWith('_attaque')?combiDepuisCarnet(p,cle):combiNeutre(cle);const e=p.combos[cle];return {...combiNeutre(cle),...(e.liste[e.active]?.choix||{})}}
function syncLegacyMoves(p){if(!p?.combos)return;for(const [cle,key] of [['scrum_attaque','scrum'],['lineout_attaque','lineout'],['kickoff_attaque','kickoff']])p[key]=combiVersCarnet(cle,combiChoix(p,cle))}
// Écrit l'ancien choix du carnet (carnet en match) dans la combinaison active.
function combiDepuisAncienChoix(p,key,value){if(!p?.combos)return;const cle=key+'_attaque',e=p.combos[cle];if(!e)return;const c=e.liste[e.active].choix,d=combiDepuisCarnet({[key]:value},cle);if(key==='lineout'){c.cible=d.cible;c.suite=d.suite}else if(key==='scrum')c.sortie=d.sortie;else c.renvoi=d.renvoi}
function combiCompleter(p){if(!p)return null;if(!p.combos){p.combos={};for(const cle of COMBI_CLES)p.combos[cle]=JSON.parse(JSON.stringify(combiListe(p,cle)))}return p.combos}
// Cible visée par un lanceur sans combinaison (ordinateur) : les lancers varient, sans tirage (3 milieu, 3 devant, 2 fond).
const COMBI_ROTATION=['milieu','devant','milieu','fond','devant','milieu','devant','fond'];
const COMBI_CONTRE={devant:{devant:-.06,milieu:-.02,fond:.015},fond:{fond:-.06,milieu:-.02,devant:.015}};
// Change une combinaison (avant le match, ou en pause : la rencontre suit aussitôt). Rend vrai si appliqué.
function setCombinaison(cle,action,index,pivot,valeur){const l=S?.live;if(l&&(!playbookRules(l)||!l.paused||l.finished||presentationPending(l)))return false;if(!S?.manager?.playbook||!COMBI_CLES.includes(cle))return false;
 const cibles=[S.manager.playbook];if(l)cibles.push(l.playbooks[l.userSide]);
 const e0=combiCompleter(S.manager.playbook)[cle];
 if(action==='choisir'){if(!Number.isInteger(index)||index<0||index>=e0.liste.length)return false}
 else if(action==='ajouter'){if(e0.liste.length>=COMBI_MAX)return false}
 else if(action==='pivot'){if(!combiOption(cle,pivot,valeur))return false}
 else return false;
 for(const p of cibles){const e=combiCompleter(p)[cle];if(action==='choisir')e.active=Math.min(index,e.liste.length-1);else if(action==='ajouter'){const c=JSON.parse(JSON.stringify(e.liste[e.active]));c.nom='Combinaison '+(e.liste.length+1);e.liste.push(c);e.active=e.liste.length-1}else e.liste[e.active].choix[pivot]=valeur;syncLegacyMoves(p)}
 if(l){addEvent(l,'Tes phases arrêtées sont ajustées.','tactic',{team:l.userSide});syncMatchPresentation(l)}save();render();return true}
function setPieceEffects(l,side,kind,fromPenalty=false){if(!playbookRules(l))return {win:0,gain:0,finish:0,move:'equilibre'};
 if(!combiRules(l)){const move=l.playbooks[side][kind];const table=kind==='scrum'?{equilibre:[0,0,0],securiser:[.025,-2,-.03],pousser:[-.04,4,.04]}:{equilibre:[0,0,0],courte:[.04,-3,-.03],fond:[-.05,5,.04],maul:[-.025,2,.05]};const [win,gain,finish]=table[move];return {win,gain,finish,move}}
 const cle=kind+'_attaque',c=combiChoix(l.playbooks[side],cle),d=combiChoix(l.playbooks[1-side],kind+'_defense');let win=0,gain=0,finish=0,label=null;
 for(const [pivot] of COMBI_PIVOTS[cle]){const v=combiOption(cle,pivot,c[pivot])?.[2]||[0,0,0];win+=v[0];gain+=v[1];finish+=v[2]}
 if(kind==='scrum'&&c.sortie==='huit'){
  // 8 qui part : la puissance du n° 8 fait le gain (bon 8 : plus de mètres et d'essais ; 8 moyen : moins).
  const huit=matchPlayer(l,side,l.sheets[side].on[7]),f=skill(huit,'power',fitArrete(l))-65;gain+=Math.round(clamp(f*.06,-1,1));finish+=clamp(f*.0015,-.02,.02);label='8 qui part'}
 if(kind==='scrum'&&d.poussee==='pousser')win-=.03;
 if(kind==='lineout'){
  if(d.contre==='maul'){win+=.02;gain-=1;finish-=.04}
  else if(COMBI_CONTRE[d.contre]){const vise=l.playbooks[side].combos?.lineout_attaque||c.cible!=='milieu'?c.cible:COMBI_ROTATION[(l.stats[side].lineouts||0)%COMBI_ROTATION.length];win+=COMBI_CONTRE[d.contre][vise]||0}
  if(fromPenalty){const r=combiChoix(l.playbooks[1-side],'penalty_defense').repli;finish+=r==='mur'?-.04:r==='vite'?.02:0}
 }
 const lu=l.combiLecture?.side===side&&l.combiLecture.kind===kind?Math.min(4,l.combiLecture.n):0;if(lu){win-=.02*lu;finish-=.025*lu}
 const move=combiVersCarnet(cle,c);return {win,gain,finish,move,label,huit:kind==='scrum'&&c.sortie==='huit',ras:kind==='lineout'&&c.suite==='ras'}}
// Effets affichés d'une combinaison : [libellé, valeur, unité, sens] (sens 1 : plus est mieux pour nous ; −1 : moins est mieux).
// Mêmes tables que le match ; « 8 qui part » avec la puissance du n° 8 donnée (65 si inconnue) ; contre en touche moyenné sur
// des lancers variés (3 milieu, 3 devant, 2 fond).
function combiEffets(cle,choix,puissanceHuit=65){const c={...combiNeutre(cle),...choix},r=x=>Math.round(x*10)/10;
 if(cle==='lineout_attaque'||cle==='scrum_attaque'){let w=0,g=0,f=0;for(const [pivot] of COMBI_PIVOTS[cle]){const v=combiOption(cle,pivot,c[pivot])?.[2]||[0,0,0];w+=v[0];g+=v[1];f+=v[2]}if(c.sortie==='huit'){const d=puissanceHuit-65;g+=Math.round(clamp(d*.06,-1,1));f+=clamp(d*.0015,-.02,.02)}return [['Conquête',r(w*100),'%',1],['Mètres',r(g),'m',1],['Essai',r(f*100),'%',1]]}
 if(cle==='kickoff_attaque'){const k={normal:[0,0],court:[20,-8],long:[-10,2]}[c.renvoi]||[0,0];return [['Récupération',k[0],'%',1],['Territoire',k[1],'m',1]]}
 if(cle==='lineout_defense'){if(c.contre==='maul')return [['Leur conquête',2,'%',-1],['Leurs mètres',-1,'m',-1],['Leur essai',-4,'%',-1]];const t=COMBI_CONTRE[c.contre];return [['Leur conquête',t?r(COMBI_ROTATION.reduce((a,v)=>a+t[v],0)/COMBI_ROTATION.length*100):0,'%',-1],['Leurs mètres',0,'m',-1],['Leur essai',0,'%',-1]]}
 if(cle==='scrum_defense')return c.poussee==='pousser'?[['Leur conquête',-3,'%',-1],['Pénalités contre nous',6,'%',-1]]:[['Leur conquête',0,'%',-1],['Pénalités contre nous',0,'%',-1]];
 if(cle==='penalty_defense'){const v={vite:[-4,2],mur:[3,-4]}[c.repli]||[0,0];return [['Leur jeu vite',v[0],'%',-1],['Leur pénaltouche',v[1],'%',-1]]}
 if(cle==='kickoff_defense'){const v={avants:[-8,2],profonde:[5,-2]}[c.reception]||[0,0];return [['Leur récupération',v[0],'%',-1],['Leur territoire',v[1],'m',-1]]}
 return []}
// Lecture : une consigne de pénalité figée (pénaltouche, mêlée, jeu vite) est lue par l'adversaire à chaque répétition
// dans le match (n-ième fois : n − 1 répétitions déjà vues). Choix « Selon le score » du staff : jamais lu.
function combiLire(l,side,kind,quoi,fn){if(!combiRules(l))return fn();l.combiLu=l.combiLu||[{},{}];const n=l.combiLu[side][quoi]||0;l.combiLu[side][quoi]=n+1;l.combiLecture={side,kind,n};try{return fn()}finally{delete l.combiLecture}}
// Pénalités de mêlée sur poussée adverse : part des pénalités sifflées pour l'équipe qui introduit.
function combiBiaisMelee(l,side){return combiRules(l)&&combiChoix(l.playbooks[1-side],'scrum_defense').poussee==='pousser'?.06:0}
// Repli adverse contre la pénalité jouée vite.
function combiSurpriseJeuVite(l,side){if(!combiRules(l))return 0;const r=combiChoix(l.playbooks[1-side],'penalty_defense').repli,lu=l.combiLecture?.side===side&&l.combiLecture.kind==='main'?Math.min(3,l.combiLecture.n):0;return (r==='vite'?-.04:r==='mur'?.03:0)-.04*lu}
// Plan de pénalité réglé avant le match : zone (distance à la ligne adverse) → staff, poteaux, touche, mêlée, main.
function combiPlanPenalite(l,side,distance){if(!combiRules(l)||(l.penaltyPolicies?.[side]||'auto')!=='auto')return 'staff';const c=combiChoix(l.playbooks[side],'penalty_attaque');return c[distance<=22?'pres':distance<=40?'portee':'loin']||'staff'}
function kickoffPolicy(l,side,kind){const choice=kind==='kickoff'&&playbookRules(l)?(combiRules(l)?combiChoix(l.playbooks[side],'kickoff_attaque').renvoi:l.playbooks[side].kickoff):'normal';let retain=choice==='court'?.2:choice==='long'?-.1:0,extra=0;
 if(kind==='kickoff'&&combiRules(l)){const r=combiChoix(l.playbooks[1-side],'kickoff_defense').reception;if(r==='avants'){retain-=.08;extra=choice==='court'?0:2}else if(r==='profonde'){retain+=.05;extra=choice==='court'?0:-2}}
 return {choice,distance:choice==='court'?[10,14]:choice==='long'?[18,26]:null,retain,extra,plafond:choice==='court'?.14:0}}
function playbookPanel(l=null){if(l&&!playbookRules(l))return '';const p=l?l.playbooks[l.userSide]:S.manager.playbook,disabled=l&&(!l.paused||l.finished),z=p.zones[playbookZone];return `<section class="card playbook-panel" aria-label="Consignes par zone et phases arrêtées"><div class="cardtitle"><h2>Le carnet de jeu</h2><span class="tag">${l?'EN PAUSE':'PROCHAIN MATCH'}</span></div><p class="help">Les zones sont orientées depuis ton propre en-but. Une consigne locale remplace le plan principal dans cette zone.</p><div class="zone-tabs">${Object.entries(FIELD_ZONES).map(([key,title])=>`<button class="small ${playbookZone===key?'dark':''}" onclick="playbookZone='${key}';render()">${title}</button>`).join('')}</div><div class="playbook-selects">${[['attack','Attaque de la zone',TACTICS],['defence','Défense de la zone',DEFENCES]].map(([key,title,options])=>`<label>${title}<select aria-label="${title}" ${disabled?'disabled':''} onchange="setPlaybookChoice('${key}',this.value)"><option value="inherit">Suivre le plan principal</option>${Object.entries(options).map(([value,[name]])=>`<option value="${value}" ${z[key]===value?'selected':''}>${name}</option>`).join('')}</select></label>`).join('')}</div><p class="help">${z.attack==='inherit'?'Attaque : plan principal.':TACTICS[z.attack][1]} ${z.defence==='inherit'?'Défense : plan principal.':DEFENCES[z.defence][1]}</p><h3>Les phases arrêtées</h3><div class="playbook-selects">${[['scrum','Sur tes mêlées',SCRUM_MOVES],['lineout','Sur tes touches',LINEOUT_MOVES],['kickoff','Tes renvois au centre',KICKOFF_MOVES]].map(([key,title,options])=>`<label>${title}<select aria-label="${title}" ${disabled?'disabled':''} onchange="setPlaybookChoice('${key}',this.value)">${Object.entries(options).map(([value,[name]])=>`<option value="${value}" ${p[key]===value?'selected':''}>${name}</option>`).join('')}</select><small>${options[p[key]][1]}</small></label>`).join('')}</div><p class="help">Les procédures réglementaires restent prioritaires : aucun effet de poussée sur une mêlée non disputée. Les placements 2D restent schématiques.</p>${l?fourZoneTacticalPanel(l):''}</section>`}
function playbookView(){return heading('VOTRE IDENTITÉ RUGBY','Le plan de jeu.','Adapte ton approche aux zones du terrain et prépare les phases arrêtées.')+playbookPanel()+`<div class="notice">Ces choix s’appliquent au prochain match. En rencontre, tu peux les ajuster dans les consignes pendant une pause.</div><button class="primary" style="margin-top:18px" onclick="nav('match')">Préparer la rencontre →</button>`}
