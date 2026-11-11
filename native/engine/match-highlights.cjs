'use strict';
// Temps forts d'un match — PROTOTYPE de sélection (conception du 11 novembre 2026,
// docs/match-temps-forts-conception-20261111.md).
//
// Post-traitement pur du journal d'un match (`live.events`) : aucune lecture ni
// écriture de l'état du moteur, aucun tirage aléatoire, aucune modification des
// événements reçus. Le résultat sportif ne dépend jamais de ce module. Il n'est
// branché sur aucun écran : il sert à mesurer et à régler la sélection.
//
// Entrée : les événements tels que le moteur les écrit
//   {min, period, type, text, scene:{kind, team, possession, from, to, score, tries, move, incident, actor}}
// Sortie : pour un niveau donné, la liste des temps forts
//   {debut, fin, minuteDebut, minuteFin, type, types, score, force, duree, plans, coupes}
// où `debut` et `fin` sont des indices (inclus) dans le journal.

const NIVEAUX=Object.freeze({
 // seuil : score d'intérêt minimal d'une action pour ouvrir un temps fort ;
 // avant / apres : nombre maximal d'actions montrées avant et après l'action décisive ;
 // cible : durée d'action visée en secondes [minimum, maximum] pour 80 minutes.
 aucun:Object.freeze({seuil:Infinity,avant:0,apres:0,cible:[0,0]}),       // commentaire seul
 resume:Object.freeze({seuil:Infinity,avant:1,apres:0,cible:[0,150]}),     // seulement ce qui change le score ou l'effectif
 cles:Object.freeze({seuil:78,avant:2,apres:0,cible:[120,210]}),
 etendus:Object.freeze({seuil:56,avant:4,apres:1,cible:[270,390]}),
 integral:Object.freeze({seuil:0,avant:99,apres:99,cible:[0,Infinity]}),   // tout le jeu, temps morts coupés
 // Le seuil et l'amorce du niveau dynamique dépendent de la tension du moment.
 dynamique:Object.freeze({seuil:null,avant:null,apres:1,cible:[120,420]})
});
const SEUIL_DYNAMIQUE=t=>86-32*t; // de 54 (tout se joue) à 80 (match plié)

// Durée de présentation visée par plan, en secondes, à vitesse normale. Ce sont
// des cibles de mise en scène, pas des mesures de l'écran actuel (0,32 s par événement).
// Touche (lancer, prise, redescente : 1,9 s), ballon porté (6,9 s) et essai (3 s) reprennent
// les durées mesurées des gestes de la PR 554 ; l'alignement est montré déjà formé.
const DUREES=Object.freeze({
 kickoff:3.5,drop22:3,goalLine:3,reception:2.5,carry:4.5,kick:4,touch:1.5,
 lineout:1.5,scrum:1.5,'setpiece-win-touche':2,'setpiece-win-melee':4,'setpiece-loss':3,maul:7,
 turnover:3,'hand-fault':2,penalty:1.5,card:3,goal:6,miss:5.5,try:5,transformation:4.5,ingoal:3.5,
 break:2,end:3
});
const ENTREE=0.6,SORTIE=0.8,COUPE=0.3,RALENTI=6;
// Horloge accélérée de l'écran intermédiaire : secondes réelles par minute de match.
const HORLOGE=Object.freeze({lente:3,normale:1.5,rapide:0.6,eclair:0.25});

// Plans jamais joués en 3D : ils passent en bandeau ou dans le fil de commentaire.
const BANDEAUX=new Set(['message','tactic','sub','advantage']);
// Événements qui terminent une action (ballon mort ou coup de sifflet).
const FINS=new Set(['touch','hand-fault','try','goal','miss','ingoal','penalty','break','end']);
// Événements qui lancent une action « déjà en place ».
const LANCEMENTS=new Set(['lineout','scrum','kickoff','drop22','goalLine']);

