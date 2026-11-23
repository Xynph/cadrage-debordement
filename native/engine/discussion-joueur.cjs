'use strict';
// Discussion avec un joueur (revue FM27, idée 23, choix de Léo du 23/11/2026) : petite fenêtre du Vestiaire, données du
// joueur à gauche, fil de discussion à droite ; un clic sur une phrase la dit tout de suite (commande
// relationship_conversation avec `phrase`, relationships.cjs). Une discussion par joueur et par semaine.
//  - Discussion en trois tours (retour de Léo du 23/11 : « l'échange doit avoir un sens ») : une ouverture (3 au choix,
//    selon la situation), une relance qui découle de l'ouverture (2 au choix), une conclusion (2 au choix, selon la
//    situation). Chaque phrase a sa réponse : une pour une bonne réaction, une neutre, une pour une mauvaise.
//  - Situation du joueur au début de la discussion (la première qui s'applique) : blessé ; mécontent du temps de jeu
//    promis au contrat (humeur « mecontent » ou « attentif » de role-contrat.cjs) ; mécontent (satisfaction < 45) ; peu
//    utilisé (moyenne < 20 min sur au moins 3 matchs suivis) ; en forme (moyenne des 3 dernières notes ≥ 7) ; sinon
//    normal. Un relais ou un cadre en situation normale a une ouverture « collectif » à la place du soutien.
//  - Chaque phrase a une nature (écoute, soutien, éloge, critique, exigence, collectif) et une famille d'entretien
//    (ecouter / rassurer / clarifier : la famille de l'ouverture garde les effets collectifs de l'entretien et le format
//    de sauvegarde).
//  - Réaction à une phrase (déterministe) = base de la nature + trait du joueur + situation + hiérarchie, bornée à ±5 ;
//    elle choisit la réponse (> 0 bonne, 0 neutre, < 0 mauvaise). Effet sur la satisfaction : réaction entière à
//    l'ouverture, moitié (arrondie en s'éloignant de zéro) à la relance et à la conclusion ; total borné à ±6, appliqué
//    tour après tour. Le trait vient de CDLivingLockerRoom.personality (Ambitieux = le fier : la critique le braque).
//  - Hiérarchie : Relais (leader du groupe, CDRelationsV70.leader), Cadre (5 plus forts leaderships suivants), Jeune
//    (21 ans et moins), Groupe. À la conclusion, un relais entraîne le moral du groupe (total ≥ +3 → +1, ≤ −2 → −1),
//    un cadre seulement vers le bas (total ≤ −3 → −1).
//  - Attitude (6 paliers de la satisfaction : Fermé < 30 ≤ Mécontent < 45 ≤ Inexpressif < 55 ≤ Neutre < 65 ≤ Content
//    < 80 ≤ Enthousiaste) : palier du début ± 1 (total ±1 à ±2) ou ± 2 (total ±3 et plus).
//  - Sauvegarde : l'entrée « coach » de S.economy.relationLog porte le chemin (ids des phrases), les réactions de chaque
//    tour, la situation et la hiérarchie du début, et l'effet total.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const NATURES=Object.freeze(['ecoute','soutien','eloge','critique','exigence','collectif']);
 const BASE=Object.freeze({ecoute:2,soutien:1,eloge:2,critique:-1,exigence:0,collectif:1});
 const TRAITS=Object.freeze({
  ecoute:Object.freeze({Sensible:2,Discret:1,Loyal:1,Exigeant:-1,Competiteur:-1}),
  soutien:Object.freeze({Sensible:1,Loyal:1,Collectif:1,Protecteur:1,Ambitieux:-1,Competiteur:-1}),
  eloge:Object.freeze({Ambitieux:1,Competiteur:1,Sensible:1,Discret:-1,Exigeant:-1}),
  critique:Object.freeze({Exigeant:3,Competiteur:1,Discret:-1,Protecteur:-1,Ambitieux:-3,Sensible:-3}),
  exigence:Object.freeze({Exigeant:2,Ambitieux:1,Competiteur:1,Sensible:-1}),
  collectif:Object.freeze({Collectif:2,Protecteur:2,Loyal:1,Ambitieux:-2})});
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
 const BORNE=5,BORNE_TOTAL=6,TOURS=3;
 // Phrases : id → [texte, nature, famille, [réponse bonne, neutre, mauvaise], relances (ouvertures seulement)].
 const N=(texte,nature,choix,reponses,suite)=>Object.freeze({texte,nature,choix,reponses:Object.freeze(reponses),...(suite?{suite:Object.freeze(suite)}:{})});
 const NOEUDS=Object.freeze({
  // Blessé.
  b_corps:N('Comment va le corps ?','ecoute','ecouter',['Ça revient, doucement.','Ça tire encore un peu.','Mal. Et ça me rend fou.'],['b_kine','b_tete']),
  b_patience:N('Prends ton temps, on t’attend.','soutien','rassurer',['Merci. J’avais peur pour ma place.','Du temps, j’en ai, là.','Je veux pas de temps, je veux jouer.'],['b_place','b_tete']),
  b_reprise:N('Je te veux prêt pour la reprise.','exigence','clarifier',['Je serai prêt, je bosse double.','Je fais ce que dit le kiné.','Tu crois que je traîne exprès ?'],['b_kine','b_place']),
  b_kine:N('Tu bosses bien avec le kiné ?','ecoute','ecouter',['Oui, il me pousse bien.','On fait les exercices.','Ses exercices, j’en peux plus.']),
  b_tete:N('Et la tête, ça tient ?','ecoute','ecouter',['Oui, je reste avec le groupe.','Ça dépend des jours.','Je tourne en rond chez moi.']),
  b_place:N('Ta place, personne te la prend.','soutien','rassurer',['Ça, ça fait du bien à entendre.','On verra à mon retour.','Le petit qui joue est bon, pourtant.']),
  b_fin_vestiaire:N('Viens au vestiaire les jours de match.','collectif','rassurer',['Je serai là, promis.','Si le kiné veut bien.','Regarder les autres jouer ? Non merci.']),
  b_fin_retour:N('On se fixe une date de retour.','exigence','clarifier',['Ok. Ça me donne un cap.','Si le corps suit.','Arrête de me presser.']),
  // Temps de jeu promis non tenu.
  tj_ecoute:N('Tu joues moins. Parle-moi.','ecoute','ecouter',['J’ai signé pour jouer, coach.','Rien à dire. Je regarde.','Tu sais très bien ce qui va pas.'],['tj_pourquoi','tj_attente']),
  tj_minutes:N('Tes minutes vont revenir.','soutien','rassurer',['J’y crois. Faut que ça vienne.','On m’a déjà dit ça.','Des mots. Moi, je veux le terrain.'],['tj_attente','tj_concurrence']),
  tj_merite:N('Ta place, faut la gagner.','critique','clarifier',['Ok. Je vais te la prendre.','Je fais quoi de plus ?','J’ai signé pour jouer, pas pour ça !'],['tj_pourquoi','tj_concurrence']),
  tj_pourquoi:N('Je t’explique mes choix.','exigence','clarifier',['Ok, je comprends mieux.','Si tu le dis.','Tes choix, je les subis.']),
  tj_attente:N('Qu’est-ce que t’attends de moi ?','ecoute','ecouter',['Juste qu’on me fasse confiance.','Des minutes, c’est tout.','Que tu tiennes parole.']),
  tj_concurrence:N('L’autre est en forme, c’est tout.','critique','clarifier',['Alors je vais être meilleur.','Ça peut tourner.','Il est pas meilleur que moi.']),
  tj_fin_chance:N('Ta chance arrive, sois prêt.','soutien','rassurer',['Je serai prêt.','On verra bien.','J’attends de voir.']),
  tj_fin_jeudi:N('Montre-le-moi à l’entraînement.','exigence','clarifier',['Regarde-moi bien jeudi.','Comme d’habitude.','Je fais que ça, coach.']),
  // Mécontent.
  mec_ecoute:N('Qu’est-ce qui va pas ?','ecoute','ecouter',['Je me sens un peu seul, en ce moment.','Rien. La fatigue.','Comme si ça t’intéressait.'],['mec_detail','mec_groupe2']),
  mec_groupe:N('Le groupe a besoin de toi.','collectif','rassurer',['Je sais. Je vais pas lâcher.','Le groupe, ça va.','Et moi, j’ai besoin de quoi ?'],['mec_detail','mec_compte']),
  mec_recadrer:N('Ta tête doit être au rugby.','critique','clarifier',['T’as raison. Je me reprends.','Elle y est.','Commence pas à me faire la leçon.'],['mec_compte','mec_exemple']),
  mec_detail:N('Raconte. Ça reste entre nous.','ecoute','ecouter',['Merci. Ça fait du bien de le dire.','Y’a pas grand-chose à raconter.','Non. Je garde ça pour moi.']),
  mec_groupe2:N('Les gars t’aiment bien, tu sais.','collectif','rassurer',['Ça me touche. Vraiment.','Ouais, peut-être.','Ils le montrent pas beaucoup.']),
  mec_compte:N('Je compte sur toi, pour de vrai.','soutien','rassurer',['Alors je vais te le rendre.','On verra.','Tu dis ça à tout le monde.']),
  mec_exemple:N('Les jeunes te regardent.','collectif','rassurer',['Ouais. Je vais montrer l’exemple.','Ils ont pas besoin de moi.','C’est pas mon boulot.']),
  mec_fin_porte:N('Ma porte reste ouverte.','soutien','rassurer',['Merci coach, je viendrai.','Ok.','On verra si elle l’est.']),
  mec_fin_reaction:N('J’attends une réaction samedi.','exigence','clarifier',['Tu l’auras.','On fera le max.','Mets-moi la pression, tiens.']),
  // Peu utilisé.
  pu_ecoute:N('Comment tu vis le banc ?','ecoute','ecouter',['Pas facile, mais je m’accroche.','Je fais avec.','Mal. Très mal.'],['pu_detail','pu_plans']),
  pu_patience:N('Bosse, ta chance va venir.','soutien','rassurer',['Je bosse, t’inquiète.','Elle arrive quand ?','Ça fait des semaines que j’attends.'],['pu_plans','pu_agressif']),
  pu_exigence:N('Montre-moi plus à l’entraînement.','exigence','clarifier',['Ok, tu vas voir cette semaine.','Je donne déjà tout.','Tu regardes même pas les entraînements.'],['pu_agressif','pu_detail']),
  pu_detail:N('Qu’est-ce qui te manque, selon toi ?','ecoute','ecouter',['Du rythme. Juste des minutes.','Je sais pas trop.','Rien. C’est toi qui vois pas.']),
  pu_plans:N('T’es dans mes plans, crois-moi.','soutien','rassurer',['Ça me rassure, coach.','Si tu le dis.','Tes plans, je les vois pas.']),
  pu_agressif:N('Je te veux plus agressif.','exigence','clarifier',['Agressif, je sais faire.','Je vais essayer.','Je suis pas un bourrin.']),
  pu_fin_samedi:N('Sois prêt, tu peux entrer samedi.','soutien','rassurer',['Je serai prêt à entrer.','Si tu m’appelles.','On m’a déjà fait le coup.']),
  pu_fin_point:N('On refait le point dans un mois.','exigence','clarifier',['Ça marche. Tu verras la différence.','Ok.','Un mois de plus sur le banc ?']),
  // En forme.
  ef_eloge:N('Tu es en feu, continue.','eloge','rassurer',['Merci coach. J’en veux encore.','Je fais mon boulot.','Garde ça pour la presse.'],['ef_declic','ef_vise']),
  ef_groupe:N('Tire les autres avec toi.','collectif','rassurer',['Compte sur moi pour le groupe.','Je fais déjà mon match.','Chacun son match, coach.'],['ef_jeunes','ef_vise']),
  ef_exigence:N('Ne te relâche pas maintenant.','exigence','clarifier',['Aucun risque, j’ai faim.','Je me relâche pas.','Tu me trouves jamais assez bien ?'],['ef_declic','ef_jeunes']),
  ef_declic:N('C’est quoi, le déclic ?','ecoute','ecouter',['Je me sens libre sur le terrain.','Je sais pas, ça sourit.','J’en parle pas, ça porte malheur.']),
  ef_jeunes:N('Les jeunes te regardent jouer.','collectif','rassurer',['Je vais les prendre sous mon aile.','Qu’ils regardent, ça peut aider.','J’ai assez à gérer avec mon match.']),
  ef_vise:N('Tu vises quoi, cette saison ?','ecoute','ecouter',['Le titre. Et pourquoi pas une sélection.','Le prochain match, c’est tout.','Que tu me laisses jouer mon jeu.']),
  ef_fin_fiers:N('Continue comme ça, on est fiers.','eloge','rassurer',['Merci coach, ça compte.','Ok, on continue.','Pas besoin d’en faire trop.']),
  ef_fin_samedi:N('Samedi, je veux la même chose.','exigence','clarifier',['Tu l’auras, et même plus.','Je ferai de mon mieux.','Lâche-moi un peu, coach.']),
  // Normal.
  n_ecoute:N('Dis-moi comment tu te sens.','ecoute','ecouter',['Bien. Je me sens en forme.','Ça va. Je bosse.','Ça va. On a fini ?'],['n_objectif','n_groupe']),
  n_soutien:N('On compte sur toi.','soutien','rassurer',['Merci, je serai là.','Je sais.','Comme sur tout le monde, non ?'],['n_objectif','n_details']),
  n_critique:N('J’attends plus de toi.','critique','clarifier',['Ok. Tu vas voir.','Plus comment ?','Je donne déjà tout, moi.'],['n_details','n_groupe']),
  n_leader:N('Le groupe te suit. Montre la voie.','collectif','rassurer',['Je vais parler aux gars.','Je fais ce que je peux.','C’est ton boulot, pas le mien.'],['n_objectif','n_groupe']),
  n_objectif:N('Tu te fixes quoi, cette saison ?','ecoute','ecouter',['Être titulaire. Et gagner.','Jouer le plus possible.','Je verrai bien.']),
  n_details:N('Plus de rigueur sur les détails.','exigence','clarifier',['Les détails, je m’y mets.','D’accord, je vais y bosser.','Toujours les mêmes reproches.']),
  n_groupe:N('Avec le groupe, ça se passe bien ?','ecoute','ecouter',['Super. On est soudés.','Ça va, pas de souci.','Avec certains, c’est tendu.']),
  n_fin_confiance:N('Je te fais confiance.','soutien','rassurer',['Je te décevrai pas.','Merci.','On verra ça samedi.']),
  n_fin_samedi:N('Montre-le samedi.','exigence','clarifier',['Compte sur moi.','Je vais essayer.','Comme chaque samedi.'])});
 const ARBRES=Object.freeze({
  blesse:Object.freeze({ouvertures:['b_corps','b_patience','b_reprise'],fins:['b_fin_vestiaire','b_fin_retour']}),
  temps_jeu:Object.freeze({ouvertures:['tj_ecoute','tj_minutes','tj_merite'],fins:['tj_fin_chance','tj_fin_jeudi']}),
  mecontent:Object.freeze({ouvertures:['mec_ecoute','mec_groupe','mec_recadrer'],fins:['mec_fin_porte','mec_fin_reaction']}),
  peu_utilise:Object.freeze({ouvertures:['pu_ecoute','pu_patience','pu_exigence'],fins:['pu_fin_samedi','pu_fin_point']}),
  en_forme:Object.freeze({ouvertures:['ef_eloge','ef_groupe','ef_exigence'],fins:['ef_fin_fiers','ef_fin_samedi']}),
  normal:Object.freeze({ouvertures:['n_ecoute','n_soutien','n_critique'],fins:['n_fin_confiance','n_fin_samedi']})});
 const ACCUEIL='Oui, coach ?';
 const SEUILS_ATTITUDE=Object.freeze([30,45,55,65,80]);
 const RULES=Object.freeze({NATURES,BASE,TRAITS,SITUATIONS,HIERARCHIE,BORNE,BORNE_TOTAL,TOURS,SEUILS_ATTITUDE});
 const borne=(x,a,b)=>Math.max(a,Math.min(b,x));
 function effet(nature,trait,situation='normal',hierarchie='groupe'){
  if(!NATURES.includes(nature))return 0;
  const n=BASE[nature]+(TRAITS[nature][trait]||0)+(SITUATIONS[situation]?.[nature]||0)+(HIERARCHIE[hierarchie]?.[nature]||0);
  return borne(n,-BORNE,BORNE);
 }
 // Effet d'un tour sur la satisfaction : réaction entière à l'ouverture, moitié ensuite.
 const poids=(reaction,tour)=>tour===0?reaction:Math.sign(reaction)*Math.ceil(Math.abs(reaction)/2);
 const total=effets=>borne(effets.reduce((n,r,i)=>n+poids(r,i),0),-BORNE_TOTAL,BORNE_TOTAL);
 const palier=score=>Number.isFinite(score)?SEUILS_ATTITUDE.filter(s=>score>=s).length:2;
 const pas=e=>e>=3?2:e>0?1:e<=-3?-2:e<0?-1:0;
 const noeud=id=>Object.hasOwn(NOEUDS,id)?NOEUDS[id]:null;
 const reponse=(id,reaction)=>{const n=noeud(id);return n?n.reponses[reaction>0?0:reaction<0?2:1]:null;};
 // Phrases proposées au tour `chemin.length` d'une discussion commencée dans cette situation.
 function options(sit,rang,chemin=[]){
  const a=ARBRES[sit]||ARBRES.normal;
  if(chemin.length===0){const l=a.ouvertures.slice();if(sit==='normal'&&(rang==='relais'||rang==='cadre'))l[1]='n_leader';return l;}
  if(chemin.length===1)return (noeud(chemin[0])?.suite||[]).slice();
  if(chemin.length===2)return a.fins.slice();
  return [];
 }
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
 function hierarchie(joueurs,leaderId){
  const out=new Map(),liste=Array.isArray(joueurs)?joueurs:[];
  const rangs=liste.filter(p=>p&&p.id!==leaderId).map(p=>[p.id,leadershipDe(p)]).sort((a,b)=>b[1]-a[1]||(String(a[0])<String(b[0])?-1:1));
  const cadres=new Set(rangs.slice(0,5).map(r=>r[0]));
  for(const p of liste)out.set(p.id,p.id===leaderId?'relais':cadres.has(p.id)?'cadre':Number.isFinite(p.age)&&p.age<=21?'jeune':'groupe');
  return out;
 }
 const traitDe=p=>{try{return typeof CDLivingLockerRoom!=='undefined'?String(CDLivingLockerRoom.personality(p)?.trait||''):'';}catch(e){return '';}};
 const SITS=Object.keys(ARBRES),RANGS=Object.keys(HIERARCHIE);
 // Entrée « coach » de la discussion de cette semaine (la plus récente du joueur), si elle a un chemin.
 function entreeDeLaSemaine(p,s=typeof S==='undefined'?null:S){
  const m=p?.satisfaction?.coachMeeting;
  if(!(m&&m.season===s?.season&&m.week===s?.economy?.week))return null;
  const e=(s?.economy?.relationLog||[]).find(x=>x&&x.kind==='coach'&&x.playerId===p.id);
  return e&&e.season===s.season&&Array.isArray(e.chemin)?e:null;
 }
 // Tours d'une entrée sauvegardée : phrase dite, réponse, effet du tour.
 function tours(e){
  const chemin=Array.isArray(e?.chemin)?e.chemin:[],reactions=Array.isArray(e?.reactions)?e.reactions:[];
  return chemin.map((id,i)=>{const n=noeud(id),r=Number.isFinite(reactions[i])?reactions[i]:0;
   return {phrase:id,texte:n?.texte??null,nature:n?.nature??null,choice:n?.choix??null,reponse:reponse(id,r),reaction:r,effet:poids(r,i)};});
 }
 // Vue d'un joueur pour l'écran : situation, rang, attitude, phrases du tour, fil de la dernière discussion.
 function vue(p,rang,disponible=true,s=typeof S==='undefined'?null:S){
  const score=Number.isFinite(p?.satisfaction?.score)?p.satisfaction.score:null;
  const semaine=entreeDeLaSemaine(p,s);
  const faiteAncienne=!semaine&&p?.satisfaction?.coachMeeting?.season===s?.season&&p?.satisfaction?.coachMeeting?.week===s?.economy?.week;
  const sit=semaine&&SITS.includes(semaine.situation)?semaine.situation:situation(p,s);
  const r=semaine&&RANGS.includes(semaine.rang)?semaine.rang:rang;
  const chemin=semaine?semaine.chemin:[];
  const fini=faiteAncienne||chemin.length>=TOURS;
  const derniere=semaine||(s?.economy?.relationLog||[]).find(x=>x&&x.kind==='coach'&&x.playerId===p.id&&Array.isArray(x.chemin))||null;
  const avant=semaine&&Number.isFinite(semaine.amount)?semaine.amount:score;
  const tot=semaine?total(semaine.reactions||[]):0;
  return {situation:sit,hierarchie:r,tour:chemin.length,tours:TOURS,faite:fini,enCours:!!semaine&&!fini,
   attitudeAvant:palier(avant),attitude:semaine?borne(palier(avant)+pas(tot),0,5):palier(score),effet:tot,avant,
   accueil:ACCUEIL,phrases:disponible&&!fini?options(sit,r,chemin).map(id=>({id,texte:NOEUDS[id].texte,nature:NOEUDS[id].nature,choice:NOEUDS[id].choix})):[],
   fil:derniere?{season:derniere.season,round:derniere.round,courante:!!semaine,avant:derniere.amount,apres:derniere.minimum,effet:Number.isFinite(derniere.effet)?derniere.effet:total(derniere.reactions||[]),tours:tours(derniere)}:null};
 }
 // Tour suivant de la discussion : phrase proposée maintenant ? réaction, effet total après ce tour.
 function evaluer(p,phraseId,rang,s=typeof S==='undefined'?null:S){
  const semaine=entreeDeLaSemaine(p,s);
  if(!semaine&&p?.satisfaction?.coachMeeting?.season===s?.season&&p?.satisfaction?.coachMeeting?.week===s?.economy?.week)return null;
  const sit=semaine?semaine.situation:situation(p,s),r=semaine?semaine.rang:rang,chemin=semaine?semaine.chemin:[];
  if(chemin.length>=TOURS||!options(sit,r,chemin).includes(phraseId))return null;
  const n=NOEUDS[phraseId],reaction=effet(n.nature,traitDe(p),sit,r),reactions=[...(semaine?.reactions||[]),reaction];
  return {phrase:{id:phraseId,...n},situation:sit,rang:r,tour:chemin.length,reaction,reactions,total:total(reactions),entree:semaine,fin:reactions.length>=TOURS};
 }
 function moralGroupe(rang,e){
  if(rang==='relais')return e>=3?1:e<=-2?-1:0;
  if(rang==='cadre')return e<=-3?-1:0;
  return 0;
 }
 function installHooks(){globalThis.CDDiscussionJoueur={vue,evaluer,hierarchie,moralGroupe,effet,situation,palier,pas,reponse,total,RULES};return true;}
 return {project(){return null;},validate(){return true;},execute(){throw Error('Aucune commande de discussion.');},installHooks,
  RULES,NOEUDS,ARBRES,effet,poids,total,palier,pas,reponse,options,situation,hierarchie,tours,vue,evaluer,moralGroupe,ACCUEIL};
}
module.exports={files,commands,factory};
