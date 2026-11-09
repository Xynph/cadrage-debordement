'use strict';
module.exports=function worldModel(base,publishedVenue){
 const W=CDWorldCareer,copy=x=>JSON.parse(JSON.stringify(x));
 const catalogues=new WeakMap();
 const positions=['Piliers','Talonneurs','Deuxièmes lignes','Troisièmes lignes','Demis de mêlée','Demis d’ouverture','Ailiers','Centres','Arrières'];
 function startingRoster(players,profiles){
  const byPosition=positions.map(name=>({name,count:0,points:0}));
  let forwards=0,backs=0,points=0;
  for(const player of players){
   const position=profiles?.players[player.id]?.position.primary??player.pos;
   const family=FAMILIES[POS.indexOf(position)];
   if(family<4)forwards++;else backs++;
   points+=player.rating;
   const group=byPosition[family];
   if(group){group.count++;group.points+=player.rating;}
  }
  const ordered=byPosition.filter(row=>row.count).sort((a,b)=>b.points/b.count-a.points/a.count);
  const strongest=ordered[0],weakest=ordered.length>1?ordered.at(-1):null;
  const detail=group=>group?{count:group.count,average:Math.round(group.points/group.count*10)/10}:null;
  return {
   average:players.length?Math.round(points/players.length*10)/10:null,forwards,backs,
   strengths:strongest?.name??'',strengthDetail:detail(strongest),
   needs:weakest?.name??'',weaknessDetail:detail(weakest),
  };
 }
 function catalogue(R){
  if(!catalogues.has(R)){
   const profiles=CDRosterFoundation.resolve(CDRosterFoundation.marker);
   catalogues.set(R,R.clubs.map(({players,...c})=>({...c,division:c.leagueId,playable:c.leagueId!=='guest',startingRoster:startingRoster(players,profiles)})));
  }
  return catalogues.get(R);
 }
 const database=R=>({id:R.id,version:R.version,snapshot:R.snapshot,playerCount:R.playerCount,clubCount:R.clubCount});
 return function project(){
  const m=base(),old=CDWorldEditions.forMode('world').registry,pacific=CDWorldEditions.forMode('world-pacific')?.registry,japan=CDWorldEditions.forMode('world-japan')?.registry,nationale=CDWorldEditions.forMode('world-nationale')?.registry,champ=CDWorldEditions.forMode('world-champ')?.registry;
  m.meta.legacyCatalogue=m.meta.catalogue;m.meta.legacyDatabase=m.meta.database;m.meta.worldDatabase=database(old);
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
  m.club=clubSummary(S.club);m.league=tables[W.leagueId(S)].map(tableRow);
  if(edition.version>=2)m.meta.edition=edition.mode;
  if(edition.version>=3){m.meta.competitionRules+=' · Japon D1/D2 '+years.join('–');m.japanPromotion=copy(S.worldMode.japan);CDWorldJapanQuota.project(S,m);}
  m.leagues=edition.leagueIds.map(id=>{const l=S.worldMode.leagues[id];return{id,name:R.leagues.find(x=>x.id===id).name,phase:l.phase,champion:l.champion===null?null:clubSummary(l.champion),finalist:l.finalist===null?null:clubSummary(l.finalist),rows:tables[id].map(tableRow)};});
  for(const [id,cup]of Object.entries(S.worldMode.europe)){const pools=W.cupTables(S,id).map((rows,i)=>({id:i,label:'Poule '+(i+1),rows:rows.map(r=>({...tableRow({...r,id:r.clubId,form:r.form.map(x=>({W:'V',L:'D',D:'N'})[x])}),rank:r.rank,poolId:i}))}));m.leagues.push({id,name:id==='champions'?'Coupe des champions':'Challenge européen',phase:cup.phase,champion:cup.champion===null?null:clubSummary(cup.champion),finalist:cup.finalist===null?null:clubSummary(cup.finalist),pools,rows:pools.flatMap(p=>p.rows),seeds:cup.seeds||[],transfers:cup.transfers||[]});}
  const venue=f=>publishedVenue(f,S.season)??(f.venuePolicy==='centralised-super-round'?'Super Round · terrain commun':f.venueRegion==='Europe'?'Terrain désigné en Europe':f.venueDesignationPending||f.neutral?'Terrain désigné':S.clubs[f.homeId].stadium);
  m.calendar=S.worldMode.fixtures.filter(f=>f.homeId===S.club||f.awayId===S.club).map(f=>{const r=S.history.find(r=>r.fixtureId===f.id);return{id:f.id,label:(R.leagues.find(l=>l.id===f.competitionId)?.name||names[f.competitionId]||f.competitionId)+' · '+(f.phase==='league'||f.phase==='pool'?'J'+(f.round+1):f.phase==='promotion'?'Manche '+f.leg:phaseLabels[f.phase]||(f.competitionId==='champ'?champPhases[f.phase]:null)||f.phase),week:f.week,date:f.date,home:clubSummary(f.homeId),away:clubSummary(f.awayId),score:r?.score||null,played:!!r,phase:f.phase,leagueId:f.competitionId,competitionId:f.competitionId,neutral:f.neutral,competitionRound:f.round,venue:venue(f),winner:r?.winner??null,...dateProof(f)};}).sort((a,b)=>a.date.localeCompare(b.date)||a.id.localeCompare(b.id));
  const f=W.userFixture(S);m.next=f?{pair:[f.homeId,f.awayId],home:clubSummary(f.homeId),away:clubSummary(f.awayId),label:W.label(S),round:f.round,week:S.round,date:f.date,neutral:f.neutral,phase:f.phase,leagueId:f.competitionId,competitionId:f.competitionId,venue:venue(f),...dateProof(f)}:null;
  if(edition.version>=2&&m.meta.leagueId==='srp'&&!m.next){const upcoming=m.calendar.find(x=>!x.played&&x.week>S.round);if(upcoming)m.meta.pacificPreparation={nextWeek:upcoming.week,nextDate:upcoming.date,weeksUntil:upcoming.week-S.round};}
  if(edition.version>=3&&['jlo-d1','jlo-d2'].includes(m.meta.leagueId)&&!m.next){const upcoming=m.calendar.find(x=>!x.played&&x.week>S.round);if(upcoming)m.meta.japanPreparation={nextWeek:upcoming.week,nextDate:upcoming.date,weeksUntil:upcoming.week-S.round};}
  if(edition.version>=4){m.meta.competitionRules+=' · Division fédérale';m.nationalePromotion=copy(S.worldMode.nationale);const cards=f?CDWorldNationaleCards.project(S,{...f,season:years[0]},[...S.lineup,...S.reserves]):null;if(cards)m.selection.nationaleQualification=cards;}
  if(edition.version===5){
   m.meta.competitionRules+=' · Accession anglaise';m.champBoundary=copy(S.worldMode.champ);
   if(m.meta.leagueId==='champ'&&!m.next){const upcoming=m.calendar.find(x=>!x.played&&x.week>S.round);if(upcoming)m.meta.champPreparation={nextWeek:upcoming.week,nextDate:upcoming.date,weeksUntil:upcoming.week-S.round};}
  }
  m.archives={limit:15,seasons:S.worldMode.yearbook.map(y=>({...copy(y),champions:Object.entries(y.champions).map(([leagueId,clubId])=>({leagueId,clubId}))}))};m.finance.notice='La saison couvre '+W.sizing(S).rounds+' semaines de gestion.';
  if(m.live)m.live.teams=m.live.pair.map(clubSummary);
  return m;
 };
};
