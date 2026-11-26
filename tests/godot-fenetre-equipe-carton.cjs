'use strict';
// Fenêtre « Équipe » du direct, pilier n°3 en carton jaune (PR #1338). Le vrai moteur (giveMatchCard, le chemin des
// cartons du jeu) exclut le pilier du club du joueur sur un vrai match Monde, une minute de plus est jouée pour que
// l'événement soit montré (live.direct.cartons rempli, comme en jeu), puis le vrai Godot reprend ce match et ouvre
// la vraie fenêtre Équipe : le n° 3 reste occupé par le pilier exclu avec la pastille « Carton », il n'est pas dans
// les remplaçants, aucun poste n'est vide.
// Captures (affichage graphique) : CD_EQUIPE_GRAPHICS=1 CD_EQUIPE_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

test('Fenêtre Équipe : pilier n°3 en carton jaune gardé à son poste avec la pastille Carton', { skip: !godot && 'SDK Godot requis', timeout: 900000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-equipe-carton-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    let carton, sauvegarde;
    try {
      let m = M.jusquAuMatch(jeu, M.creer(jeu, 102));
      if (!m.selection.valid) m = jeu.call('auto_lineup');
      if (!m.selection.valid) m = jeu.call('promote_cover', { confirmed: true });
      jeu.call('save');
      m = skipMatchTalk(jeu.call('begin_match'), jeu.call);
      m = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      const vm = jeu.bridge.vm;
      carton = JSON.parse(vm.run(`JSON.stringify((() => { const l = S.live, sh = l.sheets[l.userSide], id = sh.on[2]; delete l.incidentChoix;
        return { id, donne: giveMatchCard(l, l.userSide, id, 'yellow') }; })())`));
      assert.equal(carton.donne, true, 'moteur : carton jaune donné au pilier n°3');
      // Une minute de jeu : l'événement de carton est montré, comme en match (direct.cartons rempli).
      m = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      m = jeu.call('pause', { paused: true });
      assert.ok((m.live.direct?.cartons || []).some(c => c.id === carton.id), 'direct.cartons contient le pilier exclu');
      sauvegarde = vm.run('JSON.stringify(createSaveDocument())');
    } finally { jeu.fermer(); }
    const fichier = path.join(profil, 'carton-save.json');
    fs.writeFileSync(fichier, sauvegarde);
    const sortie = process.env.CD_EQUIPE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-equipe-carton-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_EQUIPE_GRAPHICS === '1';
    const args = [...(graphique ? [...(process.platform === 'win32' ? [] : ['--display-driver', 'x11']), '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-fenetre-equipe-carton.gd')];
    const commande = graphique && process.platform !== 'win32' && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 2560x1440x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 600000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_EQUIPE_OUTPUT: sortie, CD_EQUIPE_SAUVEGARDE: fichier, CD_EQUIPE_CARTON_ID: carton.id } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    const lignes = journal.split('\n');
    const premieres = lignes.map((l, i) => /SCRIPT ERROR/.test(l) ? l + '\n' + (lignes[i + 1] || '') : null).filter(Boolean).slice(0, 6).join('\n');
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, premieres + '\n…\n' + journal.slice(-2500));
    const ligne = lignes.find(l => l.startsWith('EQUIPE-CARTON '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-4000));
    const rapport = JSON.parse(ligne.slice('EQUIPE-CARTON '.length));
    console.log('Fenêtre Équipe, carton (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
