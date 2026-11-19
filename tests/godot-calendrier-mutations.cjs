'use strict';
// Calendrier du recrutement dans le vrai jeu (docs/gdd/calendrier-mutations.md) : carrière Monde (club 102, world-champ)
// préparée par le vrai moteur, en août : un pré-contrat signé avec un joueur d'un autre club (arrivée au 1er juillet), un
// joueur du club approché par un autre club (courrier « precontrat_approche »), un devis de pré-contrat disponible
// (calculé par le moteur, réglage de six mois élargi le temps de la préparation). Le vrai Godot (fenêtre 1280×720)
// vérifie : Recrutement (période des joueurs sans club écrite), Marché entre clubs (période des mutations, filtre des
// fins de contrat, pré-contrat signé, fenêtre « Proposer un pré-contrat » et sa confirmation W1 : libellé = action, focus
// sur Annuler), fiche joueur (approche) et lien du courrier « Proposer une prolongation ». Textes ≥ 13 px, aucun
// chevauchement. Captures 1280×720 en affichage graphique : CD_CALENDRIER_GRAPHICS=1 CD_CALENDRIER_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const R = require('../native/engine/calendrier-mutations.json');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const racine = path.resolve(__dirname, '..');

test('Calendrier du recrutement : périodes, pré-contrats et courrier d’approche dans le vrai jeu', { skip: !godot && 'SDK Godot requis', timeout: 1200000 }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-calendrier-'));
  const origine = JSON.parse(JSON.stringify(R.preContrats));
  let attendu;
  try {
    const jeu = M.ouvrir({ dataDir: profil, mandatoryPress: false, testVm: true });
    try {
      let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102 }));
      const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
      const run = s => { jeu.bridge.vm.run(s); return jeu.call('save'); };
      assert.equal(m.mutations.freeAgents.open, true);
      // Préparation seulement : pré-contrats possibles dès l'été (moins de 12 mois de contrat), approche forcée.
      R.preContrats.moisAvantFin = 12; R.preContrats.approches.chanceSemaine = 1;
      run('club().cash=Math.max(club().cash,9e6);(()=>{const e=budgetTransfertsEtat(true);e.enveloppe=Math.max(e.enveloppe,5e6);})()');
      const liste = () => lire(`nativeSystems.domain('interclubMarket').project()`);
      const possibles = liste().candidates.filter(c => c.preContract?.available).sort((a, b) => a.preContract.premium - b.preContract.premium || (a.id < b.id ? -1 : 1));
      assert.ok(possibles.length >= 2, 'pré-contrats possibles');
      const [signe, devis] = possibles;
      m = jeu.call('precontract_offer', { playerId: signe.id, sellerId: signe.clubId, salary: signe.preContract.salary, years: 1, confirmed: true });
      const approche = lire(`(()=>{for(const p of club().players.slice().sort((a,b)=>roleNote(b)-roleNote(a)).slice(0,4))p.contractEnd=S.season;calSemaine();
        const x=S.calendrierMutations.preContrats.find(y=>y.sens==='depart');
        if(!S.clubMail)nativeSystems.domain('clubMail').recevoir(S,CDWorldCareer.calendarToday(S));
        const c=calCourriers(S,'approche')[0],st=S.clubMail;
        st.mails.push({id:'mail-'+(++st.seq),type:'precontrat_approche',date:CDWorldCareer.calendarToday(S),f:0,vars:c.vars,player:c.player,club:c.club,status:'info',choice:null});
        return x;})()`);
      jeu.call('save');
      assert.ok(approche && approche.etat === 'approche', 'approche préparée');
      R.preContrats = JSON.parse(JSON.stringify(origine));
      m = jeu.call('snapshot');
      const fiche = m.squad.find(p => p.id === approche.playerId).preContract;
      assert.equal(fiche.state, 'approche');
      assert.ok(m.clubLife.clubMail.mails.some(x => x.type === 'precontrat_approche' && x.ecran === 'prolongation'));
      const signeVue = liste().candidates.find(c => c.id === signe.id);
      assert.ok(signeVue.preContract.signed, 'pré-contrat signé visible au marché');
      attendu = { summary: m.mutations.summary, interclubNote: m.mutations.interclub.note, signe: { id: signe.id, label: signeVue.preContract.signed.label },
        devis, approche: { playerId: approche.playerId, short: fiche.short } };
    } finally { R.preContrats = JSON.parse(JSON.stringify(origine)); jeu.fermer(); }
    const sortie = process.env.CD_CALENDRIER_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-calendrier-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_CALENDRIER_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-calendrier-mutations.gd')];
    const commande = graphique && !process.env.DISPLAY && process.platform !== 'win32' ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1280x720x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_CALENDRIER_OUTPUT: sortie, CD_CALENDRIER_ATTENDU: JSON.stringify(attendu) } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('CALENDRIER '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('CALENDRIER '.length));
    console.log('Calendrier du recrutement (Godot) : ' + JSON.stringify(rapport));
    assert.deepEqual(rapport.failures, []);
    assert.ok(rapport.controles >= 25, 'contrôles : ' + rapport.controles);
    assert.equal(r.status, 0, journal.slice(-3000));
    if (graphique) for (const f of ['calendrier-recrutement.png', 'calendrier-marche.png', 'calendrier-precontrat.png', 'calendrier-confirmation.png', 'calendrier-fiche.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
