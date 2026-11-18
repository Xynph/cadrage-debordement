'use strict';
// Courrier du club avec réponses (décision de Léo, 16/11/2026 ; native/engine/club-mail.cjs + club-mail.json).
//   1. Données : catégories, déclencheurs, formulations (au moins deux par type), réponses et effets connus.
//   2. Carrière Monde (`world-champ`, départ « veille », calendrier journalier, journal d'actions) jouée à « Continuer »
//      sur cinq semaines (fenêtre allongée le 18/11/2026 : certains courriers dépendent d'une série de défaites), en répondant aux mails : au moins 25 types reçus, jamais deux fois de suite la même
//      formulation pour un type, une réception n'écrit que la boîte (monde et graine inchangés), une réponse ne se
//      donne qu'une fois, et les mails qui le demandent arrêtent « Continuer » sur le bon écran.
//   3. Journal : profil copié en cours de partie (arrêt imprévu), rouvert : les réponses rejouées donnent la même
//      carrière (état et graine identiques).
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const DATA = require('../native/engine/club-mail.json');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const EFFETS = ['moral', 'confiance', 'supporters', 'medias', 'pression', 'satisfaction', 'fatigue', 'condition', 'plan', 'entrainement', 'focus', 'promesse', 'promouvoir', 'caisse', 'suite', 'appel', 'contratDS', 'consigneDS', 'orientation', 'pret', 'a2r', 'reprise', 'doublon', 'repos_liste', 'specialiste'];

test('Données : catalogue complet, formulations variées, effets connus', () => {
  const types = Object.entries(DATA.types);
  assert.ok(types.length >= 30, types.length + ' types');
  for (const [id, t] of types) {
    assert.ok(DATA.categories[t.categorie], id + ' : catégorie');
    assert.ok(DATA.cadence.semaine[t.categorie] > 0, id + ' : plafond hebdomadaire');
    assert.ok(t.formulations.length >= 2 || t.declencheur === 'suite' || id === 'selection_jeune', id + ' : formulations');
    for (const f of t.formulations) assert.ok(f.sujet && f.corps && !/fictif|généré|\bIA\b/i.test(f.sujet + f.corps), id + ' : texte');
    for (const r of t.reponses) {
      assert.ok(r.id && r.libelle && r.resultat, id + ' : réponse');
      for (const k of Object.keys(r.effets)) assert.ok(EFFETS.includes(k), id + '/' + r.id + ' : effet ' + k);
      if (r.effets.suite) assert.ok(DATA.types[r.effets.suite.type], id + ' : suite');
      // Effets mesurés : jauges à ±3 au plus (±8 de satisfaction pour un refus net), trésorerie à 20 000 € au plus.
      for (const k of ['moral', 'confiance', 'supporters', 'medias', 'pression']) if (r.effets[k] !== undefined) assert.ok(Math.abs(r.effets[k]) <= 3, id + '/' + r.id + ' ' + k);
      if (r.effets.satisfaction !== undefined) assert.ok(Math.abs(r.effets.satisfaction) <= 8);
      if (r.effets.caisse !== undefined) assert.ok(Math.abs(r.effets.caisse) <= 20000);
    }
  }
});

// Choix du manager pendant la partie (sinon la première réponse possible).
const CHOIX = { temps_de_jeu: 'plus_tard', relance_temps_de_jeu: 'promettre', agent: 'rapport', discipline: 'appel', gene: 'medecin', surcharge: 'alleger', president: 'bilan', cadre_rdv: 'recevoir', prolongation: 'reporter', pepite: 'progresser', moral_groupe: 'sortie', seance_adjoint: 'garder', analyste: 'conquete', kine_bilan: 'programme', critique: 'calme' };
const FIN = '2026-10-21';
const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const ouvrir = dir => M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
const etat = jeu => ({ texte: sha(jeu.bridge.vm.run('JSON.stringify(S)')), graine: jeu.bridge.vm.seed() });

