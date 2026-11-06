'use strict';
const C=require('./calibration.cjs');
const normalize=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
function audit(master,data){
 C.validate(master);if(data.schema!=='rugby-real-public-2025-26-v11'||data.cutoff!=='2026-07-01')throw Error('Invalid history schema');
 const names=new Map();for(const p of master.players){const n=normalize(p.realName);if(!names.has(n))names.set(n,[]);names.get(n).push(p);}
 const rows=[];
 for(const list of data.lists){
  if(list.season!=='2025-2026'||!['top14','prod2'].includes(list.league)||!/^https:\/\/(top14|prod2)\.lnr\.fr\/classement\/joueurs\/[^/]+\/2025-2026$/.test(list.sourceUrl))throw Error('Invalid source season');
  const seen=new Set();for(const row of list.ranking){
   if(seen.has(row.lnrId))throw Error('Duplicate row in ranking');seen.add(row.lnrId);
   rows.push({...row,sourceUrl:list.sourceUrl,scope:list.scope,historicalLeague:list.league});
  }
 }
 for(const row of data.careerSeasonRows||[]){if(row.season!=='2025-2026'||!['TOP 14','PRO D2'].includes(row.competition)||!new RegExp('^https://(top14|prod2)\\.lnr\\.fr/joueur/'+row.lnrId+'-[a-z0-9-]+$').test(row.sourceUrl))throw Error('Invalid career source season/identity');rows.push({...row,scope:'career-season-2025-2026'});}
 for(const row of data.observations||[]){if(row.season!=='2025-2026'||!row.asOf.startsWith('2025-12'))throw Error('Invalid observation season');rows.push(row);}
 const unmatched=[],ambiguous=[],matched=[],matchedIds=new Set(),newIds=new Set(),prior=new Set(data.priorCoverage.names.map(normalize));
 for(const row of rows){
  if(!row.name||!row.sourceUrl?.startsWith('https://')||!row.scope||!row.stats||Object.values(row.stats).some(v=>!Number.isFinite(v)||v<0))throw Error('Invalid observed stats');
  const possibilities=names.get(normalize(row.name))||[];
  if(possibilities.length===0){unmatched.push(row.name);continue;}
  if(possibilities.length!==1){ambiguous.push(row.name);continue;}
  const p=possibilities[0];matchedIds.add(p.id);if(!prior.has(normalize(row.name)))newIds.add(p.id);
  matched.push({playerId:p.id,name:p.realName,currentLeague:p.league,currentRole:p.gameplayPosition,sourceUrl:row.sourceUrl,scope:row.scope,stats:row.stats});
 }
 const players=master.players.filter(p=>matchedIds.has(p.id));
 return {schema:'rugby-real-v11-history-coverage',rankingRows:data.lists.reduce((n,l)=>n+l.ranking.length,0),careerRows:data.careerSeasonRows.length,midseasonObservations:data.observations.length,
  totalRows:rows.length,distinctMatched:matchedIds.size,newMatchedSinceV8V9:newIds.size,matchedRows:matched.length,unmatched:[...new Set(unmatched)],ambiguous:[...new Set(ambiguous)],
  lowMinuteCareerRows:data.careerSeasonRows.filter(r=>r.stats.minutes<=600).length,forwardPlayers:players.filter(p=>['Pilier gauche','Pilier droit','Talonneur','Deuxième ligne','Troisième ligne','Numéro 8'].includes(p.gameplayPosition)).length,
  youngPlayers:players.filter(p=>p.ageApprox<=23).length,byCurrentLeague:Object.fromEntries(['top14','prod2'].map(l=>[l,players.filter(p=>p.league===l).length])),
  noAutomaticStatToSkillConversion:true,matched,
  limitations:['Ranking and career tables may include different phase totals; never add or overwrite conflicting scopes','Midseason observations are not season totals and have no exposure denominator unless provided','No tackle attempt counts or success rates collected; no inferred defensive efficiency','Unmatched or missing history is unknown, never zero','Only strict unique normalized full-name matches; no fuzzy identity joins']};
}
module.exports={audit,normalize};
