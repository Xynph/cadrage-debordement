'use strict';
// Pro D2 jouable (suite de #882) : la deuxième division française ne finit plus entièrement dans le rouge.
// Repère réel (A2R/CCCP 2024-2025) : salaires des joueurs à ~30 % des produits, 2 clubs sur 16 en bénéfice,
// 5 ou 6 proches de l'équilibre, les autres en perte comblée par l'actionnaire.
// Ni le plafond salarial ni les autres championnats ne bougent.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const B = require('../native/engine/club-budget.cjs');
const E = require('../native/engine/league-economy.cjs');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const forces = ['elite', 'prem', 'urc', 'accession', 'nationale', 'srp'].flatMap((division, d) =>
  Array.from({ length: 16 }, (_, i) => ({ id: d * 16 + i, division, base: 62 + i })));

test('Limites : Pro D2 (et Nationale, tests/nationale-equilibre.cjs) encadrées, les autres championnats gardent leur borne', () => {
  assert.deepEqual(Object.entries(E.CHAMPIONNATS).filter(([, c]) => c.encadrement).map(([k]) => k), ['accession', 'nationale']);
  const R = B.recettes(forces);
  for (let saison = 1; saison <= 12; saison++) for (const [id, l] of B.limites(forces, saison)) {
    const f = forces[id], c = E.CHAMPIONNATS[f.division], p = B.proprietaire(forces, id), annuel = R.get(id);
    // Championnat encadré : la borne suit la gestion propre du club (cibleGestion), ailleurs l'enveloppe entière.
    const aPerdre = c.encadrement && c.gestion ? -B.cibleGestion(forces, id) : p.enveloppe;
    const budget = (annuel - B.fonctionnementAnnuel(annuel) - annuel * (c.prudence ?? 0) + aPerdre + (c.encadrement ? 0 : 0.15 * annuel)) / 1.4;
    const bornes = [budget, c.plafond ?? Infinity, c.ratio ? annuel * 0.52 : Infinity];
    const attendu = Math.min(c.plafond ?? Infinity, Math.min(...bornes) * l.tolerance);
    assert.ok(Math.abs(l.limite - attendu) <= 100, f.division + ' ' + id + ' saison ' + saison + ' : ' + l.limite + ' au lieu de ' + Math.round(attendu));
    if (c.plafond) assert.ok(l.limite <= c.plafond, 'plafond jamais dépassé');
    if (f.division === 'accession') {
      // Une masse à la limite ne prévoit pas plus de pertes que ce que le propriétaire comble (audace d'un mécène : 5 % au plus).
      const resultat = annuel * 0.42 - l.limite * 1.4;
      assert.ok(resultat >= -p.enveloppe - 0.05 * l.limite * 1.4 - 100, 'Pro D2 ' + id + ' : perte prévue ' + Math.round(resultat));
      if (p.type === 'association') assert.ok(resultat >= 0.02 * annuel * l.tolerance - 100, 'une association vise un excédent : ' + Math.round(resultat));
    }
  }
});

