'use strict';
// Chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1, éteint par défaut).
//
// Micro-simulation de présentation : à partir des faits que le moteur a déjà décidés
// pour un temps fort (équipe, porteurs, gains, marqueur, point d'essai, coup de pied et
// son issue, positions de départ), elle produit des trajectoires continues pour les
// trente joueurs et le ballon, pas à pas (0,1 s), avec un état d'animation par joueur.
// Elle ne lit ni n'écrit la carrière, ne consomme aucun tirage du moteur et ne change
// jamais l'issue : elle met en scène ce que le moteur a décidé.
//
// Types : essai en jeu courant (origine « open »), franchissement sans essai (porteur
// finalement plaqué), jeu au pied et chasse (réception ou touche). Les pistes couvrent
// le temps fort depuis sa remise en jeu (mêlée ou touche formée, coup d'envoi) ou sa
// récupération, avec les temps de jeu que le moteur a enregistrés.
// Conception : docs/match-choregraphe-20261112.md.

const VERSION=2;
const PAS=0.1;              // pas de la micro-simulation, en secondes
const PAS_SORTIE=0.2;       // pas des pistes envoyées à la vue
const DUREE_MIN=12, DUREE_MAX=25;
const DUREE_PLAFOND=50;     // plusieurs faits du moteur : la mise en scène peut aller jusque-là
const DUREE_LIMITE=60;      // garde-fou : au-delà, la mise en scène est abandonnée
const EN_BUT=2;             // le ballon est aplati 2 m derrière la ligne (même règle que la vue)
const ECART=0.8;            // distance visée entre deux joueurs hors contact (garantie : 0,6 m), en mètres
const EVITEMENT=1.7;        // rayon d'évitement (direction voulue), en mètres
const CHUTE=9;              // décélération d'une chute ou d'un plongeon, en m/s²
const APLATI=12;            // décélération du plongeon d'aplati (glissade courte), en m/s²
const CONTACT=1.0;          // distance du plaquage
const RATE=1.35;            // distance où un défenseur tente (et rate) le plaquage d'un porteur en percée
const CLOTURE=1.8;          // après le dernier fait (ruck formé, ballon sorti), la scène dure encore ce temps
const TYPES=Object.freeze(['essai_jeu_courant','franchissement','jeu_au_pied']);
const ETATS=Object.freeze(['course','passe','reception','plaquage','plaque','plaquage_rate','au_sol','se_relever','ruck','ramassage','aplati','joie','deception',
 'melee','lancer','saut','soutien_saut','jeu_au_pied']);
// États de contact : la décélération y est celle d'une chute, pas celle d'une course.
const CHUTES=new Set(['plaquage','plaque','plaquage_rate','aplati','au_sol']);
// Allure plafond par état (m/s) ; null = plafond du profil.
const PLAFOND=Object.freeze({course:null,passe:null,reception:null,plaquage:null,plaque:null,plaquage_rate:null,au_sol:0,se_relever:0.4,ruck:0.6,ramassage:1.5,aplati:null,joie:2.5,deception:1.5,
 melee:0.6,lancer:0.3,saut:0.3,soutien_saut:0.3,jeu_au_pied:null});
// Coups de pied qui finissent en touche (cause du fait « touch » du moteur).
const TOUCHES_AU_PIED=Object.freeze(['direct-touch','indirect-touch','50-22']);
// Gain du moteur à partir duquel un temps de jeu est montré comme une percée (plaquages ratés, couverture).
const GAIN_PERCEE=10;

// Profil physique d'un joueur : allure de pointe et accélération plafonnées.
// `vitesse` : compétence « Vitesse » du moteur (15 à 99, forme comprise) si elle est connue.
function profil(slot,vitesse){
 const v=Number.isFinite(vitesse)?vitesse:(slot<8?45:62);
 return {vmax:+Math.min(9.4,Math.max(6.2,6.2+0.034*(v-15))).toFixed(2),amax:+Math.min(4.6,Math.max(3.2,3.0+0.015*v)).toFixed(2)};
}

function hacher(texte){let h=2166136261;for(const c of String(texte)){h^=c.codePointAt(0);h=Math.imul(h,16777619)}return h>>>0}
function tirage(graine){let a=graine>>>0;return()=>{a=(a+0x6D2B79F5)>>>0;let t=a;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296}}
const borne=(n,a,b)=>Math.max(a,Math.min(b,n));
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const r2=n=>Math.round(n*100)/100;
const r1=n=>Math.round(n*10)/10;
const fini=n=>Number.isFinite(n);

function valider(e){
 if(!e||typeof e!=='object')throw new TypeError('Chorégraphe : entrée absente');
 if(!TYPES.includes(e.type))throw new RangeError('Chorégraphe : type non pris en charge : '+e.type);
 if(![0,1].includes(e.equipe))throw new RangeError('Chorégraphe : équipe invalide');
 const joueurs=(e.joueurs||[]).filter(p=>p&&p.id!=null&&[0,1].includes(p.side)&&fini(p.x)&&fini(p.y));
 const ids=new Set(joueurs.map(p=>String(p.id)));
 if(joueurs.length<20||ids.size!==joueurs.length)throw new RangeError('Chorégraphe : joueurs incomplets');
 const cle=e.type==='essai_jeu_courant'?e.marqueur:e.vedette;
 const vedette=joueurs.find(p=>String(p.id)===String(cle));
 if(!vedette||vedette.side!==e.equipe)throw new RangeError(e.type==='essai_jeu_courant'?'Chorégraphe : marqueur absent de son équipe':'Chorégraphe : joueur clé absent de son équipe');
 if(e.type==='essai_jeu_courant'&&(!e.essai||![0,100].includes(e.essai.x)||!fini(e.essai.y)))throw new RangeError('Chorégraphe : point d’essai invalide');
 if(!e.ballon||!fini(e.ballon.x)||!fini(e.ballon.y))throw new RangeError('Chorégraphe : ballon de départ invalide');
 if(![0,1].includes(e.possession))throw new RangeError('Chorégraphe : possession de départ invalide');
 const etapes=Array.isArray(e.etapes)?e.etapes:null;
 if(etapes){
  for(const s of etapes){
   if(!s||!['porte','franchi','essai','pied','recup'].includes(s.k))throw new RangeError('Chorégraphe : étape invalide');
   if(s.joueur!=null&&!ids.has(String(s.joueur)))throw new RangeError('Chorégraphe : joueur d’étape absent');
  }
  const der=etapes.at(-1);
  if(e.type==='essai_jeu_courant'&&der?.k!=='essai')throw new RangeError('Chorégraphe : l’essai doit finir la mise en scène');
  if(e.type!=='essai_jeu_courant'&&etapes.some(s=>s.k==='essai'))throw new RangeError('Chorégraphe : essai hors d’un temps fort d’essai');
 }
 const o=e.ouverture;
 if(o&&!['jeu','melee','touche','envoi'].includes(o.k))throw new RangeError('Chorégraphe : ouverture invalide');
 if(o&&o.k!=='jeu'&&(!fini(o.x)||!fini(o.y)))throw new RangeError('Chorégraphe : point de remise en jeu invalide');
 if(o?.k==='envoi'&&(!ids.has(String(o.botteur))||!ids.has(String(o.receveur))))throw new RangeError('Chorégraphe : botteur ou receveur absent');
 return {...e,joueurs};
}

