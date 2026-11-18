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

// Consignes en direct : trois crans par axe, le cran du milieu est neutre.
const CONSIGNES={
 // Libellés courts : la tuile Consignes doit rester lisible en 1280×720 (capture du 18/11).
 piedJeu:{label:'Jeu au pied',valeurs:[['moins','Garder'],['normal','Équilibré'],['plus','Occuper']]},
 rucks:{label:'Rucks',valeurs:[['prudente','Prudence'],['normale','Normale'],['agressive','Contester']]},
 discipline:{label:'Discipline',valeurs:[['stricte','Zéro faute'],['normale','Normale'],['limite','À la limite']]},
 rythme:{label:'Rythme',valeurs:[['lent','Ralentir'],['normal','Normal'],['rapide','Accélérer']]},
 touche:{label:'Touche',valeurs:[['sure','Sûre'],['normale','Normale'],['risquee','Risquée']]}
};
const CONSIGNES_NEUTRES=Object.fromEntries(Object.entries(CONSIGNES).map(([k,c])=>[k,c.valeurs[1][0]]));
function consigneLabel(axe,valeur){return CONSIGNES[axe]?.valeurs.find(v=>v[0]===valeur)?.[1]||valeur}

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
  pertes:t.handErrors||0,arraches:to.handErrors||0,touches:s.lineouts||0,touchesGagnees:s.lineoutsWon||0,penalitesAdverses:l.stats[o].penalties||0};
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
const pilConsigne=(l,side,axe)=>!pilotageActif(l)?null:side===l.userSide?l.pilotage.consignes[axe]:l.pilotage.consignesAdverses?.[axe]??null;
// Ce que le manager voit changer chez l'adversaire (le jeu sur le terrain, pas un ordre entendu).
const CONSIGNES_ADVERSES_VUES={
 piedJeu:{moins:'garde le ballon en main',normal:'revient à un jeu au pied équilibré',plus:'occupe le terrain au pied'},
 rucks:{prudente:'ne conteste plus les rucks',normale:'conteste les rucks normalement',agressive:'conteste chaque ruck'},
 discipline:{stricte:'resserre sa discipline',normale:'relâche un peu sa discipline',limite:'joue à la limite'},
 rythme:{lent:'ralentit le jeu',normal:'revient à un rythme normal',rapide:'accélère le rythme'},
 touche:{sure:'assure ses lancers en touche',normale:'varie ses lancers en touche',risquee:'vise le fond d\'alignement'}
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
// Probabilité de faute de l'équipe `fautif` : 'jeu' (en défense : hors-jeu, rucks), 'attaque' (ballon non libéré).
function pilotageFoul(l,fautif,kind){
 if(!pilotageActif(l))return 1;
 const a=l.pilotage.arbitre;let f=kind==='attaque'?pilSev(a.rucks,.08):pilSev(a.horsJeu,.04)*pilSev(a.rucks,.04);
 const r=pilConsigne(l,fautif,'rucks'),d=pilConsigne(l,fautif,'discipline'),y=pilConsigne(l,fautif,'rythme');
 if(kind==='jeu'){
  // Contester chaque ruck coûte plus cher devant un arbitre pointilleux sur les rucks.
  if(r==='agressive')f*=1+.22*pilSev(a.rucks,.2);else if(r==='prudente')f*=.85;
  if(d==='stricte')f*=.78;else if(d==='limite')f*=1.2;
 }else{
  if(y==='rapide')f*=1.15;else if(y==='lent')f*=.9;
  if(d==='stricte')f*=.85;else if(d==='limite')f*=1.1;
 }
 return f;
}
function pilotageScrumPenalty(l){return pilotageActif(l)?pilSev(l.pilotage.arbitre.melee,.12):1}
function pilotageCard(l){return pilotageActif(l)?pilSev(l.pilotage.arbitre.cartons,.2):1}
// Ballons perdus par l'attaquant `side` (en-avant, ballon arraché).
function pilotageHandFault(l,side){
 if(!pilotageActif(l))return 0;
 const y=pilConsigne(l,side,'rythme'),r=pilConsigne(l,1-side,'rucks'),d=pilConsigne(l,1-side,'discipline');
 return (y==='rapide'?.02:y==='lent'?-.015:0)+(r==='agressive'?.025:r==='prudente'?-.01:0)+(d==='limite'?.01:d==='stricte'?-.005:0);
}
// Avantage du porteur `side` (kind 'attack') : rythme, pression adverse sur les rucks, plateforme de touche.
function pilotageEdge(l,side,kind){
 if(!pilotageActif(l)||kind!=='attack')return 0;
 const y=pilConsigne(l,side,'rythme'),r=pilConsigne(l,1-side,'rucks'),d=pilConsigne(l,1-side,'discipline'),p=l.pilotage.plateforme;
 return (y==='rapide'?.02:y==='lent'?-.02:0)+(r==='agressive'?-.012:r==='prudente'?.012:0)+(d==='stricte'?.012:d==='limite'?-.008:0)+(p&&p.side===side&&l.minute-p.minute<=1?.05:0);
}
function pilotageKick(l,side){
 const k=pilConsigne(l,side,'piedJeu'),y=pilConsigne(l,side,'rythme');
 return (k==='moins'?.55:k==='plus'?1.55:1)*(y==='lent'?1.1:1);
}
function pilotageLineout(l,side){const t=pilConsigne(l,side,'touche');return t==='sure'?.06:t==='risquee'?-.06:0}
// Touche gagnée en fond d'alignement : meilleure plateforme pour l'action suivante.
function pilotageLineoutWon(l,side){if(pilConsigne(l,side,'touche')==='risquee')l.pilotage.plateforme={side,minute:l.minute}}

// Bonus d'attribut d'un joueur du club joué selon son état (causerie) et le cri de la touche en cours.
// Lu à chaque geste : cache par état et par cri.
let PILOTAGE_CACHE={src:null,cri:null,mods:null,ids:null};
function pilotageSkillMod(p,k){
 const l=typeof S!=='undefined'&&S?S.live:null;
 if(!l||l.pilotageVersion!==1||!l.pilotage)return 0;
 const etats=l.pilotage.etats,cri=l.pilotage.cri||null;
 if(PILOTAGE_CACHE.src!==etats||PILOTAGE_CACHE.cri!==cri){
  const mods=new Map();
  for(const [id,e] of Object.entries(etats||{})){const d=PILOTAGE_ETATS[e?.etat];if(d)mods.set(id,d)}
  PILOTAGE_CACHE={src:etats,cri,mods,ids:cri?new Set(cri.ids):null};
 }
 const d=PILOTAGE_CACHE.mods.get(p.id);
 let n=d?d.tous+(d[k]||0):0;
 if(cri&&l.minute<cri.jusqua&&PILOTAGE_CACHE.ids.has(p.id)){
  const c=CRIS[cri.id];
  if(c.apaise&&d&&d.tous<0)n=0;
  n+=Math.round(((c.tous||0)+(c[k]||0))*cri.force);
 }
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
  return {id,label:x.label,note:!tot?'À partir de la '+x.des+'e minute':f===1?x.note:f===.5?'Déjà crié : effet réduit de moitié':'Trop répété : ils n’écoutent plus',disponible:tot&&!l.finished,usure:1-f}})};
}
// Fatigue : le rythme et « Tout donner » usent plus vite (charge par minute, rugby.js).
function pilotageFatigue(l,side){
 if(!pilotageActif(l)||side!==l.userSide)return 1;
 const y=l.pilotage.consignes.rythme,c=l.pilotage.cri;
 return (y==='rapide'?1.12:y==='lent'?.92:1)*(c&&l.minute<c.jusqua&&CRIS[c.id].fatigue||1);
}
// Prévision à 10 minutes, même formule que le moteur (rugby.js, charge × endurance), au rythme actuel.
function pilotagePrevision(l,minutes=10){
 const u=l.userSide,charge=(typeof tacticalLoad==='function'?tacticalLoad(l,u):1)*(typeof meteoNiveau==='function'&&meteoNiveau(l,'chaleur')&&typeof METEO_MATCH!=='undefined'?METEO_MATCH.chaleur.fatigue:1)*pilotageFatigue(l,u);
 return activePlayers(l,u).map(p=>({id:p.id,condition:Math.round(p.condition),prevue:Math.round(Math.max(12,Math.min(100,p.condition-charge*(1+(70-skill(p,'stamina'))*.009)*minutes)))}));
}
// Conseil de Gabi : le joueur qui sera le plus entamé dans 10 minutes, remplacé par le meilleur remplaçant possible.
function pilotageConseilChangement(l,prevision){
 if(l.finished||typeof eligibleChanges!=='function')return null;
 const u=l.userSide,on=l.sheets[u].on;
 for(const x of [...prevision].sort((a,b)=>a.prevue-b.prevue)){
  if(x.prevue>=55)break;
  const slot=on.indexOf(x.id);if(slot<0)continue;
  const options=eligibleChanges(l,u,slot).filter(p=>p.condition>=85).sort((a,b)=>(b.rating||0)-(a.rating||0));
  if(!options.length)continue;
  const sortant=activePlayers(l,u).find(p=>p.id===x.id),entrant=options[0];
  return {outId:x.id,inId:entrant.id,slot,texte:`${sortant?.name||'Le n° '+(slot+1)} (${slot+1}) sera à ${x.prevue} % dans 10 minutes. ${entrant.name} est frais.`};
 }
 return null;
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
function causerieAdverse(l,phase,c,key){
 if(!pilotageActif(l)||!l.pilotage.adversaire||(phase!=='pre'&&phase!=='half'))return null;
 const adv=l.pilotage.adversaire;adv.causeries=adv.causeries||{};
 if(adv.causeries[phase])return adv.causeries[phase];
 const o=1-l.userSide,sh=l.sheets?.[o]||{},effectif=new Map((S.clubs[l.pair[o]]?.players||[]).map(p=>[p.id,p]));
 const joueurs=[...new Set([...(sh.initial||[]),...(sh.bench||[])])].map(id=>effectif.get(id)).filter(Boolean);
 if(!joueurs.length)return null;
 const cx=contexteAdverse(c||{}),ctx={confiance:50,tons:adv.tons||[],niveau:adv.niveau},cle='adverse:'+key;
 const tone=tonDuStaff(joueurs,phase,cx,cle,TONS_CAUSERIE,ctx);
 const etats={...l.pilotage.etats};
 for(const p of joueurs)etats[p.id]={etat:reactionJoueur(p,tone,phase,cx,cle,false,ctx).etat,phase,adverse:true};
 l.pilotage.etats=etats;
 adv.tons=[...(adv.tons||[]),tone];adv.causeries[phase]=tone;
 l.pilotage.journal.push({minute:l.minute,auteur:'adversaire',texte:`Vestiaire ${vestiaireDe(nomAdverse(l))} : discours ${TONS_ADVERSES[tone]} ${phase==='pre'?'avant le match':'à la mi-temps'}.`});
 l.pilotage.journal=l.pilotage.journal.slice(-30);
 return tone;
}

// --- Consignes d'un staff toutes les 5 minutes : celui du manager quand le match lui est confié, celui de
// l'adversaire pendant tout le match. Mêmes règles ; vigilance liée à la compétence (`lv`).
function reglesDuStaff(l,side,c,lv,graine,recent,maintenant,poser){
 const voit=k=>(pilotageHash(graine+l.minute+'|'+k)%100)<Math.round(25+(lv-45)*1.5);
 const a=l.pilotage.arbitre,ecart=l.score[side]-l.score[1-side];
 if(l.minute<=5&&a.rucks>=4&&voit('arbitre-rucks'))poser('rucks','prudente');
 if(maintenant.penalites-recent.penalites>=2&&c.discipline!=='stricte'&&voit('discipline'))poser('discipline','stricte');
 const touchesPerdues=(maintenant.touches-recent.touches)-(maintenant.touchesGagnees-recent.touchesGagnees);
 if(touchesPerdues>=2&&c.touche!=='sure'&&voit('touche'))poser('touche','sure');
 if(l.minute>=55&&ecart<0&&voit('poursuite')){poser('rythme','rapide');poser('piedJeu','moins')}
 else if(l.minute>=65&&ecart>0&&ecart<=10&&voit('gestion')){poser('piedJeu','plus');poser('rythme','lent')}
}
function pilotageStaff(l){
 if(!pilotageActif(l)||l.finished||l.minute===l.pilotage.staffMinute||l.minute%5)return;
 l.pilotage.staffMinute=l.minute;
 const recent=l.pilotage.staffReleve||pilotageReleve(l),maintenant=pilotageReleve(l);
 l.pilotage.staffReleve=maintenant;
 reglesDuStaff(l,l.userSide,l.pilotage.consignes,niveauStaff(),l.worldContext.id+'|',recent,maintenant,(axe,v)=>setConsigne(l,axe,v,'staff'));
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

// --- Projection pour l'écran 2D ---
function pilotageBilan(l,axe){
 const v=l.pilotage.consignes[axe],r=l.pilotage.releves[axe];if(!r||v===CONSIGNES_NEUTRES[axe])return null;
 const m=pilotageReleve(l),d=k=>m[k]-r[k],pl=(n,s,p)=>n+' '+(n>1?p:s);
 const morceaux={
  rucks:[pl(d('penalites'),'pénalité','pénalités'),pl(d('arraches'),'ballon arraché','ballons arrachés')],
  discipline:[pl(d('penalites'),'pénalité','pénalités'),pl(d('cartons'),'carton','cartons')],
  piedJeu:[pl(d('coups'),'coup de pied','coups de pied'),pl(d('metres'),'mètre gagné','mètres gagnés')],
  rythme:[pl(d('porteurs'),'temps de jeu','temps de jeu'),pl(d('pertes'),'ballon perdu','ballons perdus')],
  touche:[`${d('touchesGagnees')}/${d('touches')} touche${d('touches')>1?'s':''} gagnée${d('touchesGagnees')>1?'s':''}`]
 }[axe];
 return {axe,valeur:v,depuis:l.pilotage.depuis[axe],texte:`${CONSIGNES[axe].label} « ${consigneLabel(axe,v)} » depuis ${l.pilotage.depuis[axe]}′ : ${morceaux.join(', ')}.`};
}
function pilotageProjection(l){
 if(!pilotageActif(l))return null;
 const p=l.pilotage,joueurs={};
 // États du club joué seulement : ceux des joueurs adverses restent dans le vestiaire adverse.
 for(const [id,e] of Object.entries(p.etats||{}))if(!e?.adverse)joueurs[id]={etat:e.etat,label:PILOTAGE_ETATS[e.etat]?.label||'',phase:e.phase,confiance:confianceManager(id)};
 return {
  arbitre:{...p.arbitre},
  consignes:{...p.consignes},
  axes:Object.entries(CONSIGNES).map(([id,c])=>({id,label:c.label,valeur:p.consignes[id],options:c.valeurs.map(([v,t])=>({id:v,label:t}))})),
  bilans:Object.keys(CONSIGNES).map(a=>pilotageBilan(l,a)).filter(Boolean),
  joueurs,
  journal:p.journal.slice(-8),
  cris:pilotageCrisProjection(l),
  ...(()=>{const prev=pilotagePrevision(l);return {fatigue:[...prev].sort((a,b)=>a.prevue-b.prevue).slice(0,4),conseilChangement:pilotageConseilChangement(l,prev)}})(),
  // Banc adverse : consignes en cours (ce que son jeu laisse voir), derniers changements, tons de ses causeries.
  adversaire:{consignes:{...CONSIGNES_NEUTRES,...(p.consignesAdverses||{})},derniers:(p.adversaire?.derniers||[]).slice(-5).map(x=>({...x})),
   causeries:Object.fromEntries(Object.entries(p.adversaire?.causeries||{}).map(([ph,t])=>[ph,{ton:t,label:TONS_LABELS[t]||t}]))}
 };
}
if(typeof module!=='undefined'&&module.exports)module.exports={ARBITRES,arbitreDuMatch,arbitreResume,CONSIGNES,CRIS,TONS_CAUSERIE,TONS_LABELS,PILOTAGE_ETATS};
