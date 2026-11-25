'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Doublons (clubs privés de leurs internationaux) et temps de jeu des internationaux français.
// Carrière Monde uniquement. Décision de Léo du 18/11/2026.
//
// 1. Doublon : une journée de championnat jouée pendant une fenêtre internationale (Top 14 2026-27 : 3 doublons, J9
//    du 7-9 nov., J10 du 28 nov. si la France joue la finale du Nations Championship, J17 à partir du 20 fév. ;
//    URC pendant le Tournoi). `impact()` chiffre ce que le club perd ; les trois réponses du courrier « doublon »
//    (club-mail.json) sont appliquées par `agir()` : faire tourner l'effectif (charge de repos pour les cadres
//    fatigués, rendue après le match), aligner la meilleure feuille possible, lancer des jeunes du centre.
//    Source du calendrier : https://www.rugbypass.com/news/le-calendrier-de-la-saison-2026-2027-est-connu-voici-les-trois-doublons-qui-concernent-le-top-14/
// 2. Liste élite des Bleus : protocole expérimental FFR-LNR 2026-27 (convention 2026-2031 : groupes de 42, 14 relâchés
//    avant chaque test). Liste NON publique de 33 joueurs fixée par le sélectionneur ; les clubs doivent les laisser
//    au repos au moins 2 fois sur une période de 8 rencontres ; le XV de France les fait jouer au maximum 9 fois sur
//    les 12 tests de la saison (appliqué dans international-career.cjs). Ce sont des « lignes directrices »
//    ajustables par accord entre staffs, suivies par une cellule FFR-LNR, sans sanction publiée.
//    Source : https://www.rugbypass.com/fr/news/liste-33-joueurs-xv-de-france-2027/
//    Ce qui compte comme repos n'est pas public : on retient l'option la plus prudente, « absent de la feuille de
//    match » alors que le joueur est apte et disponible (une absence pour blessure ou pour la sélection n'est pas un
//    repos). Seule la saison 2026-27 est publique : la règle est reconduite chaque saison, faute d'autre information.
//    Les clubs de l'ordinateur et la sélection du staff appliquent la même règle (feuille de match, comme comply() du
//    JIFF), en étalant les repos (rotation du staff, 19/11/2026).
function factory(){
 const POLICY='bleus-33-2026-27-v1',NATION='FRA',LIST_SIZE=33,WINDOW=8,MIN_RESTS=2,KEEP=12,RELATION_START=60;
 // Répartition par famille de poste (international-callups.cjs : familles 0 à 8) : 33 joueurs, tous les postes couverts.
 const QUOTAS=[4,3,4,6,3,3,4,4,2];
 const FAMILY_LABELS=['première ligne','première ligne','deuxième ligne','troisième ligne','charnière','charnière','ailes','centres','arrière'];
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('Doublons : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const hash=x=>{let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);h^=h>>>16;h=Math.imul(h,2246822507);h^=h>>>13;return h>>>0;};
 const worldOn=s=>!!s&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const active=s=>worldOn(s)&&s.doublons?.version===1&&s.doublons.season===s.season;
 const ids=s=>active(s)?new Set(s.doublons.ids):new Set();
 const listed=(s,pid)=>active(s)&&s.doublons.ids.includes(pid);
 const released=(s,p,date)=>!!date&&typeof CDWorldCareer.clubReleaseOn==='function'&&!!CDWorldCareer.clubReleaseOn(s,p.id,date);
 const fixtureOf=(s,clubId)=>CDWorldCareer.fixtures(s).find(f=>f.homeId===clubId||f.awayId===clubId)||null;
 const nextFixture=s=>{try{return CDWorldCareer.userFixture(s);}catch(e){return null;}};
 const playedFixture=(s,fid)=>(s.history||[]).some(r=>r.fixtureId===fid);
 const nationName=code=>typeof nativeFacts!=='undefined'&&nativeFacts.nations?.[code]?nativeFacts.nations[code][0]:code;
 const fatigueOf=p=>Number(p.physicalLoad?.fatigue)||0;
 const conditionOf=p=>Number.isFinite(p.condition)?p.condition:100;

 // ------------------------------------------------------------------ liste des 33
 // Les mieux notés des internationaux documentés (nation sénior France), puis des joueurs éligibles à la France, par
 // famille de poste. Choisie à l'ouverture de la saison et gardée jusqu'à la suivante.
 function buildList(s){
  const pool=[];
  for(const c of s.clubs)for(const p of c.players){
   if((p.age||0)<18||typeof nativeFacts==='undefined'||!nativeFacts.eligible(p.id,NATION))continue;
   const f=nativeFacts.source(p.id)||{},caps=Number.isInteger(f.seniorCaps)?f.seniorCaps:0;
   pool.push({id:p.id,fam:p.fam,documented:f.seniorNation===NATION?1:0,score:(typeof niveauMatch==='function'?niveauMatch(p):p.rating||0)+0.1*Math.min(caps,80)});
  }
  const order=(a,b)=>b.documented-a.documented||b.score-a.score||(a.id<b.id?-1:a.id>b.id?1:0);
  pool.sort(order);
  const picked=[],taken=new Set();
  for(let fam=0;fam<QUOTAS.length;fam++)for(const x of pool.filter(y=>y.fam===fam).slice(0,QUOTAS[fam])){picked.push(x.id);taken.add(x.id);}
  for(const x of pool){if(picked.length>=LIST_SIZE)break;if(!taken.has(x.id)){picked.push(x.id);taken.add(x.id);}}
  return picked.slice(0,LIST_SIZE);
 }
 function open(s){
  const prev=s.doublons,relation=prev?.relation??RELATION_START;
  const bilans=(prev?.bilans||[]).slice(-4);
  if(prev&&prev.version===1&&prev.season<s.season){
   bilans.push({season:prev.season,violations:prev.violations,relation});
   if(prev.violations>0&&typeof news==='function')news('Protocole des Bleus : '+prev.violations+' fois, un joueur de la liste a été aligné alors qu’il devait souffler. La cellule FFR-LNR en a pris note, notre relation avec la fédération est à '+relation+'/100.');
  }
  s.doublons={version:1,policy:POLICY,season:s.season,ids:buildList(s),rests:{},relation,waivers:{},violations:0,pending:[],rotation:null,bilans};
 }
 // Appelée après chaque commande (worker.cjs) : liste de la saison, plans en attente.
 function observe(){
  const s=state();
  if(!worldOn(s))return false;
  let changed=false;
  if(!(s.doublons?.version===1&&s.doublons.season===s.season)){open(s);changed=true;}
  if(s.phase==='ended')return changed;
  return restoreRotation(s)||applyPending(s)||changed;
 }

 // ------------------------------------------------------------------ suivi des repos
 // Historique d'un joueur : un caractère par match de son club cette saison : j = sur la feuille, r = repos (absent
 // alors qu'il est apte et disponible), n = à la disposition de sa sélection, x = indisponible (blessure).
 const history=(s,pid)=>s.doublons.rests[pid]||'';
 const restCount=text=>[...text].filter(c=>c==='r').length;
 // Fenêtre glissante de 8 rencontres, au moins 2 repos : le joueur DOIT souffler au prochain match si, parmi les
 // rencontres déjà jouées de la fenêtre (sept au plus), il en manque assez pour que le seul repos possible soit celui-ci.
 function mustRest(s,pid,fixture){
  if(!listed(s,pid))return false;
  const w=s.doublons.waivers[pid];
  if(w&&fixture&&w===fixture.id)return false;
  const last=history(s,pid).slice(-(WINDOW-1));
  return MIN_RESTS-restCount(last)>=WINDOW-last.length;
 }
 const clubOfPlayer=(s,pid)=>s.clubs.find(c=>c.players.some(p=>p.id===pid));

 // Enregistre la feuille de chaque club ayant des joueurs de la liste, avant les blessures du match (une fois par match).
 function record(l){
  const s=state();
  if(!active(s)||!l||l.injuriesApplied||!l.worldContext||!Array.isArray(l.sheets)||!Array.isArray(l.pair))return;
  const list=ids(s),date=l.worldContext.date;
  for(let side=0;side<2;side++){
   const club=s.clubs[l.pair[side]],sheet=l.sheets[side];
   if(!club||!sheet||!Array.isArray(sheet.nominated))continue;
   const on=new Set(sheet.nominated);
   for(const p of club.players){
    if(!list.has(p.id))continue;
    const fixture=l.worldContext;
    const must=club.id===s.club&&mustRest(s,p.id,fixture);
    let code='j';
    if(!on.has(p.id))code=released(s,p,date)?'n':(p.injury>0||p.suspension>0?'x':'r');
    else if(must){
     s.doublons.violations++;
     s.doublons.relation=Math.max(0,s.doublons.relation-4);
    }
    s.doublons.rests[p.id]=(history(s,p.id)+code).slice(-KEEP);
   }
  }
 }

 // ------------------------------------------------------------------ clubs de l'ordinateur
 function eligibleAt(p,slot){
  return slot<15?(typeof slotEligible==='function'?slotEligible(p,slot):true):(typeof benchEligible==='function'?benchEligible(p,slot-15):true);
 }
 // Remplace sur la feuille les joueurs de la liste qui doivent souffler. Meilleur joueur disponible du poste (le statut
 // JIFF est conservé quand c'est possible) ; si personne ne convient, le joueur reste sur la feuille.
 // Rotation du staff (décision de Léo du 19/11/2026) : un vrai staff étale les repos au lieu d'attendre que tous ses
 // internationaux arrivent ensemble au bout de la fenêtre (capture du 19/11 : 9 Toulousains à faire souffler le même
 // jour après 6 matchs pleins). Repos anticipé dès qu'il reste moins de ROTATION_AVANCE matchs de marge dans la
 // fenêtre, au plus ROTATION_MAX par match (les plus pressés, puis les moins frais) ; les repos obligatoires passent
 // toujours. 9 internationaux × 2 repos sur 8 matchs ≈ 2,25 repos par match : 3 suffisent à lisser.
 const ROTATION_AVANCE=4,ROTATION_MAX=3;
 function marge(s,pid){
  const last=history(s,pid).slice(-(WINDOW-1));
  return (WINDOW-last.length)-(MIN_RESTS-restCount(last));
 }
 function staffRest(s,c,fixture){
  const list=ids(s),avail=c.players.filter(p=>list.has(p.id)&&!p.injury&&!released(s,p,fixture.date));
  const must=avail.filter(p=>mustRest(s,p.id,fixture)).map(p=>p.id);
  const anticipe=avail.filter(p=>!must.includes(p.id)&&!(s.doublons.waivers[p.id]===fixture.id)&&MIN_RESTS-restCount(history(s,p.id).slice(-(WINDOW-1)))>0&&marge(s,p.id)<ROTATION_AVANCE)
   .sort((a,b)=>marge(s,a.id)-marge(s,b.id)||(conditionOf(a)-conditionOf(b))||(a.id<b.id?-1:1))
   .slice(0,Math.max(0,ROTATION_MAX-must.length)).map(p=>p.id);
  return new Set([...must,...anticipe]);
 }
 // Feuille du staff : clubs de l'ordinateur et, pour le club du joueur, « Sélection du staff » / composition confiée au
 // staff (autoLineup → buildSheet). Une feuille choisie à la main n'est jamais modifiée (crochet ci-dessous).
 function comply(s,c,sheet){
  if(!active(s)||!c||!Array.isArray(c.players)||!sheet)return sheet;
  const list=ids(s);
  if(!c.players.some(p=>list.has(p.id)))return sheet;
  const fixture=fixtureOf(s,c.id);
  if(!fixture)return sheet;
  const rest=staffRest(s,c,fixture);
  const lineup=sheet.lineup.slice(),bench=sheet.bench.slice(),used=new Set([...lineup,...bench].filter(Boolean));
  if(![...rest].some(x=>used.has(x)))return sheet;
  const byId=new Map(c.players.map(p=>[p.id,p]));
  const jiff=p=>typeof CDJiff!=='undefined'&&CDJiff&&typeof CDJiff.isJiff==='function'&&s.jiff?.version===1&&CDJiff.isJiff(s,p);
  const value=p=>(typeof fitScore==='function'?fitScore(p):p.rating||0);
  const swap=(slots,offset)=>{
   for(let i=0;i<slots.length;i++){
    if(!rest.has(slots[i]))continue;
    const out=byId.get(slots[i]);
    const options=c.players.filter(q=>!q.injury&&!used.has(q.id)&&!rest.has(q.id)&&!released(s,q,fixture.date)&&eligibleAt(q,i+offset));
    if(!options.length)continue;
    options.sort((a,b)=>(Number(jiff(b)===jiff(out))-Number(jiff(a)===jiff(out)))||value(b)-value(a)||(a.id<b.id?-1:1));
    used.delete(slots[i]);used.add(options[0].id);slots[i]=options[0].id;
   }
  };
  swap(lineup,0);swap(bench,15);
  return {...sheet,lineup,bench};
 }

 // ------------------------------------------------------------------ club du joueur : alerte de feuille
 // Meilleur remplaçant (hors feuille, apte, disponible) à la place d'un joueur qui doit souffler.
 function advice(s,club,fixture){
  const list=ids(s),byId=new Map(club.players.map(p=>[p.id,p]));
  const rest=new Set(club.players.filter(p=>list.has(p.id)&&!p.injury&&!released(s,p,fixture.date)&&mustRest(s,p.id,fixture)).map(p=>p.id));
  const slots=(s.lineup||[]).concat(s.reserves||[]);
  const on=new Set(slots.filter(Boolean)),starters=[],changes=[],used=new Set();
  const value=p=>(typeof fitScore==='function'?fitScore(p):p.rating||0);
  slots.forEach((pid,slot)=>{
   if(!pid||!rest.has(pid))return;
   starters.push({slot,playerId:pid});
   const options=club.players.filter(q=>!q.injury&&!on.has(q.id)&&!used.has(q.id)&&!rest.has(q.id)&&!released(s,q,fixture.date)&&eligibleAt(q,slot)&&q.age>=18);
   options.sort((a,b)=>value(b)-value(a)||(a.id<b.id?-1:1));
   if(options.length){used.add(options[0].id);changes.push({slot,playerId:options[0].id,sortant:pid,condition:Math.round(conditionOf(byId.get(pid))),entrantCondition:Math.round(conditionOf(options[0]))});}
  });
  return {starters,changes};
 }
 function project(){
  const s=state();
  if(!active(s))return {available:false,applies:false};
  const club=s.clubs[s.club],list=ids(s),own=club?club.players.filter(p=>list.has(p.id)):[];
  const base={available:true,applies:own.length>0,window:WINDOW,minRests:MIN_RESTS,relation:s.doublons.relation,violations:s.doublons.violations,listSize:s.doublons.ids.length,maxTests:9,ofTests:12};
  if(!own.length)return base;
  const fixture=s.live&&!s.live.finished?null:nextFixture(s);
  const players=own.map(p=>{
   const last=history(s,p.id).slice(-WINDOW);
   return {id:p.id,matches:last.length,rests:restCount(last),mustRest:!!fixture&&!p.injury&&!released(s,p,fixture.date)&&mustRest(s,p.id,fixture),waived:!!fixture&&s.doublons.waivers[p.id]===fixture.id};
  });
  const out={...base,players,fixtureId:fixture?fixture.id:null,reposer:[],changes:[]};
  if(fixture&&!(s.live&&!s.live.finished)){
   const a=advice(s,club,fixture);
   out.reposer=a.starters;out.changes=a.changes;
  }
  return out;
 }

 // ------------------------------------------------------------------ doublon : ce que le club perd
 const dayFormat=new Intl.DateTimeFormat('fr-FR',{weekday:'long',day:'numeric',month:'long',timeZone:'UTC'});
 const dayText=date=>dayFormat.format(new Date(date+'T00:00:00Z'));
 function xvType(club){
  const taken=new Set(),xv=[];
  for(let slot=0;slot<15;slot++){
   const best=club.players.filter(p=>!p.injury&&!taken.has(p.id)&&eligibleAt(p,slot)).sort((a,b)=>(typeof niveauMatch==='function'?niveauMatch(b):b.rating||0)-(typeof niveauMatch==='function'?niveauMatch(a):a.rating||0)||(a.id<b.id?-1:1))[0];
   if(best){taken.add(best.id);xv.push(best);}
  }
  return xv;
 }
 // null : pas de doublon sensible pour ce match ; sinon les chiffres du courrier.
 function impact(s,fixture,seuils={}){
  if(!worldOn(s)||!fixture||fixture.phase!=='league')return null;
  const club=s.clubs[s.club],date=fixture.date;
  const camps=(s.national?.career?.callups||[]).filter(c=>c.playerIds.some(pid=>club.players.some(p=>p.id===pid)));
  const absent=club.players.filter(p=>!p.injury&&released(s,p,date));
  if(!absent.length)return null;
  const gone=new Set(absent.map(p=>p.id)),xv=xvType(club),titulaires=xv.filter(p=>gone.has(p.id));
  if(absent.length<(seuils.absents??3)&&titulaires.length<(seuils.titulaires??1))return null;
  const families=[...new Set(absent.map(p=>FAMILY_LABELS[p.fam]).filter(Boolean))];
  const nations=[...new Set(camps.filter(c=>c.from<=date&&date<=c.through&&c.playerIds.some(pid=>gone.has(pid))).map(c=>nationName(c.nation)))];
  const noms=absent.slice().sort((a,b)=>(typeof niveauMatch==='function'?niveauMatch(b):b.rating||0)-(typeof niveauMatch==='function'?niveauMatch(a):a.rating||0)||(a.id<b.id?-1:1)).slice(0,3).map(p=>p.name);
  const opponent=fixture.homeId===s.club?fixture.awayId:fixture.homeId;
  return {n:absent.length,titulaires:titulaires.length,postes:families.join(', ')||'tout le groupe',nations:nations.join(', ')||'leur sélection',
   joueurs:noms.join(', ')+(absent.length>3?' et '+(absent.length-3)+' autre'+(absent.length>4?'s':''):''),adversaire:s.clubs[opponent]?.name||'l’adversaire',
   jour:dayText(date),rencontre:fixture.id};
 }

 // Joueur de la liste à ménager au prochain match du club du manager (courrier de la cellule FFR-LNR) : le mieux noté.
 function aMenager(s,fixture){
  if(!active(s)||!fixture)return null;
  const club=s.clubs[s.club];
  const rest=club.players.filter(p=>ids(s).has(p.id)&&!p.injury&&!released(s,p,fixture.date)&&mustRest(s,p.id,fixture))
   .sort((a,b)=>(typeof niveauMatch==='function'?niveauMatch(b):b.rating||0)-(typeof niveauMatch==='function'?niveauMatch(a):a.rating||0)||(a.id<b.id?-1:1));
  if(!rest.length)return null;
  const p=rest[0],last=history(s,p.id).slice(-(WINDOW-1));
  return {player:p,matchs:last.length,repos:restCount(last),opponent:s.clubs[fixture.homeId===s.club?fixture.awayId:fixture.homeId]?.name||'l’adversaire',jour:dayText(fixture.date)};
 }

 // ------------------------------------------------------------------ réponses des courriers
 function fixtureById(s,fid){return (s.worldMode.fixtures||[]).find(f=>f.id===fid)||null;}
 // Raison pour laquelle une réponse est impossible ('' : possible).
 function refus(s,mail,kind){
  if(!active(s))return 'Le protocole n’est pas en vigueur cette saison.';
  const f=fixtureById(s,mail.vars?.rencontre);
  if(!f||playedFixture(s,f.id))return 'Ce match est déjà joué.';
  const club=s.clubs[s.club];
  if(kind==='rotation'){
   if(!cadresFatigues(s,club,f).length)return 'Aucun cadre fatigué à ménager.';
  }else if(kind==='jeunes'){
   if(!candidatsJeunes(s,club,f).length)return 'Aucun jeune du centre n’a le profil pour les postes touchés.';
  }else if(kind==='forte'){
   // Toujours possible : la meilleure feuille disponible.
  }else if(['reposer','amenagement','ignorer'].includes(kind)){
   const p=club.players.find(x=>x.id===mail.player);
   if(!p)return 'Ce joueur ne fait plus partie de l’effectif.';
   if(kind==='reposer'&&f.id===nextFixture(s)?.id&&!advice(s,club,f).changes.some(c=>c.sortant===p.id)&&[...(s.lineup||[]),...(s.reserves||[])].includes(p.id))return 'Personne de disponible pour le remplacer.';
   if(s.doublons.waivers[p.id]===f.id)return 'L’aménagement est déjà accordé.';
  }else return 'Réponse inconnue.';
  return '';
 }
 function cadresFatigues(s,club,f){
  return club.players.filter(p=>!p.injury&&!released(s,p,f.date)).sort((a,b)=>(typeof niveauMatch==='function'?niveauMatch(b):b.rating||0)-(typeof niveauMatch==='function'?niveauMatch(a):a.rating||0)||(a.id<b.id?-1:1)).slice(0,20)
   .filter(p=>fatigueOf(p)>=20||conditionOf(p)<80).sort((a,b)=>fatigueOf(b)-fatigueOf(a)||conditionOf(a)-conditionOf(b)||(a.id<b.id?-1:1)).slice(0,6);
 }
 // Jeunes du centre (18 ans et plus, aptes) qui occupent un poste d'un titulaire absent, un par poste, deux au plus.
 function candidatsJeunes(s,club,f){
  const gone=new Set(club.players.filter(p=>!p.injury&&released(s,p,f.date)).map(p=>p.id)),xv=xvType(club);
  const academy=(s.development?.academy||[]).filter(y=>(y.age||0)>=18&&!y.injury&&!y.espoirLoan);
  const out=[],used=new Set();
  xv.forEach((p,slot)=>{
   if(out.length>=2||!gone.has(p.id))return;
   const y=academy.filter(z=>!used.has(z.id)&&eligibleAt(z,slot)).sort((a,b)=>(b.rating||0)-(a.rating||0)||(a.id<b.id?-1:1))[0];
   if(y){used.add(y.id);out.push(y.id);}
  });
  return out;
 }
 // Feuille de la rencontre sans les joueurs retenus en sélection à cette date.
 function bestSheet(s,f){
  const club=s.clubs[s.club];
  return buildSheet({...club,players:club.players.filter(p=>!released(s,p,f.date))});
 }
 function placeYouth(s,f,youthIds){
  const club=s.clubs[s.club];
  for(const yid of youthIds){
   const y=club.players.find(p=>p.id===yid);if(!y)continue;
   const slots=s.lineup.concat(s.reserves),byId=new Map(club.players.map(p=>[p.id,p]));
   if(slots.includes(yid))continue;
   let best=null;
   slots.forEach((pid,slot)=>{
    if(!eligibleAt(y,slot))return;
    const q=pid?byId.get(pid):null,rank=q?(typeof niveauMatch==='function'?niveauMatch(q):q.rating||0):-1;
    if(!best||rank<best.rank||(rank===best.rank&&slot>best.slot))best={slot,rank};
   });
   if(best){if(best.slot<15)s.lineup[best.slot]=yid;else s.reserves[best.slot-15]=yid;}
  }
 }
 // Plans qui attendent la semaine de leur match (la feuille du manager sert aussi aux matchs d'ici là).
 function applyPending(s){
  const list=s.doublons.pending||[];
  if(!list.length)return false;
  const f=nextFixture(s),keep=[];
  let changed=false;
  for(const item of list){
   if(playedFixture(s,item.fixtureId))continue;
   if(!f||f.id!==item.fixtureId||s.live){keep.push(item);continue;}
   if(item.kind==='forte'||item.kind==='jeunes'){
    const sheet=bestSheet(s,f);
    s.lineup=sheet.lineup;s.reserves=sheet.bench;
    if(item.kind==='jeunes')placeYouth(s,f,item.ids||[]);
   }else if(item.kind==='reposer'){
    const club=s.clubs[s.club],a=advice(s,club,f),c=a.changes.find(x=>x.sortant===item.player);
    if(c){if(c.slot<15)s.lineup[c.slot]=c.playerId;else s.reserves[c.slot-15]=c.playerId;}
   }
   changed=true;
  }
  s.doublons.pending=keep;
  return changed;
 }
 function restoreRotation(s){
  const r=s.doublons.rotation;
  if(!r||!playedFixture(s,r.fixtureId))return false;
  const club=s.clubs[s.club];
  for(const [pid,plan] of Object.entries(r.prior)){
   const p=club.players.find(x=>x.id===pid);
   if(p&&p.physicalLoad&&p.physicalLoad.plan==='repos')p.physicalLoad.plan=plan;
  }
  s.doublons.rotation=null;
  return true;
 }
 // Réponse du manager : retourne le texte de résultat (verdict) ; lève une erreur si impossible.
 function agir(s,mail,kind){
  const reason=refus(s,mail,kind);
  check(!reason,reason.replace(/\.$/,''));
  const club=s.clubs[s.club],f=fixtureById(s,mail.vars.rencontre),st=s.doublons;
  const now=nextFixture(s);
  if(kind==='rotation'){
   const who=cadresFatigues(s,club,f),prior={};
   for(const p of who){
    const load=typeof ensurePhysicalLoad==='function'?ensurePhysicalLoad(p):(p.physicalLoad||(p.physicalLoad={version:1,fatigue:0,plan:'collective'}));
    if(load.plan!=='repos')prior[p.id]=load.plan;
    load.plan='repos';
   }
   st.rotation={fixtureId:f.id,prior:{...(st.rotation?.fixtureId===f.id?st.rotation.prior:{}),...prior}};
   return 'Au repos jusqu’à la rencontre : '+who.map(p=>p.name).join(', ')+'.';
  }
  if(kind==='forte'){
   st.pending=st.pending.filter(x=>!(x.fixtureId===f.id&&x.kind==='forte')).concat({fixtureId:f.id,kind:'forte'}).slice(-6);
   applyPending(s);
   return now&&now.id===f.id?'La meilleure feuille possible est posée.':'La meilleure feuille possible sera posée la semaine du match.';
  }
  if(kind==='jeunes'){
   const chosen=candidatsJeunes(s,club,f),signed=[];
   for(const yid of chosen){
    const y=(s.development?.academy||[]).find(z=>z.id===yid);
    if(y&&typeof promoteYouth==='function'&&promoteYouth(yid)===true)signed.push(y);
   }
   check(signed.length>0,'aucun jeune n’a pu être promu');
   st.pending=st.pending.filter(x=>!(x.fixtureId===f.id&&x.kind==='jeunes')).concat({fixtureId:f.id,kind:'jeunes',ids:signed.map(y=>y.id)}).slice(-6);
   applyPending(s);
   return signed.map(y=>y.name).join(', ')+(signed.length>1?' signent':' signe')+' et '+(signed.length>1?'seront lancés':'sera lancé')+' dans la feuille du match.';
  }
  const p=club.players.find(x=>x.id===mail.player);
  if(kind==='reposer'){
   st.pending=st.pending.filter(x=>!(x.fixtureId===f.id&&x.kind==='reposer'&&x.player===p.id)).concat({fixtureId:f.id,kind:'reposer',player:p.id}).slice(-6);
   applyPending(s);
   return p.name+' souffle ce week-end : la cellule en prend note.';
  }
  if(kind==='amenagement'){
   // Accord possible, jamais garanti : la décision dépend de la relation avec la fédération et d'une empreinte du mail.
   const odds=Math.max(20,Math.min(85,55+Math.round((st.relation-RELATION_START)/2)));
   if(hash(mail.id+':'+s.club+':amenagement')%100<odds){
    st.waivers[p.id]=f.id;
    return 'Le staff des Bleus accepte : '+p.name+' peut jouer ce week-end.';
   }
   return 'Le staff des Bleus refuse : '+p.name+' doit souffler.';
  }
  // ignorer
  st.relation=Math.max(0,st.relation-3);
  return 'Tu passes outre : la cellule le consigne, la relation avec la fédération tombe à '+st.relation+'/100.';
 }

 // ------------------------------------------------------------------ domaine
 function validate(s){
  if(!s||s.doublons===undefined)return true;
  const st=s.doublons;
  check(object(st)&&st.version===1&&st.policy===POLICY&&int(st.season,1,s.season)&&Array.isArray(st.ids)&&st.ids.length<=LIST_SIZE&&st.ids.every(id)&&new Set(st.ids).size===st.ids.length,'état invalide');
  check(object(st.rests)&&Object.keys(st.rests).length<=LIST_SIZE&&Object.entries(st.rests).every(([k,v])=>id(k)&&typeof v==='string'&&v.length<=KEEP&&/^[jrnx]*$/.test(v)),'repos invalides');
  check(int(st.relation,0,100)&&int(st.violations,0,1000)&&object(st.waivers)&&Object.keys(st.waivers).length<=LIST_SIZE&&Object.entries(st.waivers).every(([k,v])=>id(k)&&id(v)),'relation invalide');
  check(Array.isArray(st.pending)&&st.pending.length<=6&&st.pending.every(x=>object(x)&&id(x.fixtureId)&&['forte','jeunes','reposer'].includes(x.kind)&&(x.ids===undefined||Array.isArray(x.ids)&&x.ids.every(id))&&(x.player===undefined||id(x.player))),'plans invalides');
  check(st.rotation===null||object(st.rotation)&&id(st.rotation.fixtureId)&&object(st.rotation.prior)&&Object.keys(st.rotation.prior).length<=6&&Object.entries(st.rotation.prior).every(([k,v])=>id(k)&&['collective','normal','intense','repos'].includes(v)),'rotation invalide');
  check(Array.isArray(st.bilans)&&st.bilans.length<=5&&st.bilans.every(b=>object(b)&&int(b.season,1,s.season)&&int(b.violations,0,1000)&&int(b.relation,0,100)),'bilans invalides');
  return true;
 }
 function execute(){throw Error('Doublons : aucune commande.');}
 function installHooks(){
  if(typeof buildSheet==='function'&&!buildSheet.__doublons){
   const original=buildSheet,wrapped=function(c,preferred=[],preferredBench=[]){
    const sheet=original.apply(this,arguments),s=state();
    // Une feuille choisie à la main n'est jamais modifiée.
    if(!s||!c||preferred.length||preferredBench.length)return sheet;
    return comply(s,c,sheet);
   };
   Object.assign(wrapped,original);wrapped.__doublons=true;buildSheet=wrapped;
  }
  if(typeof applyMatchInjuries==='function'&&!applyMatchInjuries.__doublons){
   const original=applyMatchInjuries,wrapped=function(l){
    try{record(l);}catch(e){/* le suivi ne doit jamais empêcher un match */}
    return original.apply(this,arguments);
   };
   Object.assign(wrapped,original);wrapped.__doublons=true;applyMatchInjuries=wrapped;
  }
  return true;
 }
 return {POLICY,WINDOW,MIN_RESTS,project,validate,execute,installHooks,observe,comply,mustRest,record,impact,aMenager,refus,agir,
  isListed:(s,pid)=>listed(s,pid),idSet:s=>ids(s),buildList,history:(s,pid)=>active(s)?history(s,pid):''};
}
module.exports={files,commands,factory};
