'use strict';
// Avis du conseil sur notre jeu (revue FM27, idée n° 31 ; choix de Léo du 23/11/2026 : option A, effet réel, attentes
// propres à chaque club, entrées dans les 22 m). Onglet Club › Notre jeu.
//  - Chiffres : les matchs de la saison dans notre championnat (S.history, phase « league »), comparés à la moyenne des
//    clubs du même championnat et classés (rang). 16 chiffres en 6 familles : plan de jeu, conquête, spectacle, attaque
//    (dont les entrées dans les 22 m adverses, stats[i].entries22), défense, formation (jeunes de moins de 23 ans dans le
//    XV de départ, stats[i].jeunes). Ces deux derniers chiffres n'existent que pour les matchs joués depuis le 23/11/2026.
//  - Note d'un chiffre sur 100 : 50 au niveau de la moyenne, 100 à +35 %, 0 à −35 % (écart de points : 10 points = 35 %) ;
//    avis ▲ à +8 %, ▼ à −8 %. Note d'une famille = moyenne de ses chiffres.
//  - Attentes du conseil : chaque club a une identité de jeu (Spectacle, Défense, Combat devant, Formation, Résultats),
//    tirée de son style de jeu habituel (managerStyle), des traits de sa direction (club-directions.cjs : ambition et
//    prudence du président, goût du directeur sportif pour la formation, confiance de l'entraîneur aux jeunes) et d'une
//    part de hasard (graine de la carrière). L'identité donne une importance de 1 à 3 à chaque famille. Note du jeu =
//    moyenne des familles pondérée par ces importances.
//  - Effet réel : au bilan du conseil (tous les 3 matchs, dist/career-integration.js), la note du jeu compte pour 15 %
//    de la note du club, avec une part de hasard (±6, graine, saison, journée) : le conseil a son humeur du jour.
//    Rien de chiffré sur cet effet n'est montré au manager (lettre, mots et flèches seulement).
// Sauvegarde : S.conseilJeu = {version:1, attentes:{idClub: identité}} (identité fixée au premier bilan du club géré ;
// absente des anciennes sauvegardes, elle est alors recalculée à l'identique). Projection : clubLife.conseilJeu.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const SEUIL=.08,PLEIN=.35,BRUIT=6,MIN_MATCHS=3;
 // id : [libellé, unité, sens (+1 : plus c'est haut, mieux c'est), cumul (total de la saison montré dans la fenêtre)].
 const INDICATEURS=Object.freeze({
  victoires:['Victoires','%',1,false],ecart:['Écart de points','',1,false],
  melee:['Mêlées gagnées','%',1,false],touche:['Touches gagnées','%',1,false],possession:['Possession','%',1,false],
  essais:['Essais par match','',1,true],bonus:['Matchs à 4 essais','%',1,false],
  points:['Points marqués','',1,true],entrees22:['Entrées dans les 22 m','',1,true],territoire:['Territoire','%',1,false],buteur:['Réussite au but','%',1,false],
  encaisses:['Points encaissés','',-1,true],essais_enc:['Essais encaissés','',-1,true],penalites:['Pénalités concédées','',-1,true],jaunes:['Cartons jaunes','',-1,true],
  jeunes:['Jeunes titulaires (−23 ans)','',1,false]});
 const FAMILLES=Object.freeze([
  ['plan','Plan de jeu','tactic',['victoires','ecart']],
  ['conquete','Conquête','people',['melee','touche','possession']],
  ['spectacle','Spectacle','star',['essais','bonus']],
  ['attaque','Attaque','ball',['points','entrees22','territoire','buteur']],
  ['defense','Défense','shield',['encaisses','essais_enc','penalites','jaunes']],
  ['formation','Formation','school',['jeunes']]]);
 // Identités de jeu du conseil : importance (1 peu, 2 attendu, 3 prioritaire) de chaque famille.
 const PROFILS=Object.freeze({
  spectacle:Object.freeze({mot:'Spectacle',poids:Object.freeze({plan:2,conquete:1,spectacle:3,attaque:3,defense:1,formation:1})}),
  defense:Object.freeze({mot:'Défense',poids:Object.freeze({plan:2,conquete:2,spectacle:1,attaque:1,defense:3,formation:1})}),
  conquete:Object.freeze({mot:'Combat devant',poids:Object.freeze({plan:2,conquete:3,spectacle:1,attaque:1,defense:2,formation:1})}),
  formation:Object.freeze({mot:'Formation',poids:Object.freeze({plan:1,conquete:1,spectacle:2,attaque:2,defense:1,formation:3})}),
  resultats:Object.freeze({mot:'Résultats',poids:Object.freeze({plan:3,conquete:2,spectacle:1,attaque:1,defense:2,formation:1})})});
 const vm=()=>typeof S==='undefined'?null:S;
 const fini=x=>typeof x==='number'&&Number.isFinite(x);
 const borne=(x,a,b)=>Math.max(a,Math.min(b,x));
 function hache(texte){let h=0x811c9dc5;for(const c of String(texte)){h^=c.codePointAt(0);h=Math.imul(h,0x01000193)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;return h>>>0;}
 const graine=s=>Number.isInteger(s?.careerVariation?.seed)?s.careerVariation.seed:0;
 const joue=(m,id)=>Array.isArray(m?.pair)&&m.pair.some(c=>Number(c)===id);
 const ligue=m=>m&&typeof m==='object'&&m.phase==='league';

 // --- Chiffres d'un match ------------------------------------------------------------------------------------------
 // Valeurs d'un camp (i = nous, 1 − i = l'adversaire) ; un chiffre absent du match (ancien match, résultat rapide) manque.
 function echantillon(m,i){
  const j=1-i,score=Array.isArray(m.score)?m.score:[0,0],essais=Array.isArray(m.tries)?m.tries:[0,0];
  const stats=Array.isArray(m.stats)?m.stats:[],s=stats[i]&&typeof stats[i]==='object'?stats[i]:{},t=stats[j]&&typeof stats[j]==='object'?stats[j]:{};
  const a=Number(score[i])||0,b=Number(score[j])||0;
  const e={victoires:a>b?100:a===b?50:0,ecart:a-b,essais:Number(essais[i])||0,bonus:(Number(essais[i])||0)>=4?100:0,points:a,encaisses:b,essais_enc:Number(essais[j])||0};
  if(s.scrums>0&&fini(s.scrumsWon))e.melee=100*s.scrumsWon/s.scrums;
  if(s.lineouts>0&&fini(s.lineoutsWon))e.touche=100*s.lineoutsWon/s.lineouts;
  if(fini(s.possession)&&fini(t.possession)&&s.possession+t.possession>0)e.possession=100*s.possession/(s.possession+t.possession);
  if(fini(s.territory)&&fini(t.territory)&&s.territory+t.territory>0)e.territoire=100*s.territory/(s.territory+t.territory);
  const tentatives=(Number(s.goalAttempts)||0)+(Number(s.conversionAttempts)||0);
  if(tentatives>0)e.buteur=100*((Number(s.goals)||0)+(Number(s.conversions)||0))/tentatives;
  if(fini(s.penalties))e.penalites=s.penalties;
  if(fini(s.yellows))e.jaunes=s.yellows;
  if(fini(s.entries22))e.entrees22=s.entries22;
  if(fini(s.jeunes))e.jeunes=s.jeunes;
  return e;
 }
 function moyennes(liste){
  const somme={},compte={};
  for(const e of liste)for(const [k,v]of Object.entries(e)){somme[k]=(somme[k]||0)+v;compte[k]=(compte[k]||0)+1;}
  const r={};for(const k of Object.keys(somme))r[k]=somme[k]/compte[k];return r;
 }

 // --- Attentes du conseil ------------------------------------------------------------------------------------------
 function profilCalcule(s,id){
  const d=s?.clubDirections?.clubs?.[id],trait=(p,k)=>fini(p?.traits?.[k])?p.traits[k]:50;
  const style=typeof managerStyle==='function'?managerStyle(id):['conquete','large','occupation','equilibre'][((id%4)+4)%4];
  const base=fini(s?.clubs?.[id]?.base)?s.clubs[id].base:65;
  const alea=k=>hache('conseil-jeu|'+graine(s)+'|'+id+'|'+k)%26;
  const scores={
   spectacle:(style==='large'?45:0)+(100-trait(d?.president,'prudence'))*.3+alea('spectacle'),
   defense:(style==='occupation'?45:0)+trait(d?.president,'prudence')*.3+alea('defense'),
   conquete:(style==='conquete'?45:0)+(100-trait(d?.coach,'youth'))*.25+alea('conquete'),
   formation:trait(d?.director,'formation')*.35+trait(d?.coach,'youth')*.2+(/rajeun|formation|jeune/.test(String(d?.strategy||''))?25:0)+alea('formation'),
   resultats:trait(d?.president,'ambition')*.35+borne(base-60,0,30)+alea('resultats')};
  return Object.entries(scores).sort((x,y)=>y[1]-x[1]||(x[0]<y[0]?-1:1))[0][0];
 }
 function profil(s,id){const fixe=s?.conseilJeu?.attentes?.[String(id)];return Object.hasOwn(PROFILS,fixe)?fixe:profilCalcule(s,id);}

 // --- Saison ---------------------------------------------------------------------------------------------------------
 // Saison de notre championnat (la plus récente où nous avons joué en phase régulière), chiffres, rangs et notes.
 function donnees(s=vm()){
  if(!s||!Array.isArray(s.history)||!s.clubs?.[s.club])return null;
  const id=Number(s.club);let saison=-1,competition='';
  for(const m of s.history)if(ligue(m)&&joue(m,id))saison=Math.max(saison,Number(m.season)||0);
  for(const m of s.history)if(ligue(m)&&joue(m,id)&&Number(m.season)===saison)competition=String(m.competitionId??m.leagueId??'');
  if(saison<0)return null;
  const parClub=new Map(),nos=[];
  for(const m of s.history){
   if(!ligue(m)||Number(m.season)!==saison||String(m.competitionId??m.leagueId??'')!==competition||!Array.isArray(m.pair))continue;
   for(let i=0;i<2;i++){
    const e=echantillon(m,i),cle=Number(m.pair[i]);
    if(!parClub.has(cle))parClub.set(cle,[]);parClub.get(cle).push(e);
    if(cle===id)nos.push({journee:(Number(m.competitionRound??m.round)||0)+1,ordre:Number(m.round)||0,valeurs:e});
   }
  }
  nos.sort((a,b)=>a.ordre-b.ordre||a.journee-b.journee);
  const parMoy=new Map([...parClub].map(([cle,liste])=>[cle,moyennes(liste)]));
  const indicateurs={};
  for(const [cle,[nom,unite,sens,cumul]]of Object.entries(INDICATEURS)){
   const valeurs=[...parMoy.values()].filter(x=>fini(x[cle])).map(x=>x[cle]),nous=parMoy.get(id)?.[cle];
   if(!fini(nous)||!valeurs.length)continue;
   const moyenne=valeurs.reduce((n,v)=>n+v,0)/valeurs.length;
   const rang=1+valeurs.filter(v=>sens>0?v>nous:v<nous).length;
   const relatif=cle==='ecart'?(nous-moyenne)/10*PLEIN:Math.abs(moyenne)>.01?sens*(nous-moyenne)/Math.abs(moyenne):-sens*nous*.2;
   const total=nos.filter(x=>fini(x.valeurs[cle])).reduce((n,x)=>n+x.valeurs[cle],0);
   indicateurs[cle]={id:cle,nom,unite,sens,nous,moyenne,rang,clubs:valeurs.length,note:50+50*borne(relatif/PLEIN,-1,1),
    avis:relatif>=SEUIL?'up':relatif<=-SEUIL?'down':'neutre',matchs:nos.filter(x=>fini(x.valeurs[cle])).length,...(cumul?{total}:{})};
  }
  const p=profil(s,id),poids=PROFILS[p].poids,familles=[];let somme=0,masse=0;
  for(const [fid,nom,picto,liste]of FAMILLES){
   const notes=liste.filter(k=>indicateurs[k]).map(k=>indicateurs[k].note);
   if(!notes.length)continue;
   const note=notes.reduce((n,v)=>n+v,0)/notes.length;
   familles.push({id:fid,nom,picto,indicateurs:liste.filter(k=>indicateurs[k]),note,attente:poids[fid]});
   somme+=note*poids[fid];masse+=poids[fid];
  }
  return {saison,courante:saison===Number(s.season),competition,profil:p,identite:PROFILS[p].mot,
   matchs:nos.map(x=>({journee:x.journee,valeurs:x.valeurs})),indicateurs,familles,note:masse?somme/masse:null};
 }

 // Note du jeu pour le bilan du conseil (0-100) : saison en cours, au moins 3 matchs de championnat ; part de hasard ±6.
 // Fixe l'identité du club géré dans la sauvegarde (appel pendant le bilan, seul moment où le moteur écrit).
 function noteBilan(){
  const s=vm();const d=donnees(s);
  if(!d||!d.courante||d.matchs.length<MIN_MATCHS||!fini(d.note))return null;
  fixer(s,s.club,d.profil);
  const bruit=hache('conseil-jeu-bilan|'+graine(s)+'|'+s.season+'|'+s.round)%(2*BRUIT+1)-BRUIT;
  return Math.round(borne(d.note+bruit,0,100));
 }
 function fixer(s,id,p){
  if(!s||!Object.hasOwn(PROFILS,p))return;
  if(!etatValide(s.conseilJeu))s.conseilJeu={version:1,attentes:{}};
  if(!Object.hasOwn(s.conseilJeu.attentes,String(id)))s.conseilJeu.attentes[String(id)]=p;
 }
 const etatValide=e=>!!e&&typeof e==='object'&&!Array.isArray(e)&&e.version===1&&Object.keys(e).length===2
  &&!!e.attentes&&typeof e.attentes==='object'&&!Array.isArray(e.attentes)&&Object.keys(e.attentes).length<=2000;
 function validate(s){
  if(!s||s.conseilJeu===undefined)return true;
  if(!etatValide(s.conseilJeu))throw Error('Avis du conseil sur le jeu : sauvegarde invalide.');
  for(const [k,v]of Object.entries(s.conseilJeu.attentes))
   if(!/^(0|[1-9]\d{0,3})$/.test(k)||!Array.isArray(s.clubs)||Number(k)>=s.clubs.length||!Object.hasOwn(PROFILS,v))throw Error('Avis du conseil sur le jeu : attente invalide.');
  return true;
 }
 // Projection : saison lue, chiffres, familles et attentes ; le dernier avis du conseil sur le jeu (bilan, lettre).
 function project(){
  const s=vm();if(!s)return null;
  const d=donnees(s);if(!d)return {available:false};
  const bilan=(s.careerManagement?.boardHistory||[]).find(b=>fini(b?.jeu));
  return {available:true,...d,dernierBilan:bilan?{season:bilan.season,round:bilan.round,jeu:bilan.jeu}:null};
 }
 function installHooks(){return true;}
 return {project,validate,execute(){throw Error('Aucune commande pour l’avis du conseil sur le jeu.');},installHooks,donnees,noteBilan,profil:id=>profil(vm(),id),
  RULES:Object.freeze({SEUIL,PLEIN,BRUIT,MIN_MATCHS,INDICATEURS,FAMILLES,PROFILS})};
}
module.exports={files,commands,factory};
