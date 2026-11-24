'use strict';
// Réception médicale (captures « reception-medicale ») : Godot réel + moteur réel, carrière Monde (world-champ). La partie avance
// de rencontre en rencontre jusqu'à l'arrivée d'un vrai courrier médical (rien d'injecté), ouvert dans la Réception ; captures du mail
// avec le tableau de l'infirmerie et du panneau « Concerné » en 1920×1080 et 1280×720. Sortie : CD_RECEPTION_MEDICALE_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Réception médicale : vrai courrier de blessure, tableau et panneau « Concerné » sans coupure', { skip: !godot ? 'SDK Godot requis' : !process.env.CD_RECEPTION_MEDICALE_OUTPUT && 'Recette graphique opt-in : CD_RECEPTION_MEDICALE_OUTPUT=<dossier> (captures « reception-medicale »)' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-reception-medicale-'));
  try {
    const sortie = process.env.CD_RECEPTION_MEDICALE_OUTPUT || '';
    const affichage = sortie ? ['--display-driver', process.platform === 'win32' ? 'windows' : 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless'];
    const r = spawnSync(godot, [...affichage, '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-reception-medicale.gd')], {
      cwd: racine, encoding: 'utf8', timeout: 900000,
      env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_RECEPTION_MEDICALE_OUTPUT: sortie ? path.resolve(sortie) : '' },
    });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
    const ligne = journal.split('\n').find(l => l.startsWith('RECEPTION_MEDICALE '));
    assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('RECEPTION_MEDICALE '.length));
    assert.deepEqual(rapport.failures, [], journal.slice(-3000));
    assert.equal(r.status, 0, journal.slice(-3000));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
