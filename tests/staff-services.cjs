'use strict';
// Staff par service (native/engine/staff-services.cjs ; revue FM27 n° 22, choix A de Léo du 23/11/2026) : répartition
// du staff sur les postes minimum, postes visés au-delà du minimum (0 à 3 par service, un clic = appliqué), bonus réels
// (progression +5 %, blessures −5 %, soins +10 %, observation −10 % par poste) et salaires (2 500 / 1 500 / 2 000 /
// 1 200 € par semaine), avis des dirigeants. Règles pures d'abord (état fourni), puis carrière Monde réelle.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory } = require('../native/engine/staff-services.cjs');
const completion = require('../native/engine/staff-completion.cjs');

const f = factory();
const t = f._tests;
const LIBELLES = Object.fromEntries(Object.entries(completion.FUNCTIONS).map(([k, v]) => [k, v]));
// Staff d'un club : les 15 postes minimum (deux kinés), plus des membres en plus.
function etat({ extras = [], base = 70, ambition = null, niveau = 64 } = {}) {
  const gens = [];
  let n = 0;
  const ajouter = (cle, level = niveau) => gens.push({ id: 'staff:' + cle + ':' + (++n), name: 'Membre ' + n, role: LIBELLES[cle].role, roleLabel: LIBELLES[cle].label, level, clubId: 0, contractEnd: 2 });
  for (const [cle, nombre] of Object.entries(completion.MINIMUM)) for (let i = 0; i < nombre; i++) ajouter(cle);
  for (const [cle, level] of extras) ajouter(cle, level);
  gens.push({ id: 'staff:ailleurs', name: 'Ailleurs', role: 'medical', roleLabel: 'Kinésithérapeute', level: 90, clubId: 1, contractEnd: 2 });
  const s = {
    club: 0, season: 1, phase: 'league', round: 3, worldMode: { week: 3 },
    staffCareer: { version: 1, completionPolicy: completion.POLICY, completionOrigins: [{ clubId: 0, base, country: 'FR' }, { clubId: 1, base: 60, country: 'FR' }], people: [gens] },
    clubs: [{ id: 0, players: [{ id: 'j1', injury: 0 }, { id: 'j2', injury: 5 }, { id: 'j3', injury: 1 }] }, { id: 1, players: [{ id: 'adv', injury: 4 }] }],
    ...(ambition === null ? {} : { clubDirections: { clubs: { 0: { president: { traits: { ambition } } } } } })
  };
  globalThis.S = s;
  return s;
}
const service = (projection, id) => projection.services.find(x => x.id === id);
const viser = (service, cible) => f.execute('staff_services_target', { service, cible });

test('Règles chiffrées : 4 services, 3 postes en plus au plus, bonus et salaires par poste', () => {
  assert.equal(f.RULES.MAX, 3);
  assert.equal(f.RULES.OBSERVATION, 5000);
  assert.deepEqual(f.RULES.SERVICES.map(s => [s.id, s.bonus, s.parPoste, s.salaire]), [
    ['coaching', 'progression', 0.05, 2500], ['fitness', 'prevention', 0.05, 1500], ['medical', 'soins', 0.10, 2000], ['club', 'observation', 0.10, 1200]]);
  // Les quatre services couvrent exactement les 15 postes minimum de staff-completion.cjs.
  assert.deepEqual(f.RULES.SERVICES.flatMap(s => s.fonctions).sort(), Object.keys(completion.MINIMUM).sort());
  assert.equal(commandsOf(), 'staff_services_target');
});
function commandsOf() { return require('../native/engine/staff-services.cjs').commands.join(','); }

