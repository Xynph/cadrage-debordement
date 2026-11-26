'use strict';
// Match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0) : projection `live.direct` du modèle.
//
// Lecture seule. La sélection vient de match-highlights.cjs (`en_direct`) ; ce module
// y ajoute ce que l'écran doit afficher : les scènes 3D des plans à rejouer, le fil,
// la zone de jeu, quelques chiffres. Rien n'est écrit dans la carrière, aucun tirage
// n'est consommé : avec ou sans cette projection, le match simulé est le même.
const selection=require('./match-highlights.cjs');
const choregraphe=require('./match-choregraphe.cjs');
const notesMatch=require('./match-notes.cjs');
const feuilleStats=require('./match-stats.cjs');
const pourquoi=require('./match-pourquoi.cjs');
const {zone22}=require('./match-zone22.cjs');
const bonusFin=require('./match-bonus.cjs');

const NIVEAUX=Object.freeze(Object.keys(selection.NIVEAUX));
const LIBELLES=Object.freeze({aucun:'Commentaire seul',resume:'Résumé',cles:'Temps forts clés',etendus:'Temps forts étendus',dynamique:'Dynamique',integral:'Match complet'});
const TYPES=Object.freeze({
 essai:'Essai',penalite_reussie:'Pénalité',penalite_manquee:'Pénalité manquée',carton_rouge:'Carton rouge',carton_jaune:'Carton jaune',
 essai_refuse:'En-avant dans l’en-but',ballon_tenu_en_but:'Ballon tenu en but',en_but_sous_pression:'En-but sous pression',en_but_defendu:'En-but défendu',ballon_mort:'Ballon mort',
 cinquante_22:'50:22',touche_5m:'Touche près de la ligne',melee_5m:'Mêlée près de la ligne',ballon_porte:'Ballon porté',franchissement:'Franchissement',
 pres_de_la_ligne:'Près de la ligne',entree_dans_les_22:'Entrée dans les 22',jeu_dans_les_22:'Jeu dans les 22',progression:'Progression',pression_dans_les_22:'Pression dans les 22',
 ballon_sauve:'Ballon sauvé',ballon_gratte_haut:'Ballon gratté',conquete_volee:'Conquête volée',ballon_recupere:'Ballon récupéré',coup_d_envoi:'Coup d’envoi',reprise:'Reprise',
 fin_de_match_serree:'Fin de match',long_jeu_au_pied:'Jeu au pied',penalite_sifflee:'Pénalité sifflée',penalite_jouee_a_la_main:'Pénalité jouée à la main',faute_de_main:'Faute de main',sortie_en_touche:'Sortie en touche',
 jeu_courant:'Jeu courant',suite_de_l_action:'L’action continue',jeu:'Le match'
});

// Fonctions sérialisées dans la machine du moteur. Elles lisent le match en cours
// sans le modifier : le curseur de présentation est toujours remis à sa place.
function lecteur(){
 const sceneDe=(l,index)=>{
  const p=playback(l),curseur=p.cursor;p.cursor=index;
  try{return CDMatch3DAdapter.normalize(matchScene(l))}finally{p.cursor=curseur}
 };
 return {
  scenes(indices){const l=S.live;return indices.map(i=>l&&Number.isInteger(i)&&l.events[i]?.scene?sceneDe(l,i):null)},
  // Plan déduit, sans événement : le buteur face aux poteaux après un essai.
  transformation(index,reussie){
   const l=S.live,record=l?.events[index]?.scene;if(!record||record.kind!=='try')return null;
   const scene=sceneDe(l,index),side=record.team,but=attackingGoal(side);
   const y=Math.max(5,Math.min(65,record.to.y)),depart={x:but+(side===0?-22:22),y};
   const buteur=chooseScorer(S.clubs[l.pair[side]],record.on[side].filter(Boolean))?.id;
   const players=scene.players.map(p=>p.id===String(buteur)&&p.side===side?{...p,...depart,featured:true}:{...p,featured:false});
   return {...scene,key:scene.key+':transformation',kind:reussie?'goal':'miss',players,origin:depart,ball:{x:but,y:reussie?35:y>=35?43:27},possession:side};
  },
  // Profils physiques (chorégraphe) : compétence « Vitesse », forme comprise, sans rien écrire.
  profils(ids){
   const l=S.live,out={};if(!l)return out;
   for(const id of ids)for(let side=0;side<2;side++){
    const p=matchPlayer(l,side,id);
    if(p&&p.skills)out[id]={side,vitesse:skill(p,'speed',true)};
   }
   return out;
  },
  etat(){
   const l=S.live;if(!l)return null;
   const cartons=l.userSide>=0?l.sheets[l.userSide].cards.map(c=>({id:c.id,nom:matchPlayer(l,l.userSide,c.id)?.name||'',retour:c.until})):[];
   // Effectif adverse du jour (titulaires et remplaçants) : nom, poste et état visible de chacun.
   const eux=l.userSide>=0?1-l.userSide:-1,feuille=eux>=0?l.sheets[eux]:null;
   const effectifAdverse=feuille?[...feuille.on,...(feuille.bench||[])].filter(Boolean).map(id=>{const p=matchPlayer(l,eux,id);return p?{id:String(p.id),name:p.name,pos:p.pos,condition:Math.round(p.condition??100)}:null}).filter(Boolean):[];
   // XV adverse actuel (demande de Léo : ses remplacements se voient tout de suite).
   const xvAdverseActuel=feuille?feuille.on.map(id=>id==null?null:String(id)):[];
   // Contexte de la note de match (feuille, minutes, niveau au poste), même calcul qu'en fin de match.
   const notes=typeof CDMatchNotes!=='undefined'?CDMatchNotes.contexte(l):null;
   // Énergie moyenne des deux XV sur le terrain (« Pourquoi » d'après-match, match-pourquoi.cjs).
   const energie=l.userSide>=0?[l.userSide,1-l.userSide].map(side=>{const on=l.sheets[side].on.map(id=>id==null?null:matchPlayer(l,side,id)).filter(Boolean);return on.length?Math.round(on.reduce((n,p)=>n+(p.condition??100),0)/on.length):null;}):null;
   // Barème du bonus de la rencontre (match-bonus.cjs), null hors phase de classement.
   const bonus=typeof nativeMatchBonus!=='undefined'?nativeMatchBonus.regleDuMatch(l):null;
   return {bonus,notes,energie,rencontre:[S.season,S.round,S.phase,l.pair.join('-')].join(':'),horloge:matchClock(l),camp:l.userSide,possession:l.possession,territoire:l.territory,cartons,effectifAdverse,xvAdverseActuel,
    tactique:l.tacticalStats?l.tacticalStats.map(s=>({longGains:s.longGains,handErrors:s.handErrors,metres:Math.round(s.metres)})):null};
  }
 };
}

