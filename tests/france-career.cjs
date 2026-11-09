'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-france-career-'));let n=0;
function request(b,command,payload={}){const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,r.error);return r.model;}
for(let club=0;club<30;club++){
 const b=createBridge({dataDir:path.join(root,String(club)),seed:827381,now:1700000000000});
 try{const m=request(b,'new_career',{club,mode:'france'});assert.equal(m.meta.mode,'france30');assert.equal(m.leagues[0].rows.length,14);assert.equal(m.leagues[1].rows.length,16);assert.equal(m.lineup.length,15);assert.equal(m.reserves.length,8);assert.equal(m.selection.valid,true);const doc=JSON.parse(request(b,'export').meta.exportText);assert.equal(doc.state.clubs.length,30);assert.equal(doc.state.aiRoster.academies.length,29);assert.equal(doc.state.aiRosterVersion,2);assert.equal(doc.state.aiRoster.version,2);assert.equal(doc.state.aiRoster.lastIntake,1);for(const academy of doc.state.aiRoster.academies){assert.equal(academy.intakeSeason,1);const promoted=doc.state.aiRoster.events.filter(e=>e.season===1&&e.clubId===academy.clubId&&e.kind==='promote').map(e=>e.playerId);assert.ok(promoted.every(id=>doc.state.clubs[academy.clubId].players.some(p=>p.id===id)),'les promus du centre restent dans le groupe professionnel du même club');const intakeIds=[...academy.players.map(p=>p.id),...promoted];assert.equal(intakeIds.length,6,'six entrants v2, conservés au centre ou réellement promus');assert.equal(new Set(intakeIds).size,6,'aucun jeune compté deux fois entre centre et professionnels');}request(b,'import',{text:JSON.stringify(doc)});assert.equal(request(b,'snapshot').club.id,club);}finally{b.close();}
}
console.log('France30 : trente créations/export/import, feuilles et deux divisions PASS');
