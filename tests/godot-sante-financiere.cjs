'use strict';
// Santé financière des clubs dans le vrai jeu (club-finance-health.cjs) : carrière Monde (Béziers, club 14, Pro D2)
// préparée par le vrai moteur. L'historique des trois saisons closes est posé par le test (sinon il faut jouer trois
// saisons) : résultat visé par chaque club (cibleGestion) plus un écart propre au club. Le vrai Godot ouvre
// Finances > Classement (classement financier du championnat) puis la fiche d'un autre club (ligne « Finances »).
// Captures 1920×1080 en affichage graphique : CD_SANTE_GRAPHICS=1 CD_SANTE_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Santé financière : classement financier et fiche club dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sante-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    let attendu;
    try {
      M.creer(jeu, 14);
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      attendu = lire(`(()=>{const f=budgetForces();for(const c of S.clubs){const k=S.clubBudget.clubs[c.id];
        for(let a=3;a>=1;a--){const cible=nativeClubBudget.cibleGestion(f,c.id,k.type),ecart=(nativeLeagueEconomy.unite('test-sante|'+c.id+'|'+a)-0.5)*0.9e6;
          const s=S.season;S.season=s-a;santeHistoriser(c.id,cible+ecart);S.season=s;}}
        return santeClassement(S.club).map(x=>[x.id,x.etiquette,x.proprietaire.type,x.courbe.length]);})()`);
      assert.equal(attendu.length, 16);
      assert.ok(attendu.every(x => x[3] === 3), 'trois saisons dans chaque courbe');
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_SANTE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sante-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_SANTE_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-sante-financiere.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_SANTE_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('SANTE '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('SANTE '.length));
    console.log('Santé financière (Godot) : ' + JSON.stringify(rapport) + ' · moteur : ' + JSON.stringify(attendu));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['sante-classement.png', 'sante-fiche-club.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