// Légende d'un plan : jamais le résultat avant l'image. Le texte de l'essai annonce déjà
// sa transformation et le score ; ils sont retirés de la légende (affichage seulement).
function legende(plan,texte){
 if(plan.kind==='transformation')return plan.reussie?'Transformation réussie.':'Transformation manquée.';
 if(plan.kind!=='try')return texte;
 const coupe=texte.search(/, transform/);
 return coupe>0?texte.slice(0,coupe)+'.':'Essai.';
}
const ANNONCES=Object.freeze({goal:'Tir au but.',miss:'Tir au but.',transformation:'Transformation.'});
const horloge=l=>{const limite=l.periode===1?40:80;return l.minute>limite?limite+'+'+(l.minute-limite)+'′':l.minute+'′'};
const point=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.y)?{x:Math.max(0,Math.min(100,p.x)),y:Math.max(0,Math.min(70,p.y))}:null;

// Mises en scène déjà calculées (le temps fort reste le même pendant plusieurs pas).
const CHOREGRAPHIES=new Map();
// Chorégraphie d'un temps fort (CD_MATCH_CHOREGRAPHE=1) : essai en jeu courant, franchissement
// sans essai, jeu au pied et chasse, avec les plans qui les amènent (remise en jeu, récupération,
// temps de jeu). Présentation seule : en cas d'échec, le temps fort part sans elle (repli de la vue).
function choregraphier(tf,plans,events,lire){
 const cle=tf.cle+'|'+plans.map(p=>p.index).join(',');
 if(CHOREGRAPHIES.has(cle))return CHOREGRAPHIES.get(cle);
 // Scène affichée avant le premier plan quand le temps fort n'a pas de départ (suite d'action).
 let avant=null;
 if(!tf.depart){
  const idx=plans[0].index;
  for(let i=idx-1;i>=0&&avant===null;i--){const e=events[i];if(e?.scene&&!['advantage','card','break','end'].includes(e.scene.kind))avant=lire.scenes([i])[0]}
 }
 let base=choregraphe.entreeDepuisTempsFort({...tf,plans},events,{avant,cle:tf.cle});
 if(!base){CHOREGRAPHIES.set(cle,null);return null}
 const ids=base.joueurs.map(p=>p.id),bruts=typeof lire.profils==='function'?lire.profils(ids):{},profils={};
 for(const p of base.joueurs)profils[p.id]=choregraphe.profil(p.slot,bruts[p.id]?.vitesse);
 let c=null;
 try{c=choregraphe.composer({...base,profils});}
 catch(error){
  // Longue action (remise en jeu puis nombreux temps de jeu) : même la mise en scène la plus courte dépasse le plafond
  // de durée. Plutôt que de ne rien montrer, l'action est reprise plus tard (un fait de moins en amont à chaque essai),
  // depuis la scène affichée juste avant le premier fait gardé ; le fait clé et sa suite restent montrés.
  const duree=e=>e instanceof RangeError&&/durée voulue/.test(e.message);
  const amont=base.etapes.filter(s=>!s.cle&&s.plan!==undefined&&s.plan<base.dernier).length;
  if(!duree(error)||amont<1)throw error;
  for(let limite=amont-1;limite>=0&&!c;limite--){
   const court=choregraphe.entreeDepuisTempsFort({...tf,plans},events,{avant,cle:tf.cle,limiteAmont:limite});
   if(!court)break;
   const manquants=court.joueurs.filter(p=>!profils[p.id]).map(p=>p.id),autres=manquants.length&&typeof lire.profils==='function'?lire.profils(manquants):{};
   for(const p of court.joueurs)if(!profils[p.id])profils[p.id]=choregraphe.profil(p.slot,autres[p.id]?.vitesse);
   try{c=choregraphe.composer({...court,profils});base=court;}
   catch(retry){if(!duree(retry))throw retry;}
  }
  if(!c)throw error;
 }
 // Outil de test (options.choregraphe === 'entrees') : l'entrée est jointe, pour en faire un jeu d'essai.
 Object.defineProperty(c,'entree',{value:{...base,profils},enumerable:false});
 CHOREGRAPHIES.set(cle,c);
 while(CHOREGRAPHIES.size>8)CHOREGRAPHIES.delete(CHOREGRAPHIES.keys().next().value);
 return c;
}

