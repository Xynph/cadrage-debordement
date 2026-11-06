'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E24=require('./economy-v2-obligations-run.cjs');
const E31=require('./economy-v2-e31-run.cjs');
const Adapter=require('./economy-v2-e32-adapter.cjs');
const N=require('../tests/career-resilience/native.cjs');
const profiles={reference:0,modeste:13,alternatif:6};
function run(profile,seed,dir='economy-v2-e32-reports'){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed));
 const game=N.fresh(profiles[profile],seed);
 const before=N.data(game,'createSaveDocument()');
 const initial=N.data(game,'({clubs:S.clubs.map(c=>({id:c.id,facilities:worldClub(c.id).facilities,reputation:worldClub(c.id).reputation}))})');
 const after=N.data(game,'createSaveDocument()');
 assert.deepEqual(after.state,before.state);
 assert.equal(after.checksum,before.checksum);
 const native=E24.run(profile,seed);
 const advisory=E31.run(profile,seed,dir);
 const observed=Adapter.adapt(native,initial);
 assert.equal(advisory.observation.saveParity,true);
 assert.equal(native.counts.imports,3);
 assert.equal(native.counts.unmeasuredLiabilities,210);
 assert.equal(native.counts.rounds,435);
 assert.equal(native.counts.cashMovements,advisory.observation.cashMovements);
 assert.equal(native.series.length,advisory.observation.seasons);
 const report={stage:'E3.2',profile,seed,observation:observed,
  nativeCampaign:{seasons:15,rounds:native.counts.rounds,imports:native.counts.imports,
   cashMovements:native.counts.cashMovements,saveParity:advisory.observation.saveParity,
   saveChecksum:advisory.observation.saveChecksum,unknownPayables:native.counts.unmeasuredLiabilities},
  decisionScenariosNative:false,gameplayChanged:false};
 const html=Adapter.render(observed,advisory);
 assert.ok(html.includes('id="e32-native"'));
 fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,'e32-'+profile+'-'+seed+'.json'),JSON.stringify(report,null,2));
 fs.writeFileSync(path.join(dir,'e32-'+profile+'-'+seed+'.html'),html);
 return report;
}
if(require.main===module){try{
 const [profile,seed,dir]=process.argv.slice(2);const r=run(profile,Number(seed),dir);
 console.log('E32 PASS '+JSON.stringify({profile,seed,...r.nativeCampaign,clubs:r.observation.clubs.length,
  unknown:r.observation.unknown,gameplayChanged:r.gameplayChanged}));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
