'use strict';
const fs=require('node:fs'),path=require('node:path'),B=require('./bridge.cjs'),C=require('../rugby-real-v12/review.cjs');
const master=require('../../modding/data06/rugby-master-2026-2027.json'),review=require('../../data/scouting/review-v12/candidate.json');
const result=B.candidate(master,review),historical=new Map(master.players.map(p=>[p.id,p]));
const seen=new Set(),rows=Object.create(null);
for(const p of result.master.players){
 if(seen.has(p.id))throw Error('Duplicate player '+p.id);seen.add(p.id);
 const old=historical.get(p.id);if(!old)throw Error('Missing original '+p.id);
 const room=Math.max(0,old.potential-old.rating);
 rows[p.id]=[p.ratingV12,room,C.KEYS.map(k=>p.attributesV2[k]),Object.keys(C.PROJECTION).map(k=>p.skills[k]),p.gameplayPosition,p.hiddenTraitsV2];
}
if(seen.size!==1592||result.variant!=='mild')throw Error('Unexpected data volume/version');
const output="'use strict';\n// Generated from immutable V12 review with mild depth, no official player ratings.\n"+
 "const LNR_V12_PLAYER_DATA="+JSON.stringify({version:1,asOf:'2026-07-01',source:'V12 gameplay estimate + mild depth',attributeKeys:C.KEYS,skillKeys:Object.keys(C.PROJECTION),players:rows})+";\n";
const target=process.argv[2]||path.join(__dirname,'../../dist/lnr-ratings-v12.js');
fs.writeFileSync(target,output);
console.log(JSON.stringify({file:target,players:seen.size,bytes:Buffer.byteLength(output),levels:result.weights}));