// Une mise en scène complète avec `phases` temps de jeu ajoutés (porteur plaqué, ruck)
// avant le fait clé. Rend null si la mise en scène n'aboutit pas.
function simuler(e,phases,graine){
 const alea=tirage(graine);
 const T=e.equipe,essai=e.type==='essai_jeu_courant';
 const sens=essai?(e.essai.x===100?1:-1):(e.sens===1||e.sens===-1?e.sens:T===0?1:-1);
 const ligne=sens>0?100:0;
 const G=essai?{x:ligne+sens*EN_BUT,y:borne(e.essai.y,5,65)}:null;
 const dirDe=side=>side===T?sens:-sens;
 // Défense : consigne tactique de l'équipe qui défend (pression : montée plus rapide, ligne
 // plus haute ; prudente : ligne plus profonde, montée retenue). Présentation seule.
 const consigne=side=>String(e.defense?.[side]||'equilibre');
 const montee=side=>consigne(side)==='pression'?{vitesse:3.6,haut:2.8,fond:0.9,ruck:0.6,allure:6.3}:consigne(side)==='prudente'?{vitesse:1.5,haut:6.5,fond:3.2,ruck:2.6,allure:4.8}:{vitesse:2.5,haut:4.5,fond:1.2,ruck:0.9,allure:5.5};
 const ouverture=e.ouverture||{k:'jeu'};
 const J=e.joueurs.map(p=>{const pr=e.profils?.[p.id]||profil(p.slot,undefined);return {id:String(p.id),side:p.side,slot:p.slot|0,x:borne(p.x,-3,103),y:borne(p.y,0.5,69.5),vx:0,vy:0,vmax:pr.vmax,amax:pr.amax,etat:'course',depuis:0,role:'',cible:null,allure:0,arrive:true,cap:p.side===0?0:Math.PI,suite:[],plonge:null,rate:false}});
 const parId=new Map(J.map(j=>[j.id,j]));
 const att=J.filter(j=>j.side===T),def=J.filter(j=>j.side!==T);
 const S=parId.get(String(essai?e.marqueur:e.vedette));
 const demiDe=side=>J.find(j=>j.side===side&&j.slot===8)||J.filter(j=>j.side===side&&j!==S).sort((a,b)=>Math.abs(a.slot-8)-Math.abs(b.slot-8))[0];
 const demi=demiDe(T);
 const arriereDe=side=>J.find(j=>j.side===side&&j.slot===14)||null;
 const arriere=arriereDe(1-T);
 // Côté du jeu : vers le point d'essai, sinon vers le grand côté.
 const cote=y=>G&&Math.abs(G.y-y)>4?Math.sign(G.y-y):(y<35?1:-1);
 let t=0;
 const contacts=[],evenements=[],echantillons=[],ballonPiste=[],porteurs=[],etatsJ=new Map(J.map(j=>[j.id,[[0,'course']]])),jalons=[];
 const ballon={x:e.ballon.x,y:e.ballon.y,h:1,porteur:null,vol:null,sol:false};
 // Paires au contact voulu (plaquage, ruck, mêlée, plongeon) : seules autorisées sous l'écart minimal.
 const paires=new Map();
 const cle=(a,b)=>a.id<b.id?a.id+'|'+b.id:b.id+'|'+a.id;
 const contact=(a,b,duree)=>{const c={a:a.id,b:b.id,t0:t,t1:t+duree};contacts.push(c);const k=cle(a,b);if(!paires.has(k))paires.set(k,[]);paires.get(k).push(c);return c};
 const groupeContact=(groupe,duree)=>{const l=[];for(let a=0;a<groupe.length;a++)for(let b=a+1;b<groupe.length;b++)l.push(contact(groupe[a],groupe[b],duree));return l};
 // Deux joueurs libres (debout, ni liés ni en train de ramasser) s'évitent même dans une fenêtre de contact.
 const libre=j=>debout(j)&&j.etat!=='ramassage';
 const enContact=(a,b)=>{if(libre(a)&&libre(b))return false;const l=paires.get(cle(a,b));return !!l&&l.some(c=>t>=c.t0-0.05&&t<=c.t1+0.05)};
 const etat=(j,nom,suite=[])=>{if(!ETATS.includes(nom))throw Error(nom);j.etat=nom;j.depuis=t;j.suite=suite;const l=etatsJ.get(j.id);if(l.at(-1)[1]!==nom)l.push([r1(t),nom])};
 const tenir=j=>{ballon.porteur=j.id;ballon.vol=null;ballon.sol=false;ballon.depose=null;if(porteurs.at(-1)?.[1]!==j.id)porteurs.push([r1(t),j.id])};
 const lacher=()=>{ballon.porteur=null;if(porteurs.at(-1)?.[1]!==null)porteurs.push([r1(t),null])};
 const debout=j=>!['plaquage','plaque','plaquage_rate','au_sol','se_relever','ruck','aplati','melee','saut','soutien_saut'].includes(j.etat);
 const vers=(j,x,y,allure,arrive=true)=>{j.cible={x:borne(x,-3,103),y:borne(y,1.5,68.5)};j.allure=Math.min(allure,j.vmax);j.arrive=arrive};
 const jalon=plan=>{if(Number.isInteger(plan)&&!jalons.some(([,k])=>k===plan))jalons.push([r1(t),plan])};

 // --- Script du metteur en scène : étapes du moteur, puis temps de jeu ajoutés avant le fait clé.
 const file=[];
 if(Array.isArray(e.etapes))for(const s of e.etapes)file.push({...s,joueur:s.joueur==null?null:String(s.joueur)});
 else file.push({k:'essai',joueur:S.id,plan:e.plan,cle:true});
 if(phases>0&&!file.some(s=>s.k!=='recup'))return null; // coup d'envoi seul : aucun temps de jeu à ajouter
 if(file.length&&!file.some(s=>s.cle))file.at(-1).cle=true;
 const iCle=Math.max(0,file.findIndex(s=>s.cle));
 // Temps de jeu ajoutés : courts hors essai, pour ne pas manger le gain que le moteur a donné.
 for(let n=0;n<phases;n++)file.splice(iCle,0,{k:'porte',joueur:null,x:null,ajoute:true});
 const pos0=e.possession;
 // Ballon adverse au départ (jeu ouvert) : le premier temps est la récupération par l'équipe du fait clé.
 if(ouverture.k==='jeu'&&pos0!==T&&file[0]?.k!=='recup')file.unshift({k:'recup',joueur:null});

 // Direction du jeu (machine à états du metteur en scène).
 const d={phase:'porte',porteur:null,ruck:null,passe:null,chaine:[],apres:null,etape:null,soutiens:[],plaqueur:null,objectif:null,fin:null,aplati:null,ouvreur:null,attente:0,
  but:G,couvreur:null,coup:null,horsJeuPied:new Set(),apresPied:false,cloture:null,sp:null};

 function choisirSoutiens(p){
  return J.filter(j=>j.side===p.side&&j!==p&&j!==S&&j!==demiDe(p.side)&&debout(j)).sort((a,b)=>dist(a,p)-dist(b,p)||a.slot-b.slot).slice(0,2);
 }
 // Course d'un porteur jusqu'au point que le moteur a donné (sinon un gain tiré), puis plaquage.
 function lancerPorte(p,etape){
  d.phase='porte';d.porteur=p;tenir(p);d.etape=etape||null;
  const s=dirDe(p.side);
  let x;
  if(fini(etape?.x))x=etape.x;
  else{
   const gain=etape?.gain??(etape?.ajoute&&!essai?0.8+alea()*1.7:p.side!==T?1.5:3+alea()*3);
   x=p.x+s*gain;
   // Hors essai, un temps ajouté ne dépasse pas le point de départ du fait suivant du moteur.
   const suivant=file.find(f=>fini(f.depuis));
   if(!essai&&etape?.ajoute&&suivant)x=s>0?Math.min(x,Math.max(p.x+0.5,suivant.depuis+1)):Math.max(x,Math.min(p.x-0.5,suivant.depuis-1));
  }
  d.objectif={x:borne(x,2.5,97.5),y:borne(p.y+(alea()-0.5)*3,4,66)};
  d.soutiens=choisirSoutiens(p);
  // Plaqueur : le défenseur debout le plus proche du point visé (l'arrière garde la profondeur).
  const arr=arriereDe(1-p.side);
  d.plaqueur=J.filter(j=>j.side!==p.side&&debout(j)&&j!==arr).sort((a,b)=>dist(a,d.objectif)-dist(b,d.objectif)||a.slot-b.slot)[0];
  d.debutJeu=t;
  evenements.push({t:r1(t),type:'course',joueur:p.id});
 }
 // Ruck après un plaquage. Le gagnant est l'équipe du plaqué, sauf récupération décidée par le moteur.
 function formerRuck(p,pl){
  const s=dirDe(p.side);
  // Le plaqué présente le ballon vers son camp (loi 14).
  const B={x:p.x-s*0.7,y:p.y};
  lacher();ballon.sol=true;ballon.depose={x:ballon.x,y:ballon.y,h:ballon.h,t0:t,B};
  const recup=file[0]?.k==='recup'?file[0]:null;
  const gagnant=recup?(recup.side??T):p.side;
  // Repère du ruck : l'équipe du fait clé, sauf un ruck adverse qu'elle ne dispute pas (après un coup de pied).
  const camp=p.side===T||gagnant===T?T:1-T,rs=dirDe(camp);
  const lies=[];
  const jackal=recup?.joueur?parId.get(recup.joueur):null;
  // Ramasseur : le gratteur du moteur, sinon le demi ; demi plaqué ou plaqueur, le partenaire debout le plus proche.
  const dm=demiDe(gagnant);
  const ramasseur=jackal&&jackal.side===gagnant&&debout(jackal)?jackal:debout(dm)&&dm!==p&&dm!==pl?dm:
   J.filter(j=>j.side===gagnant&&debout(j)&&j!==p&&j!==pl&&j!==S).sort((a,b)=>dist(a,B)-dist(b,B)||a.slot-b.slot)[0]||dm;
  const lier=(j,c)=>{lies.push(j);j.lie={x:B.x+rs*(c>0?0.2:1.0),y:B.y+(lies.length%2?0.45:-0.45)}};
  const arrivants=(side,n,exclus)=>J.filter(j=>j.side===side&&debout(j)&&!exclus.includes(j)&&j!==S&&j!==demiDe(side)&&j!==ramasseur&&j!==d.ouvreur).sort((a,b)=>dist(a,B)-dist(b,B)||a.slot-b.slot).slice(0,n);
  const nCamp=arrivants(camp,2,[p,pl]),nAutre=arrivants(1-camp,1,[p,pl]);
  d.ruck={B,forme:t,camp,s:rs,gagnant,recupere:gagnant!==p.side,ramasseur,lies,att:nCamp,def:nAutre,recup};
  nCamp.forEach(j=>lier(j,1));
  nAutre.forEach(j=>lier(j,-1));
  d.phase='ruck';
  evenements.push({t:r1(t),type:'ruck',x:r2(B.x),y:r2(B.y),recupere:gagnant!==p.side,gagnant});
 }
 // Où le ramasseur prend le ballon : derrière le ruck, de son côté.
 const pointRamassage=r=>({x:r.B.x-r.s*0.7*(r.gagnant===r.camp?1:-1),y:r.B.y});
 // Ligne de hors-jeu d'un ruck (loi 15) : pied le plus en arrière de son équipe dans le ruck.
 const horsJeu=side=>d.ruck?d.ruck.B.x+(side===d.ruck.camp?-d.ruck.s*1.0:d.ruck.s*1.6):null;
 const enJeu=j=>{const l=horsJeu(j.side);if(l===null)return true;const s=j.side===d.ruck.camp?d.ruck.s:-d.ruck.s;return (l-j.x)*s>=-0.05};
 function passer(de,a){
  lacher();
  const vol=Math.max(0.38,dist(de,a)/11);
  ballon.vol={de:{x:de.x,y:de.y},a:a.id,t0:t,t1:t+vol,depuis:de.id,h0:ballon.h,h1:1.0};
  // Passe jamais vers l'avant (loi 11) : le receveur prend le ballon en retrait du point de lâcher.
  d.passe={de,a,t1:t+vol,lache:{x:de.x,y:de.y}};
  etat(de,'passe');
  evenements.push({t:r1(t),type:'passe',de:de.id,vers:a.id,lache:{x:r2(de.x),y:r2(de.y)}});
  d.phase='passe';
 }
 const placeSoutien=(p,cote_,lat,recul,s=sens)=>({x:p.x-s*recul,y:borne(p.y+cote_*lat,3,67)});
 // Le receveur est-il prêt : en retrait du passeur, à portée de passe, et le restera pendant le vol.
 function pret(de,a){
  const s=dirDe(de.side),vol=Math.max(0.38,dist(de,a)/11),fx=a.x+a.vx*vol;
  return (de.x-fx)*s>=0.6&&(de.x-a.x)*s>=0.9&&dist(de,a)<=14&&dist(de,a)>=2.5;
 }
 // Prochain porteur choisi par le metteur en scène : un avant debout, lancé depuis le ruck.
 function choisirCoureur(h){
  const pris=d.ruck?d.ruck.lies:[];
  const ok=j=>j.side===h.side&&debout(j)&&j!==S&&j!==h&&j!==demiDe(h.side)&&!pris.includes(j);
  const ref=d.ruck?d.ruck.B:h;
  return J.filter(j=>ok(j)&&j.slot<8).sort((a,b)=>dist(a,ref)-dist(b,ref)||a.slot-b.slot)[0]||J.filter(ok).sort((a,b)=>dist(a,ref)-dist(b,ref)||a.slot-b.slot)[0]||null;
 }
 // Prépare la suite pour le joueur qui va tenir le ballon `h` : chaîne de receveurs et action finale.
 function preparer(h){
  while(file[0]?.k==='recup')file.shift(); // une récupération ne se joue qu'au ruck
  const st=file[0];
  d.etape=st||null;d.chaine=[];d.apres=null;d.ouvreur=null;
  if(!st||h.side!==T&&!d.apresPied&&st.k!=='porte')return;
  if(st.k==='porte'){
   const r=st.joueur?parId.get(st.joueur):choisirCoureur(h);
   if(!r||r.side!==h.side)return;
   d.chaine=r===h?[]:[r];d.apres='porte';
  }else if(st.k==='essai'||st.k==='franchi'){
   const v=parId.get(st.joueur)||S;
   if(v===h)d.chaine=[];
   else{
    const ouvreur=J.find(j=>j.side===T&&j.slot===9&&j!==v&&j!==h&&debout(j)&&!(d.ruck?.lies||[]).includes(j));
    d.ouvreur=h===demi&&v.slot>=10&&ouvreur&&alea()<0.75?ouvreur:null;
    d.chaine=d.ouvreur?[d.ouvreur,v]:[v];
   }
   d.apres=st.k==='essai'?'percee':'franchi';
  }else if(st.k==='pied'){
   const k=parId.get(st.joueur)||h;
   d.chaine=k===h?[]:[k];d.apres='pied';
  }
 }
 // Le dernier receveur de la chaîne tient le ballon : l'étape se joue.
 function agir(h){
  const st=file.shift();
  if(!st||!d.apres){cloturer();return}
  if(d.apres==='porte')lancerPorte(h,st);
  else if(d.apres==='percee')lancerPercee(st);
  else if(d.apres==='franchi')lancerPercee(st);
  else if(d.apres==='pied'){
   // Le botteur garde le ballon un instant (prise, deux pas) avant de frapper.
   tenir(h);d.phase='armer';d.armer={k:h,st,t0:t};
  }
 }
 // Après la remise en jeu, la prise ou le ballon joué au ruck : la chaîne part du joueur `h`.
 function lancerSuite(h){
  if(!d.etape){cloturer();return}
  if(d.chaine.length===0)agir(h);
  else{d.phase='tenu';d.tenuDepuis=t;d.tenuDe=null}
 }
 // Le receveur d'un coup de pied a le ballon : il est plaqué par la chasse, ou son équipe joue la suite.
 function recevoir(r,geste){
  const c=d.coup;
  tenir(r);etat(r,geste);jalon(c.etape.plan);c.recu=t;
  evenements.push({t:r1(t),type:'reception',joueur:r.id,x:r2(r.x),y:r2(r.y),cible:r2(c.x)});
  if(r.side===T){
   d.apresPied=false;preparer(r);
   if(d.etape&&d.chaine.length===0)agir(r);else if(d.etape)lancerSuite(r);else lancerPorte(r,{gain:1+alea()*2});
  }else lancerPorte(r,{gain:1+alea()*2.5});
 }
 function cloturer(){if(d.phase!=='cloture'){d.phase='cloture';d.cloture=t+CLOTURE}}

 function lancerPercee(st){
  d.phase='percee';
  const v=parId.get(st.joueur)||S;
  d.vedette=v;d.franchi=st.k==='franchi'?st:null;
  if(d.franchi){
   // Franchissement : le porteur perce puis l'arrière (ou le défenseur le plus en profondeur) le plaque au point du moteur.
   const x=borne(fini(st.x)?st.x:v.x+sens*22,4,96);
   d.but={x,y:borne(v.y+(alea()-0.5)*8,6,64)};
   d.couvreur=(arriere&&debout(arriere)?arriere:null)||def.filter(debout).sort((a,b)=>(b.x-a.x)*sens-(a.x-b.x)*sens||a.slot-b.slot)[0];
  }else d.but=G;
  // Tentatives de plaquage (toutes ratées) : les deux défenseurs debout les plus proches, et l'arrière sur un essai.
  d.tentatives=new Set(def.filter(j=>debout(j)&&j!==arriere&&j!==d.couvreur).sort((a,b)=>dist(a,v)-dist(b,v)||a.slot-b.slot).slice(0,2));
  if(arriere&&!d.franchi)d.tentatives.add(arriere);
  evenements.push({t:r1(t),type:'percee',joueur:v.id});
 }
 // Coup de pied : vol du ballon jusqu'au point du moteur, chasse, réception ou touche.
 function lancerPied(k,st,depart){
  const issue=st.issue==='touche'?'touche':'reception';
  const de=depart||{x:k.x,y:k.y};
  const yT=issue==='touche'?(st.cote===70||st.cote===0?st.cote:(de.y>=35?70:0)):null;
  const x=borne(fini(st.x)?st.x:de.x+sens*30,3,97);
  // Point de chute : x du moteur ; en largeur (le moteur ne la donne pas), près d'un receveur possible.
  const candidat=issue==='reception'?(st.receveur?parId.get(String(st.receveur)):J.filter(j=>j.side!==k.side&&[10,13,14].includes(j.slot)).sort((a,b)=>Math.abs(a.x-x)-Math.abs(b.x-x)||a.slot-b.slot)[0]):null;
  const y=issue==='touche'?(yT===0?-1.2:71.2):borne(fini(st.y)?st.y:(candidat?candidat.y:de.y)+(alea()-0.5)*8,8,62);
  const D=Math.hypot(x-de.x,y-de.y);
  const vol=borne(1.4+D/15,1.9,4.2),apex=issue==='touche'?borne(D*0.16,5,11):borne(D*0.3,8,17);
  etat(k,'jeu_au_pied');lacher();
  ballon.vol={de:{x:de.x,y:de.y},vers:{x,y},t0:t,t1:t+vol,depuis:k.id,h0:0.5,h1:issue==='touche'?0.6:1.6,apex};
  const kp=k.side;
  // Hors-jeu sur un coup de pied (loi 10) : les partenaires devant le botteur attendent d'être remis en jeu.
  d.horsJeuPied=new Set(J.filter(j=>j.side===kp&&j!==k&&(j.x-k.x)*dirDe(kp)>0).map(j=>j.id));
  d.coup={botteur:k,camp:kp,issue,x,y,t0:t,t1:t+vol,etape:st,receveur:null,horsJeu0:[...d.horsJeuPied].map(id=>({id,x:parId.get(id).x}))};
  if(issue==='reception'){
   const r=st.receveur?parId.get(String(st.receveur)):null;
   d.coup.receveur=r&&r.side!==kp?r:J.filter(j=>j.side!==kp&&debout(j)&&[10,13,14,9].includes(j.slot)).sort((a,b)=>dist(a,{x,y})-dist(b,{x,y})||a.slot-b.slot)[0]||J.filter(j=>j.side!==kp).sort((a,b)=>dist(a,{x,y})-dist(b,{x,y}))[0];
   if(st.receveur&&r&&r.side===kp)d.coup.receveur=r; // ballon repris par l'équipe qui botte (coup d'envoi)
  }
  d.apresPied=true;d.phase='vol';
  evenements.push({t:r1(t),type:'jeu_au_pied',joueur:k.id,x:r2(x),y:r2(y),issue});
 }

 // --- Remise en jeu ----------------------------------------------------------
 // Mêlée ou touche formée : coupe d'entrée sur la phase en place (positions refaites ici).
 function placer(j,x,y){j.x=borne(x,-3,103);j.y=borne(y,0.4,69.6);j.vx=0;j.vy=0;j.cible={x:j.x,y:j.y};j.allure=0}
 // Premier receveur après la remise en jeu (porteur désigné par le moteur) : un arrière vient
 // se placer pendant la phase, sans franchir sa ligne de hors-jeu (lois 18 et 20).
 function prochainDe(h){
  const st=file.find(f=>f.k!=='recup');
  if(!st||st.k!=='porte'||!st.joueur)return null;
  const r=parId.get(st.joueur);
  return r&&r.side===T&&r.slot>8&&r!==h?r:null;
 }
 function ouvrirMelee(){
  const M={x:borne(ouverture.x,6,94),y:borne(ouverture.y,6,64)},sI=[0,1].includes(ouverture.introduit)?ouverture.introduit:T,sG=T;
  const off={0:[-0.6,-0.7],1:[-0.6,0],2:[-0.6,0.7],3:[-1.5,-0.35],4:[-1.5,0.35],5:[-1.4,-1.2],6:[-1.4,1.2],7:[-2.4,0]};
  const pack=[];
  for(const side of [0,1]){
   const ds=dirDe(side),lat=side===sI?1:-1;
   for(const j of J.filter(j=>j.side===side&&j.slot<8)){const o=off[j.slot];placer(j,M.x+ds*o[0],M.y+lat*o[1]);etat(j,'melee');pack.push(j)}
   const dm=demiDe(side);
   if(side===sI)placer(dm,M.x-ds*0.3,M.y-1.7);else placer(dm,M.x-ds*0.7,M.y-2.5);
   // Arrières : cinq mètres derrière le dernier pied de leur mêlée (loi 20).
   for(const j of J.filter(j=>j.side===side&&j.slot>8)){const lim=M.x-ds*8.5;placer(j,(j.x-lim)*ds>0?lim-ds*(0.5+(j.slot%3)*0.6):j.x,j.y)}
  }
  const intro=demiDe(sI);tenir(intro);ballon.x=intro.x;ballon.y=intro.y;
  d.sp={k:'melee',M,sI,sG,pack,etape:0,base:{x:M.x-dirDe(sG)*2.9,y:M.y},contacts:groupeContact(pack,60),intro,prochain:prochainDe(demiDe(sG)),ligne:M.x-dirDe(sG)*8.6};
  d.phase='melee';
  jalon(ouverture.plan);
 }
 function ouvrirTouche(){
  const yT=ouverture.y>35?70:0,ty=yT===0?1:-1,L={x:borne(ouverture.x,6,94)};
  const sL=[0,1].includes(ouverture.lance)?ouverture.lance:T;
  const ordre=[0,3,2,5,4,6,7],dists=[5.5,7,8.5,10,11.5,13,14.5];
  for(const side of [0,1]){
   const ds=dirDe(side);
   for(const j of J.filter(j=>j.side===side&&j.slot<8)){
    if(j.slot===1){if(side===sL)placer(j,L.x-ds*0.4,yT+ty*0.5);else placer(j,L.x-ds*2.0,yT+ty*2.6);continue}
    placer(j,L.x-ds*0.5,yT+ty*dists[ordre.indexOf(j.slot)]);
   }
   placer(demiDe(side),L.x-ds*3,yT+ty*9.5);
   // Arrières : dix mètres derrière la ligne de touche jusqu'à la fin de l'alignement (loi 18).
   for(const j of J.filter(j=>j.side===side&&j.slot>8)){const lim=L.x-ds*10;placer(j,(j.x-lim)*ds>0?lim-ds*(0.5+(j.slot%3)*0.7):j.x,Math.abs(j.y-yT)<17?yT+ty*(17+(j.slot-9)*8):j.y)}
  }
  const lanceur=J.find(j=>j.side===sL&&j.slot===1)||demiDe(sL);
  const v=ouverture.sauteur?parId.get(String(ouverture.sauteur)):null;
  const sauteur=v&&v.side===T&&v.slot>=2&&v.slot<8&&v.slot!==1?v:J.find(j=>j.side===T&&j.slot===4);
  const k=ordre.indexOf(sauteur.slot),voisins=[ordre[k-1],ordre[k+1]].filter(s=>s!=null&&s!==1).map(s=>J.find(j=>j.side===T&&j.slot===s)).filter(Boolean);
  tenir(lanceur);ballon.x=lanceur.x;ballon.y=lanceur.y;ballon.h=2.0;
  d.sp={k:'touche',L,yT,ty,sL,lanceur,sauteur,leveurs:voisins,etape:0,prochain:prochainDe(demiDe(T)),ligne:L.x-sens*10.4};
  d.phase='touche';
  jalon(ouverture.plan);
 }
 function ouvrirEnvoi(){
  const k=parId.get(String(ouverture.botteur)),r=parId.get(String(ouverture.receveur));
  const dk=dirDe(k.side);
  // Partenaires du botteur derrière le ballon au coup d'envoi (loi 12) ; adversaires à 10 m au moins.
  for(const j of J){
   if(j===k){placer(j,ouverture.x-dk*2.2,ouverture.y-1.2);continue}
   const ds=dirDe(j.side);
   if(j.side===k.side&&(j.x-ouverture.x)*ds>-0.8)placer(j,ouverture.x-ds*(1+(j.slot%4)*0.6),j.y);
   else if(j.side!==k.side&&(ouverture.x-j.x)*dk<10.5&&(j.x-ouverture.x)*dk<10.5)placer(j,ouverture.x+dk*(11+(j.slot%5)*1.5),j.y);
  }
  ballon.x=ouverture.x;ballon.y=ouverture.y;ballon.h=0.15;ballon.sol=true;
  d.sp={k:'envoi',botteur:k,receveur:r,etape:0};
  d.phase='envoi';
  vers(k,ouverture.x-dk*0.4,ouverture.y-0.3,3);
 }

 // Porteur de départ (jeu ouvert) : le joueur mis en avant par la scène de départ, sinon le plus proche du ballon.
 if(ouverture.k==='melee')ouvrirMelee();
 else if(ouverture.k==='touche')ouvrirTouche();
 else if(ouverture.k==='envoi')ouvrirEnvoi();
 else{
  let porteur=(e.porteur!=null&&parId.get(String(e.porteur))?.side===pos0)?parId.get(String(e.porteur)):null;
  if(!porteur)porteur=J.filter(j=>j.side===pos0).sort((a,b)=>dist(a,ballon)-dist(b,ballon))[0];
  tenir(porteur);
  if(pos0!==T){lancerPorte(porteur,{gain:1.5})}
  else{
   preparer(porteur);
   // Le porteur de départ porte lui-même s'il le faut ; sinon il donne au premier receveur.
   if(d.apres==='porte'&&d.chaine.length&&!file[0]?.joueur){file[0].joueur=porteur.id;d.chaine=[]}
   if(!d.etape)return null;
   if(d.chaine.length===0)agir(porteur);else{d.phase='tenu';d.tenuDepuis=0;d.tenuDe=null}
  }
 }

 // --- Comportements par rôle --------------------------------------------------
 function comportementRemise(j){
  const sp=d.sp;
  if(sp.prochain===j){
   const dm=demiDe(T),c=cote(dm.y),y=sp.k==='touche'?sp.yT+sp.ty*(12+6):dm.y+c*6;
   vers(j,sp.ligne-sens*0.5,borne(y,4,66),j.vmax*0.7);return;
  }
  if(sp.k==='melee'){
   const dG=dirDe(sp.sG);
   if(j.etat==='melee'){vers(j,j.x+dG*(sp.etape>=1?0.3:0),j.y,0.4);return}
   const dm=demiDe(sp.sG);
   if(j===dm){
    if(j===sp.intro&&sp.etape<1){vers(j,j.x,j.y,1);return}
    // Il contourne la mêlée par l'arrière des troisièmes lignes, jusqu'aux pieds du n° 8.
    if((j.x-(sp.M.x-dG*1.9))*dG>0)vers(j,sp.M.x-dG*2.2,sp.M.y-2.7,3.5,false);
    else vers(j,sp.base.x-dG*0.7,sp.base.y-0.9,3.5);
    return;
   }
   if(j===demiDe(1-sp.sG)){vers(j,j.x,j.y,1);return}
   vers(j,j.x,j.y,1.5);return;
  }
  if(sp.k==='touche'){
   if(['saut','soutien_saut'].includes(j.etat)){vers(j,j.x,j.y,0.3);return}
   if(j===sp.lanceur){vers(j,j.x,j.y,0.5);return}
   if(j.slot<8){vers(j,j.x,j.y,0.8);return}
   if(j===demiDe(T)&&sp.etape>=2){vers(j,sp.L.x-sens*3.8,sp.sauteur.y,3);return}
   vers(j,j.x,j.y,1);return;
  }
  if(sp.k==='envoi'){
   const k=sp.botteur;
   if(j===k){return}
   if(j.side===k.side){vers(j,j.x,j.y,1);return}
   vers(j,j.x,j.y,1);
  }
 }
 // Pendant le vol d'un coup de pied et jusqu'à la fin : chasse, couverture, receveur.
 function comportementPied(j){
  const c=d.coup,dk=dirDe(c.camp),chute={x:c.x,y:c.y};
  const porteur=ballon.porteur?parId.get(ballon.porteur):null;
  if(d.phase==='porte'&&(j===d.porteur||j===d.plaqueur))return comportementJeu(j);
  if(j.side===c.camp){
   if(d.horsJeuPied.has(j.id)){vers(j,j.x-dk*1.5,j.y,1.6);return} // en attente d'être remis en jeu
   if(c.issue==='touche'){vers(j,j.x+dk*Math.max(0,(c.x-j.x)*dk*0.5),borne(j.y+(c.y<35?-1:1)*2,3,67),Math.min(j.vmax,5));return}
   const cible=porteur&&porteur.side!==c.camp?porteur:chute;
   // Avant la prise, la chasse s'arrête à distance du receveur ; après, elle le presse.
   const recul=ballon.vol?2.5+(j.slot%5)*1.6:1.2+(j.slot%5)*1.4;
   const l=dist(j,cible)||1,ux=(j.x-cible.x)/l,uy=(j.y-cible.y)/l;
   vers(j,cible.x+ux*recul,cible.y+uy*recul+((j.slot%3)-1)*2.5,j===c.botteur?j.vmax*0.55:j.vmax*0.9);return;
  }
  // Équipe qui reçoit.
  if(j===c.receveur&&(ballon.vol||d.phase==='rebond')){vers(j,ballon.vol?c.x:ballon.x,ballon.vol?c.y:ballon.y,j.vmax*0.9);return}
  const ref=porteur||chute,dr=dirDe(j.side);
  if(c.issue==='touche'){vers(j,j.x-dr*0.5,borne(j.y+(c.y<35?-1:1)*1.5,3,67),3);return}
  if(j.slot<8){vers(j,ref.x-dr*(4+(j.slot%3)*1.5),borne(ref.y+((j.slot%4)-1.5)*4,3,67),4.5);return}
  vers(j,ref.x-dr*(6+(j.slot%4)*2),borne(ref.y+((j.slot%5)-2)*7,3,67),4.5);
 }
 function comportement(j){
  if(!debout(j)&&!['ruck','melee'].includes(j.etat))return; // chute, sol, relevé, sauteur levé : géré par l'état
  if(j.etat==='ruck'){vers(j,j.lie.x,j.lie.y,3);return}
  if(['joie','deception'].includes(j.etat)){j.cible=null;return}
  // Joueur appelé au ruck : il y court, puis se lie.
  if(j.lie&&d.ruck&&d.ruck.lies.includes(j)&&(d.phase==='ruck'||d.phase==='plaquage'||d.phase==='cloture')){
   if(dist(j,j.lie)<0.6)etat(j,'ruck');else vers(j,j.lie.x,j.lie.y,j.vmax*0.9);
   return;
  }
  if(d.phase==='cloture'||d.phase==='fin'&&!G){vers(j,borne(j.x+j.vx*0.6,1,99),j.y+j.vy*0.6,2);return}
  if(['melee','touche','envoi'].includes(d.phase))return comportementRemise(j);
  if(d.apresPied)return comportementPied(j);
  return comportementJeu(j);
 }
 function comportementJeu(j){
  // Ramasseur du ruck (demi ou gratteur), quelle que soit l'équipe.
  if(d.phase==='ruck'&&d.ruck&&j===d.ruck.ramasseur){const q=pointRamassage(d.ruck);vers(j,q.x,q.y,j.vmax*0.9);return}
  // Porteur et plaqueur d'un temps de jeu, quelle que soit l'équipe (ballon récupéré compris).
  if(d.phase==='porte'&&j===d.porteur){
   const s=dirDe(j.side),o=d.objectif,reste=(o.x-j.x)*s;
   // Il court au point du moteur ; si le plaqueur n'y est pas encore, il ralentit au contact de la ligne.
   const pl=d.plaqueur,loin=pl&&dist(pl,o)>3.5&&dist(pl,j)>2.5,moteur=fini(d.etape?.x);
   // Gain du moteur : il ne va pas au-delà ; plaqueur en retard, il ralentit sur la ligne d'avantage.
   if(moteur&&(loin||reste<-0.5))vers(j,o.x+s*0.6,o.y,j.vmax*(reste>8?0.88:0.6),true);
   else vers(j,borne(o.x+s*6,1.5,98.5),o.y,j.vmax*(moteur&&reste>8?0.88:0.8),false);
   return;
  }
  if(d.phase==='porte'&&j===d.plaqueur){
   // Le plaqueur vise l'endroit où le porteur sera (anticipation bornée) ; loin du point du moteur, il y va d'abord.
   const p=d.porteur,o=d.objectif,s=dirDe(p.side);
   if((o.x-p.x)*s>6&&fini(d.etape?.x)){vers(j,o.x+s*1.2,o.y,j.vmax*0.85);return}
   const lead=Math.min(0.8,dist(j,p)/8);
   vers(j,p.x+p.vx*lead,p.y+p.vy*lead,j.vmax*0.9,false);return;
  }
  const b=ballon.porteur?parId.get(ballon.porteur):null;
  const bx=b?b.x:ballon.x,by=b?b.y:ballon.y;
  // Fin : après l'essai, chacun ralentit ; les partenaires proches rejoignent le marqueur.
  if(d.phase==='aplati'||d.phase==='fin'){
   if(j.side===T&&dist(j,G)<22&&j!==S)vers(j,G.x-sens*2.5+(j.slot%3-1)*1.2,G.y+(j.slot%2?1.5:-1.5),4);
   else if(dist(j,S)<5){const l=dist(j,S)||1;vers(j,j.x+(j.x-S.x)/l*2.5,j.y+(j.y-S.y)/l*2.5,3)} // on s'écarte du marqueur au sol
   else vers(j,j.x+j.vx*0.6,j.y+j.vy*0.6,2);
   return;
  }
  const V=d.vedette||S;
  if(d.phase==='armer'&&j===d.armer.k){vers(j,j.x+sens*1.5,j.y,2.5,false);return}
  if(j.side===T){
   if(d.phase==='percee'){
    // Percée : les partenaires suivent le porteur à distance, sans le dépasser (loi 10).
    if(j===V)return;
    const p=V,dx=(p.x-j.x)*sens;
    const lat=borne(j.y-p.y,-12,12);
    vers(j,p.x-sens*Math.max(3,Math.min(dx,10)),p.y+lat*0.8,j.vmax*0.85,false);
    return;
   }
   if(j.id===ballon.porteur&&d.phase==='tenu'){
    // Il fixe la défense en avançant (cinq mètres au plus), sans courir vers la ligne d'en-but.
    const de=d.tenuDe||(d.tenuDe={x:j.x,y:j.y});
    vers(j,de.x+sens*5,de.y,3.2,true);return;
   }
   // Receveur désigné : en retrait et sur le côté du passeur.
   const passeur=d.phase==='ruck'?null:(ballon.porteur?parId.get(ballon.porteur):null);
   const ruckB=d.ruck?.B;
   const prochain=['ruck','ramassage','tenu'].includes(d.phase)?d.chaine[0]:null;
   const c=cote(by);
   if(j===demi&&d.phase==='porte'&&j!==ballon.porteur&&b&&b.side===T){vers(j,b.x-sens*3,b.y-c*1.5,j.vmax*0.75);return}
   if(prochain===j){
    const ref=ruckB&&d.phase==='ruck'?{x:ruckB.x-sens*0.7,y:ruckB.y}:passeur||{x:bx,y:by};
    const fin=j===d.chaine.at(-1)&&d.apres!=='porte';
    const lat=!fin?(d.apres==='porte'?4:6.5):d.chaine.length===1?(d.ouvreur?13:7):6.5;
    const recul=!fin?(d.apres==='porte'?3:4.5):6;
    const p=placeSoutien(ref,c,lat,recul);
    vers(j,p.x,p.y,j.vmax*0.8);
    return;
   }
   if(d.phase==='passe'&&j===d.passe.a){
    // En vol : il court sur le ballon sans dépasser le point de lâcher.
    const l=d.passe.lache;
    const x=sens>0?Math.min(j.x+2,l.x-0.8):Math.max(j.x-2,l.x+0.8);
    vers(j,x,j.y+(l.y-j.y)*0.1,j.vmax*0.8,true);
    return;
   }
   if(d.soutiens.includes(j)&&d.phase==='porte'&&b&&b.side===T){
    const k=d.soutiens.indexOf(j);
    const q=placeSoutien(b,k?1:-1,1.8,1.6);
    vers(j,q.x,q.y,j.vmax*0.85,false);return;
   }
   if(d.chaine.includes(j)||j===V||j===d.ouvreur){
    const ref=ruckB||{x:bx,y:by},k=j===d.chaine.at(-1)?1:0;
    const q=placeSoutien(ref,c,k?13:6,k?7:5);
    vers(j,q.x,q.y,j.vmax*0.6);return;
   }
   // Les autres : avants en grappes près du ballon, arrières en ligne derrière.
   if(j.slot<8){const q={x:bx-sens*(5+(j.slot%3)*1.5),y:borne(by+((j.slot%4)-1.5)*4,3,67)};vers(j,q.x,q.y,4.2);return}
   const rang=j.slot-8;
   const q={x:bx-sens*(6+rang*1.2),y:borne(by+c*(4+rang*6.5),3,67)};
   vers(j,q.x,q.y,4.5);
   return;
  }
  // Défense.
  const p=ballon.porteur?parId.get(ballon.porteur):null;
  const pv=p&&p.side===T?p:null;
  if(j===arriere&&!(d.phase==='percee'&&d.couvreur===j)){
   if(d.phase==='percee'&&pv){
    // Couverture : il coupe la course du porteur, sans le rattraper s'il est battu.
    const but=d.but;
    vers(j,pv.x+sens*Math.max(2,(but.x-pv.x)*sens*0.35),pv.y+(but.y-pv.y)*0.35,j.vmax*0.95,false);return;
   }
   vers(j,sens>0?Math.min(bx+18,ligne-3):Math.max(bx-18,ligne+3),by*0.7+35*0.3,5);return;
  }
  if(d.phase==='percee'&&pv){
   const vS=Math.hypot(pv.vx,pv.vy);
   if(j===d.couvreur){
    // Le couvreur va au point du moteur et l'attend ; tout près, il plaque.
    const o=d.but;
    if(dist(pv,o)<5||(pv.x-o.x)*sens>0)vers(j,pv.x+pv.vx*0.25,pv.y+pv.vy*0.25,j.vmax,false);
    else vers(j,o.x+sens*1.0,pv.y+(o.y-pv.y)*0.6,j.vmax*0.95);
    return;
   }
   if(d.tentatives.has(j)&&!j.rate){vers(j,pv.x+pv.vx*0.3,pv.y+pv.vy*0.3,j.vmax,false);return}
   // Devant le porteur : ils reculent vers leur ligne en s'écartant de sa course ; derrière, ils le poursuivent sans le rattraper.
   const repli=d.franchi?d.but.x+sens*4:ligne+sens*1;
   if((j.x-pv.x)*sens>0){const ecart=Math.abs(j.y-d.but.y)<6?Math.sign((j.y-d.but.y)||1)*6:0;vers(j,repli,borne(j.y+ecart,2,68),Math.min(j.vmax,vS*0.8+0.3),true)}
   else vers(j,pv.x-sens*2.5,pv.y,Math.min(j.vmax,vS*0.8));
   return;
  }
  // Ligne défensive : en jeu, étalée sur la largeur, elle glisse vers le ballon puis monte selon la consigne.
  const m=montee(j.side);
  const ligneDef=def.filter(x=>x!==arriere&&debout(x)).sort((a,b)=>a.y-b.y||a.slot-b.slot);
  const k=ligneDef.indexOf(j),n=ligneDef.length;
  const ref=d.ruck&&d.phase==='ruck'?d.ruck.B:{x:bx,y:by};
  const centre=borne(ref.y,3+((n-1)/2)*6,67-((n-1)/2)*6);
  const voulu=centre+(k-(n-1)/2)*6.2;
  let y=borne(voulu+(by-ref.y)*0.5,2,68),x;
  if(d.phase==='ruck'){x=horsJeu(j.side)+sens*m.ruck}
  else{const monte=Math.min(m.haut-m.fond,(t-(d.debutJeu??t))*m.vitesse);x=ref.x+sens*Math.max(m.fond,m.haut-monte)}
  // Jamais devant la ligne de hors-jeu pendant un ruck.
  // Hors-jeu au ruck : il revient derrière la ligne en le contournant (jamais à travers le ruck).
  if(d.phase==='ruck'&&!enJeu(j)){x=horsJeu(j.side)+sens*1.2;if(Math.abs(j.y-d.ruck.B.y)<3.5)y=d.ruck.B.y+Math.sign((j.y-d.ruck.B.y)||1)*4}
  vers(j,x,y,d.phase==='ruck'?5.5:Math.min(j.vmax,m.allure));
 }

 // Paires qui cherchent le contact : elles ne s'évitent pas (porteur et plaqueur, porteur en percée et
 // défenseurs qui tentent de le plaquer ; le porteur en percée ne dévie que sur un plongeon).
 // Gain du moteur : le contact n'est cherché qu'au bout du gain (le plaquage a lieu là où le moteur l'a dit).
 const auBout=()=>!fini(d.etape?.x)||(d.objectif.x-d.porteur.x)*dirDe(d.porteur.side)<4;
 const veutContact=(j,o)=>d.phase==='porte'&&(j===d.porteur&&o===d.plaqueur||j===d.plaqueur&&o===d.porteur)||
  d.phase==='percee'&&(o===d.vedette&&(d.tentatives.has(j)||j===d.couvreur)||j===d.vedette&&o===d.couvreur);
 // --- Intégration : vitesses et accélérations plafonnées ------------------------
 function integrer(j){
  const chute=CHUTES.has(j.etat);
  const plafond=PLAFOND[j.etat]==null?j.vmax:Math.min(j.vmax,PLAFOND[j.etat]);
  let wx=0,wy=0,danger=0,ex=0,ey=0;
  // Évitement : on contourne les autres joueurs, sauf au contact voulu. Anticipation sur
  // 2 s (point de plus courte approche) en plus d'une répulsion de proximité.
  // Le marqueur, son ballon aplati, reste dessus : ce sont les autres qui l'évitent.
  if(G&&j===S&&(d.phase==='aplati'||d.phase==='fin')){j.cible={x:j.x,y:j.y};j.allure=0}
  else if(debout(j)&&j.etat!=='ruck'){
   const fonce=d.phase==='percee'&&j===d.vedette; // le porteur en percée ne dévie pas devant un adversaire
   for(const o of J){
    if(o===j||enContact(j,o)||veutContact(j,o)||fonce&&o.side!==j.side)continue;
    const px=o.x-j.x,py=o.y-j.y,l=Math.hypot(px,py);
    if(l>8)continue;
    // Un joueur au sol occupe sa longueur : on le contourne plus large.
    const rayon=EVITEMENT+(debout(o)?0:0.6),force=3+j.allure;
    if(l<rayon&&l>1e-6){const f=(rayon-l)/rayon*force;ex-=px/l*f;ey-=py/l*f;danger=Math.max(danger,(rayon-l)/rayon)}
    const rx=o.vx-j.vx,ry=o.vy-j.vy,rr=rx*rx+ry*ry;
    if(rr<1e-6)continue;
    const tc=borne(-(px*rx+py*ry)/rr,0,2.0);
    if(tc<=0)continue;
    const cx=px+rx*tc,cy=py+ry*tc,dc=Math.hypot(cx,cy),seuil=debout(o)?1.7:2.2;
    if(dc<seuil){const f=(seuil-dc)/seuil*(3+j.allure)/(1+tc),ux=dc>1e-6?cx/dc:-ry/Math.sqrt(rr),uy=dc>1e-6?cy/dc:rx/Math.sqrt(rr);ex-=ux*f;ey-=uy*f;danger=Math.max(danger,(seuil-dc)/seuil/(1+tc))}
   }
  }
  // Plus le risque de heurt est grand, plus l'attrait de la cible cède devant l'évitement.
  if(j.plonge){wx=j.plonge.x;wy=j.plonge.y}
  else if(j.cible&&(debout(j)||j.etat==='ruck'||['melee','saut','soutien_saut'].includes(j.etat))){
   const dx=j.cible.x-j.x,dy=j.cible.y-j.y,l=Math.hypot(dx,dy);
   if(l>0.05){let a=j.allure*(1-0.8*Math.min(1,danger));if(j.arrive)a=Math.min(a,Math.sqrt(2*j.amax*0.7*Math.max(0,l-0.1)));wx=dx/l*a;wy=dy/l*a}
  }
  wx+=ex;wy+=ey;
  const w=Math.hypot(wx,wy);if(w>plafond){wx*=plafond/w;wy*=plafond/w}
  const amax=j.etat==='aplati'?APLATI:chute?CHUTE:j.amax;
  // Limites du terrain (en-buts compris) : on freine à temps, sans arrêt brutal contre la limite.
  const arret=v=>v*v/(2*amax*0.75);
  const bx=j.vx>0&&j.x+arret(j.vx)>=103.6||j.vx<0&&j.x-arret(j.vx)<=-3.6,by=j.vy>0&&j.y+arret(j.vy)>=68.9||j.vy<0&&j.y-arret(j.vy)<=1.1;
  if(bx)wx=j.vx>0?Math.min(wx,0):Math.max(wx,0);
  if(by)wy=j.vy>0?Math.min(wy,0):Math.max(wy,0);
  let ax=wx-j.vx,ay=wy-j.vy;const a=Math.hypot(ax,ay),lim=amax*PAS;
  if(a>lim){
   // Le freinage devant une limite passe avant tout le reste de l'accélération disponible.
   if(by&&!bx){ay=borne(ay,-lim,lim);ax=borne(ax,-Math.sqrt(Math.max(0,lim*lim-ay*ay)),Math.sqrt(Math.max(0,lim*lim-ay*ay)))}
   else if(bx&&!by){ax=borne(ax,-lim,lim);ay=borne(ay,-Math.sqrt(Math.max(0,lim*lim-ax*ax)),Math.sqrt(Math.max(0,lim*lim-ax*ax)))}
   else{ax*=lim/a;ay*=lim/a}
  }
  j.vx+=ax;j.vy+=ay;j.dv={x:ax,y:ay};
  j.marge=Math.max(0,lim-Math.hypot(ax,ay)); // accélération encore disponible pour l'évitement
  const v=Math.hypot(j.vx,j.vy);if(v>j.vmax){j.vx*=j.vmax/v;j.vy*=j.vmax/v}
 }
 // Dernier recours : deux joueurs hors contact trop proches freinent l'un vers l'autre.
 function separer(){
  for(let i=0;i<J.length;i++)for(let k=i+1;k<J.length;k++){
   const a=J[i],b=J[k];if(enContact(a,b))continue;
   // Plus courte approche sur 1 s avec les vitesses actuelles.
   const px=a.x-b.x,py=a.y-b.y,rx=a.vx-b.vx,ry=a.vy-b.vy,rr=rx*rx+ry*ry;
   if(px*px+py*py>100)continue;
   const tc=rr>1e-9?borne(-(px*rx+py*ry)/rr,PAS,1.0):PAS;
   const nx=px+rx*tc,ny=py+ry*tc,l=Math.hypot(nx,ny);
   if(l>=ECART+0.2||l<1e-9)continue;
   const ux=nx/l,uy=ny/l,rel=(a.vx-b.vx)*ux+(a.vy-b.vy)*uy;
   // Ils se rapprochent : on annule la vitesse relative ; déjà trop près : on les écarte. Toujours
   // dans la limite d'accélération qui reste à chacun pour ce pas.
   const voulu=l<ECART?Math.max(0.6,-rel):-rel;
   if(voulu>0){
    // Près d'une ligne de touche, personne n'est poussé dehors : l'autre s'écarte.
    const dehors=(j,sy)=>j.y>67.5&&sy>0||j.y<2.5&&sy<0;
    // Le marqueur reste sur son ballon aplati : les autres s'écartent de lui.
    const fixe=j=>j===S&&(d.phase==='aplati'||d.phase==='fin')&&G;
    // Écart en danger : chacun renonce au besoin à une part de l'accélération de ce pas vers sa
    // cible pour s'écarter (le total reste sous son plafond d'accélération).
    const liberer=(j,besoin)=>{const l=Math.hypot(j.dv?.x||0,j.dv?.y||0);if(!(besoin>(j.marge??0))||l<1e-9||!debout(j))return;const f=Math.min(1,(besoin-(j.marge??0))/l);j.vx-=j.dv.x*f;j.vy-=j.dv.y*f;j.dv={x:j.dv.x*(1-f),y:j.dv.y*(1-f)};j.marge=(j.marge??0)+l*f};
    // Un joueur au sol, fixé ou contre la touche ne bouge pas : l'autre s'écarte seul.
    const bloqueA=dehors(a,uy)||fixe(a)||!debout(a),bloqueB=dehors(b,-uy)||fixe(b)||!debout(b);
    const c=bloqueA||bloqueB?voulu:voulu/2;
    if(l<ECART){if(!bloqueA)liberer(a,c);if(!bloqueB)liberer(b,c)}
    const ca=bloqueA?0:Math.min(c,a.marge??0),cb=bloqueB?0:Math.min(c,b.marge??0);a.vx+=ux*ca;a.vy+=uy*ca;b.vx-=ux*cb;b.vy-=uy*cb;a.marge-=ca;b.marge-=cb
   }
  }
 }

 // --- Boucle ---------------------------------------------------------------
 let n=0;
 const garder=()=>{
  echantillons.push(J.map(j=>[j.x,j.y,Math.hypot(j.vx,j.vy),j.cap]));
  ballonPiste.push([ballon.x,ballon.y,ballon.h]);
 };
 const capDe=j=>{
  const v=Math.hypot(j.vx,j.vy);
  let voulu=j.cap;
  if(j.plonge||v>2)voulu=Math.atan2(j.vy,j.vx);
  else if(j.etat==='melee')voulu=dirDe(j.side)>0?0:Math.PI;
  else if(debout(j)||['saut','soutien_saut'].includes(j.etat)){const b=ballon.porteur?parId.get(ballon.porteur):ballon;if(dist(b,j)>0.2)voulu=Math.atan2(b.y-j.y,b.x-j.x)}
  const diff=Math.atan2(Math.sin(voulu-j.cap),Math.cos(voulu-j.cap)),max=6*PAS;
  j.cap+=borne(diff,-max,max);j.cap=Math.atan2(Math.sin(j.cap),Math.cos(j.cap));
 };
 for(const j of J){const b=ballon;if(j.etat==='melee')j.cap=dirDe(j.side)>0?0:Math.PI;else if(dist(b,j)>0.2)j.cap=Math.atan2(b.y-j.y,b.x-j.x)}
 const ballonSuit=()=>{
  if(ballon.porteur){
   const p=parId.get(ballon.porteur);const c=Math.cos(p.cap),s=Math.sin(p.cap);ballon.x=p.x+c*0.3;ballon.y=p.y+s*0.3;
   ballon.h=p.etat==='saut'?2.9:p===d.sp?.lanceur&&d.phase==='touche'?2.0:1.0;
   // Aplati : le ballon va des mains au point d'essai, sans saut.
   if(p.etat==='aplati'){const k=Math.min(1,(t-p.depuis)/0.45);ballon.x+=(G.x-ballon.x)*k;ballon.y+=(G.y-ballon.y)*k;ballon.h=1.0-0.88*k}
  }
  else if(ballon.vol&&ballon.vol.vers){
   // Coup de pied : trajectoire en cloche jusqu'au point de chute du moteur.
   const v=ballon.vol,k=borne((t-v.t0)/(v.t1-v.t0),0,1);
   ballon.x=v.de.x+(v.vers.x-v.de.x)*k;ballon.y=v.de.y+(v.vers.y-v.de.y)*k;ballon.h=v.h0+(v.h1-v.h0)*k+4*v.apex*k*(1-k);
  }
  else if(ballon.vol){const v=ballon.vol,a=parId.get(v.a),k=borne((t-v.t0)/(v.t1-v.t0),0,1);ballon.x=v.de.x+(a.x-v.de.x)*k;ballon.y=v.de.y+(a.y-v.de.y)*k;
   const ha=a.etat==='saut'?2.9:1.0;ballon.h=(v.h0??1)+(ha-(v.h0??1))*k+Math.sin(k*Math.PI)*(v.cloche??0.35)}
  else if(ballon.sol&&ballon.depose){const v=ballon.depose,k=borne((t-v.t0)/(v.dur??0.3),0,1);ballon.x=v.x+(v.B.x-v.x)*k;ballon.y=v.y+(v.B.y-v.y)*k;ballon.h=v.h+(0.15-v.h)*k}
  else if(ballon.sol){ballon.h=0.15}
 };
 ballonSuit();garder();
 while(t<DUREE_LIMITE){
  // Décisions du metteur en scène.
  for(const j of J){
   // Fin d'un état temporaire.
   const age=t-j.depuis;
   if(j.etat==='passe'&&age>=0.35)etat(j,'course');
   if(j.etat==='lancer'&&age>=0.6)etat(j,'course');
   if(j.etat==='jeu_au_pied'&&age>=0.7)etat(j,'course');
   if(j.etat==='reception'&&age>=0.3)etat(j,'course');
   if(j.etat==='ramassage'&&age>=0.4&&d.phase!=='ramassage')etat(j,'course');
   if(j.etat==='plaquage'&&age>=0.7){etat(j,'au_sol');j.plonge=null}
   if(j.etat==='plaquage_rate'&&age>=0.55){etat(j,'au_sol');j.plonge=null}
   if(j.etat==='plaque'&&age>=0.7)etat(j,'au_sol');
   if(j.etat==='au_sol'&&j.releve!=null&&t>=j.releve){etat(j,'se_relever');j.releve=null}
   if(j.etat==='se_relever'&&age>=1.0)etat(j,'course');
   if(j.etat==='melee'&&j.libere!=null&&t>=j.libere){etat(j,'course');j.libere=null}
   if(j.etat==='ruck'&&!['ruck','cloture'].includes(d.phase)&&age>0.3)etat(j,'course');
   if(j.plonge){const v=Math.hypot(j.vx,j.vy),f=j.etat==='aplati'?APLATI:CHUTE;j.plonge={x:j.vx*Math.max(0,v-f*PAS)/Math.max(v,1e-6),y:j.vy*Math.max(0,v-f*PAS)/Math.max(v,1e-6)}}
  }
  // Remis en jeu après un coup de pied : un partenaire en jeu les a dépassés (loi 10).
  if(d.coup&&d.horsJeuPied.size){
   const dk=dirDe(d.coup.camp),enJeuPied=J.filter(j=>j.side===d.coup.camp&&!d.horsJeuPied.has(j.id));
   const joue=d.coup.recu!=null&&t-d.coup.recu>=1.0; // l'adversaire a joué le ballon (loi 10.4, simplifiée)
   for(const id of [...d.horsJeuPied]){const j=parId.get(id);if(joue||enJeuPied.some(o=>(o.x-j.x)*dk>=0))d.horsJeuPied.delete(id)}
  }
  if(d.phase==='melee'){
   const sp=d.sp,age=t;
   if(sp.etape===0&&age>=1.0){
    // Introduction (loi 20) : le demi pose le ballon dans le tunnel, il roule vers le talon du gagnant.
    sp.etape=1;etat(sp.intro,'passe');lacher();ballon.sol=true;ballon.depose={x:ballon.x,y:ballon.y,h:ballon.h,t0:t,B:{x:sp.M.x,y:sp.M.y},dur:0.35};
    evenements.push({t:r1(t),type:'introduction',joueur:sp.intro.id});
   }else if(sp.etape===1&&age>=1.4){
    sp.etape=2;ballon.depose={x:ballon.x,y:ballon.y,h:ballon.h,t0:t,B:sp.base,dur:1.25};
   }else if(sp.etape===2&&age>=2.7){
    const dm=demiDe(sp.sG),n8=J.find(j=>j.side===sp.sG&&j.slot===7);
    const st=file[0];
    // Le n° 8 garde le ballon s'il est le porteur désigné par le moteur ; sinon le demi ramasse.
    const ram=st?.k==='porte'&&n8&&st.joueur===n8.id?n8:dm;
    if(ram===n8||dist(dm,{x:sp.base.x-dirDe(sp.sG)*0.7,y:sp.base.y-0.9})<1.1||age>5){
     sp.etape=3;
     if(ram===n8){etat(n8,'course');n8.libere=null}
     etat(ram,'ramassage');tenir(ram);
     jalon(ouverture.planGain);
     evenements.push({t:r1(t),type:'ramassage',joueur:ram.id,horsJeuRespecte:true});
     for(const j of sp.pack)if(j!==ram&&j.etat==='melee')j.libere=t+0.2+((j.slot*7+j.side*3)%6)*0.12;
     for(const c of sp.contacts)c.t1=t+1.6;
     d.debutJeu=t;
     preparer(ram);
     if(!d.etape){cloturer()}
     else if(d.chaine.length===0)agir(ram);
     else{d.phase='ramassage';d.attente=t+0.35;d.ruck=null}
    }
   }
  }else if(d.phase==='touche'){
   const sp=d.sp,age=t;
   if(sp.etape===0&&age>=0.6){sp.etape=1;etat(sp.lanceur,'lancer')}
   else if(sp.etape===1&&age>=1.0){
    // Lancer droit au-dessus de la ligne de touche (loi 18), sauteur levé par deux partenaires.
    sp.etape=2;lacher();ballon.vol={de:{x:sp.lanceur.x,y:sp.lanceur.y},a:sp.sauteur.id,t0:t,t1:t+0.85,depuis:sp.lanceur.id,h0:2.0,cloche:0.9};
    etat(sp.sauteur,'saut');for(const l of sp.leveurs)etat(l,'soutien_saut');
    groupeContact([sp.sauteur,...sp.leveurs],3.0);
    evenements.push({t:r1(t),type:'lancer',joueur:sp.lanceur.id,sauteur:sp.sauteur.id});
   }else if(sp.etape===2&&age>=1.85){
    sp.etape=3;tenir(sp.sauteur);jalon(ouverture.planGain);
    evenements.push({t:r1(t),type:'reception',joueur:sp.sauteur.id});
   }else if(sp.etape===3&&age>=2.5){
    sp.etape=4;etat(sp.sauteur,'course');for(const l of sp.leveurs)etat(l,'course');
   }else if(sp.etape===4&&age>=2.8){
    const dm=demiDe(T);
    if(pret(sp.sauteur,dm)||age>6){
     sp.etape=5;
     preparer(dm);
     const suite=d.chaine,apres=d.apres;
     passer(sp.sauteur,dm);
     d.chaine=[dm,...suite];d.apres=apres;d.debutJeu=t;
    }
   }
  }else if(d.phase==='envoi'){
   const sp=d.sp,k=sp.botteur;
   if(sp.etape===0&&t>=1.0){
    sp.etape=1;
    jalon(ouverture.plan);
    lancerPied(k,{issue:'reception',x:ouverture.chute?.x,y:ouverture.chute?.y,receveur:sp.receveur.id,plan:ouverture.planReception},{x:ouverture.x,y:ouverture.y});
    d.coup.envoi=true;
   }
  }else if(d.phase==='armer'){
   if(t-d.armer.t0>=0.6)lancerPied(d.armer.k,d.armer.st);
  }else if(d.phase==='vol'){
   const c=d.coup;
   if(t>=c.t1){
    if(c.issue==='touche'){
     // Ballon sorti en touche au point du moteur.
     ballon.vol=null;ballon.sol=true;ballon.h=0.15;ballon.x=c.x;ballon.y=c.y;
     jalon(c.etape.plan);evenements.push({t:r1(t),type:'touche',x:r2(c.x)});
     cloturer();
    }else{
     const r=c.receveur;
     if(dist(r,c)>1.3){
      // Receveur pas encore sous le ballon : il tombe au point du moteur, le receveur le ramasse.
      ballon.vol=null;ballon.sol=true;ballon.depose={x:c.x,y:c.y,h:ballon.h,t0:t,B:{x:c.x,y:c.y},dur:0.35};d.phase='rebond';
     }else recevoir(r,'reception');
    }
   }
  }else if(d.phase==='rebond'){
   const r=d.coup.receveur;
   if(t-d.coup.t1>=0.35&&dist(r,ballon)<0.9)recevoir(r,'ramassage');
   else if(t-d.coup.t1>8)return null;
  }else if(d.phase==='porte'){
   const p=d.porteur;
   // Plaqueur désigné hors d'état ou distancé : le défenseur debout le plus proche prend le relais.
   if(!debout(d.plaqueur)||t-d.debutJeu>3&&dist(d.plaqueur,p)>4&&!(fini(d.etape?.x)&&(d.objectif.x-p.x)*dirDe(p.side)>4)){
    const relais=J.filter(j=>j.side!==p.side&&debout(j)).sort((a,b)=>dist(a,p)-dist(b,p)||a.slot-b.slot)[0];
    if(relais)d.plaqueur=relais;
   }
   const pl=d.plaqueur;
   if(pl&&dist(p,pl)<CONTACT&&auBout()){
    // Plaquage réussi (loi 14) : porteur amené au sol, ballon présenté, ruck.
    etat(pl,'plaquage');etat(p,'plaque');
    pl.plonge={x:pl.vx,y:pl.vy};
    contact(p,pl,6);
    evenements.push({t:r1(t),type:'plaquage',plaqueur:pl.id,porteur:p.id,x:r2(p.x),y:r2(p.y),cible:fini(d.etape?.x)?r2(d.etape.x):null});
    jalon(d.etape?.plan);
    d.attente=t+0.45;d.phase='plaquage';d.plaque={p,pl};
   }
  }else if(d.phase==='plaquage'&&t>=d.attente){
   formerRuck(d.plaque.p,d.plaque.pl);
   // Membres du ruck, plaqueur, plaqué et ramasseur : au contact jusqu'à ce que le ballon soit joué.
   const groupe=[d.plaque.p,d.plaque.pl,...d.ruck.att,...d.ruck.def,d.ruck.ramasseur].filter((j,i,l)=>j&&l.indexOf(j)===i);
   d.ruck.groupe=groupe;d.ruck.contacts=groupeContact(groupe,30);
   const recup=d.ruck.recup;
   if(recup){file.shift();d.ruck.recupPlan=recup.plan}
   const gagneT=d.ruck.gagnant===T;
   // Ballon adverse après un coup de pied, ou plus rien à jouer : la scène se clôt sur le ruck formé.
   if(d.apresPied&&!gagneT||!file.length&&!recup){cloturer();d.ruck.final=true}
   // Ballon récupéré par l'adversaire (le moteur l'a décidé) : il est joué, puis la scène se clôt.
   else if(!gagneT){d.etape=null;d.chaine=[];d.apres=null}
   else{d.apresPied=false;preparer(d.ruck.ramasseur)}
  }else if(d.phase==='ruck'){
   const r=d.ruck,ram=r.ramasseur;
   const tousEnJeu=J.every(j=>!debout(j)||r.lies.includes(j)||j===ram||enJeu(j));
   const pret_=t-r.forme>=1.4&&dist(ram,pointRamassage(r))<1.0;
   const prochain=d.chaine[0];
   const prochainPret=!prochain||(ram.x-prochain.x)*dirDe(ram.side)>=1.5;
   // Au-delà de six secondes, le ballon est joué dès que le ramasseur y est (jamais de loin).
   if(pret_&&tousEnJeu&&(prochainPret||t-r.forme>6)||t-r.forme>9&&dist(ram,pointRamassage(r))<1.0){
    etat(ram,'ramassage');tenir(ram);ballon.sol=false;ballon.depose=null;
    evenements.push({t:r1(t),type:'ramassage',joueur:ram.id,horsJeuRespecte:tousEnJeu});
    if(r.recupPlan!=null)jalon(r.recupPlan);
    d.phase='ramassage';d.attente=t+0.4;
    // Tous se relèvent : le ruck est fini quand le ballon est joué.
    for(const j of J)if(j.etat==='au_sol'&&j.releve==null)j.releve=t+0.2+((j.slot*7)%5)*0.1;
    // Fin des contacts du ruck une seconde et demie après le ballon joué (le temps de se relever et de s'écarter).
    for(const c of r.contacts)c.t1=t+1.5;
   }
  }else if(d.phase==='ramassage'&&t>=d.attente){
   // Le ramasseur ne passe qu'à un receveur en retrait (loi 11) ; il l'attend (abandon au-delà de six secondes).
   const ram=ballon.porteur?parId.get(ballon.porteur):null;
   // Tant que le ramasseur attend son receveur au pied du ruck, ceux qui en sortent peuvent le frôler.
   if(ram&&d.ruck?.contacts)for(const c of d.ruck.contacts)if(c.a===ram.id||c.b===ram.id)c.t1=Math.max(c.t1,t+0.6);
   if(ram&&(d.chaine.length===0||pret(ram,d.chaine[0]))){
    d.ruck=null;d.debutJeu=t;
    if(d.chaine.length===0)agir(ram);else passer(ram,d.chaine[0]);
   }else if(t>=d.attente+6)return null;
  }else if(d.phase==='tenu'){
   const p=parId.get(ballon.porteur),a=d.chaine[0];
   if(t-(d.tenuDepuis??(d.tenuDepuis=t))>=0.3&&pret(p,a)){d.tenuDepuis=null;passer(p,a)}
   else if(t-d.tenuDepuis>8)return null; // receveur jamais en retrait : mise en scène abandonnée
  }else if(d.phase==='passe'&&t>=d.passe.t1){
   const a=d.passe.a;
   tenir(a);etat(a,'reception');
   evenements.push({t:r1(t),type:'reception',joueur:a.id});
   if(d.chaine[0]===a)d.chaine=d.chaine.slice(1);
   if(d.chaine.length){d.phase='tenu';d.tenuDepuis=t;d.tenuDe=null}
   else agir(a);
  }else if(d.phase==='percee'){
   const V=d.vedette,o=d.but;
   // Tout plaquage tenté sur le porteur est raté : le moteur a donné l'essai ou le franchissement.
   // Un défenseur qui arrive au contact du porteur tente aussi (et rate) : personne ne le traverse.
   for(const j of def){
    if(j.rate||!debout(j)||dist(j,V)>RATE||j===d.couvreur)continue;
    j.rate=true;etat(j,'plaquage_rate');
    const dx=V.x+V.vx*0.25-j.x,dy=V.y+V.vy*0.25-j.y,l=Math.hypot(dx,dy)||1,v=Math.max(3,Math.min(j.vmax,Math.hypot(j.vx,j.vy)+1));
    j.plonge={x:dx/l*v,y:dy/l*v};j.releve=t+1.6;
    contact(V,j,1.2);
    // Plusieurs plongeons sur le même porteur : ils peuvent finir l'un contre l'autre.
    for(const q of def)if(q!==j&&q.rate&&!debout(q)&&dist(q,j)<4)contact(q,j,2.5);
    // Cadrage-débordement : le porteur s'écarte du côté opposé au plongeon.
    d.ecart={cote:Math.sign((V.y-j.y)||1),jusque:t+0.7};
    evenements.push({t:r1(t),type:'plaquage_rate',plaqueur:j.id,porteur:V.id});
   }
   const ecart=d.ecart&&t<d.ecart.jusque?d.ecart.cote*2.5:0;
   if(d.franchi){
    // Franchissement : le porteur file vers le point du moteur ; le couvreur l'y attend et le plaque.
    let cv=d.couvreur;const reste=(o.x-V.x)*sens;
    // Couvreur dépassé : le défenseur debout le plus proche devient le couvreur.
    if(cv&&debout(cv)&&(cv.x-V.x)*sens<-1.5&&reste<6){cv=d.couvreur=def.filter(j=>debout(j)&&!j.rate&&j!==cv).sort((a,b)=>dist(a,V)-dist(b,V)||a.slot-b.slot)[0]||cv}
    if(cv&&debout(cv)&&reste<6&&(cv.x-V.x)*sens>=-1.5)vers(V,cv.x,cv.y,V.vmax*0.85,false);
    else vers(V,borne(o.x+sens*3,2,98),o.y+ecart,V.vmax*(reste<0?0.6:reste<10?0.82:0.95),false);
    if(cv&&debout(cv)&&dist(V,cv)<CONTACT){
     etat(cv,'plaquage');etat(V,'plaque');cv.plonge={x:cv.vx,y:cv.vy};contact(V,cv,6);
     evenements.push({t:r1(t),type:'plaquage',plaqueur:cv.id,porteur:V.id,x:r2(V.x),y:r2(V.y),cible:r2(o.x)});
     jalon(d.franchi.plan);
     d.attente=t+0.45;d.phase='plaquage';d.plaque={p:V,pl:cv};d.franchi=null;
    }else if(!cv||!debout(cv)||reste<-4){
     // Couvreur battu (hors d'état) : le défenseur debout le plus proche prend le relais.
     d.couvreur=def.filter(j=>debout(j)&&!j.rate).sort((a,b)=>dist(a,V)-dist(b,V)||a.slot-b.slot)[0]||null;
    }
   }else{
    vers(V,G.x+sens*1.0,G.y+ecart,V.vmax*0.97,false);
    // Plongeon d'aplati déclenché pour que le corps s'arrête juste après le ballon posé.
    const vS=Math.hypot(V.vx,V.vy);
    if(dist(V,G)<Math.max(2.1,vS*vS/(2*APLATI)+0.4)&&(V.x-ligne)*sens>-4.5){
     etat(V,'aplati');V.plonge={x:V.vx,y:V.vy};d.phase='aplati';d.aplati=t;
     // Plongeon d'aplati à côté d'un joueur au sol : ils peuvent se toucher.
     for(const o of J)if(o!==V&&!debout(o)&&dist(o,V)<4)contact(V,o,6);
     evenements.push({t:r1(t),type:'aplati',joueur:V.id,x:r2(G.x),y:r2(G.y)});
     jalon(d.etape?.plan??file.find(s=>s.k==='essai')?.plan);
    }
   }
  }else if(d.phase==='aplati'){
   if(t-d.aplati>=0.45&&ballon.porteur){
    lacher();ballon.sol=true;ballon.depose=null;ballon.x=G.x;ballon.y=G.y;ballon.h=0.12;
    S.releve=d.aplati+1.3;
   }
   if(t-d.aplati>=0.6&&S.etat==='aplati'){etat(S,'au_sol');S.plonge=null}
   if(t-d.aplati>=1.0&&!d.joie){
    d.joie=true;
    for(const j of J)if(debout(j)&&dist(j,G)<25)etat(j,j.side===T?'joie':'deception');
   }
   // Fin : 2,6 s après l'aplati, prolongée (célébration) pour durer au moins DUREE_MIN.
   if(t-d.aplati>=Math.min(4.5,Math.max(2.6,DUREE_MIN-d.aplati))){d.phase='fin';d.fin=t}
  }else if(d.phase==='cloture'){
   if(t>=d.cloture&&t>=DUREE_MIN){d.phase='fin';d.fin=t}
  }
  // Fin sur un pas de sortie : la dernière image des pistes tombe sur la durée annoncée.
  if(d.phase==='fin'&&n%Math.round(PAS_SORTIE/PAS)===0)break;
  for(const j of J){if(j.etat==='ruck'||debout(j)||['melee','saut','soutien_saut'].includes(j.etat))comportement(j)}
  for(const j of J)integrer(j);
  separer();
  for(const j of J){j.x+=j.vx*PAS;j.y+=j.vy*PAS;j.x=borne(j.x,-7,107);j.y=borne(j.y,0.3,69.7);capDe(j)}
  t=r2(t+PAS);n++;
  ballonSuit();
  if(n%Math.round(PAS_SORTIE/PAS)===0)garder();
 }
 if(d.phase!=='fin')return null;
 // Chaque fait du moteur couvert par les pistes doit avoir été montré.
 if((e.jalonsAttendus||[]).some(k=>!jalons.some(([,p])=>p===k)))return null;
 jalons.sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
 return {J,echantillons,ballonPiste,porteurs,etatsJ,evenements,contacts,jalons,duree:r1(t),G,sens,S};
}

