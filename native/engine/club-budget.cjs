'use strict';
// Budget hebdomadaire d'un club pour les carrières créées avec les salaires
// de départ réalistes (state.startingSalaries). Les autres carrières gardent
// l'ancien calcul.
//
// Modèle : comptes cumulés des clubs professionnels, saison 2024-2025.
//   Recettes moyennes par club : 33 M€ en première division, 10,7 M€ en deuxième.
//   Première division : partenaires 45 %, ligue 19 %, billetterie 16 %,
//     boutique et buvettes 8 %, subventions et divers 12 %.
//   Deuxième division : partenaires 48 %, ligue 22 %, billetterie 8 %,
//     boutique 4 %, subventions et divers 18 %.
//   Charges : les joueurs pèsent environ 27 % ; les cotisations représentent
//     40 % des salaires ; le reste (staff, administratifs, achats, services,
//     amortissements) fait un peu moins de 60 % des recettes.
// Les salaires sont dus sur 52 semaines : chaque semaine de compétition en paie 52 / n.
const DIVISIONS = Object.freeze({
  elite: Object.freeze({ moyenne: 33e6, bas: 0.7, haut: 1.5, partenaires: 0.45, ligue: 0.19, billetterie: 0.16, boutique: 0.08, divers: 0.12 }),
  accession: Object.freeze({ moyenne: 10.7e6, bas: 0.62, haut: 1.55, partenaires: 0.48, ligue: 0.22, billetterie: 0.08, boutique: 0.04, divers: 0.18 }),
});
const COTISATIONS = 0.4;
const FONCTIONNEMENT = 0.58;

// forces : [{id, division, base}] ; renvoie les recettes annuelles visées par club.
function recettes(forces) {
  const resultat = new Map();
  for (const [division, regle] of Object.entries(DIVISIONS)) {
    const groupe = forces.filter(club => club.division === division);
    if (!groupe.length) continue;
    const min = Math.min(...groupe.map(club => club.base)), max = Math.max(...groupe.map(club => club.base));
    const brut = groupe.map(club => regle.bas + (regle.haut - regle.bas) * (max === min ? 0.5 : (club.base - min) / (max - min)));
    const correction = groupe.length / brut.reduce((somme, valeur) => somme + valeur, 0);
    groupe.forEach((club, i) => resultat.set(club.id, regle.moyenne * brut[i] * correction));
  }
  return resultat;
}

// Écritures d'une semaine de compétition. alea est dans [0;1].
function semaine({ forces, clubId, masseHebdo, semaines, domicile, alea, libelle }) {
  const force = forces.find(club => club.id === clubId), regle = force && DIVISIONS[force.division];
  if (!regle) throw Error('Budget de club : division inconnue.');
  if (!Number.isInteger(semaines) || semaines < 1) throw Error('Budget de club : nombre de semaines invalide.');
  const annuel = recettes(forces).get(clubId), rond = montant => Math.round(montant / 100) * 100;
  const salaires = rond(masseHebdo * 52 / semaines), receptions = Math.max(1, Math.round(semaines / 2));
  const ecritures = [
    { title: libelle + ' · Partenaires', amount: rond(annuel * regle.partenaires / semaines) },
    { title: libelle + ' · Versement de la ligue', amount: rond(annuel * regle.ligue / semaines) },
    { title: libelle + ' · Subventions et divers', amount: rond(annuel * regle.divers / semaines) },
  ];
  if (domicile) {
    ecritures.push({ title: libelle + ' · Billetterie', amount: rond(annuel * regle.billetterie / receptions * (0.85 + 0.3 * alea)) });
    ecritures.push({ title: libelle + ' · Boutique et buvettes', amount: rond(annuel * regle.boutique / receptions * (0.9 + 0.2 * alea)) });
  }
  ecritures.push({ title: libelle + ' · Salaires des joueurs', amount: -salaires });
  ecritures.push({ title: libelle + ' · Cotisations', amount: -rond(salaires * COTISATIONS) });
  ecritures.push({ title: libelle + ' · Staff et fonctionnement', amount: -rond(annuel * FONCTIONNEMENT / semaines) });
  return ecritures;
}

module.exports = Object.freeze({ DIVISIONS, COTISATIONS, FONCTIONNEMENT, recettes, semaine });
