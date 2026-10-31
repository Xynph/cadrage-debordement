'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const {context}=require('./harness.cjs');
const root=path.resolve(__dirname,'..','dist');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const squad=fs.readFileSync(path.join(root,'manager-squad.js'),'utf8');
const css=fs.readFileSync(path.join(root,'ui02-player-components.css'),'utf8');
assert.ok(html.includes('<link rel="stylesheet" href="ui01-integration.css"><link rel="stylesheet" href="ui02-player-components.css">'));
for(const file of ['ui02-player-data.js','ui02-player-components.js','ui02-player-controller.js']){
 assert.ok(html.includes('<script src="'+file+'"></script>'));
}
assert.ok(html.includes('<script src="ui-preferences.js"></script><script src="game.js"></script>'));
assert.ok(squad.includes("return tabs+rugbyTeam()"));
assert.ok(squad.includes("squadTab==='profile'"));
assert.ok(css.includes('cd02-roster-stack'));
const g=context();
for(const file of ['ui02-player-data.js','ui02-player-components.js','ui02-player-controller.js']){
 vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),g.ctx,{filename:file});
}
vm.runInContext(fs.readFileSync(path.join(root,'ui-preferences.js'),'utf8'),g.ctx,{filename:'ui-preferences.js'});
g.run('start(0)');
assert.match(g.app.innerHTML,/ui01-appbar/);
g.run("nav('team')");
assert.match(g.app.innerHTML,/cd02-roster/);
assert.match(g.app.innerHTML,/cd02-player-link/);
assert.match(g.app.innerHTML,/cd02-training/);
assert.match(g.app.innerHTML,/data-ui02-compare="0"/);
const base=g.run('JSON.stringify(S)'),save=g.store['bdt-v1'];
const playerId=g.run('club().players[0].id');
const pBefore=g.run('JSON.stringify(club().players[0])');
assert.ok(g.run('ui02ShowPlayer('+JSON.stringify(playerId)+')'));
assert.equal(g.run('squadTab'),'profile');
assert.match(g.app.innerHTML,/cd02-player/);
assert.match(g.app.innerHTML,/role="tablist"/);
assert.match(g.app.innerHTML,/NOTE AU POSTE/);
for(const tab of ['profil','attributs','contrat','progression']){
 assert.ok(g.run('ui02SetTab('+JSON.stringify(tab)+')'));
 assert.match(g.app.innerHTML,/role="tabpanel"/);
 assert.match(g.app.innerHTML,new RegExp('data-cd02-tab="'+tab+'" aria-selected="true"'));
}
assert.match(g.app.innerHTML,/Aucun historique de progression enregistré|Historique/);
g.run('ui02Back()');
assert.equal(g.run('squadTab'),'table');
assert.match(g.app.innerHTML,/cd02-roster/);
assert.ok(g.run('ui02SetPreset("contracts")'));
assert.match(g.app.innerHTML,/Salaire \/ semaine/);
assert.ok(g.run('ui02SetColumns(["name","salary","physical"])'));
assert.ok(g.app.innerHTML.includes('Colonnes personnalisées'));
assert.ok(g.app.innerHTML.includes('Charge physique'));
assert.equal(JSON.parse(g.store['cd-ui02-columns-v1']).columns.join(','),'name,salary,physical');
assert.ok(g.run('ui02Sort("salary")'));
assert.equal(g.run('ui02SortKey'),'salary');
assert.ok(!g.run('ui02Sort("__proto__")'));
assert.ok(g.run('ui02SetSlot("0")'));
assert.ok(!g.run('ui02SetSlot("15")'));
assert.ok(g.run('ui02SetSlot("all")'));
g.run('ui02Search("XXXXXXXXXX")');
assert.match(g.app.innerHTML,/Aucun joueur ne correspond/);
g.run('ui02Search("")');
assert.ok(g.run('ui02SelectCompare(0,club().players[0].id)'));
assert.ok(g.run('ui02SelectCompare(1,club().players[1].id)'));
assert.match(g.app.innerHTML,/cd02-comparison/);
assert.match(g.app.innerHTML,/Comparer les profils/);
g.run('ui02Compare=[null,null];render()');
assert.match(g.app.innerHTML,/data-ui02-compare="1"/);
g.run('squadTab="sheet";render()');
assert.match(g.app.innerHTML,/Le XV de départ/);
assert.equal(g.run('S.lineup.length'),15);
assert.equal(g.run('S.reserves.length'),8);
g.run('squadTab="depth";render()');
assert.match(g.app.innerHTML,/Couverture|APT(E|ES)/);
g.run('squadTab="planning";render()');
assert.match(g.app.innerHTML,/Plan sur 3 saisons|succession|Saison/i);
g.run("squadTab='table';render()");
assert.equal(g.run('JSON.stringify(club().players[0])'),pBefore,'player projection mutated native source');
assert.equal(g.run('JSON.stringify(S)'),base,'pure presentation changed career');
assert.equal(g.store['bdt-v1'],save,'preferences overwrote career save');
// Storage-denial fallback: selection remains active and the user sees the failure.
g.ctx.localStorage.setItem=()=>{throw Error('Quota')};
assert.ok(g.run('ui02SetColumns(["name","condition"])'));
assert.equal(g.run('ui02StorageError'),true);
assert.match(g.app.innerHTML,/Préférences de colonnes non enregistrées/);
const savedState=JSON.parse(base);
const restored=context(savedState);
assert.ok(restored.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
g.run("nav('match');beginMatch();pauseMatch();render()");
assert.match(g.app.innerHTML,/v40-cockpit/);
assert.doesNotMatch(g.app.innerHTML,/cd02-player/);
// The original harness, without opt-in scripts, must still expose its legacy table.
const legacy=context();
legacy.run('start(0);nav("team")');
assert.match(legacy.app.innerHTML,/manager-squad-table/);
console.log(JSON.stringify({passed:true,checks:[
 'UI01 scripts and session css kept','real in-game roster','full-screen player',
 'four tabs','native attributes','column presets and persistence','search and slot filters',
 'two-player comparison','native training panel','15+8 team sheet preserved',
 'depth and planning','no mutation of career','save roundtrip','storage denial visible',
 'V40 cockpit','legacy harness fallback']}));