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
// Flèches de progression (CDReleveQualites.fleches) : écart sur 4 semaines, seulement les qualités qui sortent du lot,
// niveau = moyenne des 36.
// Fonctions de la VM : CDReleveQualites.{lire, fleches, CLES}.
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
 // 36 qualités du joueur : profil détaillé, sinon profil compact (nativeAttributesV1).
 function valeurs(p){
  const a=p?.attributesV2;
  if(a&&typeof a==='object'&&CLES.every(k=>Number.isFinite(a[k])))return a;
  if(typeof p?.nativeAttributesV1==='string'&&typeof nativeAttributeStore!=='undefined'){try{return nativeAttributeStore.project(p).attributesV2;}catch(e){return null;}}
  return null;
 }
 function relever(p,mois,P=MOIS){
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
  let n=0;for(const p of joueurs(S)){if(m&&relever(p,mois))n++;if(h)relever(p,lundi,SEMAINE);}
  S.releveQualites={m:mois,...(lundi?{s:lundi}:{})};
  return n;
 }
 // Après chaque commande (worker) : carrière neuve ou ancienne sauvegarde sans relevé, premier relevé tout de suite.
 function observe(){if(typeof S==='undefined'||!S||S.releveQualites)return 0;return releverTous(true);}
 // Flèches de progression du joueur (choix de Léo du 24/11/2026) : écart entre ses qualités du jour et celles d'il y a
 // 4 semaines (relevé hebdomadaire), en crans −3..3 (dixièmes : ±1-3 léger, ±4-9 net, ±10 point gagné / perdu).
 //  - q : seulement les qualités qui sortent du lot (écart à la médiane des 36 d'au moins 2 dixièmes), 6 au plus ;
 //  - n : niveau = moyenne des 36 qualités.
 // null sans relevé d'au moins une semaine.
 const QUALITES_MAX=6,SEUIL_LOT=2;
 const cran=d=>{const a=Math.abs(d);return a>=10?3*Math.sign(d):a>=4?2*Math.sign(d):a>=1?Math.sign(d):0;};
 function fleches(p){
  const r=decoder(p?.rh,SEMAINE);if(!r)return null;
  const v=valeurs(p);if(!v)return null;
  const dernier=r.points.length-1;let k=Math.max(0,dernier-(SEMAINES-1));
  // Référence : la semaine d'il y a 4 semaines, sinon la plus ancienne relevée.
  while(k<dernier&&!r.points[k])k++;
  const ref=r.points[k];if(!ref)return null;
  const maintenant=CLES.map(c=>Math.round(v[c]*10));
  if(k===dernier&&maintenant.every((x,i)=>x===ref.dix[i]))return {n:0,q:{}};
  const ecarts=maintenant.map((x,i)=>x-ref.dix[i]);
  const tri=ecarts.slice().sort((a,b)=>a-b),mediane=(tri[17]+tri[18])/2;
  const moyenne=ecarts.reduce((a,b)=>a+b,0)/36;
  const lot=ecarts.map((d,i)=>[i,d,d-mediane]).filter(([,d,e])=>cran(d)!==0&&Math.abs(e)>=SEUIL_LOT)
   .sort((a,b)=>Math.abs(b[2])-Math.abs(a[2])||a[0]-b[0]).slice(0,QUALITES_MAX);
  return {n:cran(Math.round(moyenne)),q:Object.fromEntries(lot.map(([i,d])=>[CLES[i],cran(d)]))};
 }
 function validate(s){
  const m=s?.releveQualites;
  if(m!==undefined&&!(m&&typeof m==='object'&&Object.keys(m).every(k=>k==='m'||k==='s')&&typeof m.m==='string'&&/^\d{4}-\d{2}$/.test(m.m)&&(m.s===undefined||typeof m.s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(m.s))))throw Error('Relevé des qualités invalide.');
  for(const p of joueurs(s)){
   const rq=p.rq,rh=p.rh;
   if(rq!==undefined&&(typeof rq!=='string'||!FORME.test(rq)||rq.split(',').length>MOIS_MAX))throw Error('Relevé des qualités du joueur invalide.');
   if(rh!==undefined&&(typeof rh!=='string'||!FORME_S.test(rh)||rh.split(',').length>SEMAINES))throw Error('Relevé hebdomadaire des qualités du joueur invalide.');
  }
  if(typeof nativeInSeasonDevelopment!=='undefined'&&typeof nativeInSeasonDevelopment.validate==='function')nativeInSeasonDevelopment.validate(s);
  return true;
 }
 const api=Object.freeze({CLES,lire,fleches});
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
  _tests:{relever,releverTous,decoder,moisSuivant,lundiSuivant,SEMAINE},...api};
}
module.exports={files,commands,factory};
