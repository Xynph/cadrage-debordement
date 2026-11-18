'use strict';
// Promesses publiques en conférence de presse, carrière Monde (world-champ) : question d'objectif facultative,
// vraisemblance et réactions à l'annonce, refus, verdict (tenue / non tenue) avec effets sur supporters, direction et
// crédibilité (réputation du manager), articulation avec l'objectif de classement du conseil, sauvegarde et
// validateur. La saison complète (rappels, verdicts aux vraies échéances) : tests/presse-promesses-saison.cjs.
const assert = require('node:assert/strict');
const { test, after } = require('node:test');
const H = require('./monde-harness.cjs');

// Une carrière neuve par cas (new_career du worker) : le worker garde la main sur l'état entre les commandes.
const h = H.context(827381, { club: null, console: false });
after(() => h.close());
const nouvelle = (club = 0) => h.start(club);
// Projection lue dans la VM : l'avance rapide du harnais ne passe pas par le worker (dont l'instantané est mis en cache).
const modele = () => ({ clubLife: JSON.parse(h.run('JSON.stringify(nativeSystems.project())')) });
const etat = () => h.state();
const promesses = () => etat().pressPromises;
const messages = () => etat().manager.inbox.map(m => m.title);

// Conférence de la semaine en cours, réponses « honnêtes », avec l'objectif choisi (ou sans).
function conference(promise) {
  const m = modele(), conf = m.clubLife.press.conference;
  assert.equal(conf.available, true, 'conférence ouverte');
  const payload = { context: m.clubLife.press.context, answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers[1].id })) };
  if (promise !== undefined) payload.promise = promise;
  return { model: h.command('press_conference', payload), offre: conf.promise };
}

test('la conférence pose une question d’objectif facultative, avec vraisemblance et réactions', () => {
  nouvelle();
  const offre = modele().clubLife.press.conference.promise;
  assert.ok(offre, 'question d’objectif proposée en début de saison');
  assert.equal(offre.optional, true);
  const sortes = new Set(offre.options.map(o => o.kind));
  for (const k of ['rank', 'europe', 'maintien', 'home_wins', 'youth']) assert.ok(sortes.has(k), 'objectif ' + k + ' proposé (Top 14)');
  assert.equal(offre.refuse.id, 'refuse');
  for (const o of offre.options) {
    assert.ok(['modeste', 'realiste', 'ambitieux', 'irrealiste'].includes(o.realism), o.id);
    assert.match(o.consequence, /Supporters .* médias .* confiance .* pression/);
  }
  // Le favori (club 0) : le titre est au mieux « ambitieux », la simple qualification européenne est « modeste ».
  assert.equal(offre.options.find(o => o.id === 'rank:1').realism, 'ambitieux');
  assert.equal(offre.options.find(o => o.id === 'europe').realism, 'modeste');
  // Choix inconnu : refusé avant toute publication.
  const m = modele(), conf = m.clubLife.press.conference;
  assert.throws(() => h.command('press_conference', { context: m.clubLife.press.context, answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers[1].id })), promise: 'rank:99' }), /objectif périmé ou inconnu/);
  assert.equal(etat().pressConference, undefined, 'rien publié');
  // Sans réponse à la question : conférence publiée, la question reviendra.
  conference();
  assert.equal(promesses(), undefined, 'aucune promesse ni refus');
});