// Pistes envoyées à la vue : positions, cap, vitesse par joueur ; ballon ; états.
function sortie(r,e,graine,phases){
 const joueurs=r.J.map((j,i)=>({id:j.id,side:j.side,slot:j.slot,vmax:j.vmax,amax:j.amax,
  x:r.echantillons.map(s=>r2(s[i][0])),y:r.echantillons.map(s=>r2(s[i][1])),
  v:r.echantillons.map(s=>r2(s[i][2])),cap:r.echantillons.map(s=>r2(s[i][3])),
  etats:r.etatsJ.get(j.id)}));
 const essai=e.type==='essai_jeu_courant';
 const o={version:VERSION,type:e.type,graine,phases,pas:PAS_SORTIE,duree:r.duree,equipe:e.equipe,sens:r.sens,vedette:r.S.id,
  joueurs,ballon:{x:r.ballonPiste.map(b=>r2(b[0])),y:r.ballonPiste.map(b=>r2(b[1])),h:r.ballonPiste.map(b=>r2(b[2])),porteurs:r.porteurs},
  evenements:r.evenements,contacts:r.contacts.map(c=>[r1(c.t0),r1(c.t1),c.a,c.b]),jalons:r.jalons,
  ouverture:(e.ouverture||{k:'jeu'}).k,coupe:!!(e.ouverture&&e.ouverture.k!=='jeu')};
 if(essai){o.marqueur=r.S.id;o.essai={x:r2(r.G.x),y:r2(r.G.y)}}
 if(Number.isInteger(e.premier))o.premier=e.premier;
 if(Number.isInteger(e.dernier))o.dernier=e.dernier;
 if(Number.isInteger(e.plan))o.plan=e.plan;
 return o;
}

