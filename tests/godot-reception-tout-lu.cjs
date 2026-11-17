'use strict';
// Réception : « Tout marquer comme lu » (Godot réel + worker réel, carrière Monde world-champ, départ « veille »).
// Les informations passent en lu ; les courriers à action restent non lus et visibles ; bouton désactivé ensuite.
// CD_RECEPTION_CAPTURES=<dossier> + CD_RECEPTION_GRAPHICS=1 : captures fenêtrées avant/après.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Réception : Tout marquer comme lu ne touche que les informations', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-tout-lu-'));
  const graphique = process.env.CD_RECEPTION_GRAPHICS === '1';
  try {
    const r = spawnSync(godot, [
      ...(graphique ? ['--windowed', '--resolution', '2560x1440'] : ['--headless']),
      '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-reception-tout-lu.gd'),
    ], {
      cwd: racine, encoding: 'utf8', timeout: 420000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('TOUTLU '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('TOUTLU '.length));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
