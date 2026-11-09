'use strict';
// Keep this stdlib-only Python audit covered by the normal Node test discovery.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
test('Inventaire privé des identités : mini-ZIP, compteurs, intégrité, bornes et sortie expurgée',()=>{
 const result=spawnSync(process.env.CD_PYTHON_EXECUTABLE||(process.platform==='win32'?'python':'python3'),
  [path.join(__dirname,'audit-identity-pack.py')],{encoding:'utf8',timeout:20000,maxBuffer:2*1024*1024,env:{...process.env,PYTHONDONTWRITEBYTECODE:'1'}});
 assert.ifError(result.error);
 assert.equal(result.status,0,(result.stdout||'')+(result.stderr||''));
});
