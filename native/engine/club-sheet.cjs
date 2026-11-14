'use strict';
// Fiche d'un club (demande de Léo, 14 novembre 2026 : « quand on clique sur le nom d'un club ou
// qu'on le recherche, il faut que ça ouvre la fiche du club, avec l'effectif et le XV type, celui
// qui revient le plus »).
//
// Deux parties :
//  1. un compteur compact des feuilles de match de chaque club pour la saison en cours
//     (`S.clubSheet.clubs`), alimenté à la fin de chaque match détaillé (crochet sur
//     `recordDevelopmentMatch`, comme les notes de match) : pour chaque joueur, le nombre de
//     titularisations par maillot (1 à 15) et le nombre d'entrées en jeu depuis le banc ;
//  2. une projection en lecture seule d'un club (`sheet(clubId)`), servie par la commande
//     `club_sheet` du worker : identité, classement, forme, résultats, prochain match,
//     confrontations avec le club du manager, effectif (la connaissance des joueurs est appliquée
//     ensuite par `projectKnowledge`, comme partout ailleurs), XV type et statistiques.
//
// XV type = pour chaque maillot 1 à 15, le joueur de l'effectif actuel le plus souvent titulaire à
// ce maillot cette saison (un joueur n'occupe qu'un maillot : attribution gloutonne par nombre de
// titularisations décroissant, égalités départagées par le total de titularisations puis
// l'identifiant — résultat déterministe). Saison pas commencée, club sans feuille (championnat en
// résultats rapides) ou maillot jamais rempli par un joueur encore au club : XV probable de la
// composition automatique (`buildSheet`), annoncé comme tel.
//
// Format compact (profil Monde proche de 24 Mio) : une chaîne par club,
//   "<matchs>|<jeton>:<maillot>x<nombre>.<maillot>x<nombre>.b<entrées> <jeton>:…"
// où <jeton> est l'empreinte FNV-1a 32 bits de l'identifiant du joueur en base 36 (7 caractères au
// plus). Les collisions au sein d'un même effectif (≈ 5·10⁻⁷) sont détectées à la lecture : le
// jeton ambigu est ignoré. Remis à zéro à chaque nouvelle saison. Anciennes sauvegardes : état
// absent = aucune feuille comptée, créé au premier match (XV probable en attendant).
//
// Clubs suivis (`S.clubSheet.followed`, 24 au plus) : commande `club_follow` ; une brève de
// résultat par club suivi à la fin de chaque journée.
const files=Object.freeze([]),commands=Object.freeze(['club_follow']);