const borne=(n,min,max)=>Math.max(min,Math.min(max,n));
const distanceLigne=(equipe,x)=>equipe===0?100-x:x; // mètres jusqu'à la ligne d'essai adverse

// Le moteur n'écrit pas encore la cause d'une sortie ou d'une action d'en-but dans
// la scène. En attendant un champ structuré `scene.cause` (lot 1 du plan), elle est
// lue dans le texte, ici et nulle part ailleurs.
function cause(e){
 const s=e.scene;if(s?.cause)return s.cause;
 const t=e.text||'';
 if(s?.kind==='touch'){
  if(t.includes('50:22'))return '50-22';
  if(t.includes('pénaltouche'))return 'penalty-touch';
  if(t.includes('poussé en touche'))return 'carry-touch';
  if(t.includes('tir au but manqué'))return 'missed-goal-touch';
  if(t.includes('terminer la période'))return 'period-end';
  return t.includes('directement')?'direct-touch':'indirect-touch';
 }
 if(s?.kind==='ingoal'){
  if(t.includes('tenu dans l’en-but'))return 'held-up';
  if(t.includes('En-avant de l’attaque'))return 'ingoal-knock-on';
  if(t.includes('aplati par la défense'))return 'attacking-kick-grounded';
  if(t.includes('propre en-but'))return 'defender-grounded';
  return 'kick-dead';
 }
 if(s?.kind==='card'&&s.incident)return /carton rouge|second jaune/.test(t)?'red':'yellow';
 return null;
}

// Journal normalisé : une ligne par événement, avec l'horloge de match, le score
// avant et après, et la distance à la ligne adverse pour l'équipe concernée.
function normaliser(events){
 if(!Array.isArray(events))throw new TypeError('Journal de match indisponible');
 const lignes=[];let finPremiere=null,score=[0,0],essais=[0,0];
 for(let i=0;i<events.length;i++){
  const e=events[i]||{},s=e.scene&&typeof e.scene==='object'?e.scene:null;
  const kind=s?.kind||(['turnover','try','goal','penalty','advantage','card','sub','tactic','break','end','miss'].includes(e.type)?e.type:'message');
  const periode=e.period===2||s?.period===2?2:1;
  const min=Number.isFinite(e.min)?e.min:0;
  const minute=periode===2&&finPremiere!==null?40+min-finPremiere:min;
  if(kind==='break'&&finPremiere===null)finPremiere=min;
  const avant=score,essaisAvant=essais;
  if(Array.isArray(s?.score)&&s.score.length===2)score=[s.score[0],s.score[1]];
  if(Array.isArray(s?.tries)&&s.tries.length===2)essais=[s.tries[0],s.tries[1]];
  const equipe=[0,1].includes(s?.team)?s.team:null,possession=[0,1].includes(s?.possession)?s.possession:null;
  const x=Number.isFinite(s?.to?.x)?s.to.x:null,depuis=Number.isFinite(s?.from?.x)?s.from.x:x;
  lignes.push({i,kind,type:e.type||'play',periode,minute,equipe,possession,x,depuis,
   touche:s?Number.isFinite(s.from?.y)&&s.from.y<=4:false,move:s?.move||null,incident:s?.incident===true,
   scoreAvant:avant,scoreApres:score,essaisAvant,essaisApres:essais,cause:cause(e),
   bandeau:BANDEAUX.has(kind)||kind==='card'&&!s?.incident||kind==='miss'&&e.type!=='miss'});
 }
 return lignes;
}

