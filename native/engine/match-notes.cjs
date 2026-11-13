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
//  - influence : niveau au poste du joueur par rapport à son équipe du jour (± 0,35 au plus).
// La somme est comprimée (tanh) autour de 6,5 : la plupart des notes entre 5,5 et 8, 9 et plus rares.

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
 const arrondi=n=>Math.round(n*10)/10;
 const borne=(n,a,b)=>Math.max(a,Math.min(b,n));
 // Note affichée d'un total brut (impact) : compression douce autour de la base.
 function echelle(brut){return arrondi(borne(NOTE_DEPART+COMPRESSION*Math.tanh(brut/COMPRESSION),NOTE_MIN,NOTE_MAX));}
 // journal : [{min,type,scene}] (l.events du direct, ou journal transitoire d'un match simulé).
 // contexte : {minutes:{id:minutes jouées}, cotes:{id:0|1}, niveaux:{id:-1..1}, score:[a,b],
 //             duree, fini, camp (0|1 : seulement cette équipe ; sinon les deux)}.
 function noter(journal,contexte={}){
  const cotes=contexte.cotes||{},minutes=contexte.minutes||{},niveaux=contexte.niveaux||{};
  const camp=contexte.camp===0||contexte.camp===1?contexte.camp:null;
  const joueurs={};
  const fiche=(id,cote)=>joueurs[id]||(joueurs[id]={cote,brut:0,faits:0,essais:0,metres:0,plaquages:0,manques:0,courses:0,franchissements:0,recuperations:0,buts:0,cartons:0,minutes:0,note:NOTE_DEPART});
  for(const [id,cote] of Object.entries(cotes))if(cote===0||cote===1)fiche(String(id),cote);
  const surLeTerrain=(s,c)=>Array.isArray(s?.on?.[c])?s.on[c].filter(x=>x!=null).map(String):[];
  // Joueur nommé par un fait : son équipe est celle de la feuille, sinon celle du terrain.
  let sceneCourante=null;
  const ajoute=(id,valeur,fait)=>{
   if(id==null)return null;id=String(id);
   if(!joueurs[id]){const c=[0,1].find(c=>surLeTerrain(sceneCourante,c).includes(id));if(c===undefined)return null;fiche(id,c);}
   const n=joueurs[id];n.brut+=valeur;n.faits++;if(fait)n[fait]++;return n;
  };
  let score=[0,0],dernierScore=null;
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
    if(tx!==null){const def=(s.on?.[1-equipe]||[]).map(String),nomme=s.tackler!=null&&def.includes(String(s.tackler))?String(s.tackler):null;const tacle=nomme??plaqueur(s.on?.[1-equipe],gain,s.to?.y,i);if(gain<22)ajoute(tacle,.05,'plaquages');else ajoute(tacle,-.16,'manques');}
    const n=ajoute(s.actor,.03+Math.min(1.1,gain/32)+(gain>=22?.3:0),'courses');
    if(n){n.metres+=gain;if(gain>=22)n.franchissements++;}
    continue;
   }
   if(kind==='try'&&equipe!==null){
    ajoute(s.actor,1.05,'essais');
    for(const id of surLeTerrain(s,equipe))if(joueurs[id])joueurs[id].brut+=.05;
    if(s.origin==='open')ajoute(plaqueur(s.on?.[1-equipe],30,s.to?.y),-.15,'manques');
    continue;
   }
   if(kind==='turnover'){ajoute(s.actor,.28,'recuperations');const n=joueurs[String(s.actor)];if(n&&(equipe===null||n.cote===equipe))n.plaquages++;continue;}
   if(kind==='reception'){ajoute(s.actor,.06);continue;}
   if(kind==='kick'){ajoute(s.actor,.04+(gain>=30?.12:0));continue;}
   if(kind==='kickoff'||kind==='drop22'||kind==='goalLine'){ajoute(s.actor,.02);continue;}
   if(kind==='goal'){ajoute(s.actor,.3,'buts');continue;}
   if(kind==='miss'){if(s.actor!=null)ajoute(s.actor,-.18);continue;}
   // Conquête : la touche (départ au bord, y ≤ 4) crédite talonneur et sauteurs, la mêlée la
   // première ligne et les deuxième ligne ; un ballon perdu pèse sur les mêmes postes adverses.
   if((kind==='setpiece-win'||kind==='setpiece-loss')&&equipe!==null){
    const touche=Number.isFinite(s.from?.y)&&s.from.y<=4,postes=touche?{1:1,3:1,4:1}:{0:1,1:1,2:1,3:.4,4:.4};
    const credit=(c,valeur)=>(s.on?.[c]||[]).forEach((id,poste)=>{if(id!=null&&postes[poste]){const n=joueurs[String(id)];if(n)n.brut+=valeur*postes[poste];}});
    if(kind==='setpiece-win'){credit(equipe,touche?.045:.06);ajoute(s.actor,.03);}
    else{credit(equipe,touche?.07:.08);credit(1-equipe,touche?-.06:-.07);ajoute(s.actor,.15);}
    continue;
   }
   if(kind==='card'&&s.incident){ajoute(s.actor,s.card==='red'||s.card==='red20'||s.cause==='red'?-2:-.8,'cartons');continue;}
   // Pénalité ou faute de main : fautif non nommé, léger poids collectif (avants pour la pénalité).
   if(kind==='penalty'&&equipe!==null){const fautifs=surLeTerrain(s,1-equipe);fautifs.forEach((id,k)=>{if(joueurs[id])joueurs[id].brut-=(s.on?.[1-equipe]?.indexOf(id)??9)<8?.03:.012;});continue;}
   if(kind==='hand-fault'&&equipe!==null){for(const id of surLeTerrain(s,equipe))if(joueurs[id])joueurs[id].brut-=.012;continue;}
  }
  if(Array.isArray(contexte.score)&&contexte.score.length===2)score=contexte.score;else if(dernierScore)score=dernierScore;
  const duree=Math.max(1,Number.isFinite(contexte.duree)?contexte.duree:80);
  for(const [id,n] of Object.entries(joueurs)){
   const m=Number.isFinite(minutes[id])?Math.max(0,minutes[id]):0;n.minutes=Math.round(m);
   const part=Math.min(1,m/Math.max(80,duree));
   const ecart=(score[n.cote]||0)-(score[1-n.cote]||0);
   // Collectif : écart au score (borné) et résultat, une fois le match fini.
   const collectif=borne(ecart/32,-.45,.45)+(contexte.fini?(ecart>0?.2:ecart<0?-.2:0):0);
   const niveau=Number.isFinite(niveaux[id])?borne(niveaux[id],-1,1)*.35:0;
   // Étalonnage (saison simulée, docs/notes-de-match-20261113.md) : moyenne ≈ 6,6, écart-type ≈ 0,75.
   n.note=echelle(.72*n.brut-.28*part+(collectif+niveau)*part);
   n.metres=Math.round(n.metres);
  }
  // Homme du match (fin de match) : meilleure note parmi ceux qui ont joué 30 minutes ou plus ;
  // à égalité, le vainqueur, puis le plus de faits, puis l'identifiant.
  let hommeDuMatch=null;
  const candidats=Object.entries(joueurs).filter(([,n])=>n.minutes>=30);
  candidats.sort(([a,x],[b,y])=>y.note-x.note||((score[y.cote]-score[1-y.cote])-(score[x.cote]-score[1-x.cote]))||y.faits-x.faits||(a<b?-1:a>b?1:0));
  if(candidats.length)hommeDuMatch=candidats[0][0];
  if(camp!==null)for(const id of Object.keys(joueurs))if(joueurs[id].cote!==camp)delete joueurs[id];
  for(const n of Object.values(joueurs))delete n.brut;
  return {joueurs,hommeDuMatch,score:score.slice()};
 }
 return {NOTE_DEPART,noter,plaqueur,echelle};
}

