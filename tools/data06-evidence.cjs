'use strict';
const fs=require('node:fs'),path=require('node:path');
const SOURCE='https://top14.lnr.fr/actualite/le-tableau-des-transferts-pour-la-saison-20262027';
const clean=s=>String(s||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9]/g,'').toLowerCase();
function validate(document){
 if(document.season!=='2026-2027'||document.origin!=='LNR-public-transfers'||!Array.isArray(document.records))throw Error('Invalid DATA-06 season/source');
 const seen=new Set(),errors=[];
 for(const [i,p] of document.records.entries()){
  if(!p.name||!p.club||!p.position||!p.nationality||!p.from||p.sourceUrl!==SOURCE||p.evidenceType!=='LNR-transfer-arrival')errors.push('Missing evidence '+i);
  if(p.historicalAsOfJuly1Verified!==false||p.verifiedSalary!==null||p.verifiedContractEnd!==null||p.verifiedBudget!==null)errors.push('Unverified historical/financial claim '+i);
  const key=clean(p.club)+'|'+clean(p.name);if(seen.has(key))errors.push('Duplicate '+key);seen.add(key);
  if(p.loan!==/prêt/i.test(p.from))errors.push('Loan conflict '+i);
 }
 if(errors.length)throw Error(errors.join('; '));
 return {season:document.season,entries:document.records.length,clubs:new Set(document.records.map(x=>x.club)).size,duplicates:0,financialFacts:0,officialRatingClaims:0};
}
function matchRoster(document,roster){
 const byClub=new Map(),all=new Map();
 for(const p of roster){
  const key=clean(p.club)+'|'+clean(p.name);if(!byClub.has(key))byClub.set(key,[]);byClub.get(key).push(p);
  const name=clean(p.name);if(!all.has(name))all.set(name,[]);all.get(name).push(p);
 }
 const results=document.records.map(p=>{
  const key=clean(p.club)+'|'+clean(p.name),local=byClub.get(key)||[],remote=all.get(clean(p.name))||[];
  return {name:p.name,club:p.club,sourceUrl:p.sourceUrl,linkedId:local.length===1?local[0].id:null,status:local.length===1?'club-match':remote.length?'manual-review-club':'not-found',candidateIds:remote.map(x=>x.id)};
 });
 return {results,matched:results.filter(x=>x.status==='club-match').length,review:results.filter(x=>x.status==='manual-review-club').length,unknown:results.filter(x=>x.status==='not-found').length};
}
function estimateAttributes(p,{matches=null,minutes=null,tries=null}={}){
 // A neutral unscored record is safer than manufacturing ability from nationality or body size.
 if(!Number.isInteger(matches)||matches<1||!Number.isFinite(minutes)||minutes<0||minutes>matches*100||!Number.isInteger(tries)||tries<0)return{rating:null,kind:'unrated',reason:'insufficient-verified-performance',method:'data06-v1'};
 const availability=Math.min(1,minutes/(matches*80));
 const score=Math.max(1,Math.min(99,Math.round(45+25*availability+Math.min(15,tries*2))));
 return {rating:score,kind:'game-estimate',reason:'minutes-and-tries-heuristic-not-official-skill',method:'data06-v1'};
}
function load(file=path.resolve(__dirname,'../modding/data06/official-transfers-2026-2027.json')){return JSON.parse(fs.readFileSync(file,'utf8'))}
if(require.main===module){try{console.log(JSON.stringify(validate(load())))}catch(e){console.error(e.message);process.exitCode=1}}
module.exports={clean,validate,matchRoster,estimateAttributes,load};
