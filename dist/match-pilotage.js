// Pilotage du match façon FM (docs/match-pilotage-20261118.md) : arbitre au profil connu, consignes en direct,
// état des joueurs après les causeries, choix du staff quand le match lui est confié.
// L'entraîneur adverse fait lui aussi ses causeries (avant-match, mi-temps) et règle ses consignes toutes les 5 minutes.
// Ne concerne que le match du joueur en carrière Monde créé avec `pilotageVersion` (rugbyBegin) : les matchs IA
// et les rencontres créées avant gardent leurs règles. Aucun tirage aléatoire ajouté : la suite des tirages est
// inchangée, seules les probabilités bougent. Coefficients choisis pour le jeu (ordres de grandeur), non mesurés.
var PILOTAGE_RULES=1;

// Corps arbitral fictif (aucun vrai nom), arbitres femmes comprises (`f`). Sévérités de 1 (laisse jouer) à 5 (très pointilleux), 3 = neutre.
const ARBITRES=[
 {id:'castaing',nom:'Julien Castaing',pays:'FR',rucks:4,melee:3,horsJeu:3,cartons:2},
 {id:'dubernet',nom:'Florian Dubernet',pays:'FR',rucks:2,melee:4,horsJeu:3,cartons:3},
 {id:'peyregne',nom:'Yannick Peyrègne',pays:'FR',rucks:3,melee:2,horsJeu:4,cartons:4},
 {id:'saint-criq',nom:'Olivier Saint-Criq',pays:'FR',rucks:5,melee:3,horsJeu:2,cartons:3},
 {id:'escaich',nom:'Marine Escaich',f:true,pays:'FR',rucks:3,melee:5,horsJeu:3,cartons:2},
 {id:'larrouturou',nom:'Rémi Larrouturou',pays:'FR',rucks:2,melee:2,horsJeu:3,cartons:3},
 {id:'coustal',nom:'Damien Coustal',pays:'FR',rucks:4,melee:3,horsJeu:4,cartons:5},
 {id:'bergeyre',nom:'Hugo Bergeyre',pays:'FR',rucks:3,melee:3,horsJeu:2,cartons:2},
 {id:'arrouy',nom:'Sébastien Arrouy',pays:'FR',rucks:2,melee:4,horsJeu:4,cartons:3},
 {id:'mazars',nom:'Pierre-Louis Mazars',pays:'FR',rucks:4,melee:2,horsJeu:3,cartons:4},
 {id:'claverie',nom:'Aurore Clavérie',f:true,pays:'FR',rucks:3,melee:4,horsJeu:2,cartons:3},
 {id:'soubiron',nom:'Mathieu Soubiron',pays:'FR',rucks:3,melee:3,horsJeu:5,cartons:2},
 {id:'pritchard',nom:'Owen Pritchard-Lloyd',pays:'GB',rucks:4,melee:3,horsJeu:3,cartons:3},
 {id:'strachan',nom:'Isla Strachan',f:true,pays:'GB',rucks:2,melee:3,horsJeu:4,cartons:2},
 {id:'furlong',nom:'Declan Furlong',pays:'IE',rucks:3,melee:2,horsJeu:3,cartons:4},
 {id:'whitcombe',nom:'Harry Whitcombe',pays:'GB',rucks:5,melee:4,horsJeu:3,cartons:3},
 {id:'ferrandi',nom:'Giacomo Ferrandi',pays:'IT',rucks:3,melee:4,horsJeu:2,cartons:3},
 {id:'rawiri',nom:'Tane Rāwiri',pays:'NZ',rucks:2,melee:2,horsJeu:4,cartons:2},
 {id:'oosthuysen',nom:'Riaan Oosthuysen',pays:'ZA',rucks:4,melee:5,horsJeu:3,cartons:3},
 {id:'pettigrew',nom:'Lachlan Pettigrew',pays:'AU',rucks:3,melee:3,horsJeu:3,cartons:4},
 {id:'morishima',nom:'Kenta Morishima',pays:'JP',rucks:4,melee:2,horsJeu:5,cartons:3},
 {id:'iturraspe',nom:'Tomás Iturraspe',pays:'AR',rucks:2,melee:4,horsJeu:2,cartons:4},
 {id:'kiknavelidze',nom:'Davit Kiknavelidze',pays:'GE',rucks:3,melee:5,horsJeu:3,cartons:2},
 {id:'hallworth',nom:'Tom Hallworth',pays:'GB',rucks:2,melee:3,horsJeu:3,cartons:5}
];
// Viviers par compétition : arbitres français pour les championnats français, étrangers ailleurs.
const ARBITRES_VIVIERS={elite:['FR'],accession:['FR'],nationale:['FR'],prem:['GB'],champ:['GB'],urc:['GB','IE','IT','ZA'],srp:['NZ','AU','ZA','AR'],'jlo-d1':['JP','NZ','AU'],'jlo-d2':['JP','NZ','AU']};
const ARBITRE_AXES=[['rucks','les rucks'],['melee','la mêlée'],['horsJeu','le hors-jeu'],['cartons','les cartons']];
function pilotageHash(x){let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0}
function arbitreDuMatch(fixtureId,competitionId){
 const pays=ARBITRES_VIVIERS[competitionId];
 // Coupes d'Europe et compétitions internationales : arbitres étrangers à la France.
 const vivier=ARBITRES.filter(a=>pays?pays.includes(a.pays):a.pays!=='FR');
 const a=(vivier.length?vivier:ARBITRES)[pilotageHash('arbitre:'+fixtureId)%(vivier.length||ARBITRES.length)];
 return {...a,civilite:a.f?'Mme':'M.',resume:arbitreResume(a)};
}
function arbitreResume(a){
 const severe=ARBITRE_AXES.filter(([k])=>a[k]>=4).map(([,t])=>t),souple=ARBITRE_AXES.filter(([k])=>a[k]<=2).map(([,t])=>t);
 const liste=x=>x.length>1?x.slice(0,-1).join(', ')+' et '+x.at(-1):x[0];
 const parts=[];
 if(severe.length)parts.push((a.f?'Pointilleuse':'Pointilleux')+' sur '+liste(severe));
 if(souple.length)parts.push((parts.length?'laisse vivre ':'Laisse vivre ')+liste(souple));
 return parts.length?parts.join(', ')+'.':'Arbitrage équilibré, sans manie particulière.';
}
// Facteur multiplicatif d'une sévérité (3 = neutre).
const pilSev=(s,k)=>1+k*((Number(s)||3)-3);

// Consignes en direct, rangées comme les phases du jeu (attaque, défense, conquête, adversaire), sur le modèle des
// consignes par phase de FM26/FM27. Trois crans par axe ; `neutre` = le cran sans effet (le cran du milieu sauf mention).
// Libellés courts : la fenêtre Équipe doit rester lisible en 1280×720.
const CONSIGNES_GROUPES=[['attaque','Attaque'],['defense','Défense'],['conquete','Conquête'],['adversaire','Adversaire']];
const CONSIGNES={
 piedJeu:{groupe:'attaque',label:'Jeu au pied',aide:'Garder le ballon en main ou occuper le terrain.',valeurs:[['moins','Garder'],['normal','Équilibré'],['plus','Occuper']]},
 rythme:{groupe:'attaque',label:'Rythme',aide:'Accélérer use plus vite et fait perdre plus de ballons.',valeurs:[['lent','Ralentir'],['normal','Normal'],['rapide','Accélérer']]},
 relance:{groupe:'attaque',label:'Relance',aide:'Depuis notre camp : dégager au pied ou relancer à la main.',valeurs:[['degager','Dégager'],['selon','Selon'],['relancer','Relancer']]},
 finDeMatch:{groupe:'attaque',label:'Fin de match',aide:'À partir de la 70e : jouer la montre ou tout tenter.',valeurs:[['montre','Jouer la montre'],['normal','Normal'],['tout','Tout tenter']]},
 rucks:{groupe:'defense',label:'Rucks',aide:'Contester chaque ruck arrache des ballons mais coûte des pénalités.',valeurs:[['prudente','Prudence'],['normale','Normale'],['agressive','Contester']]},
 discipline:{groupe:'defense',label:'Discipline',aide:'Zéro faute défend moins fort ; à la limite, l’arbitre veille.',valeurs:[['stricte','Zéro faute'],['normale','Normale'],['limite','À la limite']]},
 touche:{groupe:'conquete',label:'Touche',aide:'Lancer court et sûr, ou fond d’alignement pour une meilleure plateforme.',valeurs:[['sure','Sûre'],['normale','Normale'],['risquee','Risquée']]},
 maul:{groupe:'conquete',label:'Ballon porté',aide:'Après une touche gagnée près de leur ligne.',valeurs:[['jamais','Jamais'],['selon','Selon'],['souvent','Souvent']]},
 melee:{groupe:'conquete',label:'Mêlée',aide:'Pousser pour la pénalité : plus de coups de sifflet, pour ou contre nous.',valeurs:[['vite','Sortir vite'],['normale','Normale'],['pousser','Pousser']]},
 coupsEnvoi:{groupe:'conquete',label:'Coups d’envoi',aide:'Courts pour récupérer le ballon, longs pour occuper.',valeurs:[['longs','Longs'],['normaux','Normaux'],['courts','Courts']]},
 cible:{groupe:'adversaire',label:'Point faible',aide:'L’adversaire s’adapte en 20 à 30 minutes et lit le jeu ; sans vrai point faible, on perd plus qu’on ne gagne.',neutre:'aucune',valeurs:[['aucune','Aucun'],['aile','Leur aile faible'],['ouvreur','Presser l’ouvreur']]}
};
const CONSIGNES_NEUTRES=Object.fromEntries(Object.entries(CONSIGNES).map(([k,c])=>[k,c.neutre||c.valeurs[1][0]]));
function consigneLabel(axe,valeur){return CONSIGNES[axe]?.valeurs.find(v=>v[0]===valeur)?.[1]||valeur}
// Plan de jeu d'avant le match, réglable aussi dans la fenêtre Équipe (match en pause) : mêmes commandes qu'avant.
const CONSIGNES_PLAN={
 planAttaque:{groupe:'attaque',label:'Plan de jeu',aide:'Le style d’attaque de l’équipe.'},
 systemeDefense:{groupe:'defense',label:'Système',aide:'Montée agressive ou glissée prudente.'},
 penalites:{groupe:'conquete',label:'Pénalités',aide:'Ce que fait le capitaine sur une pénalité obtenue.'}
};
function planOptions(axe){
 if(axe==='planAttaque'&&typeof TACTICS!=='undefined')return Object.entries(TACTICS).map(([id,t])=>({id,label:t[0]}));
 if(axe==='systemeDefense'&&typeof DEFENCES!=='undefined')return Object.entries(DEFENCES).map(([id,t])=>({id,label:t[0]}));
 if(axe==='penalites'&&typeof PENALTY_POLICIES!=='undefined')return Object.entries(PENALTY_POLICIES).map(([id,t])=>({id,label:t}));
 return [];
}
function planValeur(l,axe){
 const u=l.userSide;
 return axe==='planAttaque'?l.tactics?.[u]:axe==='systemeDefense'?(l.defences?.[u]||'equilibre'):(l.penaltyPolicies?.[u]||'auto');
}
// Applique un réglage du plan de jeu (match en pause, comme avant) ; rend vrai si la valeur est prise.
function setPlan(l,axe,valeur){
 if(axe==='planAttaque'&&typeof setLiveTactic==='function')setLiveTactic(valeur);
 else if(axe==='systemeDefense'&&typeof setLiveDefence==='function')setLiveDefence(valeur);
 else if(axe==='penalites'&&typeof setPenaltyPolicy==='function')setPenaltyPolicy(valeur);
 else return false;
 return planValeur(l,axe)===valeur;
}

