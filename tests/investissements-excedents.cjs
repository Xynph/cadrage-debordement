'use strict';
// Investissements des excédents (suite de #870 ; native/engine/club-investments.cjs, club-budget.cjs, club-mail.cjs).
//   1. Unitaires purs : découpe exacte, répartition, avancement des chantiers (installations, staff, accueil), facteur d'accueil.
//   2. Budget : l'accueil relève seulement billetterie et boutique d'un match à domicile.
//   3. Moteur Monde (`world-champ`, graine fixe) : trois lignes « Investissements : … » dont la somme est l'ancien montant
//      unique, chantiers aboutis sur des semaines simulées, trésorerie inchangée hors effet d'accueil.
//   4. Courrier du président : une fois par saison, une seule orientation.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const B = require('../native/engine/club-budget.cjs');
const I = require('../native/engine/club-investments.cjs');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch } = require('./helpers/carriere-monde.cjs');

const somme = o => Object.values(o).reduce((s, x) => s + x, 0);
const unPlan = (extra = {}) => I.plan({ id: 0, montant: 1e7, type: 'mecene', strategie: null, installations: 2, staffDisponible: true, ...extra });
const seul = (part, extra = {}) => { const p = unPlan(extra); p.parts = { installations: 0, staff: 0, accueil: 0, [part]: 1 }; return p; };

test('Découpe : trois parts entières dont la somme est exactement le montant', () => {
  const jeux = [{ installations: 0.45, staff: 0.35, accueil: 0.2 }, { installations: 1 / 3, staff: 1 / 3, accueil: 1 / 3 }, { installations: 0, staff: 0.5, accueil: 0.5 }, { installations: 0.3, staff: 0.35, accueil: 0.35 }];
  for (const parts of jeux) for (const montant of [0, 1, 2, 7, 999999, 1666667, 17500001, 123456789]) {
    const d = I.decouper(montant, parts);
    assert.equal(somme(d), montant, JSON.stringify(parts) + ' ' + montant);
    for (const k of I.PARTS) assert.ok(Number.isInteger(d[k]) && d[k] >= 0, k);
  }
  assert.deepEqual(I.decouper(1000, { installations: 0, staff: 1, accueil: 0 }), { installations: 0, staff: 1000, accueil: 0 });
});

test('Répartition : total 1, installations nulles au niveau 10, staff nul sans staff, orientations', () => {
  for (const type of ['mecene', 'association', 'entreprise']) for (const strategie of [null, 'formateur', 'vedettes']) for (const orientation of [null, 'equilibre', 'installations', 'staff', 'accueil']) {
    for (const [installations, staffDisponible] of [[2, true], [10, true], [4, false], [10, false]]) {
      const p = I.repartition({ type, strategie, orientation, installations, staffDisponible });
      assert.ok(Math.abs(somme(p) - 1) < 1e-9, 'total ' + somme(p));
      for (const k of I.PARTS) assert.ok(p[k] >= 0);
      if (installations >= 10) assert.equal(p.installations, 0);
      if (!staffDisponible) assert.equal(p.staff, 0);
    }
  }
  const base = I.repartition({ type: 'mecene' });
  assert.deepEqual(base, I.REPARTITION.mecene);
  assert.deepEqual(I.repartition({ type: 'mecene', orientation: 'equilibre' }), base, 'équilibre = répartition du propriétaire');
  assert.ok(I.repartition({ type: 'mecene', strategie: 'formateur' }).installations > base.installations);
  assert.deepEqual(I.repartition({ type: 'mecene', strategie: 'formateur', orientation: 'staff' }), I.ORIENTATIONS.staff, 'le choix du manager prime la stratégie');
  for (const k of I.PARTS) assert.ok(I.repartition({ type: 'entreprise', orientation: k })[k] >= 0.6 - 1e-9, 'orientation ' + k);
  assert.deepEqual(I.repartition({ type: 'inconnu' }), I.REPARTITION.association);
  const rep = I.repartition({ type: 'mecene', orientation: 'installations', installations: 10 });
  assert.equal(rep.installations, 0); assert.ok(Math.abs(rep.staff + rep.accueil - 1) < 1e-9);
});

