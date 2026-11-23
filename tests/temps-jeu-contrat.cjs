'use strict';
// Temps de jeu promis au contrat (revue FM27, idée 16 ; choix de Léo du 23/11/2026) — native/engine/role-contrat.cjs :
//  - suivi des 10 derniers matchs du club par joueur (minutes, indisponible), d'une saison à l'autre ;
//  - seuils : Titulaire 50 min de moyenne, Rotation 20 min, Espoir 1 match joué sur 4, Appoint sans exigence ;
//    jugé dès 3 matchs comptés (content / attentif ≥ 60 % / mécontent) ;
//  - salaire demandé : +5 % par cran au-dessus du rôle attendu (hiérarchie), −4 % par cran en dessous, jamais sous le
//    salaire actuel en prolongation ; un ambitieux (ambition ≥ 70) refuse Appoint ; Espoir à 21 ans et moins.
// Tout est déterministe (aucun tirage).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory } = require('../native/engine/role-contrat.cjs');

const R = factory();

// Centres (famille 7, deux places dans le XV) : 90 et 85 titulaires, 80 et 75 rotation, puis espoir / appoint.
const centres = () => [90, 85, 80, 75, 70, 65].map((rating, i) => ({ id: 'c' + i, fam: 7, rating, age: i === 4 ? 20 : 27, contractEnd: 3, salary: 10000 }));
const etat = joueurs => ({ season: 1, club: 0, round: 0, clubs: [{ id: 0, name: 'Nous', players: joueurs }, { id: 1, name: 'Eux XV', players: [] }, { id: 2, name: 'Autres', players: [] }] });
const avecEtat = (s, fn) => { const avant = globalThis.S; globalThis.S = s; try { return fn(); } finally { if (avant === undefined) delete globalThis.S; else globalThis.S = avant; } };

test('Règles chiffrées', () => {
  assert.deepEqual(R.RULES.SEUILS.titulaire, { moyenne: 50 });
  assert.deepEqual(R.RULES.SEUILS.rotation, { moyenne: 20 });
  assert.deepEqual(R.RULES.SEUILS.espoir, { part: 0.25 });
  assert.equal(R.RULES.MATCHS, 10);
  assert.equal(R.RULES.JUGE_DES, 3);
  assert.equal(R.RULES.HAUSSE_CRAN, 0.05);
  assert.equal(R.RULES.BAISSE_CRAN, 0.04);
  assert.equal(R.RULES.AMBITION_REFUS, 70);
});

test('Salaire : +5 % par cran au-dessus du rôle attendu, −4 % par cran en dessous', () => {
  const j = centres(), s = etat(j);
  // c2 : attendu rotation.
  assert.equal(R.attendu(j[2], s), 'rotation');
  assert.equal(R.facteur(j[2], 'titulaire', s), 1.05);
  assert.equal(R.facteur(j[2], 'rotation', s), 1);
  assert.equal(R.facteur(j[2], 'espoir', s), 0.96);
  assert.equal(R.facteur(j[2], 'appoint', s), 0.92);
  // c0 : attendu titulaire → tout en dessous.
  assert.equal(R.facteur(j[0], 'titulaire', s), 1);
  assert.equal(R.facteur(j[0], 'appoint', s), 0.88);
  // c5 : attendu appoint → titulaire = trois crans au-dessus.
  assert.equal(R.attendu(j[5], s), 'appoint');
  assert.equal(R.facteur(j[5], 'titulaire', s), 1.15);
  // demande() : seulement pendant l'offre du joueur, arrondie à la centaine ; prolongation jamais sous le salaire actuel.
  avecEtat(s, () => {
    assert.equal(R.demande(12000, j[2], 'renew'), 12000, 'hors offre : inchangé');
    assert.equal(R.avec(j[2], 'titulaire', () => R.demande(12000, j[2], 'renew')), 12600);
    assert.equal(R.avec(j[2], 'titulaire', () => R.demande(12000, j[3], 'renew')), 12000, 'autre joueur : inchangé');
    assert.equal(R.avec(j[2], 'appoint', () => R.demande(12000, j[2], 'recruit')), 11000);
    assert.equal(R.avec(j[2], 'appoint', () => R.demande(10500, j[2], 'renew')), 10000, 'plancher = salaire actuel (10 000)');
    assert.equal(R.avec(j[2], 'rotation', () => R.demande(12345, j[2], 'renew')), 12345, 'rôle attendu : demande inchangée');
    assert.equal(R.demande(12000, j[2], 'renew'), 12000, 'offre terminée');
  });
});

