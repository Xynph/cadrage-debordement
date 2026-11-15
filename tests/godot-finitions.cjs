'use strict';
// Finitions critiques (carrière Monde, club de Champ Rugby) dans le vrai jeu : fiche joueur (Performances), voile
// de Gabi, panneau « Continuer », alerte fatigue courte et carte « État du groupe », calendrier. La sauvegarde est
// préparée par le vrai moteur (un match joué, titulaires fatigués au match suivant), puis importée dans le jeu.
// Exécution native Godot, ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
// Captures (rendu graphique) : CD_FINITIONS_CAPTURE=<préfixe de chemin>.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const Monde = require('./helpers/carriere-monde.cjs');

const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-finitions.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-finitions-'));
// CD_FINITIONS_GARDER=<fichier> : sauvegarde conservée et réutilisée entre deux essais locaux.
const sauvegarde = process.env.CD_FINITIONS_GARDER || path.join(root, 'finitions.json');
if (!fs.existsSync(sauvegarde)) {
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    let model = Monde.jusquAuMatch(jeu, Monde.creer(jeu, 102));
    model = Monde.jouerLeMatch(jeu, model);
    model = Monde.jusquAuMatch(jeu, model);
    // Neuf titulaires du prochain match sous 70 % de condition.
    jeu.bridge.vm.run(`(()=>{const c=S.clubs[S.club];let n=0;for(const id of S.lineup.slice(0,15)){const p=c.players.find(x=>x.id===id);if(p&&n<9){p.condition=58+n;n++;}}})()`);
    const instantane = jeu.call('snapshot');
    assert.ok(instantane.selection.fatigue?.starters?.length >= 9, 'titulaires fatigués publiés par le moteur');
    fs.writeFileSync(sauvegarde, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}

const sortie = process.env.CD_FINITIONS_OUTPUT || root;
const result = spawnSync(godot, [...(process.env.CD_FINITIONS_CAPTURE ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-finitions.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 1500000,
  env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot'), CD_FINITIONS_SAUVEGARDE: sauvegarde, CD_FINITIONS_OUTPUT: sortie },
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
if (!process.env.CD_FINITIONS_GARDER) fs.rmSync(sauvegarde, { force: true });
assert.equal(result.status, 0, 'Godot : ' + log.slice(-1500));
assert.match(log, /FINITIONS \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
