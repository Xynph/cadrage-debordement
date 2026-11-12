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
   // Effectif adverse du jour (titulaires et remplaçants) : nom, poste et état visible de chacun.
   const eux=l.userSide>=0?1-l.userSide:-1,feuille=eux>=0?l.sheets[eux]:null;
   const effectifAdverse=feuille?[...feuille.on,...(feuille.bench||[])].filter(Boolean).map(id=>{const p=matchPlayer(l,eux,id);return p?{id:String(p.id),name:p.name,pos:p.pos,condition:Math.round(p.condition??100)}:null}).filter(Boolean):[];
   return {rencontre:[S.season,S.round,S.phase,l.pair.join('-')].join(':'),horloge:matchClock(l),camp:l.userSide,possession:l.possession,territoire:l.territory,cartons,effectifAdverse,
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

// --- Entracte en 2D (vue de dessus, façon « match overview ») ----------------------------
// Tout ce qui suit est lu dans le journal, sans rien écrire ni tirer : le moteur reste la
// source de vérité, la vue 2D ne fait qu'interpoler entre ces images.
const SANS_IMAGE=new Set(['message','advantage','card','sub','tactic','break','end']);
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
// Place défensive de chaque poste (1 à 15) en largeur (0 à 70) : sert à désigner le plaqueur
// d'une course adverse, que le moteur ne nomme pas. Les avants plaquent au contact (petits gains),
// les trois-quarts dans leur couloir. Lecture pure du journal : aucun tirage, rien ne change au match.
const COULOIR_DEFENSE=[33,35,37,30,40,24,46,35,35,28,6,20,50,64,35];
function plaqueur(on,gain,y){
 if(!Array.isArray(on)||!on.length)return null;
 let choisi=null,meilleur=Infinity;
 on.forEach((id,poste)=>{
  if(id==null||poste>14)return;
  const avant=poste<8,cible=Number.isFinite(y)?y:35;
  // Petit gain : un avant ; course plus longue : le couloir compte d'abord.
  const ecart=Math.abs(COULOIR_DEFENSE[poste]-cible)+(gain<6?(avant?0:18):(avant?8:0))+(poste===5||poste===6?-4:0);
  if(ecart<meilleur){meilleur=ecart;choisi=String(id)}
 });
 return choisi;
}
// Note de match des joueurs d'une équipe (le manager, ou l'adversaire pour « à surveiller ») :
// 6 au coup d'envoi, puis ce que le journal leur attribue (courses et mètres, franchissements,
// essais, ballons récupérés, plaquages, tirs, cartons, fautes). Plaquages : chaque course
// adverse stoppée (moins de 22 m) et chaque ballon récupéré, comme le chiffre d'équipe.
function notesDuMatch(lignes,events,camp){
 const notes={};if(camp!==0&&camp!==1)return notes;
 const fiche=id=>notes[id]||(notes[id]={note:6,faits:0,essais:0,metres:0,plaquages:0});
 const ajoute=(id,valeur,fait)=>{if(id==null)return;const n=fiche(id);n.note+=valeur;n.faits++;if(fait==='essai')n.essais++;if(fait==='plaquage')n.plaquages++;if(typeof fait==='number')n.metres+=fait};
 for(const l of lignes){
  const s=events[l.i]?.scene;if(!s)continue;
  const gain=Number.isFinite(s.from?.x)&&Number.isFinite(s.to?.x)?Math.abs(s.to.x-s.from.x):0;
  // Course adverse stoppée : plaqueur déduit de la place défensive (voir `plaqueur`).
  if(l.kind==='carry'&&l.equipe===1-camp&&l.x!==null&&l.depuis!==null&&Math.abs(l.x-l.depuis)<22){ajoute(plaqueur(s.on?.[camp],gain,s.to?.y),.03,'plaquage');continue}
  if(s.actor==null)continue;
  const id=String(s.actor),nous=Array.isArray(s.on?.[camp])&&s.on[camp].map(String).includes(id);if(!nous)continue;
  if(l.kind==='carry')ajoute(id,.04+Math.min(.5,gain/45)+(gain>=22?.25:0),Math.round(gain));
  else if(l.kind==='try')ajoute(id,1,'essai');
  else if(l.kind==='turnover'){ajoute(id,.45);if(l.equipe===camp)notes[id].plaquages++}
  else if(l.kind==='reception')ajoute(id,.08);
  else if(l.kind==='kick')ajoute(id,.05);
  else if(l.kind==='goal')ajoute(id,.3);
  else if(l.kind==='miss')ajoute(id,-.15);
  else if(l.kind==='card')ajoute(id,s.card==='red'||l.cause==='red'?-2:-1);
  else if((l.kind==='hand-fault'||l.kind==='penalty')&&s.team!==camp)ajoute(id,-.35);
 }
 for(const n of Object.values(notes))n.note=Math.round(Math.max(3,Math.min(9.9,n.note))*10)/10;
 return notes;
}
// XV adverse (onglet de la tuile Mon XV) : la feuille adverse telle que le dernier fait montré
// la donne (un remplacement à venir n'y est pas), notes et chiffres bornés à ce qui a été montré.
function xvAdverse(lignes,events,camp,effectif){
 if(camp!==0&&camp!==1)return [];
 const eux=1-camp,notes=notesDuMatch(lignes,events,eux),fiches=new Map((effectif||[]).map(p=>[String(p.id),p]));
 let on=null;
 for(let k=lignes.length-1;k>=0&&!on;k--){const o=events[lignes[k].i]?.scene?.on?.[eux];if(Array.isArray(o)&&o.length)on=o}
 if(!on)return [];
 return on.slice(0,15).map(id=>{
  if(id==null)return null;const f=fiches.get(String(id)),n=notes[String(id)]||{note:6,faits:0,essais:0,metres:0,plaquages:0};
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
// Le journal du moteur nomme les clubs par leur sigle interne (« FDG ») ; l'écran les nomme par
// leur identité affichée (presentation.abbr). Le texte montré reprend le sigle affiché.
function renommeur(equipes){
 const paires=(Array.isArray(equipes)?equipes:[]).map(t=>[String(t?.abbr||''),String(t?.presentation?.abbr||'')]).filter(([a,b])=>/^[A-Z0-9]{2,5}$/.test(a)&&b&&a!==b);
 if(!paires.length)return t=>String(t||'');
 const motif=new RegExp('(?<![\\p{L}\\p{N}])('+paires.map(p=>p[0]).join('|')+')(?![\\p{L}\\p{N}])','gu'),table=new Map(paires);
 return t=>String(t||'').replace(motif,a=>table.get(a));
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
 const reperes=vues.filter(l=>l.kind==='try'||l.kind==='goal'||l.kind==='card'&&l.incident).map(l=>({i:l.i,kind:l.kind,equipe:l.equipe,horloge:horloge(l),minute:l.minute,x:l.x,y:events[l.i].scene?.to?.y??35,rouge:l.cause==='red'}));
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
 const tot=a=>a[0]+a[1],minuteVue=derniere?.minute??0,MIN_FAITS=6;
 const compte=(rang)=>({...rang,vide:rang.valeurs[0]+rang.valeurs[1]===0&&minuteVue<10});
 const tableau=[
  {cle:'possession',label:'Possession',valeurs:pourcent(tenus[0],tenus[1]),unite:'%',vide:tot(tenus)<MIN_FAITS},
  {cle:'occupation',label:'Occupation',valeurs:pourcent(occupes[0],occupes[1]),unite:'%',vide:tot(occupes)<MIN_FAITS},
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
 const direct={version:1,rencontre:String(etat.rencontre||''),niveau,niveaux:NIVEAUX.map(id=>({id,label:LIBELLES[id]})),horloge:etat.horloge||'',
  // Minute du dernier fait montré (borne) : l'horloge de l'entracte ne court pas devant ce qui a été vu.
  horlogeMontree:derniere?horloge(derniere):etat.horloge||'',camp:etat.camp??-1,
  possession:derniere?.possession??(vues.length?null:etat.possession??null),zone:{x:Number.isFinite(derniere?.x)?derniere.x:50,kind:derniere?.kind||'message'},
  fil,traces,reperes,chiffres,elan,cartons:(etat.cartons||[]).filter(c=>vues.some(l=>l.kind==='card'&&String(events[l.i].scene?.actor)===String(c.id))),
  borne,score:vues.length?vues.at(-1).scoreApres:[0,0],statsRows:passe?.statsRows||[],
  tableau,domination:domination(vues),notes:notesDuMatch(vues,events,etat.camp??-1),adversaire:xvAdverse(vues,events,etat.camp??-1,etat.effectifAdverse),deroule:deroule(vues,events,lire,String(etat.rencontre||''),nommer),
  bilan:{tempsForts:bilan.nombre,action:bilan.dureeAction,rafales:bilan.rafales,rafalesSautees:bilan.rafalesSautees},tempsFort:null,arret:null};
 const tf=bilan.courant;
 if(tf){
  const indices=tf.plans.filter(p=>p.kind!=='transformation').map(p=>p.i),scenes=lire.scenes(indices),parIndex=new Map(indices.map((i,n)=>[i,scenes[n]]));
  const plans=[];
  for(const p of tf.plans){
   const scene=p.kind==='transformation'?lire.transformation(p.i,p.reussie):parIndex.get(p.i);
   if(!scene)continue; // sans scène enregistrée, le plan reste dans le fil
   plans.push({index:p.i,kind:p.kind,duree:p.duree,mouvement:p.mouvement,coupe:p.coupe,horloge:horloge(lignes[p.i]),
    texte:legende(p,nommer(events[p.i].text)),...(ANNONCES[p.kind]?{annonce:ANNONCES[p.kind]}:{}),
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
   duree:tf.duree,debut:tf.debut,fin:tf.fin,
   // Déclenchement (journal de régie et tests ; jamais affiché : il ne doit rien annoncer).
   declenchement:tf.declencheur===undefined?null:{fait:tf.declencheur,importance:tf.importance,seuil:tf.seuil,rattrapage:tf.rattrapage===true},scoreAvant:lignes[plans[0].index].scoreAvant,horlogeDebut:horloge(lignes[tf.debut]),horlogeFin:horloge(lignes[tf.fin]),depart,plans,
   bandeaux:tf.bandeaux.map(i=>({kind:lignes[i].kind,texte:nommer(events[i].text)}))};
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
    direct.arret={cle:'carton-'+i,raison:'carton',rouge:l.cause==='red',pourNous:l.equipe!==direct.camp,texte:nommer(events[i].text),horloge:horloge(l)};
  }
 }
 return direct;
}

module.exports=Object.freeze({NIVEAUX,LIBELLES,lecteur,project,borneEntracte,domination,chiffresRugby,notesDuMatch,xvAdverse,plaqueur,DEROULE_MAX});