test('Acceptation : Espoir à 21 ans et moins, Appoint refusé par un ambitieux', () => {
  const j = centres();
  assert.equal(R.refus(j[4], 'espoir'), '', '20 ans');
  assert.match(R.refus(j[0], 'espoir'), /21 ans et moins/);
  assert.match(R.refus(j[0], 'capitaine'), /inconnu/);
  // Sans traits disponibles : ambition 50, pas de refus.
  assert.equal(R.refus(j[0], 'appoint'), '');
  const avant = globalThis.nativePotentialEvolution;
  try {
    globalThis.nativePotentialEvolution = { traits: p => ({ ambition: p.id === 'c0' ? 70 : 69 }) };
    assert.match(R.refus(j[0], 'appoint'), /ambitieux/);
    assert.equal(R.refus(j[1], 'appoint'), '', 'ambition 69 : accepte');
    assert.equal(R.refus(j[0], 'rotation'), '', 'un ambitieux accepte la rotation');
  } finally { if (avant === undefined) delete globalThis.nativePotentialEvolution; else globalThis.nativePotentialEvolution = avant; }
});

test('Suivi des matchs : 10 derniers, indisponible non compté, d’une saison à l’autre', () => {
  const j = centres(), s = etat(j);
  j[3].injury = 3;
  const match = (semaine, minutes, adv = 1) => { s.round = semaine; return R.apresMatch({ pair: [adv, 0], sheets: [{}, { minutes }] }, s); };
  assert.equal(match(1, { c0: 80, c1: 60, c2: 25 }), 6, 'une ligne par joueur sous contrat');
  assert.deepEqual(j[0].tempsJeu, { club: 0, m: [[1, 1, 1, 80, 0]] });
  assert.deepEqual(j[3].tempsJeu.m, [[1, 1, 1, 0, 1]], 'blessé sans jouer : indisponible');
  assert.deepEqual(j[2].tempsJeu.m, [[1, 1, 1, 25, 0]]);
  for (let w = 2; w <= 12; w++) match(w, { c0: 80, c1: w % 2 ? 0 : 50, c2: 30, c4: w % 4 === 0 ? 10 : 0 }, 2);
  assert.equal(j[0].tempsJeu.m.length, 10);
  assert.deepEqual(j[0].tempsJeu.m[0], [1, 3, 2, 80, 0], 'les plus anciens sortent');
  s.season = 2; match(1, { c0: 40 });
  assert.deepEqual(j[0].tempsJeu.m.at(-1), [2, 1, 1, 40, 0], 'nouvelle saison : la liste continue');
  // Match d'un autre club : rien.
  assert.equal(R.apresMatch({ pair: [1, 2], sheets: [{}, {}] }, s), 0);
  // Joueur parti puis revenu : suivi repris de zéro.
  j[5].tempsJeu = { club: 1, m: [[1, 1, 1, 80, 0]] };
  match(2, {});
  assert.deepEqual(j[5].tempsJeu, { club: 0, m: [[2, 2, 1, 0, 0]] });
  assert.equal(R.validate(s), true);
});

