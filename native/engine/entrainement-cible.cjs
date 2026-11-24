'use strict';
// Entraînement ciblé (choix de Léo du 24/11/2026, flèches de progression) : la progression d'un joueur ne monte plus
// les 36 qualités d'autant. Elle va aux qualités travaillées :
//  - séances collectives de la semaine (programme jour par jour, calendar-planning.cjs) : chaque séance travaille SON
//    groupe cohérent de qualités (Force → force, explosivité, port du ballon…), pour les avants ou les arrières selon
//    la séance (le jeu au pied touche peu les avants) ; récupération : rien ; préparation spécifique du match en plus ;
//  - entraînement individuel : à son poste (qualités qui comptent le plus pour le poste, d'après les compétences du
//    poste et leurs qualités), à son rôle de jeu de la fiche (Plaqueur, Gratteur… : qualités clés et utiles) et à son
//    rôle désigné (buteur, lanceur en touche, jeu au pied d'occupation) ;
//  - un fond très faible pour le reste (les qualités non travaillées ne bougent presque pas).
// Même quantité de progression qu'avant (somme des 36 hausses inchangée : la moyenne des 36, le niveau et son rythme
// restent ceux d'avant) ; seule la répartition change. Poids = parts de 36 hausses (somme 1).
// Clubs gérés par l'ordinateur et semaines sans programme : semaine type standard du staff.
// Le même fichier sert au calendrier (Node, groupes de qualités de chaque séance pour l'écran de choix) et à la VM
// (poids appliqués par in-season-development.cjs et player-attributes.cjs) : la fabrique ne touche aucune variable
// de la VM à sa construction.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const CLES=Object.freeze(['passing','receiving','offload','tackling','jackal','ruckClearout','ballCarry','evasion',
  'kickDistance','kickAccuracy','goalAccuracy','ballHandling','decisions','anticipation','vision','positioning','composure',
  'discipline','teamwork','leadership','workRate','acceleration','topSpeed','agility','explosiveness','strength','endurance',
  'jumping','scrumTechnique','hooking','lineoutThrow','lineoutJump','lineoutLift','maul','kickChase','aerialAbility']);
 const INDEX=Object.fromEntries(CLES.map((k,i)=>[k,i]));
 // Groupes de qualités (cinq ou six qualités liées) ; une séance en travaille un.
 const GROUPES=Object.freeze({
  force:['strength','explosiveness','ballCarry','ruckClearout','maul'],
  physique:['strength','endurance','workRate','explosiveness'],
  vitesse:['acceleration','topSpeed','agility','explosiveness','evasion'],
  activation:['acceleration','agility','explosiveness'],
  melee:['scrumTechnique','hooking','strength','maul'],
  touche:['lineoutThrow','lineoutJump','lineoutLift','jumping','aerialAbility'],
  conquete:['scrumTechnique','hooking','lineoutThrow','lineoutJump','lineoutLift','maul'],
  lancements:['passing','receiving','positioning','decisions','evasion'],
  ligne:['passing','receiving','ballHandling','positioning','vision'],
  circulation:['passing','ballHandling','offload','positioning','teamwork'],
  plaquage:['tackling','jackal','ruckClearout','positioning','workRate'],
  passes:['passing','receiving','ballHandling','offload','agility'],
  pied:['kickDistance','kickAccuracy','goalAccuracy','kickChase','aerialAbility'],
  miseEnPlace:['decisions','positioning','teamwork','anticipation','discipline'],
  transitions:['decisions','anticipation','workRate','teamwork','positioning'],
  video:['anticipation','vision','decisions','composure','discipline'],
  recuperation:[]
 });
 // Part d'une séance pour les avants (a) et les arrières (b) selon sa famille.
 const COTE=Object.freeze({strength:{a:1,b:.6},speed:{a:.5,b:1},team:{a:1,b:1},skills:{a:1,b:1},kicking:{a:.15,b:1},
  tactics:{a:.7,b:.7},video:{a:.5,b:.5},recovery:{a:0,b:0}});
 const ATELIERS_AVANTS={'Mêlée':'melee','Touche':'touche','Conquête':'conquete'};
 const ATELIERS_ARRIERES={'Lancements':'lancements','Jeu de ligne':'ligne','Circulation':'circulation'};
 // Groupe d'une séance pour un avant (avant=true) ou un arrière : famille + nom de la séance (ateliers par poste :
 // atelier des avants / des arrières, conquête / circulation par défaut).
 function groupe(seance,avant){
  const kind=String(seance?.kind||''),label=String(seance?.label||'');
  switch(kind){
   case 'strength':return /reprise/i.test(label)?'physique':'force';
   case 'speed':return /activation/i.test(label)?'activation':'vitesse';
   case 'team':return avant?(ATELIERS_AVANTS[seance?.forwards]||'conquete'):(ATELIERS_ARRIERES[seance?.backs]||'circulation');
   case 'skills':return /plaqu/i.test(label)?'plaquage':'passes';
   case 'kicking':return 'pied';
   case 'tactics':return /transition/i.test(label)?'transitions':'miseEnPlace';
   case 'video':return 'video';
   default:return 'recuperation';
  }
 }
 // Qualités travaillées par une séance : {avants:[clé…], arrieres:[clé…]} (vide pour une récupération ; pas de liste
 // pour un côté que la séance touche à peine).
 function qualitesSeance(seance){
  const c=COTE[seance?.kind]||{a:0,b:0};
  return {avants:c.a>=.3?GROUPES[groupe(seance,true)].slice():[],arrieres:c.b>=.3?GROUPES[groupe(seance,false)].slice():[]};
 }
 // Semaine type standard du staff (calendar-planning.cjs, programme « standard ») : clubs de l'ordinateur et semaines
 // sans programme.
 const STANDARD=Object.freeze([{kind:'strength',label:'Force'},{kind:'team',label:'Ateliers par poste',forwards:'Mêlée',backs:'Lancements'},
  {kind:'video',label:'Vidéo'},{kind:'kicking',label:'Jeu au pied'},{kind:'skills',label:'Plaquage'},{kind:'tactics',label:'Mise en place'},
  {kind:'speed',label:'Activation'},{kind:'recovery',label:'Récupération'}]);
 // Préparation spécifique du match (S.collectiveFocus) : un groupe de plus pour le club du manager.
 const FOCUS={conquete:'conquete',defence:'plaquage',pied:'pied'};
 // Rôles désignés (S.playerRoles : buteur, buteur de secours, lanceur en touche, jeu au pied d'occupation).
 const ROLES=Object.freeze({buteur:['goalAccuracy','kickAccuracy','composure'],secours:['goalAccuracy','kickAccuracy','composure'],
  lanceur:['lineoutThrow','composure','ballHandling'],pied:['kickDistance','kickAccuracy','kickChase','vision']});
 // Rôle de jeu de la fiche joueur (« SON RÔLE », native/godot/ui/immersive08/fiche_roles.gd, même table, vérifiée par
 // tests/entrainement-cible.cjs) : [id, famille, nom, 4 qualités clés, 4 utiles]. Le rôle du joueur est le meilleur
 // rôle de la famille de son poste principal (note clé × 2, utile × 1), comme la fiche ; il est travaillé à
 // l'entraînement individuel (clés × 2, utiles × 1) : un 3e ligne Plaqueur et un Gratteur ne progressent pas pareil.
 const FAMILLE=Object.freeze(['pilier','talonneur','pilier','deuxieme','deuxieme','aile','aile','huit','demi','ouvreur','ailier','centre','centre','ailier','arriere']);
 const ROLES_JEU=Object.freeze([
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
 ]);
 // Parts : séances collectives, poste, rôle de jeu, rôle désigné (buteur, lanceur…), fond réparti sur les 36.
 const PART={collectif:.5,poste:.2,roleJeu:.2,role:.12,fond:.1};
 const POSTE_TAILLE=6;
 const g=globalThis;
 const avantDe=p=>Number(p?.fam)<=3;
 // Vecteur des séances pour un côté : [vecteur de somme 1, intensité 0..1]. L'intensité est la part de la semaine
 // qui concerne ce côté (une semaine de jeu au pied seul ne fait presque rien progresser chez les avants) ; ce qui
 // manque revient au poste.
 function vecteurSeances(seances,avant){
  const v=new Array(36).fill(0);let total=0,plein=0;
  for(const s of seances){
   const c=COTE[s.kind]||{a:0,b:0},part=c[avant?'a':'b'],liste=GROUPES[s.groupe||groupe(s,avant)]||[];
   if(!liste.length)continue;
   plein+=Math.max(c.a,c.b);
   if(!part)continue;
   for(const k of liste)v[INDEX[k]]+=part/liste.length;total+=part;
  }
  return total?[v.map(x=>x/total),total/plein]:[null,0];
 }
 // Qualités du poste : importance = poids des compétences du poste (ROLE_WEIGHTS) × poids de la qualité dans chaque
 // compétence (projection du poste). Les POSTE_TAILLE premières, à parts égales.
 const postes=new Map();
 function vecteurPoste(p){
  const pos=p?.gameplayPosition||p?.pos||'',fam=Number.isInteger(p?.fam)&&p.fam>=0?p.fam:7,cle=pos+'|'+fam;
  if(postes.has(cle))return postes.get(cle);
  let v=null;
  try{
   const rw=(typeof ROLE_WEIGHTS!=='undefined'&&(ROLE_WEIGHTS[fam]||ROLE_WEIGHTS[7]))||null;
   const pw=typeof lnrProjectionWeightsV12==='function'?lnrProjectionWeightsV12({gameplayPosition:pos}):null;
   if(rw&&pw){
    const imp=new Array(36).fill(0),tot=Object.values(rw).reduce((a,b)=>a+b,0)||1;
    for(const [comp,poids] of Object.entries(rw))for(const [q,w] of Object.entries(pw[comp]||{}))if(q in INDEX)imp[INDEX[q]]+=poids/tot*w;
    const tri=imp.map((x,i)=>[x,i]).filter(([x])=>x>0).sort((a,b)=>b[0]-a[0]||a[1]-b[1]).slice(0,POSTE_TAILLE);
    const somme=tri.reduce((a,[x])=>a+x,0);
    if(somme>0){v=new Array(36).fill(0);for(const [,i] of tri)v[i]=1/tri.length;}
   }
  }catch(e){v=null;}
  postes.set(cle,v);return v;
 }
 // Famille de jeu du poste principal (maillot du poste, sinon de la famille : position-aptitudes.cjs).
 function familleJeu(p){
  let n=-1;
  try{if(typeof POS!=='undefined')n=POS.indexOf(p?.pos);if(n<0&&typeof FAMILIES!=='undefined')n=FAMILIES.indexOf(p?.fam);}catch(e){n=-1;}
  return n>=0?FAMILLE[n]:null;
 }
 function qualitesDe(p){
  const a=p?.attributesV2;
  if(a&&typeof a==='object'&&CLES.every(k=>Number.isFinite(a[k])))return a;
  if(typeof p?.nativeAttributesV1==='string'&&typeof nativeAttributeStore!=='undefined'){try{return nativeAttributeStore.project(p).attributesV2;}catch(e){return null;}}
  return null;
 }
 // Rôle de jeu du joueur : meilleur rôle de sa famille (note clé × 2, utile × 1), premier en cas d'égalité ; null sinon.
 function roleJeu(p){
  const f=familleJeu(p),v=qualitesDe(p);if(!f||!v)return null;
  let choix=null,meilleur=-1;
  for(const r of ROLES_JEU){if(r[1]!==f)continue;let t=0;for(const k of r[3])t+=2*v[k];for(const k of r[4])t+=v[k];const n=t/12;if(n>meilleur){meilleur=n;choix=r;}}
  return choix;
 }
 function vecteurRoleJeu(r){
  if(!r)return null;const v=new Array(36).fill(0);
  for(const k of r[3])v[INDEX[k]]+=2/12;for(const k of r[4])v[INDEX[k]]+=1/12;return v;
 }
 const NOMS_DESIGNES={buteur:'Buteur',secours:'Buteur de secours',lanceur:'Lanceur en touche',pied:'Jeu au pied d’occupation'};
 const state=()=>typeof S==='undefined'?null:S;
 // Séances de la semaine du club du manager (programme posé par le worker, nativeProgrammeEffets) ; null sinon.
 function seancesManager(s){
  const e=g.nativeProgrammeEffets;
  if(!s||!e||g.nativeProgrammeDesactive===true||e.season!==s.season||e.round!==s.round||!Array.isArray(e.seances))return null;
  const liste=e.seances.filter(x=>x&&typeof x.kind==='string');
  return liste.length?liste:null;
 }
 let memo=new Map();let memoCle='';
 function rolesDe(s,p){
  const r=s?.playerRoles;if(!r||typeof r!=='object')return [];
  return Object.keys(ROLES).filter(k=>r[k]===p.id);
 }
 function duManager(s,p){
  const c=s?.clubs?.[s.club];if(!c||!Array.isArray(c.players))return false;
  if(c.players.includes(p))return true;
  return (s.development?.academy||[]).includes(p);
 }
 // Poids des 36 qualités pour la progression de la semaine du joueur (somme 1), ou null (répartition égale).
 function poids(p){
  const s=state();if(!p)return null;
  const mien=!!s&&duManager(s,p),avant=avantDe(p);
  const seances=(mien&&seancesManager(s))||STANDARD;
  const focus=mien&&FOCUS[s?.collectiveFocus]?[{kind:'team',groupe:FOCUS[s.collectiveFocus]}]:[];
  const roles=mien?rolesDe(s,p):[],jeu=roleJeu(p);
  const cle=(mien?'m':'o')+'|'+(p.gameplayPosition||p.pos)+'|'+p.fam+'|'+(jeu?jeu[0]:'')+'|'+roles.join(',')+'|'+(seances===STANDARD?'std':JSON.stringify(seances.map(x=>[x.kind,x.label,x.forwards,x.backs])))+'|'+focus.map(f=>f.groupe).join(',');
  const semaine=(s?.season||0)+':'+(s?.round||0);
  if(memoCle!==semaine){memo=new Map();memoCle=semaine;}
  if(memo.has(cle))return memo.get(cle);
  const [coll,intensite]=vecteurSeances([...seances,...focus],avant),poste=vecteurPoste(p);
  let role=null;
  if(roles.length){role=new Array(36).fill(0);const qs=[...new Set(roles.flatMap(r=>ROLES[r]))];for(const k of qs)role[INDEX[k]]+=1/qs.length;}
  const parts=[[coll,PART.collectif*intensite],[poste,PART.poste],[vecteurRoleJeu(jeu),PART.roleJeu],[role,role?PART.role:0]].filter(([v,w])=>v&&w>0);
  const reste=1-PART.fond,somme=parts.reduce((a,[,w])=>a+w,0);
  let v=null;
  if(somme>0){
   v=new Array(36).fill(PART.fond/36);
   for(const [vec,w] of parts)for(let i=0;i<36;i++)v[i]+=vec[i]*w/somme*reste;
  }
  memo.set(cle,v);return v;
 }
 // Hausses entières d'un profil aux qualités entières (jeunes, profils générés) : `n` hausses d'un point réparties
 // selon les poids, tirées par une graine propre au joueur et à la semaine (même état → mêmes hausses). Renvoie les
 // index (une entrée par hausse) ; répartition égale sans poids.
 function hash(t){let h=2166136261;for(let i=0;i<t.length;i++){h^=t.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;}
 function tirages(p,n,sel){
  const w=poids(p)||new Array(36).fill(1/36),cumul=[];let t=0;for(const x of w){t+=x;cumul.push(t);}
  const s=state(),base=String(p?.id)+':'+(s?.season||0)+':'+(s?.round||0)+':'+(sel||'');const out=[];
  for(let k=0;k<n;k++){const u=(hash(base+':'+k)%1000003)/1000003*t;let i=cumul.findIndex(c=>u<c);if(i<0)i=35;out.push(i);}
  return out;
 }
 // Entraînement individuel du joueur, pour la fiche (sans chiffre) : qualités du poste, du rôle de jeu (clés, utiles)
 // et des rôles désignés au club du manager.
 function individuel(p){
  const s=state(),poste=vecteurPoste(p),jeu=roleJeu(p),mien=!!s&&duManager(s,p);
  return {poste:{nom:String(p?.pos||''),qualites:poste?CLES.filter((k,i)=>poste[i]>0):[]},
   role:jeu?{id:jeu[0],nom:jeu[2],cles:jeu[3].slice(),utiles:jeu[4].slice()}:null,
   designations:(mien?rolesDe(s,p):[]).map(r=>({id:r,nom:NOMS_DESIGNES[r],qualites:ROLES[r].slice()}))};
 }
 function project(){return null;}
 function validate(){return true;}
 function execute(){throw Error('Entraînement ciblé : aucune commande.');}
 function installHooks(){return true;}
 return {project,validate,execute,installHooks,poids,tirages,qualitesSeance,groupe,individuel,roleJeu,GROUPES,STANDARD,CLES,ROLES_JEU};
}
module.exports={files,commands,factory};
