'use strict';
// Executed in the headless engine context; helpers only receive player copies.
// No presentation identity is ever written into the career/save.
module.exports=function nativeModel(){
 const presentation=c=>c?{id:c.id,slug:c.slug,city:c.city,name:c.name,abbr:c.abbr,color:c.color,stadium:c.stadium,cityImage:c.cityImage,stadiumImage:c.stadiumImage}:null;
 const catalogue=CDFranceClubs.clubs.map(c=>({...presentation(c),division:c.division,playable:c.id<14}));
 const meta={prototype:true,mode:'fictional14',engine:'historical',dataDir:nativeDataDirectory,saveError:lastSaveError,catalogue,season:S?.season??null,round:S?.round??null,phase:S?.phase??null,trained:S?.trained??false,training:S?.training??null,morale:S?.morale??null,trust:S?.trust??null,rulesProfile:'XV adulte professionnel français 2025–2026 — abstractions du moteur historique'};
 if(!S)return {protocol:1,club:null,league:[],squad:[],next:null,history:[],messages:[],ledger:[],live:null,meta};
 const sorted=ranked();
 const summary=c=>({id:c.id,name:c.name,abbr:c.abbr,color:c.color,stadium:c.stadium,cash:c.cash,goal:c.goal,points:c.points,rank:sorted.findIndex(x=>x.id===c.id)+1,presentation:presentation(CDFranceClubs.forCareer(S,c.id))});
 const own=club();
 const squad=own.players.map(source=>{
  const p=JSON.parse(JSON.stringify(source)),index=S.lineup.indexOf(p.id),bench=S.reserves.indexOf(p.id);
  let hash=2166136261;for(const ch of p.id){hash^=ch.charCodeAt(0);hash=Math.imul(hash,16777619);}const nativeId=/^p\d+-(\d+)-\d+$/.exec(p.id);
  return {id:p.id,name:p.name,pos:p.pos,fam:p.fam,age:p.age,rating:p.rating,note:roleNote(p),potential:potentialAtRole(p),condition:p.condition,physicalLoad:physicalLoadValue(p),injury:p.injury,salary:p.salary,contractEnd:p.contractEnd??null,contractLabel:p.contractEnd==null?'Sans contrat professionnel':contractLabel(p),minutes:p.dev?.minutes??0,appearances:p.dev?.appearances??0,status:p.injury?'Blessé':index>=0?'Titulaire':bench>=0?'Remplaçant':'Hors groupe',shirtNumber:index>=0?index+1:bench>=0?bench+16:null,attributes:Object.fromEntries(Object.keys(ATTR).map(k=>[k,skill(p,k)])),portraitIndex:nativeId?Number(nativeId[1])%32:(hash>>>0)%32};
 });
 const pair=nextMatch(),l=S.live;
 let statsRows=[];
 if(l){const [a,b]=l.stats,total=a.possession+b.possession;statsRows=[
  ['Possession',total?Math.round(a.possession/total*100)+'%':'—',total?Math.round(b.possession/total*100)+'%':'—'],
  ['Territoire',total?Math.round(a.territory/total)+'%':'—',total?Math.round(b.territory/total)+'%':'—'],
  ['Mêlées conservées',a.scrumsWon+' / '+a.scrums,b.scrumsWon+' / '+b.scrums],
  ['Touches conservées',a.lineoutsWon+' / '+a.lineouts,b.lineoutsWon+' / '+b.lineouts],
  ['Pénalités concédées',a.penalties,b.penalties],['Cartons jaunes',a.yellows,b.yellows],
  ['Tirs de pénalité',a.goals+' / '+a.goalAttempts,b.goals+' / '+b.goalAttempts],
  ['Transformations',a.conversions+' / '+a.conversionAttempts,b.conversions+' / '+b.conversionAttempts]
 ].map(([label,home,away])=>({label,home,away}));}
 return {protocol:1,club:summary(own),league:sorted.map(c=>({...summary(c),played:c.played,won:c.won,drawn:c.drawn,lost:c.lost,pf:c.pf,pa:c.pa,bonus:c.bonus,form:c.form})),squad,
  next:pair?{pair,home:summary(S.clubs[pair[0]]),away:summary(S.clubs[pair[1]]),label:label(),round:S.round,phase:S.phase}:null,
  history:S.history,messages:S.news,ledger:S.ledger,
  live:l?{minute:l.minute,period:l.flow?.period??(l.minute>40?2:1),score:l.score,tries:l.tries,paused:l.paused,finished:l.finished,halftime:l.halftime,weather:l.weather,pair:l.pair,teams:l.pair.map(id=>summary(S.clubs[id])),events:l.events,stats:l.stats,statsRows,scene:CDMatch3DAdapter.normalize(matchScene(l))}:null,meta};
};
