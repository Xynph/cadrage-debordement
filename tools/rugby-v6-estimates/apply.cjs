#!/usr/bin/env node
'use strict';
// Apply provenance-aware estimated ratings to the central Rugby V6 file.
// Run locally: node tools/rugby-v6-estimates/apply.cjs INPUT_V6.json ESTIMATES.json OUTPUT.json
// Never overwrite the source; commit only after validation and save-compatibility tests.
const fs=require('node:fs');
const [input,layer,output]=process.argv.slice(2);
if(!input||!layer||!output||input===output||layer===output){
 console.error('Usage: node apply.cjs INPUT_V6.json ESTIMATES.json OUTPUT.json (distinct paths)');
 process.exit(2);
}
const db=JSON.parse(fs.readFileSync(input,'utf8'));
const estimates=JSON.parse(fs.readFileSync(layer,'utf8'));
if(db.schema!=='rugby-master-sports-v6'||estimates.schema!=='rugby-v6-estimated-overrides-v1')throw Error('Unexpected schema');
if(!Array.isArray(db.players)||!Array.isArray(estimates.players)||db.players.length!==estimates.players.length)throw Error('Missing players');
const map=new Map();
for(const e of estimates.players){
 if(!e.id||map.has(e.id)||e.ratingKind!=='estimated'||e.potentialKind!=='estimated')throw Error('Invalid or duplicate estimate');
 map.set(e.id,e);
}
let count=0;
for(const p of db.players){
 const e=map.get(p.id);
 if(!e||e.club!==p.club||e.league!==p.league)throw Error('Identity/club/league mismatch: '+p.id);
 if(!Number.isInteger(e.rating)||!Number.isInteger(e.potential)||e.rating<1||e.rating>99||e.potential<e.rating||e.potential>99)throw Error('Rating out of range: '+p.id);
 for(const [key,value] of Object.entries(e.attributesV2||{})){
  if(!Object.hasOwn(p.attributesV2,key)||!Number.isInteger(value)||value<1||value>99)throw Error('Invalid attribute: '+p.id+' '+key);
 }
 p.rating=e.rating;p.potential=e.potential;
 Object.assign(p.attributesV2,e.attributesV2);
 p.ratingKind='estimated';p.potentialKind='estimated';
 p.v6MassEstimate={model:e.model,sourceBlob:estimates.sourceBlob,individualEvidence:e.evidence.individualMinutes2025_26!==null||e.evidence.individualMinutes2024_25!==null||e.evidence.individualMatches2025_26!==null,teamContext:e.evidence.teamTry2025_26!==null};
 count++;
}
if(count!==map.size)throw Error('Coverage mismatch');
db.v6MassEstimateSummary={schema:estimates.schema,model:estimates.model,sourceBlob:estimates.sourceBlob,players:count,summary:estimates.summary,realStatisticsUnchanged:true};
fs.writeFileSync(output,JSON.stringify(db),'utf8');
const check=JSON.parse(fs.readFileSync(output,'utf8'));
if(JSON.stringify(db.rugbyDataObservations)!==JSON.stringify(check.rugbyDataObservations))throw Error('Statistics altered');
console.log(JSON.stringify({players:count,observations:db.rugbyDataObservations?.length||0,status:'estimated-output-created-not-activated'}));