// ---- Domaine natif (installé dans la VM du moteur, voir native-systems.cjs) ----------------
// État `S.matchNotes` (version 1) :
//  saison  : saison en cours ;
//  joueurs : {id:{s:[matchs, somme des notes ×10, minutes, essais, plaquages, mètres, hommes du match], f:[5 dernières notes ×10]}}
//            pour chaque joueur ayant joué (tous les clubs) ;
//  detail  : {id:[[semaine, adversaire, compétition, minutes, note×10, essais, plaquages, mètres, homme du match (0/1)], …]}
//            détail de la saison en cours pour les joueurs du club du manager ;
//  passees : {id:[[saison, club, matchs, moyenne×10, essais, hommes du match], …]} 8 saisons au plus ;
//  confiance : {id:effet cumulé de la saison sur la satisfaction (borné ±6)} ;
//  semaine : {cle, comp, notes:[[id, club, note×10, poste]]} rencontres de la journée (équipe type) ;
//  recompenses : 40 dernières distinctions [{saison, semaine, type, id, nom, club, note×10}] ;
//  dernier : homme du match et notes du dernier match du manager.
// Anciennes sauvegardes : `S.matchNotes` absent = historique vide, créé au premier match.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const VERSION=1,MAX_DETAIL=60,MAX_PASSEES=8,MAX_RECOMPENSES=40,CONFIANCE_MAX=6;
 const calc=CDMatchNotesMoteur;
 const state=()=>typeof S==='undefined'?null:S;
 const obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const check=(ok,message)=>{if(!ok)throw Error('Notes de match : '+message+'.');};
 const semaine=s=>s.worldMode?.week??s.franceMode?.week??s.round??0;
 const vide=s=>({version:VERSION,saison:s.season,joueurs:{},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null});
 function etat(s){if(!s.matchNotes)s.matchNotes=vide(s);if(s.matchNotes.saison!==s.season)rollover(s);return s.matchNotes;}
 // Fin de saison : résumé par joueur, détail effacé ; on ne garde que les joueurs encore en jeu.
 function rollover(s){
  const st=s.matchNotes;if(!st||st.saison===s.season)return;
  const clubDe=new Map();for(const c of s.clubs)for(const p of c.players)clubDe.set(p.id,c.id);
  for(const [id,j] of Object.entries(st.joueurs)){
   if(j.s[0]>0){(st.passees[id]||(st.passees[id]=[])).push([st.saison,clubDe.get(id)??-1,j.s[0],Math.round(j.s[1]/j.s[0]),j.s[3],j.s[6]]);}
   j.s=[0,0,0,0,0,0,0];
  }
  for(const id of Object.keys(st.passees)){if(!clubDe.has(id))delete st.passees[id];else st.passees[id]=st.passees[id].slice(-MAX_PASSEES);}
  for(const id of Object.keys(st.joueurs))if(!clubDe.has(id))delete st.joueurs[id];
  st.detail={};st.confiance={};st.semaine=null;st.saison=s.season;
 }
 // Contexte d'un match pour le calcul : minutes, côtés, niveau au poste relatif à l'équipe.
 function contexte(l){
  const cotes={},minutes={},niveaux={},noms={};
  for(let side=0;side<2;side++){
   const sh=l.sheets?.[side];if(!sh)continue;
   const ids=[...new Set([...(sh.used||[]),...(sh.on||[]).filter(Boolean)])];
   const notes=[];
   for(const id of ids){const p=typeof matchPlayer==='function'?matchPlayer(l,side,id):null;cotes[id]=side;minutes[id]=Number(sh.minutes?.[id])||0;if(p){const r=roleNote(p);notes.push([id,r]);noms[id]=p.name;}}
   const moyenne=notes.length?notes.reduce((n,[,r])=>n+r,0)/notes.length:0;
   for(const [id,r] of notes)niveaux[id]=Math.max(-1,Math.min(1,(r-moyenne)/10));
  }
  return {cotes,minutes,niveaux,noms,score:l.score.slice(),duree:l.minute,fini:!!l.finished};
 }
 const journalDe=l=>l.userSide>=0?l.events:(l.notesJournal||[]);
 function noterMatch(l){return calc.noter(journalDe(l),contexte(l));}
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
 const actifs=()=>typeof CDNotesEffets==='undefined'||CDNotesEffets!==false;
 const effets={
  // Composition des entraîneurs IA : forme récente (2 notes au moins), ±3 à 4 % du score de choix.
  composition(id){if(!actifs())return 1;const f=forme(id);return f===null||formeN(id)<2?1:1+Math.max(-.03,Math.min(.04,(f-6.5)*.03));},
  // Valeur marchande (indemnité) : moyenne de saison, −8 % à +12 %.
  valeur(id){if(!actifs())return 1;const m=moyenne(id);return m===null?1:1+Math.max(-.08,Math.min(.12,(m-6.5)*.08));},
  // Intérêt des clubs IA : note estimée du joueur, −2 à +3 points.
  interet(id){if(!actifs())return 0;const m=moyenne(id);return m===null?0:Math.max(-2,Math.min(3,(m-6.5)*2));},
  // Exigence salariale en négociation : −4 % à +6 %.
  salaire(id){if(!actifs())return 1;const m=moyenne(id);return m===null?1:1+Math.max(-.04,Math.min(.06,(m-6.5)*.04));},
  // Sélections nationales : bonus au score de forme du sélectionneur, −1,5 à +2 points.
  selection(id){if(!actifs())return 0;const f=forme(id);return f===null||formeN(id)<3?0:Math.max(-1.5,Math.min(2,(f-6.5)*1.2));}
 };
 function clubIdDe(l,side){return l.pair[side];}
 function competition(l){const c=l.worldContext||l.franceContext;return String(c?.competitionId||c?.competition||c?.phase||state()?.phase||'championnat').slice(0,40);}
 function enregistrer(l){
  const s=state();if(!s||!l?.finished||l.matchNotesRecorded)return null;
  l.matchNotesRecorded=true;
  const st=etat(s),r=noterMatch(l),w=semaine(s),comp=competition(l),user=l.pair.indexOf(s.club);
  for(const [id,n] of Object.entries(r.joueurs)){
   if(n.minutes<=0)continue;
   const note10=Math.round(n.note*10),hdm=r.hommeDuMatch===id?1:0;
   const j=st.joueurs[id]||(st.joueurs[id]={s:[0,0,0,0,0,0,0],f:[]});
   j.s[0]++;j.s[1]+=note10;j.s[2]+=n.minutes;j.s[3]+=n.essais;j.s[4]+=n.plaquages;j.s[5]+=n.metres;j.s[6]+=hdm;
   j.f.push(note10);if(j.f.length>5)j.f.shift();
   if(n.cote===user){const d=st.detail[id]||(st.detail[id]=[]);d.push([w,clubIdDe(l,1-n.cote),comp,n.minutes,note10,n.essais,n.plaquages,n.metres,hdm]);if(d.length>MAX_DETAIL)d.shift();}
  }
  // Rencontres de la journée (équipe type) : on ne garde que la semaine en cours.
  const cle=s.season+':'+w;
  // Nouvelle journée : la précédente est d'abord close (carrières sans `finishRound`, calendrier quotidien).
  if(st.semaine?.cle!==cle){if(st.semaine&&!st.semaine.annoncee){try{finJournee();}catch(e){}}st.semaine={cle,comp:null,notes:[]};}
  for(const [id,n] of Object.entries(r.joueurs)){
   if(n.minutes<40)continue;
   const c=clubIdDe(l,n.cote),p=matchPlayer(l,n.cote,id);
   st.semaine.notes.push([id,c,Math.round(n.note*10),p?.pos||'',comp]);
  }
  if(st.semaine.notes.length>2000)st.semaine.notes=st.semaine.notes.slice(-2000);
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
 // Distinctions de fin de journée : équipe type (15 meilleures notes de la compétition du
 // manager, au poste), meilleur joueur du mois (toutes les 4 journées) et de la saison.
 function finJournee(){
  const s=state();if(!s?.matchNotes?.semaine?.comp)return;
  const st=s.matchNotes,sem=st.semaine;if(sem.annoncee)return;sem.annoncee=true;
  const lignes=sem.notes.filter(x=>x[4]===sem.comp).sort((a,b)=>b[2]-a[2]||(a[0]<b[0]?-1:1));
  if(lignes.length<15)return;
  const pris=new Set(),xv=[];
  const postes=typeof POS!=='undefined'?POS:[],besoins={};for(const p of postes)besoins[p]=(besoins[p]||0)+1;
  const nomDe=id=>{for(const c of s.clubs){const p=c.players.find(q=>q.id===id);if(p)return p.name;}return '';};
  for(const x of lignes){if(pris.has(x[0]))continue;const poste=x[3];if(!besoins[poste])continue;besoins[poste]--;pris.add(x[0]);xv.push(x);}
  if(xv.length<15)return;
  const nous=xv.filter(x=>x[1]===s.club);
  sem.equipeType=xv.map(x=>x[0]);
  for(const x of nous)distinction(s,'equipe',x[0],nomDe(x[0]),x[1],x[2]);
  if(typeof news==='function')news('Équipe type de la journée : '+(nous.length?nous.length+' joueur'+(nous.length>1?'s':'')+' de '+s.clubs[s.club].name+' ('+nous.map(x=>nomDe(x[0])).join(', ')+')':'aucun joueur de '+s.clubs[s.club].name)+'. Meilleure note : '+nomDe(xv[0][0])+' ('+String(xv[0][2]/10).replace('.',',')+').');
  // Meilleur joueur du mois (toutes les 4 journées du manager) : moyenne des 4 dernières notes, 3 matchs au moins.
  st.journees=(st.journees||0)+1;
  if(st.journees%4===0){
   let best=null;
   for(const [id,j] of Object.entries(st.detail)){const d=j.slice(-4);if(d.length<3)continue;const m=d.reduce((n,r)=>n+r[4],0)/d.length;if(!best||m>best[1]||m===best[1]&&id<best[0])best=[id,m];}
   if(best){const nom=nomDe(best[0]);distinction(s,'mois',best[0],nom,s.club,Math.round(best[1]));if(typeof news==='function')news('Joueur du mois à '+s.clubs[s.club].name+' : '+nom+' ('+String(Math.round(best[1])/10).replace('.',',')+' de moyenne).');}
  }
 }
 function finSaison(){
  const s=state(),st=s?.matchNotes;if(!st||st.saison!==s.season)return;
  let best=null;
  for(const p of s.clubs[s.club]?.players||[]){const j=st.joueurs[p.id];if(!j||j.s[0]<10)continue;const m=j.s[1]/j.s[0];if(!best||m>best[1]||m===best[1]&&p.id<best[0].id)best=[p,m];}
  if(best){distinction(s,'saison',best[0].id,best[0].name,s.club,Math.round(best[1]));if(typeof news==='function')news('Joueur de la saison à '+s.clubs[s.club].name+' : '+best[0].name+' ('+String(Math.round(best[1])/10).replace('.',',')+' de moyenne sur '+st.joueurs[best[0].id].s[0]+' matchs).');}
 }
 // Validation stricte de l'état sauvegardé.
 function validate(s){
  if(!s||s.matchNotes===undefined)return true;
  const st=s.matchNotes;
  check(obj(st)&&st.version===VERSION&&int(st.saison,1,s.season)&&obj(st.joueurs)&&obj(st.detail)&&obj(st.passees)&&obj(st.confiance)&&Array.isArray(st.recompenses)&&st.recompenses.length<=MAX_RECOMPENSES,'schéma invalide');
  const nombres=(a,n)=>Array.isArray(a)&&a.length===n&&a.every(x=>int(x,0,1e7));
  for(const j of Object.values(st.joueurs))check(obj(j)&&nombres(j.s,7)&&Array.isArray(j.f)&&j.f.length<=5&&j.f.every(x=>int(x,10,100))&&j.s[1]<=j.s[0]*100,'joueur invalide');
  for(const d of Object.values(st.detail))check(Array.isArray(d)&&d.length<=MAX_DETAIL&&d.every(r=>Array.isArray(r)&&r.length===9&&int(r[0],0,100)&&int(r[1],-1,100000)&&typeof r[2]==='string'&&r[2].length<=40&&int(r[3],0,240)&&int(r[4],10,100)&&[5,6,7].every(k=>int(r[k],0,100000))&&(r[8]===0||r[8]===1)),'détail invalide');
  for(const d of Object.values(st.passees))check(Array.isArray(d)&&d.length<=MAX_PASSEES&&d.every(r=>Array.isArray(r)&&r.length===6&&int(r[0],1,s.season)&&int(r[1],-1,100000)&&int(r[2],1,500)&&int(r[3],10,100)&&int(r[4],0,10000)&&int(r[5],0,500)),'saison passée invalide');
  for(const v of Object.values(st.confiance))check(int(v,-CONFIANCE_MAX,CONFIANCE_MAX),'confiance invalide');
  for(const r of st.recompenses)check(obj(r)&&['hdm','equipe','mois','saison'].includes(r.type)&&typeof r.id==='string'&&int(r.note,10,100),'distinction invalide');
  check(st.semaine===null||obj(st.semaine)&&Array.isArray(st.semaine.notes)&&st.semaine.notes.length<=2000,'journée invalide');
  return true;
 }
 // Libellé d'une compétition enregistrée (phase France ou identifiant de compétition mondiale).
 const PHASES={league:'Championnat',barrage:'Barrage',semi:'Demi-finale',final:'Finale',playoff:'Phase finale'};
 function libelle(s,id){return PHASES[id]||s.worldMode?.leagues?.[id]?.name||String(id).replace(/[-_]/g,' ').replace(/^./,c=>c.toUpperCase());}
 // Projection (clubLife.matchNotes) : effectif du manager, détail, distinctions, dernier match.
 function project(){
  const s=state(),st=s?.matchNotes;
  const base={version:VERSION,noteDepart:calc.NOTE_DEPART,joueurs:{},recompenses:[],dernier:null};
  if(!s||!st)return base;
  const courant=st.saison===s.season;
  for(const p of s.clubs[s.club]?.players||[]){
   const j=st.joueurs[p.id],d=courant?st.detail[p.id]||[]:[],passe=st.passees[p.id]||[];
   if(!j&&!passe.length)continue;
   const n=courant&&j?j.s[0]:0;
   base.joueurs[p.id]={matchs:n,moyenne:n?Math.round(j.s[1]/n)/10:null,minutes:n?j.s[2]:0,essais:n?j.s[3]:0,plaquages:n?j.s[4]:0,metres:n?j.s[5]:0,hommeDuMatch:n?j.s[6]:0,
    forme:(j?.f||[]).map(x=>x/10),
    historique:d.slice().reverse().map(r=>({semaine:r[0],adversaire:s.clubs[r[1]]?.name||'',adversaireId:r[1],competition:libelle(s,r[2]),minutes:r[3],note:r[4]/10,essais:r[5],plaquages:r[6],metres:r[7],hommeDuMatch:r[8]===1})),
    saisons:passe.map(r=>({saison:r[0],club:s.clubs[r[1]]?.name||'',matchs:r[2],moyenne:r[3]/10,essais:r[4],hommeDuMatch:r[5]}))};
  }
  base.recompenses=st.recompenses.slice(-12).reverse();
  base.dernier=st.dernier?JSON.parse(JSON.stringify(st.dernier)):null;
  return base;
 }
 function execute(){throw Error('Notes de match : aucune commande.');}
 function installHooks(){
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
 return {project,validate,execute,installHooks,noterMatch,contexte,enregistrer,forme,moyenne,effets,rollover};
}
module.exports={files,commands,factory,moteur,...moteur()};
