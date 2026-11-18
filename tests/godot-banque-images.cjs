'use strict';
// Banque d'images du jeu : manifeste, règles de choix (météo, heure, résultat, phase, niveau, poste), écrans
// branchés (faits marquants entre deux temps forts, fin de match) et recoloration aux couleurs des clubs, sans
// carrière. Captures (affichage graphique) : CD_BANQUE_GRAPHICS=1 CD_BANQUE_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Banque d’images : choix et écrans branchés', { skip: !godot && 'SDK Godot requis', timeout: 300000 }, () => {
  const sortie = process.env.CD_BANQUE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-banque-'));
  fs.mkdirSync(sortie, { recursive: true });
  const graphique = process.env.CD_BANQUE_GRAPHICS === '1';
  const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-banque-images.gd')];
  const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
  const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
  const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 240000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_BANQUE_OUTPUT: graphique ? sortie : '' } });
  const journal = (r.stdout || '') + (r.stderr || '');
  if (r.error) throw r.error;
  assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
  const ligne = journal.split('\n').find(l => l.startsWith('BANQUE '));
  assert.ok(ligne, 'rapport Godot : ' + journal.slice(-3000));
  const rapport = JSON.parse(ligne.slice('BANQUE '.length));
  console.log('Banque d’images (Godot) : ' + JSON.stringify(rapport));
  assert.deepEqual(rapport.failures, []);
  assert.equal(r.status, 0, journal.slice(-3000));
});
