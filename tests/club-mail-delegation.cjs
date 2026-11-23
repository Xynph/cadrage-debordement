'use strict';
// Délégation du courrier à l'adjoint (choix de Léo, 23/11/2026 ; native/engine/club-mail.cjs, adjoint()) : sur un mail
// qui attend une réponse, « Déléguer » (choix `deleguer` de `club_mail_reply`) laisse Gabi répondre à la place du
// manager avec une des réponses propres au mail.
//   1. Pour chaque type de courrier à réponses : la réponse de Gabi est possible aujourd'hui, n'ouvre jamais d'écran,
//      est la même d'un appel à l'autre (aucun tirage) et figure dans la projection (`adjoint`) ; sans réponse possible
//      hors écran (commotion), pas de délégation. Chaque réponse projetée porte sa famille (`genre`).
//   2. Le choix suit le contexte : trésorerie (sortie d'équipe, rapport d'agent), fatigue du joueur et de l'effectif,
//      blessure, satisfaction, confiance de la direction ; Gabi ne vend pas, ne promet pas à un joueur content.
//   3. Commande : la réponse de Gabi est appliquée comme celle du manager (même effet que la réponse choisie à la
//      main), le mail est marqué « délégué » et affiche la réponse ; une seconde réponse est refusée.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const DATA = require('../native/engine/club-mail.json');
const M = require('./helpers/carriere-monde.cjs');

const GENRES = ['ecran', 'soin', 'effort', 'jeu', 'promesse', 'direction', 'competition', 'argent', 'presse', 'groupe', 'attente', 'refus', 'neutre'];
const TYPES = Object.entries(DATA.types).filter(([, t]) => (t.reponses || []).length).map(([k]) => k);

test('Données : la délégation ne remplace aucune réponse propre (« deleguer » n\'est l\'identifiant d\'aucune réponse)', () => {
  for (const k of TYPES) for (const r of DATA.types[k].reponses) assert.notEqual(r.id, 'deleguer', k);
});

