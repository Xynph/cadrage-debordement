'use strict';
// E2.6 sandbox only: immutable two-ledger transaction, NEVER loaded by the game.
const E1=require('./economy-v2-core.js');
const E25=require('./economy-v2-due-contract.js');
const check=(x,m)=>{if(!x)throw Error(m)};
const own=(o,k)=>Object.prototype.hasOwnProperty.call(o,k);
function create(clubIds){return {version:1,ledger:E1.create({clubIds}),due:E25.create()}}
function validate(state){
 check(state&&state.version===1&&state.ledger&&state.due,'Invalid adapter state');
 E1.validate(state.ledger);E25.validate(state.due);
 const e=state.ledger,d=state.due,seenEvidence=new Set(),seenReceipts=new Set(),seenPayments=new Set();
 check(e.commitments.length===d.obligations.length,'Unmatched E1 commitments');
 for(const o of d.obligations){
  const k=o.clubId+'|'+o.obligationId,c=e.commitments.filter(x=>x.clubId===o.clubId&&x.commitmentId===o.obligationId);
  check(c.length===1&&c[0].due===o.due&&c[0].amount===o.amount&&c[0].kind==='verified'&&c[0].settled===(o.status==='paid'),'Unmatched E1 obligation');
  // Documentary identity is globally unique, even between different clubs.
  const ref=o.evidenceKind+'|'+o.evidenceRef;
  check(!seenEvidence.has(ref),'Evidence reused globally');seenEvidence.add(ref);
  const p=d.payments.filter(x=>x.clubId===o.clubId&&x.obligationId===o.obligationId);
  check(p.length===(o.status==='paid'?1:0),'Unmatched E2.5 payment');
  if(p.length){
   const x=p[0],events=e.events.filter(y=>y.clubId===o.clubId&&y.eventId===x.paymentId);
   check(events.length===1&&events[0].period===x.paidPeriod&&events[0].description==='commitment:'+o.obligationId&&events[0].category==='commitment-verified','Missing exact E1 cash posting');
   check(!seenReceipts.has(x.receiptRef)&&!seenPayments.has(x.paymentId),'Payment proof reused globally');
   seenReceipts.add(x.receiptRef);seenPayments.add(x.paymentId);
  }
 }
 for(const c of e.commitments)check(d.obligations.some(o=>o.clubId===c.clubId&&o.obligationId===c.commitmentId),'Orphan E1 commitment');
 return true;
}
function verified(verify,kind,record){
 check(typeof verify==='function','Trusted proof verifier required');
 // Never trust an identifier alone: the caller's authoritative verifier must attest the ENTIRE record.
 check(verify(kind,Object.freeze({...record}))===true,'Documentary proof not authenticated');
}
function register(state,record,verify){
 validate(state);verified(verify,'obligation',record);
 check(own(state.ledger.balances,record.clubId),'Unknown accounting club');
 const due=E25.register(state.due,record);
 const ledger=E1.addCommitment(state.ledger,{clubId:record.clubId,commitmentId:record.obligationId,due:record.due,amount:record.amount,kind:'verified'});
 const next={version:1,ledger,due};
 if(due===state.due&&ledger===state.ledger)return state;
 validate(next);return next;
}
function mature(state,period){
 validate(state);const due=E25.mature(state.due,period);
 if(due===state.due)return state;
 const next={...state,due};validate(next);return next;
}
function settle(state,receipt,verify){
 validate(state);verified(verify,'receipt',receipt);
 const already=state.due.payments.find(p=>p.clubId===receipt.clubId&&p.obligationId===receipt.obligationId);
 // Same receipt is an idempotent retry, but still requires independent authentication.
 if(already){
  const same=['clubId','obligationId','paymentId','paidPeriod','receiptRef'].every(k=>already[k]===receipt[k]);
  check(same,'Conflicting receipt replay');return state;
 }
 check(!state.due.payments.some(p=>p.paymentId===receipt.paymentId||p.receiptRef===receipt.receiptRef),'Receipt reused globally');
 // All-or-nothing: E1 can reject for insolvency. Neither original ledger changes.
 const ledger=E1.settleCommitment(state.ledger,{clubId:receipt.clubId,commitmentId:receipt.obligationId,eventId:receipt.paymentId,period:receipt.paidPeriod});
 const due=E25.settle(state.due,receipt);
 const next={version:1,ledger,due};validate(next);return next;
}
function summary(state,clubId,period){validate(state);return {accounting:E1.snapshot(state.ledger,clubId,period),obligations:E25.summary(state.due,clubId,period)}}
function restore(json){const obj=typeof json==='string'?JSON.parse(json):json;validate(obj);return obj}
module.exports=Object.freeze({VERSION:1,create,validate,register,mature,settle,summary,restore});
