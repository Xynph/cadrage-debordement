'use strict';
// Captures 1280×720 du lot « dilemmes » (carrière Monde, vrai moteur pour la sauvegarde, vraie interface) :
//   1. écran 2D entre deux temps forts à la 70e minute, tuile Bonus et dilemme à deux consignes ;
//   2. feuille de match (Composition) : ligne du quota du championnat (JIFF) et joueurs de la liste des 33 ;
//   3. Travail du club > Médical : joueur sous protocole commotion (HIA) ;
//   4. feuille de match après ~8 matchs : bannière des Bleus (titulaire de la liste des 33 qui doit souffler), captures seulement.
// Sans CD_DILEMMES_CAPTURE (dossier de sortie), le script ne fait que les contrôles. Exécution native Godot, ignorée sans SDK
// (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const Monde = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXE || process.env.CD_GODOT_EXECUTABLE;
if (!godot) { console.log('SKIP godot-dilemmes.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE).'); process.exit(0); }

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-dilemmes-'));
const sauvegarde = path.join(root, 'dilemmes.json');
const sortie = process.env.CD_DILEMMES_CAPTURE || '';
// 4. Bannière des Bleus : il faut un historique de club (fenêtre glissante de 8 matchs, 2 repos). Carrière Monde jouée
// par le vrai moteur, matchs délégués, mais un manager qui garde son XV du premier match à chaque rencontre (la
// sélection du staff, elle, étale les repos depuis le 19/11), jusqu'au premier jour de match où un titulaire de la
// liste des 33 doit souffler. Seulement avec les captures (≈ 6 à 8 matchs simulés).
const sauvegardeBleus = sortie ? path.join(root, 'dilemmes-bleus.json') : '';
if (sauvegardeBleus) {
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    let model = Monde.creer(jeu, 0), joues = 0, xv = null;
    for (; joues <= 10; joues++) {
      model = Monde.jusquAuMatch(jeu, model);
      if (!xv) { model = jeu.call('auto_lineup'); xv = model.selection.slots.map(x => x.playerId ?? null); }
      else {
        const aptes = new Set(model.squad.filter(p => !(p.injury > 0) && !(p.suspension > 0)).map(p => String(p.id)));
        const changes = xv.map((playerId, slot) => ({ slot, playerId })).filter(c => c.playerId && aptes.has(String(c.playerId)));
        try { model = jeu.call('set_lineup', { changes }); } catch { /* XV impossible à remettre tel quel : feuille du jour */ }
        if (!model.selection.valid) model = jeu.call('auto_lineup');
      }
      if ((model.clubLife.doublons?.reposer || []).length) break;
      model = Monde.jusquALaSemaineSuivante(jeu, Monde.jouerLeMatch(jeu, model));
    }
    const d = model.clubLife.doublons || {};
    console.log(`BLEUS : ${joues} matchs joués, à faire souffler : ${(d.reposer || []).length}, remplaçants proposés : ${(d.changes || []).length}`);
    assert.ok((d.reposer || []).length > 0, 'un titulaire de la liste des 33 doit souffler après ' + joues + ' matchs');
    fs.writeFileSync(sauvegardeBleus, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}
{
  const jeu = Monde.ouvrir({ testVm: true });
  try {
    let model = Monde.jusquAuMatch(jeu, Monde.creer(jeu, 0));
    assert.equal(model.clubLife.jiff.applies, true, 'le club est soumis au quota JIFF');
    // Un titulaire sous protocole commotion (critère 2, diagnostiqué le jour du match) : état de test posé par le vrai moteur.
    const aujourdhui = model.meta.calendarToday;
    const pose = jeu.bridge.vm.run(`(()=>{const api=nativeSystems.domain('clubSupport').commotion,c=S.clubs[S.club],p=c.players.find(q=>q.id===S.lineup[5]);return api.diagnose(S,S.club,p,${JSON.stringify(aujourdhui)},2,'capture-dilemmes');})()`);
    assert.equal(pose, true, 'commotion posée');
    model = jeu.regler(jeu.call('auto_lineup'));
    assert.ok(model.clubLife.clubSupport.medical.commotions.length >= 1, 'le médical voit la commotion');
    fs.writeFileSync(sauvegarde, jeu.call('export').meta.exportText);
  } finally { jeu.fermer(); }
}

if (sortie) fs.mkdirSync(sortie, { recursive: true });
const result = spawnSync(godot, [...(sortie ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720'] : ['--headless']), '--max-fps', '120', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-dilemmes.gd')], {
  windowsHide: true, encoding: 'utf8', timeout: 900000,
  env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: path.join(root, 'PrototypeGodot'), CD_DILEMMES_SAUVEGARDE: sauvegarde, CD_DILEMMES_BLEUS: sauvegardeBleus, CD_DILEMMES_CAPTURE: sortie },
});
const log = (result.stdout || '') + (result.stderr || '');
console.log(log);
fs.rmSync(root, { recursive: true, force: true });
if (result.error) throw result.error;
assert.equal(result.status, 0, log);
assert.match(log, /DILEMMES \d+ controles, 0 echec/);
assert.doesNotMatch(log, /SCRIPT ERROR|Parse Error/);
