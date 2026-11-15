'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
function ready(snapshot){
 const g=context(snapshot);for(const f of ['lnr-rosters-base.js','lnr-career.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),g.ctx);return g;
}
const g=ready(),run=g.run;
try{
 assert.equal(run('LNR_CATALOGUE.clubs.length'),30);
 assert.equal(run('LNR_TOP14.length'),14);assert.equal(run('LNR_PROD2.length'),16);
 assert.equal(run('LNR_CATALOGUE.clubs.reduce((n,c)=>n+c[3].length,0)'),1592);
 assert.equal(run('new Set(LNR_CATALOGUE.clubs.flatMap(c=>c[3].map(p=>p[0]))).size'),1592);
 g.start(0);
 assert.equal(run('S.lnrMode'),undefined);assert.equal(run('S.worldMode.version'),5);
 assert.equal(run('S.clubs.length'),116,'les trente clubs français vivent dans le Monde complet');
 const initial=g.state(),registry=JSON.parse(run('JSON.stringify(CDWorldEditions.forState(S).registry)'));
 for(const c of registry.clubs.slice(0,30)){
  assert.equal(initial.clubs[c.id].name,c.name,'identité publique de la bonne édition');
  assert.ok(c.players.every(p=>initial.clubs[c.id].players.some(q=>q.id===p.id)),'effectif initial complet de la bonne édition');
 }
 assert.equal(run(`(()=>{const registry=CDWorldEditions.forState(S).registry,ids=new Set(S.clubs.flatMap(c=>c.players).map(p=>p.id));return LNR_CATALOGUE.clubs.flatMap(c=>c[3]).every(p=>ids.has(registry.compatibilityAliases?.[p[0]]?.canonicalId??p[0]));})()`),true,'1592 références françaises résolues dans l’édition active, y compris les doublons fusionnés');
 g.toMatch();
 assert.equal(run('sheetErrors().length'),0,'XV et huit remplaçants qualifiés');
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 run("nav('team')");assert.doesNotMatch(g.app.innerHTML,/Catalogue LNR|Paramètres fictifs/,'aucune entrée de carrière retirée dans le Monde');
 const state=run('JSON.stringify(S)'),stored=g.store['bdt-v1'];
 run('lnrBrowseClub(16)');
 assert.equal(run('JSON.stringify(S)'),state);assert.equal(g.store['bdt-v1'],stored);
 assert.equal(run('lnrBrowseIndex'),16);
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 const restored=ready(JSON.parse(state));try{
  assert.equal(restored.run('S.lnrMode'),undefined);assert.equal(restored.run('S.worldMode.version'),5);
  assert.ok(restored.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 }finally{restored.close();}
 run("S.clubs[0].name='Club inventé'");assert.throws(()=>run('validateCareer(S)'),'identité de club non vérifiée refusée');
 g.ctx.referenceState=state;run('S=JSON.parse(referenceState)');
 run("S.worldMode.catalogue='edition-non-verifiee'");assert.throws(()=>run('validateCareer(S)'),'édition historique non vérifiée refusée');
 run('S=JSON.parse(referenceState);delete globalThis.referenceState');
 console.log('MONDE CATALOGUE PASS : 30 clubs français, 1592 IDs, 116 clubs jouables, reprise, consultation et falsifications');
}finally{g.close();}