test('Répartition : minimum couvert, membres en plus rangés par service, rien d\'actif sans cible', () => {
  const s = etat({ extras: [['physio', 70], ['analyst', 66], ['scout', 58], ['forwards', 61]] });
  const p = f.project();
  assert.equal(p.available, true);
  assert.deepEqual(p.services.map(x => [x.id, x.minimum, x.occupes, x.vises, x.cible]), [['coaching', 4, 4, 4, 0], ['fitness', 3, 3, 3, 0], ['medical', 3, 3, 3, 0], ['club', 5, 5, 5, 0]]);
  assert.equal(service(p, 'medical').surnombre.length, 1, 'le kiné en plus est en surnombre');
  assert.equal(service(p, 'club').surnombre.length, 2);
  assert.equal(service(p, 'coaching').surnombre.length, 1);
  assert.ok(!p.services.some(x => x.surnombre.includes('staff:ailleurs')), 'le staff des autres clubs ne compte pas');
  // Fonctions : identifiants des personnes sur chaque poste minimum.
  assert.equal(service(p, 'medical').fonctions.find(x => x.cle === 'physio').ids.length, 2);
  for (const type of ['progression', 'prevention', 'soins', 'observation']) assert.equal(f.bonus(type, s), 0, type + ' : aucun bonus sans cible');
  assert.equal(p.salaireSemaine, 0);
  assert.equal(p.coutObservation, 5000);
  assert.equal(s.staffServices, undefined, 'la projection n\'écrit rien');
});

test('Postes visés : un clic applique, bonus et salaire suivent les postes tenus', () => {
  const s = etat({ extras: [['physio', 70], ['analyst', 66], ['scout', 58], ['forwards', 61], ['conditioning', 63]] });
  viser('medical', 2);
  let p = f.project();
  assert.deepEqual([service(p, 'medical').occupes, service(p, 'medical').vises], [4, 5], '4/5 : un poste visé reste à pourvoir');
  assert.equal(service(p, 'medical').enPlus.length, 1);
  assert.deepEqual(service(p, 'medical').bonus, { type: 'soins', parPoste: 0.1, total: 0.1 });
  assert.equal(service(p, 'medical').salaire.semaine, 2000);
  assert.equal(f.bonus('soins'), 0.1);
  viser('club', 3); viser('coaching', 1); viser('fitness', 1);
  p = f.project();
  assert.equal(service(p, 'club').enPlus.length, 2, 'deux membres en plus pour trois postes visés');
  // L'analyste à 66 prend le poste minimum ; l'analyste du départ (64) puis le recruteur (58) sont en plus.
  const niveaux = id => s.staffCareer.people[0].find(x => x.id === id).level;
  assert.deepEqual(service(p, 'club').enPlus.map(niveaux), [64, 58], 'les meilleurs niveaux d\'abord');
  assert.equal(niveaux(service(p, 'club').fonctions.find(x => x.cle === 'analyst').ids[0]), 66);
  assert.equal(f.bonus('observation'), 0.2);
  assert.equal(f.coutObservation(), 4000);
  assert.equal(f.bonus('progression'), 0.05);
  assert.equal(f.bonus('prevention'), 0.05);
  assert.equal(p.salaireSemaine, 2000 + 2 * 1200 + 2500 + 1500);
  // Un membre déjà payé par l'emploi rémunéré du staff n'est pas payé deux fois.
  s.staffEmployment = { contracts: [{ staffId: service(p, 'coaching').enPlus[0], clubId: 0, endSeason: 2, salary: 500 }] };
  assert.equal(f.project().salaireSemaine, 2000 + 2 * 1200 + 1500);
  delete s.staffEmployment;
  // Retour à 0 : plus de bonus ni de coût.
  for (const id of ['medical', 'club', 'coaching', 'fitness']) viser(id, 0);
  assert.equal(f.project().salaireSemaine, 0);
  assert.equal(f.coutObservation(), 5000);
  // Refus : service inconnu, hors bornes, match en cours.
  assert.throws(() => viser('presse', 1), /invalide/);
  assert.throws(() => viser('medical', 4), /invalide/);
  assert.throws(() => viser('medical', -1), /invalide/);
  s.live = { finished: false };
  assert.throws(() => viser('medical', 1), /match/);
  delete s.live;
  assert.equal(f.validate(s), true);
});

test('Changement de club : les cibles de l\'ancien club ne valent plus', () => {
  const s = etat({ extras: [['physio', 70]] });
  viser('medical', 1);
  assert.equal(f.bonus('soins'), 0.1);
  s.club = 1;
  assert.equal(f.bonus('soins'), 0);
  assert.equal(t.cibles(s).medical, 0);
  viser('fitness', 2);
  assert.equal(s.staffServices.club, 1);
  assert.equal(s.staffServices.cibles.medical, 0, 'état repris à zéro pour le nouveau club');
});

