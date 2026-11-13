'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
// Cross-domain production wiring, read purity, refused transactions and disk resume.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'oval-six-'));let bridge,id=0;
function request(command,payload={}){return bridge.handle({id:++id,command,payload});}
function call(command,payload={}){const r=request(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;}
try{
 bridge=createBridge({dataDir:root,seed:27,now:1700000000000});
 const calendar={action:'generate',name:'Coupe fictive',clubs:['A','B','C'],doubleRound:true};
 assert.equal(call('competition_editor_preview',calendar).competitionEditor.summary.matches,6,'editor available before creating a career');
 let m=settleClubMeetings(call('new_career',{mode:'world-champ',club:0}),call);
 for(const key of ['interclubMarket','staffMentoring','performanceAnalysis'])assert.ok(m.clubLife[key],key+' must be wired into production snapshot');
 const exported=call('export').meta.exportText,profile=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(profile);
 for(let n=0;n<2;n++)call('snapshot');
 assert.equal(call('competition_editor_preview',calendar).competitionEditor.summary.rounds,6);
 assert.equal(request('competition_editor_preview',{...calendar,clubs:['A','A']}).ok,false);
 assert.equal(call('export').meta.exportText,exported,'read-only domains do not mutate career');assert.deepEqual(fs.readFileSync(profile),bytes);
 const refused=request('interclub_transfer',{playerId:'missing',context:{season:-1,week:-1,club:-1}});assert.equal(refused.ok,false);
 assert.equal(call('export').meta.exportText,exported,'refused cross-club move is atomic');assert.deepEqual(fs.readFileSync(profile),bytes);
 m=call('snapshot');
 const q=m.clubLife.interclubMarket.candidates.find(p=>p.available);assert.ok(q,'one contracted player can actually be bought');
 const beforeState=JSON.parse(exported).state;
 m=call('interclub_transfer',{playerId:q.id,sellerId:q.clubId,fee:q.fee,salary:q.salary,sourceSalary:q.sourceSalary,contractEnd:q.contractEnd,context:m.clubLife.interclubMarket.context,confirmed:true});
 const bought=call('export').meta.exportText,afterState=JSON.parse(bought).state;
 assert.equal(afterState.clubs[0].cash,beforeState.clubs[0].cash-q.fee);
 assert.equal(afterState.clubs[q.clubId].cash,beforeState.clubs[q.clubId].cash+q.fee);
 assert.equal(afterState.clubs[0].players.filter(p=>p.id===q.id).length,1);
 assert.equal(afterState.clubs[q.clubId].players.some(p=>p.id===q.id),false);
 assert.equal(m.clubLife.staffMentoring.canEnable,true,'staff careers expose optional mentoring in the integrated worker');
 m=call('staff_mentoring_enable',{context:m.clubLife.staffMentoring.context,confirmed:true});
 const mentored=call('export').meta.exportText;assert.equal(JSON.parse(mentored).state.staffMentoring.version,1);
 call('shutdown');bridge=createBridge({dataDir:root,now:1700000000000});
 assert.equal(call('export').meta.exportText,mentored,'all domains support disk resume after real transactions and mentoring activation');
 call('import',{text:mentored});assert.equal(call('export').meta.exportText,mentored,'strict import accepts the integrated optional domain');
 console.log('Six lots : domaines production, lectures pures, refus atomique et reprise disque PASS.');
}finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