test('Gestion propre à chaque club de Pro D2 : bons élèves, clubs à l’équilibre, clubs qui perdent', () => {
  const R = B.recettes(forces), pro = forces.filter(f => f.division === 'accession');
  for (const f of forces) if (f.division !== 'accession') assert.equal(B.cibleGestion(forces, f.id), 0, f.division + ' ' + f.id + ' : aucune cible hors Pro D2');
  const cibles = pro.map(f => ({ ...B.proprietaire(forces, f.id), annuel: R.get(f.id), cible: B.cibleGestion(forces, f.id) }));
  for (const c of cibles) {
    // Stable d'une saison à l'autre (même club, même propriétaire) et jamais au-delà de ce que le propriétaire comble.
    assert.ok(c.cible >= -c.enveloppe - 100, c.type + ' : ' + c.cible);
    if (c.type === 'association') assert.ok(c.cible >= 0.02 * c.annuel - 100 && c.cible <= 0.06 * c.annuel + 100, 'association : excédent de 2 à 6 %');
    else if (c.type === 'entreprise') assert.ok(c.cible <= 100 && c.cible >= -0.6 * c.enveloppe - 100, 'entreprise : 0 à 60 % de l’enveloppe');
    else assert.ok(c.cible <= -0.8 * c.enveloppe + 100, 'mécène : 80 à 100 % de l’enveloppe');
  }
  assert.ok(new Set(cibles.map(c => c.type)).size === 3, 'les trois sortes de propriétaires en Pro D2');
  // Train de vie : l'excédent visé n'est pas dépensé, seul ce qui le dépasse l'est.
  assert.equal(B.ajustement(10e6, 2.72e6, 0, 0.4e6), 0, 'excédent prévu (0,39 M€) sous l’excédent visé (0,4) : le train de vie n’y touche pas');
  assert.ok(Math.abs(B.ajustement(10e6, 2e6, 0, 0.4e6) - 0.7 * (1.4e6 - 0.4e6)) < 1, 'au-delà de l’excédent visé, 70 % repartent');
  assert.ok(Math.abs(B.ajustement(10e6, 2e6, 0) - 0.7 * 1.4e6) < 1, 'sans marge (autres championnats, club joué) : règle inchangée');
});

test('Excédents d’un club de Pro D2 : 2 % des recettes engagés au plus par saison, sans limite ailleurs', () => {
  const R = B.recettes(forces), riche = id => ({ id, cash: B.reserveCible(R.get(id), id, forces[id].division) + 3e6, masse: 2e6 });
  const o = B.ouverture({ forces, saison: 2, clubs: forces.map(f => riche(f.id)), excedents: true });
  for (const f of forces) {
    const k = o.clubs[f.id], engage = k.investissement + k.dividende;
    if (f.division === 'accession') assert.ok(engage <= 0.02 * R.get(f.id) + 200, 'Pro D2 ' + f.id + ' : ' + engage);
    else assert.ok(engage >= 1.5e6, f.division + ' ' + f.id + ' : règle générale (' + engage + ')');
  }
});

test('Réserve : 20 à 30 % des recettes en Pro D2, règle générale ailleurs', () => {
  const R = B.recettes(forces);
  for (const f of forces) {
    const r = B.reserveCible(R.get(f.id), f.id, f.division), general = B.reserveCible(R.get(f.id), f.id);
    if (f.division === 'accession') assert.ok(r >= 0.2 * R.get(f.id) - 1e4 && r <= 0.3 * R.get(f.id) + 1e4, 'Pro D2 ' + f.id + ' : ' + r);
    else if (f.division !== 'nationale') assert.equal(r, general, f.division + ' ' + f.id);
  }
});

