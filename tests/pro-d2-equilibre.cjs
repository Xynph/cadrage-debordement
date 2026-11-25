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
    // Championnat encadré : la borne suit la gestion propre du club (cibleGestion) quand son championnat en donne une pour son
    // propriétaire, sinon l'enveloppe entière.
    const aPerdre = c.encadrement && c.gestion?.[p.type] ? -B.cibleGestion(forces, id) : p.enveloppe;
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

test('Excédents d’un club de Pro D2 et de Nationale : 2 % des recettes engagés au plus par saison, sans limite ailleurs', () => {
  // Masse nulle : la saison laisse toute la place au réinvestissement (depuis le 25/11/2026, il ne prend que ce que le budget de
  // la saison laisse au-dessus du résultat visé, club-budget.cjs, ouverture) ; seule la limite d'engagement du championnat joue ici.
  const R = B.recettes(forces), riche = id => ({ id, cash: B.reserveCible(R.get(id), id, forces[id].division) + 3e6, masse: 0 });
  const o = B.ouverture({ forces, saison: 2, clubs: forces.map(f => riche(f.id)), excedents: true });
  for (const f of forces) {
    const k = o.clubs[f.id], engage = k.investissement + k.dividende;
    // Nationale depuis le 24/11/2026 : un relégué de Pro D2 n'engage plus d'un coup sa caisse au-dessus de la réserve.
    if (f.division === 'accession' || f.division === 'nationale') assert.ok(engage <= 0.02 * R.get(f.id) + 200, f.division + ' ' + f.id + ' : ' + engage);
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
    // Un club bien géré (salaires des joueurs sous 27 % des recettes) finit dans le vert : son train de vie garde l'épargne
    // de la Pro D2 (6 % des recettes, league-economy.cjs) pour les recrues et une prime de classement sous la moyenne.
    for (const c of saison.filter(x => x.part < 0.27)) assert.ok(c.resultat > 0, 'club ' + c.id + ' bien géré (' + c.part.toFixed(2) + ') : ' + c.resultat);
    assert.ok(saison.some(x => x.part < 0.27), 'au moins un club bien géré dans la base');
  } finally { jeu.fermer(); }
});

