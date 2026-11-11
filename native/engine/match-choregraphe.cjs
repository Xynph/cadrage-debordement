'use strict';
// Chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1, éteint par défaut).
//
// Micro-simulation de présentation : à partir des faits que le moteur a déjà décidés
// pour une action (équipe, porteur, marqueur, positions de départ, point d'essai),
// elle produit des trajectoires continues pour les trente joueurs et le ballon, pas à
// pas (0,1 s), avec un état d'animation par joueur. Elle ne lit ni n'écrit la
// carrière, ne consomme aucun tirage du moteur et ne change jamais l'issue : elle met
// en scène ce que le moteur a décidé (ici, l'essai et son marqueur).
//
// Première tranche : un seul type d'action, l'essai en jeu courant (origine « open »).
// Conception : docs/match-choregraphe-20261112.md.

const VERSION=1;
const PAS=0.1;              // pas de la micro-simulation, en secondes
const PAS_SORTIE=0.2;       // pas des pistes envoyées à la vue
const DUREE_MIN=12, DUREE_MAX=25;
const DUREE_LIMITE=40;      // garde-fou : au-delà, la mise en scène est abandonnée
const EN_BUT=2;             // le ballon est aplati 2 m derrière la ligne (même règle que la vue)
const ECART=0.7;            // distance visée entre deux joueurs hors contact (garantie : 0,6 m), en mètres
const EVITEMENT=1.7;        // rayon d'évitement (direction voulue), en mètres
const CHUTE=9;              // décélération d'une chute ou d'un plongeon, en m/s²
const CONTACT=1.0;          // distance du plaquage
const RATE=1.35;            // distance où un défenseur tente (et rate) le plaquage du marqueur
const ETATS=Object.freeze(['course','passe','reception','plaquage','plaque','plaquage_rate','au_sol','se_relever','ruck','ramassage','aplati','joie','deception']);
// États de contact : la décélération y est celle d'une chute, pas celle d'une course.
const CHUTES=new Set(['plaquage','plaque','plaquage_rate','aplati','au_sol']);
// Allure plafond par état (m/s) ; null = plafond du profil.
const PLAFOND=Object.freeze({course:null,passe:null,reception:null,plaquage:null,plaque:null,plaquage_rate:null,au_sol:0,se_relever:0.4,ruck:0.6,ramassage:1.5,aplati:null,joie:2.5,deception:1.5});

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

function valider(e){
 if(!e||typeof e!=='object')throw new TypeError('Chorégraphe : entrée absente');
 if(e.type!=='essai_jeu_courant')throw new RangeError('Chorégraphe : type non pris en charge : '+e.type);
 if(![0,1].includes(e.equipe))throw new RangeError('Chorégraphe : équipe invalide');
 const joueurs=(e.joueurs||[]).filter(p=>p&&p.id!=null&&[0,1].includes(p.side)&&Number.isFinite(p.x)&&Number.isFinite(p.y));
 const ids=new Set(joueurs.map(p=>String(p.id)));
 if(joueurs.length<20||ids.size!==joueurs.length)throw new RangeError('Chorégraphe : joueurs incomplets');
 const marqueur=joueurs.find(p=>String(p.id)===String(e.marqueur));
 if(!marqueur||marqueur.side!==e.equipe)throw new RangeError('Chorégraphe : marqueur absent de son équipe');
 if(!e.essai||![0,100].includes(e.essai.x)||!Number.isFinite(e.essai.y))throw new RangeError('Chorégraphe : point d’essai invalide');
 if(!e.ballon||!Number.isFinite(e.ballon.x)||!Number.isFinite(e.ballon.y))throw new RangeError('Chorégraphe : ballon de départ invalide');
 if(![0,1].includes(e.possession))throw new RangeError('Chorégraphe : possession de départ invalide');
 return {...e,joueurs};
}

