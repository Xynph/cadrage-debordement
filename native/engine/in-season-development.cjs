'use strict';
// Detailed source profiles use the existing XP/focus budget during the season.
// Their annual transition then applies age effects only, not a second learning grant.
//
// Progression étalée sur la saison (idée FM27 n° 14, choix de Léo du 23/11/2026) : la même progression qu'avant, mais
// sans à-coups. Avant, un point de niveau gagné (expérience ≥ 1) montait d'un coup les 36 qualités de +1, et le déclin
// de l'âge tombait en une fois à l'intersaison.
//  - Gain de niveau ou point ciblé (axe de progression) : la note de niveau monte tout de suite (comme avant), mais les
//    36 qualités et les compétences de match le reçoivent semaine après semaine (0,1 point par semaine au moins, soit
//    10 semaines au plus pour un point ; plus vite en fin de saison pour tout libérer avant l'intersaison ; en attente :
//    p.dev.etale.n niveau, .c points ciblés). Ce qui reste à la transition est appliqué à ce moment-là.
//  - Déclin de l'âge (LNR_V11_AGE, calculé comme à la transition) : appliqué chaque semaine d'entraînement au prorata
//    (SAISON semaines), le reste à la transition ; la note de niveau suit à la transition (somme des écarts, .r).
// Même total par saison qu'avant (scripts/mesure-progression-saison.cjs).
// p.dev.etale = {s: saison, t: semaines d'entraînement vues, a: semaine de départ si créé en cours de saison,
//   n: niveau en attente, c: {compétence: points ciblés en attente}, r: écart de niveau cumulé du déclin}.
//
// Jeunes du centre (choix de Léo du 23/11/2026, même mécanisme) : profils générés, sans attributesV2 ; leurs 36 qualités
// sont entières (nativeAttributesV1, suivies par player-attributes.cjs d'après les compétences de match). Avant, un point
// de niveau (séance, match, investissement du centre, accueil des centres gérés à l'intersaison) montait d'un coup les
// 11 compétences et les 36 qualités de +1. Désormais, même réservoir (p.dev.etale.n) et même rythme : la note de niveau
// monte tout de suite, les compétences reçoivent la part de la semaine (au centième) et les qualités montent une à une
// (36 hausses d'un point par point de niveau, dans un ordre propre au joueur) : leur moyenne suit la part de la semaine.
// Le suivi des qualités retranche la part versée ici (verse) pour ne pas la compter deux fois. Jeune promu en cours de
// réservoir : le reste lui est versé de la même façon. Pas de déclin de l'âge (aucun jeune concerné), pas de .c/.r/.a
// utiles ; l'état est effacé dès que rien n'est plus en attente.
module.exports=function inSeasonDevelopment(){
 // Semaines d'entraînement d'une saison Monde (17 août → 5 juillet ; mesuré le 23/11/2026, 46 semaines).
 const SAISON=46;
 // Rythme de libération : au moins un dixième de point par semaine (un point de niveau arrive en 10 semaines au plus),
 // plus vite si la fin de saison approche.
 const PAS=.1;
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n)),round=n=>Math.round(n*100)/100,cents=round,dixmill=n=>Math.round(n*1e4)/1e4;
 function detailed(p){return !!p?.attributesV2&&(p.lnrRatingsVersion===1||p.worldRatingsVersion===1&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)&&CDWorldCareer.sourcePlayerKnown(p.id));}
 // Jeune du centre au profil généré (36 qualités entières) : son gain de niveau est étalé.
 function jeune(p){return p?.academy===true&&!p.attributesV2;}
 // Qualités des jeunes : 7 et 36 étant premiers entre eux, chaque qualité monte une fois par point de niveau, en
 // alternant les familles (passe, plaquage, coup de pied, vitesse…) ; départ propre au joueur.
 const ORDRE=7;
 // Part versée aux compétences des jeunes depuis le dernier relevé d'avant commande (player-attributes.cjs).
 let verses=new WeakMap();
 // Hausses des qualités pour un réservoir qui passe de `avant` à `apres` points : 36 par point, une à une. Qualités pas
 // encore créées (jeune arrivé dans la commande) : rien, elles partiront des compétences déjà versées.
 function hausses(p,avant,apres){
  const q=p.nativeAttributesV1;let r=Math.round(avant*36);const fin=Math.max(0,Math.round(apres*36));
  if(r<=fin||typeof q!=='string'||!/^\d{72}$/.test(q))return;
  const v=[];for(let i=0;i<36;i++)v.push(Number(q.slice(2*i,2*i+2)));
  // Entraînement ciblé (24/11/2026) : hausses tirées selon les qualités travaillées (poste, séances), même nombre.
  const d=typeof nativeSystems!=='undefined'?nativeSystems.domain('entrainementCible'):null;
  if(d&&d.poids(p)){for(const i of d.tirages(p,r-fin,'jeune:'+r))v[i]=Math.min(97,v[i]+1);}
  else{const depart=(typeof seedHash==='function'?seedHash(p.id):0)%36;
  for(;r>fin;r--){const i=(depart+((36-r%36)%36)*ORDRE)%36;v[i]=Math.min(97,v[i]+1);}}
  p.nativeAttributesV1=v.map(x=>String(x).padStart(2,'0')).join('');
 }
 // Verse `part` du réservoir d'un jeune (de `avant` à `apres` points en attente) : compétences et qualités.
 function verserJeune(p,part,avant,apres){
  if(!part)return;
  p.skills=Object.fromEntries(Object.entries(p.skills).map(([key,value])=>[key,round(clamp(value+part,15,99))]));
  verses.set(p,cents((verses.get(p)||0)+part));
  hausses(p,avant,apres);
 }
 // Tout ce qui reste en attente, d'un coup (profil détaillé ou jeune).
 function solder(p,e){
  if(!e||!(e.n||e.c))return;
  if(p.attributesV2)appliquer(p,e.n||0,e.c||{},null);else verserJeune(p,e.n||0,e.n||0,0);
 }
 // Poids des 36 qualités pour la progression (entrainement-cible.cjs) : {clé: part} ou null (répartition égale).
 function poidsCibles(p){
  if(typeof nativeSystems==='undefined')return null;
  const d=nativeSystems.domain('entrainementCible');if(!d)return null;
  const w=d.poids(p);if(!w)return null;
  return Object.fromEntries(d.CLES.map((k,i)=>[k,w[i]]));
 }
 // Part ciblée du gain de niveau projetée sur les compétences (Σ poids × hausse de chaque qualité) ; elle est ramenée
 // d'un facteur f tel que la moyenne pondérée par le poste (ROLE_WEIGHTS) vaille `niveau`, comme un gain réparti
 // également. Renvoie ce qu'il faut retirer à chaque compétence ((1 − f) × part ciblée) ; null si rien à corriger.
 function correctionCible(p,niveau,cible){
  const w=lnrProjectionWeightsV12({...p,gameplayPosition:p.gameplayPosition||p.pos});
  const rw=(typeof ROLE_WEIGHTS!=='undefined'&&(ROLE_WEIGHTS[p.fam]||ROLE_WEIGHTS[7]))||null;if(!rw)return null;
  const part={};for(const [k,poids] of Object.entries(w)){let t=0;for(const [q,x] of Object.entries(poids))t+=x*niveau*36*(cible[q]??1/36);part[k]=t;}
  let num=0,den=0;for(const [k,x] of Object.entries(rw)){num+=x*(part[k]||0);den+=x;}
  if(!den||!num)return null;
  const f=clamp(niveau/(num/den),.2,5);
  return Object.fromEntries(Object.entries(part).map(([k,v])=>[k,(1-f)*v]));
 }
 function projected(p){return lnrProjectV12({...p,gameplayPosition:p.gameplayPosition||p.pos});}
 // Applique aux 36 qualités un gain de niveau (même valeur partout), des points ciblés (qualités de la compétence
 // visée) et un déclin par qualité. Les compétences suivent la projection ; niveau et base ne bougent pas.
 // Renvoie l'écart moyen des compétences (pour la note de niveau à la transition).
 function appliquer(p,niveau,cibles,declin){
  const before=p.attributesV2,old=projected(p);
  const visees=cibles?Object.entries(cibles).filter(([,v])=>v):[];
  const weights=visees.length?lnrProjectionWeightsV12({...p,gameplayPosition:p.gameplayPosition||p.pos}):null;
  // Entraînement ciblé (24/11/2026) : le gain de niveau va aux qualités travaillées (séances de la semaine, poste,
  // rôle), même total sur les 36 qu'avant.
  const cible=niveau?poidsCibles(p):null;
  p.attributesV2=Object.fromEntries(Object.entries(before).map(([key,value])=>{
   let delta=cible&&Object.hasOwn(cible,key)?niveau*36*cible[key]:niveau;
   if(weights)for(const [focus,amount] of visees)if(Object.hasOwn(weights[focus]||{},key))delta+=amount;
   if(declin)delta-=declin[key]||0;
   return [key,round(clamp(value+delta,20,97))];
  }));
  const next=projected(p);let total=0,n=0;
  // Compétences : la part ciblée du gain de niveau suit les qualités travaillées, ramenée pour que la note au poste
  // (compétences pondérées du poste) gagne autant qu'avant : pas d'inflation, seule la répartition change.
  const correction=cible?correctionCible(p,niveau,cible):null;
  p.skills=Object.fromEntries(Object.entries(p.skills).map(([key,value])=>{const d=next[key]-old[key]-(correction?correction[key]||0:0);total+=d;n++;return [key,round(clamp(value+d,15,99))];}));
  return n?total/n:0;
 }
 // Déclin de l'âge de la saison par qualité (centièmes), comme LNR_V11_AGE.step à la transition (sans exposition :
 // aucun gain), calculé sur un profil neutre (60 partout) pour ne pas buter sur les bornes. null : aucun déclin.
 const declins=new WeakMap();
 function declin(p){
  const prof=p.hiddenTraitsV2?.professionalism,pos=p.gameplayPosition||p.pos,cle=p.age+'|'+pos+'|'+prof;
  const cache=declins.get(p);if(cache&&cache.cle===cle)return cache.d;
  let d=null;
  try{
   const neutre=Object.fromEntries(Object.keys(p.attributesV2).map(k=>[k,60]));
   const r=LNR_V11_AGE.step({id:p.id,gameplayPosition:pos,attributesV2:neutre,potential:60,hiddenTraitsV2:{professionalism:prof}},
    {playerId:p.id,age:p.age,season:Math.max(1,S.season|0),lastSeason:null},{minutes:0,training:0,injuryWeeks:0,load:0});
   const v=Object.fromEntries(Object.keys(neutre).map(k=>[k,cents(60-r.player.attributesV2[k])]));
   if(Object.values(v).some(x=>x>0))d=v;
  }catch(e){d=null;}
  declins.set(p,{cle,d});return d;
 }
 // État de la saison du joueur ; un reste d'une saison close sans transition est libéré.
 function etat(p){
  const d=p.dev;let e=d.etale;
  if(e&&e.s===S.season)return e;
  if(e){solder(p,e);delete d.etale;}
  const t=clamp(Math.floor(Number(S.worldMode?.week)||0),0,SAISON);
  e=d.etale={s:S.season,t};if(t)e.a=t;
  return e;
 }
 // Point de niveau ou point ciblé gagné : niveau tout de suite (comme avant), qualités et compétences en attente.
 // La base suit le niveau et les compétences compensent les points ciblés : la note de match ne bouge pas encore.
 function franchir(p,niveau,cibles){
  const base=p.skillBase,nextBase=clamp(base+niveau,15,99),residual=niveau-(nextBase-base);
  p.skillBase=nextBase;
  if(residual||Object.values(cibles).some(v=>v))p.skills=Object.fromEntries(Object.entries(p.skills).map(([key,value])=>[key,round(clamp(value-residual-(cibles[key]||0),15,99))]));
  const e=etat(p);
  if(niveau)e.n=cents((e.n||0)+niveau);
  for(const [k,v] of Object.entries(cibles))if(v)(e.c||(e.c={}))[k]=cents((e.c[k]||0)+v);
 }
 // Une semaine d'entraînement : part des gains en attente, part du déclin de l'âge.
 function semaine(p){
  let e=p.dev.etale;
  if(e&&e.s!==S.season){if(e.n||e.c)appliquer(p,e.n||0,e.c||{},null);delete p.dev.etale;e=null;}
  const D=declin(p);
  if(!e&&!D)return; // rien en attente, aucun déclin : rien d'enregistré
  e=e||etat(p);
  const t0=e.t,reste=Math.max(1,SAISON-t0);e.t=t0+1;
  if(e.n||e.c){
   const part=v=>cents(Math.min(v,Math.max(v/reste,PAS)));
   const niveau=e.n?part(e.n):0,cibles={};
   for(const [k,v] of Object.entries(e.c||{}))cibles[k]=part(v);
   if(niveau||Object.values(cibles).some(v=>v)){
    appliquer(p,niveau,cibles,null);
    if(e.n){e.n=cents(e.n-niveau);if(e.n<=0)delete e.n;}
    for(const k of Object.keys(cibles)){e.c[k]=cents(e.c[k]-cibles[k]);if(e.c[k]<=0)delete e.c[k];}
    if(e.c&&!Object.keys(e.c).length)delete e.c;
   }
  }
  if(D){
   const inc={},avant=Math.min(1,t0/SAISON),apres=Math.min(1,e.t/SAISON);
   for(const k of Object.keys(D))inc[k]=cents(cents(D[k]*apres)-cents(D[k]*avant));
   if(Object.values(inc).some(v=>v))e.r=dixmill((e.r||0)+appliquer(p,0,null,inc));
  }
 }
 function* joueurs(s){
  const vus=new Set();
  for(const c of s?.clubs||[])for(const p of c?.players||[])if(!vus.has(p)){vus.add(p);yield p;}
  for(const p of s?.economy?.freeAgents||[])if(!vus.has(p)){vus.add(p);yield p;}
  for(const p of s?.development?.academy||[])if(!vus.has(p)){vus.add(p);yield p;}
  // Marché : copies des agents libres après un rechargement ; elles doivent rester identiques au vivier.
  for(const p of Array.isArray(s?.market)?s.market:[])if(!vus.has(p)){vus.add(p);yield p;}
  // Centres de formation des clubs gérés.
  for(const a of s?.aiRoster?.academies||[])for(const p of a?.players||[])if(!vus.has(p)){vus.add(p);yield p;}
  for(const a of s?.nativeAcademy?.centers||[])for(const p of a?.players||[])if(!vus.has(p)){vus.add(p);yield p;}
 }
 // Une semaine d'entraînement d'un jeune : part de son réservoir (même règle que semaine()), état effacé une fois vide.
 function semaineJeune(p){
  const e=p.dev.etale;
  if(e.s!==S.season){solder(p,e);delete p.dev.etale;return;}
  const reste=Math.max(1,SAISON-e.t);e.t++;
  if(e.n){const part=cents(Math.min(e.n,Math.max(e.n/reste,PAS))),apres=cents(e.n-part);verserJeune(p,part,e.n,apres);if(apres>0)e.n=apres;else delete e.n;}
  if(!e.n&&!e.c)delete p.dev.etale;
 }
 function hebdo(){if(typeof S==='undefined'||!S)return;for(const p of joueurs(S))if(p?.dev){if(detailed(p))semaine(p);else if(p.dev.etale&&!p.attributesV2)semaineJeune(p);}}
 // Suivi des qualités (player-attributes.cjs) : part versée aux compétences d'un jeune depuis le relevé d'avant
 // commande (à retrancher de l'écart constaté), et remise à zéro à chaque relevé.
 function verse(p){return verses.get(p)||0;}
 function releve(){verses=new WeakMap();}
 // Tout ce qui est en attente, d'un coup (tests).
 function liberer(p){const e=p?.dev?.etale;if(e&&(e.n||e.c)){solder(p,e);delete e.n;delete e.c;}}
 // Transition annuelle d'un profil détaillé suivi cette saison : reste des gains et du déclin, puis note de niveau.
 function transition(p,completedSeason,e){
  const d=p.dev;
  if(e.n||e.c)appliquer(p,e.n||0,e.c||{},null);
  let r=e.r||0;const D=declin(p);
  if(D){
   const inc={},fait=Math.min(1,e.t/SAISON),depart=Math.min(1,(e.a||0)/SAISON);
   for(const k of Object.keys(D))inc[k]=cents(D[k]-(cents(D[k]*fait)-cents(D[k]*depart)));
   if(Object.values(inc).some(v=>v))r+=appliquer(p,0,null,inc);
  }
  delete d.etale;
  const old=p.rating;
  d.lastYear=completedSeason;
  d.history.push({season:completedSeason,age:p.age,start:d.seasonStart,end:p.rating,minutes:d.minutes,appearances:d.appearances});d.history=d.history.slice(-12);
  p.rating=clamp(Math.round(old+r),20,99);const base=p.skillBase,nextBase=clamp(base+p.rating-old,15,99),residual=p.rating-old-(nextBase-base);p.skillBase=nextBase;
  if(residual)p.skills=Object.fromEntries(Object.entries(p.skills).map(([key,value])=>[key,round(clamp(value-residual,15,99))]));
  p.age=p.age+1;d.potential=Math.max(p.rating,d.potential);d.decline=Math.max(0,Math.min(5,old-p.rating));d.seasonStart=p.rating;
  d.minutes=0;d.appearances=0;d.xp=0;if(d.specialization)d.specialization.xp=0;p.condition=100;p.injury=0;
 }
 function validate(s){
  for(const p of joueurs(s)){
   const e=p?.dev?.etale;if(e===undefined)continue;
   const ok=e&&typeof e==='object'&&Object.keys(e).every(k=>['s','t','a','n','c','r'].includes(k))&&Number.isInteger(e.s)&&e.s>=1&&Number.isInteger(e.t)&&e.t>=0
    &&(e.a===undefined||Number.isInteger(e.a)&&e.a>=0&&e.a<=SAISON)&&(e.n===undefined||Number.isFinite(e.n)&&e.n>0&&e.n<100)
    &&(e.c===undefined||e.c&&typeof e.c==='object'&&Object.values(e.c).every(v=>Number.isFinite(v)&&v>0&&v<100))&&(e.r===undefined||Number.isFinite(e.r)&&Math.abs(e.r)<100);
   if(!ok)throw Error('Progression étalée du joueur invalide.');
  }
  return true;
 }
 let installed=false;
 function installHooks(){
  if(installed)return;installed=true;
  const legacyGrow=growPlayer;
  growPlayer=function(p,xp,allowFocus=true){
   if(!Number.isFinite(xp)||xp<=0)return legacyGrow.apply(this,arguments);
   const professionalism=typeof nativePotentialEvolution!=='undefined'?nativePotentialEvolution.traits(p).professionalism:p.hiddenTraitsV2?.professionalism??50;
   const learningXP=xp*(.85+clamp(professionalism,0,100)*.003);
   if(!detailed(p)){
    if(!jeune(p))return legacyGrow.call(this,p,learningXP,allowFocus);
    // Jeune du centre : niveau tout de suite, compétences et qualités semaine après semaine.
    const niveau=p.rating,result=legacyGrow.call(this,p,learningXP,allowFocus);
    if(p.rating>niveau)franchir(p,p.rating-niveau,{});
    return result;
   }
   const level=p.rating,bonuses={...(p.dev?.specialization?.bonuses||{})};
   const flags={};for(const key of ['lnrRatingsVersion','worldRatingsVersion'])if(Object.hasOwn(p,key)){flags[key]=p[key];delete p[key];}
   let result;try{result=legacyGrow.call(this,p,learningXP,allowFocus);}finally{Object.assign(p,flags);}
   const focus=Object.fromEntries(Object.entries(p.dev?.specialization?.bonuses||{}).map(([key,value])=>[key,value-(bonuses[key]||0)]));
   if(p.rating!==level||Object.values(focus).some(v=>v))franchir(p,p.rating-level,focus);
   p.dev.inSeasonGrowthSeason=S.season;
   return result;
  };
  const legacyAge=ageDevelopmentPlayer;
  ageDevelopmentPlayer=function(p,completedSeason=S.season){
   const e=p?.dev?.etale;
   if(e&&detailed(p)&&e.s===completedSeason){if(p.dev.lastYear===completedSeason)return;return transition(p,completedSeason,e);}
   if(e){liberer(p);delete p.dev.etale;}
   if(!detailed(p)||p.dev?.inSeasonGrowthSeason!==completedSeason)return legacyAge.apply(this,arguments);
   const d=p.dev;if(d.lastYear===completedSeason)return;
   const old=p.rating,oldSkills={...p.skills},before=projected(p);
   d.lastYear=completedSeason;
   d.history.push({season:completedSeason,age:p.age,start:d.seasonStart,end:p.rating,minutes:d.minutes,appearances:d.appearances});d.history=d.history.slice(-12);
   const aged=LNR_V11_AGE.step({...p,gameplayPosition:p.gameplayPosition||p.pos,potential:clamp(Math.max(p.rating,d.potential),20,97)},
    {playerId:p.id,age:p.age,season:completedSeason,lastSeason:null},{minutes:0,training:0,injuryWeeks:Math.min(52,p.injury||0),load:0});
   p.attributesV2=aged.player.attributesV2;const after=projected(p);
   const delta=Object.keys(oldSkills).reduce((sum,key)=>sum+after[key]-before[key],0)/Object.keys(oldSkills).length;
   p.rating=clamp(Math.round(old+delta),20,99);const base=p.skillBase,nextBase=clamp(base+p.rating-old,15,99),residual=p.rating-old-(nextBase-base);p.skillBase=nextBase;
   p.skills=Object.fromEntries(Object.entries(oldSkills).map(([key,value])=>[key,round(clamp(value+after[key]-before[key]-residual,15,99))]));
   p.age=aged.state.age;d.potential=Math.max(p.rating,d.potential);d.decline=Math.max(0,Math.min(5,old-p.rating));d.seasonStart=p.rating;
   d.minutes=0;d.appearances=0;d.xp=0;if(d.specialization)d.specialization.xp=0;p.condition=100;p.injury=0;
  };
  if(typeof trainWeek==='function'){
   const avant=trainWeek;
   trainWeek=function(){const frais=typeof S!=='undefined'&&!!S&&!S.trained;const r=avant.apply(this,arguments);if(frais&&S&&S.trained)hebdo();return r;};
   Object.assign(trainWeek,avant);
  }
 }
 return Object.freeze({installHooks,validate,liberer,semaine,hebdo,verse,releve,SAISON});
};
