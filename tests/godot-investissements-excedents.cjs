'use strict';
// Excédents réinvestis par le président dans le vrai jeu : carrière Monde (Toulouse, club 0) préparée côté Node par le vrai
// moteur — ouverture d'une saison avec un excédent au-dessus de la réserve, puis trois matchs joués pour que les
// chantiers avancent —, puis le vrai Godot ouvre Club > Infrastructures (bloc « Excédents réinvestis ») et Finances
// (lignes du grand livre). Captures 1920×1080 en affichage graphique : CD_INVEST_GRAPHICS=1 CD_INVEST_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Excédents réinvestis : chantiers du président visibles dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-invest-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    let attendu;
    try {
      let model = M.creer(jeu, 0);
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      // Une bonne saison laisse 4 M€ au-dessus de la réserve : la saison d'investissements est rouverte comme à la bascule.
      lire(`(()=>{S.clubInvest.saison=0;club().cash=S.clubBudget.clubs[S.club].reserve+4e6;budgetOuvrir(true,true);return 1;})()`);
      model = M.jouer(jeu, model, 2);
      // Recettes de guichet imprévues (suite de #875) : comme après un quart de finale à domicile, 1,6 M€ de plus qu'un
      // match moyen sont encaissés ; le club en reverse la moitié en primes et frais la semaine suivante (ligne du grand livre).
      lire(`(()=>{const c=S.clubBudget.clubs[S.club];c.imprevu=(c.imprevu||0)+1.6e6;return 1;})()`);
      model = M.jouer(jeu, model, 1);
      const frais = lire(`S.ledger.filter(e=>/Frais de match et primes de résultats/.test(e.title)).map(e=>e.amount)`);
      assert.ok(frais.length >= 1 && frais[0] <= -7e5, 'frais de match payés : ' + JSON.stringify(frais));
      attendu = lire('investResume()');
      assert.ok(attendu && attendu.montant > 0 && attendu.depense > 0, 'chantiers en cours : ' + JSON.stringify(attendu));
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_INVEST_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-invest-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_INVEST_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-investissements-excedents.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_INVEST_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('INVESTISSEMENTS '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('INVESTISSEMENTS '.length));
    console.log('Investissements (Godot) : ' + JSON.stringify(rapport) + ' · moteur : ' + JSON.stringify(attendu));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['investissements-infrastructures.png', 'investissements-finances.png', 'frais-de-match-finances.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
