'use strict';
// Panneaux latéraux de l'Effectif (21/11/2026) : colonne XV / SEMAINE / GROUPE dépliée, rail replié, état mémorisé,
// chaque élément cliqué (Composition, fiche, Entraînement, Vestiaire, petite fenêtre des tensions), programme de la
// semaine dans l'Entraînement, confiance des joueurs et tensions dans le Vestiaire.
// La carrière de test est préparée ici (Monde, jour de match) avec une vraie situation de tension dans le moteur :
// trois joueurs insatisfaits, dont deux du même poste, et une promesse de temps de jeu non tenue.
// CD_PANNEAUX_GARDER_EXPORT=<chemin> : garde la carrière préparée (captures).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

function preparer(sortie) {
  const jeu = M.ouvrir({ testVm: true });
  try {
    let model = M.jusquAuMatch(jeu, M.creer(jeu, 102));
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    jeu.bridge.vm.run(`(()=>{const ps=S.clubs[S.club].players.filter(p=>p.satisfaction&&!p.injury);
      const a=ps[0],b=ps.find(p=>p!==a&&p.fam===a.fam),c=ps.find(p=>p!==a&&p!==b&&p.fam!==a.fam);
      a.satisfaction.score=28;b.satisfaction.score=41;c.satisfaction.score=50;
      c.satisfaction.history.push({season:S.season,round:S.round,status:'broken',minutes:40,target:'titulaire'});})()`);
    fs.writeFileSync(sortie, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}

test('Panneaux de l’Effectif (carrière Monde avec tensions)', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-panneaux-effectif-'));
  const exportPath = process.env.CD_PANNEAUX_GARDER_EXPORT || path.join(profile, 'carriere.json');
  preparer(exportPath);
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    '--headless', '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-panneaux-effectif.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(profile, 'donnees'), CD_PANNEAUX_EXPORT: exportPath },
    encoding: 'utf8', windowsHide: true, timeout: 300000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /PANNEAUX|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
