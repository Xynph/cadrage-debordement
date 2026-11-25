'use strict';
// Relevé mensuel des qualités (idée FM27 n° 14 « Progression par qualité », choix de Léo du 23/11/2026) : la courbe
// sur 12 mois de l'onglet Développement de la fiche joueur vient de ce relevé, jamais d'une série reconstituée.
//
// Chaque mois (première semaine d'entraînement du mois), les 36 qualités (au dixième) et la note de niveau de chaque
// joueur des clubs, des agents libres et du centre du club sont relevées sur le joueur (p.rq), 12 mois glissants.
// Ancienne sauvegarde ou carrière neuve : premier relevé au chargement (la courbe commence là) ; joueur arrivé dans le
// monde en cours de mois : premier relevé au mois suivant.
//
// Format compact (chaîne, sans guillemet ni barre oblique inverse) :
//   "AAAA-MM:" + base + ("," + entrée)*   (au plus 11 entrées : 12 mois en tout)
//   base   = niveau (2 car.) + 36 qualités en dixièmes (2 car. chacune), mois AAAA-MM ; "~" devant le mois : base non
//            relevée (mois manqué replié), valeurs gardées pour les écarts suivants ;
//   entrée = mois suivant : écart de niveau (1 car.) + écart commun des 36 qualités en dixièmes (1 car.) + exceptions
//            (index de la qualité 1 car. + écart en dixièmes 1 car. ; plusieurs paires s'additionnent au-delà de ±3,1) ;
//            "~" : mois sans relevé.
// Alphabet base 64 « 0-9 A-Z a-z - _ » ; écart sur 1 car. : -32..31.
// S.releveQualites = {m: 'AAAA-MM'} : mois du dernier relevé (une fois par mois pour tout le monde).
// Relevé hebdomadaire (choix de Léo du 24/11/2026) : chaque semaine d'entraînement, même format avec le lundi
// (AAAA-MM-DD) à la place du mois, 5 semaines glissantes (p.rh) ; S.releveQualites.s = lundi du dernier relevé.
// Relevé hebdomadaire ancré (25/11/2026, sauvegardes allégées sans perte) : la base absolue du relevé hebdomadaire
// (74 car. par joueur) répétait des valeurs déjà écrites dans le relevé mensuel. Quand un point de la chaîne
// hebdomadaire vaut exactement les dernières valeurs connues du relevé mensuel (p.rq), la base est remplacée par
// l'index de ce point : "~?AAAA-MM-DD@j" + ("," + entrée)* (j = 0 pour la base, k après la k-ième entrée). La lecture
// rend le texte d'origine au caractère près (texteHebdo) ; sinon la base absolue reste écrite. Le relevé hebdomadaire
// est redéplié avant toute écriture de p.rq puis réancré : les deux champs restent cohérents. Anciennes sauvegardes
// (base absolue partout) : ancrées au chargement (convertir) ; S.releveQualites.f = 2 marque une carrière convertie.
// Flèches de progression (CDReleveQualites.fleches) : écart sur 4 semaines, toute qualité qui a vraiment bougé (hausse
// ou baisse), niveau = moyenne des 36.
// Fonctions de la VM : CDReleveQualites.{lire, fleches, texteHebdo, CLES}.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 // Ordre des 36 qualités (identique à nativeAttributesV1, player-attributes.cjs, et à l'écran progression_fiche.gd).
 const CLES=Object.freeze(['passing','receiving','offload','tackling','jackal','ruckClearout','ballCarry','evasion',
  'kickDistance','kickAccuracy','goalAccuracy','ballHandling','decisions','anticipation','vision','positioning','composure',
  'discipline','teamwork','leadership','workRate','acceleration','topSpeed','agility','explosiveness','strength','endurance',
  'jumping','scrumTechnique','hooking','lineoutThrow','lineoutJump','lineoutLift','maul','kickChase','aerialAbility']);
 const MOIS_MAX=12,ALPHA='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_';
 const VAL=Object.fromEntries([...ALPHA].map((c,i)=>[c,i]));
 const e1=n=>ALPHA[Math.max(0,Math.min(63,n+32))];
 const b2=n=>{const v=Math.max(0,Math.min(4095,n));return ALPHA[v>>6]+ALPHA[v&63];};
 const d1=c=>VAL[c]-32,u2=s=>VAL[s[0]]*64+VAL[s[1]];
 // Écarts d'une entrée appliqués aux 36 valeurs (exceptions : la première paire d'une qualité remplace l'écart commun).
 function appliquerEntree(dix,e){
  const commun=d1(e[1]),vues=new Set();for(let i=0;i<36;i++)dix[i]+=commun;
  for(let k=2;k+2<=e.length;k+=2){const i=VAL[e[k]];if(i>=36)continue;if(!vues.has(i)){vues.add(i);dix[i]-=commun;}dix[i]+=d1(e[k+1]);}
 }
 const FORME=/^~?\d{4}-(0[1-9]|1[0-2]):[0-9A-Za-z_-]{74}(,(~|[0-9A-Za-z_-]{2}([0-9A-Za-z_-]{2})*))*$/;
 const moisSuivant=(m,k=1)=>{const a=+m.slice(0,4),b=+m.slice(5,7)-1+k;return String(a+Math.floor(b/12))+'-'+String(((b%12)+12)%12+1).padStart(2,'0');};
 const ecartMois=(a,b)=>(+b.slice(0,4)-+a.slice(0,4))*12+(+b.slice(5,7)-+a.slice(5,7));
 // Relevé hebdomadaire (choix de Léo du 24/11/2026) : chaque semaine (lundi AAAA-MM-DD), mêmes valeurs, 5 semaines
 // glissantes (p.rh) : référence exacte « il y a 4 semaines » des flèches de progression. Même format que le relevé
 // mensuel, clé du lundi à la place du mois.
 const SEMAINES=5,JOUR=86400000;
 const FORME_S=/^~?\d{4}-\d{2}-\d{2}:[0-9A-Za-z_-]{74}(,(~|[0-9A-Za-z_-]{2}([0-9A-Za-z_-]{2})*))*$/;
 const lundiSuivant=(d,k=1)=>new Date(Date.parse(d+'T00:00:00Z')+7*k*JOUR).toISOString().slice(0,10);
 const ecartSemaines=(a,b)=>Math.round((Date.parse(b+'T00:00:00Z')-Date.parse(a+'T00:00:00Z'))/(7*JOUR));
 const MOIS={champ:'rq',long:7,max:MOIS_MAX,forme:FORME,suivant:moisSuivant,ecart:ecartMois};
 const SEMAINE={champ:'rh',long:10,max:SEMAINES,forme:FORME_S,suivant:lundiSuivant,ecart:ecartSemaines};
 // Relevé hebdomadaire ancré sur le relevé mensuel (voir l'en-tête).
 const FORME_A=/^~?\d{4}-\d{2}-\d{2}@[0-9](,(~|[0-9A-Za-z_-]{2}([0-9A-Za-z_-]{2})*))*$/;
 // Relevé lu : {mois: [AAAA-MM…], niveau: [n|null…], qualites: {clé: [v|null…]}} du plus ancien au plus récent, et
 // dernières valeurs connues (dix, note) pour l'écart suivant. null si absent ou illisible.
 function decoder(rq,P=MOIS){
  if(typeof rq!=='string'||!P.forme.test(rq))return null;
  const L=P.long,sans=rq[0]==='~',[tete,...entrees]=rq.slice(sans?1:0).split(','),debut=tete.slice(0,L),base=tete.slice(L+1);
  let note=u2(base.slice(0,2));const dix=CLES.map((_,i)=>u2(base.slice(2+2*i,4+2*i)));
  const points=[sans?null:{note,dix:dix.slice()}];
  for(const e of entrees){
   if(e==='~'){points.push(null);continue;}
   note+=d1(e[0]);appliquerEntree(dix,e);
   points.push({note,dix:dix.slice()});
  }
  return {debut,points,note,dix};
 }
 function lire(rq){
  const r=decoder(rq);if(!r)return null;
  return {mois:r.points.map((_,k)=>moisSuivant(r.debut,k)),niveau:r.points.map(p=>p?p.note:null),
   qualites:Object.fromEntries(CLES.map((c,i)=>[c,r.points.map(p=>p?p.dix[i]/10:null)]))};
 }
 function entree(dn,ecarts){
  const compte=new Map();for(const v of ecarts)compte.set(v,(compte.get(v)||0)+1);
  let commun=0,mieux=-1;for(const [v,n] of compte)if(Math.abs(v)<=31&&(n>mieux||n===mieux&&Math.abs(v)<Math.abs(commun))){commun=v;mieux=n;}
  let s=e1(Math.max(-32,Math.min(31,dn)))+e1(commun);
  ecarts.forEach((v,i)=>{if(v===commun)return;let reste=v;do{const pas=Math.max(-32,Math.min(31,reste));s+=ALPHA[i]+e1(pas);reste-=pas;}while(reste!==0);});
  return s;
 }
 // Écarts cumulés depuis la base (niveau, 36 dixièmes) à chaque position de la chaîne : 0 = base, k = après la
 // k-ième entrée ("~" n'ajoute rien). Les écarts s'additionnent : la base se retrouve à partir de n'importe quel point.
 function cumuls(entrees){
  let note=0;const dix=new Array(36).fill(0),out=[{note:0,dix:dix.slice()}];
  for(const e of entrees){if(e!=='~'){note+=d1(e[0]);appliquerEntree(dix,e);}out.push({note,dix:dix.slice()});}
  return out;
 }
 // Texte d'origine du relevé hebdomadaire (base absolue) : tel quel s'il n'est pas ancré, reconstruit depuis les
 // dernières valeurs connues du relevé mensuel s'il l'est ; null si l'ancre est illisible.
 function texteHebdo(p){
  const t=p?.rh;if(typeof t!=='string'||!FORME_A.test(t))return t;
  const a=decoder(p.rq);if(!a)return null;
  const sans=t[0]==='~',[tete,...entrees]=t.slice(sans?1:0).split(','),j=+tete[11];
  if(j>entrees.length)return null;
  const c=cumuls(entrees)[j],note=a.note-c.note,dix=a.dix.map((v,i)=>v-c.dix[i]);
  if(note<0||note>4095||dix.some(v=>v<0||v>4095))return null;
  return (sans?'~':'')+tete.slice(0,10)+':'+b2(note)+dix.map(b2).join('')+entrees.map(e=>','+e).join('');
 }
 // Ancre le relevé hebdomadaire (base absolue) sur le relevé mensuel quand un point de sa chaîne vaut exactement les
 // dernières valeurs connues de p.rq ; le texte ancré doit redonner l'original au caractère près, sinon rien ne change.
 function ancrer(p){
  const t=p.rh;if(typeof t!=='string'||!FORME_S.test(t))return false;
  const a=decoder(p.rq);if(!a)return false;
  const sans=t[0]==='~',[tete,...entrees]=t.slice(sans?1:0).split(','),bn=u2(tete.slice(11,13)),bd=CLES.map((_,i)=>u2(tete.slice(13+2*i,15+2*i)));
  const cs=cumuls(entrees);
  for(let j=Math.min(9,cs.length-1);j>=0;j--){
   const c=cs[j];if(bn+c.note!==a.note||!c.dix.every((v,i)=>bd[i]+v===a.dix[i]))continue;
   const ancre=(sans?'~':'')+tete.slice(0,10)+'@'+j+entrees.map(e=>','+e).join('');
   if(texteHebdo({rh:ancre,rq:p.rq})!==t)return false;
   p.rh=ancre;return true;
  }
  return false;
 }
 // Avant toute écriture de p.rq ou p.rh : relevé hebdomadaire remis au format d'origine (illisible : retiré, comme un
 // relevé absent) ; après : ancré sur le nouveau relevé mensuel.
 function deplier(p){if(typeof p.rh!=='string'||!FORME_A.test(p.rh))return;const t=texteHebdo(p);if(t===null)delete p.rh;else p.rh=t;}
 // 36 qualités du joueur : profil détaillé, sinon profil compact (nativeAttributesV1).
 function valeurs(p){
  const a=p?.attributesV2;
  if(a&&typeof a==='object'&&CLES.every(k=>Number.isFinite(a[k])))return a;
  if(typeof p?.nativeAttributesV1==='string'&&typeof nativeAttributeStore!=='undefined'){try{return nativeAttributeStore.project(p).attributesV2;}catch(e){return null;}}
  return null;
 }
 // Relevé d'une période pour un joueur (relevé hebdomadaire déplié puis réancré autour de l'écriture).
 function relever(p,mois,P=MOIS){deplier(p);try{return releverBrut(p,mois,P);}finally{ancrer(p);}}
 function releverBrut(p,mois,P=MOIS){
  const v=valeurs(p);if(!v||!Number.isFinite(p.rating))return false;
  const dix=CLES.map(k=>Math.round(v[k]*10)),note=Math.round(p.rating),c=P.champ,L=P.long,txt=p[c];
  const nouveau=()=>{p[c]=mois+':'+b2(note)+dix.map(b2).join('');return true;};
  const r=decoder(txt,P);if(!r)return nouveau();
  const entrees=txt.split(',').slice(1),dernier=P.suivant(r.debut,entrees.length),ecart=P.ecart(dernier,mois);
  if(ecart<=0)return false;
  if(ecart>=P.max)return nouveau();
  for(let k=1;k<ecart;k++)entrees.push('~');
  entrees.push(entree(note-r.note,dix.map((v,i)=>v-r.dix[i])));
  // Fenêtre glissante : la plus ancienne période est repliée dans la base.
  let debut=r.debut,sans=txt[0]==='~',bn=u2(txt.slice(sans?L+2:L+1,sans?L+4:L+3));const bd=CLES.map((_,i)=>{const o=(sans?L+4:L+3)+2*i;return u2(txt.slice(o,o+2));});
  while(entrees.length>P.max-1){
   const e=entrees.shift();debut=P.suivant(debut);
   if(e==='~'){sans=true;continue;}
   sans=false;bn+=d1(e[0]);appliquerEntree(bd,e);
  }
  p[c]=(sans?'~':'')+debut+':'+b2(bn)+bd.map(b2).join('')+entrees.map(e=>','+e).join('');
  return true;
 }
 function moisCourant(s){
  try{if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)){const d=CDWorldCareer.calendarToday(s);if(/^\d{4}-\d{2}/.test(d))return d.slice(0,7);}}catch(e){}
  return null;
 }
 function* joueurs(s){
  const vus=new Set();
  for(const c of s?.clubs||[])for(const p of c?.players||[])if(p&&!vus.has(p)){vus.add(p);yield p;}
  for(const p of s?.economy?.freeAgents||[])if(p&&!vus.has(p)){vus.add(p);yield p;}
  for(const p of s?.development?.academy||[])if(p&&!vus.has(p)){vus.add(p);yield p;}
  // Marché : copies des agents libres après un rechargement ; elles doivent rester identiques au vivier.
  for(const p of Array.isArray(s?.market)?s.market:[])if(p&&!vus.has(p)){vus.add(p);yield p;}
 }
 // Lundi de la semaine du calendrier (AAAA-MM-DD) ; null hors carrière Monde.
 function lundiCourant(s){
  try{if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)){const d=CDWorldCareer.calendarToday(s);if(/^\d{4}-\d{2}-\d{2}$/.test(d)){const t=Date.parse(d+'T00:00:00Z'),dow=(new Date(t).getUTCDay()+6)%7;return new Date(t-dow*JOUR).toISOString().slice(0,10);}}}catch(e){}
  return null;
 }
 // Relevé du mois (courbe 12 mois) et de la semaine (flèches) pour tout le monde, une fois par mois / par semaine.
 function releverTous(force){
  if(typeof S==='undefined'||!S)return 0;
  const mois=moisCourant(S);if(!mois)return 0;
  const lundi=lundiCourant(S),etat=S.releveQualites||{};
  const m=force||etat.m!==mois,h=!!lundi&&(force||etat.s!==lundi);
  if(!m&&!h)return 0;
  let n=0;for(const p of joueurs(S)){deplier(p);if(m&&releverBrut(p,mois))n++;if(h)releverBrut(p,lundi,SEMAINE);ancrer(p);}
  S.releveQualites={m:mois,...(lundi?{s:lundi}:{}),f:2};
  return n;
 }
 // Ancienne sauvegarde (relevés hebdomadaires à base absolue, sans marque f) : relevés ancrés une fois, sans rien changer
 // à ce qu'ils redonnent. Appelé au chargement d'un profil (worker.cjs) et après chaque commande (import).
 function convertir(s=typeof S==='undefined'?null:S){
  const m=s?.releveQualites;if(!m||typeof m!=='object'||m.f===2)return 0;
  let n=0;for(const p of joueurs(s))if(ancrer(p))n++;
  m.f=2;return n;
 }
 // Après chaque commande (worker) : carrière neuve ou ancienne sauvegarde sans relevé, premier relevé tout de suite ;
 // ancienne sauvegarde à base absolue : convertie.
 function observe(){if(typeof S==='undefined'||!S)return 0;if(S.releveQualites)return convertir(S);return releverTous(true);}
 // Flèches de progression du joueur (choix de Léo du 24/11/2026, retouche : « dans FM ça peut être plus, en positif
 // ou négatif ») : écart entre ses qualités du jour et celles d'il y a 4 semaines (relevé hebdomadaire), en crans
 // −3..3 : léger (+0,3 / −0,2 à −0,3), net (±0,4 à 0,9), point gagné / perdu (±1 ou plus).
 //  - q : toute qualité qui a vraiment bougé, en hausse comme en baisse, sans limite de nombre. Seuils de bruit sur 4
 //    semaines (mesurés en milieu de saison Monde) : hausse 0,3 point (un jeune ≤ 22 ans a 1,3 flèche en moyenne, 20 au
 //    plus ; à 0,2 il en avait 3,2 et jusqu'à 25, des mouvements de fond sans signification) ; baisse 0,2 point (le déclin
 //    de l'âge est lent et étalé : à 0,3, deux joueurs au plus par club en montraient une ; à 0,2, un joueur de 31 ans et
 //    plus en a 5 en moyenne). Baisses du moteur : déclin de l'âge, appliqué chaque semaine (in-season-development.cjs) ;
 //    ni blessure ni manque de jeu ne font baisser une qualité ;
 //  - n : niveau = moyenne des 36 qualités (hausse ou baisse, mêmes crans sur la moyenne).
 // null sans relevé d'au moins une semaine.
 const SEUIL_HAUSSE=3,SEUIL_BAISSE=2;
 const cran=d=>{const a=Math.abs(d);return a>=10?3*Math.sign(d):a>=4?2*Math.sign(d):a>=1?Math.sign(d):0;};
 function fleches(p){
  const r=decoder(texteHebdo(p),SEMAINE);if(!r)return null;
  const v=valeurs(p);if(!v)return null;
  const dernier=r.points.length-1;let k=Math.max(0,dernier-(SEMAINES-1));
  // Référence : la semaine d'il y a 4 semaines, sinon la plus ancienne relevée.
  while(k<dernier&&!r.points[k])k++;
  const ref=r.points[k];if(!ref)return null;
  const ecarts=CLES.map((c,i)=>Math.round(v[c]*10)-ref.dix[i]);
  const moyenne=ecarts.reduce((a,b)=>a+b,0)/36;
  return {n:cran(Math.round(moyenne)),q:Object.fromEntries(ecarts.flatMap((d,i)=>d>=SEUIL_HAUSSE||d<=-SEUIL_BAISSE?[[CLES[i],cran(d)]]:[]))};
 }
 function validate(s){
  const m=s?.releveQualites;
  if(m!==undefined&&!(m&&typeof m==='object'&&Object.keys(m).every(k=>k==='m'||k==='s'||k==='f')&&typeof m.m==='string'&&/^\d{4}-\d{2}$/.test(m.m)&&(m.s===undefined||typeof m.s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(m.s))&&(m.f===undefined||m.f===2)))throw Error('Relevé des qualités invalide.');
  for(const p of joueurs(s)){
   // Relevé hebdomadaire ancré : contrôlé sur son texte d'origine (ancre lisible comprise).
   const rq=p.rq,rh=typeof p.rh==='string'&&FORME_A.test(p.rh)?texteHebdo(p):p.rh;
   if(rq!==undefined&&(typeof rq!=='string'||!FORME.test(rq)||rq.split(',').length>MOIS_MAX))throw Error('Relevé des qualités du joueur invalide.');
   if(rh!==undefined&&(typeof rh!=='string'||!FORME_S.test(rh)||rh.split(',').length>SEMAINES))throw Error('Relevé hebdomadaire des qualités du joueur invalide.');
  }
  if(typeof nativeInSeasonDevelopment!=='undefined'&&typeof nativeInSeasonDevelopment.validate==='function')nativeInSeasonDevelopment.validate(s);
  return true;
 }
 const api=Object.freeze({CLES,lire,fleches,texteHebdo});
 let installe=false;
 function installHooks(){
  globalThis.CDReleveQualites=api;
  if(installe)return true;installe=true;
  if(typeof trainWeek==='function'){
   const avant=trainWeek;
   trainWeek=function(){if(typeof S!=='undefined'&&S&&!S.trained)releverTous(false);return avant.apply(this,arguments);};
   Object.assign(trainWeek,avant);
  }
  return true;
 }
 return {project(){return null;},validate,execute(){throw Error('Relevé des qualités : aucune commande.');},installHooks,observe,
  convertir,_tests:{relever,releverTous,decoder,moisSuivant,lundiSuivant,SEMAINE,ancrer,deplier,FORME_A},...api};
}
module.exports={files,commands,factory};
