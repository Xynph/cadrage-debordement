'use strict';
// E2.2: audit only. No mutation to native gameplay or persistent save.
const assert=require('node:assert/strict');
const T=require('./economy-v2-cash-trace.cjs');
const N=require('./career-resilience/native.cjs');
const key=(x)=>x.clubId;
function nativeContext(g){
 return N.data(g,`({clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,wage:c.players.reduce((s,p)=>s+p.salary,0),upkeep:worldUpkeep(worldClub(c.id).facilities),debt:worldClub(c.id).debt,facilities:worldClub(c.id).facilities})),season:S.season,round:S.round,phase:S.phase,manager:S.club})`);
}
function part(type,amount,reason){assert(Number.isSafeInteger(amount),'Invalid component');return {type,amount,reason};}
function categorizeTitle(title,amount){
 if(/Billetterie|Partenaires|Sponsor|Prime|Financement|Subvention|Recette|Indemnité perçue/i.test(title))return 'revenue';
 if(/Investissement|installation/i.test(title))return 'investment';
 if(/Emprunt|Crédit bancaire/i.test(title))return 'financing';
 if(/Salaires|Entretien|Formation|Frais|Coût|Dépense|Achat/i.test(title))return 'expense';
 return amount>=0?'unclassified-income':'unclassified-cost';
}
function actualMatches(g,before){
 return N.data(g,`S.worldManagement.matches.filter(m=>m.season===${before.season}&&m.round===${before.round}&&m.phase===${JSON.stringify(before.phase)})`);
}
function analyze(g,before,after,trace,ledger=[],phase='round'){
 const b=new Map(before.clubs.map(x=>[x.id,x])),a=new Map(after.clubs.map(x=>[x.id,x]));
 const matches=phase==='round'?actualMatches(g,before):[];
 // The manager ledger records each real cash entry. Map by amount one-to-one and track ambiguity.
 const unused=ledger.map((e,i)=>({i,title:e.title,amount:e.amount,used:false}));
 const rows=[],totals={revenue:0,expense:0,investment:0,financing:0,debtService:0,unknown:0},sites={};
 for(const m of trace.movements){
  const old=b.get(m.clubId),cur=a.get(m.clubId);
  assert(old&&cur,'Unknown cash owner');
  const site=m.site,components=[];
  if(site.includes('worldWeeklyEconomy')){
   const match=matches.find(x=>x.home==='club-'+m.clubId||x.away==='club-'+m.clubId);
   const home=match?.home==='club-'+m.clubId;
   const win=match?(home?match.homeScore>match.awayScore:match.awayScore>match.homeScore):false;
   components.push(part('revenue',160000,'weekly-partner'));
   components.push(part('expense',-old.wage,'weekly-player-wages'));
   if(home)components.push(part('revenue',360000,'home-ticket'));
   if(win)components.push(part('revenue',80000,'win-bonus'));
   if(old.upkeep)components.push(part('expense',-old.upkeep,'facility-upkeep'));
  }else if(site.includes('aiRosterContracts')){
   components.push(part('expense',m.delta,'contract-renewal-fee'));
  }else if(site.includes('aiRosterRecruitmentWeek')){
   components.push(part('expense',m.delta,'ai-recruitment-fee'));
  }else if(site.includes('worldNewSeason')){
   if(/:142:/.test(site))components.push(part('financing',m.delta,'negative-cash-converted-to-debt'));
   else if(/:145:/.test(site)){
    components.push(part('revenue',2500000,'season-allocation'));
    const repaid=2500000-m.delta;
    components.push(part('debtService',-repaid,'debt-principal-repayment'));
   }else if(/:149:/.test(site))components.push(part('investment',m.delta,'facility-upgrade'));
   else components.push(part('unknown',m.delta,'unidentified-season-write'));
  }else if(m.clubId===before.manager){
   const candidate=unused.find(e=>!e.used&&e.amount===m.delta);
   if(candidate){
    candidate.used=true;
    components.push(part(categorizeTitle(candidate.title,candidate.amount),candidate.amount,'manager-ledger:'+candidate.title));
   }else components.push(part('unknown',m.delta,'manager-unmatched-ledger'));
  }else components.push(part('unknown',m.delta,'unrecognized-source:'+site));
  const decomposed=components.reduce((s,c)=>s+c.amount,0);
  assert.equal(decomposed,m.delta,'Component reconciliation failed '+site);
  for(const c of components){totals[c.type]=(totals[c.type]||0)+c.amount;if(c.type.startsWith('unclassified'))totals.unknown+=Math.abs(c.amount)}
  sites[site]=(sites[site]||0)+1;
  rows.push({clubId:m.clubId,site,delta:m.delta,components});
 }
 assert.equal(unused.filter(x=>!x.used&&x.amount!==0).length,0,'Unmatched nonzero manager journal entries');
 const delta=after.clubs.reduce((s,c)=>s+c.cash-(b.get(c.id)?.cash||0),0);
 assert.equal(rows.reduce((s,x)=>s+x.delta,0),delta,'Aggregate cash delta mismatch');
 return {rows,totals,sites,delta,unknownCount:rows.flatMap(x=>x.components).filter(x=>x.type==='unknown'||x.type.startsWith('unclassified')).length,
  before,after};
}
function auditedAction(g,action,phase='round'){
 const before=nativeContext(g);
 const trace=T.traceAction(g,action,phase);
 const after=nativeContext(g);
 const classification=analyze(g,before,after,trace,phase==='round'?trace.outcome:[],phase);
 return {...classification,trace};
}
module.exports={nativeContext,analyze,auditedAction,categorizeTitle};
