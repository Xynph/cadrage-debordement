'use strict';
// Base commune : noms de la table, pack factice par identifiant, carrière aux noms antérieurs.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs'),{scenario}=require('./helpers/base-names-scenario.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_COMMON_TEST_ROOT||os.tmpdir(),'cd-base-names-'));
try{
 const common=scenario(root,'common',0,1592);
 const reopened=createBridge({dataDir:path.join(root,'common'),seed:1,now:1794178800000});
 try{const r=reopened.handle({id:1,command:'export',payload:{}});assert.equal(r.ok,true,r.error);assert.deepEqual(JSON.parse(r.model.meta.exportText).state,common.saved,'reprise disque d’une carrière aux noms antérieurs');}finally{reopened.close();}
 console.log(JSON.stringify({passed:true,mode:common.mode,players:common.players,staff:common.staff}));
}finally{fs.rmSync(root,{recursive:true,force:true});}