// Tension du moment, de 0 (match plié) à 1 (tout se joue), à partir de l'écart,
// de l'horloge, des bonus de classement et du type de rencontre.
function tension(ligne,{eliminatoire=false,bonus=true}={}){
 const ecart=Math.abs(ligne.scoreAvant[0]-ligne.scoreAvant[1]),m=ligne.minute;
 let t=ecart<=3?1:ecart<=7?.9:ecart<=14?.62:ecart<=21?.42:.2;
 if(m>=60)t+=ecart<=7?.15:ecart>21?-.1:0;
 else if(ligne.periode===1&&m>=37&&ecart<=14)t+=.05;
 if(m<10)t=Math.max(t-.15,.5); // début de match : tout est ouvert, rien n'est encore décisif
 if(bonus&&!eliminatoire){
  // Bonus défensif à cinq points d'écart au plus, bonus offensif à trois essais d'écart.
  const essais=Math.abs(ligne.essaisAvant[0]-ligne.essaisAvant[1]);
  if(m>=55&&(ecart>=4&&ecart<=12||essais===2||essais===3))t+=.12;
 }
 if(eliminatoire)t+=.1;
 return borne(t,0,1);
}

// Action décisive portée par un événement : type de temps fort et intérêt de base (0–100).
function action(l,lignes){
 const k=l.kind,d=l.equipe===null||l.x===null?null:distanceLigne(l.equipe,l.x);
 if(k==='try')return {type:'essai',base:100,force:true};
 if(k==='goal')return {type:'penalite_reussie',base:74,force:true};
 if(k==='miss'&&l.type==='miss')return {type:'penalite_manquee',base:64};
 if(k==='card'&&l.incident)return l.cause==='red'?{type:'carton_rouge',base:94,force:true}:{type:'carton_jaune',base:80};
 if(k==='ingoal'){
  if(l.cause==='ingoal-knock-on')return {type:'essai_refuse',base:84};
  if(l.cause==='held-up')return {type:'ballon_tenu_en_but',base:82};
  if(l.cause==='defender-grounded')return {type:'en_but_sous_pression',base:58};
  return {type:l.cause==='kick-dead'?'ballon_mort':'en_but_defendu',base:l.cause==='kick-dead'?22:36};
 }
 if(k==='touch'&&l.cause==='50-22')return {type:'cinquante_22',base:64};
 if(k==='lineout'&&d!==null&&d<=10)return {type:'touche_5m',base:60-(d>6?6:0),lancement:true};
 if(k==='scrum'&&l.type==='setup'&&d!==null&&d<=10)return {type:'melee_5m',base:58-(d>6?6:0),lancement:true};
 if(k==='setpiece-win'&&l.move==='maul'&&d!==null&&d<=22)return {type:'ballon_porte',base:d<=10?58:50};
 if(k==='carry'&&l.depuis!==null&&d!==null){
  const gain=Math.abs(l.x-l.depuis),entree=d<=22&&distanceLigne(l.equipe,l.depuis)>22;
  if(gain>=22)return {type:'franchissement',base:entree?60:50};
  if(d<=8)return {type:'pres_de_la_ligne',base:54};
  if(entree)return {type:'entree_dans_les_22',base:40};
  return d<=22?{type:'jeu_dans_les_22',base:34}:{type:'progression',base:12};
 }
 if(k==='turnover'||k==='setpiece-loss'){
  if(l.equipe===null||l.x===null)return {type:'ballon_recupere',base:14};
  const perdant=1-l.equipe,danger=distanceLigne(perdant,l.x);
  if(danger<=22)return {type:'ballon_sauve',base:danger<=10?62:54}; // la défense récupère dans ses 22
  if(d<=30)return {type:'ballon_gratte_haut',base:50};            // récupération dans le camp adverse
  return k==='setpiece-loss'?{type:'conquete_volee',base:40}:{type:'ballon_recupere',base:16};
 }
 if(k==='kickoff'){
  const premier=!lignes.slice(0,l.i).some(p=>p.kind==='kickoff'),reprise=lignes[l.i-1]?.kind==='break'||lignes.slice(0,l.i).reverse().find(p=>!p.bandeau)?.kind==='break';
  if(premier)return {type:'coup_d_envoi',base:45,force:true,lancement:true};
  if(reprise)return {type:'reprise',base:40,lancement:true};
  return null;
 }
 if(k==='kick'&&l.depuis!==null&&Math.abs(l.x-l.depuis)>=35)return {type:'long_jeu_au_pied',base:26};
 if(k==='penalty')return {type:'penalite_sifflee',base:d!==null&&d<=45?30:18};
 if(k==='hand-fault')return {type:'faute_de_main',base:d!==null&&d<=22?38:12};
 if(k==='touch')return {type:'sortie_en_touche',base:8};
 if(k==='reception'||k==='setpiece-win'||k==='lineout'||k==='scrum'||k==='drop22'||k==='goalLine')return {type:'jeu_courant',base:10,lancement:LANCEMENTS.has(k)};
 return null;
}

