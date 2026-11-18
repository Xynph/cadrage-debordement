'use strict';
// Santé financière visible (club-finance-health.cjs) et aide de la ligue aux relégués du Top 14 (club-budget.cjs,
// league-economy.cjs → accession.aideRelegue). Mode Monde uniquement.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const H = require('../native/engine/club-finance-health.cjs');
const B = require('../native/engine/club-budget.cjs');
const E = require('../native/engine/league-economy.cjs');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

test('Étiquette : caisse nette rapportée à la réserve, dette et découvert rendent fragile', () => {
  const r = 2e6;
  assert.equal(H.etiquette({ tresorerie: 0.9e6, reserve: r }), 'fragile');
  assert.equal(H.etiquette({ tresorerie: 1.2e6, reserve: r }), 'correcte');
  assert.equal(H.etiquette({ tresorerie: 2.5e6, reserve: r }), 'saine');
  assert.equal(H.etiquette({ tresorerie: 3.1e6, reserve: r }), 'riche');
  // La plus basse entre le départ de la saison et aujourd'hui : une saison qui tourne mal se voit, une belle semaine ne suffit pas.
  assert.equal(H.etiquette({ tresorerie: 3.1e6, depart: 1.5e6, reserve: r }), 'correcte');
  assert.equal(H.etiquette({ tresorerie: -1, depart: 5e6, reserve: r }), 'fragile');
  assert.equal(H.etiquette({ tresorerie: 5e6, reserve: r, dette: 0.5e6 }), 'fragile', 'endetté');
  assert.equal(H.etiquette({ tresorerie: 5e6, reserve: r, dette: 0.1e6 }), 'riche', 'reliquat de dette toléré');
  assert.equal(H.etiquette({ tresorerie: NaN, reserve: r }), null);
});

test('Historique : trois saisons au plus, une par saison, en milliers d’euros', () => {
  let h = [];
  for (const [s, v] of [[2026, 120000], [2027, -340000], [2027, -350000], [2028, 0], [2029, 1.234e6]]) h = H.historiser(h, s, v);
  assert.deepEqual(h, [[2027, -350], [2028, 0], [2029, 1234]]);
  const f = H.fiche({ tresorerie: 2.8e6, reserve: 2e6, type: 'mecene', historique: h });
  assert.deepEqual(f, { etiquette: 'saine', libelle: 'Saine', proprietaire: { type: 'mecene', libelle: 'Mécène' },
    courbe: [{ saison: 2027, resultat: -350000 }, { saison: 2028, resultat: 0 }, { saison: 2029, resultat: 1234000 }] });
});

test('Aide aux relégués : Top 14 → Pro D2 seulement, 0,6 M€ puis 0,3 M€ (dispositif LNR 2025-2026)', () => {
  assert.equal(B.aideRelegation('accession', 'elite', 0), 600000);
  assert.equal(B.aideRelegation('accession', 'elite', 1), 300000);
  assert.equal(B.aideRelegation('accession', 'elite', 2), 0);
  assert.equal(B.aideRelegation('nationale', 'accession', 0), 0, 'pas de dispositif relevé pour la Nationale');
  assert.equal(B.aideRelegation('champ', 'prem', 0), 0);
  assert.equal(B.aideRelegation('accession', 'nationale', 0), 0, 'un promu ne touche pas l’aide aux relégués');
  // Ordre de grandeur : la part de la ligue d'un club moyen de Pro D2 (22 % de 10,7 M€) ; l'aide en est un quart la première saison.
  const ligue = E.CHAMPIONNATS.accession.recettes * E.CHAMPIONNATS.accession.ligue;
  assert.ok(600000 / ligue > 0.2 && 600000 / ligue < 0.3);
  const forces = [{ id: 0, division: 'accession', base: 70 }, { id: 1, division: 'accession', base: 66 }];
  const e = B.semaine({ forces, clubId: 0, masseHebdo: 50000, semaines: 30, domicile: false, libelle: 'J1', aideRelegation: 600000 });
  assert.equal(e.find(x => x.title.endsWith(B.LIBELLE_AIDE_RELEGATION)).amount, 20000);
  assert.ok(!B.semaine({ forces, clubId: 1, masseHebdo: 50000, semaines: 30, domicile: false, libelle: 'J1' }).some(x => x.title.endsWith(B.LIBELLE_AIDE_RELEGATION)));
});

test('Moteur Monde : historique tenu à la clôture, classement financier, aide posée à la descente puis versée', () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 14);
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    const model = jeu.call('snapshot');
    assert.equal(model.finance.clubs.length, 16, 'classement financier du championnat (Pro D2)');
    assert.ok(model.finance.clubs.some(c => c.own) && model.finance.health.proprietaire, 'club du manager et sa fiche');
    assert.deepEqual(new Set(model.finance.clubs.map(c => c.etiquette)).has(null), false);
    const fiche = jeu.call('club_sheet', { club: 15 }).clubSheet.finances;
    assert.ok(fiche && fiche.libelle && fiche.proprietaire && Array.isArray(fiche.courbe), 'fiche club : ' + JSON.stringify(fiche));
    // Clôture : chaque club géré inscrit son résultat (avant l'apport du propriétaire).
    const apres = lire(`(()=>{const avant=S.clubs.map(c=>c.cash);budgetCloturer(true);return {h:S.clubFinances.clubs[15],moi:S.clubFinances.clubs[S.club]??null,s:S.season};})()`);
    assert.equal(apres.h.length, 1);
    assert.equal(apres.h[0][0], apres.s);
    assert.equal(apres.moi, null, 'le club joué est clôturé à part (financement de début de saison)');
    // Descente simulée : Béziers (club du manager) était en Top 14 dans les comptes de la saison passée.
    const aide = lire(`(()=>{S.clubBudget.clubs[S.club].division='elite';budgetPoserAidesRelegation();const pose=S.aidesRelegation[S.club];
      const avant=S.news.length;budgetOuvrir(true,false);const k=S.clubBudget.clubs[S.club];
      const e=budgetSemaine(budgetForces(),budgetRepere(),club(),null,'Test');
      const ligne=e.find(x=>x.title.endsWith(nativeClubBudget.LIBELLE_AIDE_RELEGATION));
      S.season++;budgetOuvrir(false);const deux=S.clubBudget.clubs[S.club].aideRelegation;
      S.season++;budgetPoserAidesRelegation();budgetOuvrir(false);const trois=S.clubBudget.clubs[S.club].aideRelegation;
      return {pose,un:k.aideRelegation,ligne:ligne?.amount??null,deux,trois,reste:S.aidesRelegation[S.club]??null,
        message:S.news.slice(0,S.news.length-avant+5).find(m=>/accompagne les clubs relégués/.test(m?.text??m))??null,
        autres:Object.keys(S.aidesRelegation).length};})()`);
    assert.ok(aide.pose && aide.pose.depuis === 'elite', 'aide posée : ' + JSON.stringify(aide));
    assert.equal(aide.un, 600000);
    assert.ok(aide.ligne > 0, 'ligne hebdomadaire au grand livre');
    assert.equal(aide.deux, 300000);
    assert.equal(aide.trois, 0);
    assert.equal(aide.reste, null, 'aide épuisée retirée');
    assert.equal(aide.autres, 0, 'aucun autre club aidé');
    assert.ok(aide.message, 'courrier de la ligue au club relégué');
  } finally { jeu.fermer(); }
});
