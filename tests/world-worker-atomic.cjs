'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-atomic-save-'));
try{
 for(const [mode,club]of [['common',0],['world',30]]){
  const b=createBridge({dataDir:path.join(root,mode),seed:441,now:1794178800000});let id=0;
  const call=(command,payload={})=>b.handle({id:++id,command,payload});
  const good=(command,payload)=>{const r=call(command,payload);assert.equal(r.ok,true,r.error);return r.model;};
  try{
   const m=good('new_career',{mode,club}),dir=m.meta.dataDir,primary=path.join(dir,'donnees.json'),backup=path.join(dir,'donnees-precedentes.json');
   good('save');good('set_tactics',{attack:'conquete',defense:'equilibre'});
   const before=fs.readFileSync(primary),previous=fs.readFileSync(backup),career=good('export').meta.exportText;
   assert.notDeepEqual(before,previous,'distinct recovery point before injecting a fault');
   const rename=fs.renameSync;
   fs.renameSync=(from,to)=>{if(path.resolve(to)===path.resolve(primary)&&path.basename(from).startsWith('donnees.tmp')){const e=Error('Injected refusal of final publication');e.code='EACCES';throw e;}return rename(from,to);};
   let result;try{result=call('train',{mode:'intense'});}finally{fs.renameSync=rename;}
   assert.equal(result.ok,false);assert.match(result.error,/Écriture de sauvegarde impossible/);
   assert.deepEqual(fs.readFileSync(primary),before,'current file unchanged');
   assert.deepEqual(fs.readFileSync(backup),previous,'previous recovery file unchanged');
   assert.equal(good('export').meta.exportText,career,'career and clock rolled back');
   assert.ok(!fs.readdirSync(dir).some(n=>n.includes('.tmp')||n.includes('.rollback')));
   good('train',{mode:'intense'});assert.deepEqual(fs.readFileSync(backup),before,'successful retry keeps immediately previous file');
  }finally{b.close();}
 }
 console.log(JSON.stringify({passed:true,checks:['failed final publication preserves primary, recovery, career and clock','successful retry updates recovery','common and world editions']}));
}finally{fs.rmSync(root,{recursive:true,force:true});}