test('Carrière Monde : Gabi répond à ta place, selon le contexte, de façon déterministe', { timeout: 600000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-delegation-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
  try {
    jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    const vm = jeu.bridge.vm;
    const js = code => JSON.parse(vm.run(`JSON.stringify((()=>{${code}})())`));
    // Un mail de chaque type à réponses, adressé au même joueur de l'effectif (posé directement dans la boîte).
    const joueur = js(`return S.clubs[S.club].players[0].id`);
    const poser = (type, extra = '') => js(`const st=S.clubMail,d=CDWorldCareer.calendarToday(S),id='mail-'+(++st.seq);
      st.mails.push({id,type:${JSON.stringify(type)},date:d,f:0,vars:{joueur:'Test'},player:${JSON.stringify(joueur)},status:'nouveau',choice:null});${extra}
      nativeSystems.domain('clubMail').validate(S);return id;`);
    const gabi = id => js(`return nativeSystems.domain('clubMail').adjoint(S,${JSON.stringify(id)})`);
    const projete = id => js(`return nativeSystems.domain('clubMail').project().mails.find(m=>m.id===${JSON.stringify(id)})||null`);
    const regler = code => js(code + ';return true');

    // 1. Tous les types : réponse possible, hors écran, stable, projetée.
    const ids = {};
    for (const type of TYPES) ids[type] = poser(type);
    let delegables = 0;
    for (const type of TYPES) {
      const id = ids[type], choix = gabi(id), mail = projete(id);
      assert.ok(mail, type + ' : mail projeté');
      for (const r of mail.reponses) assert.ok(GENRES.includes(r.genre), type + '/' + r.id + ' : famille ' + r.genre);
      assert.equal(mail.adjoint, choix, type + ' : projection = choix de Gabi');
      assert.equal(gabi(id), choix, type + ' : même choix au second appel');
      const possibles = mail.reponses.filter(r => r.disponible && !r.ouvrir);
      if (!possibles.length) { assert.equal(choix, null, type + ' : aucune réponse possible hors écran, pas de délégation'); continue; }
      delegables++;
      const r = mail.reponses.find(x => x.id === choix);
      assert.ok(r && r.disponible && !r.ouvrir, type + ' : réponse de Gabi possible et sans écran (' + choix + ')');
    }
    assert.ok(delegables >= TYPES.length - 8, 'au moins ' + (TYPES.length - 8) + ' types délégables : ' + delegables);
    console.log('Choix de Gabi :', TYPES.map(t => t + '=' + gabi(ids[t])).join(', '));
    assert.equal(gabi(ids.commotion), null, 'commotion : l\'infirmerie décide, pas de délégation');
    assert.equal(projete(ids.commotion).adjoint, null);
    // Familles attendues de quelques réponses (couleur et pictogramme de l'interface).
    const genreDe = (type, rep) => projete(ids[type]).reponses.find(r => r.id === rep).genre;
    assert.equal(genreDe('agent', 'negocier'), 'ecran');
    assert.equal(genreDe('blessure', 'repos'), 'soin');
    assert.equal(genreDe('blessure', 'presser'), 'effort');
    assert.equal(genreDe('analyste', 'conquete'), 'jeu');
    assert.equal(genreDe('temps_de_jeu', 'promettre'), 'promesse');
    assert.equal(genreDe('investissements', 'staff'), 'direction');
    assert.equal(genreDe('sponsor', 'operation'), 'argent');
    assert.equal(genreDe('critique', 'calme'), 'presse');
    assert.equal(genreDe('moral_groupe', 'reunir'), 'groupe');
    assert.equal(genreDe('prolongation', 'refuser'), 'refus');
    assert.equal(genreDe('agent', 'decliner'), 'neutre');
    assert.equal(genreDe('doublon', 'rotation'), 'competition');

    // 2. Contexte.
    const club = 'S.clubs[S.club]', p = `${club}.players.find(x=>x.id===${JSON.stringify(joueur)})`;
    const possible = (type, rep) => !!projete(ids[type]).reponses.find(r => r.id === rep && r.disponible);
    regler(`${club}.cash=5000000`);
    assert.equal(gabi(ids.moral_groupe), 'sortie', 'caisse pleine : sortie d\'équipe');
    assert.equal(gabi(ids.agent), 'rapport', 'caisse pleine : rapport du recruteur');
    regler(`${club}.cash=30000`);
    assert.equal(gabi(ids.moral_groupe), 'reunir', 'caisse juste : réunion, sans dépense');
    assert.equal(gabi(ids.agent), 'decliner', 'caisse juste : pas de rapport payant');
    regler(`${club}.cash=5000000`);
    regler(`const l=${p};l.physicalLoad={version:1,fatigue:85,plan:'collective'}`);
    assert.equal(gabi(ids.surcharge), 'reposer', 'joueur très chargé : repos');
    assert.equal(gabi(ids.gene), 'medecin', 'gêne : le médecin, pas aligné');
    regler(`const l=${p};l.physicalLoad={version:1,fatigue:5,plan:'collective'}`);
    assert.equal(gabi(ids.gene), 'medecin', 'gêne, joueur frais : le médecin quand même');
    assert.notEqual(gabi(ids.retour_blesse), 'rythme', 'retour de blessure : pas de pleine charge d\'emblée');
    regler(`const l=${p};l.injury=3;l.injuryRelapse=10`);
    assert.notEqual(gabi(ids.blessure), 'presser', 'blessé : jamais presser le retour');
    regler(`const l=${p};l.injury=0;delete l.injuryRelapse`);
    regler(`const l=${p};if(typeof ensureSatisfaction==='function')ensureSatisfaction(l);if(l.satisfaction)l.satisfaction.score=80`);
    assert.notEqual(gabi(ids.temps_de_jeu), 'promettre', 'joueur content : pas de promesse');
    assert.notEqual(gabi(ids.pret_actionnaire), 'vendre', 'jamais de vente décidée par l\'adjoint');
    assert.notEqual(gabi(ids.discipline), 'appel', 'pas d\'appel risqué');
    assert.notEqual(gabi(ids.pepite), 'integrer', 'pas de contrat professionnel signé par l\'adjoint');
    for (const t of ['ds_prolongation', 'ds_depart', 'ds_staff']) assert.equal(gabi(ids[t]), 'ok', t + ' : il suit le directeur sportif');
    regler(`S.trust=75`);
    assert.equal(gabi(ids.critique), 'proteger', 'direction confiante : il protège le groupe');
    regler(`S.trust=20`);
    assert.equal(gabi(ids.critique), 'offensif', 'direction méfiante : il protège sans fâcher la direction');
    assert.equal(gabi(ids.president), 'temps', 'direction méfiante : il demande du temps');
    regler(`S.trust=60`);
    assert.equal(gabi(ids.president), 'bilan', 'direction confiante : bilan simple');
    if (possible('kine_bilan', 'recuperation')) {
      regler(`for(const x of ${club}.players)x.physicalLoad={version:1,fatigue:70,plan:'collective'}`);
      assert.equal(gabi(ids.kine_bilan), 'recuperation', 'effectif fatigué : séance de récupération');
      regler(`for(const x of ${club}.players)x.physicalLoad={version:1,fatigue:5,plan:'collective'}`);
      assert.equal(gabi(ids.kine_bilan), 'programme', 'effectif frais : programme maintenu');
    }

    // 3. Commande : Gabi répond, la réponse est appliquée, le mail le dit.
    regler(`${club}.cash=5000000;for(const x of ${club}.players)x.physicalLoad={version:1,fatigue:20,plan:'collective'}`);
    const avant = js(`return {morale:S.morale,cash:${club}.cash}`);
    const attendu = gabi(ids.moral_groupe);
    assert.equal(attendu, 'sortie');
    const r = jeu.brut('club_mail_reply', { id: ids.moral_groupe, choice: 'deleguer' });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.clubMailReply.choice, 'sortie');
    assert.equal(r.model.meta.clubMailReply.delegue, true);
    assert.equal(r.model.meta.clubMailReply.ouvrir, false);
    const apres = js(`return {morale:S.morale,cash:${club}.cash}`);
    assert.equal(apres.morale, Math.min(98, avant.morale + 2), 'moral +2 de la sortie');
    assert.equal(apres.cash, avant.cash - 4000, 'sortie payée 4 000 €');
    const vu = r.model.clubLife.clubMail.mails.find(m => m.id === ids.moral_groupe);
    assert.equal(vu.status, 'repondu');
    assert.equal(vu.delegue, true);
    assert.equal(vu.adjoint, undefined, 'plus de proposition une fois répondu');
    assert.deepEqual(vu.reponse, { id: 'sortie', libelle: DATA.types.moral_groupe.reponses.find(x => x.id === 'sortie').libelle, genre: 'groupe' });
    assert.equal(r.model.clubLife.clubMail.reponses[ids.moral_groupe], 'sortie');
    assert.equal(r.model.clubLife.clubMail.delegues[ids.moral_groupe], true, 'liste des mails délégués');
    assert.match(jeu.brut('club_mail_reply', { id: ids.moral_groupe, choice: 'deleguer' }).error, /déjà répondu/);
    assert.match(jeu.brut('club_mail_reply', { id: ids.commotion, choice: 'deleguer' }).error, /Gabi ne peut pas répondre/);
    // Réponse choisie à la main : pas marquée déléguée.
    const main = jeu.brut('club_mail_reply', { id: ids.anniversaire, choice: 'rien' });
    assert.equal(main.ok, true, main.error);
    assert.equal(main.model.meta.clubMailReply.delegue, false);
    assert.equal(main.model.clubLife.clubMail.mails.find(m => m.id === ids.anniversaire).delegue, false);
    assert.equal(main.model.clubLife.clubMail.delegues[ids.anniversaire], undefined);
    // Plusieurs délégations à la suite : chacune applique la réponse annoncée.
    for (const type of ['agent', 'critique', 'analyste', 'sponsor', 'investissements']) {
      const prevu = gabi(ids[type]);
      if (prevu === null) continue;
      const x = jeu.brut('club_mail_reply', { id: ids[type], choice: 'deleguer' });
      assert.equal(x.ok, true, type + ' : ' + x.error);
      assert.equal(x.model.meta.clubMailReply.choice, prevu, type + ' : réponse annoncée appliquée');
    }
    js(`nativeSystems.domain('clubMail').validate(S);return true`);
  } finally {
    jeu.fermer();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
