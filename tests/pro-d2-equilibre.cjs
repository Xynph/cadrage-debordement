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

test('Limites : seule la Pro D2 est encadrée, les autres championnats gardent leur borne', () => {
  assert.deepEqual(Object.entries(E.CHAMPIONNATS).filter(([, c]) => c.encadrement).map(([k]) => k), ['accession']);
  const R = B.recettes(forces);
  for (let saison = 1; saison <= 12; saison++) for (const [id, l] of B.limites(forces, saison)) {
    const f = forces[id], c = E.CHAMPIONNATS[f.division], p = B.proprietaire(forces, id), annuel = R.get(id);
    const budget = (annuel * 0.42 + p.enveloppe + (c.encadrement ? 0 : 0.15 * annuel)) / 1.4;
    const bornes = [budget, c.plafond ?? Infinity, c.ratio ? annuel * 0.52 : Infinity];
    const attendu = Math.min(c.plafond ?? Infinity, Math.min(...bornes) * l.tolerance);
    assert.ok(Math.abs(l.limite - attendu) <= 100, f.division + ' ' + id + ' saison ' + saison + ' : ' + l.limite + ' au lieu de ' + Math.round(attendu));
    if (c.plafond) assert.ok(l.limite <= c.plafond, 'plafond jamais dépassé');
    if (f.division === 'accession') {
      // Une masse à la limite ne prévoit pas plus de pertes que ce que le propriétaire comble (audace d'un mécène : 5 % au plus).
      const resultat = annuel * 0.42 - l.limite * 1.4;
      assert.ok(resultat >= -p.enveloppe - 0.05 * l.limite * 1.4 - 100, 'Pro D2 ' + id + ' : perte prévue ' + Math.round(resultat));
      if (p.type === 'association') assert.ok(resultat >= -100, 'une association vise l’équilibre');
    }
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
    // Saison projetée par le vrai budget du moteur (écritures hebdomadaires du club géré, frais de match, clôture) :
    // un match sur deux à domicile, forme et classement selon la force du club.
    const saison = lire(`(()=>{const f=budgetForces(),repere=budgetRepere(),n=wageForecastWeeks(),clubs=S.clubs.filter(c=>budgetLigue(c.id)==='accession');
      const ordre=clubs.slice().sort((a,b)=>b.base-a.base||a.id-b.id);
      return clubs.map(c=>{const compte=JSON.parse(JSON.stringify(S.clubBudget.clubs[c.id])),rang=ordre.indexOf(c)+1,forme=rang<=5?'VVVDV':rang<=11?'VDVDN':'DDVDD';
        let caisse=c.cash;for(let w=0;w<n;w++){const e=nativeClubBudget.semaine({forces:f,clubId:c.id,masseHebdo:budgetMasse(c),semaines:n,receptions:repere.receptions[c.id]||15,domicile:w%2===0,
          resultats:forme.split(''),repere:'test|'+w,gere:true,formation:budgetCentre(c)});
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
    // Un club bien géré (salaires des joueurs sous 27 % des recettes) finit dans le vert.
    for (const c of saison.filter(x => x.part < 0.27)) assert.ok(c.resultat > 0, 'club ' + c.id + ' bien géré (' + c.part.toFixed(2) + ') : ' + c.resultat);
    assert.ok(saison.some(x => x.part < 0.27), 'au moins un club bien géré dans la base');
  } finally { jeu.fermer(); }
});