// États des joueurs après une causerie : bonus en points d'attribut pendant le match.
// `tous` s'applique à chaque geste ; les autres clés s'ajoutent pour ce geste précis.
const PILOTAGE_ETATS={
 galvanise:{label:'Galvanisé',tous:4,discipline:-3},
 motive:{label:'Motivé',tous:2},
 serein:{label:'Serein',tous:1,discipline:2,goal:2,lineout:1},
 indifferent:{label:'Indifférent',tous:0},
 tendu:{label:'Tendu',tous:-2,goal:-4,lineout:-3,pass:-2},
 vexe:{label:'Vexé',tous:-2,discipline:-8},
 relache:{label:'Relâché',tous:-3,tackle:-2}
};

function pilotageActif(l){return !!(l&&l.pilotageVersion===1&&l.pilotage)}
function initPilotage(l){
 if(!PILOTAGE_RULES||!l||!l.worldContext||!(l.userSide>=0)||l.pair[l.userSide]!==S.club)return;
 l.pilotageVersion=1;
 l.pilotage={arbitre:arbitreDuMatch(l.worldContext.id,l.worldContext.competitionId),consignes:{...CONSIGNES_NEUTRES},depuis:{},releves:{},etats:{},journal:[],staffMinute:-1,
  // Banc adverse : ses consignes (côté non joué) et sa mémoire (niveau du staff, tons déjà employés, derniers changements).
  consignesAdverses:{...CONSIGNES_NEUTRES},adversaire:{niveau:niveauAdverse(l),minute:-1,releve:null,tons:[],causeries:{},derniers:[]}};
}
// Relevé des chiffres utiles du club joué, pour mesurer l'effet d'une consigne depuis son changement.
function pilotageReleve(l,u=l.userSide){
 const o=1-u,s=l.stats[u],t=l.tacticalStats?.[u]||{},to=l.tacticalStats?.[o]||{};
 return {minute:l.minute,penalites:s.penalties||0,cartons:(s.yellows||0)+(s.reds||0),coups:t.kicks||0,porteurs:t.carries||0,avancees:t.advances||0,metres:t.metres||0,
  pertes:t.handErrors||0,arraches:to.handErrors||0,touches:s.lineouts||0,touchesGagnees:s.lineoutsWon||0,penalitesAdverses:l.stats[o].penalties||0,
  melees:s.scrums||0,meleesGagnees:s.scrumsWon||0,points:l.score[u]||0,encaisses:l.score[o]||0,essais:l.tries?.[u]||0,ev:l.events?.length||0};
}
function setConsigne(l,axe,valeur,auteur='manager'){
 if(!pilotageActif(l)||l.finished)return false;
 const c=CONSIGNES[axe];if(!c||!c.valeurs.some(v=>v[0]===valeur))return false;
 if(l.pilotage.consignes[axe]===valeur)return true;
 l.pilotage.consignes[axe]=valeur;l.pilotage.depuis[axe]=l.minute;l.pilotage.releves[axe]=pilotageReleve(l);
 if(auteur==='staff')l.pilotage.journal.push({minute:l.minute,auteur,texte:`Le staff passe « ${c.label} » sur « ${consigneLabel(axe,valeur)} ».`});
 l.pilotage.journal=l.pilotage.journal.slice(-30);
 return true;
}
// Consigne d'une équipe : celle du manager pour le club joué, celle du banc adverse sinon (absente des rencontres
// créées avant : aucun effet, comme avant).
// Match entre deux clubs de l'ordinateur : chaque banc a ses propres consignes (`cotes`).
const pilConsigne=(l,side,axe)=>!pilotageActif(l)?null:l.pilotage.cotes?l.pilotage.cotes[side]?.consignes[axe]??null:side===l.userSide?l.pilotage.consignes[axe]:l.pilotage.consignesAdverses?.[axe]??null;
// Ce que le manager voit changer chez l'adversaire (le jeu sur le terrain, pas un ordre entendu).
const CONSIGNES_ADVERSES_VUES={
 piedJeu:{moins:'garde le ballon en main',normal:'revient à un jeu au pied équilibré',plus:'occupe le terrain au pied'},
 rucks:{prudente:'ne conteste plus les rucks',normale:'conteste les rucks normalement',agressive:'conteste chaque ruck'},
 discipline:{stricte:'resserre sa discipline',normale:'relâche un peu sa discipline',limite:'joue à la limite'},
 rythme:{lent:'ralentit le jeu',normal:'revient à un rythme normal',rapide:'accélère le rythme'},
 touche:{sure:'assure ses lancers en touche',normale:'varie ses lancers en touche',risquee:'vise le fond d\'alignement'},
 finDeMatch:{montre:'joue la montre',normal:'revient à un jeu normal',tout:'tente le tout pour le tout'}
};
function nomAdverse(l){return S?.clubs?.[l.pair[1-l.userSide]]?.name||'L\'adversaire'}
function setConsigneAdverse(l,axe,valeur){
 if(!pilotageActif(l)||l.finished||!l.pilotage.consignesAdverses)return false;
 const c=CONSIGNES[axe];if(!c||!c.valeurs.some(v=>v[0]===valeur))return false;
 if(l.pilotage.consignesAdverses[axe]===valeur)return true;
 l.pilotage.consignesAdverses[axe]=valeur;
 const texte=`${nomAdverse(l)} ${CONSIGNES_ADVERSES_VUES[axe][valeur]}.`,adv=l.pilotage.adversaire;
 if(adv)adv.derniers=[...(adv.derniers||[]),{minute:l.minute,axe,valeur,label:consigneLabel(axe,valeur),texte}].slice(-10);
 l.pilotage.journal.push({minute:l.minute,auteur:'adversaire',texte});
 l.pilotage.journal=l.pilotage.journal.slice(-30);
 return true;
}


