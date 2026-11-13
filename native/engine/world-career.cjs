'use strict';
// Factory executed in the same VM as the rugby engine. Presentation packs never
// alter its identities, membership, ratings, calendar or results.
module.exports=function worldCareer(edition,active,initialContracts=null,lnrCalendar=null,seniorCalibration=null){
 const C=CDWorldCompetitions,REG=edition.registry,LEGACY=REG.compatibilityAliases||{},SOURCES=new Map([...REG.clubs.flatMap(c=>c.players.map(p=>[p.id,p])),...Object.entries(LEGACY).map(([id,row])=>[id,row.player])]),IDS=edition.leagueIds,WEEKS=46;
 const opening=edition.version===5&&edition.mode==='world-champ'&&initialContracts?.databaseId===REG.id&&initialContracts?.schema==='world-initial-contracts-v1'?initialContracts:null;
 const startingTerms=opening?.players;
 const EUROPE_LEAGUES=['elite','prem','urc'],playable=new Set(edition.playable),SRP=IDS.includes("srp")?CDWorldSRP:null,JP=IDS.includes('jlo-d1')?CDWorldJapan:null,N=IDS.includes('nationale')?CDWorldNationale:null,CH=IDS.includes('champ')?CDWorldChamp:null;
 const srpSeason=s=>2027+s.season-1;
 const japanYear=s=>2026+s.season-1,japanAnchor=s=>new Date(referenceStart(s)).toISOString().slice(0,10);
 const nationaleOptions=s=>({season:japanYear(s),anchor:new Date(seasonStart(s)).toISOString().slice(0,10),weeks:WEEKS,seasonModel:N.FROZEN_MODEL});
 const nationallyMutable=id=>!!N&&id===N.LEAGUE;
 const champLeague=id=>!!CH&&id===CH.LEAGUE;
 const champOptions=s=>({season:japanYear(s),anchor:new Date(seasonStart(s)).toISOString().slice(0,10),weeks:WEEKS,seasonModel:CH.FROZEN_MODEL});
 const champBoundary=()=>({national1:'closed-game-boundary',premExchange:false});
 const japanLeague=id=>!!JP&&JP.leagues.includes(id);
 const japanPromotion=id=>!!JP&&id===JP.promotionId;
 const srpOptions={policy:SRP?.referencePolicy,futurePolicy:SRP?.futurePolicy};
 const copy=x=>JSON.parse(JSON.stringify(x)),eq=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
 const check=(yes,message)=>{if(!yes)throw Error('Monde international : '+message);};
 const leagueId=(s,id=s.club)=>IDS.find(k=>s.worldMode.leagues[k].members.includes(id))||'guest';
 const sizing=()=>({clubCount:REG.clubs.length,maxRound:WEEKS,rounds:WEEKS});
 const referenceStart=s=>{const t=Date.UTC(2026+s.season-1,7,31),d=new Date(t).getUTCDay();return t-((d+6)%7)*86400000;};
 const lnrPolicy='lnr-2026-27-v1';
 const lnrOpening=s=>s.worldMode?.calendarPolicy===lnrPolicy;
 const seasonStart=s=>referenceStart(s)-(N||lnrOpening(s)?2*604800000:0);
 const calendarToday=s=>new Date(seasonStart(s)+(s.round*7+(s.worldMode.day??0))*86400000).toISOString().slice(0,10);
 const nextOpening=s=>new Date(seasonStart({season:s.season+1})).toISOString().slice(0,10);
 const day=(s,week)=>new Date(referenceStart(s)+week*604800000+5*86400000).toISOString().slice(0,10);
 const weekOf=(s,date)=>Math.floor((Date.parse(date)-seasonStart(s))/604800000);
 const fixtureOrder=(a,b)=>a.week-b.week||a.date.localeCompare(b.date)||a.id.localeCompare(b.id);
 const fixtureShape=(s,f)=>({...copy(f),season:s.season,fixtureId:f.id,week:weekOf(s,f.date),neutral:!!f.neutral});
 const fixtures=s=>s.worldMode.fixtures.filter(f=>f.week===s.round);
 const userFixture=s=>fixtures(s).find(f=>f.homeId===s.club||f.awayId===s.club)||null;
 const hasClubRole=s=>s.national?.role?.club!==false;
 const callups=s=>s.national?.career?.callups??[];
 const during=(call,date)=>call.from<=date&&date<=call.through;
 const releasedIds=(s,date)=>new Set(callups(s).filter(call=>during(call,date)).flatMap(call=>call.playerIds));
 function clubReleaseOn(s,id,date=userFixture(s)?.date){
  return date ? callups(s).find(call=>during(call,date)&&call.playerIds.includes(id))??null : null;
 }
 function matchRoster(s,team){
  if(!callups(s).length)return team;
  const fixture=fixtures(s).find(f=>f.homeId===team.id||f.awayId===team.id);
  if(!fixture)return team;
  const released=releasedIds(s,fixture.date);
  if(!released.size)return team;
  const players=team.players.filter(p=>!released.has(p.id));
  return players.length===team.players.length?team:{...team,players};
 }
 function enableDaily(s){
  if(!active(s)||s.worldMode.day!==undefined)return;
  const fixture=s.live?userFixture(s):null;
  s.worldMode.day=fixture?Math.floor((Date.parse(fixture.date)-seasonStart(s))/86400000)%7:0;
 }
 function dailyStatus(s){
  const {day,resultConfirmed}=s.worldMode;
  if(day===undefined)return null;
  const matchReady=hasClubRole(s)&&!resultConfirmed&&userFixture(s)?.date===calendarToday(s);
  return {day,matchReady,canAdvance:s.phase!=='ended'&&(!s.live||resultConfirmed===true)&&!matchReady,...(resultConfirmed?{resultConfirmed:true}:{})};
 }
 function advanceDay(s,fromDate){
  const status=dailyStatus(s);
  if(!status||s.phase==='ended')throw Error('Avance journalière indisponible.');
  if(fromDate!==calendarToday(s))throw Error('La date de carrière a changé.');
  if(!status.canAdvance)throw Error(s.live?'Terminez et validez le résultat avant de continuer.':'Jouez la rencontre prévue aujourd’hui avant de continuer.');
  if(status.day===6){
   finishWeek();
   return true;
  }
  s.worldMode.day++;
  return false;
 }
 const previousRanksFor=(standings,partition)=>Object.fromEntries(IDS.flatMap(id=>standings[id].map((cid,i)=>[cid,i+1]).filter(([cid])=>partition[id].includes(cid))));
 const asResult=r=>({...r,season:(r.competitionId==='srp'?2027:2026)+r.season-1,round:r.competitionRound??r.round,afterExtraTime:r.decision?.extraTime===true,penalties:r.stats?.map(x=>x.goals),drops:r.stats?.map(x=>x.drops||0),redCards:r.decision?.redCards});
 // Retrait de points JIFF (règlement LNR) : Top 14 et Pro D2, saison suivant le manquement.
 const jiffDeductions=(s,id,season)=>(id==='elite'||id==='accession')&&typeof CDJiff!=='undefined'&&CDJiff&&typeof CDJiff.deductionsFor==='function'?{deductions:CDJiff.deductionsFor(s,season)}:{};
 function rows(s,id,season=s.season){if(id==='guest')return edition.guests.map(clubId=>({clubId,points:0,played:0,won:0,drawn:0,lost:0,pf:0,pa:0,bonus:0,form:[]}));const ids=s.worldMode.leagues[id]?.members;if(!ids)return[];const options={season:(id==='srp'?2027:2026)+season-1,phase:'league',tieBreaks:{previousRank:s.worldMode.previousRanks||{},drawOrder:s.worldMode.draws?.['league:'+id]?.ranks},...jiffDeductions(s,id,season)};
 return (champLeague(id)?CH.table(ids,s.history.filter(r=>r.season===season),{fixtures:s.worldMode.fixtures.filter(f=>f.competitionId===id&&f.phase==='league'),tieBreaks:options.tieBreaks}):nationallyMutable(id)?N.table(ids,s.history.filter(r=>r.season===season),{fixtures:s.worldMode.fixtures.filter(f=>f.competitionId===id&&f.phase==='league'),tieBreaks:{drawOrder:s.worldMode.draws?.['league:'+id]?.ranks,previousRank:s.worldMode.previousRanks}}):japanLeague(id)?JP.table({id,members:ids,fixtures:s.worldMode.fixtures,results:s.history,season,drawOrder:s.worldMode.draws?.['league:'+id]?.order}):id==='srp'?SRP.table(ids,s.history.map(asResult),id,{...options,...srpOptions}):C.table(ids,s.history.map(asResult),id,options)).map(r=>({...r,form:r.form.map(x=>({W:'V',L:'D',D:'N'})[x])}));}
 const worldRanked=(s,id=leagueId(s))=>rows(s,id).map(r=>({...s.clubs[r.clubId],...r,id:r.clubId}));
 function worldLabel(s){if(s.phase==='ended')return'Saison terminée';const f=userFixture(s);return f?`${REG.leagues.find(l=>l.id===f.competitionId)?.name||({champions:'Coupe des champions',challenge:'Challenge européen',access:'Barrage d’accession','jlo-d1-d2':'Barrage Japon D1 / D2','access-nationale':'Barrage Pro D2 / Nationale'})[f.competitionId]||f.competitionId} · ${f.phase==='league'||f.phase==='pool'?'Journée '+(f.round+1):({barrage:'Barrages',elimination:'Match de barrage',quarter:'Quarts de finale',semi:'Demi-finales',final:'Finale',r16:'Huitièmes de finale',access:'Barrage d’accession','third-place':'Petite finale',promotion:'Manche '+(f.round+1)})[f.phase]||f.phase}`:'Semaine '+(s.round+1)+' · Préparation';}
 function installFixture(s,f){
  const item=fixtureShape(s,f);
  check(Number.isInteger(item.week)&&item.week>=0&&item.week<WEEKS,'date hors saison.');
  check(!s.worldMode.fixtures.some(x=>x.id===item.id),'identifiant de rencontre répété.');
  check(!s.worldMode.fixtures.some(x=>x.week===item.week&&[x.homeId,x.awayId].some(id=>id===item.homeId||id===item.awayId)),'deux rencontres du même club dans une semaine.');
  s.worldMode.fixtures.push(item);return item;
 }
 function sync(s){
  s.round=s.worldMode.week;s.phase=s.round===WEEKS?'ended':'league';s.playoff=null;
  s.worldMode.fixtures.sort(fixtureOrder);
  s.schedule=Array.from({length:WEEKS},(_,week)=>s.worldMode.fixtures.filter(f=>f.week===week).map(f=>[f.homeId,f.awayId]));
  for(const id of IDS)for(const r of rows(s,id)){const c=s.clubs[r.clubId];for(const k of ['points','played','won','drawn','lost','pf','pa','bonus','form'])c[k]=copy(r[k]);}
 }
 function newSeason(s,initial=false,dailyCalendar=false){
  const old=s.worldMode,previous=initial?null:old,partition=initial?Object.fromEntries(IDS.map(id=>[id,REG.clubs.filter(c=>c.leagueId===id).map(c=>c.id)])):Object.fromEntries(IDS.map(id=>[id,(previous.nationale?.movement?.[id]||previous.movement?.[id]||previous.japan?.movement?.[id]||previous.leagues[id].members).slice()]));
  const previousTables=initial?{}:Object.fromEntries(IDS.map(id=>[id,rows(s,id,s.season-1)]));
  const priorChallengeDraw=previous?.qualification?.challengeDrawPolicy?{policy:previous.qualification.challengeDrawPolicy,startSeason:previous.qualification.challengeDrawStartSeason,order:previous.qualification.drawOrders.challenge}:null;
  const yearbook=initial?[]:previous.yearbook.concat({season:s.season-1,...(priorChallengeDraw?{challengeDraw:copy(priorChallengeDraw)}:{}),standings:Object.fromEntries(IDS.map(id=>[id,previousTables[id].map(c=>c.clubId)])),champions:Object.fromEntries(IDS.map(id=>[id,previous.leagues[id].champion])),finalists:Object.fromEntries(IDS.map(id=>[id,previous.leagues[id].finalist])),movement:copy(previous.movement),europe:copy(previous.europe||{}),draws:copy(previous.draws),...(JP?{japan:{...copy(previous.japan),members:Object.fromEntries(JP.leagues.map(id=>[id,previous.leagues[id].members.slice()]))}}:{}),...(N?{nationale:{...copy(previous.nationale),members:frenchMembers(previous)}}:{}),...(CH?{champ:champBoundary()}: {})}).slice(-15);
  const annual=initial?null:annualEurope(s,previous,partition,previousTables);
  s.worldMode={version:edition.version,catalogue:REG.id,rules:edition.rules,startYear:2026,week:0,leagues:Object.fromEntries(IDS.map(id=>[id,{members:partition[id],phase:'league',champion:null,finalist:null}])),fixtures:[],yearbook,movement:null,europe:{},draws:{},previousRanks:initial?{}:previousRanksFor(yearbook.at(-1).standings,partition),qualification:annual?.qualification||null,...(JP?{japan:null}:{}),...(N?{nationale:null}:{}),...(CH?{champ:champBoundary()}: {})};
  if(dailyCalendar||old?.day!==undefined)s.worldMode.day=0;
  if(initial&&dailyCalendar)s.worldMode.calendarPolicy=lnrPolicy;
  const pools=initial?REG.initialEurope:annual.pools;
  for(const id of ['champions','challenge'])s.worldMode.europe[id]={pools:copy(pools[id]),phase:'pool',champion:null,finalist:null};
  for(const f of baseFixtures(s,partition,pools))installFixture(s,f);
  sync(s);
 }
 const lnrRegular=Object.fromEntries(Object.entries(lnrCalendar?.fixtures??{}).map(([competitionId,fixtures])=>{
  const perRound=C.rules(competitionId).clubs/2;
  return [competitionId,fixtures.map(([homeId,awayId,windowStart,windowEnd,date,kickoffLocal,sourceFixtureId,sourceRef],index)=>{
   const round=Math.floor(index/perRound),slot=index%perRound,published=sourceFixtureId!==undefined;
   const dateWindow=date<windowStart||date>windowEnd?[date,date]:[windowStart,windowEnd];
   return {id:competitionId+':2026:league:'+round+':'+slot,competitionId,season:2026,round,date,homeId,awayId,phase:'league',
    scheduleSource:published?'lnr-published-fixture':'lnr-published-pairing',sourceRef:sourceRef??lnrCalendar.regularSources[competitionId],
    ...(published?{sourceFixtureId}:{}),dateStatus:published?'published':'simulation-in-published-window',dateWindow,
    kickoffLocal,kickoffSource:published?'published':'simulated-not-official',timezone:'Europe/Paris'};
  })];
 }));
 const baseCache=new Map();
 function baseFixtures(s,partition,pools,legacyCalendar=false){
  const key=JSON.stringify([s.season,lnrOpening(s),partition,pools,legacyCalendar]);if(baseCache.has(key))return baseCache.get(key);
  const season=2026+s.season-1,excludedWeeks=C.europeanWeeks({season}),clubs=currentClubs(s,partition),fixtures=[];
  for(const competitionId of IDS){
   const participants=partition[competitionId].map(id=>clubs[id]);
   const rounds=competitionId==='srp'
    ?SRP.calendarFixtures({clubs:participants,season:srpSeason(s),...srpOptions})
    :champLeague(competitionId)?CH.calendarFixtures({clubs:partition[competitionId],...champOptions(s)}):nationallyMutable(competitionId)?N.calendarFixtures({clubs:partition[competitionId],...nationaleOptions(s)}):japanLeague(competitionId)?JP.regular({id:competitionId,members:partition[competitionId],year:japanYear(s),anchor:japanAnchor(s)}):C.regularFixtures({clubs:participants,competitionId,season,startDate:day(s,0),excludedWeeks,legacyCalendar,initialFixtures:s.season===1?((lnrOpening(s)?lnrRegular[competitionId]:undefined)??REG.initialFixtures?.[competitionId]):undefined});
   fixtures.push(...rounds);
  }
  for(const competitionId of ['champions','challenge']){
   const groups=pools[competitionId];fixtures.push(...C.poolStage({clubs:groups.flat().map(id=>clubs[id]),pools:groups,competitionId,season,initialFixtures:s.season===1?REG.initialFixtures?.[competitionId]:undefined}).map(f=>({...f,phase:'pool'})));
  }
  if(baseCache.size>=4)baseCache.delete(baseCache.keys().next().value);baseCache.set(key,fixtures);return fixtures;
 }
 function shuffled(ids){const out=ids.slice();for(let i=out.length-1;i>0;i--){const j=rand(0,i);[out[i],out[j]]=[out[j],out[i]];}return out;}
 function draw(s,key,ids,allowDraw=true){const prior=s.worldMode.draws[key];if(prior){check(eq(prior.clubIds,ids),'participants du tirage modifiés.');return prior.ranks;}check(allowDraw,'tirage requis absent.');const order=shuffled(ids),item={clubIds:ids.slice(),order,ranks:Object.fromEntries(order.map((id,i)=>[id,i+1]))};s.worldMode.draws[key]=item;return item.ranks;}
 function currentClubs(s,partition=null){return REG.clubs.map(c=>({...c,leagueId:IDS.find(id=>(partition?.[id]||s.worldMode.leagues[id].members).includes(c.id))||'guest'}));}
 function annualEurope(s,previous,partition,tables,storedOrders=null,challengeDrawPolicy=storedOrders?null:C.CHALLENGE_DRAW_POLICY,challengeDrawStartSeason=storedOrders?null:(previous.qualification?.challengeDrawStartSeason??s.season)){
  const clubs=currentClubs(s,partition).filter(c=>['elite','accession','prem','urc','guest'].includes(c.leagueId)),eligible=partition.elite;
  const elite=tables.elite.filter(r=>eligible.includes(r.clubId)).concat(tables.accession.filter(r=>eligible.includes(r.clubId)));
  // This closed world takes an explicit organiser decision each year. It does
  // not present next year's invitations as a newly verified real-world fact.
  const invitations=REG.clubs.filter(c=>c.leagueId==='guest').map(c=>c.id);
  const qualification=C.qualifyEurope({tables:{elite,prem:tables.prem,urc:tables.urc},clubs,titles:{champions:previous.europe.champions.champion,challenge:previous.europe.challenge.champion,urc:previous.leagues.urc.champion,prem:previous.leagues.prem.champion,premFinalist:previous.leagues.prem.finalist},season:2026+s.season-1,invitations});
  qualification.organiserRulings=qualification.unresolved.map(x=>({...x,policy:'closed-world-quota-and-invitations-maintained'}));
  qualification.invitationPolicy='closed-world-annual-organiser-decision';
  if(challengeDrawPolicy!==null){qualification.challengeDrawPolicy=challengeDrawPolicy;qualification.challengeDrawStartSeason=challengeDrawStartSeason;qualification.provenance.challengeDraw={status:'game-model'};}
  const pools={},orders={};
  for(const competitionId of ['champions','challenge']){const participants=qualification[competitionId],order=storedOrders?storedOrders[competitionId]:shuffled(participants);check(Array.isArray(order),'ordre de tirage annuel absent.');orders[competitionId]=order;const protectedIds=competitionId==='champions'?[...new Set([...EUROPE_LEAGUES.map(id=>previous.leagues[id].champion),previous.europe.champions.champion])].filter(id=>participants.includes(id)):[];if(competitionId==='champions'&&protectedIds.length<4&&participants.includes(previous.europe.champions.finalist)&&!protectedIds.includes(previous.europe.champions.finalist))protectedIds.push(previous.europe.champions.finalist);pools[competitionId]=C.drawPools({clubs,competitionId,participants,protectedIds,order,...(competitionId==='challenge'?{challengeDrawPolicy}:{})});}
  qualification.drawOrders=orders;return{qualification,pools};
 }
 function validateArchivedChallenge(s,y,participants,startSeason){
  const proof=y.challengeDraw,required=startSeason!==null&&y.season>=startSeason;
  check((proof!==undefined)===required,'preuve archivée incompatible avec l’ère du tirage Challenge.');
  if(!required)return;
  check(CDWorldValidation.keys(proof,['policy','startSeason','order'])&&proof.policy===C.CHALLENGE_DRAW_POLICY&&proof.startSeason===startSeason,'tirage Challenge archivé invalide.');
  const expected=C.drawPools({competitionId:'challenge',clubs:currentClubs(s,y.standings),participants,order:proof.order,challengeDrawPolicy:proof.policy});
  check(eq(expected,y.europe.challenge.pools),'tirage Challenge archivé modifié.');
 }
 function cupTables(s,id){const cup=s.worldMode.europe[id];return cup.pools.map((ids,poolId)=>C.table(ids,s.history.map(asResult),id,{season:2026+s.season-1,phase:'pool',poolId,tieBreaks:{drawOrder:s.worldMode.draws['pool:'+id]?.ranks}}));}
 function appendKnockouts(s,id,state,phases){
  if(!state.seeds)return;
  const results=s.history.map(asResult);
  const windows=lnrOpening(s)?lnrCalendar.playoffs[id]:null;
  // Use one calendar date per phase. Only the TOP 14 final has an exact published date.
  const dates=windows?Object.fromEntries(Object.entries(windows).map(([phase,window])=>[phase,window[0]])):
   s.season===1?REG.initialKnockoutDates?.[id]:undefined;
  for(const phase of phases){
   const generated=id==='srp'?SRP.knockoutFixtures({competitionId:id,season:srpSeason(s),seeds:state.seeds,phase,results,...srpOptions}):
    C.knockoutFixtures({competitionId:id,season:2026+s.season-1,seeds:state.seeds,phase,results,dates});
   for(const f of generated){
    if(s.worldMode.fixtures.some(x=>x.id===f.id))continue;
    const window=windows?.[phase];
    installFixture(s,window?{...f,scheduleSource:'lnr-published-phase-window',dateWindow:window,
     dateStatus:window[0]===window[1]?'published':'simulation-in-published-window'}:f);
   }
  }
  const final=s.history.find(r=>r.competitionId===id&&r.phase===phases.at(-1));
  if(final){state.champion=final.winner;state.finalist=final.pair.find(id=>id!==final.winner);state.phase='ended';}
  else state.phase=phases.find(phase=>s.worldMode.fixtures.some(f=>f.competitionId===id&&f.phase===phase&&!s.history.some(r=>r.fixtureId===f.id)))||phases[0];
 }
 function appendJapan(s,allowDraw){
  const w=s.worldMode,[one,two]=JP.leagues;
  const complete=id=>w.fixtures.filter(f=>f.competitionId===id&&f.phase==='league').every(f=>s.history.some(r=>r.fixtureId===f.id));
  for(const id of JP.leagues){
   const l=w.leagues[id];
   if(!l.seeds&&complete(id)){
    draw(s,'league:'+id,l.members,allowDraw);
    const ranked=rows(s,id);
    l.seeds=id===one?JP.playoffSeeds(ranked):ranked.slice(0,2).map(r=>r.clubId);
    if(id===two){[l.champion,l.finalist]=l.seeds;l.phase='ended';}
   }
  }
  const l=w.leagues[one],year=japanYear(s),anchor=japanAnchor(s);
  if(l.seeds){
   for(const phase of JP.phases)for(const f of JP.knockout({year,anchor,seeds:l.seeds,phase,results:s.history})){
    if(!w.fixtures.some(item=>item.id===f.id))installFixture(s,f);
   }
   const final=s.history.find(r=>r.competitionId===one&&r.phase==='final');
   const bronze=s.history.find(r=>r.competitionId===one&&r.phase==='third-place');
   if(final&&bronze){
    const ranking=JP.finalRanking(rows(s,one),s.history);
    l.champion=ranking[0].id;l.finalist=ranking[1].id;l.phase='ended';
   }else l.phase=JP.phases.find(phase=>w.fixtures.some(f=>f.competitionId===one&&f.phase===phase&&!s.history.some(r=>r.fixtureId===f.id)))||JP.phases[0];
  }
  if(l.seeds&&w.leagues[two].seeds){
   const p=JP.promotion({d1:rows(s,one),d2:rows(s,two),year,anchor});
   for(const f of p.fixtures)if(!w.fixtures.some(item=>item.id===f.id))installFixture(s,f);
   const legs=p.fixtures.flatMap(f=>{
    const r=s.history.find(r=>r.fixtureId===f.id);return r?[{fixtureId:r.fixtureId,pair:r.pair.slice(),score:r.score.slice(),tries:r.tries.slice(),conversions:r.stats.map(x=>x.conversions)}]:[];
   });
   const outcomes=p.pairs.map(pair=>JP.promotionDecision(pair,legs));
   w.japan={pairs:p.pairs,legs,outcomes,movement:outcomes.every(Boolean)?JP.move(Object.fromEntries(JP.leagues.map(id=>[id,w.leagues[id].members])),p.pairs,outcomes):null};
  }
 }
 const frenchIds=['elite','accession','nationale'];
 const frenchMembers=w=>Object.fromEntries(frenchIds.map(id=>[id,w.leagues[id].members.slice()]));
 const nationaleResult=r=>typeof CDWorldNationaleMatch==='undefined'?r:CDWorldNationaleMatch.asRuleResult(r);
 const lowerInputs=(s,nationaleFinal,result=null)=>({nationaleFinal,approval:{[nationaleFinal.champion]:true,[nationaleFinal.finalist]:true},
  result:result??undefined,resolveAccessTie:r=>r.winner,...nationaleOptions(s)});
 function appendNationale(s,allowDraw){
  const w=s.worldMode,l=w.leagues.nationale,results=s.history.map(nationaleResult),options=nationaleOptions(s);
  if(!l.seeds&&w.fixtures.filter(f=>f.competitionId===N.LEAGUE&&f.phase==='league').every(f=>s.history.some(r=>r.fixtureId===f.id))){
   draw(s,'league:'+N.LEAGUE,l.members,allowDraw);l.seeds=N.playoffSeeds(rows(s,N.LEAGUE));
  }
  if(!l.seeds)return;
  const phases=['barrage','semi','final'];
  for(const phase of phases)for(const f of N.knockoutFixtures({phase,seeds:l.seeds,results,...options})){
   if(!w.fixtures.some(current=>current.id===f.id))installFixture(s,f);
  }
  const final=N.finalOutcome({seeds:l.seeds,results,...options});
  if(!final){l.phase=phases.find(phase=>w.fixtures.some(f=>f.competitionId===N.LEAGUE&&f.phase===phase&&!s.history.some(r=>r.fixtureId===f.id)))||phases[0];return;}
  l.champion=final.champion;l.finalist=final.finalist;l.phase='ended';
  if(!w.leagues.accession.seeds)return;
  const proD2Rank=rows(s,'accession').map(r=>r.clubId),inputs=lowerInputs(s,final);
  const initial=N.accessPlan({...inputs,proD2Rank});
  if(initial.fixture&&!w.fixtures.some(f=>f.id===initial.fixture.id))installFixture(s,{...initial.fixture,date:initial.fixture.simulationDate});
  const witness=s.history.find(r=>r.fixtureId===initial.fixture?.id)||null;
  const lower=lowerInputs(s,final,witness),access=N.accessPlan({...lower,proD2Rank});
  const movement=w.movement&&access.status==='ready'?N.combineFrenchMovements({members:frenchMembers(w),ranks:{elite:rows(s,'elite').map(r=>r.clubId),accession:proD2Rank},topMovement:w.movement,lower}):null;
  w.nationale={access,witness:copy(witness),movement};
 }
 function appendChamp(s,allowDraw){
  const w=s.worldMode,l=w.leagues.champ,options=champOptions(s);
  if(!l.seeds){
   const completed=new Set(s.history.filter(r=>r.competitionId===CH.LEAGUE&&r.phase==='league').map(r=>r.fixtureId));
   if(!w.fixtures.filter(f=>f.competitionId===CH.LEAGUE&&f.phase==='league').every(f=>completed.has(f.id)))return;
   draw(s,'league:'+CH.LEAGUE,l.members,allowDraw);l.seeds=CH.playoffSeeds(rows(s,CH.LEAGUE));
  }
  const results=s.history.filter(r=>r.competitionId===CH.LEAGUE&&r.phase!=='league')
   .map(r=>CDWorldChampMatch.asRuleResult({...r,season:options.season}));
  const phases=['quarter','semi','final'];
  for(const phase of phases)for(const f of CH.knockoutFixtures({phase,seeds:l.seeds,results,...options})){
   if(!w.fixtures.some(current=>current.id===f.id))installFixture(s,f);
  }
  const final=CH.finalOutcome({seeds:l.seeds,results,...options});
  if(final){l.champion=final.champion;l.finalist=final.finalist;l.phase='ended';}
  else l.phase=phases.find(phase=>w.fixtures.some(f=>f.competitionId===CH.LEAGUE&&f.phase===phase&&!results.some(r=>r.fixtureId===f.id)))||phases[0];
 }
 function planStages(s,allowDraw=true){
  const w=s.worldMode;
  if(JP)appendJapan(s,allowDraw);
  for(const id of IDS.filter(id=>!japanLeague(id)&&!nationallyMutable(id)&&!champLeague(id))){const l=w.leagues[id],regular=w.fixtures.filter(f=>f.competitionId===id&&f.phase==='league');if(!l.seeds&&regular.every(f=>s.history.some(r=>r.fixtureId===f.id))){draw(s,'league:'+id,l.members,allowDraw);const ranked=rows(s,id);l.seeds=id==='srp'?SRP.playoffSeeds(ranked):ranked.slice(0,C.rules(id).playoffs).map(r=>r.clubId);}
   appendKnockouts(s,id,l,id==='srp'?SRP.phases:id==='urc'?['quarter','semi','final']:id==='prem'?['semi','final']:['barrage','semi','final']);
  }
  const poolsDone=['champions','challenge'].every(id=>w.fixtures.filter(f=>f.competitionId===id&&f.phase==='pool').every(f=>s.history.some(r=>r.fixtureId===f.id)));
  if(poolsDone&&!w.europe.champions.seeds){
   for(const id of ['champions','challenge'])draw(s,'pool:'+id,w.europe[id].pools.flat(),allowDraw);
   const cc=C.poolQualifiers({competitionId:'champions',tables:cupTables(s,'champions'),drawOrder:w.draws['pool:champions'].ranks});
   const challenge=C.poolQualifiers({competitionId:'challenge',tables:cupTables(s,'challenge'),transfers:cc.transfers,drawOrder:w.draws['pool:challenge'].ranks});
   check(cc.unresolved.length===0&&challenge.unresolved.length===0,'tirage européen incomplet.');
   w.europe.champions.seeds=cc.qualifiers.map(r=>r.clubId);w.europe.champions.transfers=cc.transfers.map(r=>r.clubId);w.europe.challenge.seeds=challenge.qualifiers.map(r=>r.clubId);
  }
  for(const id of ['champions','challenge'])appendKnockouts(s,id,w.europe[id],['r16','quarter','semi','final']);
  const elite=w.leagues.elite,accession=w.leagues.accession;
  if((lnrOpening(s)?!!elite.seeds:elite.champion!==null)&&accession.champion!==null&&!w.access){const atRisk=rows(s,'elite')[12].clubId;w.access={seeds:[atRisk,accession.finalist],champion:null,finalist:null,phase:'access'};}
  if(w.access){appendKnockouts(s,'access',w.access,['access']);if(w.access.champion!==null&&!w.movement){const relegated=[rows(s,'elite').at(-1).clubId],promoted=[accession.champion];if(w.access.champion===accession.finalist){relegated.push(w.access.seeds[0]);promoted.push(accession.finalist);}w.movement={promoted,relegated,elite:elite.members.filter(id=>!relegated.includes(id)).concat(promoted),accession:accession.members.filter(id=>!promoted.includes(id)).concat(relegated)};}}
  if(N)appendNationale(s,allowDraw);
  if(CH)appendChamp(s,allowDraw);
 }
 function sourcePlayer(source){
  const p=copy(source),profile=CDRosterFoundation.resolve(CDRosterFoundation.marker)?.players[p.id];
  if(profile){
   if(profile.position.basis==='official'){
    seniorCalibration?.alignStartingRole(p,profile.position.primary);
    p.gameplayPosition=profile.position.primary;
   }
   p.rosterProfile=copy(profile);p.pos=profile.position.primary;p.fam=FAMILIES[POS.indexOf(p.pos)];p.contractEnd=profile.contract.endSeason;
  }
  if(REG.worldProfiles[p.id])p.worldProfile=copy(REG.worldProfiles[p.id]);if(REG.nationaleQualifications?.[p.id])p.nationaleQualifications=REG.nationaleQualifications[p.id].roles.slice();return p;
 }
 function initialRoster(c){
  // The active catalogue is already deduplicated. Compatibility identities
  // are consulted only when reading an existing career, never for creation.
  return c.players.map(sourcePlayer);
 }
 // Capacité du stade (données factuelles par identifiant de club) ; absente : le module supporters retombe sur 12 000.
 const stadiumCapacity=id=>typeof CDWorldStadiumCapacities!=='undefined'&&Number.isInteger(CDWorldStadiumCapacities[id])?CDWorldStadiumCapacities[id]:undefined;
 function previewRoster(id){
  const players=initialRoster(REG.clubs[id]);
  players.push(...nativeProfessionalDepth.additions(id,players,1));
  if(seniorCalibration)seniorCalibration.apply(players,SOURCES);
  return players;
 }
 function start(id,dailyCalendar=false){
  check(playable.has(id),'club jouable invalide.');
  S={version:2,commonDatabase:copy(REG.marker),rosterFoundation:copy(CDRosterFoundation.marker),club:id,season:1,round:0,
   clubs:REG.clubs.map(c=>({id:c.id,name:c.name,abbr:c.abbr,color:c.color,base:c.base,cash:c.cashMillions*1e6,goal:c.goal||'Développer le projet sportif',stadium:c.stadium,stadiumCapacity:stadiumCapacity(c.id),points:0,played:0,won:0,drawn:0,lost:0,pf:0,pa:0,bonus:0,form:[],players:initialRoster(c)})),
   schedule:[],lineup:[],reserves:[],tactic:'equilibre',training:'normal',physicalLoadVersion:1,collectivePrepVersion:1,collectiveFocus:'aucune',developmentFocusVersion:1,recruitmentIntelVersion:1,salaryDemandVersion:1,satisfactionVersion:1,relationsVersion:1,objectivesVersion:1,v39Version:1,integratedManagementVersion:1,worldVersion:1,morale:75,trust:70,history:[],news:['Le vestiaire vous attend. À vous de donner le cap pour cette nouvelle saison.'],market:[],marketWeek:-1,phase:'league',playoff:null,live:null,lastReport:null,ledger:[],trained:false};
  if(startingTerms)for(const club of S.clubs){
   if(!['prem','urc','champ'].includes(REG.clubs[club.id].leagueId))continue;
   for(const player of club.players){
    const term=startingTerms[player.id];
    if(term?.clubId!==club.id||!Number.isInteger(term.endSeason)||term.endSeason<1||term.endSeason>6)continue;
    if(term.endType==='season-end')player.contractEnd=term.endSeason;
    if(term.endType==='minimum-season-end')player.contractEnd=Math.max(player.contractEnd,term.endSeason);
   }
  }
  newSeason(S,true,dailyCalendar);setupOpposition();setupEconomy();
  if(typeof nativeProfessionalDepth!=='undefined')nativeProfessionalDepth.fill(S);
  S.aiRoster.academyAgingVersion=1;
  setupDevelopment();
  if(seniorCalibration){
   for(const club of S.clubs)seniorCalibration.apply(club.players,SOURCES);
   S.seniorCalibrationVersion=seniorCalibration.version;
  }
  club().players.forEach(ensureSatisfaction);v39Initialize();autoLineup();if(sheetErrors().length)promoteCover();refreshMarket();setupManager();careerSetup();worldSetup();save();view='dashboard';entryScreen='game';
 }
 function context(pair){const f=fixtures(S).find(f=>f.homeId===pair[0]&&f.awayId===pair[1]);check(!!f,'rencontre hors calendrier.');return copy(f);}
 function createClubMatch(create,fixture,pair,legacy,automated,preparation){
  const coachClub=S.club,anchor=automated&&!hasClubRole(S)&&pair.includes(coachClub);
  const released=releasedIds(S,fixture.date);
  const filtered=pair.map(id=>S.clubs[id]).filter(team=>team.players.some(p=>released.has(p.id)));
  if(legacy||!anchor&&!filtered.length)return create(pair,legacy,automated,preparation);
  const rosters=filtered.map(team=>[team,team.players]);
  try{
   for(const [team,roster] of rosters)team.players=roster.filter(p=>!released.has(p.id));
   // Cover for the technical anchor must not create AI tracking data for the
   // career's club slot, which is still reserved by save validation.
   for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id],{allowAnchor:anchor});
   // The usual match initializer treats S.club as user-managed even in an
   // automated fixture. Keep the anchor out of that branch for team selection.
   if(anchor)S.club=S.clubs.find(team=>!pair.includes(team.id)).id;
   const match=create(pair,legacy,automated,preparation);
   for(const [side,sheet] of match.sheets.entries()){
    check(![...sheet.initial,...sheet.bench].some(id=>released.has(id)),'joueur convoqué sur une feuille de club.');
    if(side!==match.userSide)check([...sheet.initial,...sheet.bench].filter(Boolean).length===23,'feuille IA incomplète après les convocations.');
   }
   return match;
  }finally{
   S.club=coachClub;
   // Emergency AI promotions belong to the original club roster as usual.
   for(const [team,roster] of rosters){
    const prior=new Set(roster.map(p=>p.id));
    const additions=team.players.filter(p=>!prior.has(p.id));
    team.players=additions.length ? roster.concat(additions) : roster;
   }
  }
 }
 function result(l){return{pair:l.pair.slice(),score:l.score.slice(),tries:l.tries.slice(),stats:copy(l.stats),weather:l.weather,duration:l.minute,...(l.winner!==undefined?{winner:l.winner,decision:copy(l.decision)}:{}),...(l.worldContext?.competitionId==='srp'?CDWorldSRPMatch.historyFields(l):JP&&CDWorldJapanMatch.isFixture(l.worldContext)?CDWorldJapanMatch.historyFields(l):CH&&CDWorldChampMatch.isFixture(l.worldContext)?CDWorldChampMatch.historyFields(l):N&&typeof CDWorldNationaleMatch!=='undefined'?CDWorldNationaleMatch.historyFields(l):{})};}
 function simulate(f){if(typeof CDLeagueDetail!=='undefined'&&CDLeagueDetail.quickFixture(S,f))return CDLeagueDetail.simulate(S,f);const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);const l=createRugbyMatch(pair,null,true);for(let n=0;!l.finished;n++){check(n<=600,'limite de simulation atteinte.');l.paused=false;advanceRugby(l);}applyMatchInjuries(l);return result(l);}
 function finishWeek(){
  check(active(S)&&S.round<WEEKS&&!(S.live&&!S.live.finished),'semaine indisponible.');
  trainWeek();captureReport();const results=[],ownFixture=userFixture(S);
  for(const f of fixtures(S)){
   check(!S.history.some(r=>r.fixtureId===f.id),'rencontre déjà enregistrée.');
   const r=S.live&&[f.homeId,f.awayId].includes(S.club)?result(S.live):simulate(f);
   const entry={...r,fixtureId:f.id,competitionId:f.competitionId,leagueId:f.competitionId,season:S.season,round:S.round,competitionRound:f.round,week:S.round,date:f.date,phase:f.phase,poolId:f.poolId??null,neutral:f.neutral};
   S.history.push(entry);updateOppositionMorale(entry);worldRecordResult(entry);results.push(entry);
  }
  const own=results.find(r=>r.pair.includes(S.club)),won=CDFranceCareer.recordOwnOutcome(own);
  financeWeek(ownFixture&&!ownFixture.neutral?[ownFixture.homeId,ownFixture.awayId]:null,won);worldWeeklyEconomy(results);careerBoardWeekReview();recordSatisfactionRound(S.live);recordIndividualObjectivesRound(S.live);
  S.live=null;S.trained=false;S.worldMode.week++;
  if(S.worldMode.day!==undefined){
   S.worldMode.day=0;
   delete S.worldMode.resultConfirmed;
  }
  planStages(S);sync(S);
  if(S.phase==='ended'){check(S.worldMode.movement&&(!JP||S.worldMode.japan?.movement)&&(!N||S.worldMode.nationale?.movement?.status==='ready')&&IDS.every(id=>S.worldMode.leagues[id].champion!==null)&&['champions','challenge'].every(id=>S.worldMode.europe[id].champion!==null),'saison terminée sans titres et mouvements.');const titleLeague=edition.version>=2?leagueId(S):'elite';S.ending=S.clubs[S.worldMode.leagues[titleLeague].champion].name+' remporte '+(edition.version>=2?REG.leagues.find(l=>l.id===titleLeague).name:'le championnat')+'. La prochaine campagne se prépare déjà.';S.worldManagement.champion=S.worldMode.leagues.elite.champion;for(const id of IDS)careerRecord('trophy',REG.leagues.find(l=>l.id===id).name,S.worldMode.leagues[id].champion,'world-'+id);news(S.ending);}
  refreshMarket();repairSheet();save();view='dashboard';
 }
 function advance(){
  check(active(S)&&S.phase==='ended'&&!S.live,'terminez la saison avant l’intersaison.');
  worldEndSeason();careerSeasonEnd();closeIndividualObjectivesSeason();rollDevelopmentYear();worldPrepareRenewalLiquidity();settleContracts();
  // Build next year's entrants before clearing the results they are based on.
  S.season++;newSeason(S);S.history=[];S.lastReport=null;S.ending=null;S.trained=false;
  for(const c of S.clubs){c.points=c.played=c.won=c.drawn=c.lost=c.pf=c.pa=c.bonus=0;c.form=[];c.morale=75;for(const p of c.players){p.condition=100;p.injury=0;p.managerLoad={minutes:0,streak:0};if(p.physicalLoad)p.physicalLoad.fatigue=0;}}
  ledgerEntry('Financement de début de saison',2500000);worldNewSeason(true);S.morale=75;beginDevelopmentSeason();resetSatisfactionSeason();v39SeasonReset();careerSeasonStart();autoLineup();if(sheetErrors().length)promoteCover();refreshMarket();managerMobilityOnSeasonStart();trimHistories(S);news('Une nouvelle saison commence. Le prochain objectif est devant nous.');save();
 }
 // Fiches de progression : plusieurs milliers de joueurs gérés gagnent une ligne par
 // saison (environ 1,7 Mo et 100 000 nœuds par an pour 116 clubs, jusqu'à douze
 // lignes). Hors du club du manager et de son centre, seules les quatre dernières
 // saisons sont gardées : la sauvegarde reste sous ses limites de taille et de nœuds.
 const OTHER_HISTORY=4;
 function trimHistories(s){
  const own=new Set([...s.clubs[s.club].players,...(s.development?.academy||[])].map(p=>p.id));
  const others=[...s.clubs.filter(c=>c.id!==s.club).flatMap(c=>c.players),...(s.aiRoster?.academies||[]).flatMap(a=>a.players),...(s.economy?.freeAgents||[]),...(s.market||[])];
  for(const p of others)if(!own.has(p.id)&&Array.isArray(p.dev?.history)&&p.dev.history.length>OTHER_HISTORY)p.dev.history=p.dev.history.slice(-OTHER_HISTORY);
 }
 function validate(s){
  check(active(s),'édition de base inconnue.');const w=s.worldMode,V=CDWorldValidation;
  if(s.seniorCalibrationVersion!==undefined)check(s.seniorCalibrationVersion===seniorCalibration?.version,'barème senior inconnu.');
  check(V.keys(w,['version','catalogue','rules','startYear','week','leagues','fixtures','yearbook','movement','europe','draws','previousRanks','qualification',...(JP?['japan']:[]),...(N?['nationale']:[]),...(CH?['champ']:[]),...(w.access===undefined?[]:['access']),...(w.day===undefined?[]:['day']),...(w.resultConfirmed===undefined?[]:['resultConfirmed']),...(w.calendarPolicy===undefined?[]:['calendarPolicy'])]),'métadonnées de compétition non reconnues.');
  check(w.calendarPolicy===undefined||lnrOpening(s)&&s.season===1&&w.day!==undefined,'politique de calendrier inconnue.');
  if(CH)check(eq(w.champ,champBoundary()),'frontières du Champ modifiées.');
  check(w.rules===edition.rules&&w.startYear===2026,'profil de règles inconnu.');
  check(saveInt(s.season,1,175)&&playable.has(s.club)&&s.playoff===null&&rosterFoundationActive(s),'saison, club ou fondation de base invalide.');
  check(Number.isInteger(w.week)&&w.week>=0&&w.week<=WEEKS&&s.round===w.week&&s.phase===(w.week===WEEKS?'ended':'league'),'horloge incohérente.');
  check(Array.isArray(s.clubs)&&s.clubs.length===REG.clubs.length,'catalogue incomplet.');
  check(V.keys(w.leagues,IDS)&&V.keys(w.europe,['champions','challenge']),'compétitions incomplètes.');
  const members=IDS.flatMap(id=>{const l=w.leagues?.[id];check(l&&Array.isArray(l.members)&&l.members.length===edition.members[id],'division incomplète.');return l.members;});
  check(members.length===playable.size&&new Set(members).size===playable.size&&members.every(id=>playable.has(id)),'appartenance de division invalide.');
  const partition=Object.fromEntries(IDS.map(id=>[id,w.leagues[id].members])),initialPartition=Object.fromEntries(IDS.map(id=>[id,REG.clubs.filter(c=>c.leagueId===id).map(c=>c.id)]));
  for(const id of IDS.filter(k=>k!=='elite'&&k!=='accession'&&!japanLeague(k)&&!nationallyMutable(k)))check(eq(partition[id],initialPartition[id]),'changement de championnat non autorisé.');
  const challengeDrawPolicy=w.qualification?.challengeDrawPolicy??null,challengeDrawStartSeason=w.qualification?.challengeDrawStartSeason??null;
  check(challengeDrawPolicy===null?challengeDrawStartSeason===null:challengeDrawPolicy===C.CHALLENGE_DRAW_POLICY&&saveInt(challengeDrawStartSeason,2,s.season),'ère du tirage Challenge inconnue.');
  check(saveArray(w.yearbook,15)&&w.yearbook.length===Math.min(15,s.season-1),'palmarès incomplet.');
  let prior=null;
  for(const [i,y]of w.yearbook.entries()){
   check(V.keys(y,['season','standings','champions','finalists','movement','europe','draws',...(y?.challengeDraw===undefined?[]:['challengeDraw']),...(JP?['japan']:[]),...(N?['nationale']:[]),...(CH?['champ']:[])])&&y.season===s.season-w.yearbook.length+i&&V.keys(y.standings,IDS)&&V.keys(y.champions,IDS)&&V.keys(y.finalists,IDS),'archive de saison invalide.');
   if(CH){
    check(eq(y.champ,champBoundary()),'frontières du Champ archivées modifiées.');
    const seeds=y.standings.champ?.slice(0,6);
    check(Array.isArray(seeds)&&seeds.includes(y.champions.champ)&&seeds.includes(y.finalists.champ),'finalistes du Champ hors phase finale archivée.');
   }
   const all=IDS.flatMap(id=>y.standings[id]);check(all.length===playable.size&&new Set(all).size===playable.size&&all.every(id=>playable.has(id)),'classements archivés incomplets.');
   for(const id of IDS){const st=y.standings[id],expected=prior?.nationale?.movement[id]||prior?.movement[id]||prior?.japan?.movement[id]||initialPartition[id];check(Array.isArray(st)&&st.length===initialPartition[id].length&&st.includes(y.champions[id])&&st.includes(y.finalists[id])&&y.champions[id]!==y.finalists[id],'finalistes archivés invalides.');if(prior||y.season===1||id!=='elite'&&id!=='accession'&&!japanLeague(id)&&!nationallyMutable(id))check(st.every(cid=>expected.includes(cid)),'appartenance archivée discontinue.');}
   const m=y.movement;check(V.keys(m,['promoted','relegated','elite','accession'])&&saveArray(m.promoted,2)&&[1,2].includes(m.promoted.length)&&m.relegated?.length===m.promoted.length&&m.promoted[0]===y.champions.accession&&m.relegated[0]===y.standings.elite.at(-1),'mouvements archivés invalides.');
   if(m.promoted.length===2)check(m.promoted[1]===y.finalists.accession&&m.relegated[1]===y.standings.elite[12],'barrage archivé invalide.');
   for(const id of ['elite','accession']){const out=id==='elite'?m.relegated:m.promoted,up=id==='elite'?m.promoted:m.relegated,expected=y.standings[id].filter(cid=>!out.includes(cid)).concat(up);check(Array.isArray(m[id])&&m[id].length===expected.length&&new Set(m[id]).size===expected.length&&m[id].every(cid=>expected.includes(cid)),'partition archivée invalide.');}
   if(JP){
    const [one,two]=JP.leagues,j=y.japan;
    check(V.keys(j,['pairs','legs','outcomes','movement','members'])&&V.keys(j.members,JP.leagues),'archive des barrages Japon incomplète.');
    for(const id of JP.leagues){
     const initial=prior?.japan?.movement[id]||(y.season===1?initialPartition[id]:null);
     const members=j.members[id],standing=y.standings[id];
     check(Array.isArray(members)&&members.length===standing.length&&new Set(members).size===standing.length&&members.every(cid=>standing.includes(cid))&&(!initial||eq(initial,members)),'places japonaises archivées invalides.');
    }
    const synthetic=(id,played)=>y.standings[id].map((cid,i)=>({id:cid,rank:i+1,played,sportingTie:false}));
    const archived={season:y.season},p=JP.promotion({d1:synthetic(one,18),d2:synthetic(two,14),year:japanYear(archived),anchor:japanAnchor(archived)});
    check(eq(j.pairs,p.pairs)&&Array.isArray(j.legs)&&j.legs.length===4,'séries japonaises archivées invalides.');
    for(const [i,leg] of j.legs.entries()){
     const f=p.fixtures[i];
     check(V.keys(leg,['fixtureId','pair','score','tries','conversions'])&&leg.fixtureId===f.id&&eq(leg.pair,[f.homeId,f.awayId]),'manche japonaise archivée modifiée.');
    }
    const outcomes=p.pairs.map(pair=>JP.promotionDecision(pair,j.legs));
    check(eq(outcomes,j.outcomes)&&eq(JP.move(j.members,p.pairs,outcomes),j.movement),'mouvements japonais archivés modifiés.');
    check(y.champions[two]===y.standings[two][0]&&y.finalists[two]===y.standings[two][1]&&[y.champions[one],y.finalists[one]].every(cid=>y.standings[one].slice(0,6).includes(cid)),'palmarès japonais incompatible.');
   }
   if(N){
    const n=y.nationale,champion=y.champions.nationale,finalist=y.finalists.nationale;
    check(V.keys(n,['access','witness','movement','members'])&&V.keys(n.members,frenchIds),'archive de la Nationale incomplète.');
    for(const id of frenchIds){
     const known=prior?.nationale?.movement[id]||(y.season===1?initialPartition[id]:null),members=n.members[id],standing=y.standings[id];
     check(Array.isArray(members)&&members.length===standing.length&&new Set(members).size===standing.length&&members.every(cid=>standing.includes(cid))&&(!known||eq(known,members)),'partition de la pyramide française archivée invalide.');
    }
    const historical={season:y.season},final={champion,finalist},proD2Rank=y.standings.accession,expected=N.accessPlan({...lowerInputs(historical,final),proD2Rank});
    const f=expected.fixture,r=n.witness;
    check(r&&f&&r.fixtureId===f.id&&r.season===y.season&&r.competitionId===f.competitionId&&r.phase===f.phase&&r.date===f.simulationDate&&eq(r.pair,[f.homeId,f.awayId]),'preuve de barrage Nationale archivée absente ou incompatible.');
    V.result(r,{...f,season:y.season,date:f.simulationDate},null,edition.version);
    const lower=lowerInputs(historical,final,r),access=N.accessPlan({...lower,proD2Rank});
    const movement=N.combineFrenchMovements({members:n.members,ranks:{elite:y.standings.elite,accession:proD2Rank},topMovement:y.movement,lower});
    check(access.status==='ready'&&movement.status==='ready'&&eq(n.access,access)&&eq(n.movement,movement),'mouvements de Nationale archivés modifiés.');
   }
   check(V.keys(y.europe,['champions','challenge'])&&saveObject(y.draws),'archives européennes incomplètes.');
   const pastPools=Object.fromEntries(['champions','challenge'].map(id=>{
    const cup=y.europe[id],poolCount=id==='champions'?4:3;
    check(V.keys(cup,['pools','phase','champion','finalist','seeds',...(id==='champions'?['transfers']:[])])&&cup.phase==='ended'&&saveArray(cup.pools,poolCount)&&cup.pools.length===poolCount&&cup.pools.every(p=>saveArray(p,6)&&p.length===6&&p.every(cid=>N?[...y.standings.elite,...y.standings.prem,...y.standings.urc,...edition.guests].includes(cid):saveInt(cid,0,57))),'poules archivées invalides.');
    const ids=cup.pools.flat();check(new Set(ids).size===ids.length&&saveArray(cup.seeds,16)&&cup.seeds.length===16&&new Set(cup.seeds).size===16&&cup.seeds.includes(cup.champion)&&cup.seeds.includes(cup.finalist)&&cup.champion!==cup.finalist,'palmarès européen incomplet.');
    if(id==='champions')check(saveArray(cup.transfers,4)&&cup.transfers.length===4&&new Set(cup.transfers).size===4&&cup.transfers.every(cid=>ids.includes(cid)&&!cup.seeds.includes(cid))&&cup.seeds.every(cid=>ids.includes(cid)),'reversés archivés invalides.');
    else check(cup.seeds.every(cid=>ids.includes(cid)||y.europe.champions.transfers.includes(cid))&&y.europe.champions.transfers.every(cid=>cup.seeds.includes(cid)),'qualifiés Challenge archivés invalides.');
    V.draw(y.draws['pool:'+id],ids);return[id,ids];
   }));
   check(new Set([...pastPools.champions,...pastPools.challenge]).size===42,'club dans deux phases de poules archivées.');
   validateArchivedChallenge(s,y,pastPools.challenge,challengeDrawStartSeason);
   for(const id of IDS){const d=y.draws['league:'+id];check(d&&Array.isArray(d.clubIds)&&d.clubIds.length===y.standings[id].length&&new Set(d.clubIds).size===d.clubIds.length&&d.clubIds.every(cid=>y.standings[id].includes(cid)),'tirage de championnat archivé invalide.');V.draw(d,d.clubIds);}
   check(Object.keys(y.draws).length===IDS.length+2,'tirages archivés non reconnus.');
   prior=y;
  }
  for(const id of N?frenchIds:['elite','accession'])check(eq(partition[id],prior?(N?prior.nationale.movement[id]:prior.movement[id]):initialPartition[id]),'partition française sans provenance.');
  if(JP)for(const id of JP.leagues)check(eq(partition[id],prior?prior.japan.movement[id]:initialPartition[id]),'partition japonaise sans provenance.');
  check(eq(w.previousRanks,prior?previousRanksFor(prior.standings,partition):{}),'classements précédents incohérents.');
  const pools=Object.fromEntries(['champions','challenge'].map(id=>[id,w.europe[id].pools]));
  if(prior){const previous={europe:prior.europe,leagues:Object.fromEntries(IDS.map(id=>[id,{champion:prior.champions[id],finalist:prior.finalists[id]}]))},tables=Object.fromEntries(IDS.map(id=>[id,prior.standings[id].map(clubId=>({clubId}))]));check(saveObject(w.qualification?.drawOrders),'qualification annuelle absente.');const expected=annualEurope(s,previous,partition,tables,w.qualification.drawOrders,challengeDrawPolicy,challengeDrawStartSeason);check(eq(w.qualification,expected.qualification)&&eq(pools,expected.pools),'qualification ou poules annuelles modifiées.');}
  else check(w.qualification===null&&eq(pools,REG.initialEurope),'poules initiales modifiées.');
  check(saveObject(w.draws),'registre de tirages invalide.');
  for(const [k,d]of Object.entries(w.draws)){const [kind,id]=k.split(':'),list=kind==='league'?partition[id]:kind==='pool'?pools[id]?.flat():null;check(k===kind+':'+id&&Array.isArray(list),'tirage inconnu.');V.draw(d,list);}
  check(Array.isArray(w.fixtures)&&w.fixtures.length<=(edition.limits?.maxMatches??1200),'calendrier invalide.');
  const seen=new Set(),played=new Set(),occupied=new Set();
  for(const f of w.fixtures){check(typeof f.id==='string'&&!seen.has(f.id)&&f.fixtureId===f.id&&f.season===s.season,'identifiant de rencontre invalide.');seen.add(f.id);check(Number.isInteger(f.week)&&f.week>=0&&f.week<WEEKS&&weekOf(s,f.date)===f.week,'date de rencontre invalide.');check([f.homeId,f.awayId].every(id=>Number.isInteger(id)&&id>=0&&id<REG.clubCount)&&f.homeId!==f.awayId,'équipes invalides.');for(const id of[f.homeId,f.awayId]){const key=f.week+':'+id;check(!occupied.has(key),'deux rencontres dans une semaine.');occupied.add(key);}}
  const byFixture=new Map(w.fixtures.map(f=>[f.id,f]));
  for(const r of s.history){const f=byFixture.get(r.fixtureId);check(f&&!played.has(r.fixtureId),'résultat sans rencontre unique.');played.add(r.fixtureId);check(f.week<s.round&&eq(r.pair,[f.homeId,f.awayId])&&r.season===s.season&&r.competitionId===f.competitionId&&r.leagueId===f.competitionId&&r.phase===f.phase&&r.competitionRound===f.round&&r.round===f.week&&r.week===f.week&&r.date===f.date&&r.poolId===(f.poolId??null)&&r.neutral===f.neutral,'résultat incompatible avec le calendrier.');V.result(r,f,null,edition.version);}
  check(w.fixtures.filter(f=>f.week<s.round).every(f=>played.has(f.id)),'rencontres passées manquantes.');
  // Une saison générée avant le calendrier alterné (11/11/2026) est relue avec l’ancien générateur ; la saison suivante prend le nouveau.
  const shadowFor=legacyCalendar=>{const shadow={...s,worldMode:{...w,leagues:Object.fromEntries(IDS.map(id=>[id,{members:partition[id],phase:'league',champion:null,finalist:null}])),europe:Object.fromEntries(['champions','challenge'].map(id=>[id,{pools:pools[id],phase:'pool',champion:null,finalist:null}])),fixtures:baseFixtures(s,partition,pools,legacyCalendar).map(f=>fixtureShape(s,f)),movement:null,access:undefined,...(JP?{japan:null}:{}),...(N?{nationale:null}:{}),...(CH?{champ:champBoundary()}: {})}};
  planStages(shadow,false);shadow.worldMode.fixtures.sort(fixtureOrder);return shadow;};
  let shadow=shadowFor(false);if(!eq(w.fixtures,shadow.worldMode.fixtures)){const legacy=shadowFor(true);if(eq(w.fixtures,legacy.worldMode.fixtures))shadow=legacy;}
  const requiredDraws=IDS.filter(id=>shadow.worldMode.leagues[id].seeds).map(id=>'league:'+id);
  if(shadow.worldMode.europe.champions.seeds)requiredDraws.push('pool:champions','pool:challenge');
  check(eq(Object.keys(w.draws).sort(),requiredDraws.sort()),'tirage enregistré hors de sa phase.');
  for(const key of ['fixtures','leagues','europe','access','movement',...(JP?['japan']:[]),...(N?['nationale']:[]),...(CH?['champ']:[])])check(eq(w[key],shadow.worldMode[key]),'calendrier ou phases finales modifiés : '+key+'.');
  check(eq(s.history.map(r=>r.fixtureId),w.fixtures.filter(f=>f.week<s.round).map(f=>f.id)),'ordre des résultats modifié.');
  check(eq(s.schedule,Array.from({length:WEEKS},(_,week)=>w.fixtures.filter(f=>f.week===week).map(f=>[f.homeId,f.awayId]))),'projection calendrier modifiée.');
  if(w.resultConfirmed!==undefined)check(w.resultConfirmed===true&&w.day!==undefined&&s.live?.finished===true,'confirmation de résultat incohérente.');
  if(w.day!==undefined){
   check(saveInt(w.day,0,6)&&(s.phase!=='ended'||w.day===0),'jour de carrière incohérent.');
   const f=userFixture(s),today=calendarToday(s);
   const coherent=!hasClubRole(s)?!s.live&&!w.resultConfirmed:w.resultConfirmed?f&&today>=f.date:(!f||today<=f.date)&&(!s.live||today===f?.date);
   check(coherent,'jour de carrière incohérent.');
  }
  if(s.live)V.live(s.live,userFixture(s),edition.version);
  if(JP)CDWorldJapanQuota.validate(s);
  for(const id of IDS)for(const r of rows(s,id))for(const key of ['points','played','won','drawn','lost','pf','pa','bonus','form'])check(eq(s.clubs[r.clubId][key],r[key]),'classement incohérent.');
  const owned=[...s.clubs.flatMap(c=>c.players),...(s.development?.academy||[]),...(s.aiRoster?.academies||[]).flatMap(a=>a.players)],ownedIds=new Set(owned.map(p=>p.id));
  check(ownedIds.size===owned.length,'joueur dupliqué entre effectifs.');
  const market=[...(s.market||[]),...(s.economy?.freeAgents||[])],copies=new Map();
  for(const p of market){check(!ownedIds.has(p.id)&&saveNumber(p.price,0,1e9),'joueur déjà sous contrat ou prix du marché invalide.');check(!copies.has(p.id)||eq(copies.get(p.id),p),'copies du marché divergentes.');copies.set(p.id,p);}
  const players=[...owned,...market];
  for(const p of players){
   const source=SOURCES.get(p.id),profile=REG.worldProfiles[p.id]||LEGACY[p.id]?.worldProfile;
   // The saved display name belongs to the career: one started on an earlier table of base names keeps its names.
   if(String(p.id).startsWith('world:')||p.worldRatingsVersion!==undefined){
    check(source&&profile&&p.worldRatingsVersion===1&&p.lnrRatingsVersion===undefined,'identité de joueur mondiale inconnue.');
    check(eq(p.worldProfile,profile),'référence initiale mondiale modifiée.');
    for(const key of ['potential','birthYear','birthDate','ageEstimated','gameplayPosition','pos','fam']){
     const expected=key==='potential'&&s.careerVariation!==undefined?nativeCareerVariation.sourcePotential(source.potential,p.id,s.careerVariation):source[key];
     check(eq(p[key],expected),'profil de joueur mondial incompatible : '+key);
    }
    check(p.attributesV2&&Object.keys(p.attributesV2).length===36&&Object.keys(source.attributesV2).every(k=>Number.isFinite(p.attributesV2[k])&&p.attributesV2[k]>=20&&p.attributesV2[k]<=97),'attributs mondiaux invalides.');
    check(eq(p.hiddenTraitsV2,source.hiddenTraitsV2),'traits initiaux mondiaux modifiés.');
   }else check(eq(p.worldProfile,profile),'référence initiale mondiale modifiée.');
  }
  return s;
 }
 function installHooks(){
  const oldRanked=ranked,oldPairs=roundPairs,oldNext=nextMatch,oldLabel=label,oldFinish=finishRound,oldAdvance=advanceSeason,oldCreate=createRugbyMatch,oldFinishMatch=finishRugbyMatch;
  const oldBuild=buildSheet,oldBegin=rugbyBegin;
  ranked=function(){return active(S)?worldRanked(S):oldRanked();};
  roundPairs=function(){return active(S)?fixtures(S).map(f=>[f.homeId,f.awayId]):oldPairs();};
  nextMatch=function(){if(!active(S))return oldNext();const f=hasClubRole(S)?userFixture(S):null;return f?[f.homeId,f.awayId]:undefined;};
  buildSheet=function(team,preferred=[],bench=[]){return oldBuild(active(S)?matchRoster(S,team):team,preferred,bench);};
  rugbyBegin=function(reducedBench=false){
   if(active(S)&&!S.live&&S.phase!=='ended'){
    check(hasClubRole(S),'aucun mandat en club.');
    const fixture=userFixture(S);
    if(fixture&&[...S.lineup,...S.reserves].some(id=>id&&clubReleaseOn(S,id,fixture.date))){
     const sheet=buildSheet(matchRoster(S,club()),S.lineup,S.reserves);
     check([...sheet.lineup,...sheet.bench].filter(Boolean).length>=(reducedBench?22:23),'des joueurs sont en sélection. Complétez la feuille de match du club.');
     S.lineup=sheet.lineup;S.reserves=sheet.bench;
    }
   }
   return oldBegin(reducedBench);
  };
  label=function(){return active(S)?worldLabel(S):oldLabel();};
  finishRound=function(){return active(S)?finishWeek():oldFinish();};advanceSeason=function(){return active(S)?advance():oldAdvance();};
  finishRugbyMatch=function(l){if(!active(S)||!l.worldContext)return oldFinishMatch(l);if(l.worldContext.competitionId==='srp'?CDWorldSRPMatch.finish(l):JP&&CDWorldJapanMatch.isFixture(l.worldContext)?CDWorldJapanMatch.finish(l):CH&&CDWorldChampMatch.applies(l)?CDWorldChampMatch.finish(l):N&&typeof CDWorldNationaleMatch!=='undefined'&&CDWorldNationaleMatch.applies(l)?CDWorldNationaleMatch.finish(l):!japanPromotion(l.worldContext.competitionId)&&CDWorldKnockout.finish(l,edition.version))return;l.finished=true;l.paused=false;addEvent(l,'Coup de sifflet final.','end');};
  createRugbyMatch=function(pair,legacy=null,automated=false,preparation=null){
   if(!active(S))return oldCreate(pair,legacy,automated,preparation);
   const fixture=context(pair),match=createClubMatch(oldCreate,fixture,pair,legacy,automated,preparation);
   match.worldContext=fixture;
   return match;
  };
 }
 // Aliases prevent named inner functions shadowing the globals they replace.
 return Object.freeze({active,sizing,sourcePlayerKnown:id=>SOURCES.has(id),sourcePlayer:id=>SOURCES.get(id)||null,previewRoster,leagueId,ranked:worldRanked,rows,cupTables,fixtures,userFixture,calendarToday,nextOpening,clubReleaseOn,enableDaily,dailyStatus,advanceDay,label:worldLabel,context,start,finishWeek,advance,validate,installFixture,sync,newSeason,planStages,installHooks});
};
