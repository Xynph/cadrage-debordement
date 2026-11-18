'use strict';
// L'argent du propriétaire dans le vrai jeu (club-owner.cjs) : carrière Monde (Narbonne, club 22, Pro D2, départ « veille »)
// préparée par le vrai moteur. Le test pose la situation (sinon il faut jouer une saison entière) : propriétaire devenu
// arrivée d'un investisseur (mécène prêteur) et perte de la saison passée comblée par un prêt. Le vrai
// Godot ouvre la Réception sur le courrier du président (prêt) et sur celui du nouvel actionnaire.
// Captures 1920×1080 en affichage graphique : CD_PROPRIO_GRAPHICS=1 CD_PROPRIO_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Argent du propriétaire : courriers du prêt et du changement de propriétaire dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-proprio-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    try {
      let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 22, start: 'veille' }));
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      // Arrivée d'un investisseur (mécène prêteur) et perte de la saison passée comblée par un prêt : les deux courriers
      // arrivent le lendemain, avant le coup d'envoi du premier match.
      lire(`(()=>{proprietairesChanger([{id:S.club,de:S.clubBudget.clubs[S.club].type,vers:'mecene',raison:'ambition'}]);
        const k=S.clubBudget.clubs[S.club];k.enveloppe=900000;pretAccorder(S.club,k,700000,S.season-1);
        k.remboursement=nativeClubOwner.remboursementSaison(S.pretsActionnaires[S.club],S.season);return 1;})()`);
      for (let j = 0; j < 3 && !['pret_actionnaire', 'proprietaire_arrivee'].every(t => model.clubLife?.clubMail?.mails?.some(m => m.type === t)); j++)
        model = jeu.regler(jeu.call('advance_day', { fromDate: model.meta.calendarToday }));
      for (const type of ['pret_actionnaire', 'proprietaire_arrivee']) {
        const m = model.clubLife.clubMail.mails.find(x => x.type === type);
        assert.ok(m && m.reponses.every(r => r.disponible), type + ' : réponses possibles ' + JSON.stringify(m?.reponses));
      }
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_PROPRIO_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-proprio-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_PROPRIO_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-argent-proprietaire.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_PROPRIO_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('PROPRIO '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('PROPRIO '.length));
    console.log('Argent du propriétaire (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['pret-courrier.png', 'proprietaire-courrier.png', 'proprietaire-classement.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
