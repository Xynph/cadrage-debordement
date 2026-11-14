'use strict';
// Gabi adjoint : avis contextuels, conseils de composition et de recrutement, à partir d'une vraie
// carrière Monde (moteur Node, cadence hebdomadaire, un match joué pour avoir des notes de match).
// Exécution native Godot (script sans scène), ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');
const Monde = require('./helpers/carriere-monde.cjs');

const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;

test('Gabi adjoint : avis de chaque écran, conseils avec action, couche connaissance', {skip: !godot && 'SDK Godot requis', timeout: 600000}, () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-gabi-adjoint-'));
  const jeu = Monde.ouvrir({hebdomadaire: true, dataDir: path.join(root, 'data')});
  let model;
  try {
    model = Monde.creer(jeu);
    fs.writeFileSync(path.join(root, 'creation.json'), JSON.stringify(model));
    model = Monde.jusquAuMatch(jeu, model);
    model = Monde.jouerLeMatch(jeu, model);
    fs.writeFileSync(path.join(root, 'apres-match.json'), JSON.stringify(model));
  } finally { jeu.fermer(); }
  const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-gabi-adjoint.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 180000,
    env: {...process.env, CD_GABI_ADJOINT_MODELES: root},
  });
  const log = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(root, 'godot.log'), log);
  console.log(log.trim());
  if (result.error) throw result.error;
  assert.equal(result.status, 0, log);
  assert.match(log, /GABI_ADJOINT \d+ controles, 0 echec/);
  assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
});