// --- Entracte en 2D (vue de dessus, façon « match overview ») ----------------------------
// Tout ce qui suit est lu dans le journal, sans rien écrire ni tirer : le moteur reste la
// source de vérité, la vue 2D ne fait qu'interpoler entre ces images.
const SANS_IMAGE=new Set(['message','advantage','card','sub','tactic','break','end']);
// Minutes de jeu montré avant d'afficher possession et occupation et de lire les tendances.
const ECHANTILLON_MINUTES=10;
const DEROULE_MAX=14;
const r1=n=>Math.round(n*10)/10;
// Scènes déjà calculées (une scène passée ne change plus, sauf la toute dernière).
const SCENES_2D=new Map();
function compacte(scene){
 if(!scene||!Array.isArray(scene.players))return null;
 return {kind:scene.kind,possession:scene.possession,periode:scene.period,ballon:[r1(scene.ball.x),r1(scene.ball.y)],origine:[r1(scene.origin.x),r1(scene.origin.y)],
  joueurs:scene.players.map(p=>[p.side,p.slot,r1(p.x),r1(p.y),p.featured?1:0,p.id])};
}
// Derniers faits jouables, chacun avec la place des trente joueurs que le moteur leur donne
// (la même que la vue 3D) : la vue 2D les rejoue dans l'ordre pendant l'entracte.
function deroule(lignes,events,lire,rencontre,nommer=t=>String(t||'')){
 const derniere=lignes.length?lignes[lignes.length-1]:null;if(!derniere)return [];
 const retenues=lignes.filter(l=>!l.bandeau&&!SANS_IMAGE.has(l.kind)&&events[l.i]?.scene&&derniere.minute-l.minute<=4&&l.periode===derniere.periode).slice(-DEROULE_MAX);
 // Clé : la rencontre (saison, journée, affiche) ne suffit pas (même affiche rejouée depuis une
 // sauvegarde, autre carrière dans le même processus) : on y joint l'empreinte du fait.
 const cle=i=>{const s=events[i]?.scene||{};return rencontre+'|'+i+'|'+(events[i]?.min??'')+'|'+s.kind+'|'+s.team+'|'+s.possession+'|'+s.from?.x+','+s.from?.y+'|'+s.to?.x+','+s.to?.y+'|'+String(events[i]?.text||'').length};
 const manquants=retenues.filter(l=>!SCENES_2D.has(cle(l.i))||l.i>=events.length-2).map(l=>l.i);
 if(manquants.length){
  const scenes=lire.scenes(manquants);
  manquants.forEach((i,n)=>SCENES_2D.set(cle(i),compacte(scenes[n])));
  while(SCENES_2D.size>96)SCENES_2D.delete(SCENES_2D.keys().next().value);
 }
 return retenues.map(l=>{
  const s=events[l.i].scene,scene=SCENES_2D.get(cle(l.i));
  if(!scene)return null;
  return {i:l.i,horloge:horloge(l),minute:l.minute,kind:l.kind,equipe:l.equipe,move:s.move||null,porte:s.porte===true,cause:s.cause||null,
   gain:Number.isFinite(s.from?.x)&&Number.isFinite(s.to?.x)?r1(Math.abs(s.to.x-s.from.x)):0,score:l.scoreApres,...(l.kind==='try'?{transformation:l.transformation===true}:{}),texte:nommer(events[l.i].text),scene};
 }).filter(Boolean);
}
// Domination minute par minute, de -100 (l'équipe qui reçoit, côté 1, domine) à +100 (côté 0) :
// occupation (où se joue le ballon), possession, points et franchissements. Lissée comme une
// courbe d'élan : une minute sans fait laisse retomber la courbe vers l'équilibre.
function domination(lignes){
 const parMinute=new Map();let fin=0,miTemps=null;
 for(const l of lignes){
  if(l.kind==='break'&&miTemps===null)miTemps=l.minute;
  if(l.bandeau||SANS_IMAGE.has(l.kind))continue;
  const m=Math.max(1,l.minute);fin=Math.max(fin,m);
  const a=parMinute.get(m)||{terrain:0,n:0,possession:0,points:0};
  if(l.x!==null){a.terrain+=(l.x-50)/50;a.n++}
  if(l.possession!==null)a.possession+=l.possession===0?1:-1;
  const marques=[0,1].map(s=>(l.scoreApres[s]||0)-(l.scoreAvant[s]||0));
  a.points+=(marques[0]-marques[1])/7;
  if(l.kind==='carry'&&l.equipe!==null&&l.x!==null&&l.depuis!==null&&Math.abs(l.x-l.depuis)>=22)a.points+=l.equipe===0?.35:-.35;
  parMinute.set(m,a);
 }
 const courbe=[];let lisse=0,premiere=true;
 for(let m=1;m<=fin;m++){
  const a=parMinute.get(m);
  if(!a){lisse*=.82;courbe.push(Math.round(lisse*100));continue}
  const brut=Math.max(-1,Math.min(1,(a.n?a.terrain/a.n*.6:0)+(a.possession/Math.max(1,a.n||1))*.25+a.points*.6));
  // Première minute jouée : pas de lissage (la courbe se lit dès le coup d'envoi).
  lisse=premiere?brut:lisse*.55+brut*.45;premiere=false;
  courbe.push(Math.round(Math.max(-1,Math.min(1,lisse))*100));
 }
 return {minutes:courbe,miTemps};
}
// Rapport de l'analyste vidéo après le match (revue FM27, idée 28 ; choix de Léo du 23/11/2026) : la domination minute
// par minute et les entrées dans les 22 adverses (occasions, datées) de TOUT le journal du match terminé, gardées dans
// la carrière (`S.lastReport.analyse`, worker.cjs) quand le direct, qui les calculait, est refermé. Lecture seule.
const ANALYSE_VERSION=1;
function analyseVideo(events){
 if(!Array.isArray(events)||!events.length)return null;
 const lignes=selection.normaliser(events),d=domination(lignes),z=zone22(lignes,{liste:true});
 return {version:ANALYSE_VERSION,domination:d.minutes.slice(0,120),miTemps:Number.isInteger(d.miTemps)?d.miTemps:null,
  zone22:{entrees:z.entrees,points:z.points,secondes:z.secondes},occasions:z.liste.slice(0,200).map(([m,e])=>[Math.min(120,Math.round(m)),e])};
}
// Chiffres du rugby tirés du journal : chaque course se termine par un plaquage (ruck) ;
// une course de 22 m ou plus est un franchissement (comme `longGains` du moteur), un essai en
// jeu courant passe la dernière défense. Plaquages manqués = franchissements et essais en jeu
// courant subis (le moteur ne compte pas les plaquages joueur par joueur).
function chiffresRugby(lignes,events){
 const t=[0,1].map(()=>({courses:0,metres:0,franchissements:0,essaisCourant:0,recuperations:0,enAvant:0,plaquesStoppes:0,pieds:0,cartons:0}));
 for(const l of lignes){
  if(l.equipe===null)continue;const e=t[l.equipe],s=events[l.i]?.scene;
  if(l.kind==='carry'&&l.x!==null&&l.depuis!==null){
   const gain=Math.abs(l.x-l.depuis);e.courses++;e.metres+=gain;
   if(gain>=22)e.franchissements++;else t[1-l.equipe].plaquesStoppes++;
  }
  if(l.kind==='turnover'){e.recuperations++;e.plaquesStoppes++}
  if(l.kind==='hand-fault')e.enAvant++;
  if(['kick','touch','drop22','goalLine'].includes(l.kind))e.pieds++;
  if(l.kind==='card'&&l.incident)e.cartons++;
  if(l.kind==='try'&&s?.origin==='open')e.essaisCourant++;
 }
 return t;
}
// Note de match (match-notes.cjs, un seul calcul pour le direct et la note enregistrée) :
// 6,5 au coup d'envoi (remplaçant : 6,5 à l'entrée), puis ce que le journal montré leur
// attribue. Plaquages : chaque course adverse stoppée (moins de 22 m) et chaque ballon
// récupéré, comme le chiffre d'équipe ; le plaqueur est déduit de la place défensive.
// `contexte` (lecteur.etat().notes) : minutes, équipes et niveau au poste de la feuille.
const plaqueur=notesMatch.plaqueur,NOTE_DEPART=notesMatch.NOTE_DEPART;
function notesDuMatch(lignes,events,camp,contexte={}){
 if(camp!==0&&camp!==1)return {};
 const n=lignes.length?lignes[lignes.length-1].i+1:0;
 const score=lignes.length?lignes[lignes.length-1].scoreApres:[0,0];
 return notesMatch.noter(events.slice(0,n),{...(contexte||{}),camp,score,fini:contexte?.fini===true&&n>=events.length}).joueurs;
}
// XV adverse (onglet de la tuile principale) : la feuille adverse actuelle (un remplacement se
// voit tout de suite, demande de Léo), sinon celle du dernier fait montré ; notes et chiffres
// bornés à ce qui a été montré.
function xvAdverse(lignes,events,camp,effectif,actuel,contexte){
 if(camp!==0&&camp!==1)return [];
 const eux=1-camp,notes=notesDuMatch(lignes,events,eux,contexte),fiches=new Map((effectif||[]).map(p=>[String(p.id),p]));
 let on=Array.isArray(actuel)&&actuel.length?actuel:null;
 for(let k=lignes.length-1;k>=0&&!on;k--){const o=events[lignes[k].i]?.scene?.on?.[eux];if(Array.isArray(o)&&o.length)on=o}
 if(!on)return [];
 return on.slice(0,15).map(id=>{
  if(id==null)return null;const f=fiches.get(String(id)),n=notes[String(id)]||{note:notesMatch.NOTE_DEPART,faits:0,essais:0,metres:0,plaquages:0};
  // Clés propres à l'entracte (pas id/name : la couche « connaissance des joueurs » du modèle
  // habille ces objets-là et masque la note d'un joueur adverse non observé).
  return {joueur:String(id),nom:f?.name||'',poste:f?.pos||'',energie:f?.condition??null,note:n.note,faits:n.faits,essais:n.essais,metres:Math.round(n.metres),plaquages:n.plaquages};
 });
}