function interet(l,a,options){
 const t=tension(l,options);
 let score=a.base*(.72+.56*t);
 // Une action qui change le meneur ou ramène à portée d'un essai transformé pèse plus.
 if(l.kind==='try'||l.kind==='goal'){
  const avant=l.scoreAvant[0]-l.scoreAvant[1],apres=l.scoreApres[0]-l.scoreApres[1];
  if(Math.sign(avant)!==Math.sign(apres)||Math.abs(avant)>7&&Math.abs(apres)<=7)score+=12;
 }
 return {score:Math.round(borne(score,0,100)),tension:t};
}

// Pression continue dans les 22 mètres : au moins deux actions de suite de la même équipe.
function pressions(lignes,options){
 const sorties=[];let debut=-1,equipe=null,n=0,fin=-1;
 const clore=()=>{if(n>=2){const l=lignes[fin],a={type:'pression_dans_les_22',base:borne(36+8*n,0,72)},v=interet(l,a,options);sorties.push({i:fin,debut,...a,...v})}debut=-1;equipe=null;n=0;};
 for(const l of lignes){
  if(l.bandeau)continue;
  const dedans=l.possession!==null&&l.x!==null&&distanceLigne(l.possession,l.x)<=22&&['carry','setpiece-win','lineout','scrum','reception'].includes(l.kind);
  if(dedans&&(equipe===null||equipe===l.possession)){if(debut<0)debut=l.i;equipe=l.possession;n++;fin=l.i}
  else{clore();if(dedans){debut=l.i;equipe=l.possession;n=1;fin=l.i}}
 }
 clore();return sorties;
}

function dureePlan(l){
 if(l.bandeau)return 0;
 if(l.kind==='setpiece-win')return (l.touche?DUREES['setpiece-win-touche']:DUREES['setpiece-win-melee'])+(l.move==='maul'?DUREES.maul:0);
 if(l.kind==='try')return DUREES.try+DUREES.transformation;
 return DUREES[l.kind]??0;
}

