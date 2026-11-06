'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E32=require('./economy-v2-e32-run.cjs');
const Investments=require('./economy-v2-e33-investments.cjs');
const profiles={reference:0,modeste:13,alternatif:6};
function run(profile,seed,dir='economy-v2-e33-reports'){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed));
 const g=N.fresh(profiles[profile],seed),before=N.data(g,'createSaveDocument()');
 const evidence=Investments.observe(g);
 const after=N.data(g,'createSaveDocument()');
 assert.deepEqual(after.state,before.state);assert.equal(after.checksum,before.checksum);
 const native=E32.run(profile,seed,dir);
 const advisory=JSON.parse(fs.readFileSync(path.join(dir,'e31-'+profile+'-'+seed+'.json'),'utf8'));
 assert.equal(native.nativeCampaign.saveParity,true);
 assert.equal(native.nativeCampaign.rounds,435);
 assert.equal(native.nativeCampaign.imports,3);
 const html=Investments.render(native.observation,advisory,evidence);
 const report={schema:1,stage:'E3.3',profile,seed,evidence,
  nativeCampaign:native.nativeCampaign,source:'native-snapshot-and-e32-verified-campaign',
  snapshotSaveParity:true,forecastInvestmentPayable:null,
  futureSportOutcome:null,gameplayChanged:false};
 fs.writeFileSync(path.join(dir,'e33-'+profile+'-'+seed+'.html'),html);
 fs.writeFileSync(path.join(dir,'e33-'+profile+'-'+seed+'.json'),JSON.stringify(report,null,2));
 return report;
}
if(require.main===module){try{
 const [profile,seed,dir]=process.argv.slice(2),r=run(profile,Number(seed),dir);
 console.log('E33 PASS '+JSON.stringify({profile,seed,...r.nativeCampaign,
  snapshotSaveParity:r.snapshotSaveParity,facility:r.evidence.facility?.level??null,
  academyWeekly:r.evidence.academy?.selectedWeekly??null,
  investmentEvents:r.evidence.facility?.paidEvents.length??0,gameplayChanged:r.gameplayChanged}));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};