function factory(){
 const VERSION=1,MAX_FOLLOW=24,MAX_TEXT=8000;
 const state=()=>typeof S==='undefined'?null:S;
 const obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const check=(ok,message)=>{if(!ok)throw Error('Fiche club : '+message+'.');};
 function jeton(id){let h=0x811c9dc5;const t=String(id);for(let i=0;i<t.length;i++){h^=t.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}return h.toString(36);}
 const vide=s=>({version:VERSION,season:s.season,clubs:{},followed:[]});
 function etat(s){
  if(!obj(s.clubSheet))s.clubSheet=vide(s);
  if(s.clubSheet.season!==s.season){s.clubSheet.season=s.season;s.clubSheet.clubs={};}
  return s.clubSheet;
 }
 // Chaîne -> {n, joueurs:Map(jeton -> {m:[15 compteurs], b})}.
 function decoder(texte){
  const out={n:0,joueurs:new Map()};
  if(typeof texte!=='string'||!texte)return out;
  const [tete,corps='']=texte.split('|');out.n=Number(tete)||0;
  for(const entree of corps.split(' ')){
   if(!entree)continue;
   const [tk,parts='']=entree.split(':'),j={m:new Array(15).fill(0),b:0};
   for(const p of parts.split('.')){
    if(!p)continue;
    if(p[0]==='b'){j.b=Number(p.slice(1))||0;continue;}
    const [m,c]=p.split('x').map(Number);if(m>=1&&m<=15)j.m[m-1]=c||0;
   }
   out.joueurs.set(tk,j);
  }
  return out;
 }
 function encoder(d){
  const parts=[];
  for(const [tk,j] of [...d.joueurs.entries()].sort((a,b)=>a[0]<b[0]?-1:a[0]>b[0]?1:0)){
   const t=[];j.m.forEach((c,i)=>{if(c>0)t.push((i+1)+'x'+c);});if(j.b>0)t.push('b'+j.b);
   if(t.length)parts.push(tk+':'+t.join('.'));
  }
  return d.n+'|'+parts.join(' ');
 }
 // Fin d'un match détaillé (tous les clubs) : titulaires par maillot et entrées depuis le banc.
 function enregistrer(l){
  const s=state();if(!s||!l||!Array.isArray(l.pair)||!Array.isArray(l.sheets)||l.clubSheetRecorded)return false;
  if(l.pair.some(ci=>!int(ci,0,s.clubs.length-1)))return false;
  l.clubSheetRecorded=true;
  const st=etat(s);
  for(let side=0;side<2;side++){
   const sh=l.sheets[side],club=s.clubs[l.pair[side]];if(!sh||!club||!Array.isArray(sh.initial))continue;
   const membres=new Set(club.players.map(p=>String(p.id)));
   const initial=sh.initial.slice(0,15).map(id=>id==null?null:String(id));
   // Garde : une feuille qui ne vient pas de ce club (sélection, match spécial) n'est pas comptée.
   if(initial.filter(id=>id&&membres.has(id)).length<8)continue;
   const d=decoder(st.clubs[club.id]);d.n++;
   const fiche=id=>{const tk=jeton(id);let j=d.joueurs.get(tk);if(!j){j={m:new Array(15).fill(0),b:0};d.joueurs.set(tk,j);}return j;};
   initial.forEach((id,i)=>{if(id&&membres.has(id))fiche(id).m[i]++;});
   const titulaires=new Set(initial.filter(Boolean));
   for(const id of new Set((sh.used||[]).map(String)))if(!titulaires.has(id)&&membres.has(id)&&(Number(sh.minutes?.[id])||0)>0)fiche(id).b++;
   const texte=encoder(d);
   if(texte.length<=MAX_TEXT)st.clubs[club.id]=texte;
  }
  return true;
 }
 // Lecture des compteurs pour l'effectif ACTUEL d'un club : {n, parJoueur:Map(id -> {m,b,total})}.
 function compteurs(s,club){
  const d=decoder(s.clubSheet?.season===s.season?s.clubSheet.clubs?.[club.id]:null),par=new Map(),vus=new Map();
  for(const p of club.players){const tk=jeton(p.id);vus.set(tk,(vus.get(tk)||0)+1);}
  for(const p of club.players){
   const tk=jeton(p.id);if(vus.get(tk)!==1)continue;
   const j=d.joueurs.get(tk);if(!j)continue;
   par.set(String(p.id),{m:j.m.slice(),b:j.b,total:j.m.reduce((a,x)=>a+x,0)});
  }
  return {n:d.n,parJoueur:par};
 }
 // XV le plus fréquent (déterministe) : couples (maillot, joueur) triés par titularisations au
 // maillot, puis titularisations totales, puis maillot et identifiant ; chaque maillot et chaque
 // joueur pris une seule fois.
 function xvFrequent(par){
  const couples=[];
  for(const [id,j] of par)j.m.forEach((c,i)=>{if(c>0)couples.push([i,id,c,j.total]);});
  couples.sort((a,b)=>b[2]-a[2]||b[3]-a[3]||a[0]-b[0]||(a[1]<b[1]?-1:a[1]>b[1]?1:0));
  const maillots=new Array(15).fill(null),pris=new Set();
  for(const [i,id,c] of couples){if(maillots[i]||pris.has(id))continue;maillots[i]={id,starts:c};pris.add(id);}
  return maillots;
 }
 function probable(club){
  if(typeof buildSheet!=='function')return {lineup:new Array(15).fill(null),bench:[]};
  try{const r=buildSheet(club);return {lineup:(r.lineup||[]).map(x=>x==null?null:String(x)),bench:(r.bench||[]).filter(x=>x!=null).map(String)};}
  catch(e){return {lineup:new Array(15).fill(null),bench:[]};}
 }
 function xvType(s,club){
  const {n,parJoueur}=compteurs(s,club),frequent=xvFrequent(parJoueur),prob=probable(club);
  const pris=new Set(frequent.filter(Boolean).map(x=>x.id));
  let completes=0;
  const slots=frequent.map((x,i)=>{
   if(x)return {jersey:i+1,id:x.id,starts:x.starts,source:'feuilles'};
   // Maillot sans titulaire encore au club : XV probable, sans doublon.
   const id=prob.lineup[i];
   if(id&&!pris.has(id)){pris.add(id);completes++;return {jersey:i+1,id,starts:parJoueur.get(id)?.m[i]||0,source:'probable'};}
   completes++;return {jersey:i+1,id:null,starts:0,source:'probable'};
  });
  // Le banc ne reprend jamais un joueur du XV type affiché à côté (cohérence de la fiche).
  const xvIds=new Set(slots.map(x=>x.id).filter(Boolean));
  const bench=[...parJoueur.entries()].filter(([id,j])=>j.b>0&&!xvIds.has(id)).sort((a,b)=>b[1].b-a[1].b||b[1].total-a[1].total||(a[0]<b[0]?-1:1)).slice(0,8).map(([id,j])=>({id,entries:j.b,starts:j.total}));
  return {matches:n,source:n===0?'probable':completes===0?'feuilles':'mixte',completed:completes,slots,bench,probableBench:n===0?prob.bench.filter(id=>!xvIds.has(id)).slice(0,8):[]};
 }
 function nomLigue(s,id){
  const reg=typeof CDWorldCareer!=='undefined'?CDWorldCareer.edition(s)?.registry?.leagues:null;
  return (reg||[]).find(l=>l.id===id)?.name||null;
 }
 function ligueDe(s,clubId){
  const leagues=s.worldMode?.leagues;if(!obj(leagues))return null;
  return Object.keys(leagues).find(id=>leagues[id].members?.includes(clubId))??null;
 }
 function resultat(r,clubId){
  const side=r.pair.indexOf(clubId),pour=r.score[side],contre=r.score[1-side];
  return {fixtureId:r.fixtureId??null,date:r.date??null,competitionId:r.competitionId??null,phase:r.phase??null,home:side===0&&!r.neutral,neutral:!!r.neutral,
   opponent:r.pair[1-side],for:pour,against:contre,outcome:pour>contre?'V':pour<contre?'D':'N',tries:Array.isArray(r.tries)?[r.tries[side],r.tries[1-side]]:null};
 }
 function sheet(clubId){
  const s=state();check(s,'aucune carrière');
  check(int(clubId,0,s.clubs.length-1),'club inconnu');
  const club=s.clubs[clubId],own=s.club,saison=s.season;
  const historique=(s.history||[]).filter(r=>Array.isArray(r.pair)&&r.pair.includes(clubId)&&(r.season===undefined||r.season===saison));
  const tous=historique.map(r=>resultat(r,clubId));
  const recents=tous.slice().sort((a,b)=>String(b.date||'').localeCompare(String(a.date||''))).slice(0,6);
  const joues=new Set((s.history||[]).map(r=>r.fixtureId).filter(Boolean));
  const prochain=(s.worldMode?.fixtures||[]).filter(f=>(f.homeId===clubId||f.awayId===clubId)&&!joues.has(f.id)&&f.homeId!=null&&f.awayId!=null)
   .sort((a,b)=>String(a.date||'').localeCompare(String(b.date||''))||String(a.id).localeCompare(String(b.id)))[0]||null;
  // Confrontations avec le club du manager : toutes les saisons conservées dans l'historique.
  const face=clubId===own?[]:(s.history||[]).filter(r=>Array.isArray(r.pair)&&r.pair.includes(clubId)&&r.pair.includes(own)).map(r=>({...resultat(r,own),season:r.season??saison}));
  const bilan={played:face.length,won:face.filter(x=>x.outcome==='V').length,drawn:face.filter(x=>x.outcome==='N').length,lost:face.filter(x=>x.outcome==='D').length,
   last:face.slice().sort((a,b)=>String(b.date||'').localeCompare(String(a.date||''))).slice(0,5)};
  // Prochain match entre les deux clubs (calendrier du Monde), même sans confrontation passée.
  const prochainFace=clubId===own?null:(s.worldMode?.fixtures||[]).filter(f=>!joues.has(f.id)&&f.homeId!=null&&f.awayId!=null&&((f.homeId===clubId&&f.awayId===own)||(f.homeId===own&&f.awayId===clubId)))
   .sort((a,b)=>String(a.date||'').localeCompare(String(b.date||''))||String(a.id).localeCompare(String(b.id)))[0]||null;
  bilan.upcoming=prochainFace?{fixtureId:prochainFace.id,date:prochainFace.date??null,competitionId:prochainFace.competitionId??null,phase:prochainFace.phase??null,home:prochainFace.homeId===own,stadium:s.clubs[prochainFace.homeId]?.stadium||null}:null;
  const {parJoueur}=compteurs(s,club),notes=s.matchNotes?.joueurs||{};
  const squad=club.players.map(p=>{
   const c=parJoueur.get(String(p.id)),j=notes[p.id]?.s,f=p.playerFacts||{};
   return {id:String(p.id),name:p.name,pos:p.pos,fam:p.fam,age:p.age,rating:p.rating,potential:p.potential,
    injury:Number(p.injury)||0,suspension:Number(p.suspension)||0,contractEnd:p.contractEnd??null,salary:p.salary??null,
    nationality:f.nationality??p.lnrNationality??null,flagCode:f.flagCode??null,seniorCaps:f.seniorCaps??null,seniorNationName:f.seniorNationName??null,onInternationalDuty:!!f.onInternationalDuty,
    appearanceId:p.appearanceId??null,appearanceBuild:p.appearanceBuild??null,appearanceBankVersion:p.appearanceBankVersion??null,portraitPath:p.portraitPath??null,
    heightCm:f.heightCm??null,weightKg:f.weightKg??null,
    starts:c?.total||0,benchEntries:c?.b||0,
    matches:j?j[0]:0,average:j&&j[0]?Math.round(j[1]/j[0])/10:null,tries:j?j[3]:0,tackles:j?j[4]:0,metres:j?j[5]:0,playerOfMatch:j?j[6]:0};
  });
  const d=s.clubDirections?.clubs?.[clubId];
  const lg=ligueDe(s,clubId);
  const capacites=typeof nativeStadiumCapacities==='object'&&nativeStadiumCapacities?nativeStadiumCapacities:null;
  const essais=historique.reduce((a,r)=>a+(Array.isArray(r.tries)?Number(r.tries[r.pair.indexOf(clubId)])||0:0),0);
  const encaisses=historique.reduce((a,r)=>a+(Array.isArray(r.tries)?Number(r.tries[1-r.pair.indexOf(clubId)])||0:0),0);
  return {
   id:clubId,own:clubId===own,season:saison,followed:(s.clubSheet?.followed||[]).includes(clubId),
   name:club.name,abbr:club.abbr,color:club.color,stadium:club.stadium||null,
   capacity:Number.isFinite(club.stadiumCapacity)?club.stadiumCapacity:(capacites?.[clubId]??null),
   reputation:Number.isFinite(club.base)?club.base:null,cash:Number.isFinite(club.cash)?club.cash:null,goal:club.goal||null,
   leagueId:lg,leagueName:lg?nomLigue(s,lg):null,
   coach:d?.coach?.name||null,president:d?.president?.name||null,director:d?.director?.name||null,strategy:d?.strategy||null,
   wageBill:club.players.reduce((a,p)=>a+(Number(p.salary)||0),0),squadSize:club.players.length,
   averageAge:club.players.length?Math.round(club.players.reduce((a,p)=>a+(Number(p.age)||0),0)/club.players.length*10)/10:null,
   table:{points:club.points??0,played:club.played??0,won:club.won??0,drawn:club.drawn??0,lost:club.lost??0,pf:club.pf??0,pa:club.pa??0,bonus:club.bonus??0,form:Array.isArray(club.form)?club.form.slice(-5):[]},
   team:{matches:historique.length,triesFor:essais,triesAgainst:encaisses,pointsFor:historique.reduce((a,r)=>a+(Number(r.score?.[r.pair.indexOf(clubId)])||0),0),pointsAgainst:historique.reduce((a,r)=>a+(Number(r.score?.[1-r.pair.indexOf(clubId)])||0),0),
    won:tous.filter(x=>x.outcome==='V').length,drawn:tous.filter(x=>x.outcome==='N').length,lost:tous.filter(x=>x.outcome==='D').length},
   results:recents,
   // Calendrier du club pour la saison : matchs joués (score) et à venir, dans l'ordre des dates.
   fixtures:(s.worldMode?.fixtures||[]).filter(f=>f.homeId===clubId||f.awayId===clubId).map(f=>{
    const r=(s.history||[]).find(h=>h.fixtureId===f.id),x=r&&Array.isArray(r.pair)?resultat(r,clubId):null;
    return {fixtureId:f.id,date:f.date??null,competitionId:f.competitionId??null,phase:f.phase??null,home:f.homeId===clubId,opponent:f.homeId===clubId?f.awayId:f.homeId,
     played:!!x,for:x?x.for:null,against:x?x.against:null,outcome:x?x.outcome:null};
   }).filter(f=>f.opponent!=null).sort((a,b)=>String(a.date||'').localeCompare(String(b.date||''))||String(a.fixtureId).localeCompare(String(b.fixtureId))).slice(0,60),
   next:prochain?{fixtureId:prochain.id,date:prochain.date??null,competitionId:prochain.competitionId??null,phase:prochain.phase??null,home:prochain.homeId===clubId,opponent:prochain.homeId===clubId?prochain.awayId:prochain.homeId}:null,
   headToHead:bilan,
   squad,
   xv:xvType(s,club),
  };
 }
 function execute(command,payload){
  const s=state();check(command==='club_follow','commande inconnue');check(s,'aucune carrière');
  check(obj(payload)&&Object.keys(payload).every(k=>['club','follow'].includes(k))&&int(payload.club,0,s.clubs.length-1)&&typeof payload.follow==='boolean','paramètres invalides');
  check(payload.club!==s.club,'votre club est déjà suivi par vos soins');
  const st=etat(s),liste=st.followed.filter(id=>id!==payload.club);
  if(payload.follow){check(liste.length<MAX_FOLLOW,'24 clubs suivis au plus');liste.push(payload.club);}
  st.followed=liste;
  return {clubFollow:{club:payload.club,followed:payload.follow}};
 }
 function project(){const s=state();return {followed:(s?.clubSheet?.followed||[]).slice()};}
 function validate(s){
  if(!s||s.clubSheet===undefined)return true;
  const st=s.clubSheet;
  check(obj(st)&&st.version===VERSION&&int(st.season,0,10000)&&obj(st.clubs)&&Array.isArray(st.followed),'état invalide');
  check(st.followed.length<=MAX_FOLLOW&&new Set(st.followed).size===st.followed.length&&st.followed.every(id=>int(id,0,s.clubs.length-1)),'clubs suivis invalides');
  for(const [k,v] of Object.entries(st.clubs)){
   check(/^\d{1,4}$/.test(k)&&Number(k)<s.clubs.length&&typeof v==='string'&&v.length<=MAX_TEXT&&/^\d{1,4}\|([0-9a-z]{1,7}:(\d{1,2}x\d{1,4}|b\d{1,4})(\.(\d{1,2}x\d{1,4}|b\d{1,4}))*( |$))*$/.test(v),'feuilles du club invalides');
  }
  return true;
 }
 // Brève de fin de journée pour chaque club suivi qui vient de jouer.
 let vus=null;
 function breves(){
  const s=state(),liste=s?.clubSheet?.followed;if(!s||!Array.isArray(liste)||!liste.length||typeof news!=='function')return;
  const clubs=new Set(liste);
  for(const r of (s.history||[]).slice(-200)){
   if(!r?.fixtureId||vus?.has(r.fixtureId)||!Array.isArray(r.pair))continue;
   vus?.add(r.fixtureId);
   const c=r.pair.find(id=>clubs.has(id));if(c===undefined||r.pair.includes(s.club))continue;
   news('Club suivi · '+s.clubs[r.pair[0]].name+' '+r.score[0]+'–'+r.score[1]+' '+s.clubs[r.pair[1]].name+'.');
  }
 }
 function installHooks(){
  if(typeof recordDevelopmentMatch==='function'&&!recordDevelopmentMatch.__clubSheet){
   const original=recordDevelopmentMatch,wrapped=function(l){try{if(l&&!l.developmentRecorded)enregistrer(l);}catch(e){}return original.apply(this,arguments);};
   Object.assign(wrapped,original);wrapped.__clubSheet=true;recordDevelopmentMatch=wrapped;
  }
  if(typeof finishRound==='function'&&!finishRound.__clubSheet){
   const original=finishRound,wrapped=function(){
    const s=state();vus=new Set((s?.history||[]).map(r=>r?.fixtureId).filter(Boolean));
    const result=original.apply(this,arguments);try{breves();}catch(e){}vus=null;return result;
   };
   Object.assign(wrapped,original);wrapped.__clubSheet=true;finishRound=wrapped;
  }
  if(typeof advanceSeason==='function'&&!advanceSeason.__clubSheet){
   const original=advanceSeason,wrapped=function(){const result=original.apply(this,arguments);const s=state();if(s?.clubSheet&&s.clubSheet.season!==s.season){s.clubSheet.season=s.season;s.clubSheet.clubs={};}return result;};
   Object.assign(wrapped,original);wrapped.__clubSheet=true;advanceSeason=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,sheet,enregistrer,jeton,decoder,encoder,xvFrequent,compteurs};
}
module.exports={files,commands,factory};
