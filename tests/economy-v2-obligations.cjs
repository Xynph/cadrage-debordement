'use strict';
// E2.4 audit only: contract terms and transfer ownership observed from true native S.
const assert=require('node:assert/strict');
const N=require('./career-resilience/native.cjs');
function snapshot(g){
 return N.data(g,`({season:S.season,round:S.round,phase:S.phase,manager:S.club,
 clubs:S.clubs.map(c=>({id:c.id,name:c.name,cash:c.cash,debt:worldClub(c.id)?.debt??null,
 players:c.players.map(p=>({id:p.id,salary:p.salary,contractEnd:p.contractEnd??null}))})),
 offers:(S.economy?.offers||[]).map(o=>({id:o.id,playerId:o.playerId,buyer:o.buyer,fee:o.fee,expires:o.expires})),
 negotiations:Object.values(S.economy?.talks||{}).map(t=>({id:t.id,kind:t.kind,status:t.status,fee:t.fee,acceptedSalary:t.acceptedSalary,years:t.years})),
 transferHistoryLength:S.economy?.transfers?.length??0})`);
}
function contractEvidence(state){
 assert(state&&Array.isArray(state.clubs)&&state.clubs.length===14,'Expected fourteen native clubs');
 const seen=new Set();
 const rows=state.clubs.map(c=>{
  assert(Number.isInteger(c.id)&&Array.isArray(c.players),'Invalid native club');
  let weekly=0,knownTerms=0,unclosedTerms=0,expiring=0;
  for(const p of c.players){
   assert(typeof p.id==='string'&&!seen.has(p.id),'Duplicated contract owner '+p.id);seen.add(p.id);
   assert(Number.isInteger(p.salary)&&p.salary>=0,'Native wage invalid');weekly+=p.salary;
   if(Number.isInteger(p.contractEnd)){knownTerms++;expiring+=(p.contractEnd===state.season)?1:0;}
   else unclosedTerms++;
  }
  assert(Number.isSafeInteger(weekly),'Wage sum overflow');
  return {clubId:c.id,name:c.name,cash:c.cash,debt:c.debt,players:c.players.length,weeklyWage:weekly,
   contractTermsObserved:knownTerms,missingEnd:unclosedTerms,expiring,
   // Planning indicator, NOT an accounting debt or a future contractual liability.
   planning29Weeks:weekly*29,planningBasis:'29 weekly wage cycles at present rates: illustrative, not promised or payable',
   bookedPayable:null,remainingGuaranteedWages:null,contractDebt:null};
 });
 assert.equal(new Set(rows.map(x=>x.clubId)).size,14,'Duplicate club id');
 return {season:state.season,round:state.round,phase:state.phase,clubs:rows,
  offersPending:state.offers.length,negotiationsPending:state.negotiations.length,
  classification:{established:'current player salary and ending year as recorded in native state',
   forecast:'29-week budget illustration at unchanged observed rates',
   unavailable:'accounts payable, contingent bonuses and enforceable future wage liabilities absent from ledger',
   offer:'outstanding transfer offer is not a completed sale',
   negotiation:'ready/counter talk is not a confirmed contract'}};
}
function rosterChanges(before,after){
 const where=s=>{const byId=new Map();for(const c of s.clubs)for(const p of c.players){
  assert(!byId.has(p.id),'Duplicate player owner '+p.id);byId.set(p.id,c.id)}return byId};
 const b=where(before),a=where(after);
 let changes=0,moves=0,arrivals=0,departures=0;
 for(const [id,clubId] of a){if(!b.has(id)){arrivals++;changes++;}else if(b.get(id)!==clubId){moves++;changes++;}}
 for(const id of b.keys())if(!a.has(id)){departures++;changes++;}
 return {changes,interclubMoves:moves,arrivals,departures,feeKnown:false,
  source:'native-player-ownership-change-only'};
}
function validateTransferFixture(g,fee=180000){
 assert(Number.isSafeInteger(fee)&&fee>0,'Invalid fixture fee');
 const before=snapshot(g);
 const manager=before.manager,buyer=before.clubs.find(c=>c.id!==manager&&c.cash>=fee);
 assert(buyer,'No solvent native buyer');
 const player=before.clubs.find(c=>c.id===manager).players[0];
 assert(player,'No selling player');
 const offerId='e24-controlled-sale';
 const setup={playerId:player.id,buyer:buyer.id,fee,id:offerId,expires:999999};
 // Controlled fixture only: add an offer to the real native market, not to production/save.
 g.ctx.__e24Offer=setup;
 g.run('S.economy.offers.push(__e24Offer)');delete g.ctx.__e24Offer;
 const cash0=new Map(before.clubs.map(c=>[c.id,c.cash]));
 const accepted=g.run('acceptSale('+JSON.stringify(offerId)+')');
 assert.equal(accepted,true,'Native sale was refused');
 const after=snapshot(g),owned=after.clubs.filter(c=>c.players.some(p=>p.id===player.id));
 assert.equal(owned.length,1);assert.equal(owned[0].id,buyer.id,'Player not transferred to native buyer');
 assert.equal(after.clubs.find(c=>c.id===manager).cash-cash0.get(manager),fee,'Seller proceeds differ');
 assert.equal(after.clubs.find(c=>c.id===buyer.id).cash-cash0.get(buyer.id),-fee,'Buyer outflow differs');
 assert.equal(after.clubs.reduce((s,c)=>s+c.cash-cash0.get(c.id),0),0,'Interclub cash not conserved');
 return {fee,from:manager,to:buyer.id,cashConserved:true,ownershipUnique:true,fixture:true};
}
module.exports={snapshot,contractEvidence,rosterChanges,validateTransferFixture};
