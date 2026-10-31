'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const g=context();
const check=(name,fn)=>{fn();console.log('PASS '+name)};
check('guided creation launches a new active independent slot',()=>{
 assert.equal(g.run('entryScreen'),'menu');
 g.run('mainMenuNewCareer()');
 assert.match(g.app.innerHTML,/Choisissez votre univers/);
 assert.equal(g.run("mainMenuChooseMode('fiction')"),true);
 assert.equal(g.run('entryScreen'),'clubs');
 g.run('start(0)');
 assert.equal(g.run('CDMenuSlots.list().items.length'),1);
 assert.equal(g.run('CDMenuSlots.list().items[0].id===CDMenuSlots.list().active'),true);
 assert.ok(g.store['bdt-v1']);
});
check('changing the current career autosaves the chosen slot',()=>{
 g.run('S.trust=77;save()');
 const id=g.run('CDMenuSlots.list().active');
 assert.equal(g.run('CDMenuSlots.restore(CDMenuSlots.list().active).trust'),77);
 assert.ok(g.store['cd-career-slot-v2:'+id]);
});
check('new game preserves previous slot and creates a second one',()=>{
 const first=g.run('CDMenuSlots.list().items[0].id');
 g.run('returnToMainMenu()');
 g.run('mainMenuNewCareer()');
 assert.equal(g.run("mainMenuChooseMode('fiction')"),true);
 assert.match(g.app.innerHTML,/Conserver et continuer/);
 assert.equal(g.run('mainMenuConfirmNewCareer()'),true);
 assert.equal(g.run('S'),null);
 assert.equal(g.run('entryScreen'),'clubs');
 g.run('start(1)');
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
 g.store['cd-career-slot-v2:'+first]='{"version":2,"checksum":"bad","state":{}}';
 g.run('returnToMainMenu()');
 assert.equal(g.run('mainMenuSlotOpen('+JSON.stringify(first)+')'),false);
 assert.equal(g.run('JSON.stringify(S)'),snapshot);
 assert.equal(g.store['bdt-v1'],disk);
});
check('deleting an archive never removes the active canonical career',()=>{
 const second=g.run('CDMenuSlots.list().items[1].id');
 assert.equal(g.run('mainMenuSlotDelete('+JSON.stringify(second)+')'),true);
 assert.match(g.app.innerHTML,/Supprimer cette copie/);
 assert.equal(g.run('mainMenuSlotConfirmDelete('+JSON.stringify(second)+')'),true);
 assert.ok(g.store['bdt-v1']);
 assert.equal(g.run('CDMenuSlots.list().items.length'),1);
});
check('pause is non-destructive and reduced motion is persisted separately',()=>{
 g.run('mainMenuContinue()');
 const before=g.run('JSON.stringify(S)');
 assert.equal(g.run('openPauseMenu()'),true);
 assert.match(g.app.innerHTML,/Menu pause/);
 assert.equal(g.run('JSON.stringify(S)'),before);
 g.run('returnToMainMenu()');
 g.run("mainMenuMotion('reduced')");
 assert.equal(g.store['cd-menu-motion-v1'],'reduced');
 assert.equal(g.run('mainMenuReadMotion()'),'reduced');
});
