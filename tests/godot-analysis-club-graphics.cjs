'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

test('Analyse, Club et Bureau graphiques : résultat réel, lecteurs et retours exacts en 1440p', {
  skip: !process.env.CD_GODOT_EXECUTABLE ? 'SDK Godot requis' : process.env.CD_ANALYSIS_CLUB_GRAPHICS !== '1' && 'Recette graphique opt-in : CD_ANALYSIS_CLUB_GRAPHICS=1',
}, () => {
  const deadline = Date.now() + 270000; // la recette SDK coupe une suite à 300 s ; préparation Monde (~46 jours) incluse
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-analysis-club-graphics-'));
  const output = process.env.CD_ANALYSIS_CLUB_GRAPHICS_OUTPUT || path.join(profile, 'proofs');
  fs.mkdirSync(output, { recursive: true });
  // Local checkpoints accelerate an explicit replay. CI creates its own career
  // through the production Node API and never requires a /tmp path.
  const selected = process.env.CI ? '' : process.env.CD_ANALYSIS_CLUB_GRAPHICS_SOURCE || '';
  const receipt = { source: null, source_sha256_before: null, source_sha256_after: null, copied_profile: profile, expected_fixture: '', setup: selected ? 'copied-checkpoint' : 'public-career-node' };
  let sourceFile;
  if (selected) {
    let source = path.resolve(selected);
    if (fs.statSync(source).isFile()) source = path.dirname(source);
    if (!fs.existsSync(path.join(source, 'donnees.json'))) source = path.join(source, 'PrototypeGodot');
    sourceFile = path.join(source, 'donnees.json');
    receipt.source = sourceFile;
    receipt.source_sha256_before = sha(sourceFile);
    const saved = JSON.parse(fs.readFileSync(sourceFile, 'utf8'));
    const encoded = saved.store?.['bdt-v1'];
    const state = typeof encoded === 'string' ? JSON.parse(encoded) : encoded;
    const historical = (state?.history || []).filter(result => result.fixtureId && result.season === state.season && result.pair?.includes(state.club));
    if (!historical.length) {
      receipt.unavailable = 'Aucune rencontre propre archivée avec fixtureId et saison sûre';
      receipt.source_sha256_after = sha(sourceFile);
      fs.writeFileSync(path.join(output, 'source-copy.json'), JSON.stringify(receipt, null, 2));
      assert.fail('Checkpoint indisponible : ' + receipt.unavailable);
    }
    receipt.expected_fixture = historical.at(-1).fixtureId;
    receipt.archived_result = Object.fromEntries(['fixtureId', 'season', 'pair', 'score', 'phase', 'week'].map(key => [key, historical.at(-1)[key]]));
    fs.cpSync(source, path.join(profile, 'PrototypeGodot'), { recursive: true });
    assert.equal(sha(path.join(profile, 'PrototypeGodot', 'donnees.json')), receipt.source_sha256_before, 'La copie de carrière doit être exacte avant son ouverture');
  }
  const head = spawnSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' });
  receipt.sha = head.status === 0 ? head.stdout.trim() : 'unknown';
  let result;
  try {
    if (!selected) {
      const prepared = spawnSync(process.execPath, [path.resolve(__dirname, 'helpers/analysis-club-public-prepare.cjs'), profile, output], {
        env: process.env, encoding: 'utf8', windowsHide: true,
        timeout: Math.min(150000, Math.max(1, deadline - Date.now() - 1000)),
      });
      fs.writeFileSync(path.join(output, 'public-preparation.log'), (prepared.stdout || '') + (prepared.stderr || ''));
      if (prepared.error) throw prepared.error;
      assert.equal(prepared.status, 0, prepared.stderr);
      const preparation = JSON.parse(fs.readFileSync(path.join(output, 'public-preparation.json'), 'utf8'));
      assert.equal(preparation.ok, true);
      assert.equal(sha(path.join(profile, 'PrototypeGodot', 'donnees.json')), preparation.profile_sha256,
        'Le replay doit ouvrir exactement le profil public préparé et fermé');
      receipt.expected_fixture = preparation.expected_fixture;
      receipt.archived_result = preparation.archived_result;
      receipt.public_preparation = 'public-preparation.json';
    }
    const remaining = deadline - Date.now() - 1000;
    assert.ok(remaining > 0, 'Budget global de 270 s épuisé avant le replay');
    result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
      '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '2560x1440',
      '--audio-driver', 'Dummy', '--max-fps', '120', '--path', 'native/godot',
      '--script', path.resolve(__dirname, 'godot-analysis-club-graphics.gd'),
    ], {
      env: { ...process.env, CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: profile,
        CD_ANALYSIS_CLUB_GRAPHICS_COPIED: '1', CD_ANALYSIS_CLUB_GRAPHICS_EXPECTED_FIXTURE: receipt.expected_fixture,
        CD_ANALYSIS_CLUB_GRAPHICS_OUTPUT: output, CD_ANALYSIS_CLUB_GRAPHICS_SHA: receipt.sha },
      encoding: 'utf8', windowsHide: true, timeout: Math.min(180000, remaining),
    });
  } finally {
    if (sourceFile) {
      receipt.source_sha256_after = sha(sourceFile);
      receipt.source_unchanged = receipt.source_sha256_after === receipt.source_sha256_before;
    }
    fs.writeFileSync(path.join(output, 'source-copy.json'), JSON.stringify(receipt, null, 2));
  }
  const log = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(output, 'godot.log'), log);
  console.log(log.trim());
  console.log('Preuves graphiques Analyse/Club/Bureau : ' + output);
  if (sourceFile) assert.equal(receipt.source_sha256_after, receipt.source_sha256_before, 'Le profil source doit rester inchangé, même après un échec de recette');
  if (result.error) throw result.error;
  assert.equal(result.status, 0, log);
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error|ERROR:/);
  const report = JSON.parse(fs.readFileSync(path.join(output, 'report.json'), 'utf8'));
  assert.deepEqual(report.failures, []);
  assert.equal(report.captures.length, 3);
  for (const capture of report.captures) assert.deepEqual([capture.width, capture.height], [2560, 1440]);
});