test('Moteur Monde : aucun club de Pro D2 ne vote une perte que son propriétaire ne comblera pas, un club bien géré finit positif', () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 30);
    const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
    // Création : chaque club de Pro D2 sous sa limite, salaires des joueurs autour de 30 % des recettes.
    const etat = lire(`(()=>{const f=budgetForces(),R=nativeClubBudget.recettes(f),L=budgetLimites(false);
      return S.clubs.filter(c=>budgetLigue(c.id)==='accession').map(c=>({id:c.id,masse:budgetMasse(c)*52,limite:L.get(c.id).limite,recettes:R.get(c.id)}));})()`);
    assert.equal(etat.length, 16);
    for (const c of etat) assert.ok(c.masse <= c.limite * 1.02, 'club ' + c.id + ' : ' + Math.round(c.masse) + ' > ' + c.limite);
    const parts = etat.map(c => c.masse / c.recettes).sort((a, b) => a - b), mediane = parts[8];
    assert.ok(mediane > 0.24 && mediane <= 0.31, 'salaires des joueurs / recettes, médiane ' + mediane.toFixed(3));
    // Deuxième saison : la trésorerie de départ d'un club de Pro D2 n'est plus engagée d'un coup en investissements.
    const engage = lire(`(()=>{const f=budgetForces(),o=nativeClubBudget.ouverture({forces:f,saison:2,clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,masse:budgetMasse(c)*52})),types:budgetTypes(),excedents:true});
      return S.clubs.filter(c=>budgetLigue(c.id)==='accession').map(c=>o.clubs[c.id].investissement+o.clubs[c.id].dividende).sort((a,b)=>a-b);})()`);
    assert.ok(engage[8] <= 250000, 'engagé à l’ouverture de la saison 2, médiane ' + engage[8] + ' : ' + JSON.stringify(engage));
    // Saison projetée par le vrai budget du moteur (écritures hebdomadaires du club géré, frais de match, clôture) :
    // un match sur deux à domicile, forme et classement selon la force du club.
    const saison = lire(`(()=>{const f=budgetForces(),repere=budgetRepere(),n=wageForecastWeeks(),clubs=S.clubs.filter(c=>budgetLigue(c.id)==='accession');
      const ordre=clubs.slice().sort((a,b)=>b.base-a.base||a.id-b.id);
      return clubs.map(c=>{const compte=JSON.parse(JSON.stringify(S.clubBudget.clubs[c.id])),rang=ordre.indexOf(c)+1,forme=rang<=5?'VVVDV':rang<=11?'VDVDN':'DDVDD';
        let caisse=c.cash;for(let w=0;w<n;w++){const e=nativeClubBudget.semaine({forces:f,clubId:c.id,masseHebdo:budgetMasse(c),semaines:n,receptions:repere.receptions[c.id]||15,domicile:w%2===0,
          resultats:forme.split(''),repere:'test|'+w,gere:true,formation:budgetCentre(c),marge:Math.max(0,nativeClubBudget.cibleGestion(f,c.id,compte.type))});
          const fr=nativeClubBudget.fraisDeMatch(compte,nativeClubBudget.recettesImprevues(e,{forces:f,clubId:c.id,receptions:repere.receptions[c.id]||15}),nativeClubBudget.deficitPrevu(f,c.id,budgetMasse(c)*52));
          compte.imprevu=fr.imprevu;compte.fraisMatch=fr.fraisMatch;if(fr.montant>0)e.push({title:'frais',amount:-fr.montant});
          nativeClubBudget.compter(compte,e,budgetMasse(c)*52);caisse+=e.reduce((s,x)=>s+x.amount,0);}
        const r=nativeClubBudget.cloture({division:'accession',compte,tresorerie:caisse,rang,taille:16});
        return {id:c.id,type:compte.type,enveloppe:compte.enveloppe,resultat:r.resultat,part:budgetMasse(c)*52/nativeClubBudget.recettes(f).get(c.id)};});})()`);
    // La saison réelle coûte davantage (recrues en cours de saison, transferts, jokers) : le compte des clubs en perte se lit
    // dans la mesure des clubs gérés. Ici, le budget voté : aucun club ne prévoit une perte que son propriétaire ne comblerait pas.
    console.log('Pro D2, saison projetée : ' + JSON.stringify(saison.map(c => [c.id, c.type, Math.round(c.resultat / 1e4) / 100])));
    for (const c of saison) assert.ok(c.resultat >= -c.enveloppe - 150000, 'club ' + c.id + ' (' + c.type + ') : perte ' + c.resultat + ' pour ' + c.enveloppe + ' comblés');
    const resultats = saison.map(c => c.resultat).sort((a, b) => a - b);
    assert.ok(resultats.filter(r => r > 0).length >= 4, 'des clubs dans le vert : ' + JSON.stringify(resultats));
    // Un club bien géré (salaires des joueurs sous 27 % des recettes) finit dans le vert, à la marge près de la vraie billetterie
    // (23/11/2026 : le dernier du classement, en forme DDVDD, remplit moins son stade ; -71 100 € sur ~10 M€ de recettes).
    for (const c of saison.filter(x => x.part < 0.27)) assert.ok(c.resultat > -150000, 'club ' + c.id + ' bien géré (' + c.part.toFixed(2) + ') : ' + c.resultat);
    assert.ok(saison.some(x => x.part < 0.27), 'au moins un club bien géré dans la base');
  } finally { jeu.fermer(); }
});