test('Installations : la cagnotte atteint le devis, le niveau monte, le coût est retenu', () => {
  const p = seul('installations'); // niveau 2 : devis 750 000 €
  assert.equal(I.coutInstallations(2), 750000);
  let r = I.semaine(p, 749999, { installations: 2 });
  assert.equal(r.installations, 2); assert.equal(r.faits.travaux, 0); assert.equal(p.cagnotte.installations, 749999);
  r = I.semaine(p, 1, { installations: 2 });
  assert.equal(r.installations, 3); assert.equal(r.faits.travaux, 1);
  assert.equal(p.cagnotte.installations, 0, 'le coût du devis est retenu');
  assert.equal(p.depense.installations, 750000); assert.equal(p.travaux, 1);
  // Reste conservé, plusieurs niveaux d'un coup si la cagnotte le permet (750 000 + 900 000 = 1 650 000).
  const q = seul('installations');
  r = I.semaine(q, 1700000, { installations: 2 });
  assert.equal(r.installations, 4); assert.equal(r.faits.travaux, 2); assert.equal(q.cagnotte.installations, 50000);
  // Niveau 10 : plus de travaux ; la cagnotte bascule vers le staff, et faute de staff vers l'accueil (rien ne dort).
  const m = seul('installations');
  r = I.semaine(m, 5e6, { installations: 10 });
  assert.equal(r.installations, 10); assert.equal(r.faits.travaux, 0);
  assert.equal(m.cagnotte.installations, 0); assert.equal(m.cagnotte.staff, 0); assert.equal(m.accueil, 5); assert.ok(m.cagnotte.accueil > 0);
  const n = seul('installations'); n.cagnotte.installations = 400000;
  r = I.semaine(n, 5e5, { installations: 9 }); // devis niveau 9 : 1 800 000 €, jamais atteint ici
  assert.equal(r.installations, 9);
  r = I.semaine(n, 2e6, { installations: 9 });
  assert.equal(r.installations, 10); assert.equal(n.cagnotte.installations, 0); assert.equal(n.cagnotte.staff, 0); assert.ok(n.accueil > 0, 'le reliquat finance l’accueil');
});

test('Staff : un point au plus faible des cinq rôles, 3 points par personne et par saison, plafond 85', () => {
  const equipe = () => [{ id: 'a', role: 'coach', level: 50 }, { id: 'b', role: 'scout', level: 60 }, { id: 'c', role: 'analyst', level: 84 },
    { id: 'm', role: 'medical', level: 10 }, { id: 'p', role: 'fitness', level: 20 }, { id: 'z', role: 'assistant', level: 85 }];
  const p = seul('staff');
  let r = I.semaine(p, 59999, { installations: 2, staff: equipe() });
  assert.deepEqual(r.faits.points, []); assert.equal(p.cagnotte.staff, 59999);
  r = I.semaine(p, 1, { installations: 2, staff: equipe() });
  assert.deepEqual(r.faits.points, ['a'], 'le plus faible des rôles qui comptent (ni médical, ni physique)');
  assert.equal(p.cagnotte.staff, 0);
  // Dix points d'un coup : a 3, b 3 (plafond par personne), c 1 (plafond 85), puis plus personne : le reste part aux travaux.
  const q = seul('staff');
  r = I.semaine(q, 600000, { installations: 2, staff: equipe() });
  const par = {}; for (const id of r.faits.points) par[id] = (par[id] || 0) + 1;
  assert.deepEqual(par, { a: 3, b: 3, c: 1 });
  assert.equal(q.gains.a, 3); assert.equal(q.cagnotte.staff, 0); assert.equal(q.cagnotte.installations, 3 * 60000);
  assert.ok(!r.faits.points.includes('m') && !r.faits.points.includes('p') && !r.faits.points.includes('z'));
  // Le plafond de 3 points tient sur plusieurs semaines : les gains de la saison sont mémorisés.
  const apres = equipe(); for (const id of r.faits.points) apres.find(x => x.id === id).level++;
  r = I.semaine(q, 600000, { installations: 2, staff: apres });
  assert.deepEqual(r.faits.points, [], 'tous les membres à 3 points ou au plafond');
  // Ordre stable à niveau égal (identifiant).
  const s = seul('staff');
  r = I.semaine(s, 60000, { installations: 2, staff: [{ id: 'y', role: 'coach', level: 70 }, { id: 'x', role: 'scout', level: 70 }] });
  assert.deepEqual(r.faits.points, ['x']);
  // L'un des rôles à 84 : un seul point, jamais au-delà de 85.
  const t = seul('staff'), eq = [{ id: 'c', role: 'coach', level: 84 }];
  r = I.semaine(t, 6e6, { installations: 2, staff: eq });
  assert.deepEqual(r.faits.points, ['c']);
  assert.equal(I.STAFF.max, 85);
});

