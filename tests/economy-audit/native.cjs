'use strict';
// Observateur de test : aucune regle, aucun coefficient de production remplace.
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const N=require('../career-resilience/native.cjs');
const ROOT=path.resolve(__dirname,'../..');
const BASE='e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807';
const PROFILES=Object.freeze({
 reference:{club:0,policy:'passive'},
 modeste:{club:13,policy:'passive'},
 deficitFormation:{club:13,policy:'formation',cash:-250000}
});
const sum=a=>a.reduce((n,x)=>n+x,0);
const close=(actual,expected,label)=>assert.ok(Number.isFinite(actual)&&Number.isFinite(expected)&&Math.abs(actual-expected)<0.001,`${label}: ${actual} != ${expected}`);
const normal=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
function category(title){
 const s=normal(title);
 if(s.includes('signature du sponsor'))return 'sponsorSignature';
 if(s.includes('prime partenaire'))return 'sponsorVictoire';
 if(s.includes('sponsor '))return 'sponsorHebdo';
 if(s.includes('partenaires'))return 'partenaires';
 if(s.includes('salaires'))return 'salaires';
 if(s.includes('billetterie'))return 'billetterie';
 if(s.includes('prime de victoire'))return 'primesVictoire';
 if(s.includes('champion'))return 'primeChampion';
 if(s.includes('entretien'))return 'entretien';
 if(s.includes('investissement formation'))return 'formation';
 if(s.includes('investissement dans les installations'))return 'installations';
 if(s.includes('financement de debut'))return 'apports';
 if(s.startsWith('signature :'))return 'signatures';
 if(s.startsWith('prolongation'))return 'prolongations';
 if(s.startsWith('vente :'))return 'ventes';
 return 'nonClasse';
}
function add(flows,key,amount,count=1){
 assert.ok(Number.isFinite(amount),'Nonfinite amount');
 const row=flows[key]||(flows[key]={amount:0,count:0});row.amount+=amount;row.count+=count;
}
function merge(dst,src){for(const [k,v] of Object.entries(src))add(dst,k,v.amount,v.count);}
function total(flows){return sum(Object.values(flows).map(x=>x.amount));}
function snapshot(g){return N.data(g,`({season:S.season,round:S.round,phase:S.phase,club:S.club,
 clubs:S.clubs.map(c=>({id:c.id,name:c.name,cash:c.cash,wages:c.players.reduce((s,p)=>s+p.salary,0),
 size:c.players.length,quality:c.players.reduce((s,p)=>s+p.rating,0)/Math.max(1,c.players.length),
 points:c.points,wins:c.won,played:c.played,...worldClub(c.id),upkeep:worldUpkeep(worldClub(c.id).facilities)})),
 reports:S.aiRoster.reports,upgrades:S.worldManagement.upgrades,champion:S.worldManagement.champion})`);}
