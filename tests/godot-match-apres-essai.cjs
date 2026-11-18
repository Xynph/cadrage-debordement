'use strict';
// Après l'essai et coups de pied placés (vue 3D, sans moteur ni carrière, sans bibliothèque
// d'animations) : marqueur relevé et entouré de ses partenaires, défenseurs qui rentrent vers leur
// en-but, arbitre qui accorde l'essai bras tendu, places de la transformation (loi 8), tirs au but
// filmés dans l'axe (buteur et deux poteaux à l'image, ballon suivi jusqu'aux perches).
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Après l’essai : scène vivante, arbitre, transformation dans l’axe',{skip:!godot&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 const env={...process.env};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU'])delete env[name];
 const run=spawnSync(godot,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-apres-essai.gd')],{encoding:'utf8',windowsHide:true,timeout:180000,env});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 if(run.error)throw run.error;
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_APRES_ESSAI_CHECKS \d+ failures=0/);
});