// Une mise en scène complète pour `phases` temps de jeu intermédiaires (porteur plaqué, ruck).
function simuler(e,phases,graine){
 const alea=tirage(graine);
 const T=e.equipe,sens=e.essai.x===100?1:-1,ligne=e.essai.x;
 const G={x:ligne+sens*EN_BUT,y:borne(e.essai.y,5,65)};
 const J=e.joueurs.map(p=>{const pr=e.profils?.[p.id]||profil(p.slot,undefined);return {id:String(p.id),side:p.side,slot:p.slot|0,x:borne(p.x,-3,103),y:borne(p.y,0.5,69.5),vx:0,vy:0,vmax:pr.vmax,amax:pr.amax,etat:'course',depuis:0,role:'',cible:null,allure:0,arrive:true,cap:p.side===0?0:Math.PI,suite:[],plonge:null,rate:false}});
 const parId=new Map(J.map(j=>[j.id,j]));
 const att=J.filter(j=>j.side===T),def=J.filter(j=>j.side!==T);
 const S=parId.get(String(e.marqueur));
 const demiDe=side=>J.find(j=>j.side===side&&j.slot===8);
 const demi=demiDe(T)||att.filter(j=>j!==S).sort((a,b)=>Math.abs(a.slot-8)-Math.abs(b.slot-8))[0];
 const arriere=def.find(j=>j.slot===14)||null;
 // Côté du jeu : vers le point d'essai, sinon vers le grand côté.
 const cote=y=>Math.abs(G.y-y)>4?Math.sign(G.y-y):(y<35?1:-1);
 let t=0;
 const contacts=[],evenements=[],echantillons=[],ballonPiste=[],porteurs=[],etatsJ=new Map(J.map(j=>[j.id,[[0,'course']]]));
 const ballon={x:e.ballon.x,y:e.ballon.y,h:1,porteur:null,vol:null,sol:false};
 // Paires au contact voulu (plaquage, ruck, plongeon) : seules autorisées sous l'écart minimal.
 const paires=new Map();
 const cle=(a,b)=>a.id<b.id?a.id+'|'+b.id:b.id+'|'+a.id;
 const contact=(a,b,duree)=>{const c={a:a.id,b:b.id,t0:t,t1:t+duree};contacts.push(c);const k=cle(a,b);if(!paires.has(k))paires.set(k,[]);paires.get(k).push(c)};
 // Deux joueurs libres (debout, ni liés ni en train de ramasser) s'évitent même dans une fenêtre de contact.
 const libre=j=>debout(j)&&j.etat!=='ramassage';
 const enContact=(a,b)=>{if(libre(a)&&libre(b))return false;const l=paires.get(cle(a,b));return !!l&&l.some(c=>t>=c.t0-0.05&&t<=c.t1+0.05)};
 const etat=(j,nom,suite=[])=>{if(!ETATS.includes(nom))throw Error(nom);j.etat=nom;j.depuis=t;j.suite=suite;const l=etatsJ.get(j.id);if(l.at(-1)[1]!==nom)l.push([r1(t),nom])};
 const tenir=j=>{ballon.porteur=j.id;ballon.vol=null;ballon.sol=false;if(porteurs.at(-1)?.[1]!==j.id)porteurs.push([r1(t),j.id])};
 const lacher=()=>{ballon.porteur=null;if(porteurs.at(-1)?.[1]!==null)porteurs.push([r1(t),null])};
 const debout=j=>!['plaquage','plaque','plaquage_rate','au_sol','se_relever','ruck','aplati'].includes(j.etat);
 const vers=(j,x,y,allure,arrive=true)=>{j.cible={x:borne(x,-4,104),y:borne(y,1,69)};j.allure=Math.min(allure,j.vmax);j.arrive=arrive};

 // Porteur de départ : le joueur mis en avant par la scène de départ, sinon le plus proche du ballon.
 const pos0=e.possession;
 let porteur=(e.porteur!=null&&parId.get(String(e.porteur))?.side===pos0)?parId.get(String(e.porteur)):null;
 if(!porteur)porteur=J.filter(j=>j.side===pos0).sort((a,b)=>dist(a,ballon)-dist(b,ballon))[0];
 tenir(porteur);
 // Direction du jeu (machine à états du metteur en scène).
 const d={phase:'porte',porteur,reste:phases,ruck:null,passe:null,chaine:[],soutiens:[],plaqueur:null,objectif:null,perdu:pos0!==T,fin:null,aplati:null,ouvreur:null,coureur:null,attente:0};

 function choisirSoutiens(p){
  return J.filter(j=>j.side===p.side&&j!==p&&j!==S&&j!==demi&&debout(j)).sort((a,b)=>dist(a,p)-dist(b,p)||a.slot-b.slot).slice(0,2);
 }
 function lancerPorte(p,gain){
  d.phase='porte';d.porteur=p;tenir(p);
  const s=p.side===T?sens:-sens;
  d.objectif={x:p.x+s*gain,y:borne(p.y+(alea()-0.5)*3,4,66)};
  d.soutiens=choisirSoutiens(p);
  // Plaqueur : le défenseur debout le plus proche du point visé (l'arrière garde la profondeur).
  d.plaqueur=J.filter(j=>j.side!==p.side&&debout(j)&&j!==arriere).sort((a,b)=>dist(a,d.objectif)-dist(b,d.objectif)||a.slot-b.slot)[0];
  evenements.push({t:r1(t),type:'course',joueur:p.id});
 }
 function formerRuck(p,pl){
  const s=p.side===T?sens:-sens;
  // Le plaqué présente le ballon vers son camp (loi 14).
  const B={x:p.x-s*0.7,y:p.y};
  lacher();ballon.sol=true;ballon.x=B.x;ballon.y=B.y;
  const recupere=p.side!==T; // ballon perdu par l'adversaire : l'équipe qui va marquer le récupère
  const lies=[];
  // Liaison au-dessus du ballon : l'équipe qui va marquer sur le ballon, l'autre en face ; le demi se tient derrière.
  const lier=(j,cote)=>{lies.push(j);j.lie={x:B.x+sens*(cote>0?0.2:1.0),y:B.y+(lies.length%2?0.45:-0.45)}};
  const arrivants=(side,n,exclus)=>J.filter(j=>j.side===side&&debout(j)&&!exclus.includes(j)&&j!==S&&j!==demi&&j!==d.ouvreur).sort((a,b)=>dist(a,B)-dist(b,B)||a.slot-b.slot).slice(0,n);
  const nAtt=arrivants(T,2,[p,pl]),nDef=arrivants(1-T,1,[p,pl]);
  d.ruck={B,forme:t,att:nAtt,def:nDef,recupere,ramasseur:demi,lies};
  nAtt.forEach(j=>lier(j,1));
  nDef.forEach(j=>lier(j,-1));
  d.phase='ruck';
  evenements.push({t:r1(t),type:'ruck',x:r2(B.x),y:r2(B.y),recupere});
 }
 // Ligne de hors-jeu d'un ruck (loi 15) : pied le plus en arrière de son équipe dans le ruck.
 const horsJeu=side=>d.ruck?d.ruck.B.x+(side===T?-sens*1.0:sens*1.6):null;
 const enJeu=j=>{const l=horsJeu(j.side);if(l===null)return true;const s=j.side===T?sens:-sens;return (l-j.x)*s>=-0.05};
 function passer(de,a){
  lacher();
  const vol=Math.max(0.38,dist(de,a)/11);
  ballon.vol={de:{x:de.x,y:de.y},a:a.id,t0:t,t1:t+vol,depuis:de.id};
  // Passe jamais vers l'avant (loi 11) : le receveur prend le ballon en retrait du point de lâcher.
  d.passe={de,a,t1:t+vol,lache:{x:de.x,y:de.y}};
  etat(de,'passe');
  evenements.push({t:r1(t),type:'passe',de:de.id,vers:a.id,lache:{x:r2(de.x),y:r2(de.y)}});
  d.phase='passe';
 }
 const placeSoutien=(p,cote_,lat,recul)=>({x:p.x-sens*recul,y:borne(p.y+cote_*lat,3,67)});
 // Le receveur est-il prêt : en retrait du passeur, à portée de passe, et le restera pendant le vol.
 function pret(de,a){
  const vol=Math.max(0.38,dist(de,a)/11),fx=a.x+a.vx*vol;
  return (de.x-fx)*sens>=0.6&&(de.x-a.x)*sens>=0.9&&dist(de,a)<=14&&dist(de,a)>=2.5;
 }

function lancerPercee(){
  d.phase='percee';
  // Tentatives de plaquage (toutes ratées) : les deux défenseurs debout les plus proches et l'arrière.
  d.tentatives=new Set(def.filter(j=>debout(j)&&j!==arriere).sort((a,b)=>dist(a,S)-dist(b,S)||a.slot-b.slot).slice(0,2));
  if(arriere)d.tentatives.add(arriere);
  evenements.push({t:r1(t),type:'percee',joueur:S.id});
 }
 // `phases` : nombre de rucks avant le jeu final. Ballon adverse au départ : le premier est un ballon récupéré.
 if(d.perdu){if(phases<1)return null;d.reste=phases-1;lancerPorte(porteur,1.5)}
 else if(phases>0){d.reste=phases-1;lancerPorte(porteur,3+alea()*3)}
 else if(porteur===S)lancerPercee();
 else{d.phase='tenu';d.chaine=[S];d.tenuDepuis=0}

 // --- Comportements par rôle --------------------------------------------------
 function comportement(j){
  if(!debout(j)&&j.etat!=='ruck')return; // chute, sol, relevé : géré par l'état
  if(j.etat==='ruck'){vers(j,j.lie.x,j.lie.y,3);return}
  if(['joie','deception'].includes(j.etat)){j.cible=null;return}
  // Joueur appelé au ruck : il y court, puis se lie.
  if(j.lie&&d.ruck&&d.ruck.lies.includes(j)&&(d.phase==='ruck'||d.phase==='plaquage')){
   if(dist(j,j.lie)<0.6)etat(j,'ruck');else vers(j,j.lie.x,j.lie.y,j.vmax*0.9);
   return;
  }
  // Porteur et plaqueur d'un temps de jeu, quelle que soit l'équipe (ballon récupéré compris).
  if(d.phase==='porte'&&j===d.porteur){const s=j.side===T?sens:-sens;vers(j,d.objectif.x+s*6,d.objectif.y,j.vmax*0.8,false);return}
  if(d.phase==='porte'&&j===d.plaqueur){
   // Le plaqueur vise l'endroit où le porteur sera (anticipation bornée), jamais un point fixe.
   const p=d.porteur,lead=Math.min(0.8,dist(j,p)/8);
   vers(j,p.x+p.vx*lead,p.y+p.vy*lead,j.vmax*0.9,false);return;
  }
  const b=ballon.porteur?parId.get(ballon.porteur):null;
  const bx=b?b.x:ballon.vol?(ballon.x):ballon.x,by=b?b.y:ballon.y;
  // Fin : après l'essai, chacun ralentit ; les partenaires proches rejoignent le marqueur.
  if(d.phase==='aplati'||d.phase==='fin'){
   if(j.side===T&&dist(j,G)<22&&j!==S)vers(j,G.x-sens*2.5+(j.slot%3-1)*1.2,G.y+(j.slot%2?1.5:-1.5),4);
   else if(dist(j,S)<5){const l=dist(j,S)||1;vers(j,j.x+(j.x-S.x)/l*2.5,j.y+(j.y-S.y)/l*2.5,3)} // on s'écarte du marqueur au sol
   else vers(j,j.x+j.vx*0.6,j.y+j.vy*0.6,2);
   return;
  }
  if(j.side===T){
   if(d.phase==='percee'){
    // Percée : les partenaires suivent le marqueur à distance, sans le dépasser (loi 10).
    if(j===S)return;
    const p=S,dx=(p.x-j.x)*sens;
    const lat=borne(j.y-p.y,-12,12);
    vers(j,p.x-sens*Math.max(3,Math.min(dx,10)),p.y+lat*0.8,j.vmax*0.85,false);
    return;
   }
   if(j===ballon.porteur&&d.phase==='tenu'){
    // Il fixe la défense en avançant, sans courir vers la ligne d'en-but.
    vers(j,j.x+sens*4,j.y,3.2,false);return;
   }
   // Receveur désigné : en retrait et sur le côté du passeur.
   const passeur=d.phase==='ruck'?null:(ballon.porteur?parId.get(ballon.porteur):null);
   const ruckB=d.ruck?.B;
   const prochain=d.phase==='ruck'?(d.reste>0?d.coureur:d.chaine[0]):d.phase==='tenu'?d.chaine[0]:null;
   const c=cote(by);
   if(j===demi&&d.phase==='ruck'&&ruckB){vers(j,ruckB.x-sens*0.7,ruckB.y,j.vmax*0.9);return}
   if(j===demi&&d.phase==='porte'&&j!==ballon.porteur){const p=parId.get(ballon.porteur);vers(j,p.x-sens*3,p.y-c*1.5,j.vmax*0.75);return}
   if(prochain===j){
    const ref=ruckB&&d.phase==='ruck'?{x:ruckB.x-sens*0.7,y:ruckB.y}:passeur||{x:bx,y:by};
    const lat=j===d.coureur?4:j===S&&d.chaine.length===1?(d.ouvreur?13:7):6.5;
    const recul=j===d.coureur?3:j===S?6:4.5;
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
   if(d.soutiens.includes(j)&&d.phase==='porte'){
    const p=parId.get(ballon.porteur),k=d.soutiens.indexOf(j);
    const q=placeSoutien(p,k?1:-1,1.8,1.6);
    vers(j,q.x,q.y,j.vmax*0.85,false);return;
   }
   if(j===S||j===d.ouvreur){
    const ref=ruckB||{x:bx,y:by},k=j===S?1:0;
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
  if(j===arriere){
   if(d.phase==='percee'&&p){
    // Couverture : il coupe la course du marqueur, sans le rattraper s'il est battu.
    vers(j,p.x+sens*Math.max(2,(G.x-p.x)*sens*0.35),p.y+(G.y-p.y)*0.35,j.vmax*0.95,false);return;
   }
   vers(j,sens>0?Math.min(bx+18,ligne-3):Math.max(bx-18,ligne+3),by*0.7+35*0.3,5);return;
  }
  if(d.phase==='percee'&&p){
   const vS=Math.hypot(p.vx,p.vy);
   if(d.tentatives.has(j)&&!j.rate){vers(j,p.x+p.vx*0.3,p.y+p.vy*0.3,j.vmax,false);return}
   // Les autres couvrent : devant le marqueur, ils reculent vers leur ligne ; derrière, ils le poursuivent sans le rattraper.
   // Devant lui : ils reculent vers leur ligne en s'écartant de sa course.
   if((j.x-p.x)*sens>0){const ecart=Math.abs(j.y-G.y)<6?Math.sign((j.y-G.y)||1)*6:0;vers(j,ligne+sens*1,borne(j.y+ecart,2,68),Math.min(j.vmax,vS*0.8+0.3),true)}
   else vers(j,p.x-sens*2.5,p.y,Math.min(j.vmax,vS*0.8),false);
   return;
  }
  // Ligne défensive : en jeu, étalée sur la largeur, elle glisse vers le ballon puis monte.
  const ligneDef=def.filter(x=>x!==arriere&&debout(x)).sort((a,b)=>a.y-b.y||a.slot-b.slot);
  const k=ligneDef.indexOf(j),n=ligneDef.length;
  const ref=d.ruck&&d.phase==='ruck'?d.ruck.B:{x:bx,y:by};
  const centre=borne(ref.y,3+((n-1)/2)*6,67-((n-1)/2)*6);
  const voulu=centre+(k-(n-1)/2)*6.2;
  let y=borne(voulu+(by-ref.y)*0.5,2,68),x;
  if(d.phase==='ruck'){x=horsJeu(j.side)+sens*0.9}
  else{const monte=Math.min(4,(t-(d.debutJeu??t))*2.5);x=ref.x+sens*Math.max(1.2,4.5-monte)}
  // Jamais devant la ligne de hors-jeu pendant un ruck.
  if(d.phase==='ruck'&&!enJeu(j))x=horsJeu(j.side)+sens*1.0;
  vers(j,x,y,d.phase==='ruck'?5.5:Math.min(j.vmax,5.5));
 }

 // Paires qui cherchent le contact : elles ne s'évitent pas (porteur et plaqueur, marqueur et
 // défenseurs qui tentent de le plaquer ; le marqueur en percée ne dévie que sur un plongeon).
 const veutContact=(j,o)=>d.phase==='porte'&&(j===d.porteur&&o===d.plaqueur||j===d.plaqueur&&o===d.porteur)||
  d.phase==='percee'&&o===S&&d.tentatives.has(j);
 // --- Intégration : vitesses et accélérations plafonnées ------------------------
 function integrer(j){
  const chute=CHUTES.has(j.etat);
  const plafond=PLAFOND[j.etat]==null?j.vmax:Math.min(j.vmax,PLAFOND[j.etat]);
  let wx=0,wy=0,danger=0,ex=0,ey=0;
  // Évitement : on contourne les autres joueurs, sauf au contact voulu. Anticipation sur
  // 1,4 s (point de plus courte approche) en plus d'une répulsion de proximité.
  if(debout(j)&&j.etat!=='ruck'&&!(d.phase==='percee'&&j===S)){
   for(const o of J){
    if(o===j||enContact(j,o)||veutContact(j,o))continue;
    const px=o.x-j.x,py=o.y-j.y,l=Math.hypot(px,py);
    if(l>8)continue;
    // Un joueur au sol occupe sa longueur : on le contourne plus large.
    const rayon=EVITEMENT+(debout(o)?0:0.6),force=3+j.allure;
    if(l<rayon&&l>1e-6){const f=(rayon-l)/rayon*force;ex-=px/l*f;ey-=py/l*f;danger=Math.max(danger,(rayon-l)/rayon)}
    const rx=o.vx-j.vx,ry=o.vy-j.vy,rr=rx*rx+ry*ry;
    if(rr<1e-6)continue;
    const tc=borne(-(px*rx+py*ry)/rr,0,1.4);
    if(tc<=0)continue;
    const cx=px+rx*tc,cy=py+ry*tc,dc=Math.hypot(cx,cy),seuil=debout(o)?1.5:2.1;
    if(dc<seuil){const f=(seuil-dc)/seuil*(3+j.allure)/(1+tc),ux=dc>1e-6?cx/dc:-ry/Math.sqrt(rr),uy=dc>1e-6?cy/dc:rx/Math.sqrt(rr);ex-=ux*f;ey-=uy*f;danger=Math.max(danger,(seuil-dc)/seuil/(1+tc))}
   }
  }
  // Plus le risque de heurt est grand, plus l'attrait de la cible cède devant l'évitement.
  if(j.plonge){wx=j.plonge.x;wy=j.plonge.y}
  else if(j.cible&&debout(j)||j.etat==='ruck'){
   const dx=j.cible.x-j.x,dy=j.cible.y-j.y,l=Math.hypot(dx,dy);
   if(l>0.05){let a=j.allure*(1-0.8*Math.min(1,danger));if(j.arrive)a=Math.min(a,Math.sqrt(2*j.amax*0.7*Math.max(0,l-0.1)));wx=dx/l*a;wy=dy/l*a}
  }
  wx+=ex;wy+=ey;
  const w=Math.hypot(wx,wy);if(w>plafond){wx*=plafond/w;wy*=plafond/w}
  const amax=chute?CHUTE:j.amax;
  // Limites du terrain (en-buts compris) : on freine à temps, sans arrêt brutal contre la limite.
  const arret=v=>v*v/(2*amax*0.85);
  if(j.vx>0&&j.x+arret(j.vx)>=104.6)wx=Math.min(wx,0);
  if(j.vx<0&&j.x-arret(j.vx)<=-4.6)wx=Math.max(wx,0);
  if(j.vy>0&&j.y+arret(j.vy)>=69.6)wy=Math.min(wy,0);
  if(j.vy<0&&j.y-arret(j.vy)<=0.4)wy=Math.max(wy,0);
  let ax=wx-j.vx,ay=wy-j.vy;const a=Math.hypot(ax,ay),lim=amax*PAS;
  if(a>lim){ax*=lim/a;ay*=lim/a}
  j.vx+=ax;j.vy+=ay;
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
   if(voulu>0){const c=voulu/2,ca=Math.min(c,a.marge??0),cb=Math.min(c,b.marge??0);a.vx+=ux*ca;a.vy+=uy*ca;b.vx-=ux*cb;b.vy-=uy*cb;a.marge-=ca;b.marge-=cb}
  }
 }

 // --- Boucle ---------------------------------------------------------------
 let n=0;
 const garder=()=>{
  echantillons.push(J.map(j=>[j.x,j.y,Math.hypot(j.vx,j.vy),j.cap]));
  let bx=ballon.x,by=ballon.y,bh=ballon.h;
  ballonPiste.push([bx,by,bh]);
 };
 const capDe=j=>{
  const v=Math.hypot(j.vx,j.vy);
  let voulu=j.cap;
  if(j.plonge||v>2)voulu=Math.atan2(j.vy,j.vx);
  else if(debout(j)){const b=ballon.porteur?parId.get(ballon.porteur):ballon;voulu=Math.atan2(b.y-j.y,b.x-j.x)}
  const diff=Math.atan2(Math.sin(voulu-j.cap),Math.cos(voulu-j.cap)),max=6*PAS;
  j.cap+=borne(diff,-max,max);j.cap=Math.atan2(Math.sin(j.cap),Math.cos(j.cap));
 };
 for(const j of J){const b=ballon;j.cap=Math.atan2(b.y-j.y,b.x-j.x)}
 const ballonSuit=()=>{
  if(ballon.porteur){
   const p=parId.get(ballon.porteur);const c=Math.cos(p.cap),s=Math.sin(p.cap);ballon.x=p.x+c*0.3;ballon.y=p.y+s*0.3;ballon.h=1.0;
   // Aplati : le ballon va des mains au point d'essai, sans saut.
   if(p.etat==='aplati'){const k=Math.min(1,(t-p.depuis)/0.45);ballon.x+=(G.x-ballon.x)*k;ballon.y+=(G.y-ballon.y)*k;ballon.h=1.0-0.88*k}
  }
  else if(ballon.vol){const v=ballon.vol,a=parId.get(v.a),k=borne((t-v.t0)/(v.t1-v.t0),0,1);ballon.x=v.de.x+(a.x-v.de.x)*k;ballon.y=v.de.y+(a.y-v.de.y)*k;ballon.h=1.0+Math.sin(k*Math.PI)*0.35}
  else if(ballon.sol){ballon.h=0.15}
 };
 ballonSuit();garder();
 while(t<DUREE_LIMITE){
  // Décisions du metteur en scène.
  for(const j of J){
   // Fin d'un état temporaire.
   const age=t-j.depuis;
   if(j.etat==='passe'&&age>=0.35)etat(j,'course');
   if(j.etat==='reception'&&age>=0.3)etat(j,'course');
   if(j.etat==='ramassage'&&age>=0.4&&d.phase!=='ramassage')etat(j,'course');
   if(j.etat==='plaquage'&&age>=0.7){etat(j,'au_sol');j.plonge=null}
   if(j.etat==='plaquage_rate'&&age>=0.55){etat(j,'au_sol');j.plonge=null}
   if(j.etat==='plaque'&&age>=0.7)etat(j,'au_sol');
   if(j.etat==='au_sol'&&j.releve!=null&&t>=j.releve){etat(j,'se_relever');j.releve=null}
   if(j.etat==='se_relever'&&age>=1.0)etat(j,'course');
   if(j.etat==='ruck'&&d.phase!=='ruck'&&age>0.3)etat(j,'course');
   if(j.plonge){const v=Math.hypot(j.vx,j.vy);j.plonge={x:j.vx*Math.max(0,v-CHUTE*PAS)/Math.max(v,1e-6),y:j.vy*Math.max(0,v-CHUTE*PAS)/Math.max(v,1e-6)}}
  }
  if(d.phase==='porte'){
   const p=d.porteur;
   if(!d.debutJeu)d.debutJeu=t;
   // Plaqueur désigné hors d'état ou distancé : le défenseur debout le plus proche prend le relais.
   if(!debout(d.plaqueur)||t-d.debutJeu>3&&dist(d.plaqueur,p)>4){
    const relais=J.filter(j=>j.side!==p.side&&debout(j)).sort((a,b)=>dist(a,p)-dist(b,p)||a.slot-b.slot)[0];
    if(relais)d.plaqueur=relais;
   }
   const pl=d.plaqueur;
   if(pl&&dist(p,pl)<CONTACT){
    // Plaquage réussi (loi 14) : porteur amené au sol, ballon présenté, ruck.
    etat(pl,'plaquage');etat(p,'plaque');
    pl.plonge={x:pl.vx,y:pl.vy};
    contact(p,pl,6);
    evenements.push({t:r1(t),type:'plaquage',plaqueur:pl.id,porteur:p.id});
    d.attente=t+0.45;d.phase='plaquage';d.plaque={p,pl};
   }
  }else if(d.phase==='plaquage'&&t>=d.attente){
   formerRuck(d.plaque.p,d.plaque.pl);
   // Plaqueur et plaqué se relèvent une fois le ballon joué ; ils restent au contact jusque-là.
   // Membres du ruck, plaqueur, plaqué et ramasseur : au contact jusqu'à ce que le ballon soit joué.
   const groupe=[d.plaque.p,d.plaque.pl,...d.ruck.att,...d.ruck.def,d.ruck.ramasseur].filter((j,i,l)=>j&&l.indexOf(j)===i);
   d.ruck.groupe=groupe;d.ruck.contacts=[];
   for(let a=0;a<groupe.length;a++)for(let b=a+1;b<groupe.length;b++){contact(groupe[a],groupe[b],30);d.ruck.contacts.push(contacts.at(-1))}
   if(d.reste>0&&!d.ruck.recupere){
    // Prochain porteur : un avant debout, lancé depuis le ruck.
    d.coureur=att.filter(j=>debout(j)&&j!==S&&j!==demi&&!d.ruck.att.includes(j)&&j.slot<8).sort((a,b)=>dist(a,d.ruck.B)-dist(b,d.ruck.B)||a.slot-b.slot)[0]||att.filter(j=>debout(j)&&j!==S&&j!==demi&&!d.ruck.att.includes(j)).sort((a,b)=>dist(a,d.ruck.B)-dist(b,d.ruck.B))[0];
   }else if(d.ruck.recupere&&d.reste>0){
    d.coureur=att.filter(j=>debout(j)&&j!==S&&j!==demi&&!d.ruck.att.includes(j)).sort((a,b)=>dist(a,d.ruck.B)-dist(b,d.ruck.B)||a.slot-b.slot)[0];
   }else{
    // Dernier ruck : le demi joue vers le marqueur, avec un relais si le marqueur est loin.
    d.coureur=null;
    if(S===demi)d.chaine=[];
    else{
     const ouvreur=att.find(j=>j.slot===9&&j!==S&&debout(j)&&!d.ruck.att.includes(j));
     d.ouvreur=S.slot>=10&&ouvreur&&alea()<0.75?ouvreur:null;
     d.chaine=d.ouvreur?[d.ouvreur,S]:[S];
    }
   }
  }else if(d.phase==='ruck'){
   const r=d.ruck,ram=r.ramasseur;
   const tousEnJeu=def.every(j=>!debout(j)||r.def.includes(j)||enJeu(j))&&att.every(j=>!debout(j)||r.att.includes(j)||j===ram||enJeu(j));
   const pret_=t-r.forme>=1.4&&dist(ram,{x:r.B.x-sens*0.7,y:r.B.y})<1.0;
   const prochain=d.reste>0?d.coureur:d.chaine[0];
   const prochainPret=!prochain||(ram.x-prochain.x)*sens>=1.5;
   if(pret_&&tousEnJeu&&prochainPret||t-r.forme>6){
    etat(ram,'ramassage');tenir(ram);ballon.sol=false;
    evenements.push({t:r1(t),type:'ramassage',joueur:ram.id,horsJeuRespecte:tousEnJeu});
    d.phase='ramassage';d.attente=t+0.4;
    // Tous se relèvent : le ruck est fini quand le ballon est joué.
    for(const j of J)if(j.etat==='au_sol'&&j.releve==null)j.releve=t+0.2+((j.slot*7)%5)*0.1;
    // Fin des contacts du ruck une seconde et demie après le ballon joué (le temps de se relever et de s'écarter).
    for(const c of r.contacts)c.t1=t+1.5;
   }
  }else if(d.phase==='ramassage'&&t>=d.attente&&(pret(demi,d.reste>0?d.coureur:d.chaine[0]||demi)||d.chaine.length===0&&d.reste<=0)){
   // Le demi ne passe qu'à un receveur en retrait (loi 11) ; il l'attend (abandon au-delà de six secondes).
   const r=d.ruck;
   d.ruck=null;d.debutJeu=t;
   if(d.reste>0){d.reste--;passer(demi,d.coureur);d.suivant='porte'}
   else if(d.chaine.length===0)lancerPercee();
   else{passer(demi,d.chaine[0]);d.suivant=d.chaine.length>1?'tenu':'percee'}
   void r;
  }else if(d.phase==='ramassage'&&t>=d.attente+6){return null
  }else if(d.phase==='tenu'){
   const p=parId.get(ballon.porteur),a=d.chaine[0];
   if(t-(d.tenuDepuis??(d.tenuDepuis=t))>=0.3&&pret(p,a)){d.tenuDepuis=null;passer(p,a);d.suivant=d.chaine.length>1?'tenu':'percee'}
   else if(t-d.tenuDepuis>8)return null; // receveur jamais en retrait : mise en scène abandonnée
  }else if(d.phase==='passe'&&t>=d.passe.t1){
   const a=d.passe.a;
   tenir(a);etat(a,'reception');
   evenements.push({t:r1(t),type:'reception',joueur:a.id});
   if(d.suivant==='porte'){lancerPorte(a,2.5+alea()*3.5);d.debutJeu=t}
   else{
    d.chaine=d.chaine.slice(1);
    if(d.suivant==='tenu'){d.phase='tenu';d.tenuDepuis=t}
    else lancerPercee();
   }
  }else if(d.phase==='percee'){
   // Tout plaquage tenté sur le marqueur est raté : le moteur a donné l'essai.
   // Un défenseur qui arrive au contact du marqueur tente aussi (et rate) : personne ne le traverse.
   for(const j of def){
    if(j.rate||!debout(j)||dist(j,S)>RATE)continue;
    j.rate=true;etat(j,'plaquage_rate');
    const dx=S.x+S.vx*0.25-j.x,dy=S.y+S.vy*0.25-j.y,l=Math.hypot(dx,dy)||1,v=Math.max(3,Math.min(j.vmax,Math.hypot(j.vx,j.vy)+1));
    j.plonge={x:dx/l*v,y:dy/l*v};j.releve=t+1.6;
    contact(S,j,1.2);
    // Plusieurs plongeons sur le même porteur : ils peuvent finir l'un contre l'autre.
    for(const o of def)if(o!==j&&o.rate&&!debout(o)&&dist(o,j)<4)contact(o,j,2.5);
    // Cadrage-débordement : le marqueur s'écarte du côté opposé au plongeon.
    d.ecart={cote:Math.sign((S.y-j.y)||1),jusque:t+0.7};
    evenements.push({t:r1(t),type:'plaquage_rate',plaqueur:j.id,porteur:S.id});
   }
   const ecart=d.ecart&&t<d.ecart.jusque?d.ecart.cote*2.5:0;
   vers(S,G.x+sens*1.0,G.y+ecart,S.vmax*0.97,false);
   if(dist(S,G)<2.1&&(S.x-ligne)*sens>-2.2){
    etat(S,'aplati');S.plonge={x:S.vx,y:S.vy};d.phase='aplati';d.aplati=t;
    evenements.push({t:r1(t),type:'aplati',joueur:S.id,x:r2(G.x),y:r2(G.y)});
   }
  }else if(d.phase==='aplati'){
   if(t-d.aplati>=0.45&&ballon.porteur){
    lacher();ballon.sol=true;ballon.x=G.x;ballon.y=G.y;ballon.h=0.12;
    S.releve=d.aplati+1.3;
   }
   if(t-d.aplati>=0.6&&S.etat==='aplati'){etat(S,'au_sol');S.plonge=null}
   if(t-d.aplati>=1.0&&!d.joie){
    d.joie=true;
    for(const j of J)if(debout(j)&&dist(j,G)<25)etat(j,j.side===T?'joie':'deception');
   }
   // Fin : 2,6 s après l'aplati, prolongée (célébration) pour durer au moins DUREE_MIN.
   if(t-d.aplati>=Math.min(4.5,Math.max(2.6,DUREE_MIN-d.aplati))){d.phase='fin';d.fin=t}
  }else if(d.phase==='fin'){
  }
  // Fin sur un pas de sortie : la dernière image des pistes tombe sur la durée annoncée.
  if(d.phase==='fin'&&n%Math.round(PAS_SORTIE/PAS)===0)break;
  for(const j of J){if(j.etat==='ruck'||debout(j))comportement(j)}
  for(const j of J)integrer(j);
  separer();
  for(const j of J){j.x+=j.vx*PAS;j.y+=j.vy*PAS;j.x=borne(j.x,-5,105);j.y=borne(j.y,0.3,69.7);capDe(j)}
  t=r2(t+PAS);n++;
  ballonSuit();
  if(n%Math.round(PAS_SORTIE/PAS)===0)garder();
 }
 if(d.phase!=='fin')return null;
 return {J,echantillons,ballonPiste,porteurs,etatsJ,evenements,contacts,duree:r1(t),G,sens,S};
}

// Pistes envoyées à la vue : positions, cap, vitesse par joueur ; ballon ; états.
function sortie(r,e,graine,phases){
 const joueurs=r.J.map((j,i)=>({id:j.id,side:j.side,slot:j.slot,vmax:j.vmax,amax:j.amax,
  x:r.echantillons.map(s=>r2(s[i][0])),y:r.echantillons.map(s=>r2(s[i][1])),
  v:r.echantillons.map(s=>r2(s[i][2])),cap:r.echantillons.map(s=>r2(s[i][3])),
  etats:r.etatsJ.get(j.id)}));
 return {version:VERSION,type:e.type,graine,phases,pas:PAS_SORTIE,duree:r.duree,equipe:e.equipe,sens:r.sens,marqueur:r.S.id,
  essai:{x:r2(r.G.x),y:r2(r.G.y)},joueurs,
  ballon:{x:r.ballonPiste.map(b=>r2(b[0])),y:r.ballonPiste.map(b=>r2(b[1])),h:r.ballonPiste.map(b=>r2(b[2])),porteurs:r.porteurs},
  evenements:r.evenements,contacts:r.contacts.map(c=>[r1(c.t0),r1(c.t1),c.a,c.b])};
}

// Point d'entrée : une mise en scène de DUREE_MIN à DUREE_MAX secondes, déterministe par graine.
function composer(entree){
 const e=valider(entree);
 const graine=(Number.isInteger(e.graine)?e.graine:hacher(JSON.stringify([e.marqueur,e.essai,e.ballon])))>>>0;
 const alea=tirage(graine);
 const cible=Number.isFinite(e.duree_cible)?borne(e.duree_cible,DUREE_MIN,DUREE_MAX):14+alea()*8;
 const essais=[];
 for(let phases=0;phases<=4;phases++){
  const r=simuler(e,phases,(graine^Math.imul(phases+1,0x9E3779B1))>>>0);
  if(r)essais.push({r,phases,ecart:Math.abs(r.duree-cible)+(r.duree<DUREE_MIN||r.duree>DUREE_MAX?1000:0)});
  // Chaque ruck ajoute plusieurs secondes : inutile d'aller au-delà d'une mise en scène trop longue.
  if(r&&r.duree>Math.max(cible,DUREE_MAX))break;
 }
 essais.sort((a,b)=>a.ecart-b.ecart||a.phases-b.phases);
 const meilleur=essais[0];
 if(!meilleur||meilleur.ecart>=1000)throw new RangeError('Chorégraphe : aucune mise en scène dans la durée voulue');
 return sortie(meilleur.r,e,graine,meilleur.phases);
}

// Entrée du chorégraphe à partir d'un temps fort projeté (match-direct.cjs) et du journal.
// Rend null si le temps fort ne contient pas d'essai en jeu courant mis en scène ici.
// `profils` : {id: {vmax, amax}} ; `avant` : scène affichée juste avant le plan d'essai.
function entreeDepuisTempsFort(tf,events,{profils={},avant=null,cle=''}={}){
 const n=tf?.plans?.findIndex(p=>p.kind==='try');
 if(!(n>=0))return null;
 const plan=tf.plans[n],record=events?.[plan.index]?.scene;
 if(!record||record.kind!=='try'||record.origin!=='open'||![0,1].includes(record.team)||record.actor==null)return null;
 const depart=n>0?tf.plans[n-1].scene:(avant||tf.depart);
 if(!depart||!Array.isArray(depart.players))return null;
 const mis=depart.players.find(p=>p.featured&&p.side===depart.possession);
 return {type:'essai_jeu_courant',equipe:record.team,marqueur:String(record.actor),porteur:mis?mis.id:null,
  possession:depart.possession,ballon:{x:depart.ball.x,y:depart.ball.y},essai:{x:plan.scene.ball.x,y:plan.scene.ball.y},
  joueurs:depart.players.map(p=>({id:p.id,side:p.side,slot:p.slot,x:p.x,y:p.y})),profils,
  graine:hacher(cle+'|'+plan.index),plan:n};
}

module.exports=Object.freeze({VERSION,PAS,PAS_SORTIE,DUREE_MIN,DUREE_MAX,ECART,EN_BUT,ETATS,profil,composer,entreeDepuisTempsFort,hacher});
