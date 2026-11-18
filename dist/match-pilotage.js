// Pilotage du match façon FM (docs/match-pilotage-20261118.md) : arbitre au profil connu, consignes en direct,
// état des joueurs après les causeries, choix du staff quand le match lui est confié.
// Ne concerne que le match du joueur en carrière Monde créé avec `pilotageVersion` (rugbyBegin) : les matchs IA
// et les rencontres créées avant gardent leurs règles. Aucun tirage aléatoire ajouté : la suite des tirages est
// inchangée, seules les probabilités bougent. Coefficients choisis pour le jeu (ordres de grandeur), non mesurés.
var PILOTAGE_RULES=1;

// Corps arbitral fictif (aucun vrai nom). Sévérités de 1 (laisse jouer) à 5 (très pointilleux), 3 = neutre.
const ARBITRES=[
 {id:'castaing',nom:'Julien Castaing',pays:'FR',rucks:4,melee:3,horsJeu:3,cartons:2},
 {id:'dubernet',nom:'Florian Dubernet',pays:'FR',rucks:2,melee:4,horsJeu:3,cartons:3},
 {id:'peyregne',nom:'Yannick Peyrègne',pays:'FR',rucks:3,melee:2,horsJeu:4,cartons:4},
 {id:'saint-criq',nom:'Olivier Saint-Criq',pays:'FR',rucks:5,melee:3,horsJeu:2,cartons:3},
 {id:'escaich',nom:'Benjamin Escaich',pays:'FR',rucks:3,melee:5,horsJeu:3,cartons:2},
 {id:'larrouturou',nom:'Rémi Larrouturou',pays:'FR',rucks:2,melee:2,horsJeu:3,cartons:3},
 {id:'coustal',nom:'Damien Coustal',pays:'FR',rucks:4,melee:3,horsJeu:4,cartons:5},
 {id:'bergeyre',nom:'Hugo Bergeyre',pays:'FR',rucks:3,melee:3,horsJeu:2,cartons:2},
 {id:'arrouy',nom:'Sébastien Arrouy',pays:'FR',rucks:2,melee:4,horsJeu:4,cartons:3},
 {id:'mazars',nom:'Pierre-Louis Mazars',pays:'FR',rucks:4,melee:2,horsJeu:3,cartons:4},
 {id:'claverie',nom:'Antoine Clavérie',pays:'FR',rucks:3,melee:4,horsJeu:2,cartons:3},
 {id:'soubiron',nom:'Mathieu Soubiron',pays:'FR',rucks:3,melee:3,horsJeu:5,cartons:2},
 {id:'pritchard',nom:'Owen Pritchard-Lloyd',pays:'GB',rucks:4,melee:3,horsJeu:3,cartons:3},
 {id:'strachan',nom:'Callum Strachan',pays:'GB',rucks:2,melee:3,horsJeu:4,cartons:2},
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
 return {...a,resume:arbitreResume(a)};
}
function arbitreResume(a){
 const severe=ARBITRE_AXES.filter(([k])=>a[k]>=4).map(([,t])=>t),souple=ARBITRE_AXES.filter(([k])=>a[k]<=2).map(([,t])=>t);
 const liste=x=>x.length>1?x.slice(0,-1).join(', ')+' et '+x.at(-1):x[0];
 const parts=[];
 if(severe.length)parts.push('Pointilleux sur '+liste(severe));
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
 l.pilotage={arbitre:arbitreDuMatch(l.worldContext.id,l.worldContext.competitionId),consignes:{...CONSIGNES_NEUTRES},depuis:{},releves:{},etats:{},journal:[],staffMinute:-1};
}
// Relevé des chiffres utiles du club joué, pour mesurer l'effet d'une consigne depuis son changement.
function pilotageReleve(l){
 const u=l.userSide,o=1-u,s=l.stats[u],t=l.tacticalStats?.[u]||{},to=l.tacticalStats?.[o]||{};
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
const pilConsigne=(l,side,axe)=>pilotageActif(l)&&side===l.userSide?l.pilotage.consignes[axe]:null;


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

// Bonus d'attribut d'un joueur du club joué selon son état (causerie). Lu à chaque geste : cache par état.
let PILOTAGE_CACHE={src:null,mods:null};
function pilotageSkillMod(p,k){
 const l=typeof S!=='undefined'&&S?S.live:null;
 if(!l||l.pilotageVersion!==1||!l.pilotage)return 0;
 const etats=l.pilotage.etats;
 if(PILOTAGE_CACHE.src!==etats){
  const mods=new Map();
  for(const [id,e] of Object.entries(etats||{})){const d=PILOTAGE_ETATS[e?.etat];if(d)mods.set(id,d)}
  PILOTAGE_CACHE={src:etats,mods};
 }
 const d=PILOTAGE_CACHE.mods.get(p.id);
 return d?d.tous+(d[k]||0):0;
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
function reactionAttendue(p,tone,phase,c){
 const {pro,amb,sf,sens}=pilotageTraits(p);
 const base={calm:(60-sf)*.04+.3,demanding:(pro-55)*.04+(amb-55)*.02-(sens-50)*.015,warm:(sens-50)*.03+(55-pro)*.01+.3,
  furious:(amb-55)*.03+(pro-60)*.02-(sens-50)*.04-(60-sf)*.03-.3,protective:(60-sf)*.03+(sens-50)*.02-(amb-55)*.02,assertive:(amb-55)*.03+(sf-60)*.02+.2}[tone]||0;
 const ctx=TON_CONTEXTE[situationCauserie(phase,c)]?.[tone]||0;
 const t=confianceManager(p.id);
 let r=(base+ctx)*(.5+t/100)+(t-50)*.02;
 if((tone==='furious'||tone==='demanding')&&t<35)r-=.8;
 // Un ton répété s'use (la colère surtout).
 const n=tonsRecents().slice(-4).filter(x=>x===tone).length;r-=n*(tone==='furious'?1:.6);
 return r;
}
function reactionJoueur(p,tone,phase,c,key,seul){
 const imprevu=((pilotageHash(p.id+'|'+key+'|'+phase+'|'+tone)%1000)/1000-.5)*1.2;
 const r=Math.max(-3,Math.min(3,(reactionAttendue(p,tone,phase,c)+imprevu)*(seul?1.4:1)));
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
function niveauStaff(){
 const j=typeof staffJudges==='function'?staffJudges(S.club):null;
 const lv=j?Math.max(...Object.values(j).map(x=>Number(x?.level)||0)):0;
 return lv>0?lv:(typeof STAFF_JUDGEMENT!=='undefined'?STAFF_JUDGEMENT.niveau.defaut:60);
}
function tonDuStaff(joueurs,phase,c,key,tons=TONS_CAUSERIE){
 const classes=tons.map(tone=>({tone,v:joueurs.reduce((n,p)=>n+reactionAttendue(p,tone,phase,c),0)})).sort((a,b)=>b.v-a.v||(a.tone<b.tone?-1:1));
 const lv=niveauStaff(),juste=Math.max(0,Math.min(1,(lv-45)/40))*.65+.25;
 const h=pilotageHash(key+'|'+phase+'|staff');
 if((h%1000)/1000<juste)return classes[0].tone;
 // Erreur d'appréciation : le deuxième choix le plus souvent, parfois un ton au hasard.
 return (h>>>10)%3?classes[1].tone:classes[2+(h>>>12)%(classes.length-2)].tone;
}

// --- Consignes du staff pendant un match délégué (toutes les 5 minutes) ---
function pilotageStaff(l){
 if(!pilotageActif(l)||l.finished||l.minute===l.pilotage.staffMinute||l.minute%5)return;
 l.pilotage.staffMinute=l.minute;
 const u=l.userSide,lv=niveauStaff(),voit=k=>(pilotageHash(l.worldContext.id+'|'+l.minute+'|'+k)%100)<Math.round(25+(lv-45)*1.5);
 const a=l.pilotage.arbitre,ecart=l.score[u]-l.score[1-u],c=l.pilotage.consignes;
 const recent=l.pilotage.staffReleve||pilotageReleve(l),maintenant=pilotageReleve(l);
 l.pilotage.staffReleve=maintenant;
 if(l.minute<=5&&a.rucks>=4&&voit('arbitre-rucks'))setConsigne(l,'rucks','prudente','staff');
 if(maintenant.penalites-recent.penalites>=2&&c.discipline!=='stricte'&&voit('discipline'))setConsigne(l,'discipline','stricte','staff');
 const touchesPerdues=(maintenant.touches-recent.touches)-(maintenant.touchesGagnees-recent.touchesGagnees);
 if(touchesPerdues>=2&&c.touche!=='sure'&&voit('touche'))setConsigne(l,'touche','sure','staff');
 if(l.minute>=55&&ecart<0&&voit('poursuite')){setConsigne(l,'rythme','rapide','staff');setConsigne(l,'piedJeu','moins','staff')}
 else if(l.minute>=65&&ecart>0&&ecart<=10&&voit('gestion')){setConsigne(l,'piedJeu','plus','staff');setConsigne(l,'rythme','lent','staff')}
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
 for(const [id,e] of Object.entries(p.etats||{}))joueurs[id]={etat:e.etat,label:PILOTAGE_ETATS[e.etat]?.label||'',phase:e.phase,confiance:confianceManager(id)};
 return {
  arbitre:{...p.arbitre},
  consignes:{...p.consignes},
  axes:Object.entries(CONSIGNES).map(([id,c])=>({id,label:c.label,valeur:p.consignes[id],options:c.valeurs.map(([v,t])=>({id:v,label:t}))})),
  bilans:Object.keys(CONSIGNES).map(a=>pilotageBilan(l,a)).filter(Boolean),
  joueurs,
  journal:p.journal.slice(-8)
 };
}
if(typeof module!=='undefined'&&module.exports)module.exports={ARBITRES,arbitreDuMatch,arbitreResume,CONSIGNES,TONS_CAUSERIE,TONS_LABELS,PILOTAGE_ETATS};
