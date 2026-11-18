'use strict';
// Nationale jouable (suite de #885) : la troisième division française ne vide plus sa trésorerie.
// Repère réel (A2R, bilans 2022-2023) : budget moyen 3,73 M€, salaires des joueurs à ~30 % des produits,
// résultat moyen -0,36 M€ (le meilleur à +0,02 M€), pertes comblées par le mécénat et les actionnaires.
// Même logique que la Pro D2 : masse encadrée par le contrôle de gestion, réserve propre au championnat.
// Ni le plafond salarial ni les autres championnats ne bougent.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const B = require('../native/engine/club-budget.cjs');
const E = require('../native/engine/league-economy.cjs');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const forces = ['elite', 'prem', 'urc', 'accession', 'nationale', 'champ'].flatMap((division, d) =>
  Array.from({ length: 14 }, (_, i) => ({ id: d * 14 + i, division, base: 60 + i })));

test('Limites : la Nationale est encadrée, une association y vise l’équilibre', () => {
  assert.equal(E.CHAMPIONNATS.nationale.encadrement, true);
  for (const nom of ['elite', 'prem', 'urc', 'champ', 'jlo-d1', 'srp']) assert.ok(!E.CHAMPIONNATS[nom].encadrement, nom);
  const R = B.recettes(forces);
  for (let saison = 1; saison <= 12; saison++) for (const [id, l] of B.limites(forces, saison)) {
    const f = forces[id];
    if (f.division !== 'nationale') continue;
    const p = B.proprietaire(forces, id), annuel = R.get(id), resultat = annuel * 0.42 - l.limite * 1.4;
    assert.equal(l.regle, 'budget', 'la borne des recettes du club, pas les 52 %');
    assert.ok(resultat >= -p.enveloppe - 0.05 * l.limite * 1.4 - 100, 'Nationale ' + id + ' : perte prévue ' + Math.round(resultat));
    // Marge de prudence (2,5 % des recettes) : une association vote un léger excédent, pour absorber recrues et jokers.
    if (p.type === 'association') assert.ok(resultat >= 0.02 * annuel, 'une association garde une marge : ' + Math.round(resultat));
  }
});

test('Réserve : 30 à 45 % des recettes en Nationale, rien ne change ailleurs', () => {
  const R = B.recettes(forces);
  for (const f of forces) {
    const r = B.reserveCible(R.get(f.id), f.id, f.division);
    if (f.division === 'nationale') assert.ok(r >= 0.3 * R.get(f.id) - 1e4 && r <= 0.45 * R.get(f.id) + 1e4, 'Nationale ' + f.id + ' : ' + r);
    else if (f.division !== 'accession') assert.equal(r, B.reserveCible(R.get(f.id), f.id), f.division + ' ' + f.id);
  }
});

