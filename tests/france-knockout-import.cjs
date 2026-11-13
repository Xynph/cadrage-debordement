'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{context}=require('./france-harness.cjs'),{createBridge}=require('../native/engine/worker.cjs');const h=context();
const bridge=createBridge({dataDir:fs.mkdtempSync(path.join(os.tmpdir(),'cd-france-ko-import-')),seed:827381,now:1700000000000});let serial=0;const call=(command,payload={})=>bridge.handle({id:++serial,command,payload});
function install(text){const r=call('import',{text});assert.equal(r.ok,true,r.error);}
function rejected(text){const before=call('export'),file=path.join(before.model.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file),r=call('import',{text});assert.equal(r.ok,false);assert.deepEqual(JSON.parse(call('export').model.meta.exportText).state,JSON.parse(before.model.meta.exportText).state);assert.deepEqual(fs.readFileSync(file),bytes);}
h.run("start(0,'france');for(let w=0;w<30;w++){autoLineup();finishRound();}if(!nextMatch())finishRound();S.training='repos';trainWeek();autoLineup();if(sheetErrors().length)promoteCover();beginMatch();var original=JSON.stringify(createSaveDocument());");
assert.ok(h.state().live);assert.notEqual(h.state().live.franceContext.phase,'league');
// Exact review exploit: fake completed 80-minute draw, imaginary extra time and red card.
h.run("var forged=JSON.parse(original);var l=forged.state.live;l.minute=80;l.finished=true;l.paused=false;l.halftime=true;l.flow={...l.flow,period:2,firstEnd:40,fullEnd:80,ballDead:true,atBreak:false,advantage:null};l.winner=l.pair[0];l.decision={method:'redCards',extraTime:true,redCards:[0,1]};forged.checksum=saveChecksum(forged.state);");
assert.throws(()=>h.run('parseSaveDocument(JSON.stringify(forged))'),/France30/,'prolongation fictive et cartons inventés refusés');install(h.run('original'));rejected(h.run('JSON.stringify(forged)'));
h.run('S.live.minute=80;S.live.flow.period=2;S.live.flow.firstEnd=40;S.live.flow.fullEnd=80;S.live.halftime=true;finishRugbyMatch(S.live)');
for(const end of [90,100]){h.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");S.live.minute='+end+';S.live.flow.ballDead=true;finishRugbyMatch(S.live)');}
h.run('validateCareer(S);var completed=JSON.stringify(createSaveDocument())');assert.equal(h.state().live.decision.extraTime,true);assert.equal(h.state().live.knockout.period,2);
install(h.run('completed'));
for(const mutate of ["l.decision.extraTime=false", "l.decision.redCards=[1,1]", "l.knockout.period=1;l.knockout.firstEnd=null;l.flow.fullEnd=l.knockout.regulationEnd+10;l.minute=l.flow.fullEnd;l.restartLog=l.restartLog.filter(r=>r.cause!=='extra-second')", "l.restartLog=l.restartLog.filter(r=>r.cause!=='extra-second')"]){
 h.run('forged=JSON.parse(completed);l=forged.state.live;');h.run(mutate);h.run('forged.checksum=saveChecksum(forged.state)');assert.throws(()=>h.run('parseSaveDocument(JSON.stringify(forged))'),/France30/,'altération refusée : '+mutate);rejected(h.run('JSON.stringify(forged)'));
}
h.run('pendingSave=parseSaveDocument(completed);if(!confirmSaveImport())throw Error("import");validateCareer(S)');bridge.close();
console.log('Import éliminatoires : temps supplémentaires réels, deux reprises, cartons de feuille et export/reprise PASS');
