'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),path=require('node:path');
test('Atlas : photos publiques/ZIP natif, présence, SHA partagés, confidentialité et bornes',()=>{
 const r=spawnSync(process.env.CD_PYTHON_EXECUTABLE||(process.platform==='win32'?'python':'python3'),[path.join(__dirname,'audit-atlas-photos.py')],
  {encoding:'utf8',timeout:20000,maxBuffer:2*1024*1024,env:{...process.env,PYTHONDONTWRITEBYTECODE:'1'}});
 assert.ifError(r.error);assert.equal(r.status,0,(r.stdout||'')+(r.stderr||''));
});