// Entracte sans rien dévoiler (demande de Léo, 12 novembre 2026 : « on découvre l'action en la
// regardant ») : le moteur a une minute d'avance, et un temps fort à venir peut commencer
// jusqu'à quelques plans avant son action (amorce, `fenetre` de match-highlights), ou au début
// d'une série dans les 22. `borneEntracte` rend le premier indice du journal qu'un temps fort à
// venir pourrait encore contenir : l'entracte (fil, chiffres, score, terrain 2D) s'arrête avant.
// Tout ce qui a été montré en 3D (jusqu'à la fin du dernier temps fort) reste montrable.
const AMORCE_MAX=8;
function borneEntracte(lignes,bilan){
 const montre=(bilan.tempsForts||[]).reduce((n,h)=>Math.max(n,h.fin),-1);
 // Déclenchement par l'importance (match-importance-20261112) : le moteur ouvre un temps fort au
 // début de l'action qui monte. Une action terminée sans avoir monté ne sera plus montrée en 3D :
 // la 2D peut la dérouler. L'action en cours (ou la pénalité qui peut amener un tir) reste
 // retenue depuis le début que lui donnerait le moteur (même règle, `debutAction`).
 if(bilan.mode==='importance'){
  let dernier=-1;for(let j=lignes.length-1;j>montre;j--)if(!lignes[j].bandeau){dernier=j;break}
  if(dernier<0)return Math.max(montre+1,lignes.length);
  const l=lignes[dernier],close=selection.FINS.has(l.kind)&&l.kind!=='penalty'||l.kind==='turnover'||l.kind==='setpiece-loss';
  if(close)return lignes.length;
  const amorce=(selection.IMPORTANCE[bilan.niveau]||{amorce:AMORCE_MAX}).amorce;
  return Math.max(montre+1,selection.debutAction(lignes,dernier,montre+1,amorce));
 }
 let borne=lignes.length,vus=0,minute=null;
 for(let j=lignes.length-1;j>montre;j--){
  const l=lignes[j];if(l.bandeau)continue;
  const chaine=l.kind==='penalty'||l.kind==='card'&&l.incident;
  if(selection.FINS.has(l.kind)&&!chaine)break;
  if(minute!==null&&minute-l.minute>1)break;
  borne=j;minute=l.minute;if(!chaine)vus++;
  if(vus>=AMORCE_MAX||selection.LANCEMENTS.has(l.kind)||l.kind==='turnover'||l.kind==='setpiece-loss'||l.kind==='penalty')break;
 }
 let equipe=null;
 for(let j=lignes.length-1;j>montre;j--){
  const l=lignes[j];if(l.bandeau)continue;
  if(!selection.dansLes22(l)||equipe!==null&&l.possession!==equipe)break;
  equipe=l.possession;borne=Math.min(borne,j);
 }
 return Math.max(montre+1,Math.min(borne,lignes.length));
}
// Chiffres cumulés du moteur (possession, mêlées, pénalités…) tels qu'ils étaient quand le
// journal s'arrêtait avant la borne : relevés à chaque projection, par rencontre.
const RELEVES=new Map();
// Faits des lois sans image (`scene.loi` sur un fait `message` : coup franc, essai de pénalité, drop tenté / raté /
// réussi, ballon injouable), les plus récents du journal du moteur, chacun avec `apres` : l'indice du dernier fait
// joué qui le précède (seuls des bandeaux entre les deux). La régie 3D les écrit après le plan de ce fait (légende,
// journal, score, ligne d'état), sans geste ni image ; lus au direct le plus récent, pas dans le temps fort reçu (le
// fait peut tomber au pas du moteur suivant). Match filmé du 26/11 : essai de pénalité et drop réussi absents du
// fil du direct 3D, seul le tiroir Journal les montrait.
const LOIS_TEXTE=new Set(['coup-franc','essai-penalite','drop-tente','drop-rate','drop-reussi','injouable']),LOIS_MAX=24;
function loisDuDirect(lignes,events,nommer){
 const sortie=[];let joue=-1;
 for(const l of lignes){
  if(!l.bandeau){joue=l.i;continue}
  const loi=events[l.i]?.scene?.loi;
  if(l.kind==='message'&&LOIS_TEXTE.has(loi)&&joue>=0)sortie.push({i:l.i,apres:joue,loi,kind:l.type==='try'?'try':l.type==='goal'?'goal':'message',equipe:l.equipe,horloge:horloge(l),score:l.scoreApres,texte:nommer(events[l.i].text)});
 }
 return sortie.slice(-LOIS_MAX);
}
// Le journal du moteur nomme les clubs par leur sigle interne (« FDG ») ; l'écran les nomme par
// leur identité affichée (presentation.abbr). Le texte montré reprend le sigle affiché.
function renommeur(equipes){
 const paires=(Array.isArray(equipes)?equipes:[]).map(t=>[String(t?.abbr||''),String(t?.presentation?.abbr||'')]).filter(([a,b])=>/^[A-Z0-9]{2,5}$/.test(a)&&b&&a!==b);
 if(!paires.length)return t=>String(t||'');
 const motif=new RegExp('(?<![\\p{L}\\p{N}])('+paires.map(p=>p[0]).join('|')+')(?![\\p{L}\\p{N}])','gu'),table=new Map(paires);
 return t=>String(t||'').replace(motif,a=>table.get(a));
}

// Évolution par période (petite fenêtre d'un chiffre du direct, 22/11/2026) : chaque chiffre du tableau par tranche de
// PAS_PERIODE minutes, tiré du journal montré (rien de nouveau à enregistrer : chaque fait du journal porte sa minute,
// et le journal est déjà dans la sauvegarde, anciennes comprises). Comptes = feuille de statistiques au bout de la
// tranche moins celle du début (même source que le tableau) ; possession et occupation = parts des faits de la tranche.
// La prolongation (au-delà de 80') reste dans la dernière tranche.
const PAS_PERIODE=10,TRANCHES=8,FEUILLES_PERIODES=new Map();
const CHAMPS_PERIODES=Object.freeze({metres:'metres',franchissements:'franchissements',plaquages:'plaquages',plaquages_manques:'plaquagesManques',
 recuperations:'recuperations',en_avant:'enAvant',temps_de_jeu:'courses',pieds:'coupsDePied',passes:'passes',defenseurs_battus:'defenseursBattus',
 offloads:'offloads',ballons_perdus:'ballonsPerdus',penalites:'penalitesConcedees'});