test('Satisfaction : seuils de Léo, jugée dès 3 matchs', () => {
  const p = { id: 'x', fam: 7, rating: 90, age: 20, contractEnd: 3 }, s = etat([p]);
  const vue = (role, minutes) => {
    p.roleContrat = { role, saison: 1, fin: 3, club: 0 };
    p.tempsJeu = { club: 0, m: minutes.map((m, i) => [1, i + 1, 1, m === 'B' ? 0 : m, m === 'B' ? 1 : 0]) };
    return R.tempsJeu(p, s);
  };
  // Titulaire : 50 min de moyenne sur les matchs comptés.
  let t = vue('titulaire', [80, 80, 0, 50, 40, 'B', 'B', 60, 80, 10]);
  assert.equal(t.juges, 8); assert.equal(t.moyenne, 50); assert.equal(t.humeur, 'content'); assert.equal(t.seuil, 50);
  assert.deepEqual(t.pastilles.map(x => x.etat), ['tenu', 'tenu', 'manque', 'tenu', 'manque', 'absent', 'absent', 'tenu', 'tenu', 'manque']);
  assert.equal(t.pastilles[0].adversaire, 'Eux XV');
  assert.equal(vue('titulaire', [40, 30, 30]).humeur, 'attentif', 'moyenne 33 ≥ 30 (60 %)');
  assert.equal(vue('titulaire', [30, 20, 30]).humeur, 'mecontent', 'moyenne 27 < 30');
  assert.equal(vue('titulaire', [0, 0]).humeur, 'neutre', 'moins de 3 matchs : pas encore jugé');
  assert.equal(vue('titulaire', ['B', 'B', 'B', 80]).humeur, 'neutre', 'blessé : pas compté');
  // Rotation : 20 min de moyenne.
  assert.equal(vue('rotation', [20, 20, 20]).humeur, 'content');
  assert.equal(vue('rotation', [12, 12, 12]).humeur, 'attentif');
  assert.equal(vue('rotation', [0, 0, 30]).humeur, 'mecontent', 'moyenne 10');
  // Espoir : au moins 1 match joué sur 4.
  t = vue('espoir', [0, 0, 0, 5, 0, 0, 0, 12]);
  assert.equal(t.joues, 2); assert.equal(t.humeur, 'content'); assert.equal(t.part, 0.25);
  assert.equal(vue('espoir', [0, 0, 0, 0, 0, 0, 0, 0, 0, 5]).humeur, 'mecontent', '1 sur 10 = 40 % du seuil');
  assert.equal(vue('espoir', [0, 0, 0, 0, 0, 5]).humeur, 'attentif', '1 sur 6 = 67 % du seuil');
  assert.deepEqual(vue('espoir', [0, 5]).pastilles.map(x => x.etat), ['neutre', 'tenu']);
  // Appoint : sans exigence.
  assert.equal(vue('appoint', [0, 0, 0, 0]).humeur, 'neutre');
  // Sans contrat : pas de temps de jeu.
  assert.equal(R.tempsJeu({ id: 'y', fam: 7, contractEnd: null }, s), null);
});

test('Ancienne sauvegarde : reprise des notes de match de la saison à partir du 1er match joué', () => {
  const j = centres(), s = etat(j);
  s.matchNotes = { saison: 1, detail: {
    c0: [[1, 1, 'c', 80, 70], [2, 2, 'c', 80, 70], [3, 1, 'c', 60, 70]],
    c1: [[2, 2, 'c', 30, 60]],
    c2: [[3, 1, 'c', 5, 60]],
  } };
  assert.deepEqual(R.reprise(j[1], s), [[1, 2, 2, 30, 0], [1, 3, 1, 0, 0]], 'c1 : depuis son 1er match (semaine 2)');
  assert.deepEqual(R.reprise(j[0], s).map(r => r[3]), [80, 80, 60]);
  assert.deepEqual(R.reprise(j[3], s), [], 'jamais joué : rien d’inventé');
  // Le match en cours n'est pas repris deux fois.
  s.round = 3;
  R.apresMatch({ pair: [0, 1], sheets: [{ minutes: { c0: 70 } }, {}] }, s);
  assert.deepEqual(j[0].tempsJeu.m, [[1, 1, 1, 80, 0], [1, 2, 2, 80, 0], [1, 3, 1, 70, 0]]);
  assert.equal(R.tempsJeu(j[1], s).pastilles.length, 2, 'vue sans suivi : reprise en direct');
});

test('Validation : suivis abîmés refusés', () => {
  const j = centres(), s = etat(j);
  j[0].tempsJeu = { club: 0, m: [[1, 1, 1, 80, 0]] };
  assert.equal(R.validate(s), true);
  for (const bad of [{ club: 0, m: [[1, 1, 1, 80]] }, { club: 0, m: [[1, 1, 1, 300, 0]] }, { club: 0, m: Array(11).fill([1, 1, 1, 80, 0]) }, { club: 0, m: [], x: 1 }, { m: [] }]) {
    j[0].tempsJeu = bad;
    assert.throws(() => R.validate(s), /Temps de jeu/, JSON.stringify(bad));
  }
});

