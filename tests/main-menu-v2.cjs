'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const g=context();g.run('render()');
const check=(name,fn)=>{fn();console.log('PASS '+name)};
check('guided creation launches a new active independent slot',()=>{
 assert.equal(g.run('entryScreen'),'menu');
 g.run('mainMenuNewCareer()');
 assert.match(g.app.innerHTML,/Choisissez votre club/);
 assert.equal(g.run("mainMenuChooseMode('world-champ')"),true);
 assert.equal(g.run('entryScreen'),'clubs');
 g.run('mainMenuStartWorld(0)');
 assert.equal(g.run('CDMenuSlots.list().items.length'),1);
 assert.equal(g.run('CDMenuSlots.list().items[0].id===CDMenuSlots.list().active'),true);
 assert.ok(g.store['bdt-v1']);
});
check('changing the current career autosaves the chosen slot',()=>{
 g.run('S.trust=77');
 const web=require('./helpers/ui-save-codec.cjs').webSaveContext(g.state(),g.run('gameStorage'),g.run('CDMenuSlots'));
 web.run('save()');assert.equal(web.ctx.lastSaveError,false);
 const id=g.run('CDMenuSlots.list().active');
 assert.equal(g.run('CDMenuSlots.restore(CDMenuSlots.list().active).trust'),77);
 assert.ok(g.store['cd-career-slot-v2:'+id]);
});
check('new game preserves previous slot and creates a second one',()=>{
 const first=g.run('CDMenuSlots.list().items[0].id');
 g.run('returnToMainMenu()');
 g.run('mainMenuNewCareer()');
 assert.equal(g.run("mainMenuChooseMode('world-champ')"),true);
 assert.match(g.app.innerHTML,/Conserver et continuer/);
 assert.equal(g.run('mainMenuConfirmNewCareer()'),true);
 assert.equal(g.run('S'),null);
 assert.equal(g.run('entryScreen'),'clubs');
 g.run('mainMenuStartWorld(1)');
 assert.equal(g.run('S.club'),1);
 assert.equal(g.run('CDMenuSlots.list().items.length'),2);
 assert.equal(g.run('CDMenuSlots.restore('+JSON.stringify(first)+').club'),0);
});
check('slot restoration uses existing review and restores exactly the selected career',()=>{
 g.run('returnToMainMenu()');
 const first=g.run('CDMenuSlots.list().items[0].id');
 assert.equal(g.run('mainMenuSlotOpen('+JSON.stringify(first)+')'),true);
 assert.match(g.app.innerHTML,/Remplacer et reprendre|Restaurer cette copie/);
 assert.equal(g.run('S.club'),1);
 assert.equal(g.run('confirmSaveImport()'),true);
 assert.equal(g.run('S.club'),0);
 assert.equal(g.run('CDMenuSlots.list().active'),first);
 assert.equal(g.run('entryScreen'),'game');
});
check('corrupted slot never replaces the current or canonical save',()=>{
 const first=g.run('CDMenuSlots.list().items[0].id');
 const snapshot=g.run('JSON.stringify(S)'),disk=g.store['bdt-v1'];
 g.run('returnToMainMenu()');
 g.store['cd-career-slot-v2:'+first]='{"version":2,"checksum":"bad","state":{}}';
 assert.equal(g.run('mainMenuSlotOpen('+JSON.stringify(first)+')'),false);
 assert.ok(g.run('JSON.stringify(S)')===snapshot,'état Monde inchangé');
 assert.ok(g.store['bdt-v1']===disk,'sauvegarde Monde inchangée');
});
check('deleting an archive never removes the active canonical career',()=>{
 const second=g.run('CDMenuSlots.list().items[1].id');
 assert.equal(g.run('mainMenuSlotDelete('+JSON.stringify(second)+')'),true);
 assert.match(g.app.innerHTML,/Cette action supprime cette copie/);
 assert.equal(g.run('mainMenuSlotConfirmDelete('+JSON.stringify(second)+')'),true);
 assert.ok(g.store['bdt-v1']);
 assert.equal(g.run('CDMenuSlots.list().items.length'),1);
});
check('pause is non-destructive and reduced motion is persisted separately',()=>{
 g.run('mainMenuContinue()');
 const before=g.run('JSON.stringify(S)');
 assert.equal(g.run('openPauseMenu()'),true);
 assert.match(g.app.innerHTML,/Menu pause/);
 assert.ok(g.run('JSON.stringify(S)')===before,'état Monde inchangé');
 g.run('returnToMainMenu()');
 g.run("mainMenuMotion('reduced')");
 assert.equal(g.store['cd-menu-motion-v1'],'reduced');
 assert.equal(g.run('mainMenuReadMotion()'),'reduced');
});
check('legacy mode and invalid club refusals preserve career, storage and random stream',()=>{
 const state=g.run('JSON.stringify(S)'),disk=JSON.stringify(g.store),seed=g.seed();
 for(const mode of ['fiction','lnr','france','common','world','world-nationale'])assert.equal(g.run('mainMenuChooseMode('+JSON.stringify(mode)+')'),false);
 for(const id of [-1,56,57,116,'0'])assert.equal(g.run('mainMenuStartWorld('+JSON.stringify(id)+')'),false);
 assert.ok(g.run('JSON.stringify(S)')===state);assert.ok(JSON.stringify(g.store)===disk);assert.equal(g.seed(),seed);
 const provider=g.ctx.startWorld;delete g.ctx.startWorld;
 g.run('mainMenuNewCareer()');assert.match(g.app.innerHTML,/role="alert"/);assert.match(g.app.innerHTML,/indisponible/);
 assert.equal(g.run("mainMenuChooseMode('world-champ')"),false);assert.equal(g.run('mainMenuStartWorld(0)'),false);
 assert.ok(g.run('JSON.stringify(S)')===state);assert.ok(JSON.stringify(g.store)===disk);assert.equal(g.seed(),seed);g.ctx.startWorld=provider;
});
check('slot codec preserves exact UTF-8 bounds, unknown editions and atomic failures',()=>{
 const fs=require('node:fs'),crypto=require('node:crypto');
 const pure=require('./helpers/ui-save-codec.cjs').context();pure.ctx.slotCap=g.run('CDWorldCareer.edition(S).limits.saveBytes');
 pure.run("const CDWorldCareer={active:s=>s?.worldMode?.version===5&&s.worldMode.catalogue==='slot-codec',edition:()=>({limits:{saveBytes:slotCap}})};var slotDraws=0;var originalRandom=Math.random;Math.random=()=>{slotDraws++;return originalRandom()}");
 pure.run(fs.readFileSync(__dirname+'/../dist/main-menu-slots.js','utf8'));
 const fingerprint=()=>Object.fromEntries(Object.entries(pure.store).map(([k,v])=>[k,crypto.createHash('sha256').update(v).digest('hex')]));
 function sized(world,bytes){const state={...(world?{worldMode:{version:5,catalogue:'slot-codec'}}:{}),padding:''};const missing=bytes-Buffer.byteLength(JSON.stringify(state));state.padding='é'.repeat(Math.floor(missing/2))+(missing%2?'a':'');assert.equal(Buffer.byteLength(JSON.stringify(state)),bytes);return state;}
 for(const [world,cap] of [[false,5*1024*1024],[true,pure.ctx.slotCap]]){
  for(const bytes of [cap-1,cap]){pure.ctx.slotState=sized(world,bytes);const id=pure.run("CDMenuSlots.create('Borne',slotState)");assert.equal(Buffer.byteLength(JSON.stringify(pure.run('CDMenuSlots.restore('+JSON.stringify(id)+')'))),bytes);pure.run('CDMenuSlots.remove('+JSON.stringify(id)+')');}
  const before=fingerprint(),draws=pure.run('slotDraws');pure.ctx.slotState=sized(world,cap+1);
  assert.throws(()=>pure.run("CDMenuSlots.create('Trop grand',slotState)"),/volumineuse/);assert.deepEqual(fingerprint(),before);assert.equal(pure.run('slotDraws'),draws);
 }
 const before=fingerprint(),draws=pure.run('slotDraws');pure.ctx.slotState={worldMode:{version:99,catalogue:'unknown'}};
 assert.throws(()=>pure.run("CDMenuSlots.create('Inconnue',slotState)"),/inconnue/);assert.deepEqual(fingerprint(),before);assert.equal(pure.run('slotDraws'),draws);
 pure.run("var slotSet=gameStorage.setItem;gameStorage.setItem=(k,v)=>{if(k==='cd-career-slots-v2')throw Error('quota index');slotSet(k,v)}");
 assert.throws(()=>pure.run("CDMenuSlots.create('Erreur index',{padding:'valide'})"),/quota index/);assert.deepEqual(fingerprint(),before);
});