function totauxPeriode(events,n,rencontre,lire,feuille){
 const cle=rencontre+'|'+n+'|'+String(events[0]?.text||'');
 if(!feuille&&n>0&&n<events.length&&FEUILLES_PERIODES.has(cle))return FEUILLES_PERIODES.get(cle);
 const f=n<=0?null:feuille||feuilleStats.feuilleMontree(events,n,rencontre,lire);
 const t=[0,1].map(s=>{const e=f?.equipes?.[s];const o={};
  for(const [c,champ] of Object.entries(CHAMPS_PERIODES))o[c]=Number(e?.[champ])||0;
  o.rucks=Number(e?.rucks)||0;
  o.cartons=(Number(e?.cartonsJaunes)||0)+(Number(e?.cartonsRouges)||0);return o;});
 // Bornes closes (tranche finie) : la feuille ne bouge plus, on la garde (une feuille par borne, quelques rencontres).
 if(!feuille&&n>0&&n<events.length){FEUILLES_PERIODES.set(cle,t);while(FEUILLES_PERIODES.size>48)FEUILLES_PERIODES.delete(FEUILLES_PERIODES.keys().next().value)}
 return t;
}
function periodes(vues,events,finIndice,rencontre,lire,feuille=null){
 const jouees=vues.filter(l=>!l.bandeau&&l.kind!=='break'&&l.kind!=='end');
 if(!jouees.length)return {pas:PAS_PERIODE,tranches:[]};
 const tranche=l=>Math.min(TRANCHES-1,Math.floor(Math.max(0,l.minute)/PAS_PERIODE));
 const derniere=tranche(jouees.at(-1));
 // Indice du journal où commence chaque tranche (premier fait montré de minute ≥ début), puis la fin montrée.
 const debuts=[];for(let k=0;k<=derniere+1;k++){const l=k>derniere?null:vues.find(v=>Math.max(0,v.minute)>=k*PAS_PERIODE);debuts.push(k===0?0:l?l.i:finIndice)}
 debuts[derniere+1]=finIndice;
 const cumuls=debuts.map((n,k)=>totauxPeriode(events,n,rencontre,lire,k===debuts.length-1?feuille:null));
 const z=k=>{const avant=vues.filter(l=>l.i<debuts[k]);return zone22(avant).entrees||[0,0]};
 const zones=debuts.map((_,k)=>z(k));
 const tranches=[];
 for(let k=0;k<=derniere;k++){
  const ici=jouees.filter(l=>tranche(l)===k&&!SANS_IMAGE.has(l.kind));
  const part=(a,b)=>a+b>=4?[Math.round(a/(a+b)*100),100-Math.round(a/(a+b)*100)]:null;
  const tenus=[0,1].map(s=>ici.filter(l=>l.possession===s).length);
  const occupes=[ici.filter(l=>l.x!==null&&l.x>50).length,ici.filter(l=>l.x!==null&&l.x<50).length];
  const valeurs={possession:part(tenus[0],tenus[1]),occupation:part(occupes[0],occupes[1])};
  for(const c of Object.keys(cumuls[0][0]))valeurs[c]=[0,1].map(s=>Math.max(0,cumuls[k+1][s][c]-cumuls[k][s][c]));
  valeurs.zone22=[0,1].map(s=>Math.max(0,(zones[k+1][s]||0)-(zones[k][s]||0)));
  valeurs.plaquages_reussis=[0,1].map(s=>{const t=valeurs.plaquages[s]+valeurs.plaquages_manques[s];return t?Math.round(valeurs.plaquages[s]/t*100):null});
  // Mêlées et touches : comptes du moteur (l.stats) lus dans le journal de la tranche : chaque conquête disputée écrit
  // « setpiece-win » (équipe qui lance) ou « setpiece-loss » (équipe qui vole) ; mêlée non disputée = gagnée.
  const conquete={melees:[[0,0],[0,0]],touches:[[0,0],[0,0]]};
  for(const l of jouees.filter(l=>tranche(l)===k)){
   if(l.equipe===null)continue;
   // Chaque lancer ou introduction est préparé (« lineout » / « scrum », setup : équipe qui lance) ; une faute le
   // termine sans « setpiece-* » mais le moteur le compte. Gagné : « setpiece-win » de l'équipe qui lance.
   if(l.kind==='setpiece-win')conquete[l.touche?'touches':'melees'][l.equipe][0]++;
   else if((l.kind==='lineout'||l.kind==='scrum')&&l.type==='setup')conquete[l.kind==='lineout'?'touches':'melees'][l.equipe][1]++;
   else if(l.kind==='scrum'&&/non disputée/.test(String(events[l.i]?.text||''))){const c=conquete.melees[l.equipe];c[0]++;c[1]++}
  }
  for(const c of ['melees','touches'])valeurs[c]=[0,1].map(s=>conquete[c][s][0]);
  // Comptes des parts (numérateur, dénominateur par club) : la courbe cumulée refait la part depuis le coup d'envoi.
  const parts={possession:[[tenus[0],tenus[0]+tenus[1]],[tenus[1],tenus[0]+tenus[1]]],occupation:[[occupes[0],occupes[0]+occupes[1]],[occupes[1],occupes[0]+occupes[1]]],
   plaquages_reussis:[0,1].map(s=>[valeurs.plaquages[s],valeurs.plaquages[s]+valeurs.plaquages_manques[s]]),
   melees:conquete.melees,touches:conquete.touches};
  // `fin` : minute de fin de la tranche, ou dernière minute montrée pour la tranche en cours.
  const fin=k===derniere?Math.max(k*PAS_PERIODE+1,Math.min((k+1)*PAS_PERIODE,jouees.at(-1).minute)):(k+1)*PAS_PERIODE;
  tranches.push({de:k*PAS_PERIODE,a:(k+1)*PAS_PERIODE,fin,enCours:k===derniere,valeurs,parts});
 }
 // Minute par minute (courbe de possession / d'occupation) : faits de chaque camp, même source que les tranches.
 const fin=Math.max(0,jouees.at(-1).minute),minutes={possession:[],occupation:[]};
 for(let m=0;m<=fin;m++){minutes.possession.push([0,0]);minutes.occupation.push([0,0])}
 for(const l of jouees){
  if(SANS_IMAGE.has(l.kind))continue;const m=Math.min(fin,Math.max(0,l.minute));
  if(l.possession===0||l.possession===1)minutes.possession[m][l.possession]++;
  if(l.x!==null&&l.x!==50)minutes.occupation[m][l.x>50?0:1]++;
 }
 return {pas:PAS_PERIODE,tranches,minutes};
}

function releve(rencontre,n,valeurs,borne){
 let liste=RELEVES.get(rencontre);
 if(!liste){liste=[];RELEVES.set(rencontre,liste);while(RELEVES.size>4)RELEVES.delete(RELEVES.keys().next().value)}
 // Journal plus court que le dernier relevé : autre match de la même affiche (sauvegarde rechargée).
 if(liste.length&&liste.at(-1).n>n)liste.length=0;
 if(!liste.length||liste.at(-1).n<n)liste.push({n,...valeurs});
 else if(liste.at(-1).n===n)liste[liste.length-1]={n,...valeurs};
 while(liste.length>240)liste.shift();
 let choisi=null;for(const r of liste)if(r.n<=borne)choisi=r;
 return choisi;
}