// Fenêtre d'un temps fort autour d'une action décisive : remonte jusqu'au
// lancement de l'action (touche ou mêlée formée, renvoi, ballon récupéré) sans
// franchir un ballon mort antérieur, puis descend jusqu'à la fin de l'action.
function fenetre(lignes,ancre,avant,apres){
 let debut=ancre.debut??ancre.i,vus=0;
 if(ancre.debut===undefined&&!ancre.lancement)for(let j=ancre.i-1;j>=0&&vus<avant;j--){
  const l=lignes[j];if(l.bandeau)continue;
  // La pénalité qui précède un tir au but ou un carton appartient à l'action.
  const chaine=l.kind==='penalty'&&['penalite_reussie','penalite_manquee','carton_jaune','carton_rouge'].includes(ancre.type)||l.kind==='card'&&l.incident;
  if(FINS.has(l.kind)&&!chaine||lignes[debut].minute-l.minute>1)break; // jamais plus d'une minute d'écart entre deux plans
  debut=j;if(!chaine)vus++; // le coup de sifflet et le carton ne consomment pas l'amorce
  if(LANCEMENTS.has(l.kind)||l.kind==='turnover'||l.kind==='setpiece-loss'||l.kind==='penalty')break;
 }
 let fin=ancre.i;vus=0;
 const ouvert=ancre.lancement||!FINS.has(lignes[ancre.i].kind)&&lignes[ancre.i].kind!=='card';
 if(ouvert)for(let j=ancre.i+1;j<lignes.length&&vus<Math.max(apres,ancre.lancement?3:0);j++){
  const l=lignes[j];if(l.bandeau)continue;
  if(LANCEMENTS.has(l.kind)&&!ancre.lancement||l.kind==='kickoff'||l.minute-lignes[fin].minute>1)break;
  fin=j;vus++;
  if(FINS.has(l.kind)||l.kind==='turnover'||l.kind==='setpiece-loss')break;
 }
 // Le carton suit la pénalité, le tir manqué a sa suite : ils restent dans le temps fort.
 while(fin+1<lignes.length&&(lignes[fin+1].bandeau||lignes[fin+1].kind==='card'&&lignes[fin+1].incident)&&lignes[fin+1].minute===lignes[fin].minute&&lignes[fin+1].kind!=='break'&&lignes[fin+1].kind!=='end')fin++;
 return [debut,fin];
}

function decrire(lignes,debut,fin,membres,ralentis){
 let duree=ENTREE+SORTIE,coupes=0,plans=0,precedent=null;
 for(let j=debut;j<=fin;j++){
  const l=lignes[j],d=dureePlan(l);if(!d)continue;
  plans++;duree+=d;
  // Coupe franche entre un ballon mort et la remise en jeu déjà en place.
  if(precedent&&(FINS.has(precedent.kind)||precedent.kind==='card')&&(LANCEMENTS.has(l.kind)||['goal','miss','try'].includes(l.kind))){coupes++;duree+=COUPE}
  if(l.kind==='try'){coupes++;duree+=COUPE} // essai → transformation prête
  precedent=l;
 }
 const tete=membres.reduce((a,b)=>b.score>a.score?b:a);
 const ralenti=ralentis&&membres.some(m=>m.type==='essai'&&m.score>=85);
 if(ralenti)duree+=RALENTI;
 return {debut,fin,minuteDebut:lignes[debut].minute,minuteFin:lignes[fin].minute,periode:lignes[debut].periode,
  type:tete.type,types:[...new Set(membres.map(m=>m.type))],score:tete.score,force:membres.some(m=>m.force),
  duree:Math.round(duree*10)/10,plans,coupes,ralenti};
}