// Point d'entrée : une mise en scène déterministe par graine, de DUREE_MIN secondes à DUREE_MAX
// (jusqu'à DUREE_PLAFOND quand plusieurs faits du moteur sont montrés).
function composer(entree){
 const e=valider(entree);
 const graine=(Number.isInteger(e.graine)?e.graine:hacher(JSON.stringify([e.marqueur,e.vedette,e.essai,e.ballon])))>>>0;
 const alea=tirage(graine);
 const faits=Array.isArray(e.etapes)?e.etapes.filter(s=>!s.cle&&s.k!=='recup').length+(e.ouverture&&e.ouverture.k!=='jeu'?1:0):0;
 const max=Math.min(DUREE_PLAFOND,DUREE_MAX+6*faits);
 const cible=fini(e.duree_cible)?borne(e.duree_cible,DUREE_MIN,max):Math.min(max,14+alea()*8+4*faits);
 const essais=[];
 // Deux passes au plus : la seconde (autre tirage, même graine) seulement si la première n'a rien donné de juste.
 for(let passe=0;passe<2&&!essais.some(x=>x.ecart<1000);passe++){
  for(let phases=0;phases<=4;phases++){
   const r=simuler(e,phases,(graine^Math.imul(phases+1+passe*5,0x9E3779B1))>>>0);
   if(r)essais.push({r,phases,ecart:Math.abs(r.duree-cible)+(r.duree<DUREE_MIN||r.duree>max?1000:0)});
   // Chaque ruck ajoute plusieurs secondes : inutile d'aller au-delà d'une mise en scène trop longue.
   if(r&&r.duree>Math.max(cible,max))break;
  }
 }
 essais.sort((a,b)=>a.ecart-b.ecart||a.phases-b.phases);
 const meilleur=essais[0];
 if(!meilleur||meilleur.ecart>=1000)throw new RangeError('Chorégraphe : aucune mise en scène dans la durée voulue');
 const o=sortie(meilleur.r,e,graine,meilleur.phases);
 o.dureeMax=max;
 return o;
}

