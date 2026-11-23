'use strict';
// Économie du club (choix de Léo du 23/11/2026) :
//  1. billetterie réelle : recette d'un match à domicile = billets vendus au guichet × prix du billet, encaissée au match ;
//     trois prix de la saison (billet, abonnement, grosse affiche) fixés par le manager, conseillés ou fixés par le staff ;
//     le prix pèse sur l'affluence (bornée par la capacité) et sur les abonnés ; l'écran montre une estimation, jamais exacte ;
//  2. staff payé selon son rôle, son niveau et la division ; fonctionnement dégressif au-delà de 20 M€ de recettes.
const assert = require('node:assert/strict');
const B = require('../native/engine/club-budget.cjs');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante } = require('./helpers/carriere-monde.cjs');

// 1. Prix du billet : division et politique ; plus cher = moins de monde, jamais plus que la capacité.
assert.equal(B.prixBillet('accession', 'equilibree'), 7);
assert.ok(B.prixBillet('elite', 'equilibree') > B.prixBillet('accession', 'equilibree'), 'Top 14 plus cher que Pro D2');
assert.ok(B.prixBillet('accession', 'accessible') < 7 && B.prixBillet('accession', 'premium') > 7);
assert.equal(B.prixBillet('accession', 'inconnue'), 7, 'politique inconnue = équilibrée');
const match = (politique, resultats = ['V', 'D']) => B.spectateurs({ capacite: 12000, resultats, cle: 'x', alea: 0.5, politique });
assert.equal(match('equilibree'), B.spectateurs({ capacite: 12000, resultats: ['V', 'D'], cle: 'x', alea: 0.5 }), 'équilibrée = public d’avant');
assert.ok(match('accessible') > match('equilibree') && match('premium') < match('equilibree'), 'le prix pèse sur l’affluence');
assert.ok(match(0.8) > match(1) && match(1.3) < match(1), 'prix libre : rapport au prix de la division');
assert.ok(B.spectateurs({ capacite: 12000, resultats: ['V', 'D'], cle: 'x', alea: 0.5, affiche: true }) > match('equilibree'), 'grosse affiche : plus de demande');
// Estimation et conseil du staff : jamais exacts, plus justes avec un meilleur staff.
const ecart = (niveau, k) => Math.abs(B.estimationStaff(10000, niveau, 'k' + k) - 10000);
for (let k = 0; k < 40; k++) { assert.ok(ecart(85, k) > 0 && ecart(85, k) <= 300 && ecart(45, k) <= 1500, 'estimation ' + k); assert.notEqual(B.conseilPrix(20, 85, 'c' + k), 20); }
assert.ok([...Array(40).keys()].reduce((n, k) => n + Math.abs(B.conseilPrix(100, 45, 'c' + k) - 100), 0) > [...Array(40).keys()].reduce((n, k) => n + Math.abs(B.conseilPrix(100, 85, 'c' + k) - 100), 0), 'meilleur staff, meilleurs conseils');
assert.ok(match('accessible', ['V', 'V', 'V', 'V', 'V']) <= 12000, 'borné par la capacité');
assert.equal(B.spectateurs({ capacite: 12000, resultats: [], cle: 'x', phase: 'final', politique: 'premium' }), 11640, 'phase finale : stade plein');
// Guichet : abonnés présents (85 %) déduits ; phase finale : billet × 1,5.
assert.deepEqual(B.guichet({ spectateurs: 10000, abonnes: 4000, prix: 8 }), { spectateurs: 10000, abonnes: 3400, payants: 6600, prix: 8, recette: 52800 });
assert.equal(B.guichet({ spectateurs: 3000, abonnes: 4000, prix: 8 }).recette, 0, 'jamais négatif');
assert.equal(B.guichet({ spectateurs: 10000, abonnes: 0, prix: 8, finale: true }).recette, 120000);
assert.equal(B.abonnementsHebdo({ abonnes: 4000, prix: 8, receptions: 15, semaines: 46 }), 7300, '4 000 × 8 € × 70 % × 15 / 46');
const petit = B.abonnesEstimes(12000, 60, 'A'), gros = B.abonnesEstimes(12000, 86, 'A');
assert.ok(petit >= 0.2 * 12000 && petit <= 0.3 * 12000 && gros >= 0.7 * 12000 && gros <= 0.78 * 12000, 'abonnés estimés : ' + petit + ' / ' + gros);