// Décision de Léo du 24/11/2026 (« c'est un jeu vidéo, pas un enfer ») : un club bien géré finit dans le vert, toujours, y compris
// la saison de la remontée (club du manager, associations ; les entreprises et mécènes peuvent viser une perte que leur propriétaire
// comble, « comme dans la réalité »). Mesures (saisons Monde réelles, graines
// 4242, 7 et 2026) : club du manager relégué puis 2e de Nationale -114 000 € (0,44 M€ de sa caisse de Pro D2 engagés d'un coup,
// train de vie à 70 % de l'excédent) ; club d'entreprise à 22 % de salaires -33 000 € (0,73 M€ d'indemnités de transfert, train
// de vie qui dépensait encore 0,39 M€).
test('Saison de la remontée et club d’entreprise : un club bien géré finit dans le vert', () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 29);
    const lire = s => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + s + ')'));
    // Saison projetée par le vrai budget du moteur, comme budgetSemaine : comptes d'une nouvelle saison (excédents engagés),
    // dépense hors budget (indemnité payée la semaine 5), frais de match, clôture. id : club ; vers : division de la saison ;
    // part : masse en part des recettes (sinon la limite du club dans la division) ; surplus : caisse au-dessus de la réserve
    // de la division, en part des recettes. Le club déplacé a la billetterie du modèle de sa nouvelle division ; il reçoit une
    // fois chaque adversaire (taille - 1 réceptions, pas une semaine sur deux de toute la saison).
    const projeter = ({ id, vers, part = null, surplus = 0, rang, forme, indemnite = 0, joue = false }) => lire(`(()=>{
      const id=${id},vers='${vers}',f=budgetForces().map(x=>x.id===id?{id,division:vers,base:x.base}:x),repere=budgetRepere(),n=wageForecastWeeks(),types=budgetTypes();
      const R=nativeClubBudget.recettes(f).get(id),taille=f.filter(x=>x.division===vers).length,limite=nativeClubBudget.limites(f,2,{types}).get(id).limite,c=S.clubs.find(x=>x.id===id);
      const masse=${part === null ? 'limite' : 'Math.round(' + part + '*R)'},depart=nativeClubBudget.reserveCible(R,id,vers)+${surplus}*R;
      const compte=nativeClubBudget.ouverture({forces:f,saison:2,clubs:[{id,cash:depart,masse}],types,excedents:true}).clubs[0];
      let tresor=compte.depart;for(let w=0;w<n;w++){
        if(w===5)tresor-=${indemnite}*R;
        const depense=-(tresor-compte.depart-(compte.recettes-compte.charges));
        const e=nativeClubBudget.semaine({forces:f,clubId:id,masseHebdo:masse/52,semaines:n,receptions:taille-1,domicile:w%2===0&&w/2<taille-1,resultats:'${forme}'.split(''),repere:'test|'+w,gere:true,
          formation:budgetCentre(c),investissement:compte.investissement,marge:${joue}?0:Math.max(0,nativeClubBudget.cibleGestion(f,id,compte.type)),objectif:${joue}?null:nativeClubBudget.objectifGestion(f,id,compte.type),depense,classement:{rang:${rang},taille}});
        const fr=nativeClubBudget.fraisDeMatch(compte,nativeClubBudget.recettesImprevues(e,{forces:f,clubId:id,receptions:taille-1}),nativeClubBudget.deficitPrevu(f,id,masse));
        compte.imprevu=fr.imprevu;compte.fraisMatch=fr.fraisMatch;if(fr.montant>0)e.push({title:'frais',amount:-fr.montant});
        nativeClubBudget.compter(compte,e,masse);tresor+=e.reduce((s,x)=>s+x.amount,0);}
      const r=nativeClubBudget.cloture({division:vers,compte,tresorerie:tresor,rang:${rang},taille,joue:${joue}});
      return {id,type:compte.type,enveloppe:compte.enveloppe,recettes:Math.round(R),masse,limite,engage:compte.investissement+compte.dividende,resultat:r.resultat};})()`);
    // 1. Saison de la remontée (graine 2026) : le club du manager, relégué de Pro D2, arrive en Nationale avec 27 % de salaires et
    // sa caisse de Pro D2, 10 % des recettes au-dessus de la réserve ; 2e sur 14, il remonte et finit dans le vert, sans engager
    // sa caisse d'un coup. Avant : tout l'excédent de caisse engagé, train de vie à 70 % de l'excédent prévu, saison dans le rouge.
    const remontee = projeter({ id: 29, vers: 'nationale', part: 0.27, surplus: 0.1, rang: 2, forme: 'VVVDV', joue: true });
    console.log('Saison de la remontée : ' + JSON.stringify(remontee));
    assert.ok(remontee.engage <= 0.02 * remontee.recettes + 200, 'caisse de Pro D2 engagée au plus à 2 % des recettes : ' + remontee.engage);
    assert.ok(remontee.resultat > 0, 'remontée de Nationale dans le vert : ' + remontee.resultat);
    // Même saison au milieu du tableau (7e sur 14) : toujours dans le vert.
    const milieu = projeter({ id: 29, vers: 'nationale', part: 0.27, surplus: 0.1, rang: 7, forme: 'VDVDN', joue: true });
    assert.ok(milieu.resultat > 0, 'relégué bien géré, milieu de tableau de Nationale, dans le vert : ' + milieu.resultat);
    // 2. Première saison de Pro D2 après la montée : masse de Nationale relevée par les primes d'accession (27 % des recettes de
    // Nationale + 20 %, le maximum des clauses), 12e sur 16 en petite forme : dans le vert.
    const montee = projeter({ id: 29, vers: 'accession', part: 1.2 * 0.27 * remontee.recettes / lire(`nativeClubBudget.recettes(budgetForces()).get(29)`), surplus: 0.1, rang: 12, forme: 'DDVDD', joue: true });
    console.log('Première saison en Pro D2 après la montée : ' + JSON.stringify(montee));
    assert.ok(montee.resultat > 0, 'promu bien géré dans le vert : ' + montee.resultat);
    // 3. Clubs d'entreprise et associations gérés par le jeu, à leur limite de Pro D2, 8e. Décision de Léo du 24/11/2026
    // (« comme dans la réalité ») : une entreprise peut viser une perte, mais jamais au-delà de ce que son actionnaire comble ;
    // une association (bien gérée) finit dans le vert.
    const de = type => lire(`(()=>{const t=budgetTypes(),R=nativeClubBudget.recettes(budgetForces());return S.clubs.filter(c=>budgetLigue(c.id)==='accession'&&t[c.id]==='${type}'&&c.id!==S.club)
      .map(c=>[c.id,R.get(c.id)]).sort((a,b)=>Math.abs(a[1]-10.7e6)-Math.abs(b[1]-10.7e6)).map(x=>x[0]);})()`);
    const entreprises = de('entreprise'), associations = de('association');
    assert.ok(entreprises.length >= 3 && associations.length >= 2, 'des clubs d’entreprise et des associations en Pro D2');
    for (const id of entreprises) {
      const r = projeter({ id, vers: 'accession', rang: 8, forme: 'VDVDN' });
      assert.ok(r.resultat >= -r.enveloppe, 'entreprise ' + id + ' à sa limite, 8e : perte dans l’enveloppe ' + JSON.stringify(r));
    }
    for (const id of associations) {
      const r = projeter({ id, vers: 'accession', rang: 8, forme: 'VDVDN' });
      assert.ok(r.resultat > 0, 'association ' + id + ' à sa limite, 8e : ' + JSON.stringify(r));
    }
    // 4. Club bien géré (22 % de salaires, recettes proches de la moyenne) qui paie en cours de saison une indemnité de transfert
    // de 8 % de ses recettes, 10e (graine 4242, club 23 : 0,73 M€) : son train de vie ne dépense pas l'indemnité une deuxième
    // fois, il finit dans le vert.
    const indemnite = projeter({ id: entreprises[0], vers: 'accession', part: 0.22, rang: 10, forme: 'VDVDN', indemnite: 0.08 });
    console.log('Club à 22 % de salaires, indemnité de 8 % : ' + JSON.stringify(indemnite));
    assert.ok(indemnite.resultat > 0, 'indemnité payée, train de vie retenu : ' + indemnite.resultat);
    // 5. Association dont la masse dépasse ce qu'elle s'autorise (recettes en baisse, contrats en cours : 31 %), 10e : elle réduit
    // son fonctionnement pour tenir son objectif (avant : rien tant que la perte ne dépassait pas l'enveloppe, nulle chez elle...
    // donc 70 % seulement du déficit).
    const lourd = projeter({ id: associations[0], vers: 'accession', part: 0.31, rang: 10, forme: 'VDVDN' });
    console.log('Association à 31 % de salaires : ' + JSON.stringify(lourd));
    assert.ok(lourd.resultat > 0, 'association au-dessus de sa limite, ramenée dans le vert : ' + lourd.resultat);
    // 6. Derniers (16e, forme du bas de tableau comme la saison projetée, la plus petite prime de classement : -0,47 M€ par rapport à la moyenne) : une association voit son rang et
    // réduit son fonctionnement (dans le vert) ; une entreprise reste dans ce que son actionnaire comble.
    for (const id of associations) {
      const r = projeter({ id, vers: 'accession', rang: 16, forme: 'DDVDD' });
      assert.ok(r.resultat > 0, 'association ' + id + ' à sa limite, dernière : ' + JSON.stringify(r));
    }
    for (const id of entreprises) {
      const r = projeter({ id, vers: 'accession', rang: 16, forme: 'DDVDD' });
      assert.ok(r.resultat >= -r.enveloppe, 'entreprise ' + id + ' à sa limite, dernière : perte dans l’enveloppe ' + JSON.stringify(r));
    }
  } finally { jeu.fermer(); }
});
