'use strict';
// Rôle choisi par le club et Niveau du match (25/11/2026, chantier « moteur du match », docs/notation-fm-20261124.md).
//
// Rôle du joueur (roleId) : un des trois rôles de la famille de son poste principal (niveau-calcule.cjs, ROLES, même
// table que la fiche). Enregistré sur le joueur (p.roleId) par la commande set_player_role (joueur de notre effectif,
// hors match en direct) ; null ou '' l'efface. Repli : absent, inconnu ou d'une autre famille (changement de poste) →
// meilleur rôle de son poste, comme avant. Un joueur parti du club perd son rôle à la semaine suivante (son nouveau club
// le fait jouer à son meilleur rôle). Ancienne sauvegarde : aucun roleId, rien à migrer.
//
// Niveau du match : niveauMatch(p) = Niveau calculé au rôle (niveauJoueur(p, {roleId})), à l'échelle de `rating`
// (même moyenne et même dispersion sur le Monde) ; repli sur `rating` quand les qualités ou le poste sont inconnus.
// Remplace la lecture directe de `rating` comme niveau du joueur dans le match (teamLevel, résultat rapide), la
// sélection et les décisions de l'IA des clubs. Ne touche ni la valeur, ni les salaires, ni la progression, ni les
// compétences de match (skill, roleNote : `rating − skillBase` y reste l'écart de progression des compétences).
// Mémoire par joueur (WeakMap), invalidée dès que ses qualités, son rôle, son poste ou ses qualités cachées changent.
//
// Le module du Niveau (niveau-calcule.cjs) est injecté dans la VM par native-systems.cjs (CDNiveauCalcule).
const files=Object.freeze([]),commands=Object.freeze(['set_player_role']);
function factory(){
 const NC=typeof CDNiveauCalcule!=='undefined'?CDNiveauCalcule:null;
 const ROLE=new Map(NC?NC.ROLES.map(r=>[r[0],r]):[]);
 const MAX_ID=40;
 // Rôle retenu pour le moteur : roleId s'il est un rôle de la famille du poste du joueur, sinon null (meilleur rôle).
 function roleDe(p){
  const id=p?.roleId;if(typeof id!=='string'||!id||!NC)return null;
  const r=ROLE.get(id);return r&&r[1]===NC.familleDe(p)?id:null;
 }
 const memo=new WeakMap();
 function niveau(p){
  if(!p)return 50;
  const note=Number(p.rating)||50;if(!NC)return note;
  const a=p.attributesV2,n=p.nativeAttributesV1,role=p.roleId,h=p.hiddenTraitsV2,c=h?.consistency,b=h?.bigMatches,g=p.gameplayPosition,o=p.pos;
  const m=memo.get(p);
  if(m&&m.a===a&&m.n===n&&m.role===role&&m.c===c&&m.b===b&&m.g===g&&m.o===o&&m.note===note)return m.v;
  let v=note;
  try{const q=NC.niveauJoueur(p,{roleId:roleDe(p)})||(p.roleId?NC.niveauJoueur(p):null);if(q&&Number.isFinite(q.niveau))v=q.niveau;}catch(e){v=note;}
  memo.set(p,{a,n,role,c,b,g,o,note,v});
  return v;
 }
 const state=()=>typeof S==='undefined'?null:S;
 const effectif=s=>s?.clubs?.[s.club]?.players||[];
 function* joueurs(s){
  if(!s)return;
  for(const c of s.clubs||[])yield* c.players||[];
  yield* s.development?.academy||[];yield* s.economy?.freeAgents||[];yield* s.market||[];
 }
 function validate(s){
  for(const p of joueurs(s)){
   const r=p?.roleId;if(r===undefined)continue;
   if(typeof r!=='string'||r.length>MAX_ID)throw Error('Rôle du joueur invalide.');
  }
  return true;
 }
 // Rôle choisi pour un joueur de notre effectif (fiche) : un rôle de la famille de son poste ; null ou '' l'efface.
 function choisir(p,roleId){
  if(roleId===null||roleId===undefined||roleId===''){delete p.roleId;return null;}
  if(!NC)throw Error('Rôle du joueur : indisponible.');
  const r=typeof roleId==='string'?ROLE.get(roleId):null;
  if(!r)throw Error('Rôle inconnu.');
  if(r[1]!==NC.familleDe(p))throw Error('Rôle d’un autre poste.');
  p.roleId=roleId;return roleId;
 }
 function execute(command,payload){
  if(command!=='set_player_role')throw Error('Commande de rôle inconnue.');
  const s=state();
  if(!s||s.live&&!s.live.finished)throw Error('Rôle du joueur : indisponible pendant un match.');
  const p=effectif(s).find(x=>x.id===payload?.playerId);
  if(!p)throw Error('Rôle du joueur : joueur absent de ton effectif.');
  choisir(p,payload.roleId??null);
 }
 // Rôles choisis de notre effectif (la fiche montre « Son rôle ») : {playerId: roleId} ; rôle repli non envoyé.
 function project(){
  const out={};for(const p of effectif(state())){const r=roleDe(p);if(r)out[p.id]=r;}
  return {roles:out};
 }
 // Un joueur qui n'est plus de notre effectif perd le rôle choisi par le club (une fois par semaine d'entraînement).
 function oublierPartis(){
  const s=state();if(!s)return;
  const nous=new Set(effectif(s));
  for(const p of joueurs(s))if(p&&p.roleId!==undefined&&!nous.has(p))delete p.roleId;
 }
 let installe=false;
 function installHooks(){
  globalThis.niveauMatch=niveau;
  if(installe)return true;installe=true;
  if(typeof trainWeek==='function'){
   const avant=trainWeek;
   trainWeek=function(){if(typeof S!=='undefined'&&S&&!S.trained)oublierPartis();return avant.apply(this,arguments);};
   Object.assign(trainWeek,avant);
  }
  return true;
 }
 return {project,validate,execute,installHooks,niveauMatch:niveau,roleDe,
  // Pour les tests.
  _tests:{choisir,oublierPartis}};
}
module.exports={files,commands,factory};
