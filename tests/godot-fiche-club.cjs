'use strict';
// Fiche d'un club dans le vrai jeu Godot (carrière Monde, mode unique) : ouverture depuis un classement
// et depuis la recherche Ctrl K, quatre onglets, XV type sur le terrain, club du manager → écran « Club »,
// aucun chevauchement de texte en 1920 × 1080 et en 1280 × 720. Captures (CD_FICHE_CAPTURES=1, rendu
// graphique) : fiche-club-vue-ensemble, -effectif, -xv-type, -stats (.png) dans CD_FICHE_OUTPUT.
// Le profil est préparé par le vrai moteur : club de l'élite française, quelques journées déléguées.
// CD_FICHE_PROFIL réutilise un profil déjà préparé (itérations locales).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

function preparer(profil, journees = 3) {
  const bridge = createBridge({ dataDir: profil, seed: 4242, now: 1794315600000 });
  let id = 0, model;
  const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); model = r.model; return model; };
  try {
    call('new_career', { mode: 'world-champ', club: 0 });
    for (let j = 0, garde = 0; j < journees && garde < 40; garde++) {
      model = settleClubMeetings(model, call) || model;
      if (model.next) {
        if (!model.selection.valid) call('auto_lineup');
        model = skipMatchTalk(call('begin_match'), call);
        call('delegate'); j++;
        model = skipMatchTalk(model, call);
        model = settleClubMeetings(model, call) || model;
      }
      const r = bridge.handle({ id: ++id, command: 'finish_round', payload: {} });
      if (r.ok) model = r.model;
    }
    call('save');
    return model;
  } finally { bridge.close(); }
}

function lancer(profil, sortie, largeur, hauteur, captures) {
  // Rendu fenêtré (sous xvfb-run sans affichage) : la mise en page dépend de la vraie taille de fenêtre.
  const graphique = process.env.CD_FICHE_HEADLESS !== '1';
  const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', largeur + 'x' + hauteur] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-fiche-club.gd')];
  const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
  const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 ' + largeur + 'x' + hauteur + 'x24', godot, ...args] : args;
  const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 840000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_FICHE_OUTPUT: sortie, CD_FICHE_SIZE: largeur + 'x' + hauteur, CD_FICHE_CAPTURE: captures ? '1' : '0' } });
  const journal = (r.stdout || '') + (r.stderr || '');
  if (r.error) throw new Error(r.error.message + '\n' + journal.slice(-4000));
  assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-4000));
  const ligne = journal.split('\n').find(l => l.startsWith('FICHE_CLUB '));
  assert.ok(ligne, 'rapport Godot\n' + journal.slice(-4000));
  const rapport = JSON.parse(ligne.slice('FICHE_CLUB '.length));
  assert.deepEqual(rapport.failures, [], journal.slice(-2000));
  assert.equal(r.status, 0, journal.slice(-3000));
  return rapport;
}

test('Fiche club (Godot, Monde) : classement et recherche, onglets, XV type, club du manager, 1080p et 720p', { skip: !godot && 'SDK Godot requis' }, () => {
  const sortie = process.env.CD_FICHE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-fiche-club-ui-'));
  fs.mkdirSync(sortie, { recursive: true });
  const reutilise = process.env.CD_FICHE_PROFIL;
  const profil = reutilise || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-fiche-club-'));
  try {
    if (!reutilise) preparer(profil);
    const captures = process.env.CD_FICHE_CAPTURES === '1';
    // Chaque passage part d'une copie du profil préparé : le premier suit un club et enregistre,
    // le second doit retrouver l'état initial (sinon le clic « suivre » devient « ne plus suivre »).
    const copie = (n) => { const d = profil + '-passage' + n; fs.rmSync(d, { recursive: true, force: true }); fs.cpSync(profil, d, { recursive: true }); return d; };
    const p1 = copie(1), p2 = copie(2);
    let a, b;
    try {
      a = lancer(p1, sortie, 1920, 1080, captures);
      b = lancer(p2, sortie, 1280, 720, false);
    } finally { fs.rmSync(p1, { recursive: true, force: true }); fs.rmSync(p2, { recursive: true, force: true }); }
    console.log('Fiche club (Godot) : 1080p ' + JSON.stringify(a.mesures) + ' · 720p ' + JSON.stringify(b.mesures) + (captures ? ' · captures : ' + sortie : ''));
  } finally { if (!reutilise) fs.rmSync(profil, { recursive: true, force: true }); }
});

module.exports = { preparer };
