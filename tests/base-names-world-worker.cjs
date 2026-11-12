'use strict';
// Mode Monde : noms de la table, pack factice par identifiant, carrière aux noms antérieurs.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {scenario}=require('./helpers/base-names-scenario.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-base-names-world-'));
try{
 const world=scenario(root,'world',30,3208);
 console.log(JSON.stringify({passed:true,mode:world.mode,players:world.players,staff:world.staff}));
}finally{fs.rmSync(root,{recursive:true,force:true});}