// --- Entrée depuis un temps fort projeté (match-direct.cjs) et le journal --------------
const xDe=p=>p&&fini(p.x)?p.x:null;
// Plans que les pistes savent montrer avant le fait clé, en remontant le temps fort.
function remonter(plans,rec,k,T){
 let premier=k;
 const etapes=[];let ouverture=null;
 for(let i=k-1;i>=0;i--){
  const p=plans[i],r=rec(i);if(!r)break;
  if(p.kind==='carry'&&r.team===T&&r.actor!=null){
   // Un long gain (dix mètres et plus) se montre comme une percée, plaquée au bout par la couverture.
   const long=fini(r.to?.x)&&fini(r.from?.x)&&Math.abs(r.to.x-r.from.x)>=GAIN_PERCEE;
   etapes.unshift({k:long?'franchi':'porte',joueur:String(r.actor),x:xDe(r.to),depuis:xDe(r.from),plan:i});premier=i;continue;
  }
  if(p.kind==='turnover'&&r.team===T){etapes.unshift({k:'recup',joueur:r.actor!=null?String(r.actor):null,side:T,plan:i});premier=i;break}
  if((p.kind==='setpiece-win'||p.kind==='setpiece-loss')&&r.team===T&&i>0&&['lineout','scrum'].includes(plans[i-1].kind)&&r.move!=='maul'&&!r.porte){
   const l=rec(i-1);if(!l)break;
   const touche=plans[i-1].kind==='lineout';
   ouverture={k:touche?'touche':'melee',x:l.from?.x??l.to?.x,y:l.from?.y??l.to?.y,plan:i-1,planGain:i,
    [touche?'lance':'introduit']:l.team,sauteur:p.kind==='setpiece-loss'&&r.actor!=null?String(r.actor):null};
   // Le porteur que le moteur désigne avance jusqu'au point du fait.
   if(r.actor!=null&&p.kind==='setpiece-win'&&fini(r.to?.x)&&Math.abs(r.to.x-(r.from?.x??r.to.x))>=0.5)etapes.unshift({k:'porte',joueur:String(r.actor),x:r.to.x,depuis:xDe(r.from)});
   premier=i-1;break;
  }
  if(p.kind==='reception'&&i>0&&['kickoff','drop22'].includes(plans[i-1].kind)){
   const kr=rec(i-1);if(!kr||kr.actor==null||r.actor==null)break;
   ouverture={k:'envoi',x:kr.from?.x??50,y:kr.from?.y??35,botteur:String(kr.actor),receveur:String(r.actor),chute:{x:xDe(r.to)},plan:i-1,planReception:i};
   premier=i-1;break;
  }
  break;
 }
 return {premier,etapes,ouverture};
}
// Rend null si le temps fort ne contient rien que les pistes savent mettre en scène.
// `profils` : {id: {vmax, amax}} ; `avant` : scène affichée juste avant le premier plan.
function entreeDepuisTempsFort(tf,events,{profils={},avant=null,cle=''}={}){
 const plans=tf?.plans;if(!Array.isArray(plans))return null;
 const rec=k=>events?.[plans[k]?.index]?.scene||null;
 const gain=r=>r&&fini(r.to?.x)&&fini(r.from?.x)?Math.abs(r.to.x-r.from.x):0;
 let type=null,k=-1;
 const nEssai=plans.findIndex(p=>p.kind==='try');
 if(nEssai>=0){
  const r=rec(nEssai);
  if(!r||r.kind!=='try'||r.origin!=='open'||![0,1].includes(r.team)||r.actor==null)return null;
  type='essai_jeu_courant';k=nEssai;
 }else{
  for(let i=plans.length-1;i>=0;i--){const r=rec(i);if(plans[i].kind==='carry'&&r?.actor!=null&&gain(r)>=22){type='franchissement';k=i;break}}
  if(!type)for(let i=plans.length-1;i>=0;i--){
   const r=rec(i);if(!r)continue;
   if(plans[i].kind==='kick'&&r.actor!=null||plans[i].kind==='touch'&&TOUCHES_AU_PIED.includes(r.cause)){type='jeu_au_pied';k=i;break}
   if(plans[i].kind==='reception'&&i>0&&['kickoff','drop22'].includes(plans[i-1].kind)){type='jeu_au_pied';k=i;break}
  }
 }
 if(!type)return null;
 const r=rec(k),T=r.team;
 if(![0,1].includes(T))return null;
 let etapes=[],ouverture=null,premier=k,dernier=k,vedette=null,sens=null;
 if(type==='essai_jeu_courant'){
  vedette=String(r.actor);
  const amont=remonter(plans,rec,k,T);
  ({premier,ouverture}=amont);etapes=[...amont.etapes,{k:'essai',joueur:vedette,plan:k,cle:true}];
 }else if(type==='franchissement'){
  vedette=String(r.actor);sens=Math.sign(r.to.x-r.from.x);
  const amont=remonter(plans,rec,k,T);
  ({premier,ouverture}=amont);etapes=[...amont.etapes,{k:'franchi',joueur:vedette,x:r.to.x,depuis:r.from.x,plan:k,cle:true}];
  // La suite que le moteur a décidée : un temps de jeu de la même équipe, ou le ballon récupéré par l'adversaire.
  const n=plans[k+1],rn=rec(k+1);
  if(n&&rn&&n.kind==='carry'&&rn.team===T&&rn.actor!=null&&gain(rn)<22){etapes.push({k:gain(rn)>=GAIN_PERCEE?'franchi':'porte',joueur:String(rn.actor),x:xDe(rn.to),depuis:xDe(rn.from),plan:k+1});dernier=k+1}
  else if(n&&rn&&n.kind==='turnover'&&rn.team!==T){etapes.push({k:'recup',joueur:rn.actor!=null?String(rn.actor):null,side:rn.team,plan:k+1});dernier=k+1}
 }else{
  const kind=plans[k].kind;
  if(kind==='reception'){
   const kr=rec(k-1);
   if(!kr||kr.actor==null||r.actor==null)return null;
   ouverture={k:'envoi',x:kr.from?.x??50,y:kr.from?.y??35,botteur:String(kr.actor),receveur:String(r.actor),chute:{x:xDe(r.to)},plan:k-1,planReception:k};
   premier=k-1;vedette=String(kr.actor);
   // L'équipe du fait clé est celle qui botte ; le receveur est plaqué par la chasse.
   const B=rec(k-1).team;if(![0,1].includes(B))return null;
   // Ballon récupéré ensuite par l'équipe qui a botté (le moteur l'a décidé) : il est montré.
   const n=plans[k+1],rn=rec(k+1),suite=[];let fin=k;
   if(n&&rn&&n.kind==='turnover'&&rn.team===B&&r.team!==B){suite.push({k:'recup',joueur:rn.actor!=null?String(rn.actor):null,side:B,plan:k+1});fin=k+1}
   const de=ouverture.x,ch=ouverture.chute.x;
   return finir({type,equipe:B,vedette,sens:fini(ch)&&Math.abs(ch-de)>1?Math.sign(ch-de):B===0?1:-1,ouverture,etapes:suite,premier,dernier:fin,tf,plans,rec,profils,avant,cle});
  }
  // Coup de pied de jeu courant : botteur du moteur, sinon l'ouvreur (le moteur ne le nomme pas).
  const touche=kind==='touch';
  const de=xDe(r.from),vers_=xDe(r.to);
  sens=fini(de)&&fini(vers_)&&Math.abs(vers_-de)>1?Math.sign(vers_-de):T===0?1:-1;
  const amont=remonter(plans,rec,k,T);
  ({premier,ouverture}=amont);
  vedette=r.actor!=null?String(r.actor):null;
  etapes=[...amont.etapes,{k:'pied',joueur:vedette,x:vers_,issue:touche?'touche':'reception',depuis:de,plan:k,cle:true}];
  const n=plans[k+1],rn=rec(k+1);
  if(!touche&&n&&rn&&n.kind==='turnover'&&rn.team===T){etapes.push({k:'recup',joueur:rn.actor!=null?String(rn.actor):null,side:T,plan:k+1});dernier=k+1}
  return finir({type,equipe:T,vedette,sens,ouverture,etapes,premier,dernier,tf,plans,rec,profils,avant,cle,choisirBotteur:vedette==null});
 }
 return finir({type,equipe:T,vedette,sens,ouverture,etapes,premier,dernier,tf,plans,rec,profils,avant,cle});
}
function finir({type,equipe,vedette,sens,ouverture,etapes,premier,dernier,tf,plans,rec,profils,avant,cle,choisirBotteur}){
 // Scène de départ : la remise en jeu formée, sinon la scène affichée juste avant le premier plan.
 const depart=ouverture&&ouverture.k!=='jeu'?plans[premier].scene:premier>0?plans[premier-1].scene:(avant||tf.depart);
 if(!depart||!Array.isArray(depart.players))return null;
 const mis=depart.players.find(p=>p.featured&&p.side===depart.possession);
 const joueurs=depart.players.map(p=>({id:p.id,side:p.side,slot:p.slot,x:p.x,y:p.y}));
 if(choisirBotteur){
  // Botteur d'un coup de pied en touche : l'ouvreur, sinon l'arrière, sinon le demi (choix de mise en scène).
  const pick=[9,14,8].map(s=>joueurs.find(p=>p.side===equipe&&p.slot===s)).find(Boolean);
  if(!pick)return null;
  vedette=String(pick.id);etapes.at(-1).joueur=vedette;
 }
 // Consigne défensive de chaque équipe (plans.defence du fait clé), pour la ligne défensive.
 const r=rec(dernier)||rec(premier);
 const defense=Array.isArray(r?.plans?.defence)?r.plans.defence.map(String):null;
 // Faits du moteur couverts par les pistes : chacun doit être montré.
 const jalonsAttendus=[];for(let i=premier;i<=dernier;i++)if(plans[i].kind!=='transformation')jalonsAttendus.push(i);
 const e={type,equipe,porteur:mis?mis.id:null,possession:[0,1].includes(depart.possession)?depart.possession:equipe,
  ballon:{x:depart.ball?.x??50,y:depart.ball?.y??35},joueurs,profils,etapes,ouverture:ouverture||{k:'jeu'},premier,dernier,plan:premier,jalonsAttendus,
  graine:hacher(cle+'|'+plans[dernier].index)};
 if(defense)e.defense=defense;
 if(type==='essai_jeu_courant'){e.marqueur=vedette;e.essai={x:plans[dernier].scene.ball.x,y:plans[dernier].scene.ball.y}}
 else{e.vedette=vedette;e.sens=sens}
 return e;
}

module.exports=Object.freeze({VERSION,PAS,PAS_SORTIE,DUREE_MIN,DUREE_MAX,DUREE_PLAFOND,ECART,EN_BUT,ETATS,TYPES,profil,composer,entreeDepuisTempsFort,hacher});
