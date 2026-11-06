'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E30=require('./economy-v2-e30-run.cjs'),UI=require('./economy-v2-e31-pc.cjs');
function run(profile,seed,dir='economy-v2-e31-reports'){
 const native=E30.run(profile,seed);
 assert.equal(native.native.seasons,15);assert.equal(native.native.saveParity,true);
 assert.equal(native.native.legacyPayablesCreated,0);
 const r={stage:'E3.1',profile,seed,observation:{
  source:'native-E2.9-read-only',seasons:native.native.seasons,rounds:native.native.rounds,
  imports:native.native.imports,cashMovements:native.native.cashMovements,
  pressure:native.native.indicativePressure,recovery:native.native.indicativeRecovery,
  minObservedClubCash:native.native.minObservedClubCash,
  saveParity:native.native.saveParity,saveChecksum:native.native.saveChecksum
 },cases:native.illustrativeScenarios,gameplayChanged:false,scenariosNative:false};
 fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,'e31-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 const html=UI.render(r);
 fs.writeFileSync(path.join(dir,'e31-'+profile+'-'+seed+'.html'),html);
 assert.ok(html.includes('PROTOTYPE R&D'));
 assert.ok(!html.includes('dist/index.html'));
 return r;
}
if(require.main===module){try{
 const [profile,seed,dir]=process.argv.slice(2),r=run(profile,Number(seed),dir);
 console.log('E31 PASS '+JSON.stringify({profile,seed,seasons:r.observation.seasons,rounds:r.observation.rounds,
 imports:r.observation.imports,cashMovements:r.observation.cashMovements,
 saveParity:r.observation.saveParity,pressure:r.observation.pressure,recovery:r.observation.recovery,
 syntheticCases:Object.keys(r.cases).length,gameplayChanged:r.gameplayChanged}));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
