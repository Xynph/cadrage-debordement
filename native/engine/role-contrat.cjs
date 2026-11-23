'use strict';
// Rôle promis au contrat (revue FM27, idée 12 « contrats en un coup d'œil » ; décision de Léo du 23/11/2026, base commune
// des idées 16 « temps de jeu promis » et 18 « négociation avec l'agent »).
//  - Quatre rôles : titulaire, rotation, espoir, appoint.
//  - Enregistré sur le joueur à la signature et à la prolongation : p.roleContrat = {role, saison, fin, club} (+ deduit:true
//    quand personne ne l'a promis explicitement). `fin` et `club` rattachent le rôle à CE contrat : un nouveau contrat
//    (recrue, prolongation du manager ou du directeur sportif, promotion, retour au club) en reçoit un nouveau.
//  - Promesse explicite : champ `role` de recruit / extend_contract (gestion.cjs), posé par roleContratPoser.
//  - Sinon (et pour les contrats des anciennes sauvegardes) : rôle déduit de la hiérarchie au poste au moment où il est
//    enregistré : rang de note parmi les joueurs sous contrat du club de la même famille de poste (sans les appelés du
//    centre de formation), comparé au nombre de places de
//    cette famille dans le XV (FAMILIES de dist/rugby.js) ; dans les places = titulaire, dans les places suivantes =
//    rotation, au-delà espoir (21 ans et moins, règle « Jeune » de l'Effectif) ou appoint.
//  - observe() (worker.cjs, après chaque commande qui peut toucher les joueurs) enregistre les rôles manquants ou
//    périmés du club du manager : migration des sauvegardes au premier passage, puis chaque nouveau contrat.
//  - Écran : model.cjs envoie squad[].roleContrat = {role, deduit, saison} (rôle déduit en direct tant qu'il n'est pas
//    encore enregistré). Couleurs et libellés communs côté Godot : native/godot/ui/role_contrat.gd.
// Fonctions globales de la VM : roleContratJoueur(p), roleContratPoser(p, role, deduit), roleContratDeduire(p).
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const ROLES=Object.freeze(['titulaire','rotation','espoir','appoint']);
 const AGE_ESPOIR=21;
 // Places de chaque famille de poste dans le XV (piliers 2, talonneur 1, deuxièmes lignes 2, troisièmes lignes 3…).
 const FAMILLES_XV=Object.freeze([0,1,0,2,2,3,3,3,4,5,6,7,7,6,8]);
 const entier=x=>Number.isSafeInteger(x);
 const sousContrat=p=>!!p&&entier(p.contractEnd)&&!p.espoirLoan;
 function clubDe(s){
  if(!s||!Array.isArray(s.clubs))return null;
  return s.clubs.find(c=>c&&c.id===s.club)||s.clubs[s.club]||null;
 }
 // Rôle déduit de la hiérarchie actuelle au poste (pur : joueurs du club en argument).
 function deduire(p,joueurs){
  const fam=p?.fam,meme=(Array.isArray(joueurs)?joueurs:[]).filter(q=>sousContrat(q)&&(fam===undefined?q.pos===p.pos:q.fam===fam));
  if(!meme.some(q=>q.id===p.id))meme.push(p);
  const note=q=>Number.isFinite(q.rating)?q.rating:0;
  const rang=meme.slice().sort((a,b)=>note(b)-note(a)||(String(a.id)<String(b.id)?-1:String(a.id)>String(b.id)?1:0)).findIndex(q=>q.id===p.id);
  const places=Math.max(1,FAMILLES_XV.filter(f=>f===fam).length);
  if(rang<places)return 'titulaire';
  if(rang<2*places)return 'rotation';
  return Number.isFinite(p.age)&&p.age<=AGE_ESPOIR?'espoir':'appoint';
 }
 const valide=r=>!!r&&typeof r==='object'&&ROLES.includes(r.role)&&entier(r.saison)&&r.saison>=1&&entier(r.fin)&&entier(r.club)&&(r.deduit===undefined||r.deduit===true);
 // Rôle enregistré encore attaché au contrat en cours ?
 const aJour=(p,s)=>valide(p?.roleContrat)&&p.roleContrat.fin===p.contractEnd&&p.roleContrat.club===s?.club;
 function poser(p,role,deduit,s=typeof S==='undefined'?null:S){
  if(!sousContrat(p)||!ROLES.includes(role)||!s)return false;
  p.roleContrat={role,saison:s.season,fin:p.contractEnd,club:s.club,...(deduit?{deduit:true}:{})};
  return true;
 }
 // Vue pour l'écran : rôle du contrat en cours (déduit en direct s'il n'est pas encore enregistré).
 function vue(p,s=typeof S==='undefined'?null:S){
  if(!sousContrat(p))return null;
  if(aJour(p,s))return {role:p.roleContrat.role,deduit:p.roleContrat.deduit===true,saison:p.roleContrat.saison};
  return {role:deduire(p,clubDe(s)?.players),deduit:true,saison:null};
 }
 // Enregistre les rôles manquants ou périmés du club du manager (migration, nouveaux contrats).
 function observe(s=typeof S==='undefined'?null:S){
  const c=clubDe(s);if(!c||!Array.isArray(c.players))return 0;
  let n=0;
  for(const p of c.players){
   if(!sousContrat(p)||aJour(p,s))continue;
   poser(p,deduire(p,c.players),true,s);n++;
  }
  return n;
 }
 function validate(s){
  for(const c of Array.isArray(s?.clubs)?s.clubs:Object.values(s?.clubs||{}))for(const p of c?.players||[])
   if(p&&p.roleContrat!==undefined&&!valide(p.roleContrat))throw Error('Rôle promis au contrat invalide.');
  return true;
 }
 function installHooks(){
  globalThis.roleContratJoueur=p=>vue(p);
  globalThis.roleContratPoser=(p,role,deduit)=>poser(p,role,deduit);
  globalThis.roleContratDeduire=p=>deduire(p,clubDe(typeof S==='undefined'?null:S)?.players);
  return true;
 }
 return {project(){return null;},validate,execute(){throw Error('Aucune commande de rôle de contrat.');},installHooks,observe,deduire,poser,vue,aJour,ROLES,AGE_ESPOIR};
}
module.exports={files,commands,factory};
