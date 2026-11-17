'use strict';
// Palmarès d'un club dès le premier jour (lot 3, demande de Léo, 15 novembre 2026).
//
// L'écran Club → Histoire affichait « Saisons archivées 0 / Titres conservés 0 » en début de
// carrière : seules les saisons jouées pendant la carrière étaient lues. Ce module fusionne :
//  1. le palmarès connu avant la carrière (`club-history.json` : titres, finales, derniers rangs,
//     jusqu'à la saison 2025-26), identifié par le même numéro de club que la base du jeu ;
//  2. les saisons archivées pendant la carrière (`archives.seasons`, projection Monde).
//
// Aucune prose du fichier d'historique n'est reprise (la présentation `bio` peut citer des
// personnes réelles) : seules les données structurées (compétition, titres, finale, rang, année)
// sont lues, et les noms de compétitions viennent de l'identité du jeu côté interface.
// Fonction pure : aucune écriture, résultat déterministe.
const FINISH_ORDER=Object.freeze({final:0,semi:1,quarter:2});
const FINISH_LABEL=Object.freeze({final:'Finaliste',semi:'Demi-finaliste',quarter:'Quart de finaliste'});
const EUROPE=Object.freeze(['champions','challenge']);

const seasonLabel=endYear=>`${endYear-1}-${String(endYear).slice(2)}`;
const plural=(n,one,many)=>`${n} ${n>1?many:one}`;
const isId=(a,b)=>a!==null&&a!==undefined&&Number(a)===Number(b);

function fromHistory(history){
 const out=[];
 for(const r of Array.isArray(history?.results)?history.results:[]){
  if(!r||typeof r.competition!=='string')continue;
  const year=Number.isSafeInteger(r.year)?r.year:0;
  if(Number.isSafeInteger(r.titles)&&r.titles>0)out.push({kind:'titre',competition:r.competition,count:r.titles,year,source:'histoire'});
  else if(typeof r.finish==='string'&&r.finish in FINISH_ORDER)out.push({kind:r.finish,competition:r.competition,year,source:'histoire'});
  else if(Number.isSafeInteger(r.rank)&&r.rank>0)out.push({kind:'rang',competition:r.competition,rank:r.rank,year,source:'histoire'});
 }
 return out;
}

function fromArchives(archives,clubId){
 const out=[];
 for(const y of Array.isArray(archives?.seasons)?archives.seasons:[]){
  if(!Number.isSafeInteger(y?.season))continue;
  const year=2026+y.season; // saison 1 = 2026-27 : année de fin
  const titled=new Set();
  const champs=Array.isArray(y.champions)?y.champions:Object.entries(y.champions||{}).map(([leagueId,id])=>({leagueId,clubId:id}));
  for(const c of champs)if(c&&isId(c.clubId,clubId)){titled.add(c.leagueId);out.push({kind:'titre',competition:String(c.leagueId),count:1,year,source:'carriere'});}
  for(const id of EUROPE)if(isId(y.europe?.[id]?.champion,clubId)&&!titled.has(id)){titled.add(id);out.push({kind:'titre',competition:id,count:1,year,source:'carriere'});}
  for(const [leagueId,table] of Object.entries(y.standings||{})){
   const index=Array.isArray(table)?table.findIndex(id=>isId(id,clubId)):-1;
   if(index>=0&&!titled.has(leagueId))out.push({kind:'rang',competition:leagueId,rank:index+1,size:table.length,year,source:'carriere'});
  }
  for(const [leagueId,id] of Object.entries(y.finalists||{}))if(isId(id,clubId)&&!titled.has(leagueId))out.push({kind:'final',competition:leagueId,year,source:'carriere'});
 }
 return out;
}

// Retourne toujours un objet complet ; `vide` vaut true quand le club n'a aucune ligne.
function build({history=null,archives=null,clubId,clubName=''}={}){
 const lines=[...fromHistory(history),...fromArchives(archives,clubId)];
 const byTitle=new Map();
 for(const l of lines)if(l.kind==='titre'){
  const t=byTitle.get(l.competition)||{competition:l.competition,count:0,lastYear:0};
  t.count+=l.count;t.lastYear=Math.max(t.lastYear,l.year);byTitle.set(l.competition,t);
 }
 const titles=[...byTitle.values()].sort((a,b)=>b.count-a.count||b.lastYear-a.lastYear||a.competition.localeCompare(b.competition));
 const finals=lines.filter(l=>l.kind in FINISH_ORDER).map(l=>({competition:l.competition,finish:l.kind,label:FINISH_LABEL[l.kind],year:l.year,season:l.year?seasonLabel(l.year):'',source:l.source}))
  .sort((a,b)=>b.year-a.year||FINISH_ORDER[a.finish]-FINISH_ORDER[b.finish]||a.competition.localeCompare(b.competition));
 const recent=lines.map(l=>({kind:l.kind,competition:l.competition,year:l.year,season:l.year?seasonLabel(l.year):'',source:l.source,
   ...(l.kind==='titre'?{count:l.count}:{}),...(l.kind==='rang'?{rank:l.rank,...(l.size?{size:l.size}:{})}:{}),
   text:l.kind==='titre'?'Champion':l.kind==='rang'?`${l.rank===1?'1re':l.rank+'e'} place`:FINISH_LABEL[l.kind]}))
  .sort((a,b)=>b.year-a.year||a.competition.localeCompare(b.competition)||a.kind.localeCompare(b.kind)).slice(0,12);
 const totalTitles=titles.reduce((n,t)=>n+t.count,0);
 const careerSeasons=Array.isArray(archives?.seasons)?archives.seasons.length:0;
 const vide=lines.length===0;
 const name=String(clubName||'Le club');
 return {
  clubId,vide,totalTitles,titles,finals:finals.slice(0,8),recent,careerSeasons,
  founded:Number.isSafeInteger(history?.founded)?history.founded:null,
  // Chiffre de tête de l'écran : titres au palmarès (connus + carrière), jamais « 0 » sec.
  headline:vide?'Palmarès vierge':totalTitles>0?plural(totalTitles,'titre','titres')+' au palmarès':'Aucun titre pour l’instant',
  emptyText:vide?`${name} n’a encore rien inscrit à son palmarès : la première page de son histoire s’écrit avec toi.`:'',
 };
}

module.exports={build,fromHistory,fromArchives,seasonLabel};
