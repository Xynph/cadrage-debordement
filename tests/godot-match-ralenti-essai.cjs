'use strict';
// Ralenti de l'essai (vue 3D, sans moteur ni carrière, sans bibliothèque d'animations) : environ la
// moitié de la vitesse réelle, au plus 4 s ajoutées, seulement pour un essai et jamais avec les
// animations réduites ; caméra basse sur le côté (autre angle que la vue TV) ; mention « RALENTI »
// discrète en haut à droite ; vue suspendue pendant le ralenti puis état d'avant remis à l'identique
// (célébration, arbitre, caméra), un seul ralenti par essai, abrégeable.
// Parcours réel d'une carrière Monde : godot-match-grands-moments.cjs (godot-match-temps-forts.gd,
// mode « grands_moments ») contrôle aussi la mention et la durée sur les vrais essais.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Ralenti de l’essai : autre angle, état d’avant remis, mention RALENTI',{skip:!godot&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const env={...process.env};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU'])delete env[name];
 const run=spawnSync(godot,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-ralenti-essai.gd')],{encoding:'utf8',windowsHide:true,timeout:180000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_RALENTI_ESSAI_CHECKS \d+ failures=0/);
});
