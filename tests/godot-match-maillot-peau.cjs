'use strict';
// Maillots et carnations : une tenue couleur chair (Meadowbridge, #a46e44) ne fait plus paraître les joueurs torse nu.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs');
test('Tenues du match : écart minimal avec les carnations, teinte du club conservée (source)',()=>{
 const kit=fs.readFileSync(path.resolve(__dirname,'../native/godot/match_kit.gd'),'utf8');
 // Les carnations comparées sont celles des modèles des joueurs, pas une copie qui pourrait diverger.
 assert.match(kit,/preload\("res:\/\/match_athlete\.gd"\)/);
 assert.match(kit,/for tone in Athlete\.SKINS/);
 assert.match(kit,/var home := skin_safe\(colors\[0\]\)/);
 assert.match(kit,/var away_club := skin_safe\(colors\[1\]\)/);
 assert.match(kit,/_trim\(home, /);
});
test('Tenues du match : écart minimal avec les carnations, teinte du club conservée',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--path',project,'--script',path.resolve(__dirname,'godot-match-maillot-peau.gd')],{encoding:'utf8',windowsHide:true,timeout:60000});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.match(output,/MATCH_MAILLOT_PEAU_CHECKS \d+ failures=0/);
});
