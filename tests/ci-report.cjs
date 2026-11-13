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
// Verdict toujours publié, sauf sur créneau régulier (Godot seul, ignoré par les gates).
assert.match(yaml,/if: \$\{\{ always\(\) && github\.event_name != 'schedule' \}\}/);
// Débit : brouillons en CI légère, batterie complète au passage en prête, annulation sur main.
assert.match(yaml,/types: \[opened, synchronize, reopened, ready_for_review\]/);
assert.match(yaml,/draft: \$\{\{ github\.event\.pull_request\.draft == true \}\}/);
assert.match(yaml,/DRAFT: \$\{\{ needs\.classification\.outputs\.draft \}\}/);
assert.match(yaml,/cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \|\| github\.event_name == 'push' \}\}/);
const shardJob=yaml.split('\n  shards:\n')[1].split('\n  godot:\n')[0];
assert.match(shardJob,/needs\.classification\.outputs\.draft != 'true'/);
// Nombre de shards : une seule source (ci/ci-jobs.cjs) que la matrice doit refléter.
const {SHARD_COUNT,SHARD_PARALLEL,GODOT_SHARD_COUNT,OFFICIAL_JOBS}=require('../ci/ci-jobs.cjs');
const range=n=>Array.from({length:n},(_,i)=>i+1).join(', ');
assert.equal(SHARD_COUNT,7);
assert.equal(SHARD_PARALLEL,3);
assert.equal(OFFICIAL_JOBS.length,SHARD_COUNT+2);
assert.ok(yaml.includes('    name: Suites ${{ matrix.shard }}/'+SHARD_COUNT+'\n'));
assert.ok(yaml.includes('        shard: ['+range(SHARD_COUNT)+']\n'));
assert.ok(yaml.includes('node ci/shard-tests.cjs "$SHARD" "$COVERAGE" '+SHARD_COUNT+' '));
assert.ok(yaml.includes('bash ci/run-shard-suites.sh "$RUNNER_TEMP/shard-suites.txt" "Shard $SHARD/'+SHARD_COUNT+' ($COVERAGE)" '+SHARD_PARALLEL+'\n'));
assert.ok(yaml.includes('### Shard $SHARD/'+SHARD_COUNT+' ($COVERAGE) : aucune suite attribuée'));
// Jobs Godot : SDK épinglé et vérifié, SDK obligatoire, non bloquants pour l'instant.
const godot=yaml.split('\n  godot:\n')[1].split('\n  validation:\n')[0];
assert.ok(godot.includes('    name: Godot ${{ matrix.shard }}/'+GODOT_SHARD_COUNT+'\n'));
assert.ok(godot.includes('        shard: ['+range(GODOT_SHARD_COUNT)+']\n'));
assert.ok(godot.includes('node ci/shard-tests.cjs "$SHARD" godot '+GODOT_SHARD_COUNT+' '));
assert.match(godot,/continue-on-error: true/);
// Plus lancés sur les PR ni à chaque fusion (13/11) : créneau régulier et workflow_dispatch.
assert.match(godot,/github\.event_name == 'workflow_dispatch' \|\| github\.event_name == 'schedule'/);
assert.match(shardJob,/github\.event_name != 'schedule'/);
assert.match(godot,/GODOT_VERSION: 4\.7\.2-stable\n/);
assert.match(godot,/GODOT_SHA256: [0-9a-f]{64}\n/);
assert.match(godot,/sha256sum -c -/);
assert.match(godot,/https:\/\/github\.com\/godotengine\/godot-builds\/releases\/download\/\$GODOT_VERSION\/\$GODOT_ZIP/);
assert.match(godot,/actions\/cache@v4/);
assert.match(godot,/xvfb-run -a/);
assert.match(godot,/LIBGL_ALWAYS_SOFTWARE: '1'/);
assert.match(godot,/bash ci\/run-godot-suites\.sh/);
assert.match(godot,/CD_GODOT_EXECUTABLE=\$exe/);
assert.match(godot,/CD_GODOT_EXE=\$exe/);
// Tant qu'ils sont non bloquants, les jobs Godot restent hors du verdict officiel.
assert.doesNotMatch(yaml.split('\n  validation:\n')[1],/godot/i);
assert.doesNotMatch(yaml,/issues: write/);
assert.doesNotMatch(yaml,/github\.rest\.issues\.createComment/);
assert.doesNotMatch(yaml,/workflow_run:/);
const script=yaml.split('- name: Publier le verdict natif')[1].split('run: |')[1]
 .trimEnd().split(/\r?\n/).slice(1).map(line=>line.replace(/^          /,'')).join('\n');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-ci-verdict-'));
try {
 const summary=path.join(dir,'summary.md');
 for (const [event,coverage,shards,classification,expected,draft='false'] of [
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
  ['workflow_dispatch','web','success','success',1],
  // Brouillon : jamais vert tant que la batterie complète n'a pas tourné.
  ['pull_request','full','skipped','success',1,'true'],
  ['pull_request','web','skipped','success',1,'true'],
  ['pull_request','full','success','success',1,'true'],
  ['pull_request','documentation','skipped','success',0,'true'],
  ['pull_request','full','success','success',0,'']
 ]) {
  fs.writeFileSync(summary,'');
  const result=spawnSync(process.env.CD_BASH_EXECUTABLE||'bash',['-c',script],{
   encoding:'utf8',env:{...process.env,DRAFT:draft,EVENT_NAME:event,COVERAGE:coverage,SHARDS:shards,
    CLASSIFICATION:classification,HEAD_SHA:'pr-head',GITHUB_SHA:'merge-commit',
    GITHUB_REPOSITORY:'owner/repo',GITHUB_RUN_ID:'123',GITHUB_STEP_SUMMARY:summary.replaceAll('\\','/')}
  });
  assert.ifError(result.error);
  assert.equal(result.status,expected,result.stderr+' '+[event,coverage,shards,classification]);
  assert.match(fs.readFileSync(summary,'utf8'),expected===0?/Verdict CI : SUCCÈS/:/Verdict CI : ÉCHEC/);
  if(draft==='true'&&coverage!=='documentation')assert.match(fs.readFileSync(summary,'utf8'),/Brouillon : batterie complète non lancée/);
 }
} finally {
 fs.rmSync(dir,{recursive:true,force:true});
}
console.log('ci-report : contrat des jobs et 20 verdicts natifs vérifiés');
