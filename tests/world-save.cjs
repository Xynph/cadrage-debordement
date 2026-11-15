'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {engineContext}=require('./harness.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
const h=engineContext();h.start(0);const initial=h.state(),initialCheckpoint=h.checkpoint();let completed;
function check(s){h.ctx.candidate=s;return h.run('validateCareer(candidate)');}
function document(s){h.ctx.candidate=s;return h.run('JSON.stringify(createSaveDocument(candidate))');}
function parse(text){h.ctx.savedText=text;return h.run('parseSaveDocument(savedText)');}
test('Monde : 116 clubs et calendrier variable répété, export/import borné',()=>{
 assert.doesNotThrow(()=>check(initial));assert.equal(initial.worldMode.version,5);
 const text=document(initial);assert.ok(Buffer.byteLength(text)<h.run('CDWorldCareer.edition(S).limits.saveBytes'));
 assert.equal(parse(text).state.clubs.length,116);
 // La fin de saison se prépare par les vraies semaines, avec toutes les phases finales.
 h.deferSaves();h.season();const ended=h.state();completed=ended;assert.equal(ended.phase,'ended');assert.equal(ended.round,46);assert.doesNotThrow(()=>check(ended));
});
test('Monde : marqueurs, identités, limites et doublons restent stricts',()=>{
 assert.doesNotThrow(()=>check(initial));
 const ordinary=initial.clubs.flatMap(c=>c.players).find(p=>h.run('CDWorldCareer.sourcePlayer(S,'+JSON.stringify(p.id)+')?.age')>15).id;
 const young=initial.clubs.flatMap(c=>c.players).find(p=>h.run('CDWorldCareer.sourcePlayer(S,'+JSON.stringify(p.id)+')?.age')===15).id;
 const attacks=[s=>s.worldMode.version=2,s=>s.worldMode.catalogue='other',s=>s.commonDatabase.extra=true,s=>delete s.commonDatabase,s=>s.worldMode.rules='other',s=>s.franceMode={version:1},s=>s.lnrMode={version:1},s=>s.club=116,s=>s.round=47,s=>s.phase='final',s=>s.clubs.pop(),s=>s.clubs[40].name='Autre identité',s=>s.clubs[40].abbr='OTHER',s=>s.clubs[40].color='#000000',s=>s.clubs[40].form=['W'],s=>s.clubs[40].players[0].id=s.clubs[41].players[0].id,s=>s.clubs.flatMap(c=>c.players).find(p=>p.id===ordinary).age=15,s=>s.clubs.flatMap(c=>c.players).find(p=>p.id===young).age=14,s=>s.worldMode.fixtures=Array(1601).fill(null),s=>s.history=Array(1601).fill({}),s=>s.extra=Array(2001).fill(null)];
 for(const mutate of attacks){const bad=clone(initial);mutate(bad);assert.throws(()=>check(bad),String(mutate));}
});
test('Monde : historique européen et contexte live reconnus, validation spécialisée exigée',()=>{
 h.restore(initialCheckpoint);h.toMatch();h.run('beginMatch();pauseMatch();validateCareer(S)');const live=h.state();assert.ok(live.live);
 for(const mutate of [s=>s.live.worldContext.fixtureId='hostile',s=>s.live.knockout={period:9}]){const bad=clone(live);mutate(bad);assert.throws(()=>check(bad));}
 h.run('continueMatch();while(!S.live.finished){if(S.live.paused)continueMatch();else tick()}');assert.doesNotThrow(()=>parse(document(h.state())));h.week();assert.doesNotThrow(()=>check(h.state()));
 assert.ok(h.run('S.history.length')>0);
 // Résultats européens réels : la validation spécialisée reste exécutée au
 // plafond de l'édition, comme fonction pure, sans inventer de carrière finale.
 const european=completed.history.find(r=>['champions','challenge'].includes(r.competitionId));assert.ok(european);
 const fixture=completed.worldMode.fixtures.find(f=>f.id===european.fixtureId);assert.ok(fixture);
 h.ctx.european=european;h.ctx.europeanFixture=fixture;
 assert.equal(h.run('CDWorldCareer.edition(S).limits.maxMatches'),1600);
 assert.doesNotThrow(()=>h.run('for(let i=0;i<1600;i++)CDWorldValidation.result(european,europeanFixture,null,5)'));

});
test('Monde : préparation et instantanés utilisent la borne mondiale de semaine',()=>{
 h.ctx.candidate=initial;assert.doesNotThrow(()=>h.run('validateCollectiveSnapshot({v:1,season:1,round:46,focus:[Object.keys(COLLECTIVE_FOCI)[0],Object.keys(COLLECTIVE_FOCI)[0]],power:[.8,.8]},candidate)'));
});
test('Monde : un contexte de compétition forgé ne peut pas détourner la fin de match',()=>{
 // Ce cas était déjà natif Monde : conserver tous les championnats détaillés.
 const native=require('./monde-harness.cjs').context().toMatch();
 try{
  native.run('S.live=createRugbyMatch(nextMatch());validateCareer(S)');
  assert.throws(()=>native.run("S.live.worldContext={...S.live.worldContext,id:'forged',fixtureId:'forged',phase:'final',competitionId:'champions'};validateCareer(S)"));
 }finally{native.close();}
});
test('Monde : contrat pur des prolongations et contexte européen, sans carrière finale fabriquée',()=>{
 h.restore(initialCheckpoint);h.toMatch();h.run('beginMatch();pauseMatch();validateCareer(S)');
 const before=h.run('JSON.stringify(S)');h.ctx.pureKnockout=clone(h.state().live);
 h.run(`pureKnockout.worldContext={...pureKnockout.worldContext,phase:'semi',competitionId:'champions'};
  pureKnockout.minute=81;pureKnockout.flow.period=2;pureKnockout.halftime=true;pureKnockout.flow.firstEnd=41;pureKnockout.score=[0,0];
  CDWorldKnockout.finish(pureKnockout,5)`);
 assert.equal(h.run('pureKnockout.knockout.period'),1);
 assert.doesNotThrow(()=>h.run('CDWorldValidation.live(pureKnockout,pureKnockout.worldContext,5)'));
 h.run('pureKnockout.knockout.period=9');assert.throws(()=>h.run('CDWorldValidation.live(pureKnockout,pureKnockout.worldContext,5)'));
 h.run('pureKnockout.knockout.period=1;pureKnockout.worldContext.fixtureId="hostile"');
 assert.throws(()=>h.run('CDWorldValidation.live(pureKnockout,{...pureKnockout.worldContext,fixtureId:"original"},5)'));
 assert.ok(h.run('JSON.stringify(S)')===before,'fonctions pures sans mutation de carrière');
});
function codec(){
 const c=require('./helpers/ui-save-codec.cjs').context();
 c.run("const CDWorldCareer={active:s=>s?.worldMode?.version===5&&s.worldMode.catalogue==='codec-world'&&s.commonDatabase?.id==='codec-world'&&s.commonDatabase.version===5&&Object.keys(s.commonDatabase).length===2,edition:()=>({limits:{saveBytes:24*1024*1024,maxSaveNodes:2600000}})};validateCareer=s=>safeTree(s)");return c;
}
const marker={worldMode:{version:5,catalogue:'codec-world'},commonDatabase:{id:'codec-world',version:5}};
test('Monde : capacité de nœuds isolée, tailles et anciennes limites conservées',()=>{
 const c=codec(),shape=total=>{const tree={...clone(marker),items:[]};let remaining=total-8;while(remaining>1501){tree.items.push(Array(1500).fill(false));remaining-=1501;}if(remaining)tree.items.push(Array(remaining-1).fill(false));return tree;};
 c.ctx.tree=shape(2599999);assert.doesNotThrow(()=>c.run('safeTree(tree)'));c.ctx.tree=shape(2600000);assert.throws(()=>c.run('safeTree(tree)'),/complexe/);
 c.ctx.savedText='é'.repeat(4*1024*1024+1);assert.throws(()=>c.run('parseSaveDocument(savedText)'),/volumineux/);
 const bad=clone(initial);bad.worldMode.version=1;assert.throws(()=>check(bad));
});
test('Monde : import/export 24Mio réservé au marqueur exact, anciennes limites 8Mio conservées',()=>{
 const c=codec(),large={...clone(marker),economy:{freeAgents:[]},market:[],saveLimitNotes:Array.from({length:1450},()=> 'n'.repeat(5999))};c.ctx.candidate=large;
 const text=c.run('JSON.stringify(createSaveDocument(candidate))');assert.ok(Buffer.byteLength(text)>8*1024*1024&&Buffer.byteLength(text)<24*1024*1024);
 c.ctx.savedText=text;assert.doesNotThrow(()=>c.run('parseSaveDocument(savedText)'));
 const ordinary={...large};delete ordinary.worldMode;delete ordinary.commonDatabase;c.ctx.candidate=ordinary;c.ctx.savedText=c.run('JSON.stringify(createSaveDocument(candidate))');assert.throws(()=>c.run('parseSaveDocument(savedText)'),/volumineux/);
 const hostile=JSON.parse(text);hostile.state.commonDatabase.extra=true;c.ctx.savedText=JSON.stringify(hostile);assert.throws(()=>c.run('parseSaveDocument(savedText)'),/volumineux/);
 const huge={...clone(marker),economy:{freeAgents:[]},market:[],saveLimitNotes:Array.from({length:3},()=>Array.from({length:1500},()=> 'n'.repeat(5999)))};c.ctx.candidate=huge;assert.throws(()=>c.run('createSaveDocument(candidate)'),/volumineux/);
 c.ctx.savedText=' '.repeat(24*1024*1024+1);assert.throws(()=>c.run('parseSaveDocument(savedText)'),/volumineux/);
 h.close();
});
