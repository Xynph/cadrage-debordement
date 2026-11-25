'use strict';
// File « prochain arrêt de jeu » et pilotage individuel en direct (idée FM27 n° 32, choix de Léo du 23/11/2026).
//
// Sur un vrai terrain, l'entraîneur ne change rien pendant que le ballon vit : un remplacement, un rôle, une consigne
// individuelle ou un réglage du plan de jeu demandés en direct attendent le PROCHAIN ARRÊT DE JEU (essai, pénalité,
// touche, mêlée, sortie en touche, carton, coup d'envoi, mi-temps…). Ce module tient cette file pour le match du
// manager en carrière Monde (pilotage actif, dist/match-pilotage.js) et l'applique à la fin de la minute du moteur
// qui contient un arrêt (pilotageMinute). À la mi-temps ou avant le coup d'envoi, le ballon est déjà mort : le
// changement part tout de suite. Les matchs sans pilotage (anciens modes, IA contre IA) gardent leurs règles.
//
// API commune (globalThis.CDMatchArrets), aussi pour les idées 33 (plans de jeu) et 35 (conseils de l'adjoint) :
//   ajouter(l, change, auteur='manager') → entrée en file ({cle,…}), {applique:true} si le ballon est mort, {annule:true}
//     si le changement ramène l'état actuel ; une demande de même clé remplace la précédente.
//   retirer(l, cle) ; file(l) ; appliquer(l, cause) ; apresMinute(l) (branché sur la minute du moteur) ; projection(l).
// Changements : {type:'remplacement', slot, inId} · {type:'role', id, role|null} · {type:'consignes', id, valeurs:[…]}
//   · {type:'responsabilite', role:'buteur'|'secours'|'lanceur'|'pied', id|null} · {type:'consigne', axe, valeur}
//   · {type:'ailes'} (permuter les ailes : nos deux ailiers, n° 11 et 14, échangent leurs côtés ; redemandé avant
//   l'arrêt, la demande s'annule ; redemandé après, ils reprennent leur côté)
//   (consignes collectives en direct et plan de jeu : planAttaque, systemeDefense, penalites). `auteur` : 'manager',
//   'adjoint' (conseil de Gabi appliqué) ou 'staff'.
//
// Rôles du poste (trois par poste, mêmes identifiants que native/godot/ui/immersive08/fiche_roles.gd) et consignes
// individuelles agissent VRAIMENT : chaque rôle et chaque consigne déplacent l'accent du joueur (attributs du moteur,
// jeu au pied, réussite des temps de jeu, ballons perdus ou arrachés, fautes, mètres, touche, mêlée, fatigue). Le rôle
// « naturel » (rôle choisi par le club s'il est de ce poste, sinon meilleure note du poste) est la référence du moteur : seul l'écart avec lui compte, et un rôle moins
// adapté au joueur coûte un peu d'efficacité. Effets modérés (étalonnés dans tests/match-arrets.cjs sur des lots de
// matchs, mêmes graines), avec une part de hasard : chaque joueur applique la consigne plus ou moins bien (réceptivité
// tirée de l'empreinte du match, sans toucher au flux Math.random). Rien n'est chiffré à l'écran (principe
// d'incertitude) : la projection ne donne que les choix et la file.
//
// Numéros : `live.numeros` (model.cjs) donne le vrai numéro de feuille (1 à 23) de chaque joueur des deux camps ; un
// remplaçant entré garde le sien. Moral des remplaçants : suivi depuis le banc (dist/match-pilotage.js, pilotageMoral).
//
// Sauvegarde : tout vit dans le direct (l.pilotage.file, l.pilotage.arrets, l.pilotage.indiv), absent des anciennes
// rencontres ; validate n'impose rien quand ces champs manquent.
const files=Object.freeze([]),commands=Object.freeze(['file_arret']);
function factory(){
 // Faits du moteur qui arrêtent le jeu (types d'évènements et sortes de scène).
 const ARRET_TYPES=new Set(['try','penalty','goal','miss','card','sub','break','end','restart','setup']);
 const ARRET_SORTES=new Set(['touch','ingoal','kickoff','lineout','scrum','try','penalty','goal','card']);
 const MAX_FILE=40,MAX_APPLIQUES=16,MAX_CONSIGNES=2;
 const FAMILLE=['pilier','talonneur','pilier','deuxieme','deuxieme','aile','aile','huit','demi','ouvreur','ailier','centre','centre','ailier','arriere'];
 // [id, famille, nom, [4 qualités clés], [4 utiles]] : même table que fiche_roles.gd (test d'égalité des identifiants).
 const ROLES=[
  ['pilier-conquerant','pilier','Conquérant',['scrumTechnique','strength','maul','endurance'],['lineoutLift','ruckClearout','tackling','discipline']],
  ['pilier-mobile','pilier','Mobile',['ballCarry','workRate','tackling','endurance'],['offload','ruckClearout','receiving','acceleration']],
  ['pilier-deblayeur','pilier','Déblayeur',['ruckClearout','strength','tackling','workRate'],['jackal','maul','explosiveness','discipline']],
  ['talon-lanceur','talonneur','Lanceur',['lineoutThrow','hooking','scrumTechnique','composure'],['maul','strength','discipline','decisions']],
  ['talon-gratteur','talonneur','Gratteur',['jackal','tackling','ballCarry','workRate'],['acceleration','offload','anticipation','ruckClearout']],
  ['talon-perforateur','talonneur','Perforateur',['ballCarry','strength','explosiveness','offload'],['hooking','lineoutThrow','endurance','evasion']],
  ['deux-sauteur','deuxieme','Sauteur',['lineoutJump','jumping','aerialAbility','decisions'],['lineoutLift','maul','receiving','anticipation']],
  ['deux-pousseur','deuxieme','Pousseur',['scrumTechnique','strength','ruckClearout','maul'],['tackling','endurance','lineoutLift','workRate']],
  ['deux-mobile','deuxieme','Mobile',['workRate','ballCarry','tackling','endurance'],['offload','passing','acceleration','lineoutJump']],
  ['aile-gratteur','aile','Gratteur',['jackal','tackling','anticipation','workRate'],['positioning','ruckClearout','acceleration','discipline']],
  ['aile-perforateur','aile','Perforateur',['ballCarry','explosiveness','offload','strength'],['lineoutJump','workRate','evasion','endurance']],
  ['aile-plaqueur','aile','Plaqueur',['tackling','workRate','endurance','positioning'],['anticipation','strength','ruckClearout','discipline']],
  ['huit-porteur','huit','Porteur',['ballCarry','strength','offload','explosiveness'],['scrumTechnique','ballHandling','endurance','evasion']],
  ['huit-liant','huit','Liant',['ballHandling','decisions','passing','vision'],['teamwork','lineoutJump','receiving','offload']],
  ['huit-meneur','huit','Meneur',['leadership','decisions','tackling','lineoutJump'],['discipline','composure','workRate','scrumTechnique']],
  ['demi-eclaireur','demi','Éclaireur',['acceleration','evasion','anticipation','ballCarry'],['passing','decisions','agility','receiving']],
  ['demi-animateur','demi','Animateur',['passing','decisions','vision','teamwork'],['kickAccuracy','leadership','composure','ballHandling']],
  ['demi-tacticien','demi','Tacticien',['kickDistance','kickAccuracy','passing','decisions'],['kickChase','composure','vision','positioning']],
  ['ouvreur-stratege','ouvreur','Stratège',['kickDistance','kickAccuracy','decisions','vision'],['goalAccuracy','composure','positioning','leadership']],
  ['ouvreur-attaquant','ouvreur','Attaquant',['passing','vision','evasion','ballHandling'],['acceleration','decisions','offload','agility']],
  ['ouvreur-buteur','ouvreur','Buteur',['goalAccuracy','kickAccuracy','composure','kickDistance'],['decisions','discipline','positioning','passing']],
  ['centre-perceur','centre','Perceur',['ballCarry','strength','evasion','explosiveness'],['offload','tackling','acceleration','receiving']],
  ['centre-distributeur','centre','Distributeur',['passing','vision','ballHandling','decisions'],['kickDistance','receiving','offload','tackling']],
  ['centre-verrou','centre','Verrou',['tackling','positioning','anticipation','jackal'],['workRate','strength','decisions','discipline']],
  ['ailier-finisseur','ailier','Finisseur',['topSpeed','acceleration','evasion','agility'],['receiving','ballCarry','composure','offload']],
  ['ailier-chasseur','ailier','Chasseur',['kickChase','aerialAbility','tackling','topSpeed'],['workRate','positioning','jumping','receiving']],
  ['ailier-perforateur','ailier','Perforateur',['ballCarry','strength','explosiveness','evasion'],['topSpeed','offload','receiving','tackling']],
  ['arriere-relanceur','arriere','Relanceur',['evasion','topSpeed','receiving','vision'],['passing','acceleration','agility','decisions']],
  ['arriere-rempart','arriere','Dernier rempart',['aerialAbility','positioning','tackling','receiving'],['kickDistance','composure','anticipation','jumping']],
  ['arriere-botteur','arriere','Botteur',['kickDistance','kickAccuracy','aerialAbility','positioning'],['goalAccuracy','decisions','composure','kickChase']]
 ];
 const ROLE=new Map(ROLES.map(r=>[r[0],r]));
 // Accent de chaque rôle, dans le vocabulaire des effets ci-dessous (écart compté par rapport au rôle naturel).
 // kick : facteur de fréquence du jeu au pied (+0,1 = 10 %) ; edge : réussite des temps de jeu en attaque ;
 // def : réussite des temps de jeu adverses en moins ; hand : ballons perdus en attaque ; handOpp : ballons arrachés à
 // l'adversaire ; foul : facteur de fautes de jeu ; gain : mètres d'un temps de jeu réussi ; lineout : touche gagnée ;
 // melee : penchant de la mêlée ; maul : essai sur ballon porté ; fatigue : énergie perdue en plus par minute ;
 // skills : points d'attribut du moteur pour ce joueur.
 const EFFETS_ROLES={
  'pilier-conquerant':{melee:.03,skills:{scrum:3,speed:-1}},
  'pilier-mobile':{edge:.003,gain:.5,skills:{speed:2,pass:1,scrum:-2}},
  'pilier-deblayeur':{handOpp:.004,skills:{power:2,tackle:1,scrum:-1}},
  'talon-lanceur':{lineout:.03,skills:{lineout:3}},
  'talon-gratteur':{handOpp:.005,foul:.03,skills:{tackle:2,lineout:-2}},
  'talon-perforateur':{gain:.8,edge:.002,skills:{power:2,lineout:-2}},
  'deux-sauteur':{lineout:.03,skills:{lineout:2,power:-1}},
  'deux-pousseur':{melee:.03,maul:.02,skills:{scrum:2,power:1,speed:-1}},
  'deux-mobile':{edge:.003,def:.002,skills:{speed:2,stamina:1,scrum:-2}},
  'aile-gratteur':{handOpp:.006,foul:.04,skills:{tackle:1}},
  'aile-perforateur':{gain:1,edge:.003,hand:.002,skills:{power:2,tackle:-1}},
  'aile-plaqueur':{def:.004,skills:{tackle:3,pass:-1}},
  'huit-porteur':{gain:1,edge:.003,skills:{power:2}},
  'huit-liant':{edge:.004,hand:-.003,skills:{pass:2,power:-1}},
  'huit-meneur':{foul:-.04,skills:{mental:2,discipline:2}},
  'demi-eclaireur':{edge:.004,gain:.5,kick:-.08,skills:{speed:2}},
  'demi-animateur':{edge:.003,hand:-.003,skills:{pass:2}},
  'demi-tacticien':{kick:.15,edge:-.002,skills:{kick:2}},
  'ouvreur-stratege':{kick:.15,skills:{kick:2,pass:-1}},
  'ouvreur-attaquant':{edge:.006,hand:.004,kick:-.12,skills:{pass:2}},
  'ouvreur-buteur':{skills:{goal:3,pass:-1}},
  'centre-perceur':{gain:1,edge:.003,skills:{power:2,pass:-1}},
  'centre-distributeur':{edge:.004,hand:-.002,skills:{pass:2,power:-1}},
  'centre-verrou':{def:.005,handOpp:.003,skills:{tackle:2}},
  'ailier-finisseur':{edge:.004,skills:{speed:2,tackle:-1}},
  'ailier-chasseur':{def:.002,handOpp:.002,skills:{tackle:1,speed:1}},
  'ailier-perforateur':{gain:1,skills:{power:2,speed:-1}},
  'arriere-relanceur':{edge:.005,kick:-.1,hand:.003,skills:{speed:1}},
  'arriere-rempart':{def:.004,skills:{tackle:2}},
  'arriere-botteur':{kick:.12,skills:{kick:2,goal:1}}
 };
 // Consignes individuelles proposées par famille de poste (libellés de l'écran) et paires qui s'excluent.
 const CONSIGNES_INDIV={
  avant:[['porter','Porter davantage'],['gratter','Gratter au sol'],['plaquerBas','Plaquer bas'],['regroupement','Rester au regroupement']],
  demi:[['pied','Jouer au pied'],['accelerer','Accélérer le jeu'],['avants','Faire jouer les avants'],['intervalle','Chercher l’intervalle']],
  ouvreur:[['pied','Jouer au pied'],['aPlat','Jouer à plat'],['attaquerLigne','Attaquer la ligne'],['occuper','Occuper le terrain']],
  trois:[['intervalle','Chercher l’intervalle'],['aile','Rester sur l’aile'],['monterVite','Monter vite'],['pied','Jouer au pied']],
  arriere:[['relancer','Relancer'],['pied','Jouer au pied'],['intercaler','S’intercaler'],['couverture','Rester en couverture']]
 };
 const EXCLUS={demi:[['pied','accelerer']],ouvreur:[['pied','aPlat'],['aPlat','occuper']],trois:[['aile','intervalle']],arriere:[['relancer','pied'],['intercaler','couverture']],avant:[['porter','regroupement']]};
 const EFFETS_CONSIGNES={
  'avant:porter':{gain:1.2,edge:.004,hand:.004,fatigue:.05,skills:{power:2}},
  'avant:gratter':{handOpp:.008,foul:.06,fatigue:.03,skills:{tackle:1}},
  'avant:plaquerBas':{def:.004,foul:-.02,skills:{tackle:3,power:-1}},
  'avant:regroupement':{def:.002,handOpp:.003,edge:-.002,skills:{tackle:1}},
  'demi:pied':{kick:.18,edge:-.002},
  'demi:accelerer':{edge:.006,hand:.006,fatigue:.03},
  'demi:avants':{edge:-.002,gain:1,hand:-.004},
  'demi:intervalle':{edge:.004,gain:.8,hand:.003},
  'ouvreur:pied':{kick:.25,edge:-.003,hand:-.003},
  'ouvreur:aPlat':{edge:.008,hand:.008},
  'ouvreur:attaquerLigne':{edge:.005,gain:1,hand:.003,fatigue:.04},
  'ouvreur:occuper':{kick:.1,skills:{kick:3}},
  'trois:intervalle':{edge:.004,gain:1,hand:.004},
  'trois:aile':{edge:.003,def:-.002},
  'trois:monterVite':{def:.005,foul:.04,fatigue:.04},
  'trois:pied':{kick:.06,skills:{kick:1}},
  'arriere:relancer':{edge:.006,hand:.005,kick:-.15},
  'arriere:pied':{kick:.12,edge:-.002},
  'arriere:intercaler':{edge:.006,def:-.002,fatigue:.04},
  'arriere:couverture':{def:.004,edge:-.004}
 };
 // Bornes de l'équipe (somme des joueurs) : un XV entier sur la même consigne reste dans l'ordre d'une consigne collective.
 const BORNES={kick:[-.35,.45],edge:[-.03,.035],def:[-.02,.03],hand:[-.02,.03],handOpp:[0,.03],foul:[-.12,.2],gain:[-2,4],lineout:[-.04,.05],melee:[-.06,.06],maul:[-.03,.04]};
 const CLES=Object.keys(BORNES);
 const check=(ok,message='Changement en direct invalide.')=>{if(!ok)throw Error(message);};
 const obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const famillePoste=slot=>slot<=7?'avant':slot===8?'demi':slot===9?'ouvreur':slot===14?'arriere':'trois';
 const hash=t=>(typeof pilotageHash==='function'?pilotageHash(t):0)/4294967296;
 const matchKey=l=>[typeof S!=='undefined'&&S?S.season:0,l?.worldContext?.id??'match',(l?.pair||[]).join('-')].join('|');
 function actif(l){return !!(l&&l.pilotageVersion===1&&l.pilotage&&!l.pilotage.cotes&&l.userSide>=0&&!l.finished);}
 // Le ballon est déjà mort : avant le coup d'envoi, à la mi-temps.
 function ballonMort(l){return (Number(l.minute)||0)<=0||(typeof atHalftime==='function'&&atHalftime(l));}
 function etat(l){
  const p=l.pilotage;
  if(!Array.isArray(p.file))p.file=[];
  if(!obj(p.arrets))p.arrets={ev:(l.events||[]).length,n:0,appliques:[]};
  if(!obj(p.indiv))p.indiv={roles:{},consignes:{},v:0};
  return p;
 }
 // --- Rôles : note au rôle (même calcul que l'écran), rôle naturel du poste ---
 function attributs(p){
  try{
   if(p?.attributesV2&&Object.keys(p.attributesV2).length===36)return p.attributesV2;
   if(typeof nativeAttributeStore!=='undefined'&&typeof p?.nativeAttributesV1==='string')return nativeAttributeStore.project(p).attributesV2;
  }catch(e){}
  return null;
 }
 function noteRole(p,r){
  const v=attributs(p);if(!v||!r)return -1;let t=0,w=0;
  for(let k=0;k<2;k++)for(const c of r[3+k]){const x=v[c];if(!Number.isFinite(x))return -1;t+=(k?1:2)*x;w+=k?1:2;}
  return w?t/w:-1;
 }
 function rolesDuPoste(slot){return ROLES.filter(r=>r[1]===FAMILLE[slot]);}
 // Rôle de départ au poste : celui que le club a choisi pour le joueur (p.roleId, role-joueur.cjs) quand il est de ce
 // poste, sinon le meilleur rôle du poste (note des 8 qualités).
 function roleNaturel(p,slot){const choisi=typeof p?.roleId==='string'?ROLE.get(p.roleId):null;if(choisi&&choisi[1]===FAMILLE[slot])return choisi;let best=null,note=-2;for(const r of rolesDuPoste(slot)){const n=noteRole(p,r);if(n>note){note=n;best=r;}}return best;}
 // --- Effets : un joueur, puis l'équipe (cache par minute et par version des choix) ---
 function ajout(acc,e,f){if(!e)return;for(const k of CLES)if(e[k])acc[k]=(acc[k]||0)+e[k]*f;if(e.fatigue)acc.fatigue=(acc.fatigue||0)+e.fatigue*f;if(e.skills)for(const [k,v] of Object.entries(e.skills))acc.skills[k]=(acc.skills[k]||0)+v*f;}
 // Réceptivité d'un joueur à un choix : entre 0,7 et 1,3, tirée de l'empreinte du match (jamais montrée).
 function receptivite(l,id,choix){return .7+.6*hash('arret|'+matchKey(l)+'|'+id+'|'+choix);}
 function effetJoueur(l,p,slot){
  const ind=l.pilotage.indiv,acc={skills:{}},choix=ind.roles[p.id],cons=ind.consignes[p.id];
  if(choix){
   const r=ROLE.get(choix),nat=roleNaturel(p,slot);
   if(r&&r[1]===FAMILLE[slot]&&nat&&nat[0]!==choix){
    const f=receptivite(l,p.id,choix);
    ajout(acc,EFFETS_ROLES[choix],f);ajout(acc,EFFETS_ROLES[nat[0]],-f);
    // Rôle moins adapté que son rôle naturel : un peu d'efficacité perdue sur tous ses gestes.
    const ecart=noteRole(p,nat)-noteRole(p,r);if(ecart>0)acc.skills.tous=(acc.skills.tous||0)-Math.min(2,Math.floor(ecart/6));
   }
  }
  if(Array.isArray(cons))for(const c of cons)ajout(acc,EFFETS_CONSIGNES[famillePoste(slot)+':'+c],receptivite(l,p.id,c));
  return acc;
 }
 let CACHE={l:null,cle:'',equipe:null,joueurs:null};
 function equipe(l){
  if(!actif(l))return null;
  const ind=l.pilotage.indiv;if(!ind||(!Object.keys(ind.roles).length&&!Object.keys(ind.consignes).length))return null;
  const sh=l.sheets[l.userSide],cle=l.minute+'|'+ind.v+'|'+sh.on.join(',')+'|'+(sh.cards||[]).length;
  if(CACHE.l===l&&CACHE.cle===cle)return CACHE;
  const tot={},joueurs=new Map(),actifs=typeof activePlayers==='function'?activePlayers(l,l.userSide):[];
  for(const p of actifs){
   const slot=sh.on.indexOf(p.id);if(slot<0)continue;
   const e=effetJoueur(l,p,slot);joueurs.set(p.id,e);
   for(const k of CLES)if(e[k])tot[k]=(tot[k]||0)+e[k];
  }
  for(const k of CLES)tot[k]=Math.max(BORNES[k][0],Math.min(BORNES[k][1],tot[k]||0));
  CACHE={l,cle,equipe:tot,joueurs};
  return CACHE;
 }
 // --- Permuter les ailes : chaque ailier fait face à l'ailier adverse de sa touche (notre 11 face à leur 14, notre 14 face
 // à leur 11). Duel d'un attaquant contre son vis-à-vis : sa vitesse contre le plaquage et la vitesse du défenseur ;
 // au-delà de `seuil` points, l'avantage croît comme le carré de l'écart (`k`), plafonné à `max` : un gros décalage
 // rapporte bien plus que deux petits, c'est ce que la permutation va chercher.
 // Seul l'écart avec le placement d'avant compte (comme pour les rôles) : un ailier rapide envoyé face à leur ailier
 // lent rapporte, l'inverse coûte, et nos ailiers défendent aussi face à d'autres. L'adversaire s'adapte en
 // `adaptation` minutes (il garde `residuel` de l'effet) ; réceptivité 0,7 à 1,3 tirée de l'empreinte du match.
 // Valeurs de jeu, étalonnées dans tests/match-cris-joueur.cjs (lots de matchs, mêmes graines).
 const AILES=Object.freeze({seuil:4,k:.0004,max:.06,adaptation:25,residuel:.4});
 const AILE_G=10,AILE_D=13;
 function ailesPermutees(l){
  const a=l.pilotage?.ailes,sh=l.sheets?.[l.userSide];
  return !!(a&&Array.isArray(a.ids)&&sh&&sh.on[AILE_G]===a.ids[0]&&sh.on[AILE_D]===a.ids[1]);
 }
 function duelAile(att,def){
  if(!att||!def||typeof skill!=='function')return 0;
  const x=skill(att,'speed')-(skill(def,'tackle')+skill(def,'speed'))/2;
  const e=Math.max(0,x-AILES.seuil);return Math.min(AILES.max,AILES.k*e*e);
 }
 let CACHE_AILES={cle:'',v:null};
 // {att, def} : écart de réussite (temps de jeu) de notre attaque et de la leur, placement actuel moins placement d'avant.
 function ailesEcart(l){
  if(!actif(l)||!ailesPermutees(l))return null;
  const u=l.userSide,o=1-u,sh=l.sheets[u],so=l.sheets[o],on=x=>typeof activePlayers==='function'?activePlayers(l,x.side).find(p=>p.id===x.id)||null:null;
  const cle=l.minute+'|'+sh.on.join(',')+'|'+so.on.join(',')+'|'+(sh.cards||[]).length+'|'+(so.cards||[]).length;
  if(CACHE_AILES.l===l&&CACHE_AILES.cle===cle)return CACHE_AILES.v;
  const g=on({side:u,id:sh.on[AILE_G]}),d=on({side:u,id:sh.on[AILE_D]}),eg=on({side:o,id:so.on[AILE_G]}),ed=on({side:o,id:so.on[AILE_D]});
  const a=l.pilotage.ailes,depuis=Number.isFinite(a.minute)?a.minute:l.minute;
  const f=(.7+.6*hash('ailes|'+matchKey(l)+'|'+a.ids.join('-')+'|'+depuis))*Math.max(AILES.residuel,1-(l.minute-depuis)/AILES.adaptation);
  const att=(duelAile(g,ed)+duelAile(d,eg))-(duelAile(d,ed)+duelAile(g,eg));
  const def=(duelAile(ed,g)+duelAile(eg,d))-(duelAile(ed,d)+duelAile(eg,g));
  const v={att:att*f,def:def*f};
  CACHE_AILES={l,cle,v};
  return v;
 }
 const nous=(l,side)=>actif(l)&&side===l.userSide;
 const val=(l,k)=>equipe(l)?.equipe[k]||0;
 const effets={
  skill(p,k){
   const l=typeof S!=='undefined'&&S?S.live:null;if(!l)return 0;
   const c=equipe(l);if(!c)return 0;const e=c.joueurs.get(p.id);if(!e)return 0;
   return Math.round((e.skills[k]||0)+(e.skills.tous||0));
  },
  kick(l,side){return nous(l,side)?Math.max(.5,1+val(l,'kick')):1;},
  edge(l,side){
   const a=ailesEcart(l);
   return nous(l,side)?val(l,'edge')+(a?a.att:0):actif(l)&&side===1-l.userSide?-val(l,'def')+(a?a.def:0):0;
  },
  hand(l,side){return nous(l,side)?val(l,'hand'):actif(l)&&side===1-l.userSide?val(l,'handOpp'):0;},
  foul(l,side,kind){return nous(l,side)&&kind==='jeu'?Math.max(.6,1+val(l,'foul')):1;},
  gain(l,side){return nous(l,side)?Math.round(val(l,'gain')):0;},
  lineout(l,side){return nous(l,side)?val(l,'lineout'):0;},
  melee(l,side){return actif(l)?(side===l.userSide?1:-1)*val(l,'melee'):0;},
  maul(l,side){return nous(l,side)?val(l,'maul'):0;}
 };
 // Fatigue en plus des joueurs aux consignes ou rôles exigeants (après la minute du moteur).
 function fatigue(l){
  const c=equipe(l);if(!c)return;
  for(const p of activePlayers(l,l.userSide)){const e=c.joueurs.get(p.id);if(e?.fatigue>0)p.condition=Math.max(0,Math.round((p.condition-e.fatigue)*100)/100);}
 }
 // --- La file ---
 function normaliser(l,c){
  check(obj(c)&&typeof c.type==='string','Changement en direct invalide.');
  const sh=l.sheets[l.userSide];
  if(c.type==='remplacement'){
   check(Number.isInteger(c.slot)&&c.slot>=0&&c.slot<15&&typeof c.inId==='string'&&c.inId,'Remplacement invalide.');
   check(typeof eligibleChanges==='function'&&eligibleChanges(l,l.userSide,c.slot).some(x=>x.id===c.inId),'Changement non autorisé pour ces joueurs.');
   return {cle:'remplacement:'+c.slot,type:'remplacement',slot:c.slot,outId:sh.on[c.slot]??null,inId:c.inId};
  }
  if(c.type==='role'){
   check(typeof c.id==='string'&&sh.on.includes(c.id),'Rôle : joueur absent du terrain.');
   const slot=sh.on.indexOf(c.id);
   check(c.role===null||typeof c.role==='string'&&ROLE.get(c.role)?.[1]===FAMILLE[slot],'Rôle inconnu pour ce poste.');
   return {cle:'role:'+c.id,type:'role',id:c.id,role:c.role};
  }
  if(c.type==='consignes'){
   check(typeof c.id==='string'&&sh.on.includes(c.id)&&Array.isArray(c.valeurs)&&c.valeurs.length<=MAX_CONSIGNES,'Consignes individuelles invalides.');
   const fam=famillePoste(sh.on.indexOf(c.id)),ids=CONSIGNES_INDIV[fam].map(x=>x[0]);
   check(c.valeurs.every(v=>ids.includes(v))&&new Set(c.valeurs).size===c.valeurs.length,'Consigne inconnue pour ce poste.');
   check(!(EXCLUS[fam]||[]).some(([a,b])=>c.valeurs.includes(a)&&c.valeurs.includes(b)),'Ces deux consignes s’excluent.');
   return {cle:'consignes:'+c.id,type:'consignes',id:c.id,valeurs:ids.filter(v=>c.valeurs.includes(v))};
  }
  if(c.type==='responsabilite'){
   check(typeof PLAYER_ROLES!=='undefined'&&Object.hasOwn(PLAYER_ROLES,c.role)&&(c.id===null||typeof c.id==='string'&&activePlayers(l,l.userSide).some(p=>p.id===c.id)),'Rôle inconnu ou joueur absent du terrain.');
   return {cle:'responsabilite:'+c.role,type:'responsabilite',role:c.role,id:c.id};
  }
  if(c.type==='consigne'){
   const plan=typeof CONSIGNES_PLAN!=='undefined'&&Object.hasOwn(CONSIGNES_PLAN,c.axe);
   check(plan?planOptions(c.axe).some(o=>o.id===c.valeur):typeof CONSIGNES!=='undefined'&&CONSIGNES[c.axe]?.valeurs.some(v=>v[0]===c.valeur),'Consigne inconnue.');
   return {cle:'consigne:'+c.axe,type:'consigne',axe:c.axe,valeur:c.valeur};
  }
  if(c.type==='ailes'){
   check(sh.on[AILE_G]&&sh.on[AILE_D]&&[AILE_G,AILE_D].every(s=>activePlayers(l,l.userSide).some(p=>p.id===sh.on[s])),'Il faut nos deux ailiers sur le terrain.');
   return {cle:'ailes',type:'ailes',gauche:sh.on[AILE_G],droite:sh.on[AILE_D]};
  }
  throw Error('Changement en direct inconnu.');
 }
 // Le changement ramène-t-il l'état actuel ?
 function dejaEnPlace(l,e){
  const ind=l.pilotage.indiv,sh=l.sheets[l.userSide];
  if(e.type==='role'){const nat=roleNaturel(matchPlayer(l,l.userSide,e.id),sh.on.indexOf(e.id));return (ind.roles[e.id]||nat?.[0]||null)===(e.role||nat?.[0]||null);}
  if(e.type==='consignes')return JSON.stringify(ind.consignes[e.id]||[])===JSON.stringify(e.valeurs);
  if(e.type==='responsabilite')return (l.playerRoles?.[l.userSide]?.[e.role]??null)===e.id;
  if(e.type==='consigne'){const plan=Object.hasOwn(CONSIGNES_PLAN,e.axe);return (plan?planValeur(l,e.axe):l.pilotage.consignes[e.axe])===e.valeur;}
  return false;
 }
 function ajouter(l,change,auteur='manager'){
  check(actif(l),'Changements en direct indisponibles pour ce match.');
  check(['manager','adjoint','staff'].includes(auteur),'Auteur inconnu.');
  const p=etat(l),e=normaliser(l,change);
  // Permuter les ailes une seconde fois avant l'arrêt : la demande s'annule.
  if(e.type==='ailes'&&p.file.some(x=>x.cle==='ailes')){p.file=p.file.filter(x=>x.cle!=='ailes');return {annule:true,cle:e.cle};}
  p.file=p.file.filter(x=>x.cle!==e.cle&&!(e.type==='remplacement'&&x.type==='remplacement'&&x.inId===e.inId));
  if(dejaEnPlace(l,e))return {annule:true,cle:e.cle};
  e.auteur=auteur;e.minute=l.minute;e.n=++p.arrets.n;
  if(ballonMort(l)){const r=appliquerUn(l,e);noter(l,e,r,'arret');return {applique:r===true,cle:e.cle,...(r===true?{}:{raison:r})};}
  check(p.file.length<MAX_FILE,'Trop de changements en attente.');
  p.file.push(e);
  return {...e,enAttente:true};
 }
 function retirer(l,cle){
  if(!actif(l))return false;const p=etat(l),n=p.file.length;
  p.file=p.file.filter(x=>x.cle!==cle);return p.file.length<n;
 }
 // Applique un changement ; rend true, ou la raison du refus (situation changée depuis la demande).
 function appliquerUn(l,e){
  const ind=l.pilotage.indiv,sh=l.sheets[l.userSide];
  try{
   if(e.type==='remplacement'){
    if((sh.on[e.slot]??null)!==e.outId)return 'Le joueur de ce poste a changé.';
    if(!eligibleChanges(l,l.userSide,e.slot).some(x=>x.id===e.inId))return 'Changement devenu impossible.';
    if(!makeSub(l,l.userSide,e.slot,e.inId))return 'Changement refusé.';
    // Le sortant laisse son rôle et ses consignes ; l'entrant part de son rôle naturel.
    delete ind.roles[e.outId];delete ind.consignes[e.outId];ind.v++;
    return true;
   }
   if(e.type==='role'||e.type==='consignes'){
    if(!sh.on.includes(e.id))return 'Le joueur n’est plus sur le terrain.';
    if(e.type==='role'){const nat=roleNaturel(matchPlayer(l,l.userSide,e.id),sh.on.indexOf(e.id));if(!e.role||e.role===nat?.[0])delete ind.roles[e.id];else ind.roles[e.id]=e.role;}
    else if(e.valeurs.length)ind.consignes[e.id]=e.valeurs.slice();else delete ind.consignes[e.id];
    ind.v++;return true;
   }
   if(e.type==='responsabilite')return setPlayerRoleLive(l,e.role,e.id)?true:'Le joueur n’est plus sur le terrain.';
   if(e.type==='ailes'){
    if(sh.on[AILE_G]!==e.gauche||sh.on[AILE_D]!==e.droite)return 'Les ailiers ont changé.';
    if(![AILE_G,AILE_D].every(s=>activePlayers(l,l.userSide).some(p=>p.id===sh.on[s])))return 'Un ailier n’est plus sur le terrain.';
    const retour=ailesPermutees(l);
    sh.on[AILE_G]=e.droite;sh.on[AILE_D]=e.gauche;
    if(retour)delete l.pilotage.ailes;else l.pilotage.ailes={ids:[e.droite,e.gauche],minute:l.minute};
    return true;
   }
   if(e.type==='consigne'){
    if(Object.hasOwn(CONSIGNES_PLAN,e.axe))return plan(l,e.axe,e.valeur);
    return setConsigne(l,e.axe,e.valeur,e.auteur==='staff'?'staff':'manager')?true:'Consigne refusée.';
   }
  }catch(error){return error.message||'Changement refusé.';}
  return 'Changement inconnu.';
 }
 // Plan de jeu au prochain arrêt : mêmes effets que setLiveTactic / setLiveDefence / setPenaltyPolicy, sans exiger la
 // pause (le ballon est mort) ni redessiner l'écran web au milieu de la minute du moteur.
 function plan(l,axe,valeur){
  const u=l.userSide,mine=typeof S!=='undefined'&&S&&S.live===l;
  if(axe==='planAttaque'){if(!Object.hasOwn(TACTICS,valeur))return 'Réglage refusé.';l.tactics[u]=valeur;if(mine)S.tactic=valeur;addEvent(l,`Ta consigne : ${TACTICS[valeur][0]}.`,'tactic',{team:u});return true;}
  if(axe==='systemeDefense'){if(!Object.hasOwn(DEFENCES,valeur)||!l.defences)return 'Réglage refusé.';l.defences[u]=valeur;if(mine)S.defence=valeur;addEvent(l,`Ta défense : ${DEFENCES[valeur][0]}. ${DEFENCES[valeur][1]}`,'tactic',{team:u});return true;}
  if(axe==='penalites'){if(!Object.hasOwn(PENALTY_POLICIES,valeur))return 'Réglage refusé.';l.penaltyPolicies=l.penaltyPolicies||['auto','auto'];l.penaltyPolicies[u]=valeur;addEvent(l,`Ta consigne sur pénalité : ${PENALTY_POLICIES[valeur]}.`,'tactic',{team:u});return true;}
  return 'Réglage refusé.';
 }
 function libelle(l,e){
  const nom=id=>matchPlayer(l,l.userSide,id)?.name||'';
  if(e.type==='remplacement')return `${nom(e.inId)} remplace ${nom(e.outId)||'le joueur exclu'}`;
  if(e.type==='role')return `${nom(e.id)} : ${ROLE.get(e.role)?.[2]||'rôle naturel'}`;
  if(e.type==='consignes'){const fam=CONSIGNES_INDIV[famillePoste(Math.max(0,l.sheets[l.userSide].on.indexOf(e.id)))]||[];return `${nom(e.id)} : ${e.valeurs.map(v=>fam.find(x=>x[0]===v)?.[1]||v).join(', ')||'sans consigne'}`;}
  if(e.type==='responsabilite')return `${PLAYER_ROLES[e.role]?.[0]||e.role} : ${e.id?nom(e.id):'choix du staff'}`;
  if(e.type==='ailes')return `Ailes permutées : ${nom(e.droite)} à gauche, ${nom(e.gauche)} à droite`;
  if(e.type==='consigne'){const plan=Object.hasOwn(CONSIGNES_PLAN,e.axe);return plan?`${CONSIGNES_PLAN[e.axe].label} : ${planOptions(e.axe).find(o=>o.id===e.valeur)?.label||e.valeur}`:`${CONSIGNES[e.axe].label} : ${consigneLabel(e.axe,e.valeur)}`;}
  return '';
 }
 function noter(l,e,r,cause){
  const a=l.pilotage.arrets;
  a.appliques=[...a.appliques,{n:e.n,cle:e.cle,type:e.type,auteur:e.auteur,demande:e.minute,minute:l.minute,cause,ok:r===true,...(r===true?{}:{raison:r}),
   ...(e.type==='remplacement'?{slot:e.slot,outId:e.outId,inId:e.inId}:e.type==='responsabilite'?{role:e.role,id:e.id}:e.type==='consigne'?{axe:e.axe,valeur:e.valeur}:e.type==='ailes'?{gauche:e.gauche,droite:e.droite}:{id:e.id}),texte:libelle(l,e)}].slice(-MAX_APPLIQUES);
  if(r===true&&e.auteur!=='staff'&&Array.isArray(l.pilotage.journal)){l.pilotage.journal.push({minute:l.minute,auteur:e.auteur,texte:'Arrêt de jeu : '+libelle(l,e)+'.'});l.pilotage.journal=l.pilotage.journal.slice(-30);}
 }
 function appliquer(l,cause='arret'){
  if(!actif(l))return 0;const p=etat(l);if(!p.file.length)return 0;
  const file=p.file;p.file=[];let n=0;
  for(const e of file){const r=appliquerUn(l,e);noter(l,e,r,cause);if(r===true)n++;}
  if(typeof syncMatchPresentation==='function'&&n&&l===S?.live)try{syncMatchPresentation(l);}catch(e){}
  return n;
 }
 // Après chaque minute du moteur : un arrêt de jeu dans la minute → la file part ; fatigue des consignes exigeantes.
 function apresMinute(l){
  if(!actif(l)&&!(l?.pilotage?.file?.length&&l.finished))return;
  if(l.finished){l.pilotage.file=[];return;}
  const p=etat(l),ev=l.events||[];let arret=ballonMort(l);
  for(let i=Math.min(p.arrets.ev,ev.length);!arret&&i<ev.length;i++){const e=ev[i];if(ARRET_TYPES.has(e?.type)||ARRET_SORTES.has(e?.scene?.kind))arret=true;}
  fatigue(l);
  if(arret&&p.file.length)appliquer(l,'arret');
  p.arrets.ev=ev.length;
 }
 function projection(l){
  if(!l?.pilotage||l.pilotageVersion!==1||!(l.userSide>=0))return null;
  const p=l.pilotage,sh=l.sheets[l.userSide],ind=p.indiv||{roles:{},consignes:{}};
  const roles={};
  for(const id of sh.on){if(!id)continue;const pl=matchPlayer(l,l.userSide,id),slot=sh.on.indexOf(id),nat=pl?roleNaturel(pl,slot):null;roles[id]={role:ind.roles[id]||nat?.[0]||null,naturel:nat?.[0]||null};}
  return {
   file:(p.file||[]).map(e=>({...e,texte:libelle(l,e)})),
   appliques:(p.arrets?.appliques||[]).map(x=>({...x})),
   roles,consignes:Object.fromEntries(Object.entries(ind.consignes||{}).map(([k,v])=>[k,v.slice()])),
   catalogue:Object.fromEntries(Object.entries(CONSIGNES_INDIV).map(([k,v])=>[k,v.map(([id,label])=>({id,label}))])),
   exclusions:Object.fromEntries(Object.entries(EXCLUS).map(([k,v])=>[k,v.map(x=>x.slice())])),
   maxConsignes:MAX_CONSIGNES,
   // Ailes permutées (ailiers toujours à la place échangée) ; effet jamais chiffré.
   ailes:{permutees:ailesPermutees(l),attente:(p.file||[]).some(e=>e.cle==='ailes')}
  };
 }
 function execute(command,payload){
  check(command==='file_arret','Commande de file inconnue.');
  check(typeof S!=='undefined'&&S&&S.live&&!S.live.finished,'Aucun match en cours.');
  check(obj(payload)&&['ajouter','retirer'].includes(payload.action),'Action de file invalide.');
  if(payload.action==='retirer'){check(typeof payload.cle==='string','Clé de file invalide.');return {fileArret:{retire:retirer(S.live,payload.cle)}};}
  check(obj(payload.change)&&['role','consignes','remplacement','responsabilite','consigne','ailes'].includes(payload.change.type),'Changement en direct invalide.');
  return {fileArret:ajouter(S.live,payload.change,payload.auteur??'manager')};
 }
 function validate(s){
  const p=s?.live?.pilotage;if(!p)return true;
  if(p.file!==undefined)check(Array.isArray(p.file)&&p.file.length<=MAX_FILE&&p.file.every(e=>obj(e)&&typeof e.cle==='string'&&typeof e.type==='string'),'File des arrêts de jeu invalide.');
  if(p.indiv!==undefined)check(obj(p.indiv)&&obj(p.indiv.roles)&&obj(p.indiv.consignes)&&Object.values(p.indiv.roles).every(r=>ROLE.has(r))&&Object.values(p.indiv.consignes).every(v=>Array.isArray(v)&&v.length<=MAX_CONSIGNES),'Rôles et consignes individuelles invalides.');
  if(p.ailes!==undefined)check(obj(p.ailes)&&Array.isArray(p.ailes.ids)&&p.ailes.ids.length===2&&p.ailes.ids.every(x=>typeof x==='string'),'Ailes permutées invalides.');
  if(p.arrets!==undefined)check(obj(p.arrets)&&Array.isArray(p.arrets.appliques)&&p.arrets.appliques.length<=MAX_APPLIQUES,'Journal des arrêts de jeu invalide.');
  return true;
 }
 const api=Object.freeze({actif,ballonMort,ajouter,retirer,appliquer,apresMinute,projection,file:l=>actif(l)?etat(l).file.slice():[],effets,roleNaturel,noteRole,
  ROLES:Object.freeze(ROLES.map(r=>r[0])),ROLES_DETAIL:ROLES,CONSIGNES:CONSIGNES_INDIV,EXCLUS,EFFETS_ROLES,EFFETS_CONSIGNES,MAX_CONSIGNES});
 function installHooks(){globalThis.CDMatchArrets=api;return true;}
 return {project(){return null;},validate,execute,installHooks,...api};
}
module.exports={files,commands,factory};
