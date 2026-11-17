'use strict';
// « Confier aussi les prolongations au staff » dans le vrai jeu : carrière Monde (Toulouse, club 0) préparée côté Node,
// décisions du directeur sportif prises, puis le vrai Godot ouvre Effectif > Contrats, lit la case, la décoche et la
// recoche par le vrai moteur. Capture 1920×1080 en affichage graphique : CD_PROLONGATIONS_GRAPHICS=1
// CD_PROLONGATIONS_OUTPUT=<dossier> (prolongations-staff.png).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Contrats : case des prolongations au staff dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-prolongations-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    let decisions;
    try {
      M.creer(jeu, 0);
      decisions = jeu.bridge.vm.run('dsContratsTrancher(false)');
      assert.ok(decisions > 0, 'décisions du directeur sportif');
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_PROLONGATIONS_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-prolongations-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_PROLONGATIONS_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-prolongations-staff-carriere.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_PROLONGATIONS_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('PROLONGATIONS '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('PROLONGATIONS '.length));
    console.log('Prolongations (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) assert.ok(fs.existsSync(path.join(sortie, 'prolongations-staff.png')), 'capture écrite');
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
