'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-world-'));
let serial=0;const open=[];
function bridge(name){const b=createBridge({dataDir:path.join(root,name),seed:827381,now:1794178800000});open.push(b);return b;}
function call(b,command,payload={}){return b.handle({id:++serial,command,payload});}
function good(b,command,payload={}){const r=call(b,command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;}
function state(b){return JSON.parse(good(b,'export').meta.exportText).state;}
try{
 const b=bridge('prem'),m=settleClubMeetings(good(b,'new_career',{mode:'world',club:30}),(command,payload)=>good(b,command,payload));
 assert.equal(m.meta.mode,'world');assert.equal(m.meta.leagueId,'prem');assert.equal(m.meta.catalogue.length,58);assert.equal(m.meta.catalogue.filter(c=>c.playable).length,56);
 assert.equal(m.selection.valid,true);assert.equal(state(b).clubs.length,58);
 assert.equal(new Set(state(b).clubs.flatMap(c=>c.players.map(p=>p.id))).size,state(b).clubs.flatMap(c=>c.players).length);
 assert.equal(m.leagues.find(l=>l.id==='prem').rows.length,10);assert.equal(m.leagues.find(l=>l.id==='urc').rows.length,16);
 const initial=good(b,'export').meta.exportText;good(b,'import',{text:initial});assert.deepEqual(state(b),JSON.parse(initial).state);
 const before=state(b);assert.equal(call(b,'new_career',{mode:'world',club:56}).ok,false);assert.deepEqual(state(b),before);
 // A whole native rugby match, not a projection-only score generator.
 while(!good(b,'snapshot').next)settleClubMeetings(good(b,'finish_round'),(command,payload)=>good(b,command,payload));
 const fixture=good(b,'snapshot').next;good(b,'begin_match');assert.deepEqual(good(b,'snapshot').live.pair,fixture.pair);good(b,'delegate');settleClubMeetings(good(b,'finish_round'),(command,payload)=>good(b,command,payload));
 assert.ok(state(b).history.some(r=>r.pair.includes(30)&&r.stats&&r.score));
 const saved=state(b);good(b,'shutdown');const restarted=bridge('prem');assert.deepEqual(state(restarted),saved);
 for(const [club,leagueId]of [[0,'elite'],[14,'accession'],[40,'urc']]){const other=bridge('club'+club),model=settleClubMeetings(good(other,'new_career',{mode:'world',club}),(command,payload)=>good(other,command,payload));assert.equal(model.meta.leagueId,leagueId);assert.equal(model.selection.valid,true,'club '+club+': '+JSON.stringify(model.selection.errors));}
 const urc=bridge('urc-match');let next=settleClubMeetings(good(urc,'new_career',{mode:'world',club:40}),(command,payload)=>good(urc,command,payload)).next;for(let week=0;!next&&week<46;week++)next=settleClubMeetings(good(urc,'finish_round'),(command,payload)=>good(urc,command,payload)).next;
 assert.equal(next.competitionId,'urc');good(urc,'begin_match');good(urc,'delegate');settleClubMeetings(good(urc,'finish_round'),(command,payload)=>good(urc,command,payload));const urcState=state(urc),urcResult=urcState.history.find(r=>r.competitionId==='urc'&&r.pair.includes(40));assert.ok(urcResult?.stats);assert.equal(urcResult.date,next.date);
 console.log(JSON.stringify({passed:true,checks:['58 clubs, 56 playable','4 domestic leagues','native PREM and URC matches','export/import/restart','invalid guest creation transaction'],bytes:Buffer.byteLength(JSON.stringify(saved))}));
}finally{for(const b of open)b.close();fs.rmSync(root,{recursive:true,force:true});}