function fees(before,after,id,season){
 const get=s=>s.reports.find(x=>x.clubId===id&&x.season===season)?.fees||0;
 const d=get(after)-get(before);assert.ok(d>=0,'Current-season fees went backwards');return d;
}
function currentFees(before,after,id){return fees(before,after,id,before.season)+(before.season===after.season?0:fees(before,after,id,after.season));}
function entriesBegin(g){g.run('globalThis.__economyAuditLedger=new Set(S.ledger)');}
function entriesEnd(g){const a=N.data(g,'S.ledger.filter(x=>!__economyAuditLedger.has(x))');delete g.ctx.__economyAuditLedger;return a;}
function recordStep(report,before,after,flows,kind){
 assert.equal(before.club,after.club,'Audit must not move the manager');
 for(const c of before.clubs){
  const next=after.clubs[c.id];
  N.check(report.checks,'cash-reconciliation-'+kind,()=>close(next.cash-c.cash,total(flows[c.id]),`${kind} club ${c.id}`));
  merge(report.clubTotals[c.id].flows,flows[c.id]);
  report.clubTotals[c.id].minCash=Math.min(report.clubTotals[c.id].minCash,next.cash);
  if(next.cash<0)report.clubTotals[c.id].negativeCheckpoints++;
 }
 report.maxUnexplainedResidual=Math.max(report.maxUnexplainedResidual,...before.clubs.map(c=>Math.abs(after.clubs[c.id].cash-c.cash-total(flows[c.id]))));
}
function humanEntries(entries,flow){for(const e of entries){const k=category(e.title);assert.notEqual(k,'nonClasse','Unknown ledger category: '+e.title);add(flow,k,e.amount);}}
function action(g,report,code){
 const before=snapshot(g);entriesBegin(g);const result=g.run(code),entries=entriesEnd(g),after=snapshot(g);
 const flows=before.clubs.map(()=>({}));humanEntries(entries,flows[before.club]);
 recordStep(report,before,after,flows,'decision');return result;
}
function round(g,report){
 const before=snapshot(g),pairs=N.data(g,'roundPairs()');entriesBegin(g);g.run('finishRound()');
 const entries=entriesEnd(g),after=snapshot(g),matches=N.data(g,`S.worldManagement.matches.slice(-${pairs.length})`);
 assert.equal(matches.length,pairs.length);
 assert.ok(after.round!==before.round||after.phase!==before.phase,'Round did not progress');
 const outcomes=matches.map(x=>({pair:[Number(x.home.slice(5)),Number(x.away.slice(5))],score:[x.homeScore,x.awayScore]}));
 assert.deepEqual(outcomes.map(x=>x.pair),pairs,'Match attribution mismatch');
 const flows=before.clubs.map(()=>({}));humanEntries(entries,flows[before.club]);
 for(const c of before.clubs){
  if(c.id===before.club)continue;
  const own=outcomes.find(x=>x.pair.includes(c.id)),home=own?.pair[0]===c.id;
  const won=own&&own.score[own.pair.indexOf(c.id)]>own.score[1-own.pair.indexOf(c.id)];
  add(flows[c.id],'partenaires',160000);add(flows[c.id],'salaires',-c.wages);
  if(home)add(flows[c.id],'billetterie',360000);
  if(won)add(flows[c.id],'primesVictoire',80000);
  if(c.upkeep)add(flows[c.id],'entretien',-c.upkeep);
  const fee=currentFees(before,after,c.id);if(fee)add(flows[c.id],'signaturesIA',-fee);
 }
 for(const c of before.clubs){
  if(['semi','final'].includes(before.phase)&&flows[c.id].billetterie){
   report.neutralVenueTicketAllocations.push({season:before.season,phase:before.phase,club:c.id,amount:flows[c.id].billetterie.amount});
  }
 }
 recordStep(report,before,after,flows,'round');report.rounds++;report.matches+=pairs.length;
 return after;
}
function transition(g,report){
 const before=snapshot(g);assert.equal(before.phase,'ended');entriesBegin(g);g.run('advanceSeason()');
 const entries=entriesEnd(g),after=snapshot(g);assert.equal(after.season,before.season+1);
 const flows=before.clubs.map(()=>({}));humanEntries(entries,flows[before.club]);
 for(const c of before.clubs){
  if(c.id===before.club)continue;
  const oldFees=fees(before,after,c.id,before.season),newFees=fees(before,after,c.id,after.season);
  const capitalized=Math.max(0,oldFees-c.cash),debtOpening=c.debt+capitalized;
  const repayment=Math.min(250000,debtOpening);
  const projects=after.upgrades.filter(x=>x.season===after.season&&x.id===c.id);
  const investment=sum(projects.map(x=>x.cost));
  if(oldFees)add(flows[c.id],'prolongationsIA',-oldFees);
  if(newFees)add(flows[c.id],'signaturesIA',-newFees);
  if(capitalized)add(flows[c.id],'conversionDeficitEnDette',capitalized);
  add(flows[c.id],'apports',2500000);
  if(repayment)add(flows[c.id],'remboursementsDette',-repayment);
  if(investment)add(flows[c.id],'installations',-investment);
  N.check(report.checks,'debt-interest-reconciliation',()=>close(after.clubs[c.id].debt,debtOpening*1.04-repayment,'Debt '+c.id));
  report.clubTotals[c.id].debtInterest+=debtOpening*.04;
 }
 recordStep(report,before,after,flows,'offseason');
 report.transitions.push({from:before.season,to:after.season,flows:flows.map((f,id)=>({club:id,flows:f})),openingCash:sum(before.clubs.map(c=>c.cash)),closingCash:sum(after.clubs.map(c=>c.cash))});
 return after;
}
function sourceFingerprint(){
 const files=fs.readdirSync(path.join(ROOT,'dist')).filter(x=>x.endsWith('.js')).map(x=>'dist/'+x)
  .concat('tests/harness.cjs','tests/career-resilience/native.cjs','tests/economy-audit/native.cjs','ci/economy-audit.cjs').sort();
 const hashes=Object.fromEntries(files.map(f=>[f,N.hash(fs.readFileSync(path.join(ROOT,f)))]));
 return {digest:N.hash(JSON.stringify(hashes)),hashes};
}
function summary(report){
 const flows={};for(const c of report.clubTotals)merge(flows,c.flows);
 const champions=report.seasons.map(s=>s.champion);const wins={};for(const c of champions)wins[c]=(wins[c]||0)+1;
 const open=sum(report.clubTotals.map(c=>c.openingCash)),end=sum(report.clubTotals.map(c=>c.closingCash));
 close(end-open,total(flows),'Campaign global cash');
 return {profile:report.profile,seed:report.seed,seasons:report.seasons.length,matches:report.matches,rounds:report.rounds,reloads:report.checks.reloads,
  openingCash:open,closingCash:end,change:end-open,closingDebt:sum(report.clubTotals.map(c=>c.closingDebt)),flows,
  distinctChampions:Object.keys(wins).length,leaderTitleShare:Math.max(...Object.values(wins))/champions.length,
  neutralVenueTickets:sum(report.neutralVenueTicketAllocations.map(x=>x.amount)),
  checks:report.checks.passed,unexplainedResidual:report.maxUnexplainedResidual};
}
function failureEvidence(g,error){
 // Raw generated test state, NOT an accepted or migrated production save.
 const state=N.data(g),stored=g.store['bdt-v1'];
 const evidence={error:String(error.message),stack:String(error.stack),season:state.season,phase:state.phase,
  managerClub:state.club,champion:state.worldManagement?.champion,ledgerLength:state.ledger?.length,
  ledgerHead:state.ledger?.slice(0,5),saveErrorVisible:!!g.run('lastSaveError'),
  stateHash:N.hash(JSON.stringify(state)),lastStoredHash:typeof stored==='string'?N.hash(stored):null,
  counterfactual:{scope:'diagnostic copy only; no repair of original state or storage',trimmedLedgerValid:false}};
 g.ctx.__economyDiagnosticCopy=N.clone(state);
 try{
  if(Array.isArray(state.ledger)&&state.ledger.length>100){
   g.ctx.__economyDiagnosticCopy.ledger=g.ctx.__economyDiagnosticCopy.ledger.slice(0,100);
   g.run('validateCareer(__economyDiagnosticCopy)');evidence.counterfactual.trimmedLedgerValid=true;
  }
 }catch(e){evidence.counterfactual.error=String(e.message);}
 finally{delete g.ctx.__economyDiagnosticCopy;}
 assert.deepEqual(N.data(g),state,'Diagnostic mutated original career');
 assert.equal(g.store['bdt-v1'],stored,'Diagnostic changed stored bytes');
 return {evidence,state};
}
function campaign({profile='reference',seed=827381,years=15,onSeason=()=>{},onFailure=()=>{}}={}){
 assert.ok(PROFILES[profile]);assert.ok(Number.isInteger(years)&&years>=1&&years<=15);assert.ok(Number.isInteger(seed)&&seed>=0&&seed<=0xffffffff);
 const config=PROFILES[profile];let g=N.fresh(config.club,seed);
 const originalCash=g.run('club().cash');if(config.cash!==undefined)g.run('club().cash='+config.cash);
 const opening=snapshot(g);
 const report={schema:1,base:BASE,profile,seed,policy:config.policy,expectedYears:years,
  assumptions:{initialCashAdjustment:config.cash===undefined?0:config.cash-originalCash,
   managerPolicy:config.policy==='passive'?'No discretionary renewals, recruitment, training or investment':'Stable sponsor, training at 4000 per paid session, affordable annual facilities; no discretionary professional recruitment or renewal',
   money:'Fictitious game euros; wages charged per native round, not a simulated 52-week calendar',rng:'Test sidecar only; not a production save field'},
  clubTotals:opening.clubs.map(c=>({id:c.id,name:c.name,openingCash:c.cash,closingCash:c.cash,closingDebt:c.debt,flows:{},debtInterest:0,minCash:c.cash,negativeCheckpoints:0})),
  checks:N.newStats(),rounds:0,matches:0,maxUnexplainedResidual:0,seasons:[],transitions:[],neutralVenueTicketAllocations:[],complete:false};
 try{
 for(let y=1;y<=years;y++){
  const start=snapshot(g);assert.equal(start.season,y);
  if(config.policy==='formation'){
   action(g,report,'careerSponsorPick("prudent")');action(g,report,'careerSetAcademyInvestment(4000)');
   action(g,report,'worldUpgradeFacility()');
  }
  let rounds=0;
  while(g.run('S.phase')!=='ended'){
   assert.ok(++rounds<=29,'Unbounded season');
   if(config.policy==='formation'&&g.run('S.phase')==='league')action(g,report,'trainWeek()');
   round(g,report);
  }
  assert.equal(rounds,29,'Unexpected financial period count');
  N.verified(g,report.checks,'end-season-native-save');
  const end=snapshot(g),ranking=N.data(g,'ranked().map(c=>c.id)');
  report.seasons.push({season:y,champion:end.champion,openingCash:sum(start.clubs.map(c=>c.cash)),closingCash:sum(end.clubs.map(c=>c.cash)),
   clubs:end.clubs.map(c=>({...c,position:ranking.indexOf(c.id)+1}))});
  report.clubTotals.forEach((c,id)=>{c.closingCash=end.clubs[id].cash;c.closingDebt=end.clubs[id].debt;});
  if(y%5===0||y===years){g=N.reload(g,report.checks,'native-import-checkpoint');}
  onSeason(report.seasons.at(-1));
  if(y<years)transition(g,report);
 }
 report.complete=true;report.summary=summary(report);return report;
 }catch(error){
  report.complete=false;
  const diagnostic=failureEvidence(g,error);report.failure=diagnostic.evidence;
  report.validatedSeasons=report.seasons.length;
  onFailure(report,diagnostic.state);throw error;
 }
}
module.exports={BASE,PROFILES,N,sum,close,category,add,total,merge,snapshot,fees,recordStep,action,round,transition,sourceFingerprint,summary,failureEvidence,campaign};
