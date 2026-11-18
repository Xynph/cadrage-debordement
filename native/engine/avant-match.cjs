'use strict';
// Écran Match avant le coup d'envoi (maquette « Retenue » validée par Léo le 17/11/2026) : les données des
// tuiles qui n'existaient pas encore, calculées à partir des vraies statistiques de la carrière, en lecture
// seule et sans tirage (même état → même projection). Servi dans `clubLife.avantMatch` ; null sans
// prochaine rencontre du club, pendant un match ou hors carrière Monde.
//
//  - forme : 5 derniers résultats de chaque club cette saison (V, N, D), du plus ancien au plus récent ;
//  - forces : par match, essais marqués et points encaissés ; touches et mêlées gagnées (en %), sur la saison
//    en cours (`S.history`, toutes compétitions), ou sur la saison passée pour les deux clubs tant que l'un
//    d'eux n'a pas encore joué ; null sans aucun match ;
//  - confrontations : bilan du club du manager face à l'adversaire et 5 dernières rencontres (toutes saisons) ;
//  - aSurveiller : 3 adversaires du XV type (club-sheet.cjs), choisis sur leurs totaux de saison
//    (`S.matchNotes`, match-notes.cjs) : réussite au but, franchissements, ballons grattés, plaquages, essais ;
//    début de saison sans statistiques : leur XV probable (source « probable »), sans chiffre inventé ;
//  - gabi : une phrase et trois clés du match, tirées de la météo annoncée, des forces et des joueurs à surveiller.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const state=()=>typeof S==='undefined'?null:S;
 const POSTES=['pilier gauche','talonneur','pilier droit','deuxième ligne','deuxième ligne','troisième ligne aile','troisième ligne aile','troisième ligne centre','demi de mêlée','ouvreur','ailier','centre','centre','ailier','arrière'];
 const MIN_MATCHS=2,MIN_TENTATIVES=6;
 const virgule=(x,d=1)=>(Math.round(x*10**d)/10**d).toFixed(d).replace('.',',');
 const issue=(r,id)=>{const i=r.pair.indexOf(id),a=r.score[i],b=r.score[1-i];return a>b?'V':a<b?'D':'N';};
 const ordre=(a,b)=>(a.season??0)-(b.season??0)||String(a.date||'').localeCompare(String(b.date||''))||String(a.fixtureId||'').localeCompare(String(b.fixtureId||''));
 const valide=r=>r&&Array.isArray(r.pair)&&r.pair.length===2&&r.pair[0]!==r.pair[1]&&Array.isArray(r.score)&&r.score.length===2;
 const matchs=(s,id,saison)=>(s.history||[]).filter(r=>valide(r)&&r.pair.includes(id)&&(saison===undefined||(r.season??s.season)===saison)).sort(ordre);
 function fixture(s){
  if(!s||!s.worldMode||s.live||s.worldMode.resultConfirmed||typeof CDWorldCareer==='undefined'||typeof CDWorldCareer.userFixture!=='function')return null;
  try{const f=CDWorldCareer.userFixture(s);return f&&f.homeId!=null&&f.awayId!=null?f:null;}catch(e){return null;}
 }
 function forme(s,id){return matchs(s,id,s.season).slice(-5).map(r=>issue(r,id));}
 function totaux(s,id,saison){
  const ms=matchs(s,id,saison);if(!ms.length)return null;
  let essais=0,contre=0,t=0,tg=0,m=0,mg=0;
  for(const r of ms){
   const i=r.pair.indexOf(id),st=Array.isArray(r.stats)?r.stats[i]||{}:{};
   essais+=Array.isArray(r.tries)?Number(r.tries[i])||0:0;contre+=Number(r.score[1-i])||0;
   t+=Number(st.lineouts)||0;tg+=Number(st.lineoutsWon)||0;m+=Number(st.scrums)||0;mg+=Number(st.scrumsWon)||0;
  }
  const n=ms.length;
  return {matchs:n,essais:Math.round(essais/n*10)/10,encaisses:Math.round(contre/n*10)/10,touches:t>0?Math.round(tg/t*100):null,melees:m>0?Math.round(mg/m*100):null};
 }
 function forces(s,pair){
  for(const saison of [s.season,s.season-1]){
   if(saison<1)break;
   const rows=pair.map(id=>totaux(s,id,saison));
   if(rows.every(Boolean))return {saison:saison===s.season?'en cours':'passée',equipes:rows};
  }
  return null;
 }
 function confrontations(s,own,adv){
  const face=(s.history||[]).filter(r=>valide(r)&&r.pair.includes(own)&&r.pair.includes(adv)).sort(ordre);
  const lignes=face.slice(-5).reverse().map(r=>{
   const domicile=r.pair[0]===own&&!r.neutral;
   return {date:r.date??null,saison:r.season??s.season,domicile,neutre:!!r.neutral,stade:r.neutral?null:s.clubs[r.pair[0]]?.stadium||null,score:r.score.slice(),issue:issue(r,own)};
  });
  return {joues:face.length,victoires:face.filter(r=>issue(r,own)==='V').length,nuls:face.filter(r=>issue(r,own)==='N').length,defaites:face.filter(r=>issue(r,own)==='D').length,derniers:lignes};
 }
 function xv(s,club){
  try{const d=typeof nativeSystems!=='undefined'?nativeSystems.domain('clubSheet'):null;if(d&&typeof d.xvType==='function')return d.xvType(s,club);}catch(e){}
  return null;
 }
 // Catégories dans l'ordre de choix ; chaque joueur n'apparaît qu'une fois.
 const CATEGORIES=[
  {id:'buteur',role:'buteur',valeur:j=>j.length>13&&j[13]>=MIN_TENTATIVES?j[12]/j[13]+j[13]/1000:null,chiffre:j=>Math.round(j[12]/j[13]*100)+' %',detail:'réussite au but'},
  {id:'franchissements',role:'franchissements',valeur:j=>j.length>8&&j[8]/j[0]>=.5?j[8]/j[0]:null,chiffre:j=>virgule(j[8]/j[0])+' / m',detail:'franchissements par match'},
  {id:'grattages',role:'grattages',valeur:j=>j.length>11&&j[11]/j[0]>=.5?j[11]/j[0]:null,chiffre:j=>virgule(j[11]/j[0])+' / m',detail:'ballons grattés par match'},
  {id:'plaquages',role:'plaquages',valeur:j=>j[4]/j[0]>=8?j[4]/j[0]:null,chiffre:j=>virgule(j[4]/j[0])+' / m',detail:'plaquages par match'},
  {id:'essais',role:'finisseur',valeur:j=>j[3]>=2?j[3]+j[0]/1000:null,chiffre:j=>j[3]+' essais',detail:'essais cette saison'},
 ];
 function aSurveiller(s,adv){
  const club=s.clubs[adv];if(!club)return {source:'aucune',joueurs:[]};
  const type=xv(s,club),numero=new Map();
  for(const slot of type?.slots||[])if(slot.id!=null)numero.set(String(slot.id),slot.jersey);
  const dispo=club.players.filter(p=>numero.has(String(p.id))&&!(Number(p.injury)>0)&&!(Number(p.suspension)>0));
  const totaux=s.matchNotes?.saison===s.season?s.matchNotes.joueurs||{}:{};
  const pris=new Set(),choix=[];
  for(const c of CATEGORIES){
   if(choix.length>=3)break;
   let meilleur=null;
   for(const p of dispo){
    const id=String(p.id);if(pris.has(id))continue;
    const j=totaux[id]?.s;if(!Array.isArray(j)||j[0]<MIN_MATCHS)continue;
    const v=c.valeur(j);if(v===null||!Number.isFinite(v))continue;
    if(!meilleur||v>meilleur[1]||v===meilleur[1]&&id<meilleur[0].id)meilleur=[{id,p,j},v];
   }
   if(!meilleur)continue;
   const {id,p,j}=meilleur[0],n=numero.get(id);pris.add(id);
   choix.push({id,name:p.name,numero:n,poste:POSTES[n-1]||String(p.pos||''),categorie:c.id,role:c.role,chiffre:c.chiffre(j),detail:c.detail,matchs:j[0]});
  }
  if(choix.length)return {source:'statistiques',joueurs:choix};
  // Pas encore de statistiques : leur XV probable (ouvreur, demi de mêlée, numéro 8), sans chiffre.
  const probables=[10,9,8].map(n=>[...numero.entries()].find(([,x])=>x===n)).filter(Boolean).map(([id,n])=>{const p=club.players.find(x=>String(x.id)===id);return p?{id,name:p.name,numero:n,poste:POSTES[n-1],categorie:'probable',role:'titulaire probable',chiffre:null,detail:null,matchs:0}:null;}).filter(Boolean);
  return {source:probables.length?'probable':'aucune',joueurs:probables};
 }
 function meteo(s,f){
  try{const m=CDWorldCareer.meteoAnnoncee(s);return m&&m.fixtureId===f.id?m:null;}catch(e){return null;}
 }
 const ventOriente=m=>!!m&&m.vent>0&&[0,1].includes(m.sens)&&(typeof WIND_DIRECTION_RULES==='undefined'||!!WIND_DIRECTION_RULES);
 // Écart de niveau des XV probables (même mesure que la complaisance du moteur), null hors du moteur.
 function ecartNiveau(s,own,adv){
  if(typeof buildSheet!=='function'||typeof teamLevel!=='function')return null;
  try{const niveau=id=>{const c=s.clubs[id];if(!c)return null;const by=new Map(c.players.map(p=>[p.id,p]));const xv=buildSheet(c).lineup.map(x=>by.get(x)).filter(Boolean);return xv.length?teamLevel(xv):null;};
   const a=niveau(own),b=niveau(adv);return a===null||b===null?null:a-b;}catch(e){return null;}
 }
 function gabi(s,f,own,adv,data){
  const nous=[f.homeId,f.awayId].indexOf(own),eux=1-nous,cles=[];
  const ajoute=(id,priorite,titre,detail)=>cles.push({id,priorite,titre,detail});
  const m=meteo(s,f);
  if(ventOriente(m)){
   const fort=m.vent===2?10:0;
   if(m.sens===nous){ajoute('vent-dos',88+fort,'Marquer tôt avec le vent','il est dans notre dos en 1re période');ajoute('vent-face-2',62+fort,'Tenir après la pause','le vent nous fera face en 2e période');}
   else{ajoute('vent-face',88+fort,'Tenir le score face au vent','prends les points faciles, joue la touche');ajoute('vent-dos-2',62+fort,'Accélérer après la pause','le vent passe dans notre dos');}
  }
  if(m&&m.pluie>0)ajoute('pluie',80+(m.pluie===2?8:0),m.pluie===2?'Avancer devant sur une pelouse lourde':'Jouer simple sous la pluie',m.pluie===2?'ballon porté, jeu au pied, peu de passes':'peu de passes, conquête et jeu au pied');
  if(m&&m.chaleur>0)ajoute('chaleur',72,'Gérer l’effort dans la chaleur','fais entrer ton banc plus tôt');
  const buteur=data.aSurveiller.joueurs.find(x=>x.categorie==='buteur');
  if(buteur&&parseInt(buteur.chiffre,10)>=75)ajoute('discipline',76,'Zéro pénalité dans nos 40',buteur.name+' réussit '+buteur.chiffre+' au but');
  const franchisseur=data.aSurveiller.joueurs.find(x=>x.categorie==='franchissements');
  if(franchisseur)ajoute('franchisseur',58,'Couper '+franchisseur.name,franchisseur.chiffre.replace(' / m','')+' franchissements par match');
  const fo=data.forces;
  if(fo){
   const a=fo.equipes[nous],b=fo.equipes[eux];
   if(b.essais>=3)ajoute('essais',64,'Fermer les extérieurs','ils marquent '+virgule(b.essais)+' essais par match');
   if(b.encaisses>=25)ajoute('rythme',56,'Mettre du rythme','ils encaissent '+virgule(b.encaisses,0)+' points par match');
   if(a.touches!==null&&b.touches!==null&&a.touches-b.touches>=5)ajoute('touche',52,'Jouer sur notre touche',a.touches+' % de touches gagnées contre '+b.touches+' %');
   if(a.touches!==null&&b.touches!==null&&b.touches-a.touches>=5)ajoute('touche-secu',54,'Sécuriser nos lancers','leur touche gagne '+b.touches+' %, la nôtre '+a.touches+' %');
   if(a.melees!==null&&b.melees!==null&&a.melees-b.melees>=5)ajoute('melee',50,'Pousser en mêlée',a.melees+' % de mêlées gagnées contre '+b.melees+' %');
   if(a.melees!==null&&b.melees!==null&&b.melees-a.melees>=5)ajoute('melee-tenir',53,'Tenir en mêlée','leur mêlée gagne '+b.melees+' % de ses introductions');
  }
  // Complaisance (tactical-plans.js, RELACHEMENT) : gros favori → risque de jour sans, qu'une causerie exigeante annule.
  const ecart=ecartNiveau(s,own,adv);
  if(ecart!==null&&typeof RELACHEMENT!=='undefined'&&ecart>=RELACHEMENT.seuil)ajoute('relachement',84,'Pas de relâchement','on est favoris : choisis une causerie exigeante avant le coup d’envoi');
  const leur=data.forme[eux]||[],victoires=leur.filter(x=>x==='V').length;
  if(leur.length>=4&&victoires>=4)ajoute('dynamique',48,'Casser leur dynamique',victoires+' victoires sur leurs '+leur.length+' derniers matchs');
  ajoute('collisions',20,'Gagner les collisions','avancer sur chaque impact');
  ajoute('plan',10,'Respecter le plan de jeu','patience et discipline');
  ajoute('depart',15,'Réussir les 20 premières minutes','le premier temps fort donne le ton');
  cles.sort((x,y)=>y.priorite-x.priorite||(x.id<y.id?-1:1));
  // Deux clés « 1re/2e période » du même vent : la seconde n'a de sens qu'avec la première.
  const retenues=[];for(const c of cles){if(retenues.length>=3)break;if(c.id.endsWith('-2')&&!retenues.some(x=>x.id.startsWith('vent-')))continue;retenues.push(c);}
  let phrase='';
  const rang=data.rangs[eux];
  if(fo&&rang)phrase='Ils sont '+(rang===1?'1ers':rang+'es')+' et prennent '+virgule(fo.equipes[eux].encaisses,0)+' points par match.';
  else if(fo)phrase='Ils marquent '+virgule(fo.equipes[eux].essais)+' essais et prennent '+virgule(fo.equipes[eux].encaisses,0)+' points par match.';
  else if(leur.length)phrase='Ils restent sur '+victoires+' victoire'+(victoires>1?'s':'')+' en '+leur.length+' match'+(leur.length>1?'s':'')+'.';
  else phrase='Premier match de la saison pour eux comme pour nous.';
  return {phrase:phrase+' Trois clés pour moi :',cles:retenues.map(({titre,detail})=>({titre,detail}))};
 }
 function rangs(s,pair){
  return pair.map(id=>{
   try{
    const W=CDWorldCareer,lg=W.leagueId(s,id),table=W.ranked(s,lg);
    if(!Array.isArray(table)||!table.some(x=>x.played>0))return null;
    const i=table.findIndex(x=>x.id===id);return i>=0?i+1:null;
   }catch(e){return null;}
  });
 }
 function project(){
  const s=state(),f=fixture(s);if(!f)return null;
  const own=s.club,pair=[f.homeId,f.awayId];if(!pair.includes(own))return null;
  const adv=pair.find(id=>id!==own);
  const data={fixtureId:f.id,forme:pair.map(id=>forme(s,id)),forces:forces(s,pair),confrontations:confrontations(s,own,adv),aSurveiller:aSurveiller(s,adv),rangs:rangs(s,pair)};
  data.gabi=gabi(s,f,own,adv,data);
  delete data.rangs;
  return data;
 }
 function validate(){return true;}
 function execute(){throw Error('Avant-match : aucune commande.');}
 function installHooks(){return true;}
 return {project,validate,execute,installHooks,forme,forces,confrontations,aSurveiller,gabi};
}
module.exports={files,commands,factory};
