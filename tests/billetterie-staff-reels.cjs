'use strict';
// Économie du club (choix de Léo du 23/11/2026) :
//  1. billetterie réelle : recette d'un match à domicile = billets vendus au guichet × prix du billet, encaissée au match ;
//     abonnés payés à l'année ; le prix pèse sur l'affluence, bornée par la capacité ; prévu = encaissé ;
//  2. staff payé selon son rôle, son niveau et la division ; fonctionnement dégressif au-delà de 20 M€ de recettes.
const assert = require('node:assert/strict');
const B = require('../native/engine/club-budget.cjs');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante } = require('./helpers/carriere-monde.cjs');

// 1. Prix du billet : division et politique ; plus cher = moins de monde, jamais plus que la capacité.
assert.equal(B.prixBillet('accession', 'equilibree'), 8);
assert.ok(B.prixBillet('elite', 'equilibree') > B.prixBillet('accession', 'equilibree'), 'Top 14 plus cher que Pro D2');
assert.ok(B.prixBillet('accession', 'accessible') < 8 && B.prixBillet('accession', 'premium') > 8);
assert.equal(B.prixBillet('accession', 'inconnue'), 8, 'politique inconnue = équilibrée');
const match = (politique, resultats = ['V', 'D']) => B.spectateurs({ capacite: 12000, resultats, cle: 'x', alea: 0.5, politique });
assert.equal(match('equilibree'), B.spectateurs({ capacite: 12000, resultats: ['V', 'D'], cle: 'x', alea: 0.5 }), 'équilibrée = public d’avant');
assert.ok(match('accessible') > match('equilibree') && match('premium') < match('equilibree'), 'le prix pèse sur l’affluence');
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
  assert.ok(vue0.expectedAttendance <= vue0.capacity && vue0.price === 8, JSON.stringify(vue0));
  // Prix premium : billet plus cher, moins de monde ; retour à l'équilibré.
  const ctx = model.clubLife.clubStrategy.context;
  model = jeu.call('club_fans_price', { context: ctx, key: 'premium' });
  const premium = model.clubLife.clubStrategy.fans;
  assert.ok(premium.price > vue0.price && premium.expectedAttendance < vue0.expectedAttendance, 'premium : ' + premium.price + ' € / ' + premium.expectedAttendance);
  model = jeu.call('club_fans_price', { context: model.clubLife.clubStrategy.context, key: 'equilibree' });
  // Jusqu'au premier match à domicile : la prévision de la veille est exactement l'encaissé.
  let verifie = false;
  for (let n = 0; n < 6 && !verifie; n++) {
    model = jusquAuMatch(jeu, model);
    const vue = JSON.parse(run('JSON.stringify(budgetBilletterieVue())')), fans = model.clubLife.clubStrategy.fans;
    const chez = run(`(()=>{const f=CDWorldCareer.userFixture(S);return !!f&&f.homeId===S.club&&!f.neutral})()`);
    model = jouerLeMatch(jeu, model);
    model = jusquALaSemaineSuivante(jeu, model);
    if (!chez) continue;
    assert.equal(fans.expectedTicketRevenue, vue.expectedTicketRevenue, 'écran = moteur');
    const encaisse = JSON.parse(run(`JSON.stringify((()=>{const e=S.ledger.find(x=>/ · Billetterie$/.test(x.title));const h=S.history.find(r=>r.fixtureId===${JSON.stringify(vue.fixtureId)});return {recette:e?.amount,affluence:h?.affluence}})())`));
    assert.equal(encaisse.affluence, vue.expectedAttendance, 'spectateurs prévus = spectateurs du match');
    assert.equal(encaisse.recette, vue.expectedTicketRevenue, 'recette prévue = recette encaissée');
    verifie = true;
  }
  assert.ok(verifie, 'un match à domicile joué');
  const lignes = JSON.parse(run('JSON.stringify(S.ledger.slice(0,30).map(e=>e.title.split(" · ").pop()))'));
  for (const t of ['Abonnements', B.LIBELLE_STAFF, B.LIBELLE_FONCTIONNEMENT, 'Cotisations']) assert.ok(lignes.includes(t), 'ligne ' + t);
  const staffHebdo = JSON.parse(run('JSON.stringify(budgetStaff(club()))'));
  const paye = -JSON.parse(run(`JSON.stringify(S.ledger.find(e=>e.title.endsWith(" · ${B.LIBELLE_STAFF}")).amount)`));
  assert.equal(paye, Math.round(staffHebdo.annuel / run('wageForecastWeeks()') / 100) * 100, 'staff payé chaque semaine');
  console.log('billetterie-staff-reels PASS : billet ' + vue0.price + ' €, ' + vue0.expectedAttendance + ' spectateurs prévus, recette ' + vue0.expectedTicketRevenue + ' €, staff ' + staffHebdo.annuel + ' €/an');
} finally { jeu.fermer(); }
