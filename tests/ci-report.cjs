'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const yaml=fs.readFileSync(path.resolve(__dirname,'../.github/workflows/tests.yml'),'utf8');
assert.match(yaml,/name: Validation CI/);
assert.match(yaml,/needs: \[classification, shards\]/);
assert.match(yaml,/Publier le verdict natif/);
assert.match(yaml,/GITHUB_STEP_SUMMARY/);
assert.match(yaml,/HEAD_SHA: \$\{\{ github\.event\.pull_request\.head\.sha \|\| github\.sha \}\}/);
assert.match(yaml,/EVENT_NAME: \$\{\{ github\.event_name \}\}/);
assert.match(yaml,/CLASSIFICATION: \$\{\{ needs\.classification\.result \}\}/);
assert.match(yaml,/SHARDS: \$\{\{ needs\.shards\.result \}\}/);
assert.match(yaml,/COVERAGE: \$\{\{ needs\.classification\.outputs\.coverage \}\}/);
assert.match(yaml,/if: \$\{\{ always\(\) \}\}/);
assert.match(yaml,/name: Suites \$\{\{ matrix.shard \}\}\/5/);
assert.match(yaml,/shard: \[1, 2, 3, 4, 5\]/);
assert.doesNotMatch(yaml,/issues: write/);
assert.doesNotMatch(yaml,/github\.rest\.issues\.createComment/);
assert.doesNotMatch(yaml,/workflow_run:/);
const script=yaml.split('- name: Publier le verdict natif')[1].split('run: |')[1]
 .trimEnd().split(/\r?\n/).slice(1).map(line=>line.replace(/^          /,'')).join('\n');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-ci-verdict-'));
try {
 const summary=path.join(dir,'summary.md');
 for (const [event,coverage,shards,classification,expected] of [
  ['pull_request','documentation','skipped','success',0],
  ['pull_request','web','success','success',0],
  ['pull_request','native-art','success','success',0],
  ['pull_request','full','success','success',0],
  ['push','full','success','success',0],
  ['workflow_dispatch','full','success','success',0],
  ['pull_request','documentation','success','success',1],
  ['pull_request','web','skipped','success',1],
  ['pull_request','full','failure','success',1],
  ['pull_request','full','cancelled','success',1],
  ['pull_request','full','success','failure',1],
  ['pull_request','','success','success',1],
  ['pull_request','unknown','success','success',1],
  ['push','documentation','skipped','success',1],
  ['workflow_dispatch','web','success','success',1]
 ]) {
  fs.writeFileSync(summary,'');
  const result=spawnSync(process.env.CD_BASH_EXECUTABLE||'bash',['-c',script],{
   encoding:'utf8',env:{...process.env,EVENT_NAME:event,COVERAGE:coverage,SHARDS:shards,
    CLASSIFICATION:classification,HEAD_SHA:'pr-head',GITHUB_SHA:'merge-commit',
    GITHUB_REPOSITORY:'owner/repo',GITHUB_RUN_ID:'123',GITHUB_STEP_SUMMARY:summary.replaceAll('\\','/')}
  });
  assert.ifError(result.error);
  assert.equal(result.status,expected,result.stderr+' '+[event,coverage,shards,classification]);
  assert.match(fs.readFileSync(summary,'utf8'),expected===0?/Verdict CI : SUCCÈS/:/Verdict CI : ÉCHEC/);
 }
} finally {
 fs.rmSync(dir,{recursive:true,force:true});
}
console.log('ci-report : contrat des jobs et 15 verdicts natifs vérifiés');
