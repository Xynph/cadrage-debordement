'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');
const testRoot = path.resolve(__dirname, '..');
const productRoot = path.resolve(process.env.CD_SESSION_LINKS_ROOT || testRoot);
function sha(root) {
  const git = spawnSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'});
  assert.equal(git.status, 0, git.stderr);
  return git.stdout.trim();
}
test('Séance publiée : route exacte, garde réelle, liens clavier/souris et lecture sans effets', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'CD_GODOT_EXECUTABLE requis',
}, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-session-links-'));
  const capture = process.env.CD_SESSION_LINKS_CAPTURE === '1';
  const receipt = {test_sha: sha(testRoot), product_sha: sha(productRoot), test_root:testRoot, product_root:productRoot, capture};
  fs.writeFileSync(path.join(profile, 'provenance.json'), JSON.stringify(receipt, null, 2));
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(capture ? [] : ['--headless']), '--audio-driver', 'Dummy', '--max-fps', '120',
    '--log-file', path.join(profile, 'engine.log'),
    '--path', path.join(productRoot, 'native/godot'), '--script', path.join(__dirname, 'godot-calendar-session-links.gd'),
  ], {cwd:productRoot, encoding:'utf8', windowsHide:true, timeout:90000,
    env:{...process.env, CD_NODE_EXECUTABLE:process.execPath, CD_GODOT_SELF_TEST:'0',
      CD_GODOT_DATA_DIR:profile, CD_SESSION_LINKS_OUTPUT:profile,
      CD_SESSION_LINKS_TEST_SHA:receipt.test_sha, CD_SESSION_LINKS_PRODUCT_SHA:receipt.product_sha}});
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim());
  console.log('Preuves session : ' + profile);
  if (result.error) throw result.error;
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.equal(result.status, 0, output);
  const report = JSON.parse(fs.readFileSync(path.join(profile, 'report.json'), 'utf8'));
  assert.deepEqual(report.failures, []);
  assert.deepEqual(report.speech, {requested:0, started:0, id:0});
  assert.equal(report.test_sha, receipt.test_sha);
  assert.equal(report.product_sha, receipt.product_sha);
  if (capture) assert.ok(report.captures.includes('session-1440.png'));
});
