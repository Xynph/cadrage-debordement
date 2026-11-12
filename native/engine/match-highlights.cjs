'use strict';
// Temps forts d'un match : sélection (conception du 11 novembre 2026,
// docs/match-temps-forts-conception-20261111.md).
//
// Calcul pur sur le journal d'un match (`live.events`) : aucune lecture ni
// écriture de l'état du moteur, aucun tirage aléatoire, aucune modification des
// événements reçus. Le résultat sportif ne dépend jamais de ce module.
//
// Entrée : les événements tels que le moteur les écrit
//   {min, period, type, text, scene:{kind, team, possession, from, to, score, tries, move, incident, actor,
//    cause, card, origin, conversion}}
// Deux sorties :
// - `en_direct` décide au fil du match, rafale par rafale (les événements d'un même pas du
//   moteur), avec le seul passé : c'est ce que joue le match en temps forts, mode de base du jeu ;
// - `temps_forts` choisit a posteriori sur le journal complet : il sert de référence de mesure.
// Un temps fort : {debut, fin, minuteDebut, minuteFin, type, types, score, force, duree, plans, coupes}
// où `debut` et `fin` sont des indices (inclus) dans le journal.

const NIVEAUX=Object.freeze({
 // seuil : score d'intérêt minimal d'une action pour ouvrir un temps fort ;
 // avant / apres : nombre maximal d'actions montrées avant et après l'action décisive ;
 // cible : durée d'action visée en secondes [minimum, maximum] pour 80 minutes.
 aucun:Object.freeze({seuil:Infinity,avant:0,apres:0,cible:[0,0]}),       // commentaire seul
 resume:Object.freeze({seuil:Infinity,avant:1,apres:0,cible:[0,150]}),     // seulement ce qui change le score ou l'effectif
 cles:Object.freeze({seuil:78,avant:2,apres:0,cible:[90,170]}),
 etendus:Object.freeze({seuil:56,avant:4,apres:1,cible:[200,300]}),
 integral:Object.freeze({seuil:0,avant:99,apres:99,cible:[0,Infinity]}),   // tout le jeu, temps morts coupés
 // Le seuil et l'amorce du niveau dynamique dépendent de la tension du moment.
 dynamique:Object.freeze({seuil:null,avant:null,apres:1,cible:[90,320]})
});
const SEUIL_DYNAMIQUE=t=>86-32*t; // de 54 (tout se joue) à 80 (match plié)

// Grosses actions sans point (12 novembre 2026, demande de Léo : « pas que des essais ou des
// transformations […] pour qu'on ne sache pas à l'avance ce qu'il va se passer ») : franchissement
// stoppé, essai sauvé ou tenu en l'air, ballon récupéré près de sa ligne, longue séquence
// défendue, pénalité manquée, contre-attaque, jeu au pied dangereux. Elles sont cotées au niveau
// d'une pénalité réussie, et le niveau dynamique en garde une part réelle (régulateur d'issue) :
// voir docs/match-temps-forts-conception-20261111.md, § 13.
const GROSSES=new Set(['franchissement','ballon_sauve','ballon_tenu_en_but','essai_refuse','penalite_manquee','pression_dans_les_22',
 'pres_de_la_ligne','cinquante_22','jeu_au_pied_dangereux','contre_attaque','touche_5m','melee_5m','en_but_sous_pression','ballon_porte']);
// Régulateur d'issue du niveau dynamique : après quatre temps forts, si la part de ceux qui
// marquent dépasse PART_POINTS, le seuil des grosses actions sans point baisse de BONUS_GROSSES
// (et remonte d'autant si elles dépassent PART_GROSSES). Deux temps forts de même type à moins
// de MEME_TYPE minutes : le second (non forcé) doit dépasser un seuil relevé de REPETITION.
const PART_POINTS=0.5,PART_GROSSES=0.5,BONUS_GROSSES=10,MEME_TYPE=8,REPETITION=12;

