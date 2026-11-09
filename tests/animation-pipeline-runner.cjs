'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const tools = path.join(root, 'tools/animation-pipeline');
const runner = path.join(tools, 'run_checks.py');
const source = path.join(root, 'dist/match3d/assets/quaternius-rugby-athlete.glb');
const python = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');
function run(...args) {
  return spawnSync(python, [runner, ...args], { encoding: 'utf8', timeout: 180000, maxBuffer: 8 * 1024 * 1024 });
}
function temporary(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-animation-runner-'));
  try { return fn(dir); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
function summary(dir) { return JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'))); }

test('base réelle : suites exécutées, phases Godot absentes explicitement not_run', () => temporary(dir => {
  const proof = path.join(dir, 'proof');
  const before = fs.readFileSync(source);
  const result = run('--out', proof, '--node', process.execPath);
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  const report = summary(proof);
  assert.equal(report.status, 'partial');
  assert.equal(report.requested_checks_passed, true);
  assert.equal(report.all_checks_executed, false);
  assert.deepEqual(report.counts, { pass: 5, fail: 0, not_run: 5 });
  for (const name of ['inventory_source', 'tests_inventory', 'tests_compare_cli', 'tests_export_guards', 'inputs_unchanged']) {
    assert.equal(report.checks.find(x => x.name === name).status, 'pass');
  }
  assert.equal(fs.existsSync(path.join(proof, 'reader.json')), false);
  assert.equal(fs.existsSync(path.join(proof, 'poses.json')), false);
  assert.deepEqual(fs.readFileSync(source), before);
}));

test('échec réel source et outil manquant : résultat global en échec sans faux reçu', () => temporary(dir => {
  const invalid = path.join(dir, 'invalid.glb'); fs.writeFileSync(invalid, 'not a glb');
  const proof = path.join(dir, 'proof');
  const result = run('--out', proof, '--source', invalid, '--node', path.join(dir, 'node-absent'));
  assert.equal(result.status, 1, result.stderr);
  const report = summary(proof);
  assert.equal(report.status, 'fail');
  assert.equal(report.requested_checks_passed, false);
  assert.equal(report.checks.find(x => x.name === 'inventory_source').status, 'fail');
  assert.equal(report.checks.find(x => x.name === 'tests_inventory').status, 'fail');
  assert.equal(fs.existsSync(path.join(proof, 'inventory-source.json')), false);
}));

test('préflight : sortie existante, disque invalide, sous-dossier source et Godot implicite refusés', () => temporary(dir => {
  const existing = path.join(dir, 'existing'); fs.mkdirSync(existing);
  fs.writeFileSync(path.join(existing, 'summary.json'), 'ancien reçu');
  const blocker = path.join(dir, 'file'); fs.writeFileSync(blocker, 'intact');
  const cases = [
    ['--out', existing],
    ['--out', path.join(blocker, 'child')],
    ['--out', path.join(root, 'forbidden-runner-proof')],
    ['--out', path.join(dir, 'candidate-no-godot'), '--candidate', source],
    ['--out', path.join(dir, 'reader-no-godot'), '--reader-project', root],
    ['--out', path.join(dir, 'godot-no-task'), '--godot', 'not-invoked'],
  ];
  for (const args of cases) {
    const result = run(...args);
    assert.equal(result.status, 2, result.stderr);
    assert.equal(JSON.parse(result.stderr).ok, false);
  }
  assert.equal(fs.readFileSync(path.join(existing, 'summary.json'), 'utf8'), 'ancien reçu');
  assert.equal(fs.readFileSync(blocker, 'utf8'), 'intact');
  assert.equal(fs.existsSync(path.join(dir, 'candidate-no-godot')), false);
  if (process.platform !== 'win32') {
    const link = path.join(dir, 'dangling'); const target = path.join(dir, 'absent');
    fs.symlinkSync(target, link);
    assert.equal(run('--out', link).status, 2);
    assert.equal(fs.existsSync(target), false);
  }
}));

test('candidat réellement altéré : inventaire valide, poses refusées, fichiers sources préservés', t => {
  const godot = process.env.GODOT || process.env.CD_GODOT_EXE;
  if (!godot || !fs.existsSync(godot)) { t.skip('Définir GODOT vers Godot4.7.2 pour le contrôle réel de poses'); return; }
  temporary(dir => {
    const candidate = path.join(dir, 'negative.glb'); const proof = path.join(dir, 'proof');
    const generate = spawnSync(python, ['-c',
      'import sys; sys.path.insert(0,sys.argv[1]); import compare_poses; compare_poses.negative_glb(sys.argv[2],sys.argv[3])',
      tools, source, candidate], { encoding: 'utf8', timeout: 30000 });
    assert.equal(generate.status, 0, generate.stderr);
    const before = fs.readFileSync(candidate);
    const result = run('--out', proof, '--candidate', candidate, '--godot', godot, '--node', process.execPath);
    assert.equal(result.status, 1, result.stderr || result.error?.message);
    const report = summary(proof);
    assert.equal(report.status, 'fail');
    assert.equal(report.checks.find(x => x.name === 'inventory_candidate').status, 'pass');
    const comparison = report.checks.find(x => x.name === 'compare_poses');
    assert.equal(comparison.status, 'fail');
    assert.equal(comparison.candidate_verdict.passed, false);
    assert.equal(report.checks.find(x => x.name === 'compare_skin').status, 'fail');
    assert.equal(report.checks.find(x => x.name === 'reader').status, 'not_run');
    assert.deepEqual(fs.readFileSync(candidate), before);
  });
});


test('reçu lecteur favorable : refuser un autre asset ou une empreinte absente', () => {
  const code = `
import importlib.util, json, sys
spec=importlib.util.spec_from_file_location('runner',sys.argv[1])
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
expected='b'*64
report={'schema':'oval-animation-reader/v1','passed':79,'failures':[], 'metrics':{'loaded_asset_sha256':'a'*64}}
for loaded in ('a'*64,None):
    report['metrics']['loaded_asset_sha256']=loaded
    try:
        m.validate_reader_artifact(report,expected)
    except ValueError as e:
        assert 'empreinte' in str(e)
    else:
        raise AssertionError('Un lecteur du mauvais asset a été accepté')
report['metrics']['loaded_asset_sha256']=expected
m.validate_reader_artifact(report,expected)
print(json.dumps({'wrong_asset_rejected':True,'missing_hash_rejected':True,'matching_asset_received':True}))
`;
  const result = spawnSync(python, ['-c', code, runner], { encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { wrong_asset_rejected: true, missing_hash_rejected: true, matching_asset_received: true });
});

test('skin favorable partiel : couverture de clips et vertices obligatoire', () => {
  const code = `
import importlib.util, sys, copy
spec=importlib.util.spec_from_file_location('runner',sys.argv[1])
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
report={'passed':True,'source_points':3981,'compared_vertices_per_pose':3981,'unmatched':0,'max_skinned_distance':1e-5,'threshold':1e-4,'samples':[{'clip':clip,'t':i/8} for clip in ('walk','run') for i in range(9)]}
m.validate_skin_artifact(report,{'walk','run'})
for change in ('missing_clip','missing_points','nonfinite'):
    bad=copy.deepcopy(report)
    if change=='missing_clip':bad['samples']=[row for row in bad['samples'] if row['clip']=='walk']
    if change=='missing_points':bad['compared_vertices_per_pose']=1
    if change=='nonfinite':bad['max_skinned_distance']=float('nan')
    try:m.validate_skin_artifact(bad,{'walk','run'})
    except ValueError:pass
    else:raise AssertionError('Couverture partielle reçue: '+change)
print('skin coverage guards pass')
`;
  const result = spawnSync(python, ['-c', code, runner], { encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'skin coverage guards pass');
});
