'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const os=require('node:os');
const workflow=fs.readFileSync(path.join(__dirname,'../.github/workflows/tests.yml'),'utf8');
const marker='          # La PR temoin isolee #281 doit executer les cinq shards complets.';
const end='          echo "documentation_only=$docs" >> "$GITHUB_OUTPUT"';
const start=workflow.indexOf(marker),stop=workflow.indexOf(end,start);
assert(start>=0&&stop>start,'Trial classifier block missing');
const code=workflow.slice(start,stop).split('\n').map(s=>s.replace(/^          /,'')).join('\n');
function classify({event='pull_request',pr='281',files=['docs/ci-auto-release-trial.md']}={}){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-trial-'));
 try{
  const list=path.join(dir,'modified.txt');
  fs.writeFileSync(list,files.join('\n')+(files.length?'\n':''));
  const script='set -euo pipefail\nEVENT_NAME="$1"\nRUNNER_TEMP="$2"\ndocs=true\n'+code.replaceAll('${{ github.event.pull_request.number }}',pr)+'\nprintf "%s" "$docs"\n';
  const run=spawnSync('bash',['-c',script,'--',event,dir],{encoding:'utf8'});
  assert.equal(run.status,0,run.stderr);
  return run.stdout.trim().endsWith('false')?'false':'true';
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
}
test('exact trial PR #281 runs all five shards',()=>assert.equal(classify(),'false'));
test('ordinary docs PR still skips shards',()=>assert.equal(classify({pr:'282'}),'true'));
test('another docs path on #281 still skips shards',()=>assert.equal(classify({files:['docs/ordinary.md']}),'true'));
test('multiple docs paths on #281 still skip shards',()=>assert.equal(classify({files:['docs/ci-auto-release-trial.md','docs/ordinary.md']}),'true'));
test('push to main always runs shards',()=>assert.equal(classify({event:'push'}),'false'));
test('manual dispatch always runs shards',()=>assert.equal(classify({event:'workflow_dispatch'}),'false'));
test('empty PR diff runs shards',()=>assert.equal(classify({files:[]}), 'false'));
test('required CI jobs remain unchanged',()=>{
 assert.match(workflow,/name: Suites \$\{\{ matrix.shard \}\}\/5/);
 assert.match(workflow,/shard: \[1, 2, 3, 4, 5\]/);
 assert.match(workflow,/name: Validation CI/);
 assert.match(workflow,/needs: \[classification, shards\]/);
});
