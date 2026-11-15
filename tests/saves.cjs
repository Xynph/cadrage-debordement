'use strict';
const assert=require('node:assert/strict');
const {context,engineContext}=require('./harness.cjs');
const t=context(),run=t.run;t.start(0);
let initialState=run('JSON.stringify(S)');const initialSeed=t.seed();
let text=run('JSON.stringify(createSaveDocument())');t.ctx.exportedText=text;
assert.equal(run('parseSaveDocument(exportedText).state.club'),0);
assert.equal(run('saveFileName(createSaveDocument()).endsWith(".json")'),true);
let source=engineContext();source.start(13);
let incoming=source.run('JSON.stringify(createSaveDocument())');source.close();source=null;
t.ctx.incomingText=incoming;
// Copies indépendantes de la même vraie carrière : reprise exacte, même RNG,
// vrais parser/écritures/rendu. Chaque VM est fermée après son cas.
function withUI(fn){const q=context(JSON.parse(initialState));try{assert.ok(q.run('JSON.stringify(S)')===initialState,'fixture de reprise exacte');q.setSeed(initialSeed);q.run('entryScreen="game";view="dashboard";render()');q.ctx.incomingText=incoming;fn(q);}finally{q.close();}}
// Import preview and cancellation leave both current state and stored state unchanged.
let previous=run('JSON.stringify(S)'),stored=t.store['bdt-v1'];
run('pendingSave=parseSaveDocument(incomingText);showImportReview()');
assert.ok(run('JSON.stringify(S)')===previous,'carrière inchangée');assert.ok(t.store['bdt-v1']===stored,'sauvegarde Monde inchangée');
run('cancelSaveImport()');assert.equal(run('pendingSave'),null);assert.ok(run('JSON.stringify(S)')===previous,'carrière inchangée');
run('pendingSave=parseSaveDocument(incomingText);confirmSaveImport()');assert.equal(run('S.club'),13);assert.equal(run('backupDocument().state.club'),0);assert.equal(JSON.parse(t.store['bdt-v1']).club,13);
run('reviewBackup();confirmSaveImport()');assert.equal(run('S.club'),0);assert.equal(run('backupDocument().state.club'),13);
// Live matches are exported consistently and restored paused, with exact score and fitness.
t.start(0);t.toMatch();t.deferSaves();
run('beginMatch();for(var i=0;i<12;i++)tick();var exportLive=createSaveDocument();var liveText=JSON.stringify(exportLive),oldScore=S.live.score.join("-"),oldMinute=S.live.minute,varFitness=JSON.stringify(club().players.map(p=>p.condition))');
assert.equal(run('S.live.paused'),false);
run('start(13);pendingSave=parseSaveDocument(liveText);confirmSaveImport()');t.deferSaves();
assert.equal(run('S.live.paused'),true);assert.equal(run('S.live.score.join("-")'),run('oldScore'));assert.equal(run('S.live.minute'),run('oldMinute'));assert.equal(run('JSON.stringify(club().players.map(p=>p.condition))'),run('varFitness'));
run('tick()');assert.equal(run('S.live.minute'),run('oldMinute'));run('continueMatch();tick()');assert.equal(run('S.live.minute'),run('oldMinute+1'));
// Validation also covers half-time, the result screen and all real World playoffs.
run('fastForward();var half=createSaveDocument()');assert.ok(run('parseSaveDocument(JSON.stringify(half)).state.live.minute>=40'));assert.equal(run('half.state.live.flow.atBreak'),true);
run('continueMatch();while(!S.live.finished){if(S.live.paused)continueMatch();else tick()}');assert.equal(run('parseSaveDocument(JSON.stringify(createSaveDocument())).state.live.finished'),true);
// Recomputed hashes cannot bypass shape, reference or text validation. Payloads
// are data properties, never multi-megabyte source literals retained by the VM.
function rejected(change){const doc=JSON.parse(text);change(doc);t.ctx.hostileText=JSON.stringify(doc);const before=run('JSON.stringify(S)'),disk=t.store['bdt-v1'];
 assert.throws(()=>run('var hostile=JSON.parse(hostileText);hostile.checksum=saveChecksum(hostile.state);parseSaveDocument(JSON.stringify(hostile))'));
 assert.ok(run('JSON.stringify(S)')===before,'carrière inchangée');assert.ok(t.store['bdt-v1']===disk,'sauvegarde Monde inchangée');run('hostile=null');t.ctx.hostileText=null;
}
for(const change of [
 d=>d.state.clubs[0].players[0].name='<img src=x onerror=alert(1)>',
 d=>d.state.clubs[0].players[0].id="x');alert(1);//",
 d=>d.state.clubs[0].players[0].name='x" onfocus="alert(1)',
 d=>d.state.club=116,d=>d.state.phase='unexpected',d=>d.state.clubs[0].players[0].rating=null,
 d=>d.state.clubs[0].players[0].dev=null,d=>d.state.economy.offers={},d=>d.state.development.academy=null,
 d=>{const pairs=d.state.schedule.find(pairs=>pairs.length>1);assert.ok(pairs,'journée World avec plusieurs rencontres');pairs[0]=pairs[1]},d=>d.state.lineup[0]='missing-player',
 d=>d.state.clubs[1].players[0].id=d.state.clubs[0].players[0].id,
 d=>d.state.clubs[0].players[0].dev.potential=1,d=>d.state.economy.talks={bad:{}},
 d=>Object.defineProperty(d.state,'__proto__',{value:{polluted:true},enumerable:true})
])rejected(change);
assert.throws(()=>run('parseSaveDocument("{bad")'));assert.throws(()=>run('parseSaveDocument(" ".repeat(SAVE_LIMIT+1))'));
{const baseline=JSON.parse(text);baseline.exportVersion=999;t.ctx.badText=JSON.stringify(baseline);assert.throws(()=>run('parseSaveDocument(badText)'));}
{const broken=JSON.parse(text);broken.state.clubs[0].cash++;t.ctx.badText=JSON.stringify(broken);assert.throws(()=>run('parseSaveDocument(badText)'));}t.ctx.badText=null;
// Storage failures before backup or replacement preserve the open career.
for(const failureKey of ['bdt-before-import','bdt-v1'])withUI(q=>{
 const snapshot=q.run('JSON.stringify(S)'),disk=q.store['bdt-v1'];q.ctx.failureKey=failureKey;
 q.run('pendingSave=parseSaveDocument(incomingText);var originalSet=localStorage.setItem;localStorage.setItem=(k,v)=>{if(k===failureKey)throw Error("quota");originalSet(k,v)}');
 try{assert.equal(q.run('confirmSaveImport()'),false);assert.ok(q.run('JSON.stringify(S)')===snapshot,'carrière inchangée');assert.ok(q.store['bdt-v1']===disk,'sauvegarde Monde inchangée');}finally{q.run('localStorage.setItem=originalSet');}
});
// New browsers restore from the welcome screen without starting another career.
{const blank=context();try{blank.ctx.incomingText=incoming;blank.run('pendingSave=parseSaveDocument(incomingText);showImportReview()');assert.equal(blank.run('S'),null);assert.equal(blank.run('confirmSaveImport()'),true);assert.equal(blank.run('S.club'),13);}finally{blank.close();}}
// A malformed local career leaves the welcome/import controls reachable.
{const corrupt=context();try{corrupt.ctx.corruptText=JSON.stringify({version:2,clubs:[]});corrupt.run('gameStorage.setItem("bdt-v1",corruptText);loadedSaveText=corruptText;S=JSON.parse(corruptText);validatingStartup=true;bootSavedCareer()');assert.equal(corrupt.run('S'),null);assert.ok(corrupt.run('loadSaveFailure'));assert.ok(corrupt.store['bdt-recovery-invalid']);assert.ok(corrupt.app.innerHTML.includes('Importer une carrière JSON'));}finally{corrupt.close();}}
// A valid preview grants no permanent trust to later changes.
for(const tamper of ['pendingSave.state.clubs[pendingSave.state.club].cash+=1','pendingSave.state.morale=pendingSave.state.morale===0?1:0','pendingSave.checksum="00000000"'])withUI(q=>{
 const before=q.run('JSON.stringify(S)'),disk=q.store['bdt-v1'],backup=q.store['bdt-before-import'];
 q.run('pendingSave=parseSaveDocument(incomingText);showImportReview();'+tamper);
 assert.equal(q.run('confirmSaveImport()'),false,'tampered preview must not be committed');assert.ok(q.run('JSON.stringify(S)')===before,'carrière inchangée');assert.ok(q.store['bdt-v1']===disk,'sauvegarde Monde inchangée');assert.equal(q.store['bdt-before-import'],backup);
});
withUI(q=>{const initial=q.run('JSON.stringify(S)');q.run('pendingSave=parseSaveDocument(incomingText);showImportReview()');assert.equal(q.run('confirmSaveImport()'),true);assert.equal(q.run('S.club'),13);assert.ok(q.run('JSON.stringify(backupDocument().state)')===initial,'secours exact');});
// Libérer les gros instantanés déjà vérifiés avant la progression longitudinale.
initialState=text=incoming=previous=stored=null;t.ctx.exportedText=t.ctx.incomingText=null;run('exportLive=null;liveText=null;half=null');
console.log('PASS sauvegardes : direct, mi-temps, imports, hostilité et erreurs atomiques');
// Real integrated season, including every weekly export and all World playoffs.
t.week();let weeks=0;while(run('S.phase')!=='ended'){assert.ok(++weeks<=46);t.week();assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);}assert.equal(run('S.phase'),'ended');
console.log('PASS sauvegardes : vraie saison Monde terminée');
// The former ten forged offseasons did not play matches. Preserve the metadata
// codec boundary as ten explicitly pure cycles, separate from the season above.
const nativeBefore=run('JSON.stringify(S)'),nativeDisk=t.store['bdt-v1'],nativeSeed=t.seed();
const codec=require('./helpers/ui-save-codec.cjs').context();codec.ctx.campaignFixture=nativeBefore;
// Vrais lecteurs et validateurs de données : le codec garde les budgets séparés
// connaissance/potentiel, les références de registre et la limite de l'édition.
codec.ctx.campaignCareer=run('({active:CDWorldCareer.active,edition:CDWorldCareer.edition,sourcePlayer:CDWorldCareer.sourcePlayer,sizing:CDWorldCareer.sizing})');
codec.ctx.CDRosterFoundation=run('CDRosterFoundation');
codec.ctx.nativePotentialEvolutionValidate=t.ctx.nativePotentialEvolutionValidate;
codec.ctx.nativeKnowledgeValidate=t.ctx.nativeKnowledgeValidate;
codec.run("const CDWorldCareer=campaignCareer;validateCareer=s=>safeTree(s);var metadataState=JSON.parse(campaignFixture);delete globalThis.campaignFixture");
assert.equal(codec.run('CDWorldCareer.edition(metadataState).version'),5);
for(let y=0;y<10;y++){
 codec.run('metadataState.season='+(y+2)+';var metadataDocument=createSaveDocument(metadataState);var metadataText=JSON.stringify(metadataDocument)');
 assert.equal(codec.run('parseSaveDocument(metadataText).state.season'),y+2);assert.ok(codec.run('JSON.stringify(parseSaveDocument(metadataText).state)')===codec.run('JSON.stringify(metadataState)'),'métadonnées conservées exactement');assert.ok(codec.run('saveFileName(metadataDocument)').includes('-S'+(y+2)+'-'));
}
assert.ok(run('JSON.stringify(S)')===nativeBefore,'cycles purs sans mutation de carrière');assert.ok(t.store['bdt-v1']===nativeDisk,'cycles purs sans écriture de carrière');assert.equal(t.seed(),nativeSeed,'cycles purs sans tirage natif');

t.close();
console.log(JSON.stringify({passed:true,checks:['export/import round trip','non-mutating preview and cancellation','recoverable replacement','paused live-game restoration','halftime and playoffs','ten pure long-career metadata exports','corrupted and oversized JSON','unsupported formats','hostile text and identifiers','cross-club duplicates and broken references','quota failure rollback','welcome-screen import','corrupt local-startup recovery']}));