// --- Effets dans le moteur (appelés depuis rugby.js, restarts.js, tactical-plans.js) ---
// Rôles du poste et consignes individuelles du manager (native/engine/match-arrets.cjs, CDMatchArrets.effets) :
// absents de la version web et des matchs sans pilotage (effet nul).
const pilIndiv=()=>typeof CDMatchArrets!=='undefined'?CDMatchArrets.effets:null;
// Probabilité de faute de l'équipe `fautif` : 'jeu' (en défense : hors-jeu, rucks), 'attaque' (ballon non libéré).
function pilotageFoul(l,fautif,kind){
 if(!pilotageActif(l))return 1;
 const a=l.pilotage.arbitre;let f=kind==='attaque'?pilSev(a.rucks,.08):pilSev(a.horsJeu,.04)*pilSev(a.rucks,.04);
 const r=pilConsigne(l,fautif,'rucks'),d=pilConsigne(l,fautif,'discipline'),y=pilConsigne(l,fautif,'rythme');
 if(kind==='jeu'){
  // Contester chaque ruck coûte plus cher devant un arbitre pointilleux sur les rucks.
  if(r==='agressive')f*=1+.22*pilSev(a.rucks,.2);else if(r==='prudente')f*=.85;
  if(d==='stricte')f*=.78;else if(d==='limite')f*=1.2;
  f*=pilIndiv()?.foul(l,fautif,kind)??1;
 }else{
  if(y==='rapide')f*=1.15;else if(y==='lent')f*=.9;
  if(d==='stricte')f*=.85;else if(d==='limite')f*=1.1;
  if(finDeMatch(l,fautif)==='montre')f*=.9;
 }
 // Presser leur ouvreur : quelques plaquages en retard sifflés contre nous.
 if(kind==='jeu'&&pilConsigne(l,fautif,'cible')==='ouvreur')f*=1+.06*cibleForce(l,fautif);
 return f;
}
function pilotageScrumPenalty(l){return pilotageActif(l)?pilSev(l.pilotage.arbitre.melee,.12):1}
function pilotageCard(l){return pilotageActif(l)?pilSev(l.pilotage.arbitre.cartons,.2):1}
// Ballons perdus par l'attaquant `side` (en-avant, ballon arraché).
function pilotageHandFault(l,side){
 if(!pilotageActif(l))return 0;
 const y=pilConsigne(l,side,'rythme'),r=pilConsigne(l,1-side,'rucks'),d=pilConsigne(l,1-side,'discipline');
 const rel=enCampPropre(l,side)?pilConsigne(l,side,'relance'):null,f=finDeMatch(l,side),c=pilConsigne(l,1-side,'cible');
 return (y==='rapide'?.02:y==='lent'?-.015:0)+(r==='agressive'?.025:r==='prudente'?-.01:0)+(d==='limite'?.01:d==='stricte'?-.005:0)
  +(rel==='relancer'?.012:0)+(f==='montre'?-.025:f==='tout'?.025:0)
  // Presser leur ouvreur : plus de ballons perdus chez l'attaquant, tant qu'il ne s'est pas adapté.
  +(c==='ouvreur'?.014*cibleForce(l,1-side):0)
  // Consignes individuelles et rôles : ballons perdus en attaque, ou arrachés par nos gratteurs.
  +(pilIndiv()?.hand(l,side)??0);
}
// Avantage du porteur `side` (kind 'attack') : rythme, pression adverse sur les rucks, plateforme de touche.
function pilotageEdge(l,side,kind){
 if(!pilotageActif(l)||kind!=='attack')return 0;
 const y=pilConsigne(l,side,'rythme'),r=pilConsigne(l,1-side,'rucks'),d=pilConsigne(l,1-side,'discipline'),p=l.pilotage.plateforme;
 const rel=enCampPropre(l,side)?pilConsigne(l,side,'relance'):null,f=finDeMatch(l,side),c=pilConsigne(l,side,'cible');
 return (y==='rapide'?.02:y==='lent'?-.02:0)+(r==='agressive'?-.012:r==='prudente'?.012:0)+(d==='stricte'?.012:d==='limite'?-.008:0)+(p&&p.side===side&&l.minute-p.minute<=1?.05:0)
  +(rel==='relancer'?.022:0)+(f==='montre'?-.012:f==='tout'?.025:0)
  // Attaquer leur aile la plus faible : voir AILE_FAIBLE.
  +(c==='aile'?aileEdge(l,side):0)
  // Consignes individuelles et rôles (attaque, ou défense du camp d'en face).
  +(pilIndiv()?.edge(l,side)??0);
}
// Notre camp (là où « Relance » joue) et fin de match (dès la 70e) pour le côté `side`.
function enCampPropre(l,side){return side===0?l.territory<50:l.territory>50}
function finDeMatch(l,side){const f=pilConsigne(l,side,'finDeMatch');return l.minute>=70&&f&&f!=='normal'?f:null}
// Effet d'un point faible visé : plein au début, nul 30 minutes après (l'adversaire corrige).
function cibleForce(l,side){const d=side===l.userSide?l.pilotage.depuis?.cible:null;return Number.isFinite(d)?Math.max(0,1-(l.minute-d)/30):1}
// « Leur aile faible » (19/11/2026). Avant : l'ailier le plus faible comparé à toute la ligne (avants compris, meilleurs
// plaqueurs), donc un bonus presque toujours au plafond (+0,035) même face à une aile solide, et nul 30 minutes après :
// ≈ 0,3 point par match sur 400 matchs. Désormais l'ailier est comparé au reste de leurs trois-quarts (10 à 15) :
// - `seuil` : points de plaquage de retard sur ses voisins avant qu'il y ait quelque chose à exploiter ;
// - `parPoint`, `max` : avantage d'attaque (réussite des temps de jeu et finition) par point au-delà, plafonné ;
// - `metres` : mètres en plus par temps de jeu réussi (débordements sur son côté), à pleine force ;
// - `adaptation` : minutes pour que l'adversaire corrige (glissement de sa couverture) ; `residuel` : ce qui reste
//   ensuite, un ailier faible le restant ;
// - `previsible` : coût d'une attaque qui va toujours du même côté, à mesure que l'adversaire la lit (nul au départ,
//   plein une fois adapté) ; sans aile faible à viser, il ne reste que ce coût.
// Valeurs de jeu, étalonnées dans tests/match-pilotage.cjs (400 matchs, mêmes graines).
const AILE_FAIBLE=Object.freeze({seuil:2,parPoint:.015,max:.09,metres:5,adaptation:30,residuel:.35,previsible:.015});
// Retard au plaquage de leur ailier le plus faible sur le reste de leurs trois-quarts en jeu (0 si aucun ailier).
function aileEcart(l,defenseur){
 if(typeof activePlayers!=='function')return 0;
 const on=l.sheets[defenseur].on,arrieres=activePlayers(l,defenseur).filter(p=>{const n=on.indexOf(p.id)+1;return n>=10&&n<=15});
 const ailes=arrieres.filter(p=>[11,14].includes(on.indexOf(p.id)+1));
 if(!ailes.length)return 0;
 const faible=ailes.reduce((a,p)=>skill(p,'tackle')<skill(a,'tackle')?p:a),autres=arrieres.filter(p=>p!==faible);
 if(!autres.length)return 0;
 return autres.reduce((n,p)=>n+skill(p,'tackle'),0)/autres.length-skill(faible,'tackle');
}
// Avantage d'exploitation (avant le coût), à pleine force.
function aileFaible(l,defenseur){const A=AILE_FAIBLE;return clamp((aileEcart(l,defenseur)-A.seuil)*A.parPoint,0,A.max)}
// Part de l'effet encore exploitable : pleine au choix de la consigne, `residuel` une fois l'adversaire adapté.
function aileForce(l,side){const d=side===l.userSide?l.pilotage.depuis?.cible:null,A=AILE_FAIBLE;return Number.isFinite(d)?Math.max(A.residuel,1-(l.minute-d)/A.adaptation):1}
function aileEdge(l,side){const f=aileForce(l,side);return aileFaible(l,1-side)*f-AILE_FAIBLE.previsible*(1-f)/(1-AILE_FAIBLE.residuel)}
// Mètres en plus d'un temps de jeu réussi par `side` (tactical-plans.js, carryGain).
function pilotageGain(l,side){
 if(!pilotageActif(l))return 0;
 const indiv=pilIndiv()?.gain(l,side)??0;
 if(pilConsigne(l,side,'cible')!=='aile')return indiv;
 const A=AILE_FAIBLE,f=aileForce(l,side);return indiv+(aileFaible(l,1-side)>0?Math.round(A.metres*f):0);
}
function pilotageKick(l,side){
 const k=pilConsigne(l,side,'piedJeu'),y=pilConsigne(l,side,'rythme'),rel=enCampPropre(l,side)?pilConsigne(l,side,'relance'):null,f=finDeMatch(l,side);
 return (k==='moins'?.55:k==='plus'?1.55:1)*(y==='lent'?1.1:1)*(rel==='degager'?1.4:rel==='relancer'?.6:1)*(f==='montre'?.6:f==='tout'?.8:1)*(pilIndiv()?.kick(l,side)??1);
}
// Ballon porté après une touche gagnée près de leur ligne : chance d'essai (rugby.js, contestSetPiece).
function pilotageMaul(l,side,kind){
 if(kind!=='lineout')return 0;const m=pilConsigne(l,side,'maul');
 return (m==='souvent'?.07:m==='jamais'?-.08:0)+(pilIndiv()?.maul(l,side)??0);
}
// Mêlée : « Pousser » fait siffler plus souvent et penche vers le pack dominant ; « Sortir vite » apaise la mêlée.
// Rend {freq, biais} pour la mêlée introduite par `side` (tactical-plans.js, penaliteConquete) ; `a`, `b` : packs.
function pilotageMelee(l,side,a,b){
 if(!pilotageActif(l))return {freq:1,biais:0};
 if(!(l.userSide>=0))return {freq:1,biais:0};
 const u=l.userSide,m=pilConsigne(l,u,'melee'),dom=(side===u?a-b:b-a),indiv=pilIndiv()?.melee(l,side)??0;
 if(m==='pousser')return {freq:1.5,biais:(side===u?1:-1)*Math.max(-.15,Math.min(.15,dom*.012))+indiv};
 if(m==='vite')return {freq:.65,biais:indiv};
 return {freq:1,biais:indiv};
}
// Mêlée gagnée en sortant vite : meilleure plateforme pour l'action suivante (comme la touche risquée).
function pilotageScrumWon(l,side){if(pilConsigne(l,side,'melee')==='vite')l.pilotage.plateforme={side,minute:l.minute}}
// Coups d'envoi : {distance (facteur), garde (probabilité ajoutée de récupérer le ballon)} pour l'équipe qui botte.
function pilotageRenvoi(l,team){
 const c=pilConsigne(l,team,'coupsEnvoi');
 return c==='courts'?{distance:.6,garde:.12}:c==='longs'?{distance:1.45,garde:-.07}:{distance:1,garde:0};
}
function pilotageLineout(l,side){const t=pilConsigne(l,side,'touche');return (t==='sure'?.06:t==='risquee'?-.06:0)+(pilIndiv()?.lineout(l,side)??0)}
// Touche gagnée en fond d'alignement : meilleure plateforme pour l'action suivante.
function pilotageLineoutWon(l,side){if(pilConsigne(l,side,'touche')==='risquee')l.pilotage.plateforme={side,minute:l.minute}}

// Bonus d'attribut d'un joueur du club joué selon son état (causerie) et le cri de la touche en cours.
// Lu à chaque geste : cache par état et par cri.
let PILOTAGE_CACHE={src:null,cri:null,mods:null,ids:null};
// Match en train de jouer sa minute (pilotageMinute) : un match de l'ordinateur simulé pendant le direct du joueur
// (multiplex) lit les états de ses propres joueurs, pas ceux du direct.
let PILOTAGE_EN_COURS=null;
function pilotageSkillMod(p,k){
 const l=PILOTAGE_EN_COURS||(typeof S!=='undefined'&&S?S.live:null);
 if(!l||l.pilotageVersion!==1||!l.pilotage)return 0;
 const etats=l.pilotage.etats,cri=l.pilotage.cri||null;
 if(PILOTAGE_CACHE.src!==etats||PILOTAGE_CACHE.cri!==cri){
  const mods=new Map();
  for(const [id,e] of Object.entries(etats||{})){const d=PILOTAGE_ETATS[e?.etat];if(d)mods.set(id,d)}
  PILOTAGE_CACHE={src:etats,cri,mods,ids:cri?new Set(cri.ids):null};
 }
 const d=PILOTAGE_CACHE.mods.get(p.id);
 let n=d?d.tous+(d[k]||0):0;
 // Moral en match : l'écart à son départ, ±2 points au plus.
 const m=l.pilotage.moral?.joueurs?.[p.id];if(m)n+=moralEffet(m.v,m.ref??m.depart);
 if(cri&&l.minute<cri.jusqua&&PILOTAGE_CACHE.ids.has(p.id)){
  const c=CRIS[cri.id];
  if(c.apaise&&d&&d.tous<0)n=0;
  n+=Math.round(((c.tous||0)+(c[k]||0))*cri.force);
 }
 // Cri individuel du banc (bien ou mal pris).
 if(l.pilotage.crisJoueurs)n+=criJoueurMod(l,p,k);
 // Rôle du poste et consignes individuelles (club joué, match du manager seulement).
 if(l===(typeof S!=='undefined'&&S?S.live:null))n+=pilIndiv()?.skill(p,k)??0;
 return n;
}