test('Avis des dirigeants : niveau attendu, postes vacants, renforts', () => {
  let s = etat({ base: 70, niveau: 63 });
  assert.equal(t.niveauAttendu(s), 63, '21 + 0,6 × 70');
  let p = f.project();
  assert.deepEqual(service(p, 'coaching').avis, { verdict: 'satisfaits', note: 60, moyenne: 63, attendu: 63, manque: 0, renforts: 0 });
  s = etat({ base: 70, niveau: 63, ambition: 90 });
  assert.equal(t.niveauAttendu(s), 67, 'président ambitieux : +4');
  assert.equal(service(f.project(), 'coaching').avis.verdict, 'mitiges', '60 − 2 × 4 = 52');
  s = etat({ base: 70, niveau: 72 });
  assert.equal(service(f.project(), 'fitness').avis.verdict, 'ravis', '60 + 18 = 78');
  // Poste minimum vacant : −20.
  s = etat({ base: 70, niveau: 63 });
  s.staffCareer.people[0] = s.staffCareer.people[0].filter(x => x.roleLabel !== 'Médecin du club');
  p = f.project();
  assert.deepEqual([service(p, 'medical').occupes, service(p, 'medical').vises, service(p, 'medical').avis.manque, service(p, 'medical').avis.verdict], [2, 3, 1, 'mitiges']);
  s.staffCareer.people[0] = s.staffCareer.people[0].filter(x => x.role !== 'medical');
  assert.equal(service(f.project(), 'medical').avis.verdict, 'inquiets', 'service médical vide');
  // Renfort : +4 par poste en plus tenu ; l'écart de niveau est borné à ±30.
  s = etat({ base: 70, niveau: 63, extras: [['physio', 63], ['physio', 63], ['physio', 63]] });
  viser('medical', 3);
  assert.equal(service(f.project(), 'medical').avis.note, 72);
  s = etat({ base: 70, niveau: 99 });
  assert.equal(service(f.project(), 'club').avis.note, 90);
});

test('Soins : +10 % par poste, crédit par blessé, jamais la dernière semaine', () => {
  const s = etat({ extras: [['physio', 70], ['physio', 66], ['doctor', 60]] });
  viser('medical', 3);
  const blesse = s.clubs[0].players[1], presque = s.clubs[0].players[2], adverse = s.clubs[1].players[0];
  assert.equal(t.soigner(), 0, '0,3 semaine');
  assert.deepEqual(s.staffServices.soins, { j2: 0.3 });
  t.soigner(); t.soigner();
  assert.equal(blesse.injury, 5, '0,9 semaine : rien de retiré');
  assert.equal(t.soigner(), 1, '1,2 semaine : une semaine retirée');
  assert.equal(blesse.injury, 4);
  assert.equal(s.staffServices.soins.j2, 0.2);
  assert.equal(presque.injury, 1, 'la dernière semaine reste au protocole habituel');
  assert.equal(adverse.injury, 4, 'les autres clubs ne sont pas soignés');
  blesse.injury = 2; s.staffServices.soins.j2 = 0.9;
  t.soigner();
  assert.equal(blesse.injury, 1);
  assert.deepEqual(s.staffServices.soins, {}, 'crédit effacé quand il ne reste qu\'une semaine');
  viser('medical', 0);
  blesse.injury = 6; t.soigner();
  assert.deepEqual(s.staffServices.soins, {}, 'sans poste en plus : aucun crédit');
  assert.equal(f.validate(s), true);
});

test('Prévention : risque de blessure × (1 − 5 % par poste), joueurs du club seulement', () => {
  const s = etat({ extras: [['conditioning', 60], ['rehab', 60], ['fitnessLead', 60]] });
  assert.equal(f.facteurPrevention(s.clubs[0].players[0]), 1);
  viser('fitness', 3);
  assert.equal(f.facteurPrevention(s.clubs[0].players[0]), 0.85);
  assert.equal(f.facteurPrevention({ id: 'j1' }), 0.85, 'reconnu par son identifiant');
  assert.equal(f.facteurPrevention(s.clubs[1].players[0]), 1);
  assert.equal(f.facteurPrevention(null), 1);
});

