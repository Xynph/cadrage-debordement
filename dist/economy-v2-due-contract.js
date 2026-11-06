'use strict';
// E2.5 research ledger: explicit documentary evidence only; NEVER imported by gameplay.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else if(root)root.CDEconomyV2DueContract=api;})(typeof globalThis==='object'?globalThis:null,function(){
 const own=(o,k)=>Object.prototype.hasOwnProperty.call(o,k);
 const clone=x=>JSON.parse(JSON.stringify(x));
 const fail=m=>{throw Error(m)};
 const check=(v,m)=>{if(!v)fail(m)};
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9][A-Za-z0-9:_.\/-]{0,99}$/.test(x)&&!['__proto__','constructor','prototype'].includes(x);
 const period=x=>typeof x==='string'&&/^\d{4}-(0[1-9]|1[0-2])$/.test(x);
 const positive=x=>Number.isSafeInteger(x)&&x>0&&x<=1e12;
 const evidenceTypes=Object.freeze(['invoice-approved','payroll-verified','contract-installment-certified','loan-schedule-certified']);
 const blank=()=>({version:1,obligations:[],payments:[]});
 function create(){return blank()}
 function validate(w){
  check(w&&w.version===1&&Array.isArray(w.obligations)&&Array.isArray(w.payments),'Invalid due contract schema');
  const keys=new Set(),docs=new Set(),payments=new Set();
  for(const o of w.obligations){
   check(o&&id(o.clubId)&&id(o.obligationId)&&positive(o.amount)&&period(o.due)
    &&id(o.evidenceKind)&&evidenceTypes.includes(o.evidenceKind)&&id(o.evidenceRef)
    &&o.status&&['registered','due','paid'].includes(o.status),'Invalid verified obligation');
   check(typeof o.confirmedPeriod==='string'&&period(o.confirmedPeriod)&&o.confirmedPeriod<=o.due,'Invalid confirmation chronology');
   const key=o.clubId+'|'+o.obligationId,source=o.clubId+'|'+o.evidenceKind+'|'+o.evidenceRef;
   check(!keys.has(key)&&!docs.has(source),'Duplicate obligation or documentary source');
   keys.add(key);docs.add(source);
  }
  for(const p of w.payments){
   check(p&&id(p.clubId)&&id(p.paymentId)&&id(p.obligationId)&&period(p.paidPeriod)&&positive(p.amount)
    &&id(p.receiptRef),'Invalid payment record');
   const key=p.clubId+'|'+p.paymentId,doc=p.clubId+'|'+p.receiptRef;
   check(!payments.has(key)&&!payments.has(doc),'Duplicate payment or receipt');
   payments.add(key);payments.add(doc);
   const o=w.obligations.find(x=>x.clubId===p.clubId&&x.obligationId===p.obligationId);
   check(o&&o.amount===p.amount&&p.paidPeriod>=o.due&&o.status==='paid','Payment does not match due obligation');
  }
  for(const o of w.obligations){
   const matches=w.payments.filter(p=>p.clubId===o.clubId&&p.obligationId===o.obligationId);
   check(matches.length===(o.status==='paid'?1:0),'Paid status mismatch');
  }
  return true;
 }
 // The caller is required to provide a real, immutable documentary reference.
 // No inference from salary, offers, forecasts, balance, or unverified legacy values.
 function register(w,{clubId,obligationId,amount,due,confirmedPeriod,evidenceKind,evidenceRef}={}){
  validate(w);
  check(id(clubId)&&id(obligationId)&&positive(amount)&&period(due)&&period(confirmedPeriod)
   &&confirmedPeriod<=due&&evidenceTypes.includes(evidenceKind)&&id(evidenceRef),'Explicit documentary evidence required');
  const row={clubId,obligationId,amount,due,confirmedPeriod,evidenceKind,evidenceRef,status:'registered'};
  const existing=w.obligations.find(x=>x.clubId===clubId&&x.obligationId===obligationId);
  if(existing){
   check(['due','paid','registered'].includes(existing.status)
    &&Object.keys(row).filter(k=>k!=='status').every(k=>existing[k]===row[k]),'Conflicting documentary replay');
   return w;
  }
  check(!w.obligations.some(x=>x.clubId===clubId&&x.evidenceKind===evidenceKind&&x.evidenceRef===evidenceRef),
   'Document already recognized');
  const n=clone(w);n.obligations.push(row);validate(n);return n;
 }
 function mature(w,asOfPeriod){
  validate(w);check(period(asOfPeriod),'Invalid maturity period');
  let changed=false;const n=clone(w);
  for(const o of n.obligations)if(o.status==='registered'&&o.due<=asOfPeriod){
   o.status='due';changed=true;
  }
  if(!changed)return w;
  validate(n);return n;
 }
 function settle(w,{clubId,obligationId,paymentId,paidPeriod,receiptRef}={}){
  validate(w);
  check(id(clubId)&&id(obligationId)&&id(paymentId)&&id(receiptRef)&&period(paidPeriod),'Invalid payment evidence');
  const o=w.obligations.find(o=>o.clubId===clubId&&o.obligationId===obligationId);
  check(o,'Unknown due obligation');
  const prev=w.payments.find(p=>p.clubId===clubId&&p.obligationId===obligationId);
  if(prev){
   check(prev.paymentId===paymentId&&prev.paidPeriod===paidPeriod&&prev.receiptRef===receiptRef,
    'Already settled with different payment');
   return w;
  }
  check(o.status==='due'&&paidPeriod>=o.due,'Payment before maturity');
  check(!w.payments.some(p=>p.clubId===clubId&&(p.paymentId===paymentId||p.receiptRef===receiptRef)),
   'Payment receipt already assigned');
  const n=clone(w),row=n.obligations.find(x=>x.clubId===clubId&&x.obligationId===obligationId);
  row.status='paid';
  n.payments.push({clubId,obligationId,paymentId,paidPeriod,receiptRef,amount:row.amount});
  validate(n);return n;
 }
 function summary(w,clubId,asOfPeriod){
  validate(w);check(id(clubId)&&period(asOfPeriod),'Invalid summary');
  const matched=w.obligations.filter(o=>o.clubId===clubId&&o.confirmedPeriod<=asOfPeriod);
  const paidAsOf=o=>w.payments.some(p=>p.clubId===o.clubId&&p.obligationId===o.obligationId&&p.paidPeriod<=asOfPeriod);
  const unpaid=matched.filter(o=>!paidAsOf(o));
  const due=unpaid.filter(o=>o.due<=asOfPeriod);
  return {clubId,asOfPeriod,verifiedDocuments:matched.length,
   registeredFuture:unpaid.filter(o=>o.due>asOfPeriod).reduce((s,o)=>s+o.amount,0),
   dueUnpaid:due.reduce((s,o)=>s+o.amount,0),
   dueCount:due.length,
   paidDocuments:matched.filter(paidAsOf).length,
   unmeasuredLegacyLiabilities:null};
 }
 function legacyPreview(save){
  check(save&&typeof save==='object'&&Array.isArray(save.clubs)&&save.clubs.length===14,'Invalid legacy view');
  // Read-only, no automatic carry-over of native financial figures into obligations.
  return {version:1,activation:'not-activated',legacyUnmeasuredLiabilities:null,
   observedClubs:save.clubs.length,contractualEvidenceCreated:0,ledger:create()};
 }
 return Object.freeze({VERSION:1,EVIDENCE_KINDS:evidenceTypes,create,validate,register,mature,settle,summary,legacyPreview});
});