// --- Cris de la touche : un mot au groupe en plein match, effet court qui s'use si on le répète ---
// Points d'attribut pour les joueurs sur le terrain au moment du cri ; `apaise` efface un état négatif (Tendu, Vexé).
const CRIS={
 encourager:{label:'Encourager',note:'Rassure les joueurs tendus',duree:8,tous:1,apaise:true},
 exiger:{label:'Exiger',note:'Plus d’intensité, un peu moins de lucidité',duree:8,tous:2,discipline:-3},
 calmer:{label:'Calmer',note:'Moins de fautes, apaise les vexés',duree:10,discipline:6,apaise:true},
 defense:{label:'Serrer la défense',note:'Plaquages plus sûrs, moins de jeu',duree:10,tackle:4,pass:-2},
 toutDonner:{label:'Tout donner',note:'Pour la fin de match : use les organismes',duree:10,tous:3,des:65,fatigue:1.15}
};
function criForce(l,id){
 // Usure : le même cri dans les 20 dernières minutes porte moitié moins, une troisième fois plus du tout.
 const n=(l.pilotage.cris||[]).filter(x=>x.id===id&&l.minute-x.minute<20).length;
 return n===0?1:n===1?.5:0;
}
function crier(l,id){
 if(!pilotageActif(l)||l.finished)return false;
 const c=CRIS[id];if(!c||l.minute<(c.des||0))return false;
 const force=criForce(l,id),ids=activePlayers(l,l.userSide).map(p=>p.id);
 l.pilotage.cri={id,minute:l.minute,jusqua:l.minute+c.duree,force,ids};
 l.pilotage.cris=[...(l.pilotage.cris||[]),{id,minute:l.minute}].slice(-12);
 return true;
}
function pilotageCrisProjection(l){
 const c=l.pilotage.cri,actif=c&&l.minute<c.jusqua?{id:c.id,label:CRIS[c.id].label,jusqua:c.jusqua,force:c.force}:null;
 return {actif,options:Object.entries(CRIS).map(([id,x])=>{const f=criForce(l,id),tot=l.minute>=(x.des||0);
  return {id,label:x.label,note:!tot?'À partir de la '+x.des+'e minute':f===1?x.note:f===.5?'Déjà crié : effet réduit de moitié':'Trop répété : ils n’écoutent plus',disponible:tot&&!l.finished,usure:1-f}}),individuels:pilotageCrisJoueurProjection(l)};
}
// --- Cris à un joueur (idée FM27 n° 34, choix de Léo du 23/11/2026) ---
// Un mot du banc à un joueur sur le terrain. Bien pris : un coup de fouet court (points d'attribut pendant `duree`
// minutes) et du moral ; mal pris : l'inverse. Rien n'est chiffré à l'écran (principe d'incertitude) : la réaction se
// découvre après coup (sens 1 bien pris, -1 mal pris, 0 il n'écoute plus). Part de hasard tirée de l'empreinte du match
// (pilotageHash) : la suite des tirages Math.random reste inchangée.
// `ok` : chance d'être bien pris selon son moral du moment (palier) ; CRIS_JOUEUR_ETATS la corrige selon son état
// d'après causerie, et son mental compte un peu. `bien` / `mal` : `tous` et points par geste, `moral` (points de moral).
// Usure : un joueur déjà interpellé dans les 15 dernières minutes écoute moitié moins, une troisième fois plus du tout ;
// le banc qui crie sans arrêt s'use aussi (dès 4 cris individuels en 10 minutes : moitié moins, dès 6 : plus rien).
// Valeurs de jeu étalonnées dans tests/match-cris-joueur.cjs (lots de matchs, mêmes graines : effet sur les victoires
// négligeable, même en criant toutes les 3 minutes).
const CRIS_JOUEUR={
 bravo:{label:'Bien joué',duree:6,ok:{gonfle:.5,confiant:.7,concentre:.8,inquiet:.9,abattu:.85},bien:{tous:1,moral:6},mal:{tous:-1,moral:-1}},
 niveau:{label:'Hausse le niveau',duree:8,ok:{gonfle:.75,confiant:.7,concentre:.6,inquiet:.35,abattu:.25},bien:{tous:2,moral:2},mal:{tous:-1,moral:-6}},
 reveil:{label:'Réveille-toi',duree:8,ok:{gonfle:.3,confiant:.45,concentre:.55,inquiet:.4,abattu:.5},bien:{tous:3,moral:-1},mal:{tous:-1,discipline:-6,moral:-5}}
};
const CRIS_JOUEUR_ETATS={relache:{reveil:.25,bravo:-.1},indifferent:{reveil:.15},tendu:{bravo:.1,niveau:-.15,reveil:-.15},vexe:{reveil:-.2,bravo:.05},galvanise:{reveil:-.2,niveau:.05}};
const CRIS_JOUEUR_USURE=Object.freeze({joueur:15,banc:10,bancMoitie:4,bancMuet:6});
function criJoueurForce(l,id){
 const log=l.pilotage.crisJoueursLog||[],U=CRIS_JOUEUR_USURE;
 const n=log.filter(x=>x.id===id&&l.minute-x.minute<U.joueur).length,b=log.filter(x=>l.minute-x.minute<U.banc).length;
 return (n===0?1:n===1?.5:0)*(b>=U.bancMuet?0:b>=U.bancMoitie?.5:1);
}
function crierJoueur(l,id,cri){
 if(!pilotageActif(l)||l.finished)return false;
 const c=CRIS_JOUEUR[cri],u=l.userSide;if(!c)return false;
 const p=activePlayers(l,u).find(x=>x.id===id);if(!p)return false;
 const force=criJoueurForce(l,id),log=l.pilotage.crisJoueursLog||[];
 const m=l.pilotage.moral?.joueurs?.[id],palier=moralPalier(m?m.v:moralDepart(l,id))[1],etat=l.pilotage.etats?.[id]?.etat;
 const chance=Math.max(.1,Math.min(.95,(c.ok[palier]??.6)+(CRIS_JOUEUR_ETATS[etat]?.[cri]||0)+((typeof skill==='function'?skill(p,'mental'):60)-60)*.004));
 const tirage=pilotageHash(['crijoueur',l.worldContext?.id??'',(l.pair||[]).join('-'),id,cri,Math.floor(l.minute),log.length].join('|'))/4294967296;
 const sens=force===0?0:tirage<chance?1:-1,e=sens>0?c.bien:sens<0?c.mal:{};
 const fiche={cri,minute:l.minute,jusqua:l.minute+c.duree,sens};
 for(const [k,v] of Object.entries(e))if(k!=='moral')fiche[k]=v*force;
 if(e.moral&&l.pilotage.moral)moralBouge(l,id,e.moral*force);
 l.pilotage.crisJoueurs={...(l.pilotage.crisJoueurs||{}),[id]:fiche};
 l.pilotage.crisJoueursLog=[...log,{id,cri,minute:l.minute}].slice(-40);
 return {sens};
}
// Bonus du cri individuel en cours pour le joueur `p` et le geste `k`.
function criJoueurMod(l,p,k){const f=l.pilotage.crisJoueurs?.[p.id];return f&&l.minute<f.jusqua?(f.tous||0)+(f[k]||0):0}
function pilotageCrisJoueurProjection(l){
 const r={};
 for(const [id,f] of Object.entries(l.pilotage.crisJoueurs||{}))r[id]={cri:f.cri,label:CRIS_JOUEUR[f.cri]?.label||f.cri,minute:f.minute,sens:f.sens,enCours:l.minute<f.jusqua};
 return {options:Object.entries(CRIS_JOUEUR).map(([id,x])=>({id,label:x.label})),joueurs:r};
}
// Fatigue : le rythme et « Tout donner » usent plus vite (charge par minute, rugby.js). Même règle pour les deux
// bancs : un adversaire qui accélère s'use aussi.
function pilotageFatigue(l,side){
 if(!pilotageActif(l))return 1;
 const y=pilConsigne(l,side,'rythme'),c=side===l.userSide?l.pilotage.cri:null;
 return (y==='rapide'?1.12:y==='lent'?.92:1)*(c&&l.minute<c.jusqua&&CRIS[c.id].fatigue||1);
}
// Prévision à 10 minutes, même formule que le moteur (rugby.js, charge × endurance), au rythme actuel.
function pilotagePrevision(l,minutes=10){
 const u=l.userSide,charge=(typeof tacticalLoad==='function'?tacticalLoad(l,u):1)*(typeof meteoNiveau==='function'&&meteoNiveau(l,'chaleur')&&typeof METEO_MATCH!=='undefined'?METEO_MATCH.chaleur.fatigue:1)*pilotageFatigue(l,u);
 return activePlayers(l,u).map(p=>({id:p.id,condition:Math.round(p.condition),prevue:Math.round(Math.max(12,Math.min(100,p.condition-charge*(1+(70-skill(p,'stamina'))*.009)*minutes)))}));
}
// Conseil de Gabi : le joueur qui sera le plus entamé dans 10 minutes, remplacé par le meilleur remplaçant possible.
// C'est une estimation de l'adjoint (idée FM27 n° 35, principe d'incertitude) : plus il est compétent, plus il lit
// juste la fatigue à venir et choisit le bon remplaçant. Erreur tirée du hachage du match (aucun tirage), stable
// sur une fenêtre de 5 minutes ; un ancien direct sans contexte Monde garde la lecture exacte.
function pilotageConseilChangement(l,prevision){
 if(l.finished||typeof eligibleChanges!=='function')return null;
 const u=l.userSide,on=l.sheets[u].on,ctx=l.worldContext?.id;
 const lv=ctx==null?100:niveauStaff(),juste=Math.max(0,Math.min(1,(lv-45)/40))*.65+.25,ecart=Math.max(0,85-lv)*.4;
 const h=k=>pilotageHash(ctx+'|changement|'+Math.floor((Number(l.minute)||0)/5)+'|'+k);
 const lue=prevision.map(x=>({...x,prevue:ctx==null?x.prevue:Math.round(x.prevue+((h(x.id)%1000)/1000-.5)*2*ecart)}));
 for(const x of lue.sort((a,b)=>a.prevue-b.prevue)){
  if(x.prevue>=55)break;
  const slot=on.indexOf(x.id);if(slot<0)continue;
  const options=eligibleChanges(l,u,slot).filter(p=>p.condition>=85).sort((a,b)=>(b.rating||0)-(a.rating||0));
  if(!options.length)continue;
  // Mauvaise appréciation : le deuxième remplaçant possible plutôt que le meilleur.
  const entrant=ctx!=null&&options.length>1&&(h('choix:'+x.id)%1000)/1000>=juste?options[1]:options[0];
  const sortant=activePlayers(l,u).find(p=>p.id===x.id);
  return {outId:x.id,inId:entrant.id,slot,texte:`${sortant?.name||'Le n° '+(slot+1)} (${slot+1}) sera vers ${Math.max(12,x.prevue)} % dans 10 minutes. ${entrant.name} est frais.`};
 }
 return null;
}
// Conseil de plan de jeu de Gabi (attaque, défense) : la lecture du match (match-v61-advisor.js), vue ou non selon
// la compétence de l'adjoint (même vigilance que reglesDuStaff), réévaluée toutes les 5 minutes. Rien quand il n'a pas
// d'avis. Accepté, il part dans la file du prochain arrêt de jeu (native/engine/match-arrets.cjs, auteur 'adjoint').
function pilotagePlanAvis(l){
 if(l.finished||typeof matchV61Advice!=='function'||!l.worldContext)return null;
 const a=matchV61Advice(l);if(!a||!(a.attackChanged||a.defenceChanged))return null;
 const lv=niveauStaff(),fenetre=Math.floor((Number(l.minute)||0)/5);
 const voit=k=>(pilotageHash(l.worldContext.id+'|plan|'+fenetre+'|'+k)%100)<Math.round(25+(lv-45)*1.5);
 const u=l.userSide,out=[];
 if(a.attackChanged&&typeof TACTICS!=='undefined'&&TACTICS[a.attack]&&voit('attaque:'+a.attack))
  out.push({axe:'planAttaque',valeur:a.attack,label:CONSIGNES_PLAN.planAttaque.label,valeurLabel:TACTICS[a.attack][0],actuelLabel:TACTICS[l.tactics[u]]?.[0]||'',raison:a.attackReason});
 if(a.defenceChanged&&typeof DEFENCES!=='undefined'&&DEFENCES[a.defence]&&voit('defense:'+a.defence))
  out.push({axe:'systemeDefense',valeur:a.defence,label:CONSIGNES_PLAN.systemeDefense.label,valeurLabel:DEFENCES[a.defence][0],actuelLabel:DEFENCES[l.defences?.[u]||'equilibre']?.[0]||'',raison:a.defenceReason});
 const attente=typeof CDMatchArrets!=='undefined'?CDMatchArrets.file(l):[];
 const reste=out.filter(x=>!attente.some(e=>e.cle==='consigne:'+x.axe));
 return reste.length?reste:null;
}

