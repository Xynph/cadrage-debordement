'use strict';
const assert=require('node:assert/strict');
const {writeFileSync}=require('node:fs');
const checks=[];
function check(name,fn){try{fn();checks.push({name,status:'pass'});}catch(e){checks.push({name,status:'fail',error:e.message});throw e;}}
const create=()=>({schemaVersion:1,season:2026,clubs:[{id:'a',cash:300000,debt:0,wages:50000,facilities:3,coach:'coach-a',players:['p1']},{id:'b',cash:80000,debt:0,wages:20000,facilities:2,coach:'coach-b',players:['p2']}],players:[{id:'p1',clubId:'a',wage:10000},{id:'p2',clubId:'b',wage:7000}],transactions:[],events:[]});
function snapshot(s){return JSON.parse(JSON.stringify(s));}
function validate(s){assert.equal(s.schemaVersion,1);assert.equal(new Set(s.clubs.map(c=>c.id)).size,s.clubs.length);assert.equal(new Set(s.players.map(p=>p.id)).size,s.players.length);for(const c of s.clubs){assert.ok(Number.isFinite(c.cash)&&Number.isFinite(c.debt)&&c.debt>=0);assert.ok(Number.isFinite(c.wages)&&c.wages>=0);assert.ok(Number.isInteger(c.facilities)&&c.facilities>=1&&c.facilities<=10);assert.equal(new Set(c.players).size,c.players.length);}for(const p of s.players){assert.equal(s.clubs.filter(c=>c.id===p.clubId&&c.players.includes(p.id)).length,1);}}
function transaction(s,tx){
 const copy=snapshot(s),from=copy.clubs.find(c=>c.id===tx.from),to=copy.clubs.find(c=>c.id===tx.to),p=copy.players.find(p=>p.id===tx.player);
 if(!from||!to||!p||from.id===to.id||p.clubId!==from.id||!from.players.includes(p.id)||to.cash<tx.fee||!Number.isFinite(tx.fee)||tx.fee<0)throw Error('Transaction rejetee');
 if(copy.transactions.some(t=>t.id===tx.id))throw Error('Transaction dupliquee');
 to.cash-=tx.fee;from.cash+=tx.fee;from.players=from.players.filter(id=>id!==p.id);to.players.push(p.id);p.clubId=to.id;
 copy.transactions.push({...tx,type:'transferSigned'});copy.events.push({type:'transferSigned',transactionId:tx.id});
 validate(copy);return copy;
}
function facility(s,clubId,cost){const copy=snapshot(s),c=copy.clubs.find(c=>c.id===clubId);if(!c||!Number.isFinite(cost)||cost<=0||c.cash<cost||c.facilities>=10)throw Error('Projet refuse');c.cash-=cost;c.facilities++;copy.transactions.push({type:'facilityPayment',clubId,amount:cost});copy.events.push({type:'facility',clubId});validate(copy);return copy;}
function coachChange(s,clubId,next){const copy=snapshot(s),c=copy.clubs.find(c=>c.id===clubId);if(!c||typeof next!=='string'||!next||c.coach===next)throw Error('Coach invalide');const prev=c.coach;c.coach=next;copy.events.push({type:'coachChange',clubId,previous:prev,next});return copy;}
check('contrat de sauvegarde et identifiants',()=>validate(create()));
check('transaction de recrutement atomique',()=>{const s=create(),n=transaction(s,{id:'t1',from:'a',to:'b',player:'p1',fee:20000});assert.equal(n.clubs[0].cash,320000);assert.equal(n.clubs[1].cash,60000);assert.equal(n.players[0].clubId,'b');assert.equal(n.transactions.length,1);assert.deepEqual(s,create());});
check('double achat refuse sans mutation',()=>{const s=create(),n=transaction(s,{id:'t1',from:'a',to:'b',player:'p1',fee:20000});assert.throws(()=>transaction(n,{id:'t1',from:'a',to:'b',player:'p1',fee:20000}));assert.throws(()=>transaction(s,{id:'x',from:'a',to:'b',player:'p1',fee:999999}));assert.deepEqual(s,create());});
check('investissement a un seul debit et evenement',()=>{const s=facility(create(),'a',40000);assert.equal(s.clubs[0].cash,260000);assert.equal(s.events.filter(e=>e.type==='facility').length,1);assert.equal(s.transactions.filter(t=>t.type==='facilityPayment').length,1);});
check('mouvement entraineur trace',()=>{const n=coachChange(create(),'a','coach-new');assert.equal(n.clubs[0].coach,'coach-new');assert.deepEqual(n.events[0],{type:'coachChange',clubId:'a',previous:'coach-a',next:'coach-new'});});
check('reprise et encodage JSON stable',()=>{let s=create();s=transaction(s,{id:'t1',from:'a',to:'b',player:'p1',fee:20000});s=coachChange(s,'a','coach-new');s=facility(s,'b',20000);const resumed=JSON.parse(JSON.stringify(s));validate(resumed);assert.deepEqual(resumed,s);assert.deepEqual(JSON.parse(JSON.stringify(resumed)),resumed);});
check('donnees corrompues rejetees',()=>{const s=create();s.players[0].clubId='absent';assert.throws(()=>validate(s));});
const result={schemaVersion:1,kind:'contract-fixtures-only',checks,total:checks.length,passed:checks.filter(x=>x.status==='pass').length};
if(process.env.CD_V55_REPORT)writeFileSync(process.env.CD_V55_REPORT,JSON.stringify(result,null,2)+'\n');
console.log('V55 CONTRACT HARNESS '+JSON.stringify(result));