test('Moteur Monde : Nationale sous sa limite, trésorerie gardée, club bien géré dans le vert, relégué de Pro D2 qui survit', () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 30);
    const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
    // Création : chaque club sous sa limite, salaires des joueurs autour de 30 % des recettes.
    const etat = lire(`(()=>{const f=budgetForces(),R=nativeClubBudget.recettes(f),L=budgetLimites(false);
      return S.clubs.filter(c=>budgetLigue(c.id)==='nationale').map(c=>({id:c.id,masse:budgetMasse(c)*52,limite:L.get(c.id).limite,recettes:R.get(c.id)}));})()`);
    assert.equal(etat.length, 14);
    for (const c of etat) assert.ok(c.masse <= c.limite * 1.02, 'club ' + c.id + ' : ' + Math.round(c.masse) + ' > ' + c.limite);
    const parts = etat.map(c => c.masse / c.recettes).sort((a, b) => a - b), mediane = parts[7];
    // Trésorerie de départ : 12 à 30 % des recettes de chaque club (avant : 2,6 M€ partout, jusqu'à 115 % des recettes).
    const caisses = lire(`(()=>{const R=nativeClubBudget.recettes(budgetForces());return S.clubs.filter(c=>budgetLigue(c.id)==='nationale').map(c=>[c.cash,R.get(c.id)]);})()`);
    for (const [cash, recettes] of caisses) assert.ok(cash >= 3e5 && cash <= 1.3e6 && cash / recettes <= 0.32, 'caisse de départ ' + cash + ' pour ' + recettes);
    assert.ok(mediane > 0.24 && mediane <= 0.33, 'salaires des joueurs / recettes, médiane ' + mediane.toFixed(3));
    // Deuxième saison : la trésorerie de départ (2,6 M€ partout) n'est plus engagée d'un coup (avant : 1,3 à 1,5 M€ par club).
    const engage = lire(`(()=>{const f=budgetForces(),o=nativeClubBudget.ouverture({forces:f,saison:2,clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,masse:budgetMasse(c)*52})),types:budgetTypes(),excedents:true});
      return S.clubs.filter(c=>budgetLigue(c.id)==='nationale').map(c=>o.clubs[c.id].investissement+o.clubs[c.id].dividende).sort((a,b)=>a-b);})()`);
    assert.ok(engage[7] <= 300000, 'engagé à l’ouverture de la saison 2, médiane ' + engage[7] + ' : ' + JSON.stringify(engage));
    // Saison projetée par le vrai budget du moteur (écritures hebdomadaires, frais de match, clôture), un match sur deux
    // à domicile. deplace : identifiant d'un club placé dans la division vers (masse : sa masse annuelle, sinon la sienne).
    const projeter = (deplace = -1, vers = 'nationale', masse = null) => lire(`(()=>{const rel=${deplace},vers='${vers}',masseRel=${masse};
      const f=budgetForces().map(x=>x.id===rel?{...x,division:vers}:x),repere=budgetRepere(),n=wageForecastWeeks(),hebdo=c=>c.id===rel&&masseRel?masseRel/52:budgetMasse(c);
      const clubs=S.clubs.filter(c=>f.find(x=>x.id===c.id).division===vers),ordre=clubs.slice().sort((a,b)=>b.base-a.base||a.id-b.id),R=nativeClubBudget.recettes(f);
      const o=nativeClubBudget.ouverture({forces:f,saison:1,clubs:clubs.map(c=>({id:c.id,cash:c.cash,masse:hebdo(c)*52})),types:budgetTypes()});
      return clubs.map((c,i)=>{const compte=o.clubs[i],rang=ordre.indexOf(c)+1,forme=rang<=4?'VVVDV':rang<=10?'VDVDN':'DDVDD',rec=repere.receptions[c.id]||Math.max(13,clubs.length-1);
        let caisse=c.cash,plusBas=c.cash;for(let w=0;w<n;w++){const e=nativeClubBudget.semaine({forces:f,clubId:c.id,masseHebdo:hebdo(c),semaines:n,receptions:rec,domicile:w%2===0,
          resultats:forme.split(''),repere:'test|'+w,gere:true,formation:budgetCentre(c)});
          const fr=nativeClubBudget.fraisDeMatch(compte,nativeClubBudget.recettesImprevues(e,{forces:f,clubId:c.id,receptions:rec}),nativeClubBudget.deficitPrevu(f,c.id,hebdo(c)*52));
          compte.imprevu=fr.imprevu;compte.fraisMatch=fr.fraisMatch;if(fr.montant>0)e.push({title:'frais',amount:-fr.montant});
          nativeClubBudget.compter(compte,e,hebdo(c)*52);caisse+=e.reduce((s,x)=>s+x.amount,0);plusBas=Math.min(plusBas,caisse);}
        const r=nativeClubBudget.cloture({division:vers,compte,tresorerie:caisse,rang,taille:clubs.length});
        return {id:c.id,type:compte.type,enveloppe:compte.enveloppe,resultat:r.resultat,apport:r.apport,depart:c.cash,plusBas,fin:caisse+r.ecritures.reduce((s,x)=>s+x.amount,0),
          part:hebdo(c)*52/R.get(c.id),masse:hebdo(c)*52};});})()`);
    const saison = projeter(-1);
    console.log('Nationale, saison projetée : ' + JSON.stringify(saison.map(c => [c.id, c.type, Math.round(c.resultat / 1e4) / 100])));
    for (const c of saison) assert.ok(c.resultat >= -c.enveloppe - 150000, 'club ' + c.id + ' (' + c.type + ') : perte ' + c.resultat + ' pour ' + c.enveloppe + ' comblés');
    assert.ok(saison.filter(c => c.resultat > 0).length >= 3, 'des clubs dans le vert : ' + JSON.stringify(saison.map(c => c.resultat)));
    // Un club bien géré (salaires des joueurs sous 27 % des recettes) finit dans le vert.
    const geres = saison.filter(x => x.part < 0.27);
    assert.ok(geres.length > 0, 'au moins un club bien géré dans la base');
    for (const c of geres) assert.ok(c.resultat > 0, 'club ' + c.id + ' bien géré (' + c.part.toFixed(2) + ') : ' + c.resultat);
    // Relégué de Pro D2 : le club le plus modeste descend avec sa masse de Pro D2 (pire cas : ni clause ni départ)
    // et termine sa première saison en Nationale avec de l'argent en caisse.
    const releguable = lire(`S.clubs.filter(c=>budgetLigue(c.id)==='accession').sort((a,b)=>a.base-b.base||a.id-b.id)[0].id`);
    const descente = projeter(releguable).find(c => c.id === releguable);
    console.log('Relégué de Pro D2 en Nationale : ' + JSON.stringify(descente));
    assert.ok(descente.fin > 0, 'le relégué survit à sa première saison : caisse finale ' + descente.fin);
    // Promu en Pro D2 : le club le plus riche de Nationale monte avec sa petite trésorerie (12 à 30 % de ses recettes) et une
    // masse portée à sa limite de Pro D2 (pire cas : recalage au barème de Pro D2, effectif complété jusqu'à la limite).
    // Il finit sa saison avec de l'argent en caisse, et sa caisse ne plonge pas sous zéro en cours de saison.
    const promu = lire(`S.clubs.filter(c=>budgetLigue(c.id)==='nationale').sort((a,b)=>b.base-a.base||a.id-b.id)[0].id`);
    const limitePro = lire(`(()=>{const f=budgetForces().map(x=>x.id===${promu}?{...x,division:'accession'}:x);return nativeClubBudget.limites(f,2,{types:budgetTypes()}).get(${promu}).limite;})()`);
    const montee = projeter(promu, 'accession', limitePro).find(c => c.id === promu);
    console.log('Promu de Nationale en Pro D2 : ' + JSON.stringify(montee));
    assert.ok(montee.fin > 0 && montee.plusBas > -0.05 * montee.masse, 'le promu tient sa première saison de Pro D2 : ' + JSON.stringify(montee));
  } finally { jeu.fermer(); }
});