// --- Causeries : réaction de chaque joueur ---
const TONS_CAUSERIE=['calm','demanding','warm','furious','protective','assertive'];
const TONS_LABELS={calm:'Calme',demanding:'Exigeant',warm:'Encourageant',furious:'Furieux',protective:'Rassurant',assertive:'Affirmé'};
// Effet du contexte sur chaque ton (phase × situation). Aucune réponse n'est bonne à coup sûr.
const TON_CONTEXTE={
 'pre:favorite':{demanding:.6,furious:-.4,protective:-.8,warm:-.3},
 'pre:underdog':{assertive:.5,protective:.4,warm:.4,furious:-.5},
 'pre:neutral':{calm:.2,assertive:.2},
 'half:losing':{furious:1,demanding:.6,calm:.2,protective:.2,warm:-.2},
 'half:winning':{calm:.4,demanding:.4,warm:.2,protective:-.6,furious:-1.2},
 'half:drawing':{assertive:.5,demanding:.3,furious:-.3},
 'post:win':{warm:.8,assertive:.3,furious:-2,demanding:-.3},
 'post:loss':{calm:.3,protective:.4,demanding:.3,warm:-.2},
 'post:draw':{calm:.2,demanding:.2,furious:-.4}
};
function pilotageTraits(p){
 const t=p?.hiddenTraitsV2||{},h=pilotageHash((p?.id||'')+':temperament');
 const v=(x,d)=>Number.isFinite(x)?x:d;
 return {pro:v(t.professionalism,45+h%25),amb:v(t.ambition,45+(h>>>5)%25),sf:typeof sangFroid==='function'?sangFroid(p):55,sens:(h>>>10)%100};
}
// Confiance du joueur envers le manager (0-100), conservée dans la carrière.
function confianceManager(id){const v=S?.pilotage?.confiance?.[id];return Number.isFinite(v)?v:45+pilotageHash(id+':confiance')%21}
function tonsRecents(){return Array.isArray(S?.pilotage?.tons)?S.pilotage.tons:[]}
function situationCauserie(phase,c){
 if(phase==='pre')return 'pre:'+(c.pronostic||'neutral');
 if(phase==='half')return 'half:'+c.scoreState;
 return 'post:'+c.result;
}
// Réaction sans part d'imprévu : sert au staff pour choisir (il ne lit pas dans les têtes).
// `banc` (banc adverse) : confiance fixe envers son entraîneur et tons déjà employés pendant ce match ; sans `ctx`,
// confiance et tons de la carrière du manager.
function reactionAttendue(p,tone,phase,c,banc){
 const {pro,amb,sf,sens}=pilotageTraits(p);
 const base={calm:(60-sf)*.04+.3,demanding:(pro-55)*.04+(amb-55)*.02-(sens-50)*.015,warm:(sens-50)*.03+(55-pro)*.01+.3,
  furious:(amb-55)*.03+(pro-60)*.02-(sens-50)*.04-(60-sf)*.03-.3,protective:(60-sf)*.03+(sens-50)*.02-(amb-55)*.02,assertive:(amb-55)*.03+(sf-60)*.02+.2}[tone]||0;
 const ctx=TON_CONTEXTE[situationCauserie(phase,c)]?.[tone]||0;
 const t=Number.isFinite(banc?.confiance)?banc.confiance:confianceManager(p.id);
 let r=(base+ctx)*(.5+t/100)+(t-50)*.02;
 if((tone==='furious'||tone==='demanding')&&t<35)r-=.8;
 // Un ton répété s'use (la colère surtout).
 const n=(banc?.tons||tonsRecents()).slice(-4).filter(x=>x===tone).length;r-=n*(tone==='furious'?1:.6);
 return r;
}
function reactionJoueur(p,tone,phase,c,key,seul,ctx){
 const imprevu=((pilotageHash(p.id+'|'+key+'|'+phase+'|'+tone)%1000)/1000-.5)*1.2;
 const r=Math.max(-3,Math.min(3,(reactionAttendue(p,tone,phase,c,ctx)+imprevu)*(seul?1.4:1)));
 const sf=pilotageTraits(p).sf,favori=phase==='pre'&&c.pronostic==='favorite'||c.scoreState==='winning'&&phase==='half';
 let etat;
 if(r>=1.8)etat='galvanise';
 else if(r>=.7)etat=tone==='calm'||tone==='protective'?'serein':'motive';
 else if(r>-.7)etat='indifferent';
 else if(['furious','demanding','assertive'].includes(tone))etat=sf<55?'tendu':'vexe';
 else etat=favori?'relache':r<=-1.6?'vexe':'tendu';
 return {id:p.id,score:Math.round(r*10)/10,etat,label:PILOTAGE_ETATS[etat].label,delta:r>=.7?1:r<=-.7?-1:0};
}
// Applique une causerie : états pour le match (avant, mi-temps), confiance envers le manager, mémoire des tons.
function appliquerCauserie(phase,tone,reactions,seul){
 S.pilotage=S.pilotage&&S.pilotage.version===1?S.pilotage:{version:1,confiance:{},tons:[]};
 const l=S.live;
 if(phase!=='post'&&pilotageActif(l)){
  const etats={...l.pilotage.etats};
  for(const x of reactions)etats[x.id]={etat:x.etat,phase};
  l.pilotage.etats=etats;
 }
 const k=phase==='post'?1.5:.8;
 for(const x of reactions)S.pilotage.confiance[x.id]=Math.max(0,Math.min(100,Math.round(confianceManager(x.id)+x.score*k)));
 S.pilotage.tons=[...tonsRecents(),tone].slice(-8);
 // Moral du groupe : seulement quand le groupe entier (ou une ligne) est concerné.
 if(seul||!reactions.length)return 0;
 const moyenne=reactions.reduce((n,x)=>n+x.score,0)/reactions.length;
 return Math.max(-2,Math.min(2,Math.round(moyenne*1.2)));
}
// Choix du staff quand le match lui est confié : il connaît plus ou moins bien ses joueurs.
// `repli` : niveau rendu quand le club n'a aucun entraîneur réel (staffJudges ne donne que la valeur par défaut).
function niveauStaff(clubId=S.club,repli){
 const j=typeof staffJudges==='function'?staffJudges(clubId):null;
 if(repli!==undefined&&!(j&&Object.values(j).some(x=>x&&!String(x.id||'').startsWith('club:'))))return repli;
 const lv=j?Math.max(...Object.values(j).map(x=>Number(x?.level)||0)):0;
 return lv>0?lv:(typeof STAFF_JUDGEMENT!=='undefined'?STAFF_JUDGEMENT.niveau.defaut:60);
}
// Banc adverse sans entraîneur réel : niveau tiré du réglage « niveau adverse » du match.
const NIVEAU_ADVERSE={decouverte:50,classique:60,expert:72};
function niveauAdverse(l){return niveauStaff(l.pair[1-l.userSide],NIVEAU_ADVERSE[l.aiLevel||S?.difficulty]||NIVEAU_ADVERSE.classique)}
function tonDuStaff(joueurs,phase,c,key,tons=TONS_CAUSERIE,ctx){
 const classes=tons.map(tone=>({tone,v:joueurs.reduce((n,p)=>n+reactionAttendue(p,tone,phase,c,ctx),0)})).sort((a,b)=>b.v-a.v||(a.tone<b.tone?-1:1));
 const lv=Number.isFinite(ctx?.niveau)?ctx.niveau:niveauStaff(),juste=Math.max(0,Math.min(1,(lv-45)/40))*.65+.25;
 const h=pilotageHash(key+'|'+phase+'|staff');
 if((h%1000)/1000<juste)return classes[0].tone;
 // Erreur d'appréciation : le deuxième choix le plus souvent, parfois un ton au hasard.
 return (h>>>10)%3?classes[1].tone:classes[2+(h>>>12)%(classes.length-2)].tone;
}

// --- Causerie du vestiaire adverse (avant-match, mi-temps) ---
// Appelée par la causerie du manager (native/engine/match-talks.cjs) quand sa phase s'ouvre, avec le contexte vu du
// manager (pronostic, score) : l'entraîneur adverse choisit son ton selon sa compétence, chacun de ses joueurs
// réagit (même modèle, confiance neutre envers son entraîneur). Ni la confiance ni le moral de la carrière ne bougent.
const TONS_ADVERSES={calm:'calme',demanding:'exigeant',warm:'encourageant',furious:'furieux',protective:'rassurant',assertive:'affirmé'};
const CONTEXTE_MIROIR={favorite:'underdog',underdog:'favorite',winning:'losing',losing:'winning',drawing:'drawing'};
function contexteAdverse(c){
 const out={...c};
 if(c?.pronostic)out.pronostic=CONTEXTE_MIROIR[c.pronostic];
 if(c?.scoreState)out.scoreState=CONTEXTE_MIROIR[c.scoreState];
 return out;
}
function vestiaireDe(nom){return /^Les /.test(nom)?'des '+nom.slice(4):/^Le /.test(nom)?'du '+nom.slice(3):/^[AEIOUYÉÈÊÂÎÔ]/i.test(nom)?'d\''+nom:'de '+nom}
// Causerie d'un banc de l'ordinateur (`banc` : niveau, tons déjà employés, causeries faites) devant les joueurs de sa
// feuille, dans le contexte vu de son côté (`cx`). Mêmes règles que le staff du manager ; rend le ton choisi.
function causerieDuBanc(l,side,banc,phase,cx,cle){
 banc.causeries=banc.causeries||{};
 if(banc.causeries[phase])return null;
 const sh=l.sheets?.[side]||{},effectif=new Map((S.clubs[l.pair[side]]?.players||[]).map(p=>[p.id,p]));
 const joueurs=[...new Set([...(sh.initial||[]),...(sh.bench||[])])].map(id=>effectif.get(id)).filter(Boolean);
 if(!joueurs.length)return null;
 const ctx={confiance:50,tons:banc.tons||[],niveau:banc.niveau};
 const tone=tonDuStaff(joueurs,phase,cx,cle,TONS_CAUSERIE,ctx);
 const etats={...l.pilotage.etats};
 for(const p of joueurs)etats[p.id]={etat:reactionJoueur(p,tone,phase,cx,cle,false,ctx).etat,phase,adverse:true};
 l.pilotage.etats=etats;
 banc.tons=[...(banc.tons||[]),tone];banc.causeries[phase]=tone;
 return tone;
}
// Contexte d'une causerie vu du côté `side` : pronostic (même seuil que la causerie du manager) et score.
function contexteDuBanc(l,side,phase){
 const d=l.score[side]-l.score[1-side],out={scoreState:d>0?'winning':d<0?'losing':'drawing'};
 if(phase==='pre'&&typeof teamLevel==='function'&&typeof activePlayers==='function'){
  const g=teamLevel(activePlayers(l,side))-teamLevel(activePlayers(l,1-side)),seuil=typeof RELACHEMENT!=='undefined'?RELACHEMENT.seuil:3;
  if(g>=seuil)out.pronostic='favorite';else if(g<=-seuil)out.pronostic='underdog';
 }
 return out;
}
function causerieAdverse(l,phase,c,key){
 if(!pilotageActif(l)||!l.pilotage.adversaire||(phase!=='pre'&&phase!=='half'))return null;
 const adv=l.pilotage.adversaire;adv.causeries=adv.causeries||{};
 if(adv.causeries[phase])return adv.causeries[phase];
 const tone=causerieDuBanc(l,1-l.userSide,adv,phase,contexteAdverse(c||{}),'adverse:'+key);
 if(!tone)return null;
 l.pilotage.journal.push({minute:l.minute,auteur:'adversaire',texte:`Vestiaire ${vestiaireDe(nomAdverse(l))} : discours ${TONS_ADVERSES[tone]} ${phase==='pre'?'avant le match':'à la mi-temps'}.`});
 l.pilotage.journal=l.pilotage.journal.slice(-30);
 return tone;
}