test('Accueil : le niveau monte avec la cagnotte, plafond 5, non entretenu il se dégrade', () => {
  const p = seul('accueil');
  assert.equal(I.coutAccueil(0), 250000); assert.equal(I.coutAccueil(1), 500000);
  let r = I.semaine(p, 249999, { installations: 2 }); assert.equal(p.accueil, 0); assert.equal(r.faits.accueil, 0);
  r = I.semaine(p, 1, { installations: 2 }); assert.equal(p.accueil, 1); assert.equal(p.cagnotte.accueil, 0); assert.equal(r.faits.accueil, 1);
  r = I.semaine(p, 1e7, { installations: 2 });
  assert.equal(p.accueil, 5); assert.equal(p.accueilGagne, 5);
  assert.equal(p.cagnotte.accueil, 1e7 - (500000 + 750000 + 1000000 + 1250000), 'cagnotte restante : l’entretien du niveau 5');
  // Saison suivante : entretenu (dépense suffisante) = maintenu ; sinon recul d'un cran.
  const nouveau = (precedent, extra = {}) => I.plan({ id: 0, montant: 1e7, type: 'mecene', installations: 2, staffDisponible: true, precedent, ...extra });
  const entretenu = nouveau({ cagnotte: { installations: 12, staff: 34, accueil: 56 }, accueil: 3, depense: { installations: 0, staff: 0, accueil: I.coutAccueil(2) * 0.25 } });
  assert.equal(entretenu.accueil, 3); assert.equal(entretenu.degrade, false);
  assert.deepEqual(entretenu.cagnotte, { installations: 12, staff: 34, accueil: 56 }, 'cagnottes reportées');
  assert.deepEqual(entretenu.depense, { installations: 0, staff: 0, accueil: 0 }); assert.deepEqual(entretenu.gains, {});
  const delaisse = nouveau({ cagnotte: {}, accueil: 3, depense: { accueil: I.coutAccueil(2) * 0.25 - 1 } });
  assert.equal(delaisse.accueil, 2); assert.equal(delaisse.degrade, true);
  const sans = nouveau({ cagnotte: {}, accueil: 3, depense: {} }, { montant: 0 });
  assert.equal(sans.accueil, 2, 'un club sans excédent laisse l’accueil reculer'); assert.equal(sans.montant, 0);
  assert.equal(nouveau({ cagnotte: {}, accueil: 0, depense: {} }).accueil, 0, 'jamais sous 0');
  assert.equal(nouveau(null).accueil, 0); assert.equal(nouveau({ accueil: 'x' }).accueil, 0);
});

test('facteurAccueil : 1 à 1,125, borné', () => {
  assert.equal(I.facteurAccueil(0), 1); assert.equal(I.facteurAccueil(1), 1.025);
  assert.ok(Math.abs(I.facteurAccueil(4) - 1.1) < 1e-12); assert.ok(Math.abs(I.facteurAccueil(5) - 1.125) < 1e-12);
  assert.equal(I.facteurAccueil(9), I.facteurAccueil(5)); assert.equal(I.facteurAccueil(-3), 1);
  for (const x of [undefined, null, NaN, '3', 2.5]) assert.equal(I.facteurAccueil(x), 1, String(x));
});

