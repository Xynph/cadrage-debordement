'use strict';
// Retouches de cohérence (carrière Monde) dans le vrai jeu : fiche club (XV type sans doublon banc/XV, prochaine
// confrontation), ligne « groupe » de Gabi alignée sur l'alerte fatigue, délégation d'une feuille à 22, répartition
// des charges avec le centre de formation, calendrier (bande de période, bandeau « prochain match »).
// La sauvegarde à 22 est préparée par le vrai moteur (club de Nationale, pilier de remplacement manquant le jour du
// match), puis importée dans le jeu. Exécution native Godot, ignorée sans SDK (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
// Captures (rendu graphique) : CD_RETOUCHES_CAPTURE=<préfixe de chemin>.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const Monde = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-retouches-coherence.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-retouches-'));
const sauvegarde = path.join(root, 'feuille-a-22.json');
{
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    const model = Monde.jusquAuMatch(jeu, Monde.creer(jeu, 90));
    // Pilier gauche de remplacement manquant et aucun autre pilier gauche valide : la feuille tombe à 22.
    jeu.bridge.vm.run(`(()=>{const c=S.clubs[S.club],starter=S.lineup[0];for(const p of c.players)if(p.id!==starter&&(p.pos==='Pilier gauche'||p.nationaleQualifications?.includes('Pilier gauche')))p.injury=3;S.reserves[1]=null;S.trained=true;})()`);
    const feuille = jeu.call('snapshot');
    assert.deepEqual(feuille.selection.reducedBench, { size: 22, vacantNumber: 17 }, 'feuille à 22 au jour du match');
    assert.ok(model.next);
    fs.writeFileSync(sauvegarde, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}

const sortie = process.env.CD_RETOUCHES_OUTPUT || root;
const result = spawnSync(godot, [...(process.env.CD_RETOUCHES_CAPTURE ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-retouches-coherence.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 900000,
  env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot'), CD_RETOUCHES_SAUVEGARDE: sauvegarde, CD_RETOUCHES_OUTPUT: sortie },
});
const log = (result.stdout || '') + (result.stderr || '');
fs.writeFileSync(path.join(root, 'godot.log'), log);
console.log(log);
fs.rmSync(sauvegarde, { force: true });
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /RETOUCHES COHERENCE \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