test('promesse tenue : supporters, direction et crédibilité (réputation du manager) progressent', () => {
  nouvelle();
  const reputation = h.run('managerMobilityProfile()');
  const avant = modele().clubLife.press.metrics;
  const { model, offre } = conference('youth:3');
  const annonce = offre.options.find(o => o.id === 'youth:3');
  const actives = model.clubLife.pressPromises.active;
  assert.equal(actives.length, 1);
  assert.equal(actives[0].label, 'Lancer 3 jeunes du centre en équipe première');
  assert.ok(avant.fanTrust + annonce.effects.fanTrust <= 100);
  assert.deepEqual(promesses().promises[0].announce, annonce.effects, 'réactions annoncées = réactions appliquées');
  // La question n'est plus posée cette semaine.
  assert.equal(modele().clubLife.press.conference.promise ?? null, null);
  // Trois jeunes du centre signent pro : le suivi les relève à la journée suivante.
  for (const id of JSON.parse(h.run('JSON.stringify(S.development.academy.filter(p=>p.age>=18).slice(0,3).map(p=>p.id))'))) assert.equal(h.run('promoteYouth(' + JSON.stringify(id) + ')'), true);
  h.week(1);
  assert.equal(promesses().promises[0].youthIds.length, 3, 'jeunes lancés relevés pendant la saison');
  assert.match(modele().clubLife.pressPromises.active[0].progress.label, /3 \/ 3 jeunes lancés/);
  const jauges = { fan: etat().pressRelations.fanTrust, trust: etat().trust };
  assert.equal(h.run('nativeSystems.domain("pressPromises").settleSeason(S)'), 1);
  const p = promesses().promises[0];
  assert.equal(p.status, 'kept');
  assert.deepEqual(p.result.value, 3);
  assert.equal(p.verdict.credibility, 5);
  assert.equal(etat().pressRelations.fanTrust - jauges.fan, p.verdict.fanTrust);
  assert.ok(p.verdict.fanTrust > 0 && p.verdict.trust > 0 && p.verdict.boardPressure < 0);
  assert.equal(etat().trust - jauges.trust, p.verdict.trust);
  assert.equal(promesses().credibility, 55);
  assert.equal(h.run('managerMobilityProfile()'), Math.min(100, reputation + 1), 'crédibilité +5 : réputation +1');
  assert.ok(messages().includes('Promesse tenue : Lancer 3 jeunes du centre en équipe première'));
  h.run('validateCareer(S)');
});

test('promesse irréaliste : presse et direction réagissent, puis la promesse ratée coûte cher', () => {
  h.start(110);
  const offre = modele().clubLife.press.conference.promise;
  const folle = offre.options.find(o => o.realism === 'irrealiste' && o.kind !== 'home_wins') || offre.options.find(o => o.realism === 'ambitieux' && o.kind !== 'home_wins');
  assert.ok(folle, 'un objectif hors de portée est proposé à un club modeste');
  const { model } = conference(folle.id);
  if (folle.realism === 'irrealiste') {
    assert.ok(messages().includes('La presse doute de ta promesse'));
    assert.ok(messages().includes('La direction s’inquiète'));
    assert.ok(folle.effects.mediaTrust < 0 && folle.effects.boardPressure > 0 && folle.effects.trust < 0);
  }
  assert.equal(model.clubLife.pressPromises.active[0].realism, folle.realism);
  // Semaine suivante : le plus haut total de victoires à domicile, hors de portée après une seule journée.
  h.week(1);
  const haute = modele().clubLife.press.conference.promise.options.filter(o => o.kind === 'home_wins').sort((x, y) => y.target - x.target)[0];
  conference(haute.id);
  h.toMatch().week(1);
  const credibilite = promesses().credibility, jauges = { fan: etat().pressRelations.fanTrust, trust: etat().trust };
  h.run('nativeSystems.domain("pressPromises").settleSeason(S)');
  const p = promesses().promises.find(x => x.kind === 'home_wins');
  assert.equal(p.status, 'broken', 'objectif hors de portée après une journée');
  const autre = promesses().promises.find(x => x.kind !== 'home_wins');
  const effet = k => p.verdict[k] + (autre.verdict ? autre.verdict[k] : 0);
  assert.ok(p.verdict.fanTrust < 0 && p.verdict.trust < 0 && p.verdict.boardPressure > 0 && p.verdict.credibility < 0);
  assert.equal(promesses().credibility, credibilite + effet('credibility'));
  assert.equal(etat().pressRelations.fanTrust - jauges.fan, effet('fanTrust'));
  assert.equal(etat().trust - jauges.trust, effet('trust'));
  assert.ok(messages().some(t => t.startsWith('Promesse non tenue')));
  assert.ok(messages().includes('Gabi : après la promesse manquée'), 'Gabi commente');
  assert.ok(modele().clubLife.pressPromises.settled.some(x => x.kind === 'home_wins' && x.progress.label === 'Non tenue'));
  h.run('validateCareer(S)');
});