test('Orienter et courrier : parts mises à jour, orientation inconnue refusée, vars lisibles', () => {
  const p = unPlan(); assert.equal(p.orientation, null);
  const parts = I.orienter(p, 'staff', { installations: 2, staffDisponible: true });
  assert.deepEqual(parts, I.ORIENTATIONS.staff); assert.equal(p.orientation, 'staff'); assert.ok(p.parts.staff >= 0.6);
  assert.throws(() => I.orienter(p, 'nimporte', { installations: 2, staffDisponible: true }), /inconnue/);
  assert.throws(() => I.orienter(p, 'toString', { installations: 2, staffDisponible: true }), /inconnue/);
  const v = I.courrier(unPlan(), { installations: 2, saison: 3 });
  for (const val of Object.values(v)) assert.doesNotMatch(String(val), /undefined|NaN|Infinity|\{|\}/);
  assert.match(v.montant, /10 000 000 €/);
  assert.match(I.courrier(unPlan({ installations: 10 }), { installations: 10, saison: 3 }).travaux, /plus haut niveau/);
});

test('Résumé pour Club > Infrastructures : avancement des travaux et de l’accueil, dépense bornée, staff', () => {
  const p = unPlan();
  const vide = I.resume(p, { installations: 2 });
  assert.equal(vide.depense, 0); assert.equal(vide.installations.devis, I.coutInstallations(2)); assert.equal(vide.installations.avancement, 0);
  assert.equal(vide.accueil.niveau, 0); assert.equal(vide.accueil.effet, 0); assert.equal(vide.staff.points, 0);
  const staff = [{ id: 'a', role: 'coach', level: 50 }, { id: 'b', role: 'scout', level: 60 }];
  for (let w = 0; w < 10; w++) I.semaine(p, 250000, { installations: 2, staff });
  const r = I.resume(p, { installations: 2 });
  assert.equal(r.depense, 2500000); assert.ok(r.installations.avancement >= 0 && r.installations.avancement <= 1);
  assert.ok(r.accueil.niveau > 0 && r.accueil.effet > 0); assert.equal(r.staff.personnes, 2); assert.ok(r.staff.points > 0 && r.staff.points <= 6);
  assert.equal(I.resume(p, { installations: 10 }).installations.devis, null);
  assert.equal(I.resume(p, { installations: 10 }).installations.avancement, 1);
  for (const v of JSON.stringify(r).match(/-?\d+(\.\d+)?/g)) assert.ok(Number.isFinite(Number(v)));
});

// --- Budget ---
const forces = [...Array.from({ length: 14 }, (_, i) => ({ id: i, division: 'elite', base: 70 + i })), ...Array.from({ length: 16 }, (_, i) => ({ id: 14 + i, division: 'accession', base: 60 + i }))];
test('Budget de club : l’accueil relève seulement billetterie et boutique d’un match à domicile', () => {
  const base = { forces, clubId: 3, masseHebdo: 150000, semaines: 34, alea: 0.5, libelle: 'S', investissement: 1234567 };
  const hors = e => e.filter(x => !/Billetterie|Boutique/.test(x.title));
  const total = e => e.reduce((s, x) => s + x.amount, 0), ligne = (e, re) => e.find(x => re.test(x.title)).amount;
  for (const phase of ['league', 'knockout']) {
    const un = B.semaine({ ...base, domicile: true, phase, accueil: 1 }), quatre = B.semaine({ ...base, domicile: true, phase, accueil: I.facteurAccueil(4) });
    assert.ok(ligne(quatre, /Billetterie/) > ligne(un, /Billetterie/), phase + ' billetterie');
    assert.ok(ligne(quatre, /Boutique/) > ligne(un, /Boutique/), phase + ' boutique');
    assert.ok(ligne(quatre, /Boutique/) / ligne(un, /Boutique/) < 1.11, 'boutique : effet de 10 % au plus');
    assert.deepEqual(hors(quatre), hors(un), 'les autres écritures sont identiques');
    assert.equal(total(hors(quatre)), total(hors(un)));
    assert.ok(quatre.some(x => /Investissements/.test(x.title)));
  }
  const defaut = B.semaine({ ...base, domicile: true }), explicite = B.semaine({ ...base, domicile: true, accueil: 1 });
  assert.deepEqual(defaut, explicite, 'accueil omis = 1');
  for (const x of [0, -2, NaN, 'a']) assert.deepEqual(B.semaine({ ...base, domicile: true, accueil: x }), defaut, 'accueil invalide : ' + String(x));
  // Match à l'extérieur : rien à relever.
  assert.deepEqual(B.semaine({ ...base, domicile: false, accueil: 1.125 }), B.semaine({ ...base, domicile: false, accueil: 1 }));
});