// --- Consignes d'un staff toutes les 5 minutes : celui du manager quand le match lui est confié, celui de
// l'adversaire pendant tout le match. Mêmes règles ; vigilance liée à la compétence (`lv`).
function reglesDuStaff(l,side,c,lv,graine,recent,maintenant,poser){
 const voit=k=>(pilotageHash(graine+l.minute+'|'+k)%100)<Math.round(25+(lv-45)*1.5);
 const a=l.pilotage.arbitre,ecart=l.score[side]-l.score[1-side];
 const pl=(n,s,p)=>n+' '+(n>1?p:s);
 if(l.minute<=5&&a.rucks>=4&&voit('arbitre-rucks'))poser('rucks','prudente',`${a.nom} siffle beaucoup les rucks.`);
 const penalites=maintenant.penalites-recent.penalites;
 if(penalites>=2&&c.discipline!=='stricte'&&voit('discipline'))poser('discipline','stricte',`${pl(penalites,'pénalité concédée','pénalités concédées')} en 5 minutes.`);
 const touchesPerdues=(maintenant.touches-recent.touches)-(maintenant.touchesGagnees-recent.touchesGagnees);
 if(touchesPerdues>=2&&c.touche!=='sure'&&voit('touche'))poser('touche','sure',`${pl(touchesPerdues,'touche perdue','touches perdues')} en 5 minutes.`);
 if(l.minute>=55&&ecart<0&&voit('poursuite')){const r=`Mené de ${-ecart} : il faut garder le ballon et accélérer.`;poser('rythme','rapide',r);poser('piedJeu','moins',r)}
 else if(l.minute>=65&&ecart>0&&ecart<=10&&voit('gestion')){const r=`${ecart} point${ecart>1?'s':''} d’avance à tenir : jouer dans leur camp.`;poser('piedJeu','plus',r);poser('rythme','lent',r)}
 // Dix dernières minutes : jouer la montre devant d'un score au plus, tout tenter mené de deux scores au plus.
 if(l.minute>=70&&c.finDeMatch==='normal'){
  if(ecart>0&&ecart<=7&&voit('montre'))poser('finDeMatch','montre',`${ecart} point${ecart>1?'s':''} d’avance : tuer le temps.`);
  else if(ecart<0&&ecart>=-14&&voit('tout'))poser('finDeMatch','tout',`Mené de ${-ecart} : tout tenter.`);
 }
}
// Avis du staff (fenêtre Équipe, bouton « Appliquer ces consignes ») : toutes les 5 minutes, en direct comme en
// délégation, le staff relit le match avec sa compétence (il peut ne rien voir) et propose des consignes. Aucun
// tirage : seulement le hachage du match. En délégation, il les applique lui-même (pilotageStaff).
function pilotageStaffAvis(l){
 if(!pilotageActif(l)||l.finished||l.minute===l.pilotage.staffMinute||l.minute%5)return;
 l.pilotage.staffMinute=l.minute;
 const recent=l.pilotage.staffReleve||pilotageReleve(l),maintenant=pilotageReleve(l),propositions=[];
 l.pilotage.staffReleve=maintenant;
 reglesDuStaff(l,l.userSide,l.pilotage.consignes,niveauStaff(),l.worldContext.id+'|',recent,maintenant,(axe,valeur,raison)=>{
  const i=propositions.findIndex(x=>x.axe===axe);const x={axe,valeur,raison};if(i>=0)propositions[i]=x;else propositions.push(x);
 });
 // Un avis chasse le précédent ; sans rien de neuf, l'avis en cours reste tant qu'il n'est pas appliqué.
 if(propositions.length)l.pilotage.staffAvis={minute:l.minute,propositions};
}
function staffAvisEnAttente(l){
 const a=l.pilotage?.staffAvis;if(!a)return [];
 const attente=typeof CDMatchArrets!=='undefined'?CDMatchArrets.file(l):[];
 return a.propositions.filter(x=>l.pilotage.consignes[x.axe]!==x.valeur&&!attente.some(e=>e.cle==='consigne:'+x.axe&&e.valeur===x.valeur));
}
// Bouton « Appliquer ces consignes » (fenêtre Équipe) ou bulle de Gabi (idée FM27 n° 35) : le manager prend l'avis du
// staff, en entier ou seulement les axes cliqués (`axes`). Le changement attend le prochain arrêt de jeu (file
// native/engine/match-arrets.cjs, auteur 'adjoint') ; sans file (ancien direct), il part tout de suite.
function appliquerAvisStaff(l,axes){
 if(!pilotageActif(l)||l.finished)return false;
 let a=staffAvisEnAttente(l);
 if(Array.isArray(axes)&&axes.length)a=a.filter(x=>axes.includes(x.axe));
 if(!a.length)return false;
 const file=typeof CDMatchArrets!=='undefined'&&CDMatchArrets.actif(l)?CDMatchArrets:null;
 for(const x of a){if(file)file.ajouter(l,{type:'consigne',axe:x.axe,valeur:x.valeur},'adjoint');else setConsigne(l,x.axe,x.valeur);}
 l.pilotage.journal.push({minute:l.minute,auteur:'manager',texte:`Tu suis l’avis du staff (${a.map(x=>consigneLabel(x.axe,x.valeur)).join(', ')}).`});
 l.pilotage.journal=l.pilotage.journal.slice(-30);
 const reste=(l.pilotage.staffAvis?.propositions||[]).filter(x=>!a.some(y=>y.axe===x.axe));
 l.pilotage.staffAvis=reste.length?{...l.pilotage.staffAvis,propositions:reste}:null;
 return true;
}
function pilotageStaff(l){
 pilotageStaffAvis(l);
 const a=staffAvisEnAttente(l);if(!a.length)return;
 for(const x of a)setConsigne(l,x.axe,x.valeur,'staff');
 l.pilotage.staffAvis=null;
}
// Banc adverse : appelé après chaque minute du match du joueur (native/engine/match-delegation.cjs), en direct
// comme en délégation.
function pilotageAdversaire(l){
 const adv=l?.pilotage?.adversaire;
 if(!pilotageActif(l)||l.finished||!adv||!l.pilotage.consignesAdverses||l.minute===adv.minute||l.minute%5)return;
 adv.minute=l.minute;
 const o=1-l.userSide,recent=adv.releve||pilotageReleve(l,o),maintenant=pilotageReleve(l,o);
 adv.releve=maintenant;
 reglesDuStaff(l,o,l.pilotage.consignesAdverses,adv.niveau,'adverse|'+l.worldContext.id+'|',recent,maintenant,(axe,v)=>setConsigneAdverse(l,axe,v));
}

