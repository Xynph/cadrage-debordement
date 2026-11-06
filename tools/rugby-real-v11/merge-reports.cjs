'use strict';
const fs=require('node:fs'),path=require('node:path');
const C=require('./calibration.cjs'),R=require('./report.cjs');
function merge(inputs){
 const versions=['legacy','baseline','candidate','responseCandidate'];
 const base=inputs.find(r=>r.versions?.responseCandidate);if(!base)throw Error('Missing response proposal');
 const merged=C.clone(base);merged.versions={};merged.totalMatches=0;
 for(const version of versions){
  const matches=inputs.filter(r=>r.versions?.[version]);if(matches.length!==1)throw Error('Missing/duplicate version '+version);
  const r=matches[0];for(const key of ['sourceBase','masterSha256','selected','seeds'])if(JSON.stringify(r[key])!==JSON.stringify(base[key]))throw Error('Mismatched campaign '+key);
  merged.versions[version]=r.versions[version];
  for(const s of Object.values(r.versions[version].results))merged.totalMatches+=s.rows.length;
  if(JSON.stringify(r.versions[version].recruits)!==JSON.stringify(base.versions.responseCandidate.recruits)||JSON.stringify(r.versions[version].lost)!==JSON.stringify(base.versions.responseCandidate.lost))throw Error('Roster policy changed between variants');
 }
 return R.compact(merged);
}
if(require.main===module){
 const files=[];function walk(d){for(const f of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,f.name);if(f.isDirectory())walk(p);else if(f.name==='matches.json')files.push(p);}}walk(process.argv[2]);
 const r=merge(files.map(f=>JSON.parse(fs.readFileSync(f))));fs.mkdirSync(process.argv[3],{recursive:true});fs.writeFileSync(path.join(process.argv[3],'measures.json'),JSON.stringify(r,null,2)+'\n');fs.writeFileSync(path.join(process.argv[3],'results.md'),R.render(r));console.log(JSON.stringify({matches:r.totalMatches,targets:r.designTargets}));
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,R.render(r));
}
module.exports={merge};
