'use strict';
// Notes de match (demande de Léo, 13 novembre 2026 : « les notes de match doivent servir à
// quelque chose et être enregistrées »).
//
// Un seul calcul, `moteur().noter(journal, contexte)` : lecture pure du journal du moteur
// (aucun tirage, rien n'est écrit). Le direct l'appelle sur le journal montré (note en cours),
// la fin de match sur le journal complet (note enregistrée). Les matchs simulés sans direct
// (autres rencontres de la journée, match délégué) n'écrivent pas de scène dans `l.events` :
// le domaine ci-dessous leur tient un journal de faits transitoire, construit par la même
// fonction du moteur (`captureMatchAction`), sans tirage ni effet sur le match.
//
// Échelle 1–10 à une décimale, base 6,5 (remplaçant : 6,5 à l'entrée). Barème :
//  - faits individuels : course (mètres gagnés, franchissement à 22 m et plus), essai, ballon
//    récupéré, plaquage (course adverse stoppée : plaqueur déduit de la place défensive),
//    plaquage manqué (franchissement ou essai en jeu courant subi), réception, jeu au pied,
//    pénalité réussie ou manquée, conquête, carton ;
//  - collectif, au prorata des minutes : essai de l'équipe, écart au score, résultat ;
//  - influence : niveau au poste du joueur par rapport à son équipe du jour (± 0,35 au plus) ;
//  - poste occupé (maillots 1 à 15, 14 novembre 2026) : faits attendus du poste retirés, amplitude
//    propre au poste (POSTES_NOTE, étalonnés en carrière Monde).
// La somme est comprimée (tanh) autour de 6,5 : la plupart des notes entre 5,5 et 8, 9 et plus rares.
// Homme du match : la meilleure note (30 minutes au moins).