// --- Matchs entre deux clubs de l'ordinateur (demande de Léo, 19/11/2026) ---
// Chaque banc fait ce que fait le banc adverse du match du joueur : causerie d'avant-match et de mi-temps, consignes
// revues toutes les 5 minutes (reglesDuStaff), avec la compétence de ses entraîneurs. Les remplacements selon la
// fatigue et les révisions du plan de jeu restent ceux du moteur (manageSubstitutions, adaptManager). Arbitre désigné
// comme pour le match du joueur. Aucun tirage aléatoire ajouté : tout passe par pilotageHash.
function miTempsPassee(l){return typeof flowRules==='function'&&flowRules(l)?!!(l.flow?.atBreak||l.flow?.period===2):l.minute>=40}
function initPilotageIA(l,f){
 if(!PILOTAGE_RULES||!l||l.userSide!==-1||!f||f.id==null||l.pilotage)return;
 const repli=NIVEAU_ADVERSE[l.aiLevel||S?.difficulty]||NIVEAU_ADVERSE.classique;
 l.pilotageVersion=1;
 l.pilotage={ia:true,fixtureId:String(f.id),arbitre:arbitreDuMatch(f.id,f.competitionId),consignes:{...CONSIGNES_NEUTRES},depuis:{},releves:{},etats:{},journal:[],
  cotes:[0,1].map(side=>({consignes:{...CONSIGNES_NEUTRES},niveau:niveauStaff(l.pair[side],repli),minute:-1,releve:null,tons:[],causeries:{},changements:0}))};
 coachOrdinateur(l);
}
function coachOrdinateur(l){
 const p=l.pilotage;
 for(const side of [0,1]){
  const b=p.cotes[side],cle='ia:'+side+':'+p.fixtureId;
  if(!b.causeries.pre)causerieDuBanc(l,side,b,'pre',contexteDuBanc(l,side,'pre'),cle);
  if(!b.causeries.half&&miTempsPassee(l))causerieDuBanc(l,side,b,'half',contexteDuBanc(l,side,'half'),cle);
  if(l.minute%5||l.minute===b.minute||l.minute===0)continue;
  b.minute=l.minute;
  const recent=b.releve||pilotageReleve(l,side),maintenant=pilotageReleve(l,side);b.releve=maintenant;
  reglesDuStaff(l,side,b.consignes,b.niveau,cle+'|',recent,maintenant,(axe,v)=>{if(b.consignes[axe]!==v){b.consignes[axe]=v;b.changements++}});
 }
}
// Après chaque minute jouée, quel que soit le match : bancs de l'ordinateur, et banc adverse du match du joueur (aussi
// dans la version web, sans le domaine natif match-delegation). Causeries adverses faites ici si la causerie du manager
// ne les a pas déjà déclenchées (match sans causerie, version web).
function pilotageApresMinute(l){
 if(!pilotageActif(l)||l.finished)return;
 if(l.pilotage.cotes){coachOrdinateur(l);return}
 if(!(l.userSide>=0)||!l.pilotage.adversaire||!l.worldContext)return;
 const adv=l.pilotage.adversaire,u=l.userSide;
 if(!adv.causeries?.pre)causerieAdverse(l,'pre',contexteDuBanc(l,u,'pre'),'moteur');
 if(!adv.causeries?.half&&miTempsPassee(l))causerieAdverse(l,'half',contexteDuBanc(l,u,'half'),'moteur');
 pilotageAdversaire(l);
}
// --- Moral individuel en match (revue FM27 de Léo, 22/11/2026) ---
// Échelle 0-100 par joueur. Départ : la réaction à la causerie (état ci-dessus), 50 sans causerie ; une causerie de
// mi-temps décale le départ. Les faits du match le font bouger (lisible, modéré), puis il revient doucement vers son
// départ (4 % de l'écart par minute). Effet sur le jeu : seulement l'écart au départ, ±1 point d'attribut par 10 points
// de moral, borné à ±2 (l'état de causerie garde son propre effet, déjà compté).
const MORAL_DEPART={galvanise:72,motive:64,serein:60,indifferent:50,tendu:40,vexe:36,relache:44};
const MORAL_FAITS={attente:-2,essaiMarque:8,essaiEquipe:3,essaiEncaisse:-3,butReussi:2,butManque:-3,percee:3,battu:-3,enAvant:-3,grattage:3,carton:-12,cartonEquipe:-2,entree:4,scoreMene:1,scoreSubi:-1,retour:.04,ecart:8};
const MORAL_PALIERS=[[78,'gonfle','Gonflé à bloc'],[62,'confiant','Confiant'],[42,'concentre','Concentré'],[28,'inquiet','Inquiet'],[0,'abattu','Abattu']];
function moralPalier(v){return MORAL_PALIERS.find(x=>v>=x[0])||MORAL_PALIERS[MORAL_PALIERS.length-1]}
function moralEffet(v,depart){return Math.max(-2,Math.min(2,Math.round((v-depart)/10)))}
function moralDepart(l,id){return MORAL_DEPART[l.pilotage.etats?.[id]?.etat]??50}
function moralFiche(l,id){
 const M=l.pilotage.moral,d=moralDepart(l,id);let f=M.joueurs[id];
 if(!f)f=M.joueurs[id]={v:d,depart:d,repere:d};
 // Nouvelle causerie (mi-temps) : le départ change, le moral suit du même écart.
 else if(f.depart!==d){f.v=Math.max(0,Math.min(100,f.v+d-f.depart));if(f.ref!==undefined)f.ref+=d-f.depart;f.depart=d}
 return f;
}
function moralBouge(l,id,delta){if(id==null||!delta)return;const f=moralFiche(l,id);f.v=Math.max(0,Math.min(100,f.v+delta))}
function pilotageMoral(l){
 if(!pilotageActif(l)||!l.sheets)return;
 const p=l.pilotage,F=MORAL_FAITS;
 const premier=!p.moral;
 const M=p.moral||(p.moral={joueurs:{},ev:0,jaunes:[{},{}],sur:[[],[]],minute:-1});
 const sur=[0,1].map(s=>activePlayers(l,s).map(x=>x.id));
 // Remplaçants suivis dès le coup d'envoi (revue FM27, idée 32) : ils vivent le match depuis le banc (moral montré).
 // À son entrée, son moral du moment devient sa référence (`ref`) : l'effet sur le jeu repart de zéro comme avant,
 // seul le moral montré garde la trace du banc.
 M.banc=M.banc||{};for(const s of [0,1])for(const id of l.sheets[s].bench||[])if(id&&!(l.sheets[s].used||[]).includes(id)){moralFiche(l,id);M.banc[id]=true}
 // Entrées en jeu : un remplaçant arrive avec l'envie d'en découdre.
 for(const s of [0,1]){for(const id of sur[s]){moralFiche(l,id);if(!premier&&!M.sur[s].includes(id)&&!(l.sheets[s].cards||[]).some(c=>c.id===id)){if(M.banc?.[id])M.joueurs[id].ref=M.joueurs[id].v;moralBouge(l,id,F.entree)}}M.sur[s]=sur[s]}
 const equipe=(s,delta,sauf)=>{for(const id of sur[s])if(id!==sauf)moralBouge(l,id,delta)};
 // Le banc vit le match à moitié : la moitié des faits collectifs (arrondie).
 const banc=(s,delta)=>{for(const id of l.sheets[s].bench||[])if(id&&M.joueurs[id])moralBouge(l,id,Math.sign(delta)*Math.floor(Math.abs(delta)/2))};
 const events=l.events||[];
 for(let i=premier?events.length:M.ev;i<events.length;i++){
  const e=events[i],sc=e?.scene;if(!sc)continue;const s=sc.team;
  if(e.type==='try'&&(s===0||s===1)){moralBouge(l,sc.actor,F.essaiMarque);equipe(s,F.essaiEquipe,sc.actor);equipe(1-s,F.essaiEncaisse);banc(s,F.essaiEquipe);banc(1-s,F.essaiEncaisse)}
  else if(sc.kind==='goal')moralBouge(l,sc.actor,F.butReussi);
  else if(sc.kind==='miss')moralBouge(l,sc.actor,F.butManque);
  else if(sc.kind==='hand-fault')moralBouge(l,sc.actor,F.enAvant);
  else if(sc.kind==='turnover')moralBouge(l,sc.actor,F.grattage);
  else if(sc.kind==='carry'&&sc.from&&sc.to&&Math.abs(sc.to.x-sc.from.x)>=15){moralBouge(l,sc.actor,F.percee);moralBouge(l,sc.tackler,F.battu)}
 }
 M.ev=events.length;
 // Cartons : le joueur sanctionné, et un peu toute son équipe.
 for(const s of [0,1]){const n=l.sheets[s].yellowCounts||{};for(const [id,c] of Object.entries(n)){if(c>(M.jaunes[s][id]||0)&&!premier){moralBouge(l,id,F.carton);equipe(s,F.cartonEquipe,id)}M.jaunes[s][id]=c}}
 const minute=Math.floor(l.minute||0);
 if(minute!==M.minute){
  // Score et temps : en 2e mi-temps, toutes les 5 minutes, l'équipe qui mène nettement prend confiance, l'autre doute.
  if(minute>=40&&minute%5===0)for(const s of [0,1]){const ecart=(l.score?.[s]||0)-(l.score?.[1-s]||0);if(ecart>=F.ecart){equipe(s,F.scoreMene);banc(s,F.scoreMene)}else if(ecart<=-F.ecart){equipe(s,F.scoreSubi);banc(s,F.scoreSubi)}}
  // Remplaçant jamais entré : l'impatience monte doucement en fin de match (toutes les 10 minutes dès la 60e).
  if(minute>=60&&minute%10===0)for(const s of [0,1])for(const id of l.sheets[s].bench||[])if(id&&!(l.sheets[s].used||[]).includes(id))moralBouge(l,id,F.attente);
  // Retour doux vers le départ ; repère de tendance toutes les 5 minutes.
  for(const f of Object.values(M.joueurs)){f.v=Math.round((f.v+((f.ref??f.depart)-f.v)*F.retour)*10)/10;if(minute%5===0)f.repere=f.v}
  M.minute=minute;
 }
}
function pilotageMoralProjection(l){
 const M=l.pilotage?.moral;if(!M)return {};
 const u=l.userSide,ids=new Set([...(l.sheets[u].on||[]),...(l.sheets[u].bench||[])]),r={};
 for(const [id,f] of Object.entries(M.joueurs)){if(!ids.has(id))continue;const [,cle,label]=moralPalier(f.v);
  r[id]={valeur:Math.round(f.v),depart:f.depart,cle,label,tendance:f.v-f.repere>=3?1:f.v-f.repere<=-3?-1:0,effet:moralEffet(f.v,f.ref??f.depart)}}
 return r;
}
function pilotageMinute(l,moteur){
 const avant=PILOTAGE_EN_COURS;PILOTAGE_EN_COURS=l||null;
 try{const r=moteur(l);if(l){pilotageMoral(l);pilotageApresMinute(l);if(typeof CDMatchArrets!=='undefined')CDMatchArrets.apresMinute(l)}return r}
 finally{PILOTAGE_EN_COURS=avant}
}
// Branché sur la minute du moteur (rugby.js, chargé avant ce fichier).
if(typeof advanceRugby==='function'&&!advanceRugby.pilotageMinute){
 const moteurRugby=advanceRugby;
 advanceRugby=function(l){return pilotageMinute(l,moteurRugby)};
 Object.assign(advanceRugby,moteurRugby,{pilotageMinute:true});
}

