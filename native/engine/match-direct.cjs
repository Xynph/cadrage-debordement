'use strict';
// Match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0) : projection `live.direct` du modèle.
//
// Lecture seule. La sélection vient de match-highlights.cjs (`en_direct`) ; ce module
// y ajoute ce que l'écran doit afficher : les scènes 3D des plans à rejouer, le fil,
// la zone de jeu, quelques chiffres. Rien n'est écrit dans la carrière, aucun tirage
// n'est consommé : avec ou sans cette projection, le match simulé est le même.
const selection=require('./match-highlights.cjs');
const choregraphe=require('./match-choregraphe.cjs');

const NIVEAUX=Object.freeze(Object.keys(selection.NIVEAUX));
const LIBELLES=Object.freeze({aucun:'Commentaire seul',resume:'Résumé',cles:'Temps forts clés',etendus:'Temps forts étendus',dynamique:'Dynamique',integral:'Match complet'});
const TYPES=Object.freeze({
 essai:'Essai',penalite_reussie:'Pénalité',penalite_manquee:'Pénalité manquée',carton_rouge:'Carton rouge',carton_jaune:'Carton jaune',
 essai_refuse:'En-avant dans l’en-but',ballon_tenu_en_but:'Ballon tenu en but',en_but_sous_pression:'En-but sous pression',en_but_defendu:'En-but défendu',ballon_mort:'Ballon mort',
 cinquante_22:'50:22',touche_5m:'Touche près de la ligne',melee_5m:'Mêlée près de la ligne',ballon_porte:'Ballon porté',franchissement:'Franchissement',
 pres_de_la_ligne:'Près de la ligne',entree_dans_les_22:'Entrée dans les 22',jeu_dans_les_22:'Jeu dans les 22',progression:'Progression',pression_dans_les_22:'Pression dans les 22',
 ballon_sauve:'Ballon sauvé',ballon_gratte_haut:'Ballon gratté',conquete_volee:'Conquête volée',ballon_recupere:'Ballon récupéré',coup_d_envoi:'Coup d’envoi',reprise:'Reprise',
 fin_de_match_serree:'Fin de match',long_jeu_au_pied:'Jeu au pied',penalite_sifflee:'Pénalité sifflée',faute_de_main:'Faute de main',sortie_en_touche:'Sortie en touche',
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
   return {rencontre:[S.season,S.round,S.phase,l.pair.join('-')].join(':'),horloge:matchClock(l),camp:l.userSide,possession:l.possession,territoire:l.territory,cartons,
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
 const base=choregraphe.entreeDepuisTempsFort({...tf,plans},events,{avant,cle:tf.cle});
 if(!base){CHOREGRAPHIES.set(cle,null);return null}
 const ids=base.joueurs.map(p=>p.id),bruts=typeof lire.profils==='function'?lire.profils(ids):{},profils={};
 for(const p of base.joueurs)profils[p.id]=choregraphe.profil(p.slot,bruts[p.id]?.vitesse);
 const c=choregraphe.composer({...base,profils});
 // Outil de test (options.choregraphe === 'entrees') : l'entrée est jointe, pour en faire un jeu d'essai.
 Object.defineProperty(c,'entree',{value:{...base,profils},enumerable:false});
 CHOREGRAPHIES.set(cle,c);
 while(CHOREGRAPHIES.size>8)CHOREGRAPHIES.delete(CHOREGRAPHIES.keys().next().value);
 return c;
}

// `lire` : accès en lecture au moteur ({scenes, transformation, etat, profils}).
// `options.choregraphe` : joindre au temps fort sa mise en scène continue (chorégraphe).
function project(model,niveau,lire,options={}){
 const live=model.live,events=live.events;
 if(!NIVEAUX.includes(niveau))throw new RangeError('Niveau de temps forts inconnu : '+niveau);
 const phase=model.next?.phase,eliminatoire=typeof phase==='string'&&phase!=='league';
 const bilan=selection.en_direct(events,{niveau,eliminatoire}),lignes=selection.normaliser(events),etat=lire.etat()||{};
 const jouable=l=>!l.bandeau&&l.kind!=='break'&&l.kind!=='end';
 const derniere=[...lignes].reverse().find(jouable)||null;
 // Fil : sans les messages d'avantage, les retours de carton ni les mises en place.
 const bruit=l=>l.kind==='advantage'||l.kind==='card'&&!l.incident||l.type==='setup'||l.kind==='miss'&&l.type!=='miss';
 const fil=lignes.filter(l=>!bruit(l)).slice(-10).map(l=>({horloge:horloge(l),texte:String(events[l.i].text||''),kind:l.kind,equipe:l.equipe}));
 const traces=lignes.filter(l=>jouable(l)&&events[l.i].scene).slice(-3).map(l=>({depuis:point(events[l.i].scene.from),vers:point(events[l.i].scene.to),equipe:l.equipe,kind:l.kind})).filter(t=>t.depuis&&t.vers);
 const reperes=lignes.filter(l=>l.kind==='try'||l.kind==='goal'||l.kind==='card'&&l.incident).map(l=>({kind:l.kind,equipe:l.equipe,horloge:horloge(l),x:l.x,y:events[l.i].scene?.to?.y??35,rouge:l.cause==='red'}));
 // Chiffres : ceux que le moteur tient déjà.
 const rang=nom=>(live.statsRows||[]).find(r=>r.label===nom);
 const chiffres=[];
 for(const [nom,titre] of [['Possession','Possession'],['Territoire','Occupation'],['Touches conservées','Touches conservées'],['Mêlées conservées','Mêlées conservées'],['Pénalités concédées','Pénalités concédées']]){
  const r=rang(nom);if(r)chiffres.push({label:titre,home:String(r.home),away:String(r.away)});
 }
 if(etat.tactique)chiffres.push({label:'Franchissements',home:String(etat.tactique[0].longGains),away:String(etat.tactique[1].longGains)},{label:'Fautes de main',home:String(etat.tactique[0].handErrors),away:String(etat.tactique[1].handErrors)});
 // Élan : où s'est joué le match pendant les dix dernières minutes (0 = en-but de l'équipe qui reçoit).
 const recents=derniere?lignes.filter(l=>jouable(l)&&l.x!==null&&l.periode===derniere.periode&&derniere.minute-l.minute<10):[];
 const elan=recents.length?Math.round(recents.reduce((n,l)=>n+l.x,0)/recents.length):50;
 const direct={version:1,rencontre:String(etat.rencontre||''),niveau,niveaux:NIVEAUX.map(id=>({id,label:LIBELLES[id]})),horloge:etat.horloge||'',camp:etat.camp??-1,
  possession:etat.possession??null,zone:{x:Number.isFinite(etat.territoire)?etat.territoire:50,kind:derniere?.kind||'message'},
  fil,traces,reperes,chiffres,elan,cartons:etat.cartons||[],
  bilan:{tempsForts:bilan.nombre,action:bilan.dureeAction,rafales:bilan.rafales,rafalesSautees:bilan.rafalesSautees},tempsFort:null,arret:null};
 const tf=bilan.courant;
 if(tf){
  const indices=tf.plans.filter(p=>p.kind!=='transformation').map(p=>p.i),scenes=lire.scenes(indices),parIndex=new Map(indices.map((i,n)=>[i,scenes[n]]));
  const plans=[];
  for(const p of tf.plans){
   const scene=p.kind==='transformation'?lire.transformation(p.i,p.reussie):parIndex.get(p.i);
   if(!scene)continue; // sans scène enregistrée, le plan reste dans le fil
   plans.push({index:p.i,kind:p.kind,duree:p.duree,mouvement:p.mouvement,coupe:p.coupe,horloge:horloge(lignes[p.i]),
    texte:legende(p,String(events[p.i].text||'')),...(ANNONCES[p.kind]?{annonce:ANNONCES[p.kind]}:{}),
    score:p.kind==='try'?lignes[p.i].scoreAvant.map((n,side)=>n+(side===lignes[p.i].equipe?5:0)):lignes[p.i].scoreApres,scene});
  }
  // Position de départ : le dernier plan jouable avant la fenêtre, pour que le premier
  // plan parte d'où l'action se trouvait et non de la scène précédemment affichée.
  let depart=null;
  if(plans.length&&!tf.suite&&!plans[0].coupe){
   const avant=[...lignes.slice(0,tf.debut)].reverse().find(l=>jouable(l)&&events[l.i].scene);
   if(avant)depart=lire.scenes([avant.i])[0];
  }
  if(plans.length)direct.tempsFort={cle:tf.cle,suite:tf.suite,type:tf.type,titre:TYPES[tf.type]||'Temps fort',types:tf.types,score:tf.score,force:tf.force,
   duree:tf.duree,debut:tf.debut,fin:tf.fin,scoreAvant:lignes[plans[0].index].scoreAvant,horlogeDebut:horloge(lignes[tf.debut]),horlogeFin:horloge(lignes[tf.fin]),depart,plans,
   bandeaux:tf.bandeaux.map(i=>({kind:lignes[i].kind,texte:String(events[i].text||'')}))};
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
 if(rafale&&direct.camp>=0){
  for(let i=rafale[0];i<=rafale[1];i++){
   const l=lignes[i];
   if(l.kind==='card'&&l.incident&&(l.equipe===direct.camp||l.cause==='red'))
    direct.arret={cle:'carton-'+i,raison:'carton',rouge:l.cause==='red',pourNous:l.equipe!==direct.camp,texte:String(events[i].text||''),horloge:horloge(l)};
  }
 }
 return direct;
}

module.exports=Object.freeze({NIVEAUX,LIBELLES,lecteur,project});