// --- Moteur (carrière Monde `world-champ`, graine fixe) ---
test('Moteur Monde : trois lignes pour un montant, chantiers aboutis, trésorerie inchangée hors accueil', { timeout: 170000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = creer(jeu, 0);
    const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
    // 0. Création : rien à investir, carrière Monde au budget réaliste.
    assert.equal(lire('S.clubInvest&&S.clubInvest.clubs.length===S.clubs.length'), true);
    assert.equal(lire('S.clubInvest.clubs.filter(p=>p.montant>0).length'), 0);
    assert.equal(lire('investCourrier()'), null);
    // 1. Nouvelle saison forcée : tous les clubs sont riches (réserve + 30 M€) ; la saison d'investissements est rouverte.
    const ouv = lire(`(()=>{S.clubInvest.saison=0;for(const c of S.clubs)c.cash=S.clubBudget.clubs[c.id].reserve+30e6;budgetOuvrir(true,true);
      const b=S.clubBudget.clubs,e=S.clubInvest;return {saison:e.saison===S.season,semaines:wageForecastWeeks(),
       egal:e.clubs.every((p,i)=>p.montant===b[i].investissement),plus:e.clubs.filter(p=>p.montant>0).length,n:S.clubs.length,
       montant:e.clubs[S.club].montant,fac:worldClub(S.club).facilities,acc:e.clubs[S.club].accueil,
       parts:e.clubs[S.club].parts,type:b[S.club].type,valide:nativeClubInvestments.valide(e,S.clubs.length)};})()`);
    assert.equal(ouv.saison, true); assert.equal(ouv.valide, true);
    assert.equal(ouv.egal, true, 'montant = investissement de #870 pour chaque club');
    assert.equal(ouv.plus, ouv.n, 'tous les clubs riches réinvestissent'); assert.ok(ouv.montant > 0);
    assert.ok(Math.abs(somme(ouv.parts) - 1) < 1e-9);
    // 2. Une vraie semaine de jeu : le grand livre montre trois lignes dont la somme est l'ancien montant unique.
    const avant = lire('({ledger:S.ledger.length,cash:club().cash,fac:worldClub(S.club).facilities})');
    model = jusquAuMatch(jeu, model); model = jouerLeMatch(jeu, model);
    const lignes = lire(`S.ledger.filter(e=>/Investissements/.test(e.title||e.label||JSON.stringify(e))).map(e=>({t:e.title||e.label,a:e.amount}))`);
    // Une semaine = un préfixe de libellé ; chaque semaine porte les trois lignes et leur somme est l'ancien montant unique de #870.
    const semaines = {}; for (const l of lignes) { const [pre, part] = l.t.split(' · Investissements : '); (semaines[pre] ??= {})[part] = l.a; }
    assert.ok(Object.keys(semaines).length >= 1, JSON.stringify(lignes));
    for (const [pre, parts] of Object.entries(semaines)) {
      assert.deepEqual(Object.keys(parts).sort(), ['accueil et billetterie', 'installations', 'staff'], pre);
      assert.equal(somme(parts), -Math.round(ouv.montant / ouv.semaines / 100) * 100, pre + ' : même dépense que #870');
    }
    assert.ok(!lire(`S.ledger.some(e=>/excédents réinvestis/.test(JSON.stringify(e)))`), 'plus de ligne unique');
    // 3. Semaines simulées (budgetSemaine du moteur) : club joué et clubs gérés, une saison entière.
    // Pour chaque semaine du club joué : même semaine sans investissement d'accueil (comparaison à #870) ; seules billetterie
    // et boutique peuvent différer, et uniquement à la hausse.
    const sim = lire(`(()=>{const forces=budgetForces(),repere=budgetRepere(),c=club(),e=S.clubInvest,p=e.clubs[c.id],autre=S.clubs.find(x=>x.id!==c.id).id;
      const depart={cash:c.cash,fac:worldClub(c.id).facilities,acc:p.accueil,niv:investStaff(c.id).map(x=>x.level)};
      const gerees=S.clubs.filter(x=>x.id!==c.id).slice(0,40).map(x=>x.id);
      const avantGeres=gerees.map(id=>({id,fac:worldClub(id).facilities,niv:investStaff(id).reduce((s,x)=>s+x.level,0),cash:S.clubs[id].cash}));
      let ecartAutres=0,ecartRecettes=0,pires=0,depenses=0,attendu=0,cashJoue=0,cashBase=0,maxLignes=0;
      const total=l=>l.reduce((s,x)=>s+x.amount,0),hors=l=>l.filter(x=>!/Billetterie|Boutique|Investissements|Frais de match/.test(x.title)).map(x=>[x.title,x.amount]);
      for(let w=0;w<${ouv.semaines};w++){
        const rc={pair:w%2?[c.id,autre]:[autre,c.id],neutral:false,phase:'league'};
        // Les frais de match (recettes imprévues) se cumulent dans le compteur : la semaine de comparaison ne doit pas les compter deux fois.
        const cpt=S.clubBudget.clubs[c.id],f0=[cpt.imprevu,cpt.fraisMatch];
        const k=[p.accueil,e.saison];e.saison=-1;p.accueil=0;const base=budgetSemaine(forces,repere,c,rc,'S');e.saison=k[1];p.accueil=k[0];[cpt.imprevu,cpt.fraisMatch]=f0;
        const reel=budgetSemaine(forces,repere,c,rc,'S');
        maxLignes=Math.max(maxLignes,reel.filter(x=>/Investissements/.test(x.title)).length);
        if(JSON.stringify(hors(base))!==JSON.stringify(hors(reel)))ecartAutres++;
        const inv=l=>total(l.filter(x=>/Investissements/.test(x.title))),rec=l=>total(l.filter(x=>/Billetterie|Boutique/.test(x.title)));
        if(inv(base)!==inv(reel))pires++;
        if(rec(reel)<rec(base))ecartRecettes++;
        depenses+=inv(reel);attendu+=inv(base);cashJoue+=total(reel);cashBase+=total(base);
        for(const id of gerees)budgetSemaine(forces,repere,S.clubs[id],null,'');
      }
      const joue={fac:worldClub(c.id).facilities,acc:p.accueil,niv:investStaff(c.id).map(x=>x.level),travaux:p.travaux,points:p.points,depense:p.depense,
       cagnotte:p.cagnotte,gains:p.gains};
      const geres=gerees.map((id,i)=>({id,fac:worldClub(id).facilities-avantGeres[i].fac,niv:investStaff(id).reduce((s,x)=>s+x.level,0)-avantGeres[i].niv,
       depense:somme(S.clubInvest.clubs[id].depense),montant:S.clubInvest.clubs[id].montant,travaux:S.clubInvest.clubs[id].travaux}));
      function somme(o){return o.installations+o.staff+o.accueil;}
      return {depart,joue,ecartAutres,ecartRecettes,pires,depenses,attendu,cashJoue,cashBase,maxLignes,geres,
       upgrades:S.worldManagement.upgrades.filter(x=>x.source==='excedents').length,valide:nativeClubInvestments.valide(S.clubInvest,S.clubs.length),
       lim:[...S.clubInvest.clubs[c.id].parts?[]:[]]};})()`);
    assert.equal(sim.maxLignes, 3);
    assert.equal(sim.ecartAutres, 0, 'les autres écritures sont celles de #870');
    assert.equal(sim.pires, 0, 'même dépense d’investissement chaque semaine');
    assert.equal(sim.depenses, sim.attendu, 'dépense totale inchangée');
    assert.equal(sim.ecartRecettes, 0, 'l’accueil ne réduit jamais les recettes');
    assert.ok(sim.cashJoue >= sim.cashBase, 'trésorerie : pas moins que #870');
    assert.ok(sim.cashJoue - sim.cashBase <= (sim.cashJoue + Math.abs(sim.depenses)) * 0.2, 'gain d’accueil modeste (≤ 12,5 % des recettes de match)');
    assert.equal(sim.valide, true);
    // Chantiers aboutis : installations et/ou staff du club joué ; le mécanisme est aussi à l'œuvre chez les clubs gérés.
    assert.ok(sim.joue.fac > sim.depart.fac || sim.joue.niv.some((n, i) => n > sim.depart.niv[i]), 'un chantier a abouti chez le club joué');
    assert.ok(sim.joue.fac >= sim.depart.fac);
    assert.ok(sim.joue.acc > sim.depart.acc, 'l’accueil monte');
    assert.ok(sim.joue.niv.every((n, i) => n >= sim.depart.niv[i] && n <= 85), 'niveaux de staff ≤ 85, jamais en baisse');
    for (const [id, g] of Object.entries(sim.joue.gains)) assert.ok(g <= 3, 'au plus 3 points par personne : ' + id);
    assert.ok(sim.joue.depense.installations + sim.joue.depense.staff + sim.joue.depense.accueil >= -sim.depenses, "la dépense suivie par club couvre les semaines simulées");
    assert.ok(sim.geres.some(g => g.fac > 0 || g.niv > 0), 'des clubs gérés progressent aussi');
    assert.ok(sim.geres.every(g => g.fac >= 0 && g.niv >= 0 && g.fac <= 8));
    assert.equal(sim.upgrades, 0, 'aucune entrée « achat du manager » créée par les travaux du président');
    // La carrière reste valide après des niveaux de staff relevés (staff-career.cjs validate) : le jeu continue.
    model = jusquAuMatch(jeu, model); model = jouerLeMatch(jeu, model);
    // La carrière reste sauvegardable : état valide après la saison simulée.
    assert.equal(lire('nativeClubInvestments.valide(S.clubInvest,S.clubs.length)'), true);
  } finally { jeu.fermer(); }
});

