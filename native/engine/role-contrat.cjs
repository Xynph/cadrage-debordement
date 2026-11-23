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
// Temps de jeu promis (revue FM27, idée 16, choix de Léo du 23/11/2026 : option A, seuils, rôle qui pèse sur le
// salaire et l'acceptation) :
//  - Suivi : p.tempsJeu = {club, m:[[saison, semaine, adversaire, minutes, indisponible 0/1], …]} : les 10 derniers matchs
//    du club du manager depuis que le joueur y est (toutes compétitions, d'une saison à l'autre), posé après chaque match
//    (recordDevelopmentMatch). Indisponible = blessé ou suspendu sans jouer : le match ne compte pas. Anciennes
//    sauvegardes : repris des notes de match de la saison (S.matchNotes.detail) à partir du 1er match joué au club.
//  - Seuils : Titulaire 50 min de moyenne, Rotation 20 min de moyenne, Espoir au moins 1 match joué sur 4, Appoint sans
//    exigence. Jugé dès 3 matchs comptés : atteint = content, au moins 60 % du seuil = attentif, sinon mécontent.
//  - Salaire demandé : le rôle « attendu » est celui que la hiérarchie lui donne (deduire) ; promettre plus coûte +5 % par
//    cran (titulaire > rotation > espoir > appoint), promettre moins rapporte −4 % par cran ; en prolongation, jamais sous
//    le salaire actuel. Le minimum accepté (reservationWage) suit, puisqu'il part de la demande.
//  - Acceptation : un joueur ambitieux (ambition cachée ≥ 70, nativePotentialEvolution.traits) refuse Appoint ; Espoir
//    seulement à 21 ans et moins.
// Fonctions globales de la VM : roleContratJoueur(p), roleContratPoser(p, role, deduit), roleContratDeduire(p),
// roleContratRefus(p, role), roleContratAvec(p, role, fn), roleContratRoles(p, kind), roleContratTempsJeu(p).
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const ROLES=Object.freeze(['titulaire','rotation','espoir','appoint']);
 const AGE_ESPOIR=21;
 // Temps de jeu promis (idée 16).
 const MATCHS=10,JUGE_DES=3,ATTENTIF=.6;
 const SEUILS=Object.freeze({titulaire:Object.freeze({moyenne:50}),rotation:Object.freeze({moyenne:20}),espoir:Object.freeze({part:.25}),appoint:Object.freeze({})});
 const NIVEAU=Object.freeze({titulaire:3,rotation:2,espoir:1,appoint:0});
 const HAUSSE_CRAN=.05,BAISSE_CRAN=.04,AMBITION_REFUS=70;
 const RULES=Object.freeze({MATCHS,JUGE_DES,ATTENTIF,SEUILS,NIVEAU,HAUSSE_CRAN,BAISSE_CRAN,AMBITION_REFUS,AGE_ESPOIR});
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
 // --- Salaire et acceptation selon le rôle promis -------------------------------------------------------------------
 // Rôle attendu : place que la hiérarchie actuelle du club lui donne (recrue comprise, comparée à l'effectif).
 const attendu=(p,s=typeof S==='undefined'?null:S)=>deduire(p,clubDe(s)?.players);
 function facteur(p,role,s){
  if(!ROLES.includes(role))return 1;
  const d=NIVEAU[role]-NIVEAU[attendu(p,s)];
  return Math.round((1+(d>0?d*HAUSSE_CRAN:d*BAISSE_CRAN))*1000)/1000;
 }
 const ambition=p=>{try{return typeof nativePotentialEvolution!=='undefined'?nativePotentialEvolution.traits(p).ambition:50;}catch(e){return 50;}};
 // Motif de refus d'un rôle ('' si accepté).
 function refus(p,role){
  if(!ROLES.includes(role))return 'Rôle promis inconnu.';
  if(role==='espoir'&&!(Number.isFinite(p?.age)&&p.age<=AGE_ESPOIR))return 'Espoir : '+AGE_ESPOIR+' ans et moins.';
  if(role==='appoint'&&ambition(p)>=AMBITION_REFUS)return 'Joueur ambitieux : il refuse un rôle d’appoint.';
  return '';
 }
 // Offre en cours : askingWage (enveloppé dans installHooks) applique le facteur du rôle à ce joueur seulement.
 let enCours=null;
 function avec(p,role,fn){
  const avant=enCours;enCours=p&&ROLES.includes(role)?{id:p.id,role}:null;
  try{return fn();}finally{enCours=avant;}
 }
 function demande(base,p,kind){
  if(!enCours||!p||p.id!==enCours.id||!Number.isFinite(base))return base;
  const k=facteur(p,enCours.role);if(k===1)return base;
  const v=Math.round(base*k/100)*100;
  return kind==='renew'&&Number.isFinite(p.salary)?Math.max(p.salary,v):v;
 }
 // Les quatre rôles d'une offre : salaire demandé et refus éventuel ; `attendu` = rôle sans supplément.
 function roles(p,kind){
  if(!p||typeof askingWage!=='function')return null;
  return {attendu:attendu(p),liste:ROLES.map(role=>({role,salary:avec(p,role,()=>askingWage(p,kind)),refus:refus(p,role)}))};
 }
 // --- Temps de jeu : 10 derniers matchs du club ----------------------------------------------------------------------
 const semaineDe=s=>s?.worldMode?.week??s?.franceMode?.week??s?.round??0;
 const ligneValide=r=>Array.isArray(r)&&r.length===5&&entier(r[0])&&entier(r[1])&&entier(r[2])&&entier(r[3])&&r[3]>=0&&r[3]<=240&&(r[4]===0||r[4]===1);
 const suiviValide=t=>!!t&&typeof t==='object'&&Object.keys(t).every(k=>k==='club'||k==='m')&&entier(t.club)&&Array.isArray(t.m)&&t.m.length<=MATCHS&&t.m.every(ligneValide);
 // Reprise des notes de match de la saison (anciennes sauvegardes) : matchs du club à partir du 1er joué par le joueur.
 function reprise(p,s,exclure){
  const st=s?.matchNotes,detail=st?.detail;if(!detail||typeof detail!=='object')return [];
  const lignes=Array.isArray(detail[p.id])?detail[p.id].filter(r=>Array.isArray(r)&&entier(r[0])&&entier(r[1])):[];if(!lignes.length)return [];
  const c=clubDe(s),cles=new Map();
  for(const q of c?.players||[])for(const r of Array.isArray(detail[q.id])?detail[q.id]:[])if(Array.isArray(r)&&entier(r[0])&&entier(r[1])){const k=r[0]+':'+r[1];if(!cles.has(k))cles.set(k,[r[0],r[1]]);}
  if(exclure)cles.delete(exclure);
  const debut=Math.min(...lignes.map(r=>r[0]));
  const saison=entier(st.saison)?st.saison:s.season;
  return [...cles.values()].filter(([w])=>w>=debut).sort((a,b)=>a[0]-b[0]||a[1]-b[1]).slice(-MATCHS).map(([w,a])=>{
   const r=lignes.find(x=>x[0]===w&&x[1]===a);return [saison,w,a,Math.max(0,Math.min(240,Math.round(Number(r?.[3])||0))),0];});
 }
 function suivi(p,s,exclure){
  if(suiviValide(p.tempsJeu)&&p.tempsJeu.club===s.club)return p.tempsJeu;
  p.tempsJeu={club:s.club,m:reprise(p,s,exclure)};
  return p.tempsJeu;
 }
 // Après un match du club du manager (recordDevelopmentMatch) : une ligne par joueur sous contrat.
 function apresMatch(l,s=typeof S==='undefined'?null:S){
  if(!s||!l||!Array.isArray(l.pair)||!Array.isArray(l.sheets))return 0;
  const side=l.pair.indexOf(s.club);if(side<0)return 0;
  const feuille=l.sheets[side]||{},c=clubDe(s);if(!c)return 0;
  const semaine=semaineDe(s),adv=l.pair[1-side];if(!entier(semaine)||!entier(adv))return 0;
  let n=0;
  for(const p of c.players||[]){
   if(!sousContrat(p))continue;
   const t=suivi(p,s,semaine+':'+adv);
   const minutes=Math.max(0,Math.min(240,Math.round((feuille.minutes?.[p.id]||0)-(l.devBaseline?.[side]?.[p.id]||0))));
   const indispo=minutes===0&&(Number(p.injury)>0||Number(p.suspension)>0)?1:0;
   t.m.push([s.season,semaine,adv,minutes,indispo]);if(t.m.length>MATCHS)t.m.splice(0,t.m.length-MATCHS);
   n++;
  }
  return n;
 }
 // Vue de l'écran (squad[].tempsJeu) : rôle, seuil, matchs, mesure et humeur.
 function tempsJeu(p,s=typeof S==='undefined'?null:S){
  const r=vue(p,s);if(!r)return null;
  const t=suiviValide(p.tempsJeu)&&p.tempsJeu.club===s?.club?p.tempsJeu.m:reprise(p,s,null);
  const role=r.role,seuil=SEUILS[role],noms=s?.clubs||[];
  const nomClub=id=>(Array.isArray(noms)?noms.find(c=>c&&c.id===id)||noms[id]:noms[id])?.name||'';
  const pastilles=t.map(([saison,semaine,adv,minutes,indispo])=>({saison,semaine,adversaireId:adv,adversaire:nomClub(adv),minutes,
   etat:indispo?'absent':seuil.moyenne?(minutes>=seuil.moyenne?'tenu':'manque'):minutes>0?'tenu':'neutre'}));
  const comptes=t.filter(x=>!x[4]),juges=comptes.length;
  const joues=comptes.filter(x=>x[3]>0).length,total=comptes.reduce((n,x)=>n+x[3],0);
  const moyenne=juges?Math.round(total/juges):0,part=juges?joues/juges:0;
  const taux=seuil.moyenne?moyenne/seuil.moyenne:seuil.part?part/seuil.part:null;
  const humeur=taux===null||juges<JUGE_DES?'neutre':taux>=1?'content':taux>=ATTENTIF?'attentif':'mecontent';
  return {role,deduit:r.deduit,saison:r.saison,seuil:seuil.moyenne??null,part:seuil.part??null,juges,joues,moyenne,pastilles,humeur};
 }
 function validate(s){
  for(const c of Array.isArray(s?.clubs)?s.clubs:Object.values(s?.clubs||{}))for(const p of c?.players||[]){
   if(p&&p.roleContrat!==undefined&&!valide(p.roleContrat))throw Error('Rôle promis au contrat invalide.');
   if(p&&p.tempsJeu!==undefined&&!suiviValide(p.tempsJeu))throw Error('Temps de jeu au contrat invalide.');
  }
  return true;
 }
 let installe=false;
 function installHooks(){
  globalThis.roleContratJoueur=p=>vue(p);
  globalThis.roleContratPoser=(p,role,deduit)=>poser(p,role,deduit);
  globalThis.roleContratDeduire=p=>deduire(p,clubDe(typeof S==='undefined'?null:S)?.players);
  globalThis.roleContratRefus=(p,role)=>refus(p,role);
  globalThis.roleContratAvec=(p,role,fn)=>avec(p,role,fn);
  globalThis.roleContratRoles=(p,kind)=>roles(p,kind);
  globalThis.roleContratTempsJeu=p=>tempsJeu(p);
  if(installe)return true;installe=true;
  if(typeof askingWage==='function'){
   const ask=askingWage;
   askingWage=function(p,kind){return demande(ask.apply(this,arguments),p,kind);};
  }
  if(typeof recordDevelopmentMatch==='function'){
   const avant=recordDevelopmentMatch;
   recordDevelopmentMatch=function(l){const premier=!!l&&!l.developmentRecorded,r=avant.apply(this,arguments);if(premier&&l.developmentRecorded)apresMatch(l);return r;};
   Object.assign(recordDevelopmentMatch,avant);
  }
  return true;
 }
 return {project(){return null;},validate,execute(){throw Error('Aucune commande de rôle de contrat.');},installHooks,observe,deduire,poser,vue,aJour,ROLES,AGE_ESPOIR,
  RULES,attendu,facteur,refus,avec,demande,roles,apresMatch,tempsJeu,suivi,reprise};
}
module.exports={files,commands,factory};