test('Progression : part en plus sur la base de la séance du club', () => {
  const s = etat({ extras: [['assistant', 60], ['defence', 60]] });
  const recu = [];
  globalThis.growPlayer = (p, xp, focus) => recu.push([p.id, Math.round(xp * 1e6) / 1e6, focus]);
  globalThis.ageGrowth = () => 1;
  globalThis.growthFitnessFactor = () => 1;
  try {
    const p = { id: 'j1', injury: 0, condition: 90 };
    assert.equal(t.progresser(p, 'normal', 0), 0, 'sans cible');
    viser('coaching', 2);
    t.progresser(p, 'normal', 0); t.progresser(p, 'intense', 0); t.progresser({ ...p, condition: 40 }, 'normal', 0);
    t.progresser(p, 'repos', 0); t.progresser({ ...p, injury: 2 }, 'normal', 0); t.progresser(p, 'normal', 1); t.progresser(p, 'normal', null);
    assert.deepEqual(recu, [['j1', 0.0055, false], ['j1', 0.01, false], ['j1', 0.00275, false]], '+10 % de 0,055 / 0,10, moitié sous 50 de condition');
  } finally { delete globalThis.growPlayer; delete globalThis.ageGrowth; delete globalThis.growthFitnessFactor; }
});

test('Paie : une fois par semaine, au registre du club', () => {
  const s = etat({ extras: [['physio', 70], ['scout', 60]] });
  const registre = [];
  globalThis.ledgerEntry = (titre, montant) => registre.push([titre, montant]);
  try {
    assert.equal(t.paie(), 0, 'aucun état : rien');
    viser('medical', 1); viser('club', 1);
    assert.equal(t.paie(), 3200);
    assert.equal(t.paie(), 0, 'même semaine : déjà payé');
    s.worldMode.week = 4;
    assert.equal(t.paie(), 3200);
    assert.deepEqual(registre, [['Salaires du staff · postes en plus · semaine 4', -3200], ['Salaires du staff · postes en plus · semaine 5', -3200]]);
    assert.deepEqual(s.staffServices.paie, { season: 1, week: 4 });
  } finally { delete globalThis.ledgerEntry; }
});

test('Validation : états abîmés refusés', () => {
  const s = etat();
  viser('medical', 1);
  const bon = JSON.parse(JSON.stringify(s.staffServices));
  for (const casse of [{ ...bon, version: 2 }, { ...bon, cibles: { ...bon.cibles, medical: 4 } }, { ...bon, cibles: { medical: 1 } },
    { ...bon, soins: { j2: 1 } }, { ...bon, paie: { season: 1 } }, { ...bon, extra: 1 }, { ...bon, club: -1 }]) {
    s.staffServices = casse;
    assert.throws(() => f.validate(s), /Staff par service/, JSON.stringify(casse));
  }
  s.staffServices = bon;
  assert.equal(f.validate(s), true);
  delete globalThis.S;
});

