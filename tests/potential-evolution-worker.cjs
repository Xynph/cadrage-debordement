'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {advanceToNextMatch}=require('./helpers/monde-matchs.cjs');
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
test('real training and completed match persist development evidence without revealing ceilings',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'oval-potential-worker-'));let bridge=createBridge({dataDir:root,seed:917,now:1794310000000}),serial=0;
 t.after(()=>{bridge.close();fs.rmSync(root,{recursive:true,force:true});});
 const go=(command,payload={})=>{const r=bridge.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 let model=settleClubMeetings(go('new_career',{mode:'world-champ',club:0}),go),file=path.join(model.meta.dataDir,'donnees.json');
 const raw=()=>JSON.parse(JSON.parse(fs.readFileSync(file)).store['bdt-v1']);
 const first=fs.readFileSync(file);go('snapshot');assert.deepEqual(fs.readFileSync(file),first);assert.equal(raw().potentialEvolution,undefined);
 const source=raw().clubs[0].players.find(p=>p.lnrRatingsVersion===1&&p.age<=22&&p.dev.potential>=p.rating+2);assert.ok(source);
 assert.equal(model.decisions.development.professionals.find(p=>p.id===source.id).development.available,true,'the real UI offers source-player specialization');
 // Resume a real career just before an earned XP point, then use the public
 // training command: detailed source players must improve before season end.
 const prepared=JSON.parse(go('export').meta.exportText);
 prepared.state.clubs[0].players.find(p=>p.id===source.id).dev.xp=.999;
 const checksum=state=>{let h=2166136261;for(const c of JSON.stringify(state))h=Math.imul(h^c.charCodeAt(0),16777619);return (h>>>0).toString(16).padStart(8,'0');};
 prepared.checksum=checksum(prepared.state);go('import',{text:JSON.stringify(prepared)});
 go('set_development_focus',{playerId:source.id,focus:'equilibre'});
 model=go('train',{mode:'normal'});let trainedState=raw(),evidence=trainedState.potentialEvolution;assert.ok(evidence.records.flat().length>0);assert.ok(evidence.records.flat().some(r=>trainedState.clubs[1].players.some(p=>p.id===r[0])),'other clubs are trained under the same system');
 const learned=trainedState.clubs[0].players.find(p=>p.id===source.id);
 assert.equal(learned.rating,source.rating+1);assert.equal(learned.dev.inSeasonGrowthSeason,trainedState.season);
 assert.ok(Object.keys(source.attributesV2).some(k=>learned.attributesV2[k]>source.attributesV2[k]));
 assert.equal(model.squad.find(p=>p.id===source.id).rating,learned.rating);
 go('train',{mode:'normal'});assert.deepEqual(raw().potentialEvolution,evidence,'weekly training cannot be repeated');
 advanceToNextMatch(go('snapshot'),go);go('auto_lineup');go('begin_match');model=go('delegate');assert.equal(model.live.finished,true);
 settleClubMeetings(go('finish_round'),go);
 const played=raw().potentialEvolution.records.flat().filter(r=>r[7]>0);assert.ok(played.length>0);assert.ok(played.every(r=>r[8]>0));
 const state=raw(),before=fs.readFileSync(file),text=go('export').meta.exportText;go('snapshot');assert.deepEqual(fs.readFileSync(file),before);
 model=go('import',{text});assert.deepEqual(raw().potentialEvolution,state.potentialEvolution);
 assert.ok(model.squad.every(p=>p.potential===null&&p.potentialRange.max-p.potentialRange.min===4));
 bridge.close();bridge=createBridge({dataDir:root,seed:1,now:1});go('snapshot');assert.deepEqual(raw().potentialEvolution,state.potentialEvolution);
 const doc=JSON.parse(go('export').meta.exportText);doc.state.potentialEvolution.records[0][0].push(0);
 let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');
 const pristine=fs.readFileSync(file),bad=bridge.handle({id:++serial,command:'import',payload:{text:JSON.stringify(doc)}});assert.equal(bad.ok,false);assert.match(bad.error,/Potentiel évolutif/);assert.deepEqual(fs.readFileSync(file),pristine);
});