test('Carrière Monde : matchs suivis, temps de jeu à l’écran, rôle qui règle salaire et acceptation', { timeout: 900000 }, () => {
  const { context } = require('./monde-harness.cjs');
  const h = context(827381);
  const val = src => JSON.parse(h.run(`JSON.stringify(${src})`));
  try {
    h.run("nativeSystems.domain('roleContrat').observe()");
    h.toMatch(); h.week(1); h.toMatch(); h.week(1); h.toMatch(); h.week(1);
    const suivis = val('S.clubs[S.club].players.filter(p=>Number.isInteger(p.contractEnd)&&!p.espoirLoan).map(p=>({id:p.id,t:p.tempsJeu}))');
    assert.ok(suivis.length > 20);
    for (const x of suivis) assert.equal(x.t?.m?.length, 3, x.id + ' : trois matchs suivis');
    const joueurs = suivis.filter(x => x.t.m.some(r => r[3] > 0));
    assert.ok(joueurs.length >= 15, 'au moins le XV a joué');
    // Minutes du suivi = minutes des notes de match de la saison.
    const detail = val('S.matchNotes.detail');
    for (const x of joueurs) for (const r of x.t.m) {
      const d = (detail[x.id] || []).find(l => l[0] === r[1] && l[1] === r[2]);
      assert.equal(r[3], d ? d[3] : 0, x.id + ' semaine ' + r[1]);
    }
    h.run('validateCareer(S)');
    // Écran : squad[].tempsJeu, renewal.roles, market[].roles.
    const model = h.command('set_player_load', { playerId: suivis[0].id, mode: 'repos' });
    const sous = model.squad.filter(p => Number.isInteger(p.contractEnd) && !p.calledUp);
    for (const p of sous) {
      assert.ok(p.tempsJeu, p.name + ' : temps de jeu');
      assert.equal(p.tempsJeu.role, p.roleContrat.role);
      assert.equal(p.tempsJeu.pastilles.length, 3);
      assert.ok(['content', 'attentif', 'mecontent', 'neutre'].includes(p.tempsJeu.humeur));
    }
    assert.ok(new Set(sous.map(p => p.tempsJeu.humeur)).size >= 2, 'humeurs variées');
    const cible = sous.find(p => p.renewal?.available && p.renewal.roles && p.renewal.roles.attendu !== 'titulaire');
    assert.ok(cible, 'un joueur à prolonger qui n’est pas titulaire');
    const roles = Object.fromEntries(cible.renewal.roles.liste.map(r => [r.role, r]));
    assert.equal(roles[cible.renewal.roles.attendu].salary, cible.renewal.salary, 'rôle attendu = demande affichée');
    assert.ok(roles.titulaire.salary > cible.renewal.salary, 'titulaire : plus cher');
    assert.ok(roles.appoint.salary <= cible.renewal.salary, 'appoint : moins cher ou égal');
    assert.ok(model.market.length > 0 && model.market.every(p => p.roles?.liste?.length === 4), 'rôles au recrutement');
    // Espoir refusé au-delà de 21 ans, par la commande du jeu.
    const age = sous.find(p => p.age > 21 && p.renewal?.available);
    const brut = (nom, charge) => { h.run('delete S.clubMeetings'); try { h.command(nom, charge); return ''; } catch (e) { return e.message; } };
    assert.match(brut('extend_contract', { playerId: age.id, salary: 100000, years: age.renewal.minYears, confirmed: true, role: 'espoir' }), /21 ans et moins/);
    // Une offre au salaire de la demande « rotation » passe en rotation mais pas en titulaire (demande plus haute).
    const offre = Math.ceil(roles.rotation.salary * 0.95 / 100) * 100;
    const minimum = role => val(`roleContratAvec(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}),${JSON.stringify(role)},()=>reservationWage(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}),'renew',${cible.renewal.minYears}))`);
    assert.ok(minimum('titulaire') > minimum('rotation'), `minimum accepté : titulaire ${minimum('titulaire')} > rotation ${minimum('rotation')}`);
    assert.ok(offre >= minimum('rotation') || offre < minimum('titulaire'));
    // Prolongation avec rôle promis : enregistré, envoyé à l'écran.
    const signe = brut('extend_contract', { playerId: cible.id, salary: Math.min(100000, roles.titulaire.salary * 2), years: cible.renewal.minYears, confirmed: true, role: 'titulaire' });
    assert.equal(signe, '');
    assert.equal(val(`S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}).roleContrat.role`), 'titulaire');
    assert.equal(val(`'deduit' in S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}).roleContrat`), false, 'promesse explicite');
    h.run('validateCareer(S)');
  } finally { h.close(); }
});
