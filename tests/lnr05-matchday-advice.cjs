'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {engineContext:context}=require('./harness.cjs');
function boot(){const t=context();for(const f of ['lnr-rosters-base.js','lnr-career.js','lnr05-mesures.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),t.ctx);return t}
test('Monde: aide rotation en lecture seule et compatibilite du mode fictif',()=>{
 const t=boot(),run=t.run;
 assert.equal(run('S'),null,'absence de carrière avant les contrôles de disponibilité');
 assert.equal(run('lnr05AdviceCandidates().length'),0);
 assert.equal(run('lnr05AdviceView()'),'');
 run('start(0)');assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));t.close();
 const g=boot(),r=g.run;
 r("start(0,'world-champ')");
 const old=r('JSON.stringify(S)'),saved=g.store['bdt-v1'];
 const candidates=r('lnr05AdviceCandidates().map(x=>({id:x.id,slot:x.slot,score:x.score,valid:x.proposal.valid}))');
 assert(candidates.length<=3);
 for(const c of candidates){assert(c.valid);assert(c.slot>=0&&c.slot<15);assert(c.score>0)}
 assert.match(r('lnr05AdviceView()'),/Options de rotation avant-match/);
 assert.match(r('lnr05AdviceView()'),/sans confirmation|jusqu’à confirmation/);
 assert.equal(r('JSON.stringify(S)'),old);
 assert.equal(g.store['bdt-v1'],saved);
 assert.ok(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 r('S.live={finished:false}');
 assert.equal(r('lnr05AdviceCandidates().length'),0);
});
