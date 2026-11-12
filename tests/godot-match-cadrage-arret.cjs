'use strict';
// Plans d'arrêt de jeu en temps forts : jamais d'image sans joueur (défaut de la 75e minute, capture Windows).
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
test('Cadrage des temps forts : coup de sifflet et carton montrent les joueurs, pas l’herbe seule',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const env={...process.env};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU'])delete env[name];
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-cadrage-arret.gd')],{encoding:'utf8',windowsHide:true,timeout:180000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_CADRAGE_ARRET_CHECKS \d+ failures=0/);
});
