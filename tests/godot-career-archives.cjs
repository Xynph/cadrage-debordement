'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-archives-')),b=createBridge({dataDir:root,seed:827381,now:1700000000000});let n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
try{
 const text=zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/roster-foundation-v1-s2.json.gz'))).toString();
 const m=good('import',{text});
 assert.deepEqual(m.archives,{limit:15,seasons:[{season:1,champions:[{leagueId:'elite',clubId:12},{leagueId:'accession',clubId:28}],standings:{elite:[8,0,12,9,4,1,11,2,5,7,13,3,6,10],accession:[28,20,15,24,19,21,26,16,25,14,23,18,17,27,29,22]},movement:{promoted:[28],relegated:[10]}}]},'archives par IDs depuis la vraie saison livrée');
 const before=good('export').meta.exportText,disk=path.join(root,'PrototypeGodot','donnees.json'),bytes=fs.readFileSync(disk);
 for(let i=0;i<3;i++)assert.deepEqual(good('snapshot').archives,m.archives);
 assert.equal(good('export').meta.exportText,before,'projection sans mutation S/RNG');assert.deepEqual(fs.readFileSync(disk),bytes,'projection sans écriture');
 assert.deepEqual(settleClubMeetings(good('new_career',{club:0,mode:'fiction'}),(command,payload)=>good(command,payload)).archives,{limit:15,seasons:[]},'nouvelle carrière sans archive inventée');
 console.log('Archives : checkpoint réel S2, IDs exacts, lectures sans mutation et nouvelle carrière PASS');
}finally{b.close();fs.rmSync(root,{recursive:true,force:true});}