test('Moteur Monde : un chantier d’installations du président ne bloque pas l’achat du manager', { timeout: 120000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 0);
    const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
    const r = lire(`(()=>{const c=club(),e=S.clubInvest,p=e.clubs[c.id],info=worldClub(c.id);
      p.montant=5e7;p.parts={installations:1,staff:0,accueil:0};p.saison=S.season;
      const forces=budgetForces(),repere=budgetRepere();S.clubBudget.clubs[c.id].investissement=5e7;
      const f0=info.facilities;
      for(let w=0;w<8&&info.facilities===f0;w++)budgetSemaine(forces,repere,c,null,'S');
      const gagne=info.facilities-f0;
      return {gagne,bloque:S.worldManagement.upgrades.some(x=>x.season===S.season&&x.id===S.club)};})()`);
    assert.ok(r.gagne >= 1, 'les travaux ont abouti');
    assert.equal(r.bloque, false, 'l’achat du manager (une fois par saison) reste possible');
  } finally { jeu.fermer(); }
});

// --- Courrier du président ---
test('Courrier : une seule fois par saison, une orientation, la seconde refusée', { timeout: 170000 }, () => {
  const jeu = ouvrir({ testVm: true });
  try {
    creer(jeu, 0);
    const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
    const recevoir = (jours, fin = jours) => lire(`(()=>{const D=nativeSystems.domain('clubMail'),d=CDWorldCareer.calendarToday(S),
      sh=(x,n)=>new Date(Date.parse(x+'T00:00:00Z')+n*864e5).toISOString().slice(0,10);for(let i=${jours};i<=${fin};i+=5)D.recevoir(S,sh(d,i));
      return S.clubMail.mails.filter(x=>x.type==='investissements').map(x=>({id:x.id,date:x.date,status:x.status}));})()`);
    // Sans excédent (création) : pas de courrier.
    assert.equal(lire('investCourrier()'), null);
    assert.deepEqual(recevoir(0, 3), []);
    // Excédent : le courrier arrive.
    run(`(()=>{S.clubInvest.saison=0;club().cash=S.clubBudget.clubs[S.club].reserve+30e6;budgetOuvrir(true,true);})()`);
    const v = lire('investCourrier()'); assert.ok(v && /€/.test(v.montant));
    // Écran Club > Infrastructures : le même état passe dans le modèle (finance.investissements) envoyé à Godot.
    const vu = jeu.call('snapshot').clubLife.clubStrategy.finance.investissements;
    assert.ok(vu && vu.montant === lire('S.clubInvest.clubs[S.club].montant') && vu.montant > 0, JSON.stringify(vu));
    assert.equal(vu.installations.niveau, lire('worldClub(S.club).facilities'));
    let mails = recevoir(1, 2);
    assert.equal(mails.length, 1, 'le courrier arrive'); assert.equal(mails[0].status, 'nouveau');
    // Une seule fois dans la saison, même sans réponse, au-delà de la mémoire des sujets (150 jours).
    mails = recevoir(3, 320);
    assert.equal(mails.length, 1, 'une fois par saison : ' + JSON.stringify(mails));
    const id = mails[0].id;
    run(`S.clubMail.mails.find(x=>x.id==='${id}').status='nouveau'`); // classé après 7 jours : rouvert pour la réponse
    const sain = lire(`(()=>{const m=S.clubMail.mails.find(x=>x.id==='${id}');return {m:m.status,corps:JSON.stringify(m.vars)}})()`);
    assert.doesNotMatch(sain.corps, /undefined|NaN/);
    // Réponse « staff » : parts majoritaires au staff.
    const avant = lire('S.clubInvest.clubs[S.club].parts');
    const r = jeu.brut('club_mail_reply', { id, choice: 'staff' });
    assert.equal(r.ok, true, r.error);
    const apres = lire('S.clubInvest.clubs[S.club]');
    assert.equal(apres.orientation, 'staff'); assert.ok(apres.parts.staff >= 0.6 && apres.parts.staff > apres.parts.installations && apres.parts.staff > apres.parts.accueil);
    assert.notDeepEqual(apres.parts, avant); assert.equal(lire('investCourrier()'), null, 'orientation donnée : plus de courrier');
    assert.match(jeu.brut('club_mail_reply', { id, choice: 'accueil' }).error, /déjà répondu/);
    // Une seconde orientation (second courrier injecté) est refusée, les parts ne bougent pas.
    run(`(()=>{const m=JSON.parse(JSON.stringify(S.clubMail.mails.find(x=>x.id==='${id}')));m.id='mail-test-2';m.status='nouveau';m.choice=null;S.clubMail.mails.push(m);})()`);
    const r2 = jeu.brut('club_mail_reply', { id: 'mail-test-2', choice: 'installations' });
    assert.equal(r2.ok, false); assert.match(r2.error, /déjà arrêtée/);
    assert.deepEqual(lire('S.clubInvest.clubs[S.club].parts'), apres.parts); assert.equal(lire('S.clubInvest.clubs[S.club].orientation'), 'staff');
    // Les semaines restantes suivent la nouvelle répartition.
    const t = lire(`(()=>{const forces=budgetForces(),repere=budgetRepere(),e=ecr=>ecr.filter(x=>/Investissements/.test(x.title));
      const l=e(budgetSemaine(forces,repere,club(),null,'S'));const s=l.reduce((a,x)=>a+x.amount,0);
      const st=l.find(x=>/staff/.test(x.title));return {n:l.length,part:st.amount/s};})()`);
    assert.ok(t.part >= 0.55, 'part du staff : ' + t.part);
    // Accueil/installations : orienter sans excédent est refusé (courrier absent).
    assert.equal(lire(`(()=>{S.clubInvest.clubs[S.club].montant=0;return investOrienter('staff');})()`), false);
  } finally { jeu.fermer(); }
});
