'use strict';
// Composition : avis du staff dans le bandeau de briefing (selection.staffAdvice, match-actions.js lot 3).
// Carrière world-champ, club 102 : le manager met au centre un joueur que le staff juge nettement moins bon ;
// le moteur doit le signaler et Godot l'afficher (ligne d'avis, repère « ! » sur le poste).
// Captures (affichage graphique) : CD_AVIS_GRAPHICS=1 CD_AVIS_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Composition : avis du staff affiché sur la feuille', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-avis-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false });
    let poste;
    try {
      let m = M.jusquAuMatch(jeu, M.creer(jeu, 102));
      if (!m.selection.valid) m = jeu.call('auto_lineup');
      // Poste 12 (premier centre) : le moins bien noté des remplaçants possibles hors XV.
      poste = 11;
      const xv = new Set(m.lineup), note = id => m.squad.find(p => p.id === id)?.rating ?? 99;
      const choix = m.selection.slots[poste].eligibleIds.filter(id => !xv.has(id)).sort((a, b) => note(a) - note(b))[0];
      m = jeu.call('set_lineup', { playerId: choix, slot: poste });
      const avis = m.selection.staffAdvice;
      assert.ok(avis && avis.conseils.some(c => c.slot === poste && c.chosenId === choix), 'avis du staff sur le poste modifié : ' + JSON.stringify(avis));
      console.log('Avis (moteur) : ' + avis.conseils.map(c => c.texte).join(' | '));
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_AVIS_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-avis-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_AVIS_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-avis-staff.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_AVIS_OUTPUT: sortie, CD_AVIS_POSTE: String(poste) } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('AVIS '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('AVIS '.length));
    console.log('Avis (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
