'use strict';
const fs=require('node:fs'),path=require('node:path');
const C=require('./calibration.cjs'),H=require('./history.cjs'),A=require('./aging.cjs');
function run(dest){
 const file=path.resolve(__dirname,'../../modding/data06/rugby-master-2026-2027.json'),buffer=fs.readFileSync(file),master=JSON.parse(buffer),history=require('../../data/scouting/performance-2025-26-v11.json');
 const candidate=C.consolidate(master);C.apply(master,candidate);
 const coverage=H.audit(master,history),trajectories=A.trajectories(master);
 const files=fs.readdirSync(path.resolve(__dirname,'../../dist')).filter(f=>f.endsWith('.js')).map(f=>'dist/'+f).concat('tests/harness.cjs');
 const fingerprints=Object.fromEntries(files.map(f=>[f,C.hash(fs.readFileSync(path.resolve(__dirname,'../..',f)))]));
 fs.mkdirSync(dest,{recursive:true});for(const [name,r] of Object.entries({candidate,coverage,trajectories,fingerprints}))fs.writeFileSync(path.join(dest,name+'.json'),JSON.stringify(r,null,2)+'\n');
 if(!fs.readFileSync(file).equals(buffer))throw Error('Master mutated');
 console.log(JSON.stringify({masterSha256:C.hash(buffer),candidate:candidate.summary,coverage:{rows:coverage.totalRows,players:coverage.distinctMatched,new:coverage.newMatchedSinceV8V9,forwards:coverage.forwardPlayers,young:coverage.youngPlayers}}));
 return {candidate,coverage,trajectories,fingerprints};
}
if(require.main===module)run(process.argv[2]||'/tmp/v11-export');
module.exports={run};
