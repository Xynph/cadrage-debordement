'use strict';
// Vestiaire › Entretiens et duos : chaque carte, anneau, portrait et pastille déclenche son action ; petite fenêtre du groupe.
const assert=require('node:assert/strict'),path=require('node:path'),{spawnSync}=require('node:child_process');
const sdk=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!sdk){console.log('SKIP godot-vestiaire-entretiens-clics : SDK Godot requis.');process.exit(0);}
const result=spawnSync(sdk,['--headless','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-vestiaire-entretiens-clics.gd')],
 {encoding:'utf8',timeout:90000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1'}});
const log=(result.stdout||'')+(result.stderr||'');console.log(log);
if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);assert.match(log,/VESTIAIRE_CLICS checks=\d+ failures=0/);