test('refuser de promettre : médias −1, question close pour la saison', () => {
  nouvelle();
  const avant = modele().clubLife.press.metrics;
  const { model, offre } = conference('refuse');
  assert.deepEqual(offre.refuse.effects, { fanTrust: -1, mediaTrust: -1, boardPressure: 0, trust: 0 });
  assert.equal(promesses().refusals.length, 1);
  assert.equal(promesses().promises.length, 0);
  assert.equal(model.clubLife.pressPromises.refusedThisSeason, true);
  assert.ok(model.clubLife.press.metrics.mediaTrust <= avant.mediaTrust + 10);
  // Conférence suivante : plus de question d'objectif cette saison ; un choix forcé est rejeté.
  h.week(1);
  const conf = modele().clubLife.press.conference;
  assert.equal(conf.available, true);
  assert.equal(conf.promise, null);
  assert.throws(() => conference('youth:3'), /aucune question d’objectif/);
});

test('objectif du conseil : une promesse en dessous de sa place le froisse, sans créer d’objectif en double', () => {
  nouvelle();
  // Le président fixe déjà un objectif de classement au départ (tout club joué) : on s'appuie dessus.
  const cible = etat().nativeBoardCalendar.objectives.find(o => o.type === 'rank').target;
  assert.equal(cible, 1, 'objectif de départ du président : le titre pour ce club');
  const objectifs = etat().nativeBoardCalendar.objectives.length;
  const offre = modele().clubLife.press.conference.promise;
  const prudente = offre.options.find(o => o.id === 'rank:4');
  const titre = offre.options.find(o => o.id === 'rank:1');
  assert.match(prudente.boardNote, /En dessous de l’objectif du conseil \(1re place\)/);
  assert.match(titre.boardNote, /Conforme à l’objectif du conseil/);
  const base = { modeste: -2, realiste: 1, ambitieux: 0, irrealiste: -3 };
  assert.equal(prudente.effects.trust, base[prudente.realism] - 2, 'malus de −2 sur la confiance');
  assert.equal(titre.effects.trust, base[titre.realism], 'aucun malus quand la promesse va au-delà');
  conference('rank:4');
  assert.equal(etat().nativeBoardCalendar.objectives.length, objectifs, 'aucun objectif du conseil créé');
  assert.equal(promesses().promises[0].board, cible, 'objectif du conseil mémorisé');
  // Le verdict ne compte que pour moitié auprès du conseil, qui juge déjà son propre objectif.
  h.toMatch().week(1); // une journée jouée : le classement existe
  const trust = etat().trust;
  h.run('nativeSystems.domain("pressPromises").settleSeason(S)');
  const p = promesses().promises[0];
  const plein = (p.status === 'kept' ? { modeste: 1, realiste: 3, ambitieux: 5, irrealiste: 6 } : { modeste: -6, realiste: -4, ambitieux: -3, irrealiste: -5 })[p.realism];
  assert.ok(['kept', 'broken'].includes(p.status));
  assert.equal(p.verdict.trust, Math.max(-trust, Math.min(100 - trust, Math.round(plein * 0.5))));
});

test('sauvegarde, rechargement et validateur', () => {
  nouvelle();
  conference('home_wins:11');
  h.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");validateCareer(S)');
  const p = promesses();
  assert.equal(p.promises.length, 1);
  assert.equal(p.promises[0].id, 'promesse:1:0:home_wins');
  assert.equal(p.promises[0].target, 11);
  assert.equal(modele().clubLife.pressPromises.active[0].kind, 'home_wins', 'promesse suivie après rechargement');
  const rejette = (mutation, motif) => {
    const cp = h.checkpoint();
    try { assert.throws(() => h.run(mutation + ';validateCareer(S)'), motif); } finally { h.restore(cp); }
  };
  rejette('S.pressPromises.promises[0].kind="titre"', /promesse invalide/);
  rejette('S.pressPromises.promises[0].target=0', /objectif chiffré invalide/);
  rejette('S.pressPromises.promises[0].verdict={fanTrust:1,mediaTrust:1,boardPressure:1,trust:1,credibility:1}', /verdict de promesse invalide/);
  rejette('S.pressPromises.promises.push(JSON.parse(JSON.stringify(S.pressPromises.promises[0])))', /identifiant de promesse invalide ou répété/);
  rejette('S.pressPromises.credibility=101', /schéma invalide/);
  rejette('S.pressPromises.promises[0].espion=1', /schéma inconnu/);
  rejette('S.pressPromises.refusals.push({season:1,week:0,club:0},{season:1,week:1,club:0})', /refus répété/);
  rejette('S.pressPromises.promises[0].reminders=["demain"]', /rappels invalides/);
});
