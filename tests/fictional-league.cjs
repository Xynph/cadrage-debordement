'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {context}=require('./harness.cjs');
const catalog=require('../world-data/r1/fr-2026-2027.json');
const demo=context(),run=demo.run;
const names=JSON.parse(run('JSON.stringify(CLUBS.map(c=>c[0]))'));
assert.equal(names.length,14);
assert.equal(new Set(names).size,14);
assert.deepEqual(names,catalog.clubs.slice(0,14).map(c=>c.name));
assert.ok(names.every(n=>!['Stade Toulousain','Union Bordeaux-Bègles','Racing 92','RC Toulon'].includes(n)));
assert.ok(!demo.app.innerHTML.includes('Stade Toulousain'));
run('mainMenuNewCareer()');run("mainMenuChooseMode('fiction')");assert.ok(demo.app.innerHTML.includes('Stade des Brumes'));
run('start(0)');
assert.equal(run('club().name'),names[0]);
assert.equal(run('S.clubs.length'),14);
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
// Une sauvegarde historique garde son nom sérialisé, même si les nouveaux clubs changent.
run('S.clubs.forEach((c,i)=>{c.name=LEGACY_CLUB_NAMES[i];c.abbr=LEGACY_CLUB_ABBR[i]})');
const historical=run('JSON.stringify(createSaveDocument())');
assert.equal(run('parseSaveDocument('+JSON.stringify(historical)+').state.clubs[0].name'),
 'Stade Toulousain','ancienne sauvegarde non renommée');
run("S.clubs[0].name='Identité inconnue'");
assert.throws(()=>run('createSaveDocument()'),/incohérentes/,'sauvegarde hostile rejetée');
const game=fs.readFileSync(__dirname+'/../dist/game.js','utf8');
assert.ok(!game.includes('Clubs réels'));
assert.ok(!game.includes('top14.lnr.fr'));
console.log(JSON.stringify({passed:true,clubs:14,checks:['14 clubs fictifs','catalogue R1 cohérent','nouvelle carrière','ancienne carrière inchangée','JSON valide','accueil original']}));