function moteur(){
 const NOTE_DEPART=6.5,NOTE_MIN=1,NOTE_MAX=10,COMPRESSION=3.2;
 // Place défensive de chaque poste (1 à 15) en largeur (0 à 70) : sert à désigner le plaqueur
 // d'une course adverse, que le moteur ne nomme pas (voir match-direct.cjs).
 const COULOIR_DEFENSE=[33,35,37,30,40,24,46,35,35,28,6,20,50,64,35];
 // `rang` (indice du fait) répartit les plaquages au contact entre les avants, sans tirage.
 function plaqueur(on,gain,y,rang){
  if(!Array.isArray(on)||!on.length)return null;
  let choisi=null,meilleur=Infinity;
  on.forEach((id,poste)=>{
   if(id==null||poste>14)return;
   const avant=poste<8,cible=Number.isFinite(y)?y:35;
   const tournant=Number.isInteger(rang)&&avant&&gain<12?((poste*7+rang)%6)*1.5:0;
   const ecart=Math.abs(COULOIR_DEFENSE[poste]-cible)+(gain<6?(avant?0:18):(avant?8:0))+(poste===5||poste===6?-2:0)+tournant;
   if(ecart<meilleur){meilleur=ecart;choisi=String(id)}
  });
  return choisi;
 }
 // Barème (étalonné sur des matchs simulés, docs/notes-de-match-20261113.md). `negatif` : poids d'un impact
 // négatif avant la compression (plancher relevé : moins de notes sous 5,5).
 const B={course:.03,metresPar:24,metresMax:1.5,franchissement:.6,essai:1.5,essaiEquipe:.05,essaiSubi:-.45,
  plaquage:.08,plaquageDomine:.05,plaquageManque:-.32,recuperation:.65,ballonPerdu:-.3,reception:.06,pied:.04,piedLong:.3,cinquante22:.5,
  but:.4,butManque:-.3,toucheGagnee:.045,meleeGagnee:.06,toucheVolee:.1,meleeVolee:.12,touchePerdue:-.09,meleePerdue:-.1,volee:.35,
  jaune:-1.4,rouge:-2.8,penalite:-.32,enAvant:-.45,ecartMax:.45,resultat:.2,echelle:1.08,negatif:.8,poste:.25};
 // Pondération par poste (maillots 1 à 15, poste occupé sur le terrain), étalonnée en carrière
 // Monde (docs/homme-du-match-postes-20261114.md) : [faits attendus sur 80 minutes, dispersion].
 // Les postes n'ont pas les mêmes occasions de faits dans le journal (un troisième ligne plaque
 // et court bien plus qu'un pilier) : on retire l'attendu du poste (moyennes par poste proches),
 // puis la dispersion du poste fixe l'amplitude des notes (un ouvreur fait plus souvent le match,
 // ou le rate, qu'un pilier). L'homme du match est la meilleure note : la répartition par poste
 // vient de ces seules pondérations (aucun tirage, aucun quota).
 // Essais réalistes (docs/essais-realistes-20261114.md) : attendus et amplitudes ré-étalonnés avec
 // scripts/etalonner-notes-postes.cjs (441 matchs après l'apport des stats de #709 ; 795 avant, mêmes conditions que docs/homme-du-match-postes-20261114.md).
 const POSTES_NOTE=[[0.48,1.09],[0.17,0.92],[0.26,1.01],[1.53,0.97],[1.83,1.1],[2.48,1.02],[2.57,0.99],[2.51,1.07],[0.47,1.14],[1.55,1.33],[1.44,0.86],[0.82,0.98],[0.86,0.85],[1.27,0.92],[0.34,1.02]];
 // Repli quand seul le poste naturel du joueur est connu (FAMILIES : 0 pilier, 1 talonneur,
 // 2 deuxième ligne, 3 troisième ligne, 4 demi de mêlée, 5 ouvreur, 6 ailier, 7 centre, 8 arrière).
 const MAILLOTS_FAMILLE=[[0,2],[1],[3,4],[5,6,7],[8],[9],[10,13],[11,12],[14]];
 const POSTE=MAILLOTS_FAMILLE.map(m=>[0,1].map(k=>m.reduce((a,i)=>a+POSTES_NOTE[i][k],0)/m.length));
 const arrondi=n=>Math.round(n*10)/10;
 const borne=(n,a,b)=>Math.max(a,Math.min(b,n));
 // Note affichée d'un total brut (impact) : compression douce autour de la base.
 function echelle(brut){if(brut<0)brut*=B.negatif;return arrondi(borne(NOTE_DEPART+COMPRESSION*Math.tanh(brut/COMPRESSION),NOTE_MIN,NOTE_MAX));}
 // journal : [{min,type,scene}] (l.events du direct, ou journal transitoire d'un match simulé).
 // contexte : {minutes:{id:minutes jouées}, cotes:{id:0|1}, niveaux:{id:-1..1}, score:[a,b],
 //             duree, fini, camp (0|1 : seulement cette équipe ; sinon les deux)}.
 // ---- Feuille de statistiques (match-stats.cjs, 14 novembre 2026 : « les stats d'un joueur ne
 // ressemblent pas à de vraies stats ») ----------------------------------------------------------
 // Les chiffres comptés du journal (une trentaine de courses racontées par match : 0 à 3 plaquages
 // pour un ailier) sont remplacés par ceux de la feuille réaliste, la même que l'écran de match :
 // mêmes essais (mêmes marqueurs, issus du journal), plaquages, mètres, passes… L'apport de la feuille
 // (`apports`, match-stats.apportsNote : écart au rendement attendu du poste dans ce match, somme
 // nulle par équipe, borné) s'ajoute à l'impact brut : la note suit la ligne de stats sans déplacer
 // la base 6,5 ni l'étalonnage par poste.
 const DE_LA_FEUILLE={essais:'essais',plaquages:'plaquages',manques:'plaquagesManques',metres:'metres',courses:'courses',franchissements:'franchissements',recuperations:'recuperations',pertes:'ballonsPerdus',penalites:'penalitesConcedees'};
 const EN_PLUS=['passes','offloads','defenseursBattus','points','soutiensRuck','coupsDePied'];
 function feuilleDansNotes(joueurs,feuille,apports){
  for(const [id,n] of Object.entries(joueurs)){
   const f=feuille.joueurs[id];
   for(const [k,c] of Object.entries(DE_LA_FEUILLE))n[k]=f?f[c]|0:0;
   for(const c of EN_PLUS)n[c]=f?f[c]|0:0;
   const a=apports?.[id];if(Number.isFinite(a))n.brut+=a;
  }
 }
 function noter(journal,contexte={}){
  const cotes=contexte.cotes||{},minutes=contexte.minutes||{},niveaux=contexte.niveaux||{};
  const camp=contexte.camp===0||contexte.camp===1?contexte.camp:null;
  const joueurs={};
  const fiche=(id,cote)=>joueurs[id]||(joueurs[id]={cote,brut:0,faits:0,essais:0,metres:0,plaquages:0,manques:0,courses:0,franchissements:0,recuperations:0,pertes:0,penalites:0,buts:0,cartons:0,minutes:0,note:NOTE_DEPART});
  for(const [id,cote] of Object.entries(cotes))if(cote===0||cote===1)fiche(String(id),cote);
  const surLeTerrain=(s,c)=>Array.isArray(s?.on?.[c])?s.on[c].filter(x=>x!=null).map(String):[];
  // Joueur nommé par un fait : son équipe est celle de la feuille, sinon celle du terrain.
  let sceneCourante=null;
  const ajoute=(id,valeur,fait)=>{
   if(id==null)return null;id=String(id);
   if(!joueurs[id]){const c=[0,1].find(c=>surLeTerrain(sceneCourante,c).includes(id));if(c===undefined)return null;fiche(id,c);}
   const n=joueurs[id];n.brut+=valeur;n.faits++;if(fait)n[fait]++;return n;
  };
  let score=[0,0],dernierScore=null;const porteur=[null,null],buteurPied=[null,null];
  for(let i=0;i<(journal||[]).length;i++){
   const e=journal[i]||{},s=e.scene;if(!s||typeof s!=='object')continue;
   if(Array.isArray(s.score)&&s.score.length===2)dernierScore=[s.score[0],s.score[1]];
   const equipe=s.team===0||s.team===1?s.team:null,kind=s.kind;
   sceneCourante=s;
   const tx=Number.isFinite(s.to?.x)?s.to.x:null,fx=Number.isFinite(s.from?.x)?s.from.x:tx;
   const gain=fx!==null&&tx!==null?Math.abs(tx-fx):0;
   if(kind==='carry'&&equipe!==null){
    // Course stoppée (moins de 22 m) : plaquage réussi ; franchissement : plaquage manqué
    // (même règle que les chiffres d'équipe de l'entracte). Plaqueur nommé par le moteur (fait
    // `tackler`, le même que la 3D), sinon déduit de la place défensive (anciens journaux).
    if(tx!==null){const def=(s.on?.[1-equipe]||[]).map(String),nomme=s.tackler!=null&&def.includes(String(s.tackler))?String(s.tackler):null;const tacle=nomme??plaqueur(s.on?.[1-equipe],gain,s.to?.y,i);if(gain<22)ajoute(tacle,B.plaquage+(gain<2?B.plaquageDomine:0),'plaquages');else ajoute(tacle,B.plaquageManque,'manques');}
    const n=ajoute(s.actor,B.course+Math.min(B.metresMax,gain/B.metresPar)+(gain>=22?B.franchissement:0),'courses');
    if(n){n.metres+=gain;if(gain>=22)n.franchissements++;}
    if(s.actor!=null)porteur[equipe]=String(s.actor);
    continue;
   }
   if(kind==='try'&&equipe!==null){
    ajoute(s.actor,B.essai,'essais');
    for(const id of surLeTerrain(s,equipe))if(joueurs[id])joueurs[id].brut+=B.essaiEquipe;
    if(s.origin==='open')ajoute(plaqueur(s.on?.[1-equipe],30,s.to?.y),B.essaiSubi,'manques');
    continue;
   }
   if(kind==='turnover'){ajoute(s.actor,B.recuperation,'recuperations');const n=joueurs[String(s.actor)];if(n&&(equipe===null||n.cote===equipe))n.plaquages++;
    // Ballon perdu : le dernier porteur de l'équipe qui le perd.
    if(equipe!==null&&porteur[1-equipe])ajoute(porteur[1-equipe],B.ballonPerdu,'pertes');continue;}
   if(kind==='reception'){ajoute(s.actor,B.reception);continue;}
   if(kind==='kick'){ajoute(s.actor,B.pied+(gain>=30?B.piedLong:0));if(equipe!==null&&s.actor!=null)buteurPied[equipe]=String(s.actor);continue;}
   if(kind==='touch'&&s.cause==='50-22'&&equipe!==null){ajoute(s.actor??buteurPied[equipe],B.cinquante22);continue;}
   if(kind==='kickoff'||kind==='drop22'||kind==='goalLine'){ajoute(s.actor,.02);continue;}
   if(kind==='goal'){ajoute(s.actor,B.but,'buts');continue;}
   if(kind==='miss'){if(s.actor!=null)ajoute(s.actor,B.butManque);continue;}
   // Conquête : la touche (départ au bord, y ≤ 4) crédite talonneur et sauteurs, la mêlée la
   // première ligne et les deuxième ligne ; un ballon perdu pèse sur les mêmes postes adverses.
   if((kind==='setpiece-win'||kind==='setpiece-loss')&&equipe!==null){
    const touche=Number.isFinite(s.from?.y)&&s.from.y<=4,postes=touche?{1:1,3:1,4:1}:{0:1,1:1,2:1,3:.4,4:.4};
    const credit=(c,valeur)=>(s.on?.[c]||[]).forEach((id,poste)=>{if(id!=null&&postes[poste]){const n=joueurs[String(id)];if(n)n.brut+=valeur*postes[poste];}});
    if(kind==='setpiece-win'){credit(equipe,touche?B.toucheGagnee:B.meleeGagnee);ajoute(s.actor,.03);}
    else{credit(equipe,touche?B.toucheVolee:B.meleeVolee);credit(1-equipe,touche?B.touchePerdue:B.meleePerdue);ajoute(s.actor,B.volee);}
    continue;
   }
   if(kind==='card'&&s.incident){ajoute(s.actor,s.card==='red'||s.card==='red20'||s.cause==='red'?B.rouge:B.jaune,'cartons');continue;}
   // Pénalité concédée : fautif déduit de la place défensive (au contact, sans tirage), petit
   // poids collectif pour les avants ; faute de main : le dernier porteur, poids collectif léger.
   if(kind==='penalty'&&equipe!==null){
    const def=s.on?.[1-equipe],cause=s.cause;
    // Cause connue (pénalités réalistes, 14 novembre 2026) : mêlée = première ligne (1-2-3, en
    // alternance sans tirage) ; ballon non libéré / scellement = dernier porteur de l'équipe fautive ;
    // touche ou ballon porté = avant du lancer (talonneur, deuxième et troisième ligne). Jeu courant :
    // plaqueur déduit de la place défensive, comme avant.
    const parmi=(postes)=>{const ids=postes.map(p=>def?.[p]).filter(id=>id!=null);return ids.length?String(ids[i%ids.length]):null;};
    const fautif=Array.isArray(def)&&cause==='scrum'?parmi([0,1,2])
     :(cause==='not-release'||cause==='sealing')?(porteur[1-equipe]??plaqueur(def,3,s.to?.y,i))
     :Array.isArray(def)&&cause==='maul'?parmi([1,3,4,5,6,7])
     :plaqueur(def,3,s.to?.y,i);
    ajoute(fautif,B.penalite,'penalites');
    for(const id of surLeTerrain(s,1-equipe))if(joueurs[id])joueurs[id].brut-=(s.on?.[1-equipe]?.indexOf(id)??9)<8?.02:.008;
    continue;
   }
   if(kind==='hand-fault'&&equipe!==null){if(porteur[equipe])ajoute(porteur[equipe],B.enAvant,'pertes');for(const id of surLeTerrain(s,equipe))if(joueurs[id])joueurs[id].brut-=.01;continue;}
  }
  // Feuille de statistiques réaliste (match-stats.cjs, 14 novembre 2026) : une seule source pour les
  // chiffres du joueur (ceux de l'écran de match) et son apport à la note (voir feuilleDansNotes).
  if(contexte.feuille?.joueurs)feuilleDansNotes(joueurs,contexte.feuille,contexte.apports);
  if(Array.isArray(contexte.score)&&contexte.score.length===2)score=contexte.score;else if(dernierScore)score=dernierScore;
  const duree=Math.max(1,Number.isFinite(contexte.duree)?contexte.duree:80);
  const familles=contexte.familles||{},postes=contexte.postes||{};
  for(const [id,n] of Object.entries(joueurs)){
   const m=Number.isFinite(minutes[id])?Math.max(0,minutes[id]):0;n.minutes=Math.round(m);
   const part=Math.min(1,m/Math.max(80,duree));
   const ecart=(score[n.cote]||0)-(score[1-n.cote]||0);
   // Collectif : écart au score (borné) et résultat, une fois le match fini.
   const collectif=borne(ecart/32,-B.ecartMax,B.ecartMax)+(contexte.fini?(ecart>0?B.resultat:ecart<0?-B.resultat:0):0);
   const niveau=Number.isFinite(niveaux[id])?borne(niveaux[id],-1,1)*.35:0;
   // Poste occupé (maillot 1 à 15), sinon poste naturel (famille) : attendu retiré, dispersion
   // du poste, constante commune (B.poste) qui garde la moyenne générale. Journal réduit
   // (matchs internationaux, essais seuls) : aucune pondération (voir la doc).
   const mt=contexte.journalReduit?null:postes[id],f=contexte.journalReduit?null:familles[id];
   const p=Number.isInteger(mt)&&POSTES_NOTE[mt]?POSTES_NOTE[mt]:Number.isInteger(f)&&POSTE[f]?POSTE[f]:null;
   n.impact=p?p[1]*(B.echelle*n.brut-p[0]*part)+(B.poste+collectif+niveau)*part:B.echelle*n.brut+(collectif+niveau)*part;
   n.poste=Number.isInteger(mt)&&POSTES_NOTE[mt]?mt:null;
   n.note=echelle(n.impact);
   n.metres=Math.round(n.metres);
  }
  // Homme du match (fin de match), au moins 30 minutes : la meilleure note (déjà pondérée par
  // poste) ; à égalité, l'impact avant arrondi, le vainqueur, le plus de faits, l'identifiant.
  let hommeDuMatch=null;
  const candidats=Object.entries(joueurs).filter(([,n])=>n.minutes>=30);
  candidats.sort(([a,x],[b,y])=>y.note-x.note||y.impact-x.impact||((score[y.cote]-score[1-y.cote])-(score[x.cote]-score[1-x.cote]))||y.faits-x.faits||(a<b?-1:a>b?1:0));
  if(candidats.length)hommeDuMatch=candidats[0][0];
  if(camp!==null)for(const id of Object.keys(joueurs))if(joueurs[id].cote!==camp)delete joueurs[id];
  for(const n of Object.values(joueurs)){delete n.brut;delete n.impact;delete n.poste;}
  return {joueurs,hommeDuMatch,score:score.slice()};
 }
 return {NOTE_DEPART,noter,plaqueur,echelle,B,POSTE,POSTES_NOTE,MAILLOTS_FAMILLE};
}

