'use strict';
// Vente de joueurs dans le vrai jeu (docs/gdd/vente-joueurs.md) : carrière Monde (club 102, world-champ) préparée par le
// vrai moteur : deux joueurs proposés aux autres clubs, trois offres reçues (une acceptable, une spontanée, une dont
// l'acheteur n'a plus les moyens), une vente en attente (accord conclu hors période des mutations), une recrue bloquée,
// et le courrier « offre_transfert » en Réception. Le vrai Godot (fenêtre 1280×720) vérifie : Recrutement → « Offres
// reçues », la boîte des offres (raisons écrites, période des mutations), la confirmation (W1 : libellé = action, focus
// sur Annuler ; caisse, effectif après vente, part rendue au budget), la fiche joueur (onglet Contrat), l'Effectif et
// le lien du courrier. Textes ≥ 13 px, aucun chevauchement.
// Captures 1280×720 en affichage graphique : CD_VENTE_GRAPHICS=1 CD_VENTE_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Vente de joueurs : offres reçues, confirmation, fiche, Effectif et courrier dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-vente-'));
  let attendu;
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    try {
      let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102 }));
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      const run = s => { jeu.bridge.vm.run(s); return jeu.call('save'); };
      const libres = m.squad.filter(p => !p.sale.blocked);
      const [proposeA, proposeB, enAttente, recrue] = [libres[0], libres[1], libres[2], libres[libres.length - 1]];
      for (const p of [proposeA, proposeB]) m = jeu.call('sale_list', { playerId: p.id, listed: true });
      const riche = lire('S.clubs.filter(c=>c.id!==S.club&&professionalPlaces(c)>0&&c.cash>=3e6).slice(0,3).map(c=>c.id)');
      // Accord conclu hors période (août) : vente en attente jusqu'au 1er mai.
      run(`S.economy.offers.push({id:'godot-accord',playerId:'${enAttente.id}',buyer:${riche[2]},fee:180000,expires:S.economy.week+1})`);
      const accord = jeu.call('sale_answer', { offerId: 'godot-accord', action: 'accept', confirmed: true });
      assert.equal(accord.meta.saleAnswer.deferred, true, 'accord hors période');
      run(`(()=>{const p=player('${recrue.id}');p.joinedSeason=S.season;p.joinedRound=S.round;
        S.economy.offers.push({id:'godot-offre',playerId:'${proposeA.id}',buyer:${riche[0]},fee:150000,expires:S.economy.week+1});
        S.economy.offers.push({id:'godot-spontanee',playerId:'${libres[3].id}',buyer:${riche[1]},fee:320000,expires:S.economy.week,spontaneous:true});
        S.economy.offers.push({id:'godot-fauche',playerId:'${proposeB.id}',buyer:${riche[2]},fee:900000,expires:S.economy.week+1});
        S.clubs[${riche[2]}].cash=100000;
        // Carrière neuve : la boîte du club n'existe qu'après une première réception.
        if(!S.clubMail)nativeSystems.domain('clubMail').recevoir(S,CDWorldCareer.calendarToday(S));
        const c=venteCourriers(S).find(x=>x.key==='godot-offre'),st=S.clubMail;
        st.mails.push({id:'mail-'+(++st.seq),type:'offre_transfert',date:CDWorldCareer.calendarToday(S),f:0,vars:c.vars,player:c.player,club:c.club,status:'info',choice:null});})()`);
      m = jeu.call('snapshot');
      const offres = Object.fromEntries(m.sales.offers.map(o => [o.id, o]));
      assert.equal(offres['godot-offre'].accept.available, true);
      assert.match(offres['godot-fauche'].accept.reason, /^Plus disponible : .+ n’a plus les moyens ou plus de place dans son effectif\.$/);
      assert.equal(offres['godot-spontanee'].spontaneous, true);
      assert.equal(m.sales.pending.length, 1);
      assert.ok(m.clubLife.clubMail.mails.some(x => x.type === 'offre_transfert' && x.ecran === 'ventes'));
      attendu = { offre: offres['godot-offre'], fauche: offres['godot-fauche'], accord: m.sales.pending[0], propose: proposeA.id, recrue: recrue.id,
        raisonRecrue: m.squad.find(p => p.id === recrue.id).sale.blocked, enAttente: enAttente.id, offres: m.sales.offers.length };
      assert.equal(attendu.raisonRecrue, 'Nouvelle recrue : attends trois journées avant de la revendre.');
    } finally { jeu.fermer(); }
    const sortie = process.env.CD_VENTE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-vente-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_VENTE_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-vente-joueurs.gd')];
    const commande = graphique && !process.env.DISPLAY && process.platform !== 'win32' ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1280x720x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_VENTE_OUTPUT: sortie, CD_VENTE_ATTENDU: JSON.stringify(attendu) } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('VENTE '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('VENTE '.length));
    console.log('Vente de joueurs (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.ok(rapport.controles >= 30, 'contrôles : ' + rapport.controles);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['vente-recrutement.png', 'vente-offres.png', 'vente-confirmation.png', 'vente-fiche.png', 'vente-fiche-accord.png', 'vente-effectif.png', 'vente-courrier.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
