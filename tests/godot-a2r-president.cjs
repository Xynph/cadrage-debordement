'use strict';
// Règles financières du rugby français dans le vrai jeu (a2r.cjs, president-reprise.cjs) : carrière Monde (Toulouse,
// club 0) préparée côté Node par le vrai moteur — comptes dans le rouge auditionnés par l'A2R (apport demandé avant le
// 30 juin) et achat qui fait passer la caisse sous la réserve (le président désigne des ventes) —, puis le vrai Godot
// ouvre les deux courriers en Réception, répond à l'A2R depuis le mail et montre le verdict.
// Captures 1920×1080 en affichage graphique : CD_A2R_GRAPHICS=1 CD_A2R_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('A2R et président : courriers lisibles et réponses depuis le mail dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-a2r-'));
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    let attendu;
    try {
      M.creer(jeu, 0);
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      attendu = lire(`(()=>{const d=CDWorldCareer.calendarToday(S),D=nativeSystems.domain('clubMail'),sh=n=>new Date(Date.parse(d+'T00:00:00Z')+n*864e5).toISOString().slice(0,10);
        D.recevoir(S,sh(-1));
        // Comptes de la saison : 20 M€ de recettes, caisse à −2 M€ sans soutien du propriétaire (10 % : apport exigé).
        const c=club(),k=S.clubBudget.clubs[c.id];k.recettes=20e6;k.depart=0;k.enveloppe=0;
        const reserve=k.reserve,avant=c.cash;c.cash=-2e6;a2rAudition(d);
        // Puis un achat qui fait tomber la caisse sous la réserve (le président s'en mêle).
        k.reserve=reserve;c.cash=reserve-1.4e6;repriseApresAchat(c,reserve+0.6e6);
        D.recevoir(S,d);
        return {date:d,niveau:S.a2r.decisions[c.id].niveau,president:S.presidentReprise.clubs[c.id].joueurs.map(j=>j.name),
         mails:S.clubMail.mails.filter(m=>/^(a2r_|reprise_president)/.test(m.type)).map(m=>({id:m.id,type:m.type}))};})()`);
      assert.equal(attendu.niveau, 3);
      assert.deepEqual(attendu.mails.map(m => m.type).sort(), ['a2r_apport', 'reprise_president'], JSON.stringify(attendu));
      jeu.call('save');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_A2R_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-a2r-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_A2R_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-a2r-president.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_A2R_OUTPUT: sortie } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('A2R '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('A2R '.length));
    console.log('A2R (Godot) : ' + JSON.stringify(rapport) + ' · moteur : ' + JSON.stringify(attendu));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['a2r-courrier.png', 'a2r-reponse.png', 'president-courrier.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
