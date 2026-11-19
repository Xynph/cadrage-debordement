'use strict';
// Budget de transferts dans le vrai jeu (docs/gdd/budget-transferts.md) : carrière Monde (club 0, world-champ)
// préparée par le vrai moteur. Pour obtenir à coup sûr une piste hors budget, le test marque l’enveloppe comme presque
// entièrement dépensée (R3) : il reste 6 000 € ; la caisse, intacte, ne limite pas.
// Le vrai Godot vérifie les en-têtes Recrutement et Finances (« Disponible pour les transferts » = disponible
// du modèle) puis une offre hors budget (bouton grisé, raison écrite).
// Captures 1920×1080 en affichage graphique : CD_BUDGET_GRAPHICS=1 CD_BUDGET_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');
const RESTE = 6000;

test('Budget de transferts : en-têtes Recrutement et Finances, offre hors budget refusée dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-budget-'));
  let attendu;
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    try {
      const model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 0 }));
      const budget = model.finance?.transferBudget;
      assert.ok(budget && budget.actif === true, 'budget de transferts actif : ' + JSON.stringify(budget));
      assert.ok(Number.isInteger(budget.matelas) && budget.matelas > 0, 'matelas exposé : ' + JSON.stringify(budget));
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      lire(`(()=>{const e=budgetTransfertsEtat(true);e.depense=e.enveloppe+e.reconstitue-${RESTE};return 1;})()`);
      const apres = jeu.call('save');
      attendu = apres?.finance?.transferBudget;
      assert.equal(attendu?.disponible, RESTE, 'disponible = reste de l’enveloppe : ' + JSON.stringify(attendu));
      const hors = (apres.market || []).filter(p => Number(p.fee) > attendu.disponible && /budget/i.test(String(p.reason || '')));
      assert.ok(hors.length > 0, 'au moins une piste refusée pour le budget');
      assert.ok(hors.every(p => p.available === false), 'pistes hors budget indisponibles');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_BUDGET_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-budget-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_BUDGET_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-budget-transferts.gd')];
    const commande = graphique && !process.env.DISPLAY && process.platform !== 'win32' ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_BUDGET_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('BUDGET '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('BUDGET '.length));
    console.log('Budget de transferts (Godot) : ' + JSON.stringify(rapport) + ' · moteur : ' + JSON.stringify(attendu));
    assert.deepEqual(rapport.failures, []);
    assert.equal(rapport.disponible, attendu.disponible, 'Godot lit le même disponible que le moteur');
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['budget-recrutement.png', 'budget-finances.png', 'budget-offre-refusee.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
