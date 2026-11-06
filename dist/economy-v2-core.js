'use strict';
// E1 : noyau de comptabilité indépendant. Non importé par le jeu existant.
(function(root,build){const api=build();if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.CDEconomyV2Core=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
 const types=Object.freeze({cash:'asset',receivable:'asset',fixedAssets:'asset',debt:'liability',payable:'liability',capital:'equity',revenue:'income',expense:'expense'});
 const own=(o,k)=>Object.prototype.hasOwnProperty.call(o,k),check=(v,m)=>{if(!v)throw Error(m)},copy=v=>JSON.parse(JSON.stringify(v));
 const id=x=>typeof x==='string'&&/^[a-zA-Z0-9][a-zA-Z0-9:_./-]{0,99}$/.test(x)&&!['__proto__','constructor','prototype'].includes(x);
 const date=x=>typeof x==='string'&&/^\d{4}-(0[1-9]|1[0-2])$/.test(x);
 const money=(x,positive=true)=>Number.isSafeInteger(x)&&Math.abs(x)<=1e12&&(positive?x>0:x!==0);
 const empty=()=>Object.fromEntries(Object.keys(types).map(k=>[k,0]));
 const sign=k=>['liability','equity','income'].includes(types[k])?-1:1;
 const residual=b=>b.cash+b.receivable+b.fixedAssets+b.expense-b.debt-b.payable-b.capital-b.revenue;
 function lines(xs){
  check(Array.isArray(xs)&&xs.length>=2&&xs.length<=30,'Invalid lines');
  const ls=xs.map(v=>{check(v&&own(types,v.account),'Invalid posting');const debit=v.debit??0,credit=v.credit??0;check(Number.isSafeInteger(debit)&&Number.isSafeInteger(credit)&&debit>=0&&credit>=0&&debit<=1e12&&credit<=1e12&&(debit>0)!==(credit>0),'Invalid posting');return {account:v.account,debit,credit}});
  check(ls.reduce((s,x)=>s+x.debit-x.credit,0)===0,'Journal must balance');return ls;
 }
 function create({clubIds,version=1}={}){
  check(version===1&&Array.isArray(clubIds)&&clubIds.length>0&&clubIds.length<=100,'Invalid economic world');
  check(clubIds.every(id)&&new Set(clubIds).size===clubIds.length,'Invalid or duplicate club ID');
  return {version:1,balances:Object.fromEntries(clubIds.map(x=>[x,empty()])),events:[],commitments:[]};
 }
 function validate(w){
  check(w&&w.version===1&&w.balances&&typeof w.balances==='object'&&!Array.isArray(w.balances)&&Array.isArray(w.events)&&Array.isArray(w.commitments),'Invalid ledger');
  const expected=Object.fromEntries(Object.keys(w.balances).map(x=>[x,empty()])),keys=new Set();
  for(const e of w.events){
   check(e&&id(e.clubId)&&own(expected,e.clubId)&&id(e.eventId)&&date(e.period)&&id(e.category)&&typeof e.description==='string'&&e.description.length<=240,'Invalid ledger event');
   const k=e.clubId+'|'+e.eventId;check(!keys.has(k),'Duplicate ledger event');keys.add(k);
   for(const l of lines(e.lines)){const b=expected[e.clubId];b[l.account]+=sign(l.account)*(l.debit-l.credit);check(Number.isSafeInteger(b[l.account]),'Ledger overflow')}
  }
  for(const [key,b] of Object.entries(w.balances)){
   check(id(key)&&b&&Object.keys(b).length===Object.keys(types).length,'Invalid club account');
   for(const a of Object.keys(types))check((money(b[a],false)||b[a]===0)&&b[a]===expected[key][a],'Balance does not match journal');
   check(residual(b)===0,'Unbalanced ledger for '+key);
   check(b.cash>=0&&b.debt>=0&&b.payable>=0&&b.receivable>=0&&b.fixedAssets>=0,'Invalid asset or liability balance');
  }
  const commitments=new Set();
  for(const c of w.commitments){
   check(c&&id(c.clubId)&&own(w.balances,c.clubId)&&id(c.commitmentId)&&date(c.due)&&money(c.amount)&&id(c.kind)&&typeof c.settled==='boolean','Invalid commitment state');
   const k=c.clubId+'|'+c.commitmentId;check(!commitments.has(k),'Duplicate commitment');commitments.add(k);
   const bound=w.events.filter(e=>e.clubId===c.clubId&&e.description==='commitment:'+c.commitmentId);
   check(!c.settled||bound.length===1,'Commitment payment binding mismatch');
   if(c.settled){const e=bound[0];check(e.category==='commitment-'+c.kind&&e.period>=c.due&&e.lines.some(l=>l.account==='expense'&&l.debit===c.amount)&&e.lines.some(l=>l.account==='cash'&&l.credit===c.amount),'Invalid commitment payment')}

  }
  return true;
 }
 function post(w,{clubId,eventId,period,lines:xs,category='other',description=''}={}){
  validate(w);check(id(clubId)&&own(w.balances,clubId)&&id(eventId)&&date(period)&&id(category)&&typeof description==='string'&&description.length<=240,'Invalid event identity');
  const event={clubId,eventId,period,category,description,lines:lines(xs)};
  const prev=w.events.find(x=>x.clubId===clubId&&x.eventId===eventId);
  if(prev){check(JSON.stringify(prev)===JSON.stringify(event),'Conflicting event replay');return w}
  const next=copy(w),b=next.balances[clubId];
  for(const l of event.lines){b[l.account]+=sign(l.account)*(l.debit-l.credit);check(Number.isSafeInteger(b[l.account]),'Balance overflow')}
  next.events.push(event);validate(next);return next;
 }
 function postBatch(w,events){check(Array.isArray(events)&&events.length<=1000,'Invalid batch');return events.reduce((s,e)=>post(s,e),w)}
 function income(w,{clubId,eventId,period,amount,category='operating',description=''}={}){
  check(money(amount),'Invalid income amount');return post(w,{clubId,eventId,period,category,description,lines:[{account:'cash',debit:amount},{account:'revenue',credit:amount}]});
 }
 function payment(w,{clubId,eventId,period,amount,category='operating',description=''}={}){
  check(money(amount),'Invalid payment amount');return post(w,{clubId,eventId,period,category,description,lines:[{account:'expense',debit:amount},{account:'cash',credit:amount}]});
 }
 function injectCapital(w,{clubId,eventId,period,amount}={}){
  check(money(amount),'Invalid capital amount');return post(w,{clubId,eventId,period,category:'equity-injection',lines:[{account:'cash',debit:amount},{account:'capital',credit:amount}]});
 }
 function drawLoan(w,{clubId,eventId,period,amount}={}){
  check(money(amount),'Invalid loan amount');return post(w,{clubId,eventId,period,category:'loan-draw',lines:[{account:'cash',debit:amount},{account:'debt',credit:amount}]});
 }
 function repayLoan(w,{clubId,eventId,period,principal,interest=0}={}){
  check(money(principal)&&Number.isSafeInteger(interest)&&interest>=0&&interest<=1e12,'Invalid repayment');
  check(w.balances?.[clubId]?.debt>=principal,'Repayment exceeds debt');
  const ls=[{account:'debt',debit:principal},{account:'cash',credit:principal+interest}];
  if(interest)ls.push({account:'expense',debit:interest});
  return post(w,{clubId,eventId,period,category:'debt-service',lines:ls});
 }
 function invest(w,{clubId,eventId,period,amount}={}){
  check(money(amount),'Invalid investment');return post(w,{clubId,eventId,period,category:'capital-expenditure',lines:[{account:'fixedAssets',debit:amount},{account:'cash',credit:amount}]});
 }
 function addCommitment(w,{clubId,commitmentId,due,amount,kind='contract'}={}){
  validate(w);check(id(clubId)&&own(w.balances,clubId)&&id(commitmentId)&&date(due)&&money(amount)&&id(kind),'Invalid commitment');
  const prev=w.commitments.find(c=>c.clubId===clubId&&c.commitmentId===commitmentId);
  if(prev){check(prev.due===due&&prev.amount===amount&&prev.kind===kind,'Conflicting commitment');return w}
  const next=copy(w);next.commitments.push({clubId,commitmentId,due,amount,kind,settled:false});return next;
 }
 function settleCommitment(w,{clubId,commitmentId,eventId,period}={}){
  validate(w);
  const c=w.commitments?.find(x=>x.clubId===clubId&&x.commitmentId===commitmentId);
  check(c,'Unknown commitment');check(id(eventId)&&date(period)&&period>=c.due,'Commitment not due');
  const binding='commitment:'+commitmentId, category='commitment-'+c.kind;
  const prev=w.events.find(x=>x.clubId===clubId&&x.eventId===eventId);
  if(c.settled){
   check(prev&&prev.category===category&&prev.description===binding&&prev.period===period,'Commitment already settled');
   return w;
  }
  check(!prev,'Payment event already assigned');
  check(!w.events.some(x=>x.clubId===clubId&&x.description===binding),'Commitment payment already recorded');
  const next=payment(w,{clubId,eventId,period,amount:c.amount,category,description:binding});
  next.commitments.find(x=>x.clubId===clubId&&x.commitmentId===commitmentId).settled=true;
  validate(next);return next;
 }
 function transfer(w,{sellerId,buyerId,eventId,period,amount,bookValue=0}={}){
  check(sellerId!==buyerId&&money(amount)&&Number.isSafeInteger(bookValue)&&bookValue>=0&&bookValue<=1e12&&id(eventId)&&date(period),'Invalid transfer');
  // The seller recognizes both proceeds and the carrying value disposed of.
  // Zero bookValue is an explicit uncapitalized legacy case; do not invent assets.
  check(w.balances?.[sellerId]?.fixedAssets>=bookValue,'Transfer book value exceeds seller assets');
  const sale=[{account:'cash',debit:amount},{account:'revenue',credit:amount}];
  if(bookValue){sale.push({account:'expense',debit:bookValue},{account:'fixedAssets',credit:bookValue})}
  return postBatch(w,[{clubId:buyerId,eventId,period,category:'transfer-in',lines:[{account:'fixedAssets',debit:amount},{account:'cash',credit:amount}]},{clubId:sellerId,eventId,period,category:'transfer-out',lines:sale}]);
 }
 function snapshot(w,clubId,asOfPeriod){
  validate(w);check(id(clubId)&&own(w.balances,clubId),'Unknown club');check(asOfPeriod===undefined||date(asOfPeriod),'Invalid period');
  const b=asOfPeriod===undefined?w.balances[clubId]:(()=>{
   const out=empty();
   for(const e of w.events)if(e.clubId===clubId&&e.period<=asOfPeriod)for(const l of e.lines)out[l.account]+=sign(l.account)*(l.debit-l.credit);
   return out;
  })();
  const due=w.commitments.filter(c=>c.clubId===clubId&&!c.settled&&(asOfPeriod===undefined||c.due<=asOfPeriod));
  const booked=w.events.filter(e=>e.clubId===clubId&&(asOfPeriod===undefined||e.period<=asOfPeriod));
  return {clubId,cash:b.cash,result:b.revenue-b.expense,revenue:b.revenue,expense:b.expense,debt:b.debt,capital:b.capital,fixedAssets:b.fixedAssets,receivable:b.receivable,payable:b.payable,commitmentsDue:due.reduce((s,c)=>s+c.amount,0),commitments:due.length,bookedEvents:booked.length,accountingResidual:residual(b)};
 }
 function spendingRoom(w,clubId,{reserve=0,through}={}){
  check(Number.isSafeInteger(reserve)&&reserve>=0&&reserve<=1e12&&date(through),'Invalid budget projection');
  const s=snapshot(w,clubId,through);return {available:Math.max(0,s.cash-reserve-s.commitmentsDue),reserve,commitmentsDue:s.commitmentsDue,warning:s.cash<reserve+s.commitmentsDue};
 }
 return Object.freeze({ACCOUNTS:types,create,validate,post,postBatch,income,payment,injectCapital,drawLoan,repayLoan,invest,addCommitment,settleCommitment,transfer,snapshot,spendingRoom});
});
