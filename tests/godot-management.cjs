'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-management-'));let n=0;
const b=createBridge({dataDir:root,seed:827381,now:1700000000000});
const call=(command,payload={})=>b.handle({id:++n,command,payload});const good=(c,p)=>{const r=call(c,p);assert.equal(r.ok,true,r.error);return r.model;};
try{
 let m=settleClubMeetings(good('new_career',{club:29,mode:'france'}),(command,payload)=>good(command,payload));const before=good('export').meta.exportText;for(let i=0;i<5;i++)good('snapshot');assert.equal(good('export').meta.exportText,before);
 const slot=m.selection.slots.find(s=>s.eligibleIds.length>1),replacement=slot.eligibleIds.find(id=>id!==slot.playerId);m=good('set_lineup',{slot:slot.slot,playerId:replacement});assert.equal(m.lineup[slot.slot],replacement);assert.equal(new Set([...m.lineup,...m.reserves].filter(Boolean)).size,[...m.lineup,...m.reserves].filter(Boolean).length);
 assert.equal(call('set_lineup',{slot:0,playerId:'absent'}).ok,false);assert.equal(call('set_lineup',{slot:50,playerId:replacement}).ok,false);assert.equal(good('snapshot').meta.saveError,false,'un refus métier ne simule pas une panne disque');
 m=good('set_tactics',{attack:'large',defense:'pression'});assert.equal(m.tactics.attack,'large');assert.equal(m.tactics.defense,'pression');assert.equal(call('set_tactics',{attack:'win',defense:'pression'}).ok,false);
 const id=m.squad[0].id;m=good('set_player_load',{playerId:id,mode:'repos'});assert.equal(m.squad.find(p=>p.id===id).loadPlan,'repos');settleClubMeetings(good('train'),(command,payload)=>good(command,payload));assert.equal(call('set_player_load',{playerId:id,mode:'intense'}).ok,false);
 const candidate=m.market.find(p=>p.available&&p.maxYears>=1),cash=m.finance.cash;assert.equal(call('recruit',{playerId:candidate.id,salary:1000,years:1}).ok,false);
 m=good('recruit',{playerId:candidate.id,salary:1000,years:1,confirmed:true});assert.equal(m.meta.negotiation.status,'counter');assert.equal(m.finance.cash,cash);assert.ok(!m.squad.some(p=>p.id===candidate.id));
 const offered=m.meta.negotiation.salary;m=good('recruit',{playerId:candidate.id,salary:offered,years:1,confirmed:true});assert.equal(m.meta.negotiation.status,'signed');assert.ok(m.squad.some(p=>p.id===candidate.id));assert.equal(m.finance.cash,cash-candidate.fee);assert.equal(call('recruit',{playerId:candidate.id,salary:offered,years:1,confirmed:true}).ok,false);
 const renew=m.squad.find(p=>p.renewal.available);assert.ok(renew);m=good('extend_contract',{playerId:renew.id,salary:100000,years:renew.renewal.minYears,confirmed:true});assert.equal(m.meta.negotiation.status,'signed');assert.equal(m.squad.find(p=>p.id===renew.id).salary,100000);
 good('auto_lineup');m=good('begin_match');assert.ok(m.live);m=good('pause',{paused:true});const sub=m.live.substitutions.find(s=>s.inIds.length);assert.ok(sub);m=good('substitute',{outId:sub.outId,inId:sub.inIds[0]});assert.ok(m.live.lineup.some(p=>p?.id===sub.inIds[0]));assert.ok(!m.live.lineup.some(p=>p?.id===sub.outId));
 m=good('set_tactics',{attack:'occupation',defense:'prudente'});assert.equal(m.live.tactics.attack,'occupation');const liveBefore=good('export').meta.exportText;for(let i=0;i<5;i++)good('snapshot');assert.equal(good('export').meta.exportText,liveBefore);
 m=good('delegate');assert.ok(m.live.finished);m=settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));assert.equal(m.meta.week,1);assert.equal(m.history.length,15);assert.equal(call('next_season',{confirmed:true}).ok,false);
 console.log('Gestion native : décisions, refus, négociation, remplacements et lectures sans mutation PASS');
}finally{b.close();}