// ---- Domaine natif (installé dans la VM du moteur, voir native-systems.cjs) ----------------
// État `S.matchNotes` (version 2 ; la version 1 est migrée au premier usage) :
//  saison  : saison en cours ;
//  joueurs : {id:{s:[matchs, somme des notes ×10, minutes, essais, plaquages, mètres, hommes du match,
//            passes, franchissements, plaquages manqués, points], f:[5 dernières notes ×10]}} (7 totaux avant le 14/11/2026)
//            pour chaque joueur ayant joué (tous les clubs) ;
//  detail  : {id:[[semaine, adversaire, compétition, minutes, note×10, essais, plaquages, mètres, homme du match (0/1),
//            courses, passes, franchissements, plaquages manqués, défenseurs battus, offloads, ballons récupérés,
//            ballons perdus, points, pénalités concédées], …]} (9 champs avant le 14/11/2026)
//            détail de la saison en cours pour les joueurs du club du manager ;
//  passees : {id:[[saison, club, matchs, moyenne×10, essais, hommes du match, plaquages, mètres], …]} 8 saisons au plus ;
//  confiance : {id:effet cumulé de la saison sur la satisfaction (borné ±6)} ;
//  semaine : {cle, comp, notes:[[id, club, note×10, poste, comp, minutes, essais, championnat]], matchs:[[championnat, clubA, clubB, scoreA, scoreB]]}
//            rencontres de la journée (transitoire : vidé quand l'équipe-type est publiée) ;
//  reg     : {championnat:{id:[matchs, somme des notes ×10, minutes, essais, sélections en équipe-type, groupe de poste, club]}}
//            saison régulière seulement (version 2) ; regJ : {championnat: journées jouées} ;
//  equipes : {championnat:{saison, journee, ids[15], notes[15], clubs[15], etoile, coach:{club,nom,marge}}} dernière équipe-type de chaque championnat ;
//  saisons : équipes de la saison (6 saisons au plus) {saison, ligue, ids, moy×10, matchs, sel, clubs} ;
//  recompenses : 40 dernières distinctions [{saison, semaine, type, id, nom, club, note×10}] ;
//  dernier : homme du match et notes du dernier match du manager.
// Anciennes sauvegardes : `S.matchNotes` absent = historique vide, créé au premier match.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 // Statistiques enregistrées (14 novembre 2026) : celles de la feuille réaliste (match-stats.cjs).
 // Totaux de saison (tous les joueurs du monde, ~4 000) : 4 champs de plus, stockés en entiers dans le
 // même tableau ; détail (effectif du manager seulement) : 10 champs de plus par match. Les anciennes
 // lignes (7 totaux, détail à 9 champs, saison passée à 6) restent valides et s'affichent « — ».
 const TOTAUX=11,DETAIL_EN_PLUS=['courses','passes','franchissements','manques','defenseursBattus','offloads','recuperations','pertes','points','penalites'];
 const VERSION=2,MAX_DETAIL=60,MAX_PASSEES=8,MAX_RECOMPENSES=40,CONFIANCE_MAX=6,MAX_SAISONS=40,MAX_SEMAINE=4000;
 const calc=CDMatchNotesMoteur;
 const state=()=>typeof S==='undefined'?null:S;
 const obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const check=(ok,message)=>{if(!ok)throw Error('Notes de match : '+message+'.');};
 const semaine=s=>s.worldMode?.week??s.franceMode?.week??s.round??0;
 const vide=s=>({version:VERSION,saison:s.season,joueurs:{},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null,reg:{},regJ:{},equipes:{},saisons:[]});
 // Migration v1 → v2 : les nouveaux champs sont vides (rien n'est inventé pour le passé).
 function migrer(st){if(st&&st.version===1){st.reg={};st.regJ={};st.equipes={};st.saisons=[];st.version=VERSION;}return st;}
 function etat(s){if(!s.matchNotes)s.matchNotes=vide(s);migrer(s.matchNotes);if(s.matchNotes.saison!==s.season)rollover(s);return s.matchNotes;}
 // Fin de saison : résumé par joueur, détail effacé ; on ne garde que les joueurs encore en jeu.
 function rollover(s){
  const st=migrer(s.matchNotes);if(!st||st.saison===s.season)return;
  const clubDe=new Map();for(const c of s.clubs)for(const p of c.players)clubDe.set(p.id,c.id);
  for(const [id,j] of Object.entries(st.joueurs)){
   if(j.s[0]>0){(st.passees[id]||(st.passees[id]=[])).push([st.saison,clubDe.get(id)??-1,j.s[0],Math.round(j.s[1]/j.s[0]),j.s[3],j.s[6],j.s[4],j.s[5]]);}
   j.s=Array(TOTAUX).fill(0);
  }
  for(const id of Object.keys(st.passees)){if(!clubDe.has(id))delete st.passees[id];else st.passees[id]=st.passees[id].slice(-MAX_PASSEES);}
  for(const id of Object.keys(st.joueurs))if(!clubDe.has(id))delete st.joueurs[id];
  if(st.selection)for(const id of Object.keys(st.selection.lignes))if(!clubDe.has(id))delete st.selection.lignes[id];
  st.detail={};st.confiance={};st.semaine=null;st.reg={};st.regJ={};st.equipes={};st.saison=s.season;
 }
 // Contexte d'un match pour le calcul : minutes, côtés, niveau au poste relatif à l'équipe.
 function contexte(l){
  const cotes={},minutes={},niveaux={},noms={},familles={},postes={};
  for(let side=0;side<2;side++){
   const sh=l.sheets?.[side];if(!sh)continue;
   // Poste occupé : maillot de départ, puis celui du joueur remplacé (remplacements dans l'ordre),
   // sinon la place actuelle sur le terrain.
   (sh.initial||[]).forEach((id,i)=>{if(id!=null&&i<15&&postes[id]===undefined)postes[id]=i;});
   for(const r of l.subs||[])if(r&&r.side===side&&r.in!=null&&postes[r.in]===undefined&&postes[r.out]!==undefined)postes[r.in]=postes[r.out];
   (sh.on||[]).forEach((id,i)=>{if(id!=null&&i<15&&postes[id]===undefined)postes[id]=i;});
   const ids=[...new Set([...(sh.used||[]),...(sh.on||[]).filter(Boolean)])];
   const notes=[];
   for(const id of ids){const p=typeof matchPlayer==='function'?matchPlayer(l,side,id):null;cotes[id]=side;minutes[id]=Number(sh.minutes?.[id])||0;if(p){const r=roleNote(p);notes.push([id,r]);noms[id]=p.name;if(Number.isInteger(p.fam))familles[id]=p.fam;}}
   const moyenne=notes.length?notes.reduce((n,[,r])=>n+r,0)/notes.length:0;
   for(const [id,r] of notes)niveaux[id]=Math.max(-1,Math.min(1,(r-moyenne)/10));
  }
  for(const id of Object.keys(postes))if(cotes[id]===undefined)delete postes[id];
  return {cotes,minutes,niveaux,noms,familles,postes,score:l.score.slice(),duree:l.minute,fini:!!l.finished};
 }
 const journalDe=l=>l.userSide>=0?l.events:(l.notesJournal||[]);
 function noterMatch(l){const f=feuilleDe(l);return calc.noter(journalDe(l),f?{...contexte(l),feuille:f,apports:CDMatchStats.apportsNote(f)}:contexte(l));}
 // Feuille de statistiques réaliste du match (match-stats.cjs), calculée comme celle de l'écran de
 // match (match-direct.cjs) : même clé de rencontre (nativeMatchDirect.etat().rencontre), mêmes
 // attributs (worker.cjs, matchDirectReader.attributs), même journal. Matchs simulés : leur journal
 // de faits transitoire. Sans le module (VM de test minimale) : null, chiffres du journal.
 function feuilleDe(l){
  if(typeof CDMatchStats==='undefined'||!l?.pair)return null;
  const s=state(),joueurs={};
  // Attributs lus à la demande (getters) : seuls les joueurs qui agissent dans le journal en ont besoin, même valeur que la lecture directe.
  (l.sheets||[]).forEach((sh,side)=>{for(const id of new Set([...(sh.on||[]),...(sh.bench||[]),...(sh.used||[])])){if(id==null)continue;if(typeof matchPlayer!=='function')continue;let v;Object.defineProperty(joueurs,id,{enumerable:true,configurable:true,get(){if(v===undefined){const p=matchPlayer(l,side,id);v=p&&p.skills?{skills:p.skills}:null;}return v||undefined;}});}});
  try{return CDMatchStats.feuilleStatistiques(journalDe(l),{cle:[s?.season,s?.round,s?.phase,l.pair.join('-')].join(':'),joueurs});}catch(e){return null;}
 }
 // Forme récente (5 dernières notes) et moyenne de saison d'un joueur, sans écrire.
 function forme(id){const j=state()?.matchNotes?.joueurs?.[id];return j&&j.f.length?j.f.reduce((n,x)=>n+x,0)/j.f.length/10:null;}
 function formeN(id){return state()?.matchNotes?.joueurs?.[id]?.f.length||0;}
 function moyenne(id){
  const s=state(),st=s?.matchNotes,j=st?.joueurs?.[id];
  if(j&&j.s[0]>=5)return j.s[1]/j.s[0]/10;
  // Début de saison : la saison passée (si 10 matchs ou plus) prend le relais.
  const p=st?.passees?.[id]?.at(-1);if(p&&p[2]>=10&&(!j||j.s[0]<5))return p[3]/10;
  return null;
 }
 // Effets bornés (voir docs/notes-de-match-20261113.md). `CDNotesEffets === false` (CD_NOTES_EFFETS=0
 // dans le worker) les coupe tous : notes calculées et enregistrées, sans conséquence (mesure d'équilibre).
 // Lauréat de l'équipe de la saison de l'an dernier ou de la saison en cours : 1, sinon 0 (petit bonus, voir effets).
 function laureat(id){const st=state()?.matchNotes,s=state();return st?.saisons?.some(x=>x.saison>=s.season-1&&x.ids.includes(id))?1:0;}
 const actifs=()=>typeof CDNotesEffets==='undefined'||CDNotesEffets!==false;
 const effets={
  // Composition des entraîneurs IA : forme récente (2 notes au moins), ±3 à 4 % du score de choix.
  composition(id){if(!actifs())return 1;const f=forme(id);return f===null||formeN(id)<2?1:1+Math.max(-.03,Math.min(.04,(f-6.5)*.03));},
  // Valeur marchande (indemnité) : moyenne de saison (et, à 25 %, moyenne internationale sur
  // 3 sélections au moins), −8 % à +12 % ; +3 % pour un lauréat de l'équipe de la saison (mêmes bornes).
  valeur(id){if(!actifs())return 1;const m=melange(moyenne(id),intl(id,10),.25),d=laureat(id)*.03;return m===null&&!d?1:1+Math.max(-.08,Math.min(.12,(m===null?0:(m-6.5)*.08)+d));},
  // Intérêt des clubs IA : note estimée du joueur, −2 à +3 points.
  interet(id){if(!actifs())return 0;const m=moyenne(id),d=laureat(id)*.5;return m===null&&!d?0:Math.max(-2,Math.min(3,(m===null?0:(m-6.5)*2)+d));},
  // Exigence salariale en négociation : −4 % à +6 %.
  salaire(id){if(!actifs())return 1;const m=moyenne(id);return m===null?1:1+Math.max(-.04,Math.min(.06,(m-6.5)*.04));},
  // Sélections nationales : bonus au score de forme du sélectionneur, −1,5 à +2 points.
  // Forme en club (3 notes au moins) et forme internationale (5 dernières sélections, 3 au
  // moins) : moyenne pondérée, la sélection compte pour 40 % quand les deux existent.
  selection(id){if(!actifs())return 0;const f=melange(formeN(id)>=3?forme(id):null,intl(id,5),.4);return f===null?0:Math.max(-1.5,Math.min(2,(f-6.5)*1.2));}
 };
 // Moyenne des n dernières notes internationales (3 sélections au moins), sinon null.
 function intl(id,n){const d=state()?.matchNotes?.selection?.lignes?.[id];if(!d||d.length<3)return null;const r=d.slice(-n);return r.reduce((a,x)=>a+x[4],0)/r.length/10;}
 function melange(club,inter,poids){return club===null?inter:inter===null?club:club*(1-poids)+inter*poids;}
 // ---- Matchs internationaux -----------------------------------------------------------
 // Le moteur international simule le score seul (essais et points, sans journal) : le même
 // calcul reçoit un journal réduit à ces faits — chaque essai attribué de façon déterministe
 // (empreinte de la rencontre, arrières et troisième ligne favorisés) —, le résultat, le
 // niveau au poste et le poste. Titulaires 80 minutes, remplaçants entrés 25 minutes.
 // matchs : [{cle, date, competition, equipes:[{nation, nom, ids, points, essais}] ×2}].
 const MAX_SELECTION=10,MAX_VUS=400;
 const empreinte=t=>{let h=2166136261;for(let i=0;i<t.length;i++)h=Math.imul(h^t.charCodeAt(i),16777619);return h>>>0;};
 function enregistrerSelection(matchs){
  const s=state();if(!s||!Array.isArray(matchs)||!matchs.length)return 0;
  if(typeof CDNotesAbsentes!=='undefined'&&CDNotesAbsentes===true)return 0;
  const st=etat(s),sel=st.selection||(st.selection={lignes:{},vus:{}});
  const joueurs=new Map();for(const c of s.clubs)for(const p of c.players)joueurs.set(p.id,p);
  let n=0;
  for(const m of matchs){
   if(!m||typeof m.cle!=='string'||sel.vus[m.cle]||!Array.isArray(m.equipes)||m.equipes.length!==2)continue;
   const cotes={},minutes={},niveaux={},journal=[],on=m.equipes.map(e=>e.ids.slice(0,15));
   m.equipes.forEach((e,side)=>{
    const notes=[];
    e.ids.forEach((id,k)=>{cotes[id]=side;minutes[id]=k<15?80:25;const p=joueurs.get(id);if(p){notes.push([id,roleNote(p)]);}});
    const moy=notes.length?notes.reduce((a,[,r])=>a+r,0)/notes.length:0;for(const [id,r] of notes)niveaux[id]=Math.max(-1,Math.min(1,(r-moy)/10));
    const poids=on[side].map((id,slot)=>id==null?0:slot>=8?3:slot>=5?2:1),total=poids.reduce((a,b)=>a+b,0);
    for(let k=0;k<(e.essais|0)&&total>0;k++){let x=empreinte(m.cle+'|'+e.nation+'|'+k)%total,slot=0;while(x>=poids[slot]){x-=poids[slot];slot++;}
     journal.push({min:0,type:'try',scene:{kind:'try',team:side,actor:on[side][slot],on,score:[0,0]}});}
   });
   const r=calc.noter(journal,{cotes,minutes,niveaux,journalReduit:true,score:[m.equipes[0].points|0,m.equipes[1].points|0],fini:true});
   m.equipes.forEach((e,side)=>{
    const adverse=String(m.equipes[1-side].nom||m.equipes[1-side].nation).slice(0,60);
    for(const id of e.ids){
     const x=r.joueurs[id];if(!x||!joueurs.has(id))continue;
     const d=sel.lignes[id]||(sel.lignes[id]=[]);
     d.push([String(m.date).slice(0,10),adverse,String(m.competition||'').slice(0,60),x.minutes,Math.round(x.note*10),x.essais,r.hommeDuMatch===id?1:0]);
     if(d.length>MAX_SELECTION)d.shift();
    }
   });
   sel.vus[m.cle]=String(m.date).slice(0,10);n++;
  }
  const cles=Object.keys(sel.vus);if(cles.length>MAX_VUS){cles.sort((a,b)=>sel.vus[a]<sel.vus[b]?-1:sel.vus[a]>sel.vus[b]?1:a<b?-1:1);for(const k of cles.slice(0,cles.length-MAX_VUS))delete sel.vus[k];}
  return n;
 }
 function clubIdDe(l,side){return l.pair[side];}
 function competition(l){const c=l.worldContext||l.franceContext;return String(c?.competitionId||c?.competition||c?.phase||state()?.phase||'championnat').slice(0,40);}
 function enregistrer(l){
  const s=state();if(!s||!l?.finished||l.matchNotesRecorded)return null;
  l.matchNotesRecorded=true;
  const st=etat(s),r=noterMatch(l),w=semaine(s),comp=competition(l),user=l.pair.indexOf(s.club);
  // Nouvelle journée : la précédente est d'abord close (carrières sans `finishRound`, calendrier quotidien).
  const cle=s.season+':'+w;
  if(st.semaine?.cle!==cle){if(st.semaine&&!st.semaine.annoncee){try{finJournee();}catch(e){}}st.semaine={cle,comp:null,notes:[],matchs:[]};}
  if(!Array.isArray(st.semaine.matchs))st.semaine.matchs=[];
  // Saison régulière d'un championnat : les deux clubs en sont membres (équipe-type, équipe de la saison).
  const lg=regulier(s,l)?ligueDe(s,l.pair[0]):null,ligue=lg&&ligueDe(s,l.pair[1])===lg?lg:null;
  const reg=ligue?(st.reg[ligue]||(st.reg[ligue]={})):null;
  for(const [id,n] of Object.entries(r.joueurs)){
   if(n.minutes<=0)continue;
   const note10=Math.round(n.note*10),hdm=r.hommeDuMatch===id?1:0;
   const j=st.joueurs[id]||(st.joueurs[id]={s:Array(TOTAUX).fill(0),f:[]});
   while(j.s.length<TOTAUX)j.s.push(0); // ancienne sauvegarde : 7 totaux, complétés à zéro
   j.s[0]++;j.s[1]+=note10;j.s[2]+=n.minutes;j.s[3]+=n.essais;j.s[4]+=n.plaquages;j.s[5]+=n.metres;j.s[6]+=hdm;
   j.s[7]+=n.passes|0;j.s[8]+=n.franchissements|0;j.s[9]+=n.manques|0;j.s[10]+=n.points|0;
   j.f.push(note10);if(j.f.length>5)j.f.shift();
   if(n.cote===user){const d=st.detail[id]||(st.detail[id]=[]);d.push([w,clubIdDe(l,1-n.cote),comp,n.minutes,note10,n.essais,n.plaquages,n.metres,hdm,...DETAIL_EN_PLUS.map(k=>n[k]|0)]);if(d.length>MAX_DETAIL)d.shift();}
   if(reg){
    const g=groupeDe(matchPlayer(l,n.cote,id)?.pos),e=reg[id]||(reg[id]=[0,0,0,0,0,g<0?0:g,clubIdDe(l,n.cote)]);
    e[0]++;e[1]+=note10;e[2]+=n.minutes;e[3]+=n.essais;if(g>=0)e[5]=g;e[6]=clubIdDe(l,n.cote);
   }
  }
  // Rencontres de la journée (équipe type) : on ne garde que la semaine en cours.
  for(const [id,n] of Object.entries(r.joueurs)){
   if(n.minutes<40)continue;
   const c=clubIdDe(l,n.cote),p=matchPlayer(l,n.cote,id);
   st.semaine.notes.push([id,c,Math.round(n.note*10),p?.pos||'',comp,n.minutes,n.essais,ligue||'']);
  }
  if(ligue)st.semaine.matchs.push([ligue,l.pair[0],l.pair[1],l.score[0],l.score[1]]);
  if(st.semaine.notes.length>MAX_SEMAINE)st.semaine.notes=st.semaine.notes.slice(-MAX_SEMAINE);
  if(user>=0){
   st.semaine.comp=comp;
   const h=r.hommeDuMatch,side=h!=null?r.joueurs[h].cote:-1,hp=h!=null?matchPlayer(l,side,h):null;
   st.dernier={saison:s.season,semaine:w,pair:l.pair.slice(),score:l.score.slice(),comp,hommeDuMatch:hp?{id:h,nom:hp.name,club:l.pair[side],note:r.joueurs[h].note,essais:r.joueurs[h].essais,plaquages:r.joueurs[h].plaquages,metres:r.joueurs[h].metres}:null,
    notes:Object.entries(r.joueurs).filter(([,n])=>n.minutes>0).map(([id,n])=>({id,cote:n.cote,note:n.note,minutes:n.minutes,essais:n.essais,plaquages:n.plaquages,metres:n.metres}))};
   if(hp){distinction(s,'hdm',h,hp.name,l.pair[side],Math.round(r.joueurs[h].note*10));if(typeof news==='function')news('Homme du match : '+hp.name+' ('+String(r.joueurs[h].note).replace('.',',')+'), '+(s.clubs[l.pair[side]]?.name||'')+'.');}
   moral(s,l,r,user);
  }
  return r;
 }
 function distinction(s,type,id,nom,club,note10){
  const st=s.matchNotes;st.recompenses.push({saison:s.season,semaine:semaine(s),type,id,nom:String(nom).slice(0,120),club,note:note10});
  if(st.recompenses.length>MAX_RECOMPENSES)st.recompenses=st.recompenses.slice(-MAX_RECOMPENSES);
 }
 // Moral : la satisfaction du joueur suit sa série (3 dernières notes) : ±1 par match, ±6 par saison.
 function moral(s,l,r,user){
  if(!actifs()||s.satisfactionVersion!==1||typeof ensureSatisfaction!=='function')return;
  const st=s.matchNotes;
  for(const [id,n] of Object.entries(r.joueurs)){
   if(n.cote!==user||n.minutes<=0)continue;
   const j=st.joueurs[id];if(!j||j.f.length<3)continue;
   const serie=j.f.slice(-3).reduce((a,b)=>a+b,0)/30,delta=serie>=7.2?1:serie<=5.8?-1:0;if(!delta)continue;
   const cumul=st.confiance[id]||0;if(Math.abs(cumul+delta)>CONFIANCE_MAX)continue;
   const p=s.clubs[s.club].players.find(q=>q.id===id);if(!p)continue;
   const sat=ensureSatisfaction(p);if(!sat)continue;
   const avant=sat.score;sat.score=Math.max(20,Math.min(95,sat.score+delta));
   if(sat.score!==avant)st.confiance[id]=cumul+(sat.score-avant);
  }
 }
 // ---- Équipe-type de la journée et équipe de la saison ----------------------------------
 // Quinze postes (maillots 1 à 15) regroupés : les trois troisième ligne (aile, aile, numéro 8) forment un groupe.
 const POSTES=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière'];
 const GROUPE_DE_POSTE=[0,1,2,3,3,4,4,4,5,6,7,8,8,7,9];
 const CAPACITE=[1,1,1,2,3,1,1,2,2,1];
 const NUMEROS=[[1],[2],[3],[4,5],[6,7,8],[9],[10],[11,14],[12,13],[15]];
 const NOM_GROUPE=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Troisième ligne','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Arrière'];
 function groupeDe(pos){
  const nom=String(pos||'').replace(/'/g,'’'),i=POSTES.indexOf(nom);
  if(i>=0)return GROUPE_DE_POSTE[i];
  return /^Troisi[eè]me ligne|^Num[eé]ro 8|^Aile forward/i.test(nom)?4:-1;
 }
 // Championnat d'un club : France (elite/accession), monde (identifiant de ligue) ou ligue unique.
 function ligueDe(s,club){
  const L=s.worldMode?.leagues||s.franceMode?.leagues;
  if(!L)return 'elite';
  for(const k of Object.keys(L).sort())if(Array.isArray(L[k]?.members)&&L[k].members.includes(club))return k;
  return null;
 }
 const regulier=(s,l)=>(l.worldContext?.phase??l.franceContext?.phase??s.phase)==='league';
 function nomLigueAffiche(s,id){
  if(s.franceMode?.leagues&&!s.worldMode?.leagues)return id==='elite'?'Top 14':id==='accession'?'Pro D2':libelle(s,id);
  if(!s.worldMode?.leagues&&!s.franceMode?.leagues)return 'Ligue Première';
  return nomLigue(id)||libelle(s,id);
 }
 // La saison régulière d'un championnat est terminée : plus aucune journée de championnat à jouer.
 function regulierFini(s,lg){
  const F=s.franceMode?.leagues?.[lg];
  if(F&&Array.isArray(F.schedule))return F.phase!=='league'||F.round>=F.schedule.length;
  const fixtures=s.worldMode?.fixtures;
  if(Array.isArray(fixtures)){const f=fixtures.filter(x=>x.competitionId===lg&&x.phase==='league');return f.length>0&&f.every(x=>s.history.some(r=>r.fixtureId===x.id));}
  return s.phase!=='league';
 }
 // Entraîneur d'un club (équipe de la carrière du personnel s'il existe) ; sinon, le club seul.
 function entraineurDe(s,club){
  const gens=s.staffCareer?.version===1&&Array.isArray(s.staffCareer.people)?s.staffCareer.people.flat():[];
  const NON=/academy|acad[ée]mie|assistant|adjoint|junior|transition|university|skills|forwards|backs|defen|attack|scrum|kicking|lineout|line-out|s&c|avants|arri[eè]res|d[ée]fense|attaque|m[êe]l[ée]e|touche|jeu au pied|pr[ée]para|r[ée]athl|formation|espoirs/i,TETE=/head coach|entra[iî]neur principal|^entra[iî]neur$|^manager$|manager sportif|director of rugby|directeur du rugby|head of rugby|senior coach|^coach$/i;
  const points=p=>(TETE.test(String(p.roleLabel||''))&&!NON.test(String(p.roleLabel||''))?2:0)+(p.role==='coach'&&!NON.test(String(p.roleLabel||''))?1:0);
  const p=gens.filter(x=>x.clubId===club&&x.role==='coach').sort((a,b)=>points(b)-points(a)||(b.level||0)-(a.level||0)||(a.id<b.id?-1:1))[0];
  return p?String(p.name).slice(0,120):'';
 }
 // Choix déterministe de quinze joueurs, un par poste : `lignes` triées du meilleur au moins bon.
 // Retourne les quinze entrées dans l'ordre des maillots 1 à 15, ou null.
 function composer(lignes,groupe,pos){
  const restes=CAPACITE.slice(),pris=[[],[],[],[],[],[],[],[],[],[]];
  for(const x of lignes){const g=groupe(x);if(g<0||!restes[g])continue;restes[g]--;pris[g].push(x);}
  if(restes.some(n=>n>0))return null;
  const sortie=[];
  pris.forEach((liste,g)=>{
   const numeros=NUMEROS[g].slice(),mis=new Array(numeros.length).fill(null);
   // Le numéro 8 revient au joueur inscrit à ce poste, s'il est retenu.
   if(g===4){const k=liste.findIndex(x=>pos(x)==='Numéro 8');if(k>=0){mis[2]=liste[k];liste.splice(k,1);}}
   for(const x of liste){const k=mis.indexOf(null);mis[k]=x;}
   mis.forEach((x,k)=>{sortie[numeros[k]-1]=x;});
  });
  return sortie.length===15&&sortie.every(Boolean)?sortie:null;
 }
 // Équipe-type de la journée de chaque championnat (note du match ; minutes, essais, identifiant à égalité).
 function equipesJournee(s,st,sem){
  const parLigue={};for(const x of sem.notes)if(x[7])(parLigue[x[7]]||(parLigue[x[7]]=[])).push(x);
  const fermes=[];
  for(const lg of Object.keys(parLigue).sort()){
   st.regJ[lg]=(st.regJ[lg]||0)+1;fermes.push(lg);
   const lignes=parLigue[lg].sort((a,b)=>b[2]-a[2]||b[5]-a[5]||b[6]-a[6]||(a[0]<b[0]?-1:a[0]>b[0]?1:0));
   const xv=composer(lignes,x=>groupeDe(x[3]),x=>x[3]);
   if(!xv)continue;
   // Entraîneur de la journée : plus large victoire, puis plus de points marqués, puis identifiant du club.
   let coach=null;
   for(const [,a,b,pa,pb] of sem.matchs.filter(m=>m[0]===lg))for(const [club,pour,contre] of [[a,pa,pb],[b,pb,pa]]){
    const marge=pour-contre;if(marge<=0)continue;
    if(!coach||marge>coach.marge||marge===coach.marge&&(pour>coach.pour||pour===coach.pour&&club<coach.club))coach={club,marge,pour};
   }
   const meilleur=xv.reduce((m,x,k)=>lignes.indexOf(x)<lignes.indexOf(xv[m])?k:m,0);
   for(const x of xv){const e=st.reg[lg]?.[x[0]];if(e)e[4]++;}
   st.equipes[lg]={saison:s.season,journee:st.regJ[lg],ids:xv.map(x=>x[0]),notes:xv.map(x=>x[2]),clubs:xv.map(x=>x[1]),etoile:meilleur,
    coach:coach?{club:coach.club,nom:entraineurDe(s,coach.club),marge:coach.marge}:null};
  }
  return fermes;
 }
 const nomDe=(s,id)=>{for(const c of s.clubs){const p=c.players.find(q=>q.id===id);if(p)return p.name;}return '';};
 const virg=x=>String(x).replace('.',',');
 function annonceJournee(s,st,lg){
  const eq=st.equipes[lg];if(!eq||eq.saison!==s.season||lg!==ligueDe(s,s.club))return;
  const nous=eq.ids.map((id,k)=>[id,k]).filter(([,k])=>eq.clubs[k]===s.club);
  for(const [id,k] of nous)distinction(s,'equipe',id,nomDe(s,id),s.club,eq.notes[k]);
  if(typeof news!=='function')return;
  const tete=eq.ids[eq.etoile],tag='XV de la '+eq.journee+(eq.journee===1?'re':'e')+' journée · '+nomLigueAffiche(s,lg);
  news(tag+' : '+(nous.length?nous.length+' joueur'+(nous.length>1?'s':'')+' de '+s.clubs[s.club].name+' ('+nous.map(([id])=>nomDe(s,id)).join(', ')+')':'aucun joueur de '+s.clubs[s.club].name)+'. Joueur de la journée : '+nomDe(s,tete)+' ('+virg(eq.notes[eq.etoile]/10)+').');
 }
 // Équipe de la saison : moyenne de la saison régulière (la moitié des journées jouées au moins),
 // sélections en équipe-type de la journée, puis matchs, puis identifiant à égalité.
 function equipeSaison(s,st,lg){
  const reg=st.reg[lg];if(!reg||st.saisons.some(x=>x.saison===s.season&&x.ligue===lg))return null;
  const mini=Math.max(1,Math.ceil((st.regJ[lg]||0)/2));
  const lignes=Object.entries(reg).filter(([,e])=>e[0]>=mini).map(([id,e])=>({id,e,moy:e[1]/e[0]}))
   .sort((a,b)=>b.moy-a.moy||b.e[4]-a.e[4]||b.e[0]-a.e[0]||(a.id<b.id?-1:a.id>b.id?1:0));
  const xv=composer(lignes,x=>x.e[5],x=>x.pos);
  if(!xv)return null;
  const fiche={saison:s.season,ligue:lg,ids:xv.map(x=>x.id),moy:xv.map(x=>Math.round(x.moy)),matchs:xv.map(x=>x.e[0]),sel:xv.map(x=>x.e[4]),clubs:xv.map(x=>x.e[6]),journees:st.regJ[lg]||0};
  st.saisons.push(fiche);if(st.saisons.length>MAX_SAISONS)st.saisons=st.saisons.slice(-MAX_SAISONS);
  return fiche;
 }
 function annonceSaison(s,st,fiche){
  if(!fiche||fiche.ligue!==ligueDe(s,s.club))return;
  const nous=fiche.ids.map((id,k)=>[id,k]).filter(([,k])=>fiche.clubs[k]===s.club);
  for(const [id,k] of nous)distinction(s,'xvsaison',id,nomDe(s,id),s.club,fiche.moy[k]);
  if(typeof news!=='function')return;
  const meilleur=fiche.moy.reduce((m,x,k)=>x>fiche.moy[m]?k:m,0);
  news('XV de la saison · '+nomLigueAffiche(s,fiche.ligue)+' : '+(nous.length?nous.length+' joueur'+(nous.length>1?'s':'')+' de '+s.clubs[s.club].name+' ('+nous.map(([id])=>nomDe(s,id)).join(', ')+')':'aucun joueur de '+s.clubs[s.club].name)+'. Meilleure moyenne : '+nomDe(s,fiche.ids[meilleur])+' ('+virg(fiche.moy[meilleur]/10)+').');
 }
 // Distinctions de fin de journée : équipe-type de chaque championnat (publiée dans l'actualité pour
 // celui du manager, qu'il y figure ou non), équipe de la saison à la fin de la saison régulière,
 // meilleur joueur du mois (toutes les 4 journées) et de la saison.
 function finJournee(){
  const s=state();if(!s?.matchNotes?.semaine)return;
  const st=etat(s),sem=st.semaine;if(sem.annoncee)return;sem.annoncee=true;
  if(!Array.isArray(sem.matchs))sem.matchs=[];
  const fermes=equipesJournee(s,st,sem);
  for(const lg of fermes)annonceJournee(s,st,lg);
  for(const lg of fermes)if(regulierFini(s,lg))annonceSaison(s,st,equipeSaison(s,st,lg));
  sem.notes=[];sem.matchs=[];
  if(!sem.comp)return;
  // Meilleur joueur du mois (toutes les 4 journées du manager) : moyenne des 4 dernières notes, 3 matchs au moins.
  st.journees=(st.journees||0)+1;
  if(st.journees%4===0){
   let best=null;
   for(const [id,j] of Object.entries(st.detail)){const d=j.slice(-4);if(d.length<3)continue;const m=d.reduce((n,r)=>n+r[4],0)/d.length;if(!best||m>best[1]||m===best[1]&&id<best[0])best=[id,m];}
   if(best){const nom=nomDe(s,best[0]);distinction(s,'mois',best[0],nom,s.club,Math.round(best[1]));if(typeof news==='function')news('Joueur du mois à '+s.clubs[s.club].name+' : '+nom+' ('+virg(Math.round(best[1])/10)+' de moyenne).');}
  }
 }
 function finSaison(){
  const s=state(),st=s?.matchNotes;if(!st||st.saison!==s.season)return;
  migrer(st);
  // Championnats dont la saison régulière n'a pas été close en cours de route (reprise d'une sauvegarde).
  for(const lg of Object.keys(st.reg).sort())annonceSaison(s,st,equipeSaison(s,st,lg));
  let best=null;
  for(const p of s.clubs[s.club]?.players||[]){const j=st.joueurs[p.id];if(!j||j.s[0]<10)continue;const m=j.s[1]/j.s[0];if(!best||m>best[1]||m===best[1]&&p.id<best[0].id)best=[p,m];}
  if(best){distinction(s,'saison',best[0].id,best[0].name,s.club,Math.round(best[1]));if(typeof news==='function')news('Joueur de la saison à '+s.clubs[s.club].name+' : '+best[0].name+' ('+String(Math.round(best[1])/10).replace('.',',')+' de moyenne sur '+st.joueurs[best[0].id].s[0]+' matchs).');}
 }
 // Validation stricte de l'état sauvegardé.
 function validate(s){
  if(!s||s.matchNotes===undefined)return true;
  const st=s.matchNotes;
  check(obj(st)&&(st.version===VERSION||st.version===1)&&int(st.saison,1,s.season)&&obj(st.joueurs)&&obj(st.detail)&&obj(st.passees)&&obj(st.confiance)&&Array.isArray(st.recompenses)&&st.recompenses.length<=MAX_RECOMPENSES,'schéma invalide');
  const nombres=(a,n)=>Array.isArray(a)&&a.length===n&&a.every(x=>int(x,0,1e7));
  for(const j of Object.values(st.joueurs))check(obj(j)&&(nombres(j.s,7)||nombres(j.s,TOTAUX))&&Array.isArray(j.f)&&j.f.length<=5&&j.f.every(x=>int(x,10,100))&&j.s[1]<=j.s[0]*100,'joueur invalide');
  for(const d of Object.values(st.detail))check(Array.isArray(d)&&d.length<=MAX_DETAIL&&d.every(r=>Array.isArray(r)&&(r.length===9||r.length===9+DETAIL_EN_PLUS.length)&&int(r[0],0,100)&&int(r[1],-1,100000)&&typeof r[2]==='string'&&r[2].length<=40&&int(r[3],0,240)&&int(r[4],10,100)&&[5,6,7].every(k=>int(r[k],0,100000))&&(r[8]===0||r[8]===1)&&r.slice(9).every(x=>int(x,0,100000))),'détail invalide');
  for(const d of Object.values(st.passees))check(Array.isArray(d)&&d.length<=MAX_PASSEES&&d.every(r=>Array.isArray(r)&&(r.length===6||r.length===8)&&int(r[0],1,s.season)&&int(r[1],-1,100000)&&int(r[2],1,500)&&int(r[3],10,100)&&int(r[4],0,10000)&&int(r[5],0,500)&&r.slice(6).every(x=>int(x,0,1e7))),'saison passée invalide');
  for(const v of Object.values(st.confiance))check(int(v,-CONFIANCE_MAX,CONFIANCE_MAX),'confiance invalide');
  for(const r of st.recompenses)check(obj(r)&&['hdm','equipe','mois','saison','xvsaison'].includes(r.type)&&typeof r.id==='string'&&int(r.note,10,100),'distinction invalide');
  check(st.semaine===null||obj(st.semaine)&&Array.isArray(st.semaine.notes)&&st.semaine.notes.length<=MAX_SEMAINE,'journée invalide');
  if(st.selection!==undefined){
   const sel=st.selection,date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x);
   check(obj(sel)&&obj(sel.lignes)&&obj(sel.vus)&&Object.keys(sel.vus).length<=MAX_VUS&&Object.values(sel.vus).every(date),'sélection invalide');
   for(const d of Object.values(sel.lignes))check(Array.isArray(d)&&d.length<=MAX_SELECTION&&d.every(r=>Array.isArray(r)&&r.length===7&&date(r[0])&&typeof r[1]==='string'&&r[1].length<=60&&typeof r[2]==='string'&&r[2].length<=60&&int(r[3],0,120)&&int(r[4],10,100)&&int(r[5],0,50)&&(r[6]===0||r[6]===1)),'match international invalide');
  }
  if(st.version===1)return true;
  const cle=x=>typeof x==='string'&&x.length>0&&x.length<=40;
  check(obj(st.reg)&&obj(st.regJ)&&obj(st.equipes)&&Array.isArray(st.saisons)&&st.saisons.length<=MAX_SAISONS,'équipe-type invalide');
  for(const [lg,reg] of Object.entries(st.reg)){check(cle(lg)&&obj(reg),'championnat invalide');for(const e of Object.values(reg))check(Array.isArray(e)&&e.length===7&&[0,1,2,3,4].every(k=>int(e[k],0,1e7))&&e[1]<=e[0]*100&&int(e[5],0,9)&&int(e[6],-1,100000),'saison régulière invalide');}
  for(const [lg,n] of Object.entries(st.regJ))check(cle(lg)&&int(n,0,500),'journées invalides');
  const quinze=(a,f)=>Array.isArray(a)&&a.length===15&&a.every(f);
  for(const [lg,e] of Object.entries(st.equipes))check(cle(lg)&&obj(e)&&int(e.saison,1,s.season)&&int(e.journee,1,500)&&quinze(e.ids,x=>typeof x==='string')&&quinze(e.notes,x=>int(x,10,100))&&quinze(e.clubs,x=>int(x,-1,100000))&&int(e.etoile,0,14)&&(e.coach===null||obj(e.coach)&&int(e.coach.club,-1,100000)&&typeof e.coach.nom==='string'&&int(e.coach.marge,1,300)),'équipe de la journée invalide');
  for(const e of st.saisons)check(obj(e)&&int(e.saison,1,s.season)&&cle(e.ligue)&&quinze(e.ids,x=>typeof x==='string')&&quinze(e.moy,x=>int(x,10,100))&&quinze(e.matchs,x=>int(x,1,500))&&quinze(e.sel,x=>int(x,0,500))&&quinze(e.clubs,x=>int(x,-1,100000))&&int(e.journees,0,500),'équipe de la saison invalide');
  return true;
 }
 // Libellé d'une compétition enregistrée (phase France ou identifiant de compétition mondiale).
 const PHASES={league:'Championnat',barrage:'Barrage',semi:'Demi-finale',final:'Finale',playoff:'Phase finale'};
 const COUPES={champions:'Coupe des champions',challenge:'Challenge européen'};let ligues=null;
 function nomLigue(id){
  if(!ligues){ligues={};try{for(const t of [typeof nativeWorldRegistryText==='string'?nativeWorldRegistryText:null,typeof nativeWorldChampRegistryText==='string'?nativeWorldChampRegistryText:null])if(t)for(const l of JSON.parse(t).leagues||[])ligues[l.id]=l.name;}catch(e){}}
  return ligues[id]||null;
 }
 function libelle(s,id){return PHASES[id]||COUPES[id]||nomLigue(id)||String(id).replace(/[-_]/g,' ').replace(/^./,c=>c.toUpperCase());}

 function saisonLabel(s,n){return (typeof libelleSaison==='function'?libelleSaison:String)(n);}
 // Projection pour l'interface : équipe-type de la dernière journée et équipe de la saison de chaque championnat.
 function projeterEquipes(s,st){
  const ids=new Set(),courantes=Object.entries(st.equipes||{}).filter(([,e])=>e.saison===s.season),derniere={};
  for(const f of st.saisons||[])if(!derniere[f.ligue]||f.saison>derniere[f.ligue].saison)derniere[f.ligue]=f;
  for(const [,e] of courantes)e.ids.forEach(id=>ids.add(id));
  for(const f of Object.values(derniere))f.ids.forEach(id=>ids.add(id));
  if(!ids.size)return {ligues:[],defaut:null};
  const joueurs=new Map();for(const c of s.clubs)for(const p of c.players)if(ids.has(p.id))joueurs.set(p.id,p);
  // Un jeune appelé pour le match peut être reparti en centre de formation depuis : on le retrouve là aussi.
  for(const p of [...(s.development?.academy||[]),...(s.aiRoster?.academies||[]).flatMap(x=>x.players||[])])if(ids.has(p.id)&&!joueurs.has(p.id))joueurs.set(p.id,p);
  const identite=id=>{
   const p=joueurs.get(id);if(!p)return {id,name:nomHorsClub(id),pos:'',age:0,portraitIndex:0};
   const natif=/^p\d+-(\d+)-\d+$/.exec(p.id);let h=2166136261;for(const ch of p.id){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}
   const r={id:p.id,name:p.name,pos:p.pos,age:p.age,portraitIndex:natif?Number(natif[1])%32:(h>>>0)%32};
   for(const k of ['appearanceBankVersion','appearanceId','appearanceAge','sourcePlayerId','portraitPath'])if(p[k]!==undefined)r[k]=p[k];
   return r;
  };
  const nomHorsClub=id=>st.recompenses.find(r=>r.id===id)?.nom||'';
  const club=i=>{const c=s.clubs[i];if(!c)return {id:i,name:'',abbr:'XV',color:'#b94850'};let pres=null;try{pres=(typeof CDFranceClubs!=='undefined'&&!s.customCompetition?CDFranceClubs.forCareer(s,i):c)||c;}catch(e){pres=c;}
   return {id:c.id,name:c.name,abbr:c.abbr,color:c.color,presentation:pres?{id:pres.id,slug:pres.slug,city:pres.city,name:pres.name,abbr:pres.abbr,color:pres.color,logoPath:pres.logoPath}:null};};
  const ligues=[];
  const cles=[...new Set([...courantes.map(([k])=>k),...Object.keys(derniere)])];
  const monLigue=ligueDe(s,s.club);
  cles.sort((a,b)=>(a===monLigue?-1:b===monLigue?1:0)||(a<b?-1:1));
  for(const lg of cles){
   const e=st.equipes?.[lg],ok=e&&e.saison===s.season,f=derniere[lg];
   const fiche={id:lg,nom:nomLigueAffiche(s,lg),manager:lg===monLigue,journee:null,saison:null};
   if(ok)fiche.journee={numero:e.journee,saison:s.season,libelleSaison:saisonLabel(s,s.season),
    joueurs:e.ids.map((id,k)=>({...identite(id),numero:k+1,poste:POSTES[k],noteMatch:e.notes[k]/10,club:club(e.clubs[k]),manager:e.clubs[k]===s.club,etoile:k===e.etoile,selections:st.reg?.[lg]?.[id]?.[4]||0})),
    entraineur:e.coach?{nom:e.coach.nom,club:club(e.coach.club),marge:e.coach.marge,manager:e.coach.club===s.club}:null};
   if(f)fiche.saison={saison:f.saison,libelleSaison:saisonLabel(s,f.saison),journees:f.journees,
    joueurs:f.ids.map((id,k)=>({...identite(id),numero:k+1,poste:POSTES[k],noteMatch:f.moy[k]/10,matchs:f.matchs[k],selections:f.sel[k],club:club(f.clubs[k]),manager:f.clubs[k]===s.club,etoile:f.moy[k]===Math.max(...f.moy)&&f.moy.indexOf(f.moy[k])===k}))};
   ligues.push(fiche);
  }
  return {ligues,defaut:ligues[0]?.id??null};
 }
 // Projection (clubLife.matchNotes) : effectif du manager, détail, distinctions, dernier match.
 // Noms projetés des champs de détail ajoutés (même ordre que DETAIL_EN_PLUS).
 const DETAIL_PROJETE=['courses','passes','franchissements','plaquagesManques','defenseursBattus','offloads','recuperations','ballonsPerdus','points','penalitesConcedees'];
 function project(){
  const s=state(),st=s?.matchNotes;
  const base={version:VERSION,noteDepart:calc.NOTE_DEPART,joueurs:{},recompenses:[],dernier:null,equipeType:{ligues:[],defaut:null}};
  if(!s||!st)return base;
  const courant=st.saison===s.season;
  for(const p of s.clubs[s.club]?.players||[]){
   const j=st.joueurs[p.id],d=courant?st.detail[p.id]||[]:[],passe=st.passees[p.id]||[],inter=st.selection?.lignes?.[p.id]||[];
   if(!j&&!passe.length&&!inter.length)continue;
   const n=courant&&j?j.s[0]:0;
   // Totaux de la feuille réaliste (null : ancienne sauvegarde, champ inconnu, affiché « — »).
   const total=k=>n&&j.s.length>k?j.s[k]:n?null:0;
   base.joueurs[p.id]={matchs:n,moyenne:n?Math.round(j.s[1]/n)/10:null,minutes:n?j.s[2]:0,essais:n?j.s[3]:0,plaquages:n?j.s[4]:0,metres:n?j.s[5]:0,hommeDuMatch:n?j.s[6]:0,
    passes:total(7),franchissements:total(8),plaquagesManques:total(9),points:total(10),
    forme:(j?.f||[]).map(x=>x/10),
    historique:d.slice().reverse().map(r=>{const o={semaine:r[0],adversaire:s.clubs[r[1]]?.name||'',adversaireId:r[1],competition:libelle(s,r[2]),minutes:r[3],note:r[4]/10,essais:r[5],plaquages:r[6],metres:r[7],hommeDuMatch:r[8]===1};
     DETAIL_PROJETE.forEach((k,i)=>{o[k]=r.length>9?r[9+i]:null;});return o;}),
    saisons:passe.map(r=>({saison:r[0],club:s.clubs[r[1]]?.name||'',matchs:r[2],moyenne:r[3]/10,essais:r[4],hommeDuMatch:r[5],plaquages:r.length>6?r[6]:null,metres:r.length>7?r[7]:null})),
    // Équipe-type de la saison en cours (sélections) et équipes de la saison (repères de carrière).
    selections:courant?Object.values(st.reg||{}).reduce((n,reg)=>n+(reg[p.id]?.[4]||0),0):0,
    distinctions:(st.saisons||[]).filter(f=>f.ids.includes(p.id)).map(f=>({type:'xv-saison',saison:f.saison,libelleSaison:saisonLabel(s,f.saison),championnat:nomLigueAffiche(s,f.ligue),moyenne:f.moy[f.ids.indexOf(p.id)]/10,matchs:f.matchs[f.ids.indexOf(p.id)]})).reverse(),
    selection:inter.length?{matchs:inter.length,moyenne:Math.round(inter.reduce((a,r)=>a+r[4],0)/inter.length)/10,forme:inter.slice(-5).map(r=>r[4]/10),hommeDuMatch:inter.filter(r=>r[6]).length,
     historique:inter.slice().reverse().map(r=>({date:r[0],adversaire:r[1],competition:r[2],minutes:r[3],note:r[4]/10,essais:r[5],hommeDuMatch:r[6]===1}))}:null};
  }
  base.equipeType=projeterEquipes(s,st);
  base.recompenses=st.recompenses.slice(-12).reverse();
  base.dernier=st.dernier?JSON.parse(JSON.stringify(st.dernier)):null;
  return base;
 }
 function execute(){throw Error('Notes de match : aucune commande.');}
 function installHooks(){
  if(typeof CDNotesAbsentes!=='undefined'&&CDNotesAbsentes===true)return true;
  if(typeof captureMatchAction!=='function'||captureMatchAction.__matchNotes)return true;
  // Journal des faits des matchs simulés : la même scène que le direct, gardée sur le match
  // (transitoire, jamais sauvegardée : un match simulé ne reste pas dans l'état).
  const capture=captureMatchAction,captureNotes=function(l,type,meta={}){
   const scene=capture.apply(this,arguments);
   if(scene===undefined&&l&&l.userSide<0&&Array.isArray(l.events)){
    const side=l.userSide;let fait;l.userSide=0;try{fait=capture(l,type,meta);}finally{l.userSide=side;}
    if(fait){if(!l.notesJournal)Object.defineProperty(l,'notesJournal',{value:[],writable:true,enumerable:false,configurable:true});l.notesJournal.push({min:l.minute,type,scene:fait});}
   }
   return scene;
  };
  captureNotes.__matchNotes=true;captureMatchAction=captureNotes;
  // Note finale, avant la progression du match (le niveau au poste lu est celui du match).
  if(typeof recordDevelopmentMatch==='function'){
   const develop=recordDevelopmentMatch,wrapped=function(l){
    let r=null;if(l&&!l.developmentRecorded)r=enregistrer(l);
    const result=develop.apply(this,arguments);
    if(r)progression(l,r);
    return result;
   };
   Object.assign(wrapped,develop);recordDevelopmentMatch=wrapped;
  }
  // Composition des entraîneurs IA : la forme récente entre dans le score de choix.
  if(typeof buildSheet==='function'){
   const build=buildSheet;
   buildSheet=function(c){
    const s=state();if(!s?.matchNotes||!c||c.id===s.club||typeof fitScore!=='function')return build.apply(this,arguments);
    const fit=fitScore;fitScore=function(p){return fit.apply(this,arguments)*effets.composition(p.id);};
    try{return build.apply(this,arguments);}finally{fitScore=fit;}
   };
  }
  // Exigence salariale en négociation (prolongation et recrutement).
  if(typeof askingWage==='function'){
   const ask=askingWage;
   askingWage=function(p,kind){const base=ask.apply(this,arguments),k=p&&state()?.matchNotes?effets.salaire(p.id):1;return k===1||!Number.isFinite(base)?base:Math.round(base*k/100)*100;};
  }
  if(typeof finishRound==='function'){const fin=finishRound;finishRound=function(){const result=fin.apply(this,arguments);try{finJournee();}catch(e){}return result;};}
  if(typeof advanceSeason==='function'){const avance=advanceSeason;advanceSeason=function(){try{finSaison();}catch(e){}const result=avance.apply(this,arguments);const s=state();if(s?.matchNotes)rollover(s);return result;};}
  return true;
 }
 // Progression : petit bonus de développement pour les jeunes (21 ans et moins) bien notés.
 function progression(l,r){
  if(!actifs()||typeof growPlayer!=='function')return;
  for(const [id,n] of Object.entries(r.joueurs)){
   if(n.note<7.5||n.minutes<40)continue;
   const p=matchPlayer(l,n.cote,id);if(!p||!(p.age<=21))continue;
   growPlayer(p,Math.min(.03,(n.note-7.3)*.02),false);
  }
 }
 return {project,validate,execute,installHooks,noterMatch,contexte,enregistrer,enregistrerSelection,forme,moyenne,effets,rollover,migrer,finSaison,finJournee,composer,groupeDe};
}
module.exports={files,commands,factory,moteur,...moteur()};
