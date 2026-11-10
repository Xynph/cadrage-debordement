'use strict';
module.exports=function worldModel(base,publishedVenue,clubHistory){
 const W=CDWorldCareer,copy=x=>JSON.parse(JSON.stringify(x));
 const catalogues=new WeakMap();
 const positions=['Piliers','Talonneurs','Deuxièmes lignes','Troisièmes lignes','Demis de mêlée','Demis d’ouverture','Ailiers','Centres','Arrières'];
 const starterSlots=positions.map((_,family)=>FAMILIES.filter(slot=>slot===family).length);
 const round=value=>Math.round(value*10)/10;
 function rankLine(lanes,depth){
  let filled=0,expected=0,points=0;
  for(const lane of lanes){
   const selected=lane.ratings.slice(depth*lane.slots,(depth+1)*lane.slots);
   filled+=selected.length;
   expected+=lane.slots;
   points+=selected.reduce((sum,rating)=>sum+rating,0);
  }
  return {filled,expected,points};
 }
 function rosterProfile(players){
  const groups=positions.map((_,family)=>family===0
   ?[{position:POS[0],slots:1,ratings:[]},{position:POS[2],slots:1,ratings:[]}]
   :[{slots:starterSlots[family],ratings:[]}]);
  let forwards=0,backs=0,points=0;
  for(const player of players){
   const position=player.pos;
   const family=FAMILIES[POS.indexOf(position)];
   if(family<4)forwards++;else backs++;
   points+=player.rating;
   const lane=groups[family]?.find(row=>row.position===undefined||row.position===position);
   if(lane)lane.ratings.push(player.rating);
  }
  const byPosition=groups.map(lanes=>{
   for(const lane of lanes)lane.ratings.sort((a,b)=>b-a);
   return {starters:rankLine(lanes,0),reserves:rankLine(lanes,1)};
  });
  return {average:players.length?round(points/players.length):null,forwards,backs,byPosition};
 }
 const compareLine=(a,b)=>b.filled-a.filled||b.points-a.points;
 function leagueRank(line,peers){
  const rank=1+peers.filter(peer=>compareLine(peer,line)<0).length;
  const tied=peers.filter(peer=>compareLine(peer,line)===0).length>1;
  return {rank,tied,filled:line.filled,expected:line.expected};
 }
 function startingRoster({average,forwards,backs,byPosition},division){
  const ordered=byPosition.map((group,index)=>{
   const peers=division.map(roster=>roster.byPosition[index]);
   return {name:positions[index],detail:{
    clubs:peers.length,
    starters:leagueRank(group.starters,peers.map(peer=>peer.starters)),
    reserves:leagueRank(group.reserves,peers.map(peer=>peer.reserves)),
   }};
  });
  ordered.sort((a,b)=>{
   const left=a.detail,right=b.detail;
   const missing=line=>line.expected-line.filled;
   return missing(left.starters)-missing(right.starters)
    || (2*left.starters.rank+left.reserves.rank)-(2*right.starters.rank+right.reserves.rank)
    || left.starters.rank-right.starters.rank;
  });
  const strongest=ordered[0],weakest=ordered.at(-1);
  return {
   average,forwards,backs,
   strengths:strongest?.name??'',strengthDetail:strongest?.detail??null,
   needs:weakest?.name??'',weaknessDetail:weakest?.detail??null,
  };
 }
 function catalogue(R){
  if(!catalogues.has(R)){
   const profiles=CDRosterFoundation.resolve(CDRosterFoundation.marker);
   const rosters=R.clubs.map(({id,players})=>{
    const normalized=players.map(player=>{
     const pos=profiles?.players[player.id]?.position.primary??player.pos;
     return pos===player.pos?player:{...player,pos,fam:FAMILIES[POS.indexOf(pos)]};
    });
    return rosterProfile(normalized.concat(nativeProfessionalDepth.additions(id,normalized,1)));
   }),divisions=new Map();
   R.clubs.forEach((club,index)=>{
    if(!divisions.has(club.leagueId))divisions.set(club.leagueId,[]);
    divisions.get(club.leagueId).push(rosters[index]);
   });
   catalogues.set(R,R.clubs.map(({players,...c},index)=>{
    const history=clubHistory[c.id];
    return {
     ...c,division:c.leagueId,playable:c.leagueId!=='guest',startingRoster:startingRoster(rosters[index],divisions.get(c.leagueId)),
     ...(history?{history:{founded:history.founded,bio:history.bio,results:history.results}}:{}),
    };
   }));
  }
  return catalogues.get(R);
 }
 const startingCount=R=>R.clubs.reduce((count,club)=>count+Math.max(nativeProfessionalDepth.minimum,club.players.length),0);
 const database=R=>({id:R.id,version:R.version,snapshot:R.snapshot,playerCount:R.playerCount,startingPlayerCount:startingCount(R),clubCount:R.clubCount});
 return function project(){
  const m=base(),old=CDWorldEditions.forMode('world').registry,pacific=CDWorldEditions.forMode('world-pacific')?.registry,japan=CDWorldEditions.forMode('world-japan')?.registry,nationale=CDWorldEditions.forMode('world-nationale')?.registry,champ=CDWorldEditions.forMode('world-champ')?.registry;
  m.meta.legacyCatalogue=m.meta.catalogue;m.meta.legacyDatabase={...m.meta.database,startingPlayerCount:startingCount(CDCommonRosters)};m.meta.worldDatabase=database(old);
  m.meta.worldCatalogue=catalogue(old);m.meta.availableModes=['fiction','france','common','world'];
  if(pacific){m.meta.pacificCatalogue=catalogue(pacific);m.meta.pacificDatabase=database(pacific);m.meta.availableModes.push('world-pacific');}
  if(japan){m.meta.japanCatalogue=catalogue(japan);m.meta.japanDatabase=database(japan);m.meta.availableModes.push('world-japan');}
  if(nationale){m.meta.nationaleCatalogue=catalogue(nationale);m.meta.nationaleDatabase=database(nationale);m.meta.availableModes.push('world-nationale');}
  if(champ){m.meta.champCatalogue=catalogue(champ);m.meta.champDatabase=database(champ);m.meta.availableModes.push('world-champ');}
  if(!W.active(S))return m;
  const edition=W.edition(S),R=edition.registry,years=[2026+S.season-1,2027+S.season-1];
  const tables=Object.fromEntries([...edition.leagueIds,'guest'].map(id=>[id,W.ranked(S,id)])),summaries=new Map();
  const clubSummary=id=>{if(!summaries.has(id)){const c=S.clubs[id],{players,...source}=R.clubs[id],table=tables[W.leagueId(S,id)];summaries.set(id,{id,name:c.name,abbr:c.abbr,color:c.color,stadium:c.stadium,cash:c.cash,goal:c.goal,points:c.points,rank:table.findIndex(x=>x.id===id)+1,presentation:source});}return summaries.get(id);};
  const names={'jlo-d1-d2':'Barrage Japon D1 / D2','access-nationale':'Barrage Pro D2 / Nationale'},phaseLabels={'third-place':'Petite finale',promotion:'Barrage'},champPhases={quarter:'Quarts de finale',semi:'Demi-finales',final:'Finale'};
  const dateProof=f=>edition.version>=3&&f.competitionId.startsWith('jlo-')?{dateSource:f.dateSource,dateOptions:f.dateOptions||[],dateWindow:f.dateWindow||[],leg:f.leg||null}:edition.version>=4&&['nationale','access-nationale'].includes(f.competitionId)?{dateSource:f.dateStatus,dateWindow:f.dateWindow||[],kickoffLocal:f.kickoffLocal??null,timezone:f.timezone??'Europe/Paris',scheduleSource:f.scheduleSource}:edition.version===5&&f.competitionId==='champ'?{dateSource:f.dateStatus,kickoffLocal:f.kickoffLocal??null,kickoffSource:f.kickoffSource??null,timezone:f.timezone??'Europe/London',scheduleSource:f.scheduleSource}:{};
  const tableRow=r=>({...clubSummary(r.id),played:r.played,won:r.won,drawn:r.drawn,lost:r.lost,pf:r.pf,pa:r.pa,bonus:r.bonus,points:r.points,form:r.form,unresolvedTie:!!(r.unresolvedTie||r.sportingTie)});
  m.meta={...m.meta,mode:'world',engine:'native-rugby',catalogue:catalogue(R),database:{...database(R),active:true},week:S.round,leagueId:W.leagueId(S),competitionRules:edition.version===1?'Saison 2026–2027':'Saison '+years.join('–')+' · Pacifique '+years[1],rulesProfile:edition.rules,roundLabel:W.label(S),date:W.userFixture(S)?.date||null};
  m.meta.calendarToday=W.calendarToday(S);
  const confirmedResult=S.worldMode.resultConfirmed?S.live:null;
  const cadence=W.dailyStatus(S);
  if(cadence)m.meta.calendarCadence=cadence;
  if(confirmedResult)m.live=null;
  m.club=clubSummary(S.club);m.league=tables[W.leagueId(S)].map(tableRow);
  if(edition.version>=2)m.meta.edition=edition.mode;
  if(edition.version>=3){m.meta.competitionRules+=' · Japon D1/D2 '+years.join('–');m.japanPromotion=copy(S.worldMode.japan);CDWorldJapanQuota.project(S,m);}
  m.leagues=edition.leagueIds.map(id=>{const l=S.worldMode.leagues[id];return{id,name:R.leagues.find(x=>x.id===id).name,phase:l.phase,champion:l.champion===null?null:clubSummary(l.champion),finalist:l.finalist===null?null:clubSummary(l.finalist),rows:tables[id].map(tableRow)};});
  for(const [id,cup]of Object.entries(S.worldMode.europe)){const pools=W.cupTables(S,id).map((rows,i)=>({id:i,label:'Poule '+(i+1),rows:rows.map(r=>({...tableRow({...r,id:r.clubId,form:r.form.map(x=>({W:'V',L:'D',D:'N'})[x])}),rank:r.rank,poolId:i}))}));m.leagues.push({id,name:id==='champions'?'Coupe des champions':'Challenge européen',phase:cup.phase,champion:cup.champion===null?null:clubSummary(cup.champion),finalist:cup.finalist===null?null:clubSummary(cup.finalist),pools,rows:pools.flatMap(p=>p.rows),seeds:cup.seeds||[],transfers:cup.transfers||[]});}
  const venue=f=>publishedVenue(f,S.season)??(f.venuePolicy==='centralised-super-round'?'Super Round · terrain commun':f.venueRegion==='Europe'?'Terrain désigné en Europe':f.venueDesignationPending||f.neutral?'Terrain désigné':S.clubs[f.homeId].stadium);
  m.calendar=S.worldMode.fixtures.filter(f=>f.homeId===S.club||f.awayId===S.club).map(f=>{const r=confirmedResult?.worldContext.id===f.id?confirmedResult:S.history.find(r=>r.fixtureId===f.id);return{id:f.id,label:(R.leagues.find(l=>l.id===f.competitionId)?.name||names[f.competitionId]||f.competitionId)+' · '+(f.phase==='league'||f.phase==='pool'?'J'+(f.round+1):f.phase==='promotion'?'Manche '+f.leg:phaseLabels[f.phase]||(f.competitionId==='champ'?champPhases[f.phase]:null)||f.phase),week:f.week,date:f.date,home:clubSummary(f.homeId),away:clubSummary(f.awayId),score:r?.score||null,played:!!r,phase:f.phase,leagueId:f.competitionId,competitionId:f.competitionId,neutral:f.neutral,competitionRound:f.round,venue:venue(f),winner:r?.winner??null,...dateProof(f)};}).sort((a,b)=>a.date.localeCompare(b.date)||a.id.localeCompare(b.id));
  const f=confirmedResult?null:W.userFixture(S);m.next=f?{pair:[f.homeId,f.awayId],home:clubSummary(f.homeId),away:clubSummary(f.awayId),label:W.label(S),round:f.round,week:S.round,date:f.date,neutral:f.neutral,phase:f.phase,leagueId:f.competitionId,competitionId:f.competitionId,venue:venue(f),...dateProof(f)}:null;
  const vacantNumber=CDNationaleReducedBench?.vacancy(S);
  if(vacantNumber)m.selection.reducedBench={size:22,vacantNumber};
  if(m.live&&S.live?.nationaleReducedBench)m.live.nominationSize=22;
  if(edition.version>=2&&m.meta.leagueId==='srp'&&!m.next&&!confirmedResult){const upcoming=m.calendar.find(x=>!x.played&&x.week>S.round);if(upcoming)m.meta.pacificPreparation={nextWeek:upcoming.week,nextDate:upcoming.date,weeksUntil:upcoming.week-S.round};}
  if(edition.version>=3&&['jlo-d1','jlo-d2'].includes(m.meta.leagueId)&&!m.next&&!confirmedResult){const upcoming=m.calendar.find(x=>!x.played&&x.week>S.round);if(upcoming)m.meta.japanPreparation={nextWeek:upcoming.week,nextDate:upcoming.date,weeksUntil:upcoming.week-S.round};}
  if(edition.version>=4){m.meta.competitionRules+=' · Division fédérale';m.nationalePromotion=copy(S.worldMode.nationale);const cards=f?CDWorldNationaleCards.project(S,{...f,season:years[0]},[...S.lineup,...S.reserves]):null;if(cards)m.selection.nationaleQualification=cards;}
  if(edition.version===5){
   m.meta.competitionRules+=' · Accession anglaise';m.champBoundary=copy(S.worldMode.champ);
   if(m.meta.leagueId==='champ'&&!m.next&&!confirmedResult){const upcoming=m.calendar.find(x=>!x.played&&x.week>S.round);if(upcoming)m.meta.champPreparation={nextWeek:upcoming.week,nextDate:upcoming.date,weeksUntil:upcoming.week-S.round};}
  }
  m.archives={limit:15,seasons:S.worldMode.yearbook.map(y=>({...copy(y),champions:Object.entries(y.champions).map(([leagueId,clubId])=>({leagueId,clubId}))}))};m.finance.notice='La saison couvre '+W.sizing(S).rounds+' semaines de gestion.';
  if(m.live)m.live.teams=m.live.pair.map(clubSummary);
  return m;
 };
};
