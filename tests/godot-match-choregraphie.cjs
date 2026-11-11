'use strict';
// Chorégraphe de temps forts : la vue 3D suit les pistes du moteur, et sans pistes valides
// elle garde son interpolation (repli). Voir docs/match-choregraphe-20261112.md.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const C=require('../native/engine/match-choregraphe.cjs');
test('Vue 3D : suit les pistes du chorégraphe (joueurs, ballon, porteur), repli sans pistes',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.resolve(__dirname,'../native/godot');
 // Essai du moteur natif (graine 7, 70′ : ballon récupéré, ruck, percée) mis en scène par le chorégraphe.
 const {source,entree}=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures','match-choregraphe-essais.json'),'utf8'))[1];
 const pistes=C.composer(entree);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-choregraphie-godot-'));
 try{
  const fichier=path.join(dir,'pistes.json');
  fs.writeFileSync(fichier,JSON.stringify({source,entree,pistes}));
  const env={...process.env,CD_CHOREGRAPHIE_PISTES:fichier};for(const name of ['CD_MATCH_GESTES','CD_MATCH_ANIMATIONS','CD_MATCH_RENDU'])delete env[name];
  const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'godot-match-choregraphie.gd')],{encoding:'utf8',windowsHide:true,timeout:300000,env});
  const output=(run.stdout||'')+(run.stderr||'');console.log(output);
  assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(output,/MATCH_CHOREGRAPHIE_CHECKS \d+ failures=0/);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