// --- Projection pour l'écran 2D ---
function pilotageBilan(l,axe){
 const v=l.pilotage.consignes[axe],r=l.pilotage.releves[axe];if(!r||v===CONSIGNES_NEUTRES[axe])return null;
 const u=l.userSide,m=pilotageReleve(l),d=k=>m[k]-(r[k]||0),pl=(n,s,p)=>n+' '+(n>1?p:s);
 // Faits du moteur depuis le changement (essais sur ballon porté, coups d'envoi repris).
 const ev=(l.events||[]).slice(r.ev||0);
 const maulTries=ev.filter(e=>e.type==='try'&&e.scene?.team===u&&e.scene?.origin==='maul').length;
 let envois=0,repris=0;
 ev.forEach((e,i)=>{if(e.type==='restart'&&e.scene?.team===u){envois++;const n=ev[i+1];if(n?.scene?.kind==='reception'&&n.scene.team===u)repris++}});
 const morceaux={
  rucks:[pl(d('penalites'),'pénalité','pénalités'),pl(d('arraches'),'ballon arraché','ballons arrachés')],
  discipline:[pl(d('penalites'),'pénalité','pénalités'),pl(d('cartons'),'carton','cartons')],
  piedJeu:[pl(d('coups'),'coup de pied','coups de pied'),pl(d('metres'),'mètre gagné','mètres gagnés')],
  rythme:[pl(d('porteurs'),'temps de jeu','temps de jeu'),pl(d('pertes'),'ballon perdu','ballons perdus')],
  relance:[pl(d('coups'),'coup de pied','coups de pied'),pl(d('metres'),'mètre gagné','mètres gagnés'),pl(d('pertes'),'ballon perdu','ballons perdus')],
  finDeMatch:[`${d('points')} point${d('points')>1?'s':''} marqué${d('points')>1?'s':''}, ${d('encaisses')} encaissé${d('encaisses')>1?'s':''}`,pl(d('pertes'),'ballon perdu','ballons perdus')],
  touche:[`${d('touchesGagnees')}/${d('touches')} touche${d('touches')>1?'s':''} gagnée${d('touchesGagnees')>1?'s':''}`],
  maul:[`${d('touchesGagnees')} touche${d('touchesGagnees')>1?'s':''} gagnée${d('touchesGagnees')>1?'s':''}`,pl(maulTries,'essai sur ballon porté','essais sur ballon porté')],
  melee:[`${d('meleesGagnees')}/${d('melees')} mêlée${d('melees')>1?'s':''} gagnée${d('meleesGagnees')>1?'s':''}`,pl(d('penalitesAdverses'),'pénalité adverse','pénalités adverses'),pl(d('penalites'),'pénalité contre nous','pénalités contre nous')],
  coupsEnvoi:[`${repris}/${envois} coup${envois>1?'s':''} d’envoi récupéré${repris>1?'s':''}`],
  cible:[pl(d('essais'),'essai','essais'),pl(d('metres'),'mètre gagné','mètres gagnés'),v==='ouvreur'?pl(d('arraches'),'ballon perdu chez eux','ballons perdus chez eux'):aileFaible(l,1-u)>0?`effet ${Math.round(aileForce(l,u)*100)} %`:'pas d’aile faible chez eux']
 }[axe]||[];
 return {axe,valeur:v,depuis:l.pilotage.depuis[axe],texte:`${CONSIGNES[axe].label} « ${consigneLabel(axe,v)} » depuis ${l.pilotage.depuis[axe]}′ : ${morceaux.join(', ')}.`};
}
// Avis du staff sur chaque cran (idée FM27 n° 33, fenêtre des consignes en direct ; choix de Léo du 23/11/2026) :
// pour / contre de chaque cran EN TENDANCE, jamais chiffrés (principe d'incertitude). `force` : 2 net, 1 léger,
// 0 le staff ne sait pas. Ce que le staff lit dépend de sa compétence (`niveauStaff`) : il peut grossir, minimiser ou
// ne pas voir un effet ; la lecture est figée pour le match (hachage, aucun tirage) et tient compte de l'arbitre et de
// la météo. Mots courts, ordres de grandeur des effets réels ci-dessus et de tactical-plans.js.
const CONSIGNES_TENDANCES={
 piedJeu:{moins:[[1,1,'Ballon gardé'],[-1,2,'Moins de jeu au pied'],[-1,1,'Moins de territoire']],normal:[[0,0,'Équilibre']],plus:[[1,2,'Jeu au pied'],[1,1,'Territoire'],[-1,1,'Ballons rendus']]},
 rythme:{lent:[[1,1,'Moins d’en-avant'],[1,1,'Moins d’usure'],[-1,1,'Moins d’avancée']],normal:[[0,0,'Équilibre']],rapide:[[1,1,'Plus d’avancée'],[-1,1,'En-avant'],[-1,1,'Usure des deux XV']]},
 relance:{degager:[[1,2,'Jeu au pied chez nous'],[-1,1,'Ballon rendu']],selon:[[0,0,'Au choix du 10']],relancer:[[1,1,'Ballon à la main'],[-1,2,'Moins de pied chez nous'],[-1,1,'Ballons perdus']]},
 finDeMatch:{montre:[[1,2,'Ballon gardé'],[-1,1,'Moins de jeu au pied'],[0,0,'Dès 70′']],normal:[[0,0,'Sans effet']],tout:[[1,1,'Prise de risque'],[-1,2,'Ballons perdus'],[0,0,'Dès 70′']]},
 rucks:{prudente:[[1,1,'Moins de fautes'],[-1,1,'Moins d’arrachés']],normale:[[0,0,'Équilibre']],agressive:[[1,2,'Ballons arrachés'],[-1,'arbitre-rucks','Fautes']]},
 discipline:{stricte:[[1,2,'Moins de fautes'],[-1,1,'Défense moins mordante']],normale:[[0,0,'Équilibre']],limite:[[1,1,'Défense mordante'],[-1,2,'Fautes'],[-1,'arbitre-cartons','Cartons']]},
 touche:{sure:[[1,2,'Touche gagnée'],[-1,1,'Plateforme moyenne']],normale:[[0,0,'Équilibre']],risquee:[[1,1,'Plateforme idéale'],[-1,2,'Touches perdues']]},
 maul:{jamais:[[1,1,'Ballon vite sorti'],[-1,2,'Moins d’essais portés']],selon:[[0,0,'Au choix du pack']],souvent:[[1,2,'Essais portés'],[-1,1,'Jeu prévisible']]},
 melee:{vite:[[1,2,'Moins de sifflets'],[1,1,'Plateforme']],normale:[[0,0,'Équilibre']],pousser:[[1,1,'Pénalités si pack fort'],[-1,'arbitre-melee','Coups de sifflet']]},
 coupsEnvoi:{longs:[[1,2,'Distance'],[-1,1,'Moins de récupérés']],normaux:[[0,0,'Équilibre']],courts:[[1,2,'Ballons récupérés'],[-1,1,'Moins de distance']]},
 cible:{aucune:[[0,0,'Sans effet']],aile:[[1,1,'Mètres sur leur aile'],[-1,1,'Ils s’adaptent']],ouvreur:[[1,1,'Ballons perdus chez eux'],[-1,1,'Plaquages en retard'],[-1,1,'Ils s’adaptent']]},
 planAttaque:{equilibre:[[0,0,'Jeu varié']],large:[[1,2,'Gains plus longs'],[-1,1,'Fatigue'],[-1,'pluie-large','Fautes de main']],conquete:[[1,1,'Moins de fautes de main'],[1,1,'Pénaltouche'],[-1,1,'Gains plus courts']],occupation:[[1,2,'Territoire'],[1,1,'Moins d’usure'],[-1,1,'Ballons rendus'],[-1,'vent-occupation','Selon le vent']]},
 systemeDefense:{equilibre:[[0,0,'Compromis']],pression:[[1,2,'Erreurs provoquées'],[-1,1,'Fatigue'],[-1,1,'Grands gains concédés'],[-1,1,'Pénalités']],prudente:[[1,1,'Profondeur protégée'],[1,1,'Moins de pénalités'],[-1,1,'Premiers mètres cédés']]},
 penalites:{auto:[[0,0,'Au choix du capitaine']],points:[[1,2,'Points au pied'],[-1,1,'Moins d’occasions d’essai']],touch:[[1,1,'Ballon porté'],[-1,1,'Points laissés']],main:[[1,1,'Jeu rapide'],[-1,1,'Ballons perdus']]}
};
// Force qui dépend du contexte du match : l'arbitre et la météo durcissent un effet.
function tendanceContexte(l,cle){
 const a=l.pilotage.arbitre||{};
 if(cle==='arbitre-rucks')return a.rucks>=4?2:1;
 if(cle==='arbitre-cartons')return a.cartons>=4?2:1;
 if(cle==='arbitre-melee')return a.melee>=4?2:1;
 if(cle==='pluie-large')return l.weather==='Pluie'?2:1;
 if(cle==='vent-occupation')return l.weather==='Vent'?2:1;
 return 1;
}
// Fiabilité affichée de la lecture du staff (un mot, jamais son niveau chiffré).
function avisFiabilite(lv){return lv>=75?'fiable':lv>=60?'correct':'approximatif'}
function pilotageAvisCrans(l){
 if(!pilotageActif(l))return null;
 const lv=niveauStaff(),erreur=Math.max(.04,Math.min(.42,(95-lv)/110)),graine='avis|'+(l.worldContext?.id||'match')+'|'+(l.pair||[]).join('-')+'|';
 const axes={};
 for(const [axe,crans] of Object.entries(CONSIGNES_TENDANCES)){
  axes[axe]={};
  for(const [v,effets] of Object.entries(crans)){
   const r={pour:[],contre:[],neutre:[]};
   for(const [sens,f,mot] of effets){
    if(!sens){r.neutre.push(mot);continue;}
    let force=typeof f==='string'?tendanceContexte(l,f):f;
    // Lecture du staff : plus il est compétent, moins il se trompe d'intensité ou passe à côté.
    const h=pilotageHash(graine+axe+'|'+v+'|'+mot)/4294967296;
    if(h<erreur)force=force===2?1:(h<erreur/3?0:2);
    (sens>0?r.pour:r.contre).push({mot,force});
   }
   axes[axe][v]=r;
  }
 }
 return {fiabilite:avisFiabilite(lv),axes};
}
function pilotageProjection(l){
 if(!pilotageActif(l))return null;
 const p=l.pilotage,joueurs={};
 // États du club joué seulement : ceux des joueurs adverses restent dans le vestiaire adverse.
 for(const [id,e] of Object.entries(p.etats||{}))if(!e?.adverse)joueurs[id]={etat:e.etat,label:PILOTAGE_ETATS[e.etat]?.label||'',phase:e.phase,confiance:confianceManager(id)};
 return {
  arbitre:{...p.arbitre},
  consignes:{...p.consignes},
  // Toutes les consignes de la fenêtre Équipe, par groupe : plan de jeu (match en pause) puis consignes en direct.
  groupes:CONSIGNES_GROUPES.map(([id,label])=>({id,label})),
  axes:[...Object.entries(CONSIGNES_PLAN).map(([id,c])=>({id,groupe:c.groupe,label:c.label,aide:c.aide,pause:true,valeur:planValeur(l,id),options:planOptions(id)})).filter(a=>a.options.length),
   ...Object.entries(CONSIGNES).map(([id,c])=>({id,groupe:c.groupe,label:c.label,aide:c.aide,pause:false,valeur:p.consignes[id]??CONSIGNES_NEUTRES[id],options:c.valeurs.map(([v,t])=>({id:v,label:t}))}))]
   .sort((a,b)=>CONSIGNES_GROUPES.findIndex(g=>g[0]===a.groupe)-CONSIGNES_GROUPES.findIndex(g=>g[0]===b.groupe)),
  bilans:Object.keys(CONSIGNES).map(a=>pilotageBilan(l,a)).filter(Boolean),
  joueurs,
  moral:pilotageMoralProjection(l),
  journal:p.journal.slice(-8),
  cris:pilotageCrisProjection(l),
  // Avis du staff en attente (bouton « Appliquer ces consignes ») et rôles en direct (onglet Rôles).
  staff:(()=>{const a=staffAvisEnAttente(l);return {niveau:niveauStaff(),minute:p.staffAvis?.minute??null,
   propositions:a.map(x=>({...x,label:CONSIGNES[x.axe].label,valeurLabel:consigneLabel(x.axe,x.valeur),actuelLabel:consigneLabel(x.axe,p.consignes[x.axe]??CONSIGNES_NEUTRES[x.axe])}))}})(),
  // Conseil de plan de jeu de Gabi (bulle), vu selon sa compétence ; null sans avis.
  planAvis:pilotagePlanAvis(l),
  roles:typeof playerRolesLive==='function'?playerRolesLive(l):null,
  // File « prochain arrêt de jeu », rôles du poste et consignes individuelles (native/engine/match-arrets.cjs).
  ...(typeof CDMatchArrets!=='undefined'?{arrets:CDMatchArrets.projection(l)}:{}),
  // Avis du staff sur chaque cran, en tendance (fenêtre des consignes en direct).
  avisCrans:pilotageAvisCrans(l),
  ...(()=>{const prev=pilotagePrevision(l);return {fatigue:[...prev].sort((a,b)=>a.prevue-b.prevue).slice(0,4),conseilChangement:pilotageConseilChangement(l,prev)}})(),
  // Banc adverse : consignes en cours (ce que son jeu laisse voir), derniers changements, tons de ses causeries.
  adversaire:{consignes:{...CONSIGNES_NEUTRES,...(p.consignesAdverses||{})},derniers:(p.adversaire?.derniers||[]).slice(-5).map(x=>({...x})),
   causeries:Object.fromEntries(Object.entries(p.adversaire?.causeries||{}).map(([ph,t])=>[ph,{ton:t,label:TONS_LABELS[t]||t}]))}
 };
}
if(typeof module!=='undefined'&&module.exports)module.exports={MORAL_DEPART,MORAL_FAITS,MORAL_PALIERS,moralEffet,ARBITRES,arbitreDuMatch,arbitreResume,CONSIGNES,CONSIGNES_GROUPES,CONSIGNES_PLAN,CRIS,CRIS_JOUEUR,TONS_CAUSERIE,TONS_LABELS,PILOTAGE_ETATS};
