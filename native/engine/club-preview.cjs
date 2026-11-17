'use strict';
// Aperçu d'un club avant la création de la carrière Monde (commande `club_preview`, écran « Options de
// carrière »). Lecture seule : aucune carrière requise, rien n'est écrit (ni sauvegarde, ni état), et le
// résultat ne dépend que du club et du calendrier choisi (déterministe).
// Sources, mêmes que la création : rencontres initiales de la saison 1 (world-career.cjs previewFixtures, la
// construction de newSeason), date habituelle de reprise et amicaux (reprise.cjs preview), effectif d'aperçu
// du catalogue (previewRoster), derbys (DERBYS de rugby.js), président (nom de base pres-<club>,
// board-identities.cjs, celui que club-directions.cjs lui donne à la création).
const boardIdentities=require('./board-identities.cjs');

// Calcul dans la machine du moteur : `nativePayload` = {club, daily}.
const VM_SOURCE=`(()=>{const id=nativePayload.club,E=CDWorldEditions.forMode('world-champ'),R=E.registry,c=R.clubs[id];
 const fixtures=CDWorldCareer.previewFixtures('world-champ',nativePayload.daily).filter(f=>f.homeId===id||f.awayId===id)
  .sort((a,b)=>a.date.localeCompare(b.date)||a.id.localeCompare(b.id))
  .map(f=>({id:f.id,date:f.date,homeId:f.homeId,awayId:f.awayId,competitionId:f.competitionId,phase:f.phase,round:f.round,kickoffLocal:f.kickoffLocal??null,kickoffUtc:f.kickoffUtc??null,timezone:f.timezone??null}));
 const roster=CDWorldCareer.previewRoster(R.id,id,true).map(p=>({id:p.id,name:p.name,pos:p.pos,age:p.age,rating:p.rating,potential:Number.isFinite(p.dev?.potential)?roleNote({...p,rating:p.dev.potential}):p.potential??null,
  injury:p.injury||0,leadership:p.attributesV2?.leadership??0,appearanceId:p.appearanceId,appearanceBankVersion:p.appearanceBankVersion,portraitIndex:p.portraitIndex}));
 const rivals=DERBYS.rivalites.filter(([a,b])=>a!==b&&(a===id||b===id)).map(([a,b,t])=>({id:a===id?b:a,tension:t}));
 const first=fixtures[0]?.date??null;
 return JSON.stringify({leagueId:c.leagueId,fixtures,roster,rivals,reprise:first?CDReprise.preview(id,c.leagueId,first):null});
})()`;

const byId=(a,b)=>String(a.id).localeCompare(String(b.id));
const timeFormats=new Map();
function kickoff(f){
 if(typeof f.kickoffLocal==='string'&&/^\d{2}:\d{2}$/.test(f.kickoffLocal))return f.kickoffLocal;
 if(typeof f.kickoffUtc==='string'&&f.timezone){
  try{
   if(!timeFormats.has(f.timezone))timeFormats.set(f.timezone,new Intl.DateTimeFormat('fr-FR',{timeZone:f.timezone,hour:'2-digit',minute:'2-digit',hourCycle:'h23'}));
   return timeFormats.get(f.timezone).format(new Date(f.kickoffUtc));
  }catch{return null;}
 }
 return null;
}

// raw : résultat de VM_SOURCE ; names(id) : nom du club tel que dans le catalogue de création (pack compris) ;
// pack : pack d'identités de création compatible (ou null) ; playerName(pack,id) : nom de pack d'un joueur ;
// patchLook(face) : portrait projeté (portrait-looks.cjs) ; registry : base world-champ.
function build({clubId,raw,names,pack,playerName,patchLook,registry}){
 const nameOf=id=>names(id)??registry.clubs[id]?.name??null;
 const face=p=>{
  if(!p)return null;
  const out={id:p.id,name:(pack&&playerName(pack,p.id))||p.name,pos:p.pos,age:p.age,rating:p.rating,potential:p.potential};
  if(p.appearanceId!==undefined)out.appearanceId=p.appearanceId;
  if(p.appearanceBankVersion!==undefined)out.appearanceBankVersion=p.appearanceBankVersion;
  if(Number.isInteger(p.portraitIndex))out.portraitIndex=p.portraitIndex;
  if(patchLook)patchLook(out);
  return out;
 };
 const roster=raw.roster;
 const healthy=roster.filter(p=>!(p.injury>0));
 const leader=[...healthy].sort((a,b)=>b.leadership-a.leadership||byId(a,b))[0]||null;
 const best=[...roster].sort((a,b)=>b.rating-a.rating||byId(a,b))[0]||null;
 const young=roster.filter(p=>p.age<=21);
 const prospect=(young.length
  ?young.sort((a,b)=>(b.potential??0)-(a.potential??0)||b.rating-a.rating||byId(a,b))
  :[...roster].sort((a,b)=>a.age-b.age||(b.potential??0)-(a.potential??0)||byId(a,b)))[0]||null;
 const f=raw.fixtures[0]||null;
 const firstFixture=f?{date:f.date,kickoff:kickoff(f),opponentId:f.homeId===clubId?f.awayId:f.homeId,opponentName:nameOf(f.homeId===clubId?f.awayId:f.homeId),
  home:f.homeId===clubId,competition:f.competitionId,round:Number.isInteger(f.round)?f.round+1:1}:null;
 const rivals=raw.rivals.map(r=>({id:r.id,name:nameOf(r.id),tension:r.tension,
  dates:raw.fixtures.filter(x=>x.phase==='league'&&(x.homeId===r.id||x.awayId===r.id)).map(x=>x.date)}))
  .sort((a,b)=>b.tension-a.tension||a.id-b.id);
 const presidentId='pres-'+clubId,baseName=boardIdentities.baseName(presidentId,registry);
 const president=baseName?{name:pack?.boards?.[presidentId]?.name||baseName}:null;
 return {
  club:clubId,
  reprise:raw.reprise?{firstClubs:raw.reprise.firstClubs,club:raw.reprise.club,eve:raw.reprise.eve}:{firstClubs:'2026-07-13',club:null,eve:null},
  friendlies:raw.reprise?{count:raw.reprise.friendlies.count,dates:raw.reprise.friendlies.dates.slice()}:{count:0,dates:[]},
  firstFixture,rivals,
  faces:{leader:face(leader),best:face(best),prospect:face(prospect)},
  president,
 };
}
module.exports={VM_SOURCE,build};