// 2. Staff : rôle, niveau, division.
const kine = (level, d = 'elite') => B.salaireStaff({ role: 'medical', roleLabel: 'Kinésithérapeute', level }, d);
assert.ok(kine(70) > kine(55) && kine(55) > kine(45), 'un meilleur kiné coûte plus cher');
assert.ok(B.salaireStaff({ role: 'coach', roleLabel: 'Entraîneur principal', level: 60 }, 'elite') > B.salaireStaff({ role: 'coach', roleLabel: 'Entraîneur des avants', level: 60 }, 'elite'), 'entraîneur principal > adjoint de poste');
assert.ok(B.salaireStaff({ role: 'medical', roleLabel: 'Médecin du club', level: 60 }, 'elite') > kine(60), 'médecin > kiné');
assert.ok(kine(60, 'elite') > kine(60, 'accession') && kine(60, 'accession') > kine(60, 'nationale'), 'la division fixe le niveau des salaires');
const staff = [{ role: 'coach', roleLabel: 'Entraîneur principal', level: 70 }, { role: 'medical', roleLabel: 'Kinésithérapeute', level: 50 }];
const m = B.masseStaff(staff, 'accession', 67);
assert.equal(m.membres, 2);
assert.equal(m.annuel, staff.reduce((s, p) => s + B.salaireStaff(p, 'accession'), 0));
assert.equal(m.reference, staff.reduce((s, p) => s + B.salaireStaff(p, 'accession', B.niveauAttenduStaff(67)), 0), 'référence : mêmes postes au niveau attendu du club');

// 3. Fonctionnement dégressif ; semaine avec staff : l'enveloppe est la même, seul l'écart de niveau du staff coûte.
assert.equal(B.fonctionnementAnnuel(10e6), 5.8e6);
assert.equal(B.fonctionnementAnnuel(40e6), 0.58 * 20e6 + 0.45 * 20e6);
const forces = [...Array.from({ length: 16 }, (_, i) => ({ id: i, division: 'accession', base: 60 + i }))];
const semaine = staffArg => B.semaine({ forces, clubId: 7, masseHebdo: 50000, semaines: 46, domicile: false, alea: 0.5, libelle: 'S', staff: staffArg });
const total = l => l.reduce((s, e) => s + e.amount, 0), ligne = (l, t) => l.find(e => e.title === 'S · ' + t)?.amount;
const sans = semaine(null), egal = semaine({ annuel: 1e6, reference: 1e6 }), cher = semaine({ annuel: 1.2e6, reference: 1e6 });
assert.equal(ligne(sans, 'Staff et fonctionnement') < 0, true, 'sans staff : l’ancienne ligne');
assert.equal(ligne(egal, B.LIBELLE_STAFF), -Math.round(1e6 / 46 / 100) * 100);
assert.ok(ligne(egal, B.LIBELLE_FONCTIONNEMENT) < 0 && ligne(egal, 'Staff et fonctionnement') === undefined);
assert.ok(Math.abs(total(egal) - total(sans)) <= 300, 'staff au niveau attendu : même résultat qu’avant ' + total(egal) + ' / ' + total(sans));
assert.ok(Math.abs(total(sans) - total(cher) - 0.2e6 * 1.4 / 46) <= 300, 'staff plus fort : 200 000 € de plus par an, cotisations comprises');

