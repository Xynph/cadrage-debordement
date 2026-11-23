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
// Fonctions de la VM : CDReleveQualites.{lire, CLES}.
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
 // Relevé lu : {mois: [AAAA-MM…], niveau: [n|null…], qualites: {clé: [v|null…]}} du plus ancien au plus récent, et
 // dernières valeurs connues (dix, note) pour l'écart suivant. null si absent ou illisible.
 function decoder(rq){
  if(typeof rq!=='string'||!FORME.test(rq))return null;
  const sans=rq[0]==='~',[tete,...entrees]=rq.slice(sans?1:0).split(','),debut=tete.slice(0,7),base=tete.slice(8);
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
 function relever(p,mois){
  const v=valeurs(p);if(!v||!Number.isFinite(p.rating))return false;
  const dix=CLES.map(k=>Math.round(v[k]*10)),note=Math.round(p.rating);
  const nouveau=()=>{p.rq=mois+':'+b2(note)+dix.map(b2).join('');return true;};
  const r=decoder(p.rq);if(!r)return nouveau();
  const entrees=p.rq.split(',').slice(1),dernier=moisSuivant(r.debut,entrees.length),ecart=ecartMois(dernier,mois);
  if(ecart<=0)return false;
  if(ecart>=MOIS_MAX)return nouveau();
  for(let k=1;k<ecart;k++)entrees.push('~');
  entrees.push(entree(note-r.note,dix.map((v,i)=>v-r.dix[i])));
  // Fenêtre glissante : le plus ancien mois est replié dans la base.
  let debut=r.debut,sans=p.rq[0]==='~',bn=u2(p.rq.slice(sans?9:8,sans?11:10));const bd=CLES.map((_,i)=>{const o=(sans?11:10)+2*i;return u2(p.rq.slice(o,o+2));});
  while(entrees.length>MOIS_MAX-1){
   const e=entrees.shift();debut=moisSuivant(debut);
   if(e==='~'){sans=true;continue;}
   sans=false;bn+=d1(e[0]);appliquerEntree(bd,e);
  }
  p.rq=(sans?'~':'')+debut+':'+b2(bn)+bd.map(b2).join('')+entrees.map(e=>','+e).join('');
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
 // Relevé du mois pour tout le monde, une fois par mois.
 function releverTous(force){
  if(typeof S==='undefined'||!S)return 0;
  const mois=moisCourant(S);if(!mois)return 0;
  if(!force&&S.releveQualites?.m===mois)return 0;
  let n=0;for(const p of joueurs(S))if(relever(p,mois))n++;
  S.releveQualites={m:mois};
  return n;
 }
 // Après chaque commande (worker) : carrière neuve ou ancienne sauvegarde sans relevé, premier relevé tout de suite.
 function observe(){if(typeof S==='undefined'||!S||S.releveQualites)return 0;return releverTous(true);}
 function validate(s){
  const m=s?.releveQualites;
  if(m!==undefined&&!(m&&typeof m==='object'&&Object.keys(m).length===1&&typeof m.m==='string'&&/^\d{4}-\d{2}$/.test(m.m)))throw Error('Relevé des qualités invalide.');
  for(const p of joueurs(s)){
   const rq=p.rq;if(rq===undefined)continue;
   if(typeof rq!=='string'||!FORME.test(rq)||rq.split(',').length>MOIS_MAX)throw Error('Relevé des qualités du joueur invalide.');
  }
  if(typeof nativeInSeasonDevelopment!=='undefined'&&typeof nativeInSeasonDevelopment.validate==='function')nativeInSeasonDevelopment.validate(s);
  return true;
 }
 const api=Object.freeze({CLES,lire});
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
  _tests:{relever,releverTous,decoder,moisSuivant},...api};
}
module.exports={files,commands,factory};
