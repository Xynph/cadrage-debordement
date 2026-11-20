'use strict';
// Calendrier du recrutement dans le vrai jeu (docs/gdd/calendrier-mutations.md) : carrière Monde (club 102, world-champ)
// préparée par le vrai moteur, en août : un pré-contrat signé avec un joueur d'un autre club (arrivée au 1er juillet), un
// joueur du club approché par un autre club (courrier « precontrat_approche »), un devis de pré-contrat disponible
// (calculé par le moteur, réglage de six mois élargi le temps de la préparation). Le vrai Godot (fenêtre 1280×720)
// vérifie : Recrutement (période des joueurs sans club écrite), Marché entre clubs (période des mutations, filtre des
// fins de contrat, pré-contrat signé, fenêtre « Proposer un pré-contrat » et sa confirmation W1 : libellé = action, focus
// sur Annuler), fiche joueur (approche) et lien du courrier « Proposer une prolongation ». Textes ≥ 13 px, aucun
// chevauchement. Aussi (§ 3 bis – 3 quater) : écran des ventes (une vente acceptée prend effet au 1er juillet), courriers
// « Point mercato » et « Échos du mercato » en Réception, arrêt « Effectif trop juste » de Continuer (vrai arrêt du moteur,
// piliers droits blessés avant le 1er match). Captures 1280×720 en affichage graphique : CD_CALENDRIER_GRAPHICS=1 CD_CALENDRIER_OUTPUT=<dossier>.
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
      // Effectif trop juste (§ 3 quater, comme tests/effectif-sans-plancher.cjs) : piliers droits blessés, « Continuer »
      // du vrai moteur jusqu'à l'arrêt « Effectif trop juste » (quelques jours avant le 1er match), puis piliers guéris.
      const blesses = lire('S.clubs[S.club].players.filter(p=>p.pos===POS[2]).map(p=>[p.id,p.injury??null])');
      jeu.bridge.vm.run('S.clubs[S.club].players.forEach(p=>{if(p.pos===POS[2])p.injury=4;})');
      let court = null;
      for (let i = 0; i < 40 && !court; i++) {
        m = jeu.regler(m);
        const r = jeu.brut('advance_until_event', { fromDate: m.meta.calendarToday, stops: { messages: 'aucun' } });
        assert.equal(r.ok, true, r.error);
        m = r.model;
        if (m.meta.advanceUntilEvent?.stop?.type === 'effectif_court') court = m.meta.advanceUntilEvent;
      }
      assert.ok(court, 'arrêt « Effectif trop juste » de Continuer');
      assert.equal(court.stop.label, 'Effectif trop juste');
      jeu.bridge.vm.run(`(()=>{const b=new Map(${JSON.stringify(blesses)});for(const p of S.clubs[S.club].players)if(b.has(p.id)){if(b.get(p.id)===null)delete p.injury;else p.injury=b.get(p.id);}})()`);
      m = jeu.regler(jeu.call('save'));
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
      // Courriers du mercato (§ 3 ter, comme tests/courrier-mercato.cjs) reçus par le vrai moteur : « Échos du mercato »
      // un jour de février (8 faits : 6 lignes puis « et 2 autres »), « Point mercato » un jour de mai (3 offres reçues,
      // accords du Monde). Les offres restent pour l'écran des ventes ; les courriers sont rangés au jour de la carrière.
      const courriers = lire(`(()=>{const X=S,cad=nativeClubMailData.cadence,max=cad.maxParJour,wk=X.worldMode.week,last=X.clubMail.last,today=CDWorldCareer.calendarToday(X);
        cad.maxParJour=12;
        const autres=X.clubs.filter(c=>c&&c.id!==X.club).slice(0,4).map(c=>c.id);
        X.calendrierMutations.mercato={saison:X.season,ouverture:null,derniere:null,semaines:{
          30:[{type:'precontrat',texte:'Bordeaux a signé Jean Dupont (talonneur de Dax) pour la saison prochaine.',montant:0},
            {type:'accord',texte:'Toulon s’est mis d’accord avec Pau pour Hugo Marty (troisième ligne) : il arrivera le 1er juillet.',montant:320000},
            ...['Selon la presse, Castres suit Léo Ferrand, ouvreur de Brive en fin de contrat.','Selon la presse, Clermont suit Tom Garnier, pilier droit de Vannes en fin de contrat.',
              'Selon la presse, Lyon suit Nathan Roux, centre d’Agen en fin de contrat.','Selon la presse, Bayonne suit Paul Vidal, talonneur d’Oyonnax en fin de contrat.',
              'Selon la presse, Pau suit Louis Martin, ailier de Colomiers en fin de contrat.','Selon la presse, Brive suit Adam Petit, deuxième ligne de Béziers en fin de contrat.'].map(texte=>({type:'rumeur',texte,montant:0}))],
          41:[['La Rochelle s’est mis d’accord avec Toulon pour Mathis Blanc (centre) : il arrivera le 1er juillet.',180000],['Montpellier s’est mis d’accord avec Castres pour Enzo Moreau (demi de mêlée) : il arrivera le 1er juillet.',260000],
            ['Toulouse s’est mis d’accord avec Bayonne pour Jules Fabre (pilier gauche) : il arrivera le 1er juillet.',410000],['Bordeaux s’est mis d’accord avec Lyon pour Noah Girard (arrière) : il arrivera le 1er juillet.',350000],
            ['Clermont s’est mis d’accord avec Pau pour Victor Simon (deuxième ligne) : il arrivera le 1er juillet.',220000]].map(([texte,montant])=>({type:'accord',texte,montant}))}};
        const recevoir=(d,w)=>{X.worldMode.week=w;X.clubMail.last=new Date(Date.parse(d+'T00:00:00Z')-86400000).toISOString().slice(0,10);
          const n=X.clubMail.mails.length;nativeSystems.domain('clubMail').recevoir(X,d);return X.clubMail.mails.slice(n);};
        const e=recevoir('2027-02-10',30);
        X.economy.offers=[0,1,2].map(i=>({id:'offre-mai-'+i,playerId:X.clubs[X.club].players[10+i].id,buyer:autres[i],fee:400000+i*50000,expires:X.economy.week+20}));
        const p=recevoir('2027-05-12',41);
        X.worldMode.week=wk;X.clubMail.last=last;cad.maxParJour=max;
        for(const x of [...e,...p])x.date=today;
        return {echos:e.find(x=>x.type==='echos_mercato')?.id??null,point:p.find(x=>x.type==='point_mercato')?.id??null,types:[...e,...p].map(x=>x.type)};})()`);
      assert.ok(courriers.echos && courriers.point, 'courriers du mercato reçus : ' + JSON.stringify(courriers));
      m = jeu.call('save');
      m = jeu.call('snapshot');
      const corps = id => m.clubLife.clubMail.mails.find(x => x.id === id);
      const point = corps(courriers.point), echos = corps(courriers.echos);
      assert.equal(point.ecran, 'ventes'); assert.equal(point.nature, 'info');
      assert.equal((point.corps.match(/ propose [^\n]+ pour /g) || []).length, 3, point.corps);
      assert.equal((echos.corps.match(/^• /gm) || []).length, 6, echos.corps);
      assert.match(echos.corps, /\net 2 autres\n/);
      assert.ok(m.sales.offers.length >= 3, 'offres reçues à l’écran des ventes');
      const fiche = m.squad.find(p => p.id === approche.playerId).preContract;
      assert.equal(fiche.state, 'approche');
      assert.ok(m.clubLife.clubMail.mails.some(x => x.type === 'precontrat_approche' && x.ecran === 'prolongation'));
      const signeVue = liste().candidates.find(c => c.id === signe.id);
      assert.ok(signeVue.preContract.signed, 'pré-contrat signé visible au marché');
      attendu = { summary: m.mutations.summary, interclubNote: m.mutations.interclub.note, signe: { id: signe.id, label: signeVue.preContract.signed.label },
        devis, approche: { playerId: approche.playerId, short: fiche.short },
        point: { id: point.id, sujet: point.sujet }, echos: { id: echos.id, sujet: echos.sujet }, court, today: m.meta.calendarToday };
    } finally { R.preContrats = JSON.parse(JSON.stringify(origine)); jeu.fermer(); }
    const sortie = process.env.CD_CALENDRIER_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-calendrier-captures-'));
    fs.mkdirSync(sortie, { recursive: true });
    const graphique = process.env.CD_CALENDRIER_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', process.platform === 'win32' ? 'windows' : 'x11','--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-calendrier-mutations.gd')];
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
    if (graphique) for (const f of ['calendrier-recrutement.png', 'calendrier-marche.png', 'calendrier-precontrat.png', 'calendrier-confirmation.png', 'calendrier-fiche.png',
      'calendrier-ventes.png', 'calendrier-point-mercato.png', 'calendrier-echos-mercato.png', 'calendrier-effectif-court.png']) assert.ok(fs.existsSync(path.join(sortie, f)), 'capture ' + f);
    console.log('Captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