// 4. Moteur (Valence, Pro D2) : prévu = encaissé, staff payé, prix qui pèse sur l'affluence.
const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
try {
  let model = creer(jeu, 29);
  const run = src => jeu.bridge.vm.run(src);
  const vue0 = JSON.parse(run('JSON.stringify(budgetBilletterieVue())'));
  assert.ok(vue0.expectedAttendance <= vue0.capacity && vue0.price === 7 && vue0.prices.abonnement > 8, JSON.stringify(vue0));
  // Trois prix de la saison fixés par le manager : billet plus cher = moins de monde (estimation du staff) ; abonnement moins
  // cher = plus d'abonnés.
  const prix = (kind, valeur) => { model = jeu.call('club_ticket_price', { context: model.clubLife.clubStrategy.context, kind, prix: valeur }); return model.clubLife.clubStrategy.fans; };
  const cher = prix('base', 14);
  assert.equal(cher.ticketing.prices.base, 14);
  assert.ok(cher.expectedAttendance < vue0.expectedAttendance, 'billet à 14 € : ' + cher.expectedAttendance + ' < ' + vue0.expectedAttendance);
  const aboBas = JSON.parse(run('budgetAbonnes(club(),undefined,40)')), aboHaut = JSON.parse(run('budgetAbonnes(club(),undefined,160)'));
  assert.ok(aboBas > aboHaut, 'abonnement moins cher, plus d’abonnés : ' + aboBas + ' / ' + aboHaut);
  prix('abonnement', 90); prix('affiche', 15);
  assert.deepEqual(model.clubLife.clubStrategy.fans.ticketing.prices, { base: 14, abonnement: 90, affiche: 15 });
  assert.throws(() => jeu.call('club_ticket_price', { context: model.clubLife.clubStrategy.context, kind: 'base', prix: 0 }));
  // Conseils du responsable de la billetterie : présents, jamais égaux au meilleur prix ; délégation = ses conseils appliqués.
  const t = model.clubLife.clubStrategy.fans.ticketing, optimaux = JSON.parse(run('JSON.stringify(budgetPrixOptimaux(club()))'));
  assert.ok(t.advice && t.estimatedBy && t.estimatedBy.level > 0, JSON.stringify(t));
  for (const k of ['base', 'abonnement', 'affiche']) assert.notEqual(t.advice[k], optimaux[k], 'conseil jamais exact : ' + k);
  model = jeu.call('club_ticket_delegate', { context: model.clubLife.clubStrategy.context, delegue: true });
  assert.deepEqual(model.clubLife.clubStrategy.fans.ticketing.prices, model.clubLife.clubStrategy.fans.ticketing.advice, 'délégué : les conseils deviennent les prix');
  prix('base', 8);
  assert.equal(model.clubLife.clubStrategy.fans.ticketing.delegated, false, 'un prix fixé à la main reprend la billetterie');
  prix('abonnement', vue0.prices.abonnement); prix('affiche', vue0.prices.affiche);
  // Jusqu'au premier match à domicile : la recette encaissée est celle du public réel ; l'estimation de la veille en est
  // proche, jamais égale (règle de Léo : aucun effet exact avant d'agir).
  let verifie = false;
  for (let n = 0; n < 6 && !verifie; n++) {
    model = jusquAuMatch(jeu, model);
    const vue = JSON.parse(run('JSON.stringify(budgetBilletterieVue())')), fans = model.clubLife.clubStrategy.fans;
    const chez = run(`(()=>{const f=CDWorldCareer.userFixture(S);return !!f&&f.homeId===S.club&&!f.neutral})()`);
    const abonnes = JSON.parse(run('budgetAbonnes(club())'));
    model = jouerLeMatch(jeu, model);
    model = jusquALaSemaineSuivante(jeu, model);
    if (!chez) continue;
    assert.equal(fans.expectedTicketRevenue, vue.expectedTicketRevenue, 'écran = moteur');
    const encaisse = JSON.parse(run(`JSON.stringify((()=>{const e=S.ledger.find(x=>/ · Billetterie$/.test(x.title));const h=S.history.find(r=>r.fixtureId===${JSON.stringify(vue.fixtureId)});return {recette:e?.amount,affluence:h?.affluence}})())`));
    assert.equal(encaisse.recette, B.guichet({ spectateurs: encaisse.affluence, abonnes, prix: vue.price }).recette, 'recette = billets au guichet × prix');
    assert.ok(encaisse.affluence >= Math.round(abonnes * B.PRESENCE_ABONNES), 'les abonnés comptent dans l’affluence');
    assert.notEqual(vue.expectedAttendance, encaisse.affluence, 'estimation, pas le chiffre exact');
    assert.ok(Math.abs(vue.expectedAttendance - encaisse.affluence) / encaisse.affluence < 0.2, 'estimation proche : ' + vue.expectedAttendance + ' / ' + encaisse.affluence);
    assert.ok(Math.abs(vue.expectedTicketRevenue - encaisse.recette) / encaisse.recette < 0.25, 'recette estimée proche : ' + vue.expectedTicketRevenue + ' / ' + encaisse.recette);
    verifie = true;
  }
  assert.ok(verifie, 'un match à domicile joué');
  const lignes = JSON.parse(run('JSON.stringify(S.ledger.slice(0,30).map(e=>e.title.split(" · ").pop()))'));
  for (const t of ['Abonnements', B.LIBELLE_STAFF, B.LIBELLE_FONCTIONNEMENT, 'Cotisations']) assert.ok(lignes.includes(t), 'ligne ' + t);
  const staffHebdo = JSON.parse(run('JSON.stringify(budgetStaff(club()))'));
  const paye = -JSON.parse(run(`JSON.stringify(S.ledger.find(e=>e.title.endsWith(" · ${B.LIBELLE_STAFF}")).amount)`));
  assert.equal(paye, Math.round(staffHebdo.annuel / run('wageForecastWeeks()') / 100) * 100, 'staff payé chaque semaine');
  console.log('billetterie-staff-reels PASS : billet ' + vue0.price + ' €, abonnement ' + vue0.prices.abonnement + ' €, grosse affiche ' + vue0.prices.affiche + ' €, ' + vue0.expectedAttendance + ' spectateurs estimés, recette estimée ' + vue0.expectedTicketRevenue + ' €, staff ' + staffHebdo.annuel + ' €/an');
} finally { jeu.fermer(); }