// Durée minimale d'un plan à l'écran, en secondes, à vitesse normale. Quand un geste
// de la vue 3D dure plus longtemps (touche portée, ballon porté, essai aplati de la
// PR 554), la lecture l'attend : ces valeurs sont alors un plancher. La progression
// balle en main dépend de la distance (course à COURSE m/s, puis une seconde au contact).
const DUREES=Object.freeze({
 kickoff:2.5,drop22:2.5,goalLine:2.5,reception:2,carry:1,kick:2.5,touch:1.5,
 lineout:1.5,scrum:1.5,'setpiece-win-touche':2,'setpiece-win-melee':3,'setpiece-loss':2.5,maul:5,
 turnover:2,'hand-fault':1.8,penalty:1.5,card:2.5,goal:4.5,miss:4,try:3.5,transformation:4,ingoal:3,
 break:1.5,end:2.5
});
const COURSE=6.5,ENTREE=0.6,SORTIE=0.8,COUPE=0.3,RALENTI=6;
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

// Le moteur écrit la cause d'une sortie ou d'une action d'en-but et la couleur du
// carton dans la scène (`cause`, `card`). Les journaux commencés avant ces champs ne
// les ont pas : pour eux seulement, la cause est lue dans le texte, ici et nulle part ailleurs.
function cause(e){
 const s=e.scene;if(s?.cause)return s.cause;
 if(s?.kind==='card'&&s.incident&&s.card)return s.card==='yellow'?'yellow':'red';
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
  // Transformation : fait structuré de l'essai, sinon lue dans le score (7 ou 5 points).
  const transformation=kind!=='try'?null:typeof s.conversion==='boolean'?s.conversion:equipe!==null&&score[equipe]-avant[equipe]===7;
  lignes.push({i,kind,type:e.type||'play',periode,min,minute,equipe,possession,x,depuis,transformation,
   touche:s?Number.isFinite(s.from?.y)&&s.from.y<=4:false,move:s?.move||null,porte:s?.porte===true,incident:s?.incident===true,
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
 if(k==='miss'&&l.type==='miss')return {type:'penalite_manquee',base:70};
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
 if(k==='setpiece-win'&&(l.move==='maul'||l.porte)&&d!==null&&d<=22)return {type:'ballon_porte',base:d<=10?58:50};
 if(k==='carry'&&l.depuis!==null&&d!==null){
  const gain=Math.abs(l.x-l.depuis),entree=d<=22&&distanceLigne(l.equipe,l.depuis)>22;
  if(gain>=22)return {type:'franchissement',base:entree?70:62};
  if(d<=8)return {type:'pres_de_la_ligne',base:60};
  // Contre-attaque : douze mètres au moins gagnés depuis son propre camp.
  if(gain>=12&&distanceLigne(l.equipe,l.depuis)>=55)return {type:'contre_attaque',base:54};
  if(entree)return {type:'entree_dans_les_22',base:40};
  return d<=22?{type:'jeu_dans_les_22',base:34}:{type:'progression',base:12};
 }
 if(k==='turnover'||k==='setpiece-loss'){
  if(l.equipe===null||l.x===null)return {type:'ballon_recupere',base:14};
  const perdant=1-l.equipe,danger=distanceLigne(perdant,l.x);
  if(danger<=22)return {type:'ballon_sauve',base:danger<=10?70:62}; // la défense récupère dans ses 22
  if(d<=30)return {type:'ballon_gratte_haut',base:40};            // récupération dans le camp adverse
  return k==='setpiece-loss'?{type:'conquete_volee',base:40}:{type:'ballon_recupere',base:16};
 }
 if(k==='kickoff'){
  const premier=!lignes.slice(0,l.i).some(p=>p.kind==='kickoff'),reprise=lignes[l.i-1]?.kind==='break'||lignes.slice(0,l.i).reverse().find(p=>!p.bandeau)?.kind==='break';
  if(premier)return {type:'coup_d_envoi',base:45,force:true,lancement:true};
  if(reprise)return {type:'reprise',base:40,lancement:true};
  return null;
 }
 // Jeu au pied dangereux : le ballon tombe dans les 22 adverses.
 if(k==='kick'&&l.depuis!==null&&d!==null&&d<=22&&Math.abs(l.x-l.depuis)>=20)return {type:'jeu_au_pied_dangereux',base:56};
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

// Temps de course d'une progression balle en main : la distance gagnée à COURSE m/s.
function mouvementPlan(l){
 if(l.kind!=='carry'||l.x===null||l.depuis===null)return 0;
 return Math.round(borne(Math.abs(l.x-l.depuis)/COURSE,.8,3.6)*10)/10;
}
function dureePlan(l){
 if(l.bandeau)return 0;
 if(l.kind==='setpiece-win')return (l.touche?DUREES['setpiece-win-touche']:DUREES['setpiece-win-melee'])+(l.move==='maul'||l.porte?DUREES.maul:0);
 if(l.kind==='carry')return mouvementPlan(l)+DUREES.carry;
 return DUREES[l.kind]??0;
}
// Plans d'une fenêtre, dans l'ordre de lecture. `coupe` : coupe franche vers une phase
// déjà en place (alignement formé, packs liés, tireur prêt, équipes en place au renvoi).
// L'essai est suivi d'un plan déduit, sans événement : la transformation, buteur prêt.
// Le coup de pied de pénaltouche n'est montré qu'en match complet (`tout`) : ailleurs,
// on passe du coup de sifflet à l'alignement formé.
function plansDe(lignes,debut,fin,tout=false){
 const plans=[],bandeaux=[];
 for(let j=debut;j<=fin;j++){
  const l=lignes[j],d=dureePlan(l);
  if(!d){if(l.bandeau)bandeaux.push(j);continue}
  if(!tout&&l.kind==='touch'&&l.cause==='penalty-touch'&&j<fin)continue;
  // Une remise en jeu ou un tir au but suit toujours un arrêt : on y arrive par une coupe.
  plans.push({i:j,kind:l.kind,minute:l.minute,periode:l.periode,duree:d,mouvement:mouvementPlan(l),
   coupe:LANCEMENTS.has(l.kind)||l.kind==='goal'||l.kind==='miss'});
  if(l.kind==='try')plans.push({i:j,kind:'transformation',minute:l.minute,periode:l.periode,duree:DUREES.transformation,mouvement:0,coupe:true,reussie:l.transformation===true});
 }
 return {plans,bandeaux};
}

// Fenêtre d'un temps fort autour d'une action décisive : remonte jusqu'au
// lancement de l'action (touche ou mêlée formée, renvoi, ballon récupéré) sans
// franchir un ballon mort antérieur, puis descend jusqu'à la fin de l'action.
function fenetre(lignes,ancre,avant,apres,plancher=0,plafond=lignes.length-1){
 let debut=Math.max(plancher,ancre.debut??ancre.i),vus=0;
 if(ancre.debut===undefined&&!ancre.lancement)for(let j=ancre.i-1;j>=plancher&&vus<avant;j--){
  const l=lignes[j];if(l.bandeau)continue;
  // La pénalité qui précède un tir au but ou un carton appartient à l'action.
  const chaine=l.kind==='penalty'&&['penalite_reussie','penalite_manquee','carton_jaune','carton_rouge'].includes(ancre.type)||l.kind==='card'&&l.incident;
  if(FINS.has(l.kind)&&!chaine||lignes[debut].minute-l.minute>1)break; // jamais plus d'une minute d'écart entre deux plans
  debut=j;if(!chaine)vus++; // le coup de sifflet et le carton ne consomment pas l'amorce
  if(LANCEMENTS.has(l.kind)||l.kind==='turnover'||l.kind==='setpiece-loss'||l.kind==='penalty')break;
 }
 let fin=ancre.i;vus=0;
 const ouvert=ancre.lancement||!FINS.has(lignes[ancre.i].kind)&&lignes[ancre.i].kind!=='card';
 if(ouvert)for(let j=ancre.i+1;j<=plafond&&vus<Math.max(apres,ancre.lancement?3:0);j++){
  const l=lignes[j];if(l.bandeau)continue;
  if(LANCEMENTS.has(l.kind)&&!ancre.lancement||l.kind==='kickoff'||l.minute-lignes[fin].minute>1)break;
  fin=j;vus++;
  if(FINS.has(l.kind)||l.kind==='turnover'||l.kind==='setpiece-loss')break;
 }
 // Le carton suit la pénalité, le tir manqué a sa suite : ils restent dans le temps fort.
 while(fin+1<=plafond&&(lignes[fin+1].bandeau||lignes[fin+1].kind==='card'&&lignes[fin+1].incident)&&lignes[fin+1].minute===lignes[fin].minute&&lignes[fin+1].kind!=='break'&&lignes[fin+1].kind!=='end')fin++;
 return [debut,fin];
}

function decrire(lignes,debut,fin,membres,ralentis,suite=false,tout=false){
 const {plans}=plansDe(lignes,debut,fin,tout),coupes=plans.filter((p,n)=>p.coupe&&n>0).length;
 // Un temps fort qui en prolonge un autre n'a pas de fondu d'entrée.
 let duree=(suite?0:ENTREE)+SORTIE+plans.reduce((n,p)=>n+p.duree,0)+coupes*COUPE;
 const tete=membres.reduce((a,b)=>b.score>a.score?b:a);
 const ralenti=ralentis&&membres.some(m=>m.type==='essai'&&m.score>=85);
 if(ralenti)duree+=RALENTI;
 return {debut,fin,minuteDebut:lignes[debut].minute,minuteFin:lignes[fin].minute,periode:lignes[debut].periode,
  type:tete.type,types:[...new Set(membres.map(m=>m.type))],score:tete.score,force:membres.some(m=>m.force),
  duree:Math.round(duree*10)/10,plans:plans.filter(p=>p.kind!=='transformation').length,coupes,ralenti};
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

// ---------------------------------------------------------------------------
// Sélection en direct. Le moteur avance d'une minute par pas ; les événements d'un
// même pas forment une rafale. À chaque rafale, la décision (jouer en 3D ou laisser
// l'horloge filer) n'utilise que le journal déjà écrit : l'amorce revient sur des
// plans déjà simulés et pas encore montrés, jamais sur le futur. La fonction rejoue
// toutes les décisions depuis le coup d'envoi : elle est sans état et répétable, et
// la décision d'une rafale ne change plus quand le match continue.
function rafales(lignes){
 const liste=[];
 for(const l of lignes){
  const cle=l.periode+':'+l.min,d=liste.at(-1);
  if(d&&d.cle===cle)d.fin=l.i;else liste.push({cle,debut:l.i,fin:l.i});
 }
 return liste;
}
const DEDANS=['carry','setpiece-win','lineout','scrum','reception'];
const dansLes22=l=>!l.bandeau&&l.possession!==null&&l.x!==null&&distanceLigne(l.possession,l.x)<=22&&DEDANS.includes(l.kind);

function en_direct(events,options={}){
 const niveau=options.niveau||'dynamique',regle=NIVEAUX[niveau];
 if(!regle)throw new RangeError('Niveau de temps forts inconnu : '+niveau);
 const lignes=normaliser(events),dynamique=niveau==='dynamique',regule=options.cible!==false&&['cles','etendus','dynamique'].includes(niveau);
 const cible=options.cible||regle.cible;
 const etat={montre:-1,cumul:0,decalage:0,reglage:0,ouvert:false,suites:0,equipe:null,dernierJoue:false,
  episodes:0,points:0,grosses:0,dernierType:null,dernierMinute:-99};
 const decisions=[];
 for(const r of rafales(lignes)){
  const jouables=[];
  for(let j=Math.max(r.debut,etat.montre+1);j<=r.fin;j++)if(!lignes[j].bandeau&&dureePlan(lignes[j])>0)jouables.push(j);
  const derniere=lignes[r.fin],decision={rafale:[r.debut,r.fin],periode:derniere.periode,minute:derniere.minute,joue:false,tempsFort:null,seuil:null};
  let debut=-1,fin=-1,membres=[],suite=false;
  if(niveau==='integral'&&jouables.length){
   debut=jouables[0];fin=jouables.at(-1);membres=[{type:'jeu',score:100,force:true}];suite=etat.dernierJoue;
  }else if(niveau!=='aucun'&&jouables.length){
   const ancres=[];
   for(const j of jouables){const a=action(lignes[j],lignes);if(a)ancres.push({i:j,...a,...interet(lignes[j],a,options)})}
   // Pression dans les 22 : la série en cours, si elle passe par cette rafale.
   let n=0,premier=-1,equipe=null;
   for(let j=r.fin;j>etat.montre;j--){
    const l=lignes[j];if(l.bandeau)continue;
    if(!dansLes22(l)||equipe!==null&&l.possession!==equipe){if(n===0&&j>=r.debut)continue;break}
    equipe=l.possession;n++;premier=j;
   }
   const dernierDedans=jouables.filter(j=>dansLes22(lignes[j])).at(-1);
   if(n>=2&&dernierDedans!==undefined){const a={type:'pression_dans_les_22',base:borne(36+8*n,0,72)};ancres.push({i:dernierDedans,debut:premier,...a,...interet(lignes[dernierDedans],a,options)})}
   // Fin de match serrée : après la 78e, à un essai transformé d'écart, tout est montré.
   if(derniere.periode===2&&derniere.minute>=78&&Math.abs(derniere.scoreApres[0]-derniere.scoreApres[1])<=7&&!['break','end'].includes(lignes[jouables.at(-1)].kind))
    ancres.push({i:jouables.at(-1),type:'fin_de_match_serree',base:80,score:80,force:true,tension:1});
   // Niveau dynamique : part réelle de grosses actions sans point, et pas deux temps forts
   // quasi identiques d'affilée (même type à moins de MEME_TYPE minutes).
   const issue=a=>{
    if(!dynamique||etat.episodes<4)return 0;
    let ajuste=0;
    if(GROSSES.has(a.type)){
     if(etat.points/etat.episodes>PART_POINTS)ajuste-=BONUS_GROSSES;
     else if(etat.grosses/etat.episodes>PART_GROSSES)ajuste+=BONUS_GROSSES;
    }
    return ajuste;
   };
   const repetition=a=>dynamique&&a.type===etat.dernierType&&derniere.minute-etat.dernierMinute<MEME_TYPE?REPETITION:0;
   const seuilDe=a=>(dynamique?SEUIL_DYNAMIQUE(a.tension):regle.seuil)+etat.decalage+issue(a)+repetition(a);
   const forcee=a=>a.force&&!(dynamique&&a.type==='penalite_reussie'&&a.tension<.35);
   const retenues=ancres.filter(a=>(forcee(a)||a.score>=seuilDe(a))&&!(niveau==='resume'&&a.type==='coup_d_envoi'));
   decision.seuil=ancres.length?Math.round(Math.min(...ancres.map(seuilDe))):null;
   if(retenues.length){
    debut=Infinity;
    for(const a of retenues){
     const avant=dynamique?Math.round(1+4*a.tension):regle.avant;
     const [d,f]=fenetre(lignes,a,avant,regle.apres,etat.montre+1,r.fin);
     debut=Math.min(debut,d);fin=Math.max(fin,f);membres.push({type:a.type,score:a.score,force:forcee(a)});
    }
    suite=etat.ouvert&&debut<=r.debut;
    // Un plan isolé ne fait pas un temps fort : on allonge l'amorce de deux plans, et
    // faute de mieux on laisse l'horloge filer. Ce qui marque ou exclut reste montré.
    if(!suite&&!membres.some(m=>m.force)&&plansDe(lignes,debut,fin).plans.length<2){
     for(const a of retenues){const [d]=fenetre(lignes,a,(dynamique?Math.round(1+4*a.tension):regle.avant)+2,regle.apres,etat.montre+1,r.fin);debut=Math.min(debut,d)}
     if(plansDe(lignes,debut,fin).plans.length<2){debut=-1;fin=-1;membres=[]}
    }
   }else if(etat.ouvert&&regle.apres>0&&etat.suites<2){
    // L'action montrée n'était pas finie : on reste en direct tant qu'elle dure.
    const proche=ancres.filter(a=>a.score>=seuilDe(a)-16);
    const pression=jouables.some(j=>dansLes22(lignes[j])&&lignes[j].possession===etat.equipe);
    if(proche.length||pression){
     debut=jouables[0];fin=jouables.at(-1);suite=true;
     const tete=ancres.reduce((a,b)=>!a||b.score>a.score?b:a,null);
     membres=[{type:tete?tete.type:'suite_de_l_action',score:tete?tete.score:0,force:false}];
     // Le renvoi après des points n'est pas une suite.
     const marque=jouables.find(j=>['try','goal'].includes(lignes[j].kind));
     if(marque!==undefined)fin=marque;
    }
   }
  }
  if(debut>=0&&fin>=debut){
   const tout=niveau==='integral',{plans,bandeaux}=plansDe(lignes,debut,fin,tout);
   if(plans.length){
    // Clé : début et dernier plan montré. Un remplacement ou une consigne donnés pendant la
    // pause ajoutent des bandeaux à la même minute et allongent la fenêtre, pas les plans :
    // le temps fort reste le même et n'est pas rejoué.
    const tf={cle:debut+'-'+plans.at(-1).i,suite,...decrire(lignes,debut,fin,membres,false,suite,tout),plans,bandeaux};
    tf.plans=plans;tf.nombrePlans=plans.length;
    decision.joue=true;decision.tempsFort=tf;
    const dernier=lignes[plans.at(-1).i];
    etat.suites=suite?etat.suites+1:0;etat.montre=fin;etat.cumul+=tf.duree;
    // Ouverte : la rafale a été montrée jusqu'au bout et le ballon vit encore.
    etat.ouvert=plans.at(-1).i===jouables.at(-1)&&!FINS.has(dernier.kind)&&!['turnover','setpiece-loss','card'].includes(dernier.kind);
    etat.equipe=dernier.possession;
    if(!suite){
     etat.episodes++;
     const kinds=plans.map(p=>p.kind);
     if(kinds.includes('try')||kinds.includes('goal'))etat.points++;
     else if(tf.types.some(t=>GROSSES.has(t)))etat.grosses++;
     etat.dernierType=tf.type;etat.dernierMinute=derniere.minute;
    }
   }
  }
  if(!decision.joue){etat.ouvert=false;etat.suites=0}
  etat.dernierJoue=decision.joue;
  // Régulateur de rythme : toutes les cinq minutes de match, le temps d'action déjà
  // montré est comparé à la cible du niveau ; le seuil se déplace de 4 points.
  const m=Math.min(80,derniere.minute);
  if(regule&&m>=10&&m-etat.reglage>=5){
   etat.reglage=m;
   if(etat.cumul<cible[0]*m/80)etat.decalage=Math.max(-16,etat.decalage-4);
   else if(etat.cumul>cible[1]*m/80)etat.decalage=Math.min(16,etat.decalage+4);
   else etat.decalage-=Math.sign(etat.decalage)*4;
  }
  decision.decalage=etat.decalage;
  decisions.push(decision);
 }
 const tempsForts=decisions.filter(d=>d.joue).map(d=>d.tempsFort),derniereDecision=decisions.at(-1)||null;
 const montrables=lignes.filter(l=>!l.bandeau&&dureePlan(l)>0).length,montres=tempsForts.reduce((n,h)=>n+h.plans.filter(p=>p.kind!=='transformation').length,0);
 const sautees=decisions.filter(d=>!d.joue).length;
 return {niveau,decisions,tempsForts,courant:derniereDecision?.joue?derniereDecision.tempsFort:null,
  nombre:tempsForts.filter(h=>!h.suite).length,dureeAction:Math.round(etat.cumul),plansMontres:montres,plansTotal:montrables,
  partPlansSautes:montrables?Math.round((1-montres/montrables)*1000)/10:0,
  rafales:decisions.length,rafalesSautees:sautees,partRafalesSautees:decisions.length?Math.round(sautees/decisions.length*1000)/10:0,
  dureeHorloge:Object.fromEntries(Object.entries(HORLOGE).map(([nom,sec])=>[nom,Math.round(sautees*sec)]))};
}

module.exports=Object.freeze({NIVEAUX,DUREES,HORLOGE,GROSSES,FINS,LANCEMENTS,dansLes22,normaliser,tension,temps_forts,en_direct});
