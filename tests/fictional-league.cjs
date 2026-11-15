'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {context}=require('./harness.cjs');
const catalog=require('../world-data/r1/fr-2026-2027.json');
const demo=context(),run=demo.run;
try{
 // Le catalogue historique reste une donnée pure ; aucune carrière de ce mode.
 const names=JSON.parse(run('JSON.stringify(CLUBS.map(c=>c[0]))'));
 assert.equal(names.length,14);assert.equal(new Set(names).size,14);
 assert.deepEqual(names,catalog.clubs.slice(0,14).map(c=>c.name));
 assert.ok(names.every(n=>!JSON.parse(run('JSON.stringify(LEGACY_CLUB_NAMES)')).includes(n)));
 const menu=demo.app.innerHTML;
 assert.ok(!menu.includes(run('LEGACY_CLUB_NAMES[0]')));
 run('mainMenuNewCareer()');
 assert.equal(run("mainMenuChooseMode('fiction')"),false);
 assert.equal(run("mainMenuChooseMode('world-champ')"),true);
 const publicNames=JSON.parse(run("JSON.stringify(CDWorldEditions.forMode('world-champ').registry.clubs.map(c=>c.name))"));
 assert.ok(demo.app.innerHTML.includes(publicNames[0]));
 run('mainMenuStartWorld(0)');
 assert.equal(run('club().name'),publicNames[0]);assert.equal(run('S.clubs.length'),116);
 assert.equal(run('S.worldMode.version'),5);
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 const historical=run('JSON.stringify(createSaveDocument())');
 // La reprise conserve exactement les identités sérialisées de l'édition active.
 demo.ctx.catalogueSave=historical;
 assert.deepEqual(JSON.parse(run('JSON.stringify(parseSaveDocument(catalogueSave).state.clubs.map(c=>c.name))')),publicNames);
 run("S.clubs[0].name='Identité inconnue'");
 assert.throws(()=>run('createSaveDocument()'),/incohérentes|Monde|identité/,'sauvegarde hostile rejetée');
 const game=fs.readFileSync(__dirname+'/../dist/game.js','utf8');
 assert.ok(!game.includes('Clubs réels'));assert.ok(!game.includes('top14.lnr.fr'));
 console.log(JSON.stringify({passed:true,clubs:116,checks:['catalogue historique pur 14 clubs','catalogue R1 cohérent','menu Monde seul','nouvelle carrière World v5','identités de reprise inchangées','JSON valide','identité hostile refusée','accueil original']}));
}finally{demo.close();}
