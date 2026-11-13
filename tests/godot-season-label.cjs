'use strict';
// Libellé de saison dans Godot : la formule de l'interface et celle du moteur donnent les mêmes valeurs.
const assert=require('node:assert/strict'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP godot-season-label : SDK Godot absent.');process.exit(0);}
const {libelleSaison}=require('../dist/season-label.js');
assert.equal(libelleSaison(1),'2026-2027');assert.equal(libelleSaison(2),'2027-2028');
const run=spawnSync(godot,['--headless','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-season-label.gd')],{encoding:'utf8',timeout:120000});
const log=(run.stdout||'')+(run.stderr||'');console.log(log);
if(run.error)throw run.error;assert.equal(run.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|FAIL:/);
console.log('Libellé de saison Godot PASS');