// `lire` : accès en lecture au moteur ({scenes, transformation, etat, profils}).
// `options.choregraphe` : joindre au temps fort sa mise en scène continue (chorégraphe).
function project(model,niveau,lire,options={}){
 const live=model.live,events=live.events,nommer=renommeur(live.teams);
 if(!NIVEAUX.includes(niveau))throw new RangeError('Niveau de temps forts inconnu : '+niveau);
 const phase=model.next?.phase,eliminatoire=typeof phase==='string'&&phase!=='league';
 const etat=lire.etat()||{},bilan=selection.en_direct(events,{niveau,eliminatoire,camp:etat.camp}),lignes=selection.normaliser(events);
 const jouable=l=>!l.bandeau&&l.kind!=='break'&&l.kind!=='end';
 // L'entracte ne montre que le journal d'avant la borne (rien d'un temps fort à venir).
 const borne=borneEntracte(lignes,bilan);
 const vues=lignes.slice(0,borne);
 const derniere=[...vues].reverse().find(jouable)||null;
 const passe=releve(String(etat.rencontre||''),events.length,{stats:live.stats||[],statsRows:live.statsRows||[],tactique:etat.tactique||null},borne);
 // Fil : sans les messages d'avantage, les retours de carton ni les mises en place.
 const bruit=l=>l.kind==='advantage'||l.kind==='card'&&!l.incident||l.type==='setup'||l.kind==='miss'&&l.type!=='miss';
 const fil=vues.filter(l=>!bruit(l)).slice(-10).map(l=>({i:l.i,horloge:horloge(l),texte:nommer(events[l.i].text),kind:l.kind,equipe:l.equipe}));
 const traces=vues.filter(l=>jouable(l)&&events[l.i].scene).slice(-3).map(l=>({depuis:point(events[l.i].scene.from),vers:point(events[l.i].scene.to),equipe:l.equipe,kind:l.kind})).filter(t=>t.depuis&&t.vers);
 // Repères de la frise : le score après le fait et son acteur (identifiant, nom connu du match), pour l'entracte
 // (« E · Garnier 10-7 », nom en lien vers la fiche pour un joueur du club).
 const nomActeur=id=>id?etat.notes?.noms?.[id]||(etat.effectifAdverse||[]).find(p=>String(p.id)===id)?.name||'':'';
 // Essai de pénalité et drop réussi (faits `message` du bloc des lois, `scene.loi`) : repères « try » (sans marqueur) et
 // « goal » (le botteur), comme le fil du score (`direct.marques`).
 const loiRepere=l=>l.kind==='message'?events[l.i]?.scene?.loi:null;
 const reperes=vues.filter(l=>l.kind==='try'||l.kind==='goal'||l.kind==='card'&&l.incident||['essai-penalite','drop-reussi'].includes(loiRepere(l))).map(l=>{const loi=loiRepere(l),a=loi==='essai-penalite'?null:events[l.i]?.scene?.actor,id=a==null?null:String(a);
  return {i:l.i,kind:loi==='essai-penalite'?'try':loi==='drop-reussi'?'goal':l.kind,...(loi?{loi}:{}),equipe:l.equipe,horloge:horloge(l),minute:l.minute,x:l.x,y:events[l.i].scene?.to?.y??35,rouge:l.cause==='red',score:l.scoreApres||null,joueur:id,nom:nomActeur(id)};});
 // Chiffres : ceux que le moteur tient déjà.
 // Aucun relevé assez ancien (début de match, reprise) : les libellés, sans valeur.
 const rang=nom=>passe?(passe.statsRows||[]).find(r=>r.label===nom):(live.statsRows||[]).filter(r=>r.label===nom).map(r=>({...r,home:'—',away:'—'}))[0];
 const chiffres=[];
 for(const [nom,titre] of [['Possession','Possession'],['Territoire','Occupation'],['Touches conservées','Touches conservées'],['Mêlées conservées','Mêlées conservées'],['Pénalités concédées','Pénalités concédées']]){
  const r=rang(nom);if(r)chiffres.push({label:titre,home:String(r.home),away:String(r.away)});
 }
 if(passe?.tactique)chiffres.push({label:'Franchissements',home:String(passe.tactique[0].longGains),away:String(passe.tactique[1].longGains)},{label:'Fautes de main',home:String(passe.tactique[0].handErrors),away:String(passe.tactique[1].handErrors)});
 // Élan : où s'est joué le match pendant les dix dernières minutes (0 = en-but de l'équipe qui reçoit).
 const recents=derniere?vues.filter(l=>jouable(l)&&l.x!==null&&l.periode===derniere.periode&&derniere.minute-l.minute<10):[];
 const elan=recents.length?Math.round(recents.reduce((n,l)=>n+l.x,0)/recents.length):50;
 // Tableau de bord de l'entracte : valeurs chiffrées des deux équipes (barres comparées).
 const rugby=chiffresRugby(vues,events),stats=passe?.stats||[];
 const pourcent=(a,b)=>a+b>0?[Math.round(a/(a+b)*100),100-Math.round(a/(a+b)*100)]:[50,50];
 // Possession et occupation lues dans le journal montré (faits joués, bornés) : les compteurs
 // par minute du moteur donnent 100 % / 0 % en début de match. Pas de pourcentage avant
 // quelques faits ; les compteurs restent masqués (« — ») tant qu'ils sont nuls en début de match.
 const joues=vues.filter(l=>jouable(l)&&!SANS_IMAGE.has(l.kind));
 const tenus=[0,1].map(s=>joues.filter(l=>l.possession===s).length);
 const occupes=[joues.filter(l=>l.x!==null&&l.x>50).length,joues.filter(l=>l.x!==null&&l.x<50).length];
 // Échantillon court (lot 5, 16/11/2026) : avant ECHANTILLON_MINUTES de jeu montré, les parts
 // (possession, occupation) ne sont pas affichées (« 100 % / 0 % » à la 2e minute) et les
 // compteurs portent `court` : l'écran les atténue, l'adjoint ne les commente pas.
 const tot=a=>a[0]+a[1],minuteVue=derniere?.minute??0,MIN_FAITS=6;
 const court=minuteVue<ECHANTILLON_MINUTES;
 const compte=(rang)=>({...rang,vide:rang.valeurs[0]+rang.valeurs[1]===0&&court,court});
 const tableau=[
  {cle:'possession',label:'Possession',valeurs:pourcent(tenus[0],tenus[1]),unite:'%',vide:tot(tenus)<MIN_FAITS||court,court},
  {cle:'occupation',label:'Occupation',valeurs:pourcent(occupes[0],occupes[1]),unite:'%',vide:tot(occupes)<MIN_FAITS||court,court},
  compte({cle:'metres',label:'Mètres gagnés',valeurs:rugby.map(e=>Math.round(e.metres))}),
  compte({cle:'franchissements',label:'Franchissements',valeurs:rugby.map(e=>e.franchissements)}),
  compte({cle:'plaquages',label:'Plaquages réussis',valeurs:rugby.map(e=>e.plaquesStoppes)}),
  compte({cle:'plaquages_manques',label:'Plaquages manqués',valeurs:[0,1].map(s=>rugby[1-s].franchissements+rugby[1-s].essaisCourant),inverse:true}),
  compte({cle:'melees',label:'Mêlées gagnées',valeurs:[0,1].map(s=>stats[s]?.scrumsWon||0),sur:[0,1].map(s=>stats[s]?.scrums||0)}),
  compte({cle:'touches',label:'Touches gagnées',valeurs:[0,1].map(s=>stats[s]?.lineoutsWon||0),sur:[0,1].map(s=>stats[s]?.lineouts||0)}),
  compte({cle:'recuperations',label:'Ballons récupérés',valeurs:rugby.map(e=>e.recuperations)}),
  compte({cle:'penalites',label:'Pénalités concédées',valeurs:[0,1].map(s=>stats[s]?.penalties||0),inverse:true}),
  compte({cle:'en_avant',label:'En-avant',valeurs:rugby.map(e=>e.enAvant),inverse:true}),
  // Entracte façon match overview (demande de Léo) : temps de jeu, jeu au pied, cartons montrés.
  compte({cle:'temps_de_jeu',label:'Temps de jeu',valeurs:rugby.map(e=>e.courses)}),
  compte({cle:'pieds',label:'Coups de pied',valeurs:rugby.map(e=>e.pieds)}),
  compte({cle:'cartons',label:'Cartons',valeurs:rugby.map(e=>e.cartons),inverse:true})
 ];
 // Feuille de statistiques (match-stats.cjs) de ce qui a été montré : chiffres d'équipe du tableau
 // = somme des joueurs ; plaquages, mètres… réalistes (le journal seul en donnait 0 ou 1 par ailier).
 const feuille=feuilleStats.feuilleMontree(events,borne<lignes.length?lignes[borne].i:events.length,String(etat.rencontre||''),lire);
 feuilleStats.completerTableau(tableau,feuille);
 let parPeriode;
 try{parPeriode=periodes(vues,events,borne<lignes.length?lignes[borne].i:events.length,String(etat.rencontre||''),lire,feuille)}catch(error){parPeriode={pas:PAS_PERIODE,tranches:[]}}
 // Les chiffres ajoutés par la feuille (passes, rucks…) portent eux aussi la longueur de l'échantillon.
 for(const r of tableau)r.court=court;
 // Notes du direct : chiffres et apport de cette même feuille (match-notes.cjs, une seule source).
 const contexteNotes=etat.notes?{...etat.notes,feuille,apports:feuilleStats.apportsNote(feuille)}:etat.notes;
 const direct={version:1,rencontre:String(etat.rencontre||''),niveau,niveaux:NIVEAUX.map(id=>({id,label:LIBELLES[id]})),horloge:etat.horloge||'',
  // Minute du dernier fait montré (borne) : l'horloge de l'entracte ne court pas devant ce qui a été vu.
  horlogeMontree:derniere?horloge(derniere):etat.horloge||'',camp:etat.camp??-1,
  possession:derniere?.possession??(vues.length?null:etat.possession??null),zone:{x:Number.isFinite(derniere?.x)?derniere.x:50,kind:derniere?.kind||'message'},
  fil,traces,reperes,chiffres,elan,echantillon:{minutes:minuteVue,suffisant:!court,seuil:ECHANTILLON_MINUTES},cartons:(etat.cartons||[]).filter(c=>vues.some(l=>l.kind==='card'&&String(events[l.i].scene?.actor)===String(c.id))),
  borne,score:vues.length?vues.at(-1).scoreApres:[0,0],statsRows:passe?.statsRows||[],
  tableau,periodes:parPeriode,domination:domination(vues),
  // Entrées dans les 22 adverses, points et secondes qui en découlent (faits montrés seulement).
  zone22:zone22(vues),notes:notesDuMatch(vues,events,etat.camp??-1,contexteNotes),adversaire:xvAdverse(vues,events,etat.camp??-1,etat.effectifAdverse,etat.xvAdverseActuel,contexteNotes),deroule:deroule(vues,events,lire,String(etat.rencontre||''),nommer),
  bilan:{tempsForts:bilan.nombre,action:bilan.dureeAction,rafales:bilan.rafales,rafalesSautees:bilan.rafalesSautees},tempsFort:null,arret:null,hommeDuMatch:null};
 // Bonus de la rencontre vu de notre camp (règle du championnat, état, dilemme de fin de match), sur le score, les
 // essais et la minute du journal montré : rien d'un temps fort à venir. null sans bonus en jeu.
 {const vue=vues.at(-1);direct.bonus=bonusFin.projection(etat.bonus||null,{score:direct.score,essais:vue?vue.essaisApres:[0,0],camp:direct.camp,minute:minuteVue,fini:live.finished===true&&borne>=events.length});}
 // Homme du match (résumé d'après-match) : désigné quand tout le journal a été montré, par le
 // calcul de la note enregistrée (match-notes.cjs).
 if(live.finished&&borne>=events.length&&etat.notes){
  const r=notesMatch.noter(events,{...contexteNotes,fini:true}),h=r.hommeDuMatch,n=h!=null?r.joueurs[h]:null;
  if(n){const fiche=(etat.effectifAdverse||[]).find(p=>String(p.id)===h);
   // Clé `joueur` (pas id/name), comme le XV adverse : la couche « connaissance » ne la masque pas.
   direct.hommeDuMatch={joueur:h,camp:n.cote,nom:etat.notes.noms?.[h]||fiche?.name||'',note:n.note,essais:n.essais,plaquages:n.plaquages,metres:n.metres};}
 }
 // « Pourquoi » d'après-match : trois raisons au plus, tirées des faits mesurés ci-dessus (match-pourquoi.cjs).
 if(live.finished&&borne>=events.length){
  try{const f=pourquoi.faits({...direct,notes:direct.notes},{energie:Array.isArray(etat.energie)&&etat.energie.every(Number.isFinite)?etat.energie:null,noms:etat.notes?.noms||{}});direct.pourquoi=pourquoi.raisons(f);}
  catch(error){direct.pourquoi={issue:null,raisons:[]};}
  // Fil du score de l'après-match : chaque essai et chaque coup de pied réussi, son auteur (clé `joueur`, comme
  // l'homme du match) et le score qui en découle.
  // `nature` : essai, essai transformé (la transformation est comptée sur la ligne de l'essai), pénalité ou drop ;
  // `buteur` : auteur de la transformation, le même que le plan « transformation » du direct (lire.transformation).
  const nomDe=id=>id?etat.notes?.noms?.[id]||(etat.effectifAdverse||[]).find(p=>String(p.id)===id)?.name||'':'';
  // Essai de pénalité (7 points, ni marqueur ni botteur) et drop réussi (3 points, le botteur) : faits `message` du bloc des lois, repérés par `scene.loi`.
  const loiDe=l=>events[l.i]?.scene?.loi;
  direct.marques=vues.filter(l=>l.kind==='try'||l.kind==='goal'||l.kind==='message'&&['essai-penalite','drop-reussi'].includes(loiDe(l))).map(l=>{
   const a=events[l.i]?.scene?.actor,penalty=loiDe(l)==='essai-penalite',id=a==null||penalty?null:String(a);
   const nature=penalty?'essai-penalite':l.kind==='try'?(l.transformation===true?'essai-transforme':'essai'):loiDe(l)==='drop-reussi'||/drop/i.test(String(events[l.i]?.text||''))?'drop':'penalite';
   let buteur=null;
   if(nature==='essai-transforme'&&typeof lire.transformation==='function'){try{const p=(lire.transformation(l.i,true)?.players||[]).find(x=>x.featured);if(p)buteur={joueur:String(p.id),nom:nomDe(String(p.id))};}catch{buteur=null;}}
   return {horloge:horloge(l),minute:l.minute,kind:l.kind==='message'?(penalty?'try':'goal'):l.kind,nature,equipe:l.equipe,joueur:id,nom:nomDe(id),buteur,score:l.scoreApres,texte:nommer(events[l.i].text)};});
 }
 direct.lois=loisDuDirect(lignes,events,nommer);
 direct.feuille=feuille;feuilleStats.habillerAdversaire(direct.adversaire,feuille);
 direct.statsRows=[...direct.statsRows,...feuilleStats.lignesEquipe(feuille)];
 const tf=bilan.courant;
 if(tf){
  const indices=tf.plans.filter(p=>p.kind!=='transformation').map(p=>p.i),scenes=lire.scenes(indices),parIndex=new Map(indices.map((i,n)=>[i,scenes[n]]));
  const plans=[];
  for(const p of tf.plans){
   let scene=p.kind==='transformation'?lire.transformation(p.i,p.reussie):parIndex.get(p.i);
   if(!scene)continue; // sans scène enregistrée, le plan reste dans le fil
   // Deux événements identiques (même minute, texte et position : touches répétées après pénaltouches)
   // donnent la même clé : on la rend unique par l'index pour que chaque plan soit une scène distincte.
   if(plans.some(q=>q.scene.key===scene.key))scene={...scene,key:scene.key+'#'+p.i};
   plans.push({index:p.i,kind:p.kind,duree:p.duree,mouvement:p.mouvement,coupe:p.coupe,horloge:horloge(lignes[p.i]),
    texte:legende(p,nommer(events[p.i].text)),...(ANNONCES[p.kind]?{annonce:ANNONCES[p.kind]}:{}),
    score:p.kind==='try'?lignes[p.i].scoreAvant.map((n,side)=>n+(side===lignes[p.i].equipe?5:0)):lignes[p.i].scoreApres,
    // Cause de l'arrêt (passe en avant…) : la ligne d'état dit « Passe en avant », pas « En-avant ».
    ...(lignes[p.i].cause?{cause:lignes[p.i].cause}:{}),scene});
  }
  // Position de départ : le dernier plan jouable avant la fenêtre, pour que le premier
  // plan parte d'où l'action se trouvait et non de la scène précédemment affichée.
  let depart=null;
  if(plans.length&&!tf.suite&&!plans[0].coupe){
   const avant=[...lignes.slice(0,tf.debut)].reverse().find(l=>jouable(l)&&events[l.i].scene);
   if(avant)depart=lire.scenes([avant.i])[0];
  }
  if(plans.length)direct.tempsFort={cle:tf.cle,suite:tf.suite,type:tf.type,titre:TYPES[tf.type]||'Temps fort',types:tf.types,score:tf.score,force:tf.force,
   duree:tf.duree,debut:tf.debut,fin:tf.fin,
   // Déclenchement (journal de régie et tests ; jamais affiché : il ne doit rien annoncer).
   declenchement:tf.declencheur===undefined?null:{fait:tf.declencheur,importance:tf.importance,seuil:tf.seuil,rattrapage:tf.rattrapage===true},scoreAvant:lignes[plans[0].index].scoreAvant,horlogeDebut:horloge(lignes[tf.debut]),horlogeFin:horloge(lignes[tf.fin]),depart,plans,
   bandeaux:tf.bandeaux.map(i=>({i,kind:lignes[i].kind,...(events[i]?.scene?.loi?{loi:events[i].scene.loi}:{}),texte:nommer(events[i].text)}))};
  if(plans.length&&(options.choregraphe===true||options.choregraphe==='entrees')){
   try{
    const c=choregraphier(direct.tempsFort,plans,events,lire);
    if(c)direct.tempsFort.choregraphie=c;
    if(c&&options.choregraphe==='entrees')direct.tempsFort.choregraphieEntree=c.entree;
   }
   catch(error){direct.tempsFort.choregraphieErreur=String(error?.message||error)}
  }
 }
 // Arrêt-décision : un carton contre mon équipe, ou un rouge adverse, dans la dernière rafale.
 const rafale=bilan.decisions.at(-1)?.rafale;
 let arretLigne=-1;
 if(rafale&&direct.camp>=0){
  for(let i=rafale[0];i<=rafale[1];i++){
   const l=lignes[i];
   if(l.kind==='card'&&l.incident&&(l.equipe===direct.camp||l.cause==='red')){
    direct.arret={cle:'carton-'+i,raison:'carton',rouge:l.cause==='red',pourNous:l.equipe!==direct.camp,texte:nommer(events[i].text),horloge:horloge(l)};arretLigne=i;}
  }
 }
 // Arrêt-incident (incidents-match.cjs) : remplacement forcé de mon équipe (blessure, saignement, HIA, commotion,
 // couverture de première ligne) déjà montré ; le choix du manager y est joint s'il a plus d'une option. Un carton plus
 // récent garde la main.
 const incident=live.incidentChoix;
 if(incident&&direct.camp>=0&&Number.isInteger(incident.evenement)&&incident.evenement<borne&&incident.evenement>arretLigne&&lignes[incident.evenement]){
  const i=incident.evenement;
  direct.arret={cle:incident.cle,raison:incident.kind,rouge:false,pourNous:false,texte:nommer(events[i].text),horloge:horloge(lignes[i]),...(incident.options.length>1?{choix:{type:incident.type,options:incident.options}}:{})};
 }
 // Multiplex des autres matchs de la journée et classement « si ça finit ainsi » (match-multiplex.cjs),
 // à la minute du dernier fait montré : jamais au-delà de ce que le joueur a vu.
 if(typeof lire.journee==='function'){
  try{
   const fini=live.finished===true&&borne>=events.length,vue=vues.at(-1);
   const j=lire.journee(minuteVue,fini,direct.score,vue?vue.essaisApres:[0,0]);
   direct.journee=j?habillerJournee(j,model):null;
  }catch(error){direct.journee=null;direct.journeeErreur=String(error?.message||error);}
 }
 return direct;
}

// Noms et sigles affichés (identité du club, presentation) des clubs du multiplex et du classement.
function habillerJournee(j,model){
 const fiches=new Map();
 for(const c of [...(Array.isArray(model.league)?model.league:[]),...(Array.isArray(model.live?.teams)?model.live.teams:[])])if(c&&c.id!==undefined)fiches.set(c.id,c);
 const nom=(id,x)=>{const c=fiches.get(id);return c?{abbr:c.presentation?.abbr||c.abbr||x.abbr,nom:c.presentation?.name||c.name||x.nom}:{abbr:x.abbr,nom:x.nom};};
 return {...j,matchs:j.matchs.map(m=>({...m,home:{...m.home,...nom(m.home.id,m.home)},away:{...m.away,...nom(m.away.id,m.away)}})),
  classement:j.classement.map(r=>({...r,...nom(r.clubId,r)}))};
}

module.exports=Object.freeze({analyseVideo,ANALYSE_VERSION,NOTE_DEPART,NIVEAUX,LIBELLES,lecteur,project,borneEntracte,domination,chiffresRugby,periodes,PAS_PERIODE,notesDuMatch,xvAdverse,plaqueur,DEROULE_MAX,ECHANTILLON_MINUTES});