test('Carrière Monde : projection à l\'écran, clic appliqué, soins, prévention, observation, paie et sauvegarde', { timeout: 900000 }, () => {
  const { context } = require('./monde-harness.cjs');
  const h = context(827381);
  const val = src => JSON.parse(h.run(`JSON.stringify(${src})`));
  const commande = (nom, charge) => { h.run('delete S.clubMeetings'); return h.command(nom, charge); };
  let modele = commande('set_delegation', { key: 'lineup', enabled: false });
  let p = modele.clubLife.staffServices;
  assert.equal(p.available, true);
  assert.deepEqual(p.services.map(x => x.id), ['coaching', 'fitness', 'medical', 'club']);
  for (const x of p.services) {
    assert.equal(x.vises, x.minimum, x.id + ' : aucun poste en plus par défaut');
    assert.equal(x.occupes, x.minimum, x.id + ' : minimum couvert (complément du staff)');
    assert.ok(['ravis', 'satisfaits', 'mitiges', 'inquiets'].includes(x.avis.verdict));
  }
  assert.equal(p.salaireSemaine, 0);
  // Les identifiants projetés sont ceux du staff montré à l'écran.
  const montres = new Set(modele.staff.teams.find(e => e.id === modele.club.id).members.map(m => m.id));
  for (const x of p.services) for (const id of [...x.fonctions.flatMap(y => y.ids), ...x.surnombre]) assert.ok(montres.has(id), id);
  // Un poste visé dans chaque service où un membre est en surnombre : appliqué au premier clic.
  const avecSurnombre = p.services.filter(x => x.surnombre.length > 0).map(x => x.id);
  assert.ok(avecSurnombre.includes('medical') && avecSurnombre.includes('fitness') && avecSurnombre.includes('club'), avecSurnombre.join(','));
  for (const id of avecSurnombre) modele = commande('staff_services_target', { service: id, cible: 1 });
  p = modele.clubLife.staffServices;
  for (const id of avecSurnombre) assert.equal(p.services.find(x => x.id === id).enPlus.length, 1, id);
  const attendu = p.services.reduce((n, x) => n + x.enPlus.length * x.salaire.parPoste, 0);
  assert.equal(p.salaireSemaine, attendu);
  assert.equal(p.coutObservation, 4500);
  assert.equal(val('nativeSystems.domain(\'staffServices\').bonus(\'prevention\')'), 0.05);
  // Prévention : la fragilité du joueur est réduite de 5 % pour le club, pas pour l'adversaire.
  const [nous, eux] = val('[facteurFragilite(S.clubs[S.club].players[0])/nativeSystems.domain(\'fragilite\').facteur(S.clubs[S.club].players[0]),facteurFragilite(S.clubs[(S.club+1)%S.clubs.length].players[0])/nativeSystems.domain(\'fragilite\').facteur(S.clubs[(S.club+1)%S.clubs.length].players[0])]');
  assert.ok(Math.abs(nous - 0.95) < 1e-9 && Math.abs(eux - 1) < 1e-9, nous + ' / ' + eux);
  // Soins : un blessé de 12 semaines gagne 0,1 semaine par séance en plus de la semaine du moteur ; après 10 séances,
  // une semaine gagnée (1 au lieu de 2).
  const blesse = val('S.clubs[S.club].players.find(p=>!p.injury).id');
  const joueur = `S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(blesse)})`;
  h.run(`${joueur}.injury=12`);
  for (let i = 0; i < 10; i++) h.run('S.trained=false;trainWeek()');
  assert.equal(val(`${joueur}.injury`), 1, '12 − 10 séances − 1 semaine gagnée par les soins');
  assert.equal(val(`S.staffServices.soins[${JSON.stringify(blesse)}]??null`), null, 'crédit soldé');
  h.run(`${joueur}.injury=0`);
  // Paie : une ligne au registre la semaine suivante, du montant affiché.
  const tresorerie = val('S.clubs[S.club].cash');
  h.week(1);
  const ligne = val('S.ledger.find(e=>/postes en plus/.test(e.title))');
  assert.ok(ligne && ligne.amount === -attendu, JSON.stringify(ligne));
  assert.ok(val('S.clubs[S.club].cash') !== tresorerie);
  // Observation ciblée par la commande du jeu : 4 500 € débités au lieu de 5 000 €.
  modele = commande('set_delegation', { key: 'lineup', enabled: false });
  const cible = val('S.clubs[(S.club+29)%S.clubs.length].players[0].id');
  const avant = modele.finance.cash;
  modele = commande('observe_player', { playerId: cible, confirmed: true, context: { season: modele.meta.season, week: modele.meta.week, club: modele.club.id } });
  assert.equal(modele.finance.cash, avant - 4500);
  // Sauvegarde : l'état passe la validation et survit à l'aller-retour JSON.
  h.run('validateCareer(S)');
  const etatSauve = val('S.staffServices');
  assert.deepEqual(etatSauve.cibles, Object.fromEntries(['coaching', 'fitness', 'medical', 'club'].map(id => [id, avecSurnombre.includes(id) ? 1 : 0])));
  h.close();
});
