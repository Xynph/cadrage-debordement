'use strict';
// Discussion avec un joueur (revue FM27, idée 23, choix de Léo du 23/11/2026) : petite fenêtre du Vestiaire, données du
// joueur à gauche, fil de discussion à droite ; un clic sur une phrase la dit tout de suite (commande
// relationship_conversation avec `phrase`, relationships.cjs). Une discussion par joueur et par semaine (règle de
// l'entretien existant).
//  - Situation du joueur (la première qui s'applique) : blessé ; mécontent du temps de jeu promis au contrat (humeur
//    « mecontent » ou « attentif » de role-contrat.cjs) ; mécontent (satisfaction < 45) ; peu utilisé (moyenne < 20 min
//    sur au moins 3 matchs suivis) ; en forme (moyenne des 3 dernières notes ≥ 7) ; sinon normal. Trois phrases par
//    situation ; un relais ou un cadre en situation normale reçoit une phrase « collectif » au lieu du soutien.
//  - Chaque phrase a une nature (écoute, soutien, éloge, critique, exigence, collectif) et une famille d'entretien
//    (ecouter / rassurer / clarifier) qui garde les effets collectifs de l'entretien (premier de la semaine : rassurer
//    moral +1, clarifier confiance du conseil +1) et le format de sauvegarde.
//  - Effet réel sur la satisfaction (déterministe, borné à ±5) = base de la nature + trait du joueur + situation +
//    hiérarchie. Le trait vient de CDLivingLockerRoom.personality (Ambitieux = le fier : la critique le braque).
//  - Hiérarchie du vestiaire : Relais (leader du groupe, CDRelationsV70.leader), Cadre (5 plus forts leaderships
//    suivants), Jeune (21 ans et moins), Groupe. Un relais entraîne le moral du groupe : effet ≥ +3 → moral +1,
//    effet ≤ −2 → moral −1 ; un cadre : effet ≤ −3 → moral −1.
//  - Attitude (6 paliers de la satisfaction : Fermé < 30 ≤ Mécontent < 45 ≤ Inexpressif < 55 ≤ Neutre < 65 ≤ Content
//    < 80 ≤ Enthousiaste) : la réponse la fait bouger d'un palier (effet ±1 à ±2) ou de deux (effet ±3 et plus).
// Fonctions pures exportées par la fabrique (tests) : effet, situation, phrases, hierarchie, palier, pas, reponse.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const NATURES=Object.freeze(['ecoute','soutien','eloge','critique','exigence','collectif']);
 const BASE=Object.freeze({ecoute:2,soutien:1,eloge:2,critique:-1,exigence:0,collectif:1});
 // Réaction du trait à chaque nature (s'ajoute à la base).
 const TRAITS=Object.freeze({
  ecoute:Object.freeze({Sensible:2,Discret:1,Loyal:1,Exigeant:-1,Competiteur:-1}),
  soutien:Object.freeze({Sensible:1,Loyal:1,Collectif:1,Protecteur:1,Ambitieux:-1,Competiteur:-1}),
  eloge:Object.freeze({Ambitieux:1,Competiteur:1,Sensible:1,Discret:-1,Exigeant:-1}),
  critique:Object.freeze({Exigeant:3,Competiteur:1,Discret:-1,Protecteur:-1,Ambitieux:-3,Sensible:-3}),
  exigence:Object.freeze({Exigeant:2,Ambitieux:1,Competiteur:1,Sensible:-1}),
  collectif:Object.freeze({Collectif:2,Protecteur:2,Loyal:1,Ambitieux:-2})});
 // Situation : ce qui pèse en plus (un blessé n'aime pas qu'on le presse, un joueur privé de minutes se méfie des mots…).
 const SITUATIONS=Object.freeze({
  blesse:Object.freeze({soutien:1,exigence:-1,critique:-1}),
  temps_jeu:Object.freeze({ecoute:1,soutien:-1,critique:-1}),
  mecontent:Object.freeze({ecoute:1,critique:-1}),
  peu_utilise:Object.freeze({soutien:1}),
  en_forme:Object.freeze({eloge:1,critique:-1}),
  normal:Object.freeze({})});
 const HIERARCHIE=Object.freeze({
  jeune:Object.freeze({soutien:1,eloge:1,critique:-1}),
  cadre:Object.freeze({ecoute:1,collectif:1}),
  relais:Object.freeze({ecoute:1,collectif:1}),
  groupe:Object.freeze({})});
 const BORNE=5;
 // Phrases de vestiaire : [id, texte, nature, famille d'entretien].
 const P=(id,texte,nature,choix)=>Object.freeze({id,texte,nature,choix});
 const PHRASES=Object.freeze({
  blesse:Object.freeze([P('blesse_ecoute','Comment va le corps ?','ecoute','ecouter'),P('blesse_patience','Prends ton temps, on t’attend.','soutien','rassurer'),P('blesse_retour','Je te veux prêt pour la reprise.','exigence','clarifier')]),
  temps_jeu:Object.freeze([P('tj_ecoute','Tu joues moins. Parle-moi.','ecoute','ecouter'),P('tj_minutes','Tes minutes vont revenir.','soutien','rassurer'),P('tj_merite','Ta place, faut la gagner.','critique','clarifier')]),
  mecontent:Object.freeze([P('mec_ecoute','Qu’est-ce qui ne va pas ?','ecoute','ecouter'),P('mec_groupe','Le groupe a besoin de toi.','collectif','rassurer'),P('mec_recadrer','Ta tête doit être au rugby.','critique','clarifier')]),
  peu_utilise:Object.freeze([P('pu_ecoute','Comment tu vis le banc ?','ecoute','ecouter'),P('pu_patience','Bosse, ta chance va venir.','soutien','rassurer'),P('pu_exigence','Montre-moi plus à l’entraînement.','exigence','clarifier')]),
  en_forme:Object.freeze([P('ef_eloge','Tu es en feu, continue.','eloge','rassurer'),P('ef_groupe','Tire les autres avec toi.','collectif','rassurer'),P('ef_exigence','Ne te relâche pas maintenant.','exigence','clarifier')]),
  normal:Object.freeze([P('n_ecoute','Dis-moi comment tu te sens.','ecoute','ecouter'),P('n_soutien','On compte sur toi.','soutien','rassurer'),P('n_critique','J’attends plus de toi.','critique','clarifier')])});
 const LEADER=P('n_leader','Le groupe te suit. Montre la voie.','collectif','rassurer');
 // Réponse du joueur : nature × sens de la réaction (+ / 0 / −).
 const REPONSES=Object.freeze({
  ecoute:['Merci de prendre le temps, coach.','Ça va. Je bosse.','Je préfère parler sur le terrain.'],
  soutien:['Ça me fait du bien. Je serai prêt.','On verra sur le terrain.','Des mots… J’attends des actes.'],
  eloge:['Merci coach. J’en veux encore.','Je fais mon boulot.','Garde ça pour la presse.'],
  critique:['Reçu. Tu vas voir la réaction.','Compris.','Tu me parles pas comme ça.'],
  exigence:['C’est clair. Je sais quoi faire.','Compris.','J’avais déjà compris.'],
  collectif:['Compte sur moi pour le groupe.','Si tu le dis.','Et moi, dans tout ça ?']});
 const ACCUEIL='Oui, coach ?';
 const SEUILS_ATTITUDE=Object.freeze([30,45,55,65,80]);
 const RULES=Object.freeze({NATURES,BASE,TRAITS,SITUATIONS,HIERARCHIE,BORNE,SEUILS_ATTITUDE});
 const borne=(x,a,b)=>Math.max(a,Math.min(b,x));
 function effet(nature,trait,situation='normal',hierarchie='groupe'){
  if(!NATURES.includes(nature))return 0;
  const n=BASE[nature]+(TRAITS[nature][trait]||0)+(SITUATIONS[situation]?.[nature]||0)+(HIERARCHIE[hierarchie]?.[nature]||0);
  return borne(n,-BORNE,BORNE);
 }
 const palier=score=>Number.isFinite(score)?SEUILS_ATTITUDE.filter(s=>score>=s).length:2;
 // Palier gagné ou perdu dans la discussion.
 const pas=e=>e>=3?2:e>0?1:e<=-3?-2:e<0?-1:0;
 const reponse=(nature,e)=>(REPONSES[nature]||REPONSES.ecoute)[e>0?0:e<0?2:1];
 // --- Lecture de l'état --------------------------------------------------------------------------------------------
 const notes=(s,id)=>{const d=s?.matchNotes?.detail?.[id];return Array.isArray(d)?d.filter(r=>Array.isArray(r)&&Number.isFinite(r[4])).map(r=>r[4]/10):[];};
 function situation(p,s=typeof S==='undefined'?null:S,tj){
  if(!p)return 'normal';
  if(Number(p.injury)>0)return 'blesse';
  const t=tj!==undefined?tj:(typeof roleContratTempsJeu==='function'?roleContratTempsJeu(p):null);
  if(t&&(t.humeur==='mecontent'||t.humeur==='attentif'))return 'temps_jeu';
  const sat=Number.isFinite(p.satisfaction?.score)?p.satisfaction.score:65;
  if(sat<45)return 'mecontent';
  if(t&&Number.isInteger(t.juges)&&t.juges>=3&&t.moyenne<20)return 'peu_utilise';
  const n=notes(s,p.id).slice(-3);
  if(n.length>=3&&n.reduce((a,b)=>a+b,0)/n.length>=7)return 'en_forme';
  return 'normal';
 }
 const leadershipDe=p=>{try{return typeof CDLivingLockerRoom!=='undefined'?CDLivingLockerRoom.personality(p)?.leadership??0:0;}catch(e){return 0;}};
 // Hiérarchie de tout le groupe : Map id → relais / cadre / jeune / groupe.
 function hierarchie(joueurs,leaderId){
  const out=new Map(),liste=Array.isArray(joueurs)?joueurs:[];
  const rangs=liste.filter(p=>p&&p.id!==leaderId).map(p=>[p.id,leadershipDe(p)]).sort((a,b)=>b[1]-a[1]||(String(a[0])<String(b[0])?-1:1));
  const cadres=new Set(rangs.slice(0,5).map(r=>r[0]));
  for(const p of liste)out.set(p.id,p.id===leaderId?'relais':cadres.has(p.id)?'cadre':Number.isFinite(p.age)&&p.age<=21?'jeune':'groupe');
  return out;
 }
 function phrases(sit,rang){
  const l=(PHRASES[sit]||PHRASES.normal).slice();
  if(sit==='normal'&&(rang==='relais'||rang==='cadre'))l[1]=LEADER;
  return l;
 }
 const trouver=id=>[...Object.values(PHRASES).flat(),LEADER].find(x=>x.id===id)||null;
 const traitDe=p=>{try{return typeof CDLivingLockerRoom!=='undefined'?String(CDLivingLockerRoom.personality(p)?.trait||''):'';}catch(e){return '';}};
 // Vue d'un joueur pour l'écran : situation, rang, attitude, phrases du moment, fil des derniers échanges.
 function vue(p,rang,s=typeof S==='undefined'?null:S){
  const sit=situation(p,s),score=Number.isFinite(p?.satisfaction?.score)?p.satisfaction.score:null;
  const log=(s?.economy?.relationLog||[]).filter(e=>e&&e.kind==='coach'&&e.playerId===p.id);
  const fil=log.slice(0,3).reverse().map(e=>{const ph=trouver(e.phrase),ef=Number.isFinite(e.effet)?e.effet:Math.round((e.minimum??0)-(e.amount??0));
   return {season:e.season,round:e.round,phrase:ph?.id??null,texte:ph?.texte??null,choice:e.detail,nature:ph?.nature??null,reponse:ph?reponse(ph.nature,ef):null,effet:ef,avant:e.amount,apres:e.minimum,
    attitudeAvant:palier(e.amount),attitudeApres:borne(palier(e.amount)+pas(ef),0,5)};});
  const cetteSemaine=p?.satisfaction?.coachMeeting?.season===s?.season&&p?.satisfaction?.coachMeeting?.week===s?.economy?.week;
  const dernier=cetteSemaine&&fil.length?fil[fil.length-1]:null;
  return {situation:sit,hierarchie:rang,attitude:dernier?dernier.attitudeApres:palier(score),attitudeAvant:dernier?dernier.attitudeAvant:palier(score),
   accueil:ACCUEIL,phrases:phrases(sit,rang).map(x=>({id:x.id,texte:x.texte,nature:x.nature,choice:x.choix})),fil,faite:!!cetteSemaine};
 }
 // Effet de la phrase choisie pour ce joueur maintenant ; null si la phrase n'est pas proposée.
 function evaluer(p,phraseId,rang,s=typeof S==='undefined'?null:S){
  const sit=situation(p,s),ph=phrases(sit,rang).find(x=>x.id===phraseId);if(!ph)return null;
  return {phrase:ph,situation:sit,effet:effet(ph.nature,traitDe(p),sit,rang)};
 }
 function moralGroupe(rang,e){
  if(rang==='relais')return e>=3?1:e<=-2?-1:0;
  if(rang==='cadre')return e<=-3?-1:0;
  return 0;
 }
 function installHooks(){globalThis.CDDiscussionJoueur={vue,evaluer,hierarchie,moralGroupe,effet,situation,palier,pas,reponse,RULES};return true;}
 return {project(){return null;},validate(){return true;},execute(){throw Error('Aucune commande de discussion.');},installHooks,
  RULES,effet,palier,pas,reponse,situation,hierarchie,phrases,trouver,vue,evaluer,moralGroupe,ACCUEIL};
}
module.exports={files,commands,factory};