function temps_forts(events,options={}){
 const niveau=options.niveau||'etendus',regle=NIVEAUX[niveau];
 if(!regle)throw new RangeError('Niveau de temps forts inconnu : '+niveau);
 const lignes=normaliser(events),ralentis=options.ralentis!==false;
 const montrables=lignes.filter(l=>!l.bandeau&&dureePlan(l)>0);
 const minutes=new Set(lignes.map(l=>l.periode+':'+l.minute)).size;
 const bilan=liste=>{
  const duree=liste.reduce((n,h)=>n+h.duree,0),couvertes=new Set(),plans=liste.reduce((n,h)=>n+h.plans,0);
  for(const h of liste)for(let j=h.debut;j<=h.fin;j++)couvertes.add(lignes[j].periode+':'+lignes[j].minute);
  const sautees=minutes-couvertes.size;
  return {niveau,tempsForts:liste,nombre:liste.length,dureeAction:Math.round(duree),plansMontres:plans,plansTotal:montrables.length,
   partPlansSautes:montrables.length?Math.round((1-plans/montrables.length)*1000)/10:0,
   minutesTotal:minutes,minutesSautees:sautees,partMinutesSautees:minutes?Math.round(sautees/minutes*1000)/10:0,
   dureeHorloge:Object.fromEntries(Object.entries(HORLOGE).map(([nom,s])=>[nom,Math.round(sautees*s)]))};
 };
 if(niveau==='aucun')return bilan([]);
 if(niveau==='integral'){
  // Tout est joué ; seuls les temps morts sont coupés. Un temps fort par période.
  const liste=[];
  for(const periode of [1,2]){
   const p=lignes.filter(l=>l.periode===periode);if(!p.length)continue;
   liste.push(decrire(lignes,p[0].i,p.at(-1).i,[{type:'periode_'+periode,score:100,force:true}],ralentis));
  }
  return bilan(liste);
 }
 const ancres=[];
 for(const l of lignes){
  if(l.bandeau)continue;
  const a=action(l,lignes);if(!a)continue;
  ancres.push({i:l.i,...a,...interet(l,a,options)});
 }
 ancres.push(...pressions(lignes,options));
 // Fin de match serrée : la dernière action est toujours montrée.
 const dernier=[...lignes].reverse().find(l=>!l.bandeau&&!['break','end'].includes(l.kind));
 if(dernier&&Math.abs(dernier.scoreApres[0]-dernier.scoreApres[1])<=7&&dernier.periode===2)ancres.push({i:dernier.i,type:'fin_de_match_serree',base:80,score:80,force:true,tension:1});
 const composer=(seuilFixe)=>{
  const fenetres=[];
  for(const a of ancres){
   const dynamique=niveau==='dynamique';
   const seuil=seuilFixe??(dynamique?SEUIL_DYNAMIQUE(a.tension):regle.seuil);
   // En dynamique, un match plié ne garde en « forcé » que les essais et les rouges.
   const force=a.force&&!(dynamique&&a.type==='penalite_reussie'&&a.tension<.35);
   if(!force&&a.score<seuil||niveau==='resume'&&a.type==='coup_d_envoi')continue;
   const avant=dynamique?Math.round(1+4*a.tension):regle.avant;
   const [debut,fin]=fenetre(lignes,a,avant,regle.apres);
   fenetres.push({debut,fin,membre:{type:a.type,score:a.score,force}});
  }
  fenetres.sort((a,b)=>a.debut-b.debut||a.fin-b.fin);
  const fusion=[];
  for(const f of fenetres){
   const d=fusion.at(-1);
   // Deux fenêtres qui se touchent, ou que ne séparent que des bandeaux, n'en font qu'une.
   // Au-delà, l'horloge accélérée reprend entre les deux : on ne joue pas neuf minutes d'un trait.
   const colle=d&&(f.debut<=d.fin||lignes[f.debut].minute-lignes[d.fin].minute<=1&&lignes.slice(d.fin+1,f.debut).every(l=>l.bandeau));
   if(colle){d.fin=Math.max(d.fin,f.fin);d.membres.push(f.membre)}else fusion.push({debut:f.debut,fin:f.fin,membres:[f.membre]});
  }
  return fusion.map(f=>decrire(lignes,f.debut,f.fin,f.membres,ralentis));
 };
 let liste=composer();
 if(options.cible!==false){
  const [min,max]=options.cible||regle.cible,total=l=>l.reduce((n,h)=>n+h.duree,0);
  // Match pauvre : on abaisse le seuil par paliers pour tenir la durée minimale.
  for(let seuil=(niveau==='dynamique'?66:Math.min(regle.seuil,82))-4;total(liste)<min&&seuil>=24;seuil-=4){
   const large=composer(seuil);if(total(large)>max)break;liste=large;
  }
  // Match trop riche : on retire les temps forts non forcés les moins intéressants.
  while(total(liste)>max){
   const candidats=liste.filter(h=>!h.force);if(!candidats.length)break;
   const retire=candidats.reduce((a,b)=>b.score<a.score?b:a);
   liste=liste.filter(h=>h!==retire);
  }
 }
 return bilan(liste);
}

module.exports=Object.freeze({NIVEAUX,DUREES,HORLOGE,normaliser,tension,temps_forts});
