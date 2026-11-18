'use strict';
// Plan de jeu probable de l'adversaire (18/11/2026, suite de #906) : dès la veille du match, le staff lit le style
// d'attaque que l'IA adverse choisira au coup d'envoi (avant-match.cjs planAdverse, même calcul que opposition.js).
// Vérifie, sur une vraie carrière Monde (world-champ, club 102, calendrier journalier) :
//  - le mail de la veille (club-mail.cjs `plan_adverse`) avec ses actions (composition, consignes) ;
//  - la tuile adversaire et une clé de Gabi le jour du match (clubLife.avantMatch.planAdverse) ;
//  - la lecture est honnête : le style « réel » du contrôle est celui que l'IA retient au coup d'envoi, et l'annonce
//    est ce style ou, si le staff se trompe, le deuxième ;
//  - rien n'est annoncé pendant le match ; en Découverte, l'annonce est l'identité fixe du club.
const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('./helpers/carriere-monde.cjs');

const STYLES = ['equilibre', 'large', 'conquete', 'occupation'];

test('Plan adverse : mail de la veille, avant-match, coup d’envoi', { timeout: 900000 }, () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    const vm = jeu.bridge.vm;
    const lire = src => JSON.parse(vm.run('JSON.stringify(' + src + ')'));
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102 }));
    const mails = [];
    let veillePlan = null;
    for (let j = 0; j < 150; j++) {
      m = jeu.regler(m);
      for (const x of m.clubLife.clubMail.mails) if (x.type === 'plan_adverse' && !mails.some(y => y.id === x.id)) mails.push(x);
      const am = m.clubLife.avantMatch;
      if (am?.planAdverse && !veillePlan) veillePlan = { jour: m.meta.calendarToday, plan: am.planAdverse };
      if (!am?.planAdverse && am && !(m.meta.calendarCadence?.matchReady && m.next)) {
        // Avant la veille : aucune annonce (la météo n'est pas encore connue).
        assert.equal(lire('CDWorldCareer.meteoAnnoncee(S)'), null, 'pas de plan sans météo annoncée');
      }
      if (m.meta.calendarCadence?.matchReady && m.next) break;
      m = jeu.call('advance_day', { fromDate: m.meta.calendarToday });
    }
    assert.ok(m.meta.calendarCadence?.matchReady, 'jour de match atteint');
    const f = lire('CDWorldCareer.userFixture(S)');
    const veille = new Date(Date.parse(m.meta.calendarToday + 'T00:00:00Z') - 86400000).toISOString().slice(0, 10);

    // Mail de la veille.
    const mail = mails.find(x => x.key === f.id) || mails[mails.length - 1];
    assert.ok(mail, 'mail « plan adverse » reçu avant le match');
    assert.ok([veille, m.meta.calendarToday].includes(String(mail.date).slice(0, 10)), 'reçu la veille ou le matin du match (quota du courrier)');
    assert.equal(mail.expediteur, 'Gabi, ton adjoint');
    assert.match(mail.corps, /(ils vont (jouer au près|jouer au large|occuper au pied|varier le jeu))/, 'annonce du style');
    assert.deepEqual(mail.reponses.map(r => r.id), ['composition', 'consignes', 'rien']);
    assert.ok(mail.reponses.find(r => r.id === 'consignes').ouvrir, 'action : ouvrir les consignes');
    assert.ok(veillePlan && veillePlan.jour === veille, 'tuile adversaire remplie dès la veille');

    // Avant-match du jour : tuile adversaire et clé de Gabi.
    const plan = m.clubLife.avantMatch.planAdverse;
    assert.ok(plan, 'plan adverse le jour du match');
    assert.ok(STYLES.includes(plan.style));
    for (const k of ['titre', 'raison', 'conseil', 'libelle']) assert.ok(typeof plan[k] === 'string' && plan[k].length > 3, k);
    assert.ok(['sure', 'probable', 'incertaine'].includes(plan.confiance));
    assert.ok(['composition', 'consignes'].includes(plan.action));
    assert.equal(plan.reel, undefined, 'le vrai choix de l’IA n’est jamais projeté');
    assert.ok(m.clubLife.avantMatch.gabi.cles.some(c => c.titre === plan.titre), 'une des trois clés de Gabi');

    // Projection déterministe (même état, même lecture).
    const ctlAvant = lire('nativeSystems.domain("avantMatch").planAdverse(S,CDWorldCareer.userFixture(S),undefined,true)');
    assert.deepEqual(lire('nativeSystems.domain("avantMatch").planAdverse(S,CDWorldCareer.userFixture(S),undefined,true)'), ctlAvant);

    // Coup d'envoi : feuille validée, contrôle relu juste avant, puis le style que l'IA retient vraiment.
    if (!m.selection.valid) m = jeu.call('auto_lineup');
    if (!m.selection.valid) m = jeu.call('promote_cover', { confirmed: true });
    const ctl = lire('nativeSystems.domain("avantMatch").planAdverse(S,CDWorldCareer.userFixture(S),undefined,true)');
    m = M.jouerLeMatch(jeu, m, { delegue: false });
    const live = lire('{t:S.live.tactics,u:S.live.userSide}');
    const reel = live.t[1 - live.u];
    assert.equal(ctl.reel, reel, 'la lecture du staff part du vrai choix de l’IA au coup d’envoi');
    assert.ok(ctl.style === ctl.reel || ctl.chance > 0, 'une annonce fausse n’arrive que si le staff peut se tromper');
    assert.equal(m.clubLife.avantMatch ?? null, null, 'rien n’est annoncé pendant le match');

    // Découverte : l'identité fixe du club, lecture nette.
    vm.run('S.__live=S.live;S.live=null;S.__d=S.difficulty;S.difficulty="decouverte"');
    const dec = lire('nativeSystems.domain("avantMatch").planAdverse(S,CDWorldCareer.userFixture(S),"Sec",true)');
    const adv = f.homeId === lire('S.club') ? f.awayId : f.homeId;
    vm.run('S.live=S.__live;S.difficulty=S.__d;delete S.__live;delete S.__d');
    assert.equal(dec.style, lire('managerStyle(' + adv + ')'));
    assert.equal(dec.confiance, 'sure');
  } finally { jeu.fermer(); }
});