test('Carrière Monde : courrier varié, réponses enregistrées, monde inchangé à la réception, rejeu identique', { timeout: 900000 }, () => {
  const t0 = Date.now(), dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-courrier-'));
  let copie = null;
  const jeu = ouvrir(dir);
  try {
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    const vm = jeu.bridge.vm, arrets = [], reponses = [], durees = { creation: Date.now() - t0, reponses: 0, controles: 0 };
    let receptions = 0;
    // Réception rejouée sur une copie de la carrière : seule la boîte change, la graine ne bouge pas.
    const receptionNeutre = () => {
      const verdict = JSON.parse(vm.run(`(()=>{const x=JSON.parse(JSON.stringify(S)),d=CDWorldCareer.calendarToday(S);if(!x.clubMail||!x.clubMail.last)return JSON.stringify({ok:true,skip:true});
        const sans=o=>JSON.stringify({...o,clubMail:null});x.clubMail.last=new Date(Date.parse(d+'T00:00:00Z')-86400000).toISOString().slice(0,10);
        x.clubMail.mails=x.clubMail.mails.filter(m=>m.date<d);const avant=sans(x),n=x.clubMail.mails.length;nativeSystems.domain('clubMail').recevoir(x,d);
        return JSON.stringify({ok:sans(x)===avant,recus:x.clubMail.mails.length-n});})()`));
      return verdict;
    };
    for (let i = 0; i < 400 && m.meta.calendarToday < FIN; i++) {
      m = jeu.regler(m);
      // Copie complète de la carrière (~25 Mo) : contrôle un tour sur quatre pour tenir la durée de la CI de PR.
      if (i % 4 === 0) {
        const debut = Date.now(), graine = vm.seed(), v = receptionNeutre();
        durees.controles += Date.now() - debut;
        assert.equal(v.ok, true, 'réception du ' + m.meta.calendarToday + ' : le monde a changé');
        assert.equal(vm.seed(), graine, 'réception : graine inchangée');
        receptions++;
      }
      // Réponses aux mails en attente (choix scénarisés), puis une seconde réponse refusée.
      // Une réponse par type de mail (chaque réponse coûte une projection complète du modèle).
      for (const mail of m.clubLife.clubMail.mails.filter(x => x.status === 'nouveau' && x.reponses.some(r => r.disponible) && !reponses.some(y => y.startsWith(x.type + '/')))) {
        const choix = mail.reponses.find(r => r.id === CHOIX[mail.type] && r.disponible) || mail.reponses.find(r => r.disponible);
        // Réponse déclarée « club du manager seulement » (state-versions.cjs, OWN_CLUB) : sections lourdes autres que les
        // clubs et clubs autres que celui du manager intacts (sinon la projection garderait un texte périmé).
        const horsClub = () => sha(vm.run('JSON.stringify([S.aiRoster,S.staffCareer,S.potentialEvolution,S.worldMode,S.matchNotes,S.clubs.filter((c,i)=>i!==S.club)])'));
        const avantReponse = horsClub();
        const debut = Date.now(), r = jeu.brut('club_mail_reply', { id: mail.id, choice: choix.id });
        durees.reponses += Date.now() - debut;
        if (r.ok) assert.equal(horsClub(), avantReponse, mail.type + '/' + choix.id + ' : seul le club du manager change');
        assert.equal(r.ok, true, mail.type + '/' + choix.id + ' : ' + r.error);
        m = r.model;
        assert.equal(m.meta.clubMailReply.choice, choix.id);
        assert.equal(m.clubLife.clubMail.reponses[mail.id], choix.id);
        reponses.push(mail.type + '/' + choix.id);
        if (reponses.length === 1) assert.match(jeu.brut('club_mail_reply', { id: mail.id, choice: choix.id }).error, /déjà répondu/);
      }
      if (m.meta.calendarCadence?.matchReady && m.next) { m = M.jouerLeMatch(jeu, m); continue; }
      if (m.live) { m = jeu.regler(skipMatchTalk(jeu.call('finish_round'), jeu.call)); continue; }
      const borne = Math.max(1, Math.round((Date.parse(FIN) - Date.parse(m.meta.calendarToday)) / 86400000));
      const r = jeu.brut('advance_until_event', { fromDate: m.meta.calendarToday, maxDays: Math.min(120, borne), stops: { messages: 'aucun' } });
      assert.equal(r.ok, true, 'Continuer le ' + m.meta.calendarToday + ' : ' + r.error);
      m = r.model;
      const a = m.meta.advanceUntilEvent.stop;
      if (a.kind === 'info') arrets.push(a);
      const scene = vm.run('S.sceneInvitations?.activeId||null');
      if (scene) m = jeu.call('scene_invitation_close', { id: scene, dismiss: true });
    }
    // Arrêt imprévu : copie du profil avec son journal, avant toute sauvegarde de fermeture.
    copie = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-courrier-rejeu-'));
    fs.cpSync(dir, copie, { recursive: true });
    fs.rmSync(path.join(copie, 'PrototypeGodot', 'profil.lock'), { force: true });
    const reference = etat(jeu);
    const brut = JSON.parse(vm.run('JSON.stringify(S.clubMail)'));
    const mails = brut.mails;
    const types = [...new Set(mails.map(x => x.type))];
    console.log(m.meta.calendarToday, '·', mails.length, 'mails ·', types.length, 'types ·', reponses.length, 'réponses ·', arrets.length, 'arrêts informatifs ·', Math.round((Date.now() - t0) / 1000), 's');
    console.log('Types :', types.join(', '));
    console.log('Réponses :', reponses.join(', '));
    assert.ok(types.length >= 25, 'au moins 25 types de mails : ' + types.length);
    // Pas de spam : plafond par jour respecté, et en moyenne moins de trois mails par jour.
    const parJour = {};
    for (const x of mails) parJour[x.date] = (parJour[x.date] || 0) + 1;
    for (const [d, n] of Object.entries(parJour)) assert.ok(n <= DATA.cadence.maxParJour, d + ' : ' + n + ' mails');
    const jours = Math.round((Date.parse(m.meta.calendarToday) - Date.parse(mails[0].date)) / 86400000) + 1;
    assert.ok(receptions >= 5, receptions + ' réceptions contrôlées');
    assert.ok(mails.length <= 2.5 * jours, mails.length + ' mails en ' + jours + ' jours');
    // Formulations : jamais deux fois de suite la même pour un type ; textes presque tous distincts.
    const dernier = {};
    for (const x of mails) {
      if ((DATA.types[x.type].formulations.length > 1) && dernier[x.type] !== undefined) assert.notEqual(x.f, dernier[x.type], x.type + ' répété le ' + x.date);
      dernier[x.type] = x.f;
    }
    const textes = m.clubLife.clubMail.mails.map(x => x.sujet + '|' + x.corps);
    assert.ok(new Set(textes).size >= textes.length * 0.9, 'textes distincts : ' + new Set(textes).size + '/' + textes.length);
    for (const x of m.clubLife.clubMail.mails) assert.doesNotMatch(x.sujet + x.corps + x.expediteur, /\{|\}|undefined|NaN/, x.type);
    // Réponses variées et arrêts : le mail qui attend une réponse arrête « Continuer » sur la Réception.
    assert.ok(new Set(reponses.map(x => x.split('/')[0])).size >= 10, 'réponses à au moins 10 types de mails');
    assert.ok(reponses.includes('agent/rapport') && types.includes('rapport_agent'), 'rapport demandé à un agent puis reçu');
    const courrier = arrets.filter(x => x.type === 'courrier');
    assert.ok(courrier.length >= 3 && courrier.every(x => x.mail && x.ecran === 'Réception'), 'arrêts courrier : ' + courrier.length);
    assert.ok(arrets.some(x => x.type === 'veille' && x.ecran === 'Composition'), 'veille : composition');
    // Rejeu du journal : même carrière.
    durees.partie = Date.now() - t0;
    const rejeu = ouvrir(copie);
    try {
      const snap = rejeu.call('snapshot');
      assert.ok(snap.meta.autosave?.notice?.replayed > 0, 'actions reprises du journal : ' + JSON.stringify(snap.meta.autosave?.notice));
      const apres = etat(rejeu);
      assert.equal(apres.texte, reference.texte, 'carrière rejouée identique');
      assert.equal(apres.graine, reference.graine, 'graine rejouée identique');
    } finally { rejeu.bridge.close(); }
    console.log('Durée totale', Math.round((Date.now() - t0) / 1000), 's', JSON.stringify(durees));
  } finally {
    jeu.fermer();
    fs.rmSync(dir, { recursive: true, force: true });
    if (copie) fs.rmSync(copie, { recursive: true, force: true });
  }
});
