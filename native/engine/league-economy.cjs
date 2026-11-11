'use strict';
// Économie et réputation de chaque championnat de la base.
//
// masse      : masse salariale moyenne des joueurs d'un club, par an, en euros.
// recettes   : recettes moyennes d'un club, par an, en euros.
// bas, haut  : écart entre le club le plus modeste et le plus riche, en part de la moyenne.
// parts      : d'où viennent les recettes (total 1).
// plafond    : plafond salarial de la ligue, en euros, ou null.
// ratio      : la ligue limite-t-elle les salaires à 52 % des recettes (règle française).
// reputation : attrait sportif aux yeux des joueurs, 100 pour le championnat de référence.
// pays       : zone du championnat, pour les joueurs qui tiennent à rester chez eux.
// source     : 'relevé' quand le chiffre vient d'une publication, 'estimation' sinon
//              (détail et liens dans docs/salaires-par-niveau-20261111.md).
const parts = (partenaires, ligue, billetterie, boutique, divers) => Object.freeze({ partenaires, ligue, billetterie, boutique, divers });
const CHAMPIONNATS = Object.freeze({
  elite: Object.freeze({ libelle: 'Première division française', pays: 'france', reputation: 100, masse: 9.9e6, recettes: 33e6, bas: 0.7, haut: 1.5, ...parts(0.45, 0.19, 0.16, 0.08, 0.12), plafond: 10.7e6, ratio: true, espoir: 'elite', source: 'relevé' }),
  prem: Object.freeze({ libelle: 'Première division anglaise', pays: 'angleterre', reputation: 92, masse: 6.9e6, recettes: 23e6, bas: 0.75, haut: 1.35, ...parts(0.36, 0.24, 0.22, 0.08, 0.10), plafond: 7.5e6, ratio: false, espoir: 'elite', source: 'plafond relevé, masse et recettes estimées' }),
  urc: Object.freeze({ libelle: 'Championnat celte, italien et sud-africain', pays: 'celte', reputation: 90, masse: 5.4e6, recettes: 18e6, bas: 0.5, haut: 1.9, ...parts(0.30, 0.40, 0.18, 0.05, 0.07), plafond: null, ratio: false, espoir: 'elite', source: 'estimation à partir de trois repères' }),
  srp: Object.freeze({ libelle: 'Championnat du Pacifique', pays: 'pacifique', reputation: 86, masse: 2.3e6, recettes: 7.6e6, bas: 0.8, haut: 1.25, ...parts(0.28, 0.45, 0.15, 0.05, 0.07), plafond: 2.6e6, ratio: false, espoir: 'accession', source: 'plafond et salaire moyen relevés, recettes estimées' }),
  'jlo-d1': Object.freeze({ libelle: 'Première division japonaise', pays: 'japon', reputation: 78, masse: 6.0e6, recettes: 20e6, bas: 0.7, haut: 1.5, ...parts(0.70, 0.08, 0.10, 0.04, 0.08), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
  accession: Object.freeze({ libelle: 'Deuxième division française', pays: 'france', reputation: 70, masse: 3.2e6, recettes: 10.7e6, bas: 0.62, haut: 1.55, ...parts(0.48, 0.22, 0.08, 0.04, 0.18), plafond: null, ratio: true, espoir: 'accession', source: 'relevé' }),
  guest: Object.freeze({ libelle: 'Clubs invités', pays: 'autre', reputation: 70, masse: 4.0e6, recettes: 13e6, bas: 0.9, haut: 1.1, ...parts(0.40, 0.25, 0.18, 0.06, 0.11), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
  'jlo-d2': Object.freeze({ libelle: 'Deuxième division japonaise', pays: 'japon', reputation: 52, masse: 2.0e6, recettes: 6.6e6, bas: 0.7, haut: 1.4, ...parts(0.72, 0.06, 0.08, 0.04, 0.10), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
  nationale: Object.freeze({ libelle: 'Troisième division française', pays: 'france', reputation: 50, masse: 1.4e6, recettes: 4.6e6, bas: 0.6, haut: 1.6, ...parts(0.50, 0.10, 0.08, 0.04, 0.28), plafond: null, ratio: true, espoir: 'accession', source: 'estimation à partir d’une fourchette de salaires relevée' }),
  champ: Object.freeze({ libelle: 'Deuxième division anglaise', pays: 'angleterre', reputation: 48, masse: 1.1e6, recettes: 3.6e6, bas: 0.7, haut: 1.5, ...parts(0.50, 0.06, 0.18, 0.10, 0.16), plafond: null, ratio: false, espoir: 'accession', source: 'salaire moyen relevé, recettes estimées' }),
});
// Seuls ces deux championnats gardent les salaires bruts de la règle : elle a été réglée sur eux.
const REFERENCES = Object.freeze(['elite', 'accession']);

// Tirage stable dans [0;1[ à partir d'un texte.
function unite(texte) {
  let h = 2166136261;
  for (let i = 0; i < texte.length; i++) { h ^= texte.charCodeAt(i); h = Math.imul(h, 16777619); }
  h ^= h >>> 15; h = Math.imul(h, 2246822507); h ^= h >>> 13;
  return (h >>> 0) / 4294967296;
}

// Tempérament d'un joueur face à un départ : il ne dépend que de son identité, jamais de son niveau.
//   casanier    : attaché à son pays, demande plus pour le quitter ;
//   voyageur    : curieux d'un autre rugby, demande un peu moins pour partir ;
//   ambitieux   : le prestige du championnat compte beaucoup pour lui ;
//   pragmatique : le prestige compte peu, il regarde le projet et le contrat.
function temperament(joueurId) {
  const tirage = unite('temperament|' + joueurId);
  return tirage < 0.2 ? 'casanier' : tirage < 0.35 ? 'voyageur' : tirage < 0.5 ? 'ambitieux' : tirage < 0.7 ? 'pragmatique' : 'neutre';
}
const POIDS_PRESTIGE = Object.freeze({ ambitieux: 1.35, pragmatique: 0.35 });
// Prime demandée pour descendre : faible entre championnats proches, forte quand l'écart se creuse
// (30 points d'écart, de la première à la deuxième division française : +30 % pour un joueur ordinaire).
const primeDescente = ecart => Math.min(0.55, 0.3 * (ecart / 30) ** 1.6);
// Rabais consenti pour monter : jusqu'à 10 %.
const rabaisMontee = ecart => Math.min(0.1, 0.1 * (ecart / 30) ** 1.2);

// Ce que l'attrait d'un championnat change au salaire qu'un joueur demande pour y signer.
// Renvoie un multiplicateur (1 = aucun effet) et ses raisons, sans rien dire du niveau du joueur.
//   origine : championnat que le joueur quitte (null si inconnu) ; destination : celui du club qui recrute ;
//   situation, tout ce que le club sait déjà du joueur :
//     sansClub     : saisons passées sans club (0 s'il vient d'être libéré) ;
//     peuUtilise   : il a peu joué la saison passée ;
//     ancienClub   : le club qui recrute l'a formé ou l'a déjà eu sous contrat.
function attrait({ origine = null, destination, joueurId, age, situation = null }) {
  const vers = CHAMPIONNATS[destination], depuis = origine ? CHAMPIONNATS[origine] : null;
  if (!vers) throw Error('Attrait : championnat inconnu.');
  const profil = temperament(String(joueurId)), poids = POIDS_PRESTIGE[profil] ?? 1, raisons = [];
  let taux = 0;
  if (depuis && depuis !== vers) {
    const ecart = vers.reputation - depuis.reputation;
    if (ecart > 0) { taux -= rabaisMontee(ecart) * poids; raisons.push('championnat plus réputé'); }
    else if (ecart < 0) {
      // Un joueur qui a peu joué descend plus volontiers : il cherche du temps de jeu.
      taux += primeDescente(-ecart) * poids * (situation?.peuUtilise ? 0.6 : 1);
      raisons.push('championnat moins réputé');
      if (situation?.peuUtilise) raisons.push('cherche du temps de jeu');
    }
    if (vers.pays !== depuis.pays) {
      if (profil === 'casanier') { taux += 0.08; raisons.push('attaché à son pays'); }
      else if (profil === 'voyageur') { taux -= 0.04; raisons.push('envie de découvrir un autre rugby'); }
    }
    // Le Japon : loin de tout pour un joueur en pleine carrière, très séduisant pour finir la sienne.
    if (vers.pays === 'japon' && depuis.pays !== 'japon' && Number.isFinite(age)) {
      if (age >= 31) { taux = Math.min(taux, 0) - (age >= 33 ? 0.12 : 0.08); raisons.push('fin de carrière au Japon'); }
      else if (age <= 29) { taux += 0.06; raisons.push('loin de chez lui en pleine carrière'); }
    }
  } else if (!depuis && vers.reputation >= 95 && profil === 'ambitieux') { taux -= 0.03; raisons.push('rêve du meilleur championnat'); }
  if (situation?.sansClub > 0) { taux -= Math.min(0.1, 0.05 * situation.sansClub); raisons.push('sans club depuis une saison ou plus'); }
  if (situation?.ancienClub) { taux -= 0.06; raisons.push('retour dans un club qu’il connaît'); }
  // Chaque joueur a son idée : sept points d'écart au plus, dans un sens ou dans l'autre.
  taux += (unite('humeur|' + joueurId + '|' + destination) - 0.5) * 0.14;
  return { multiplicateur: Math.max(0.82, Math.min(1.6, 1 + taux)), profil, raisons };
}

// Nom du dernier club d'un joueur libre, tel que le jeu l'écrit à sa libération (« Club » ou « Club · centre de formation »).
const dernierClub = joueur => typeof joueur?.formerClub === 'string' ? joueur.formerClub.split(' · ')[0] : null;

// Ce que le club sait d'un joueur du marché, pour l'attrait : rien ici ne touche à son niveau.
//   saison : saison en cours ; clubId, nomClub : club qui recrute.
function situation(joueur, saison, clubId, nomClub = null) {
  const depuis = joueur?.population?.availableSince, passee = joueur?.dev?.history?.at?.(-1), forme = /^youth-(\d+)-/.exec(String(joueur?.id ?? ''))?.[1];
  return {
    sansClub: Number.isInteger(depuis) && Number.isInteger(saison) && joueur?.population?.origin === 'released' ? Math.max(0, saison - depuis) : 0,
    peuUtilise: !!passee && Number.isFinite(passee.minutes) && passee.minutes < 480,
    ancienClub: Number.isInteger(clubId) && (joueur?.population?.clubId === clubId || (forme !== undefined && Number(forme) === clubId) || (nomClub !== null && dernierClub(joueur) === nomClub)),
  };
}

// Championnat d'origine d'un joueur du marché, d'après ce que la base sait de lui : son dernier club
// (identifiant, sinon nom), sinon son identifiant dans la base, sinon inconnu.
//   ligueDuClub : fonction (identifiant de club) -> championnat ; ligueDuNom : fonction (nom de club) -> championnat.
function origine(joueur, ligueDuClub, ligueDuNom = null) {
  const club = joueur?.population?.clubId;
  if (Number.isInteger(club)) return ligueDuClub(club) ?? null;
  const nom = dernierClub(joueur), parNom = nom && ligueDuNom ? ligueDuNom(nom) : null;
  if (parNom) return parNom;
  const prefixe = /^world:([a-z]+)[:-]/.exec(String(joueur?.id ?? ''))?.[1];
  if (prefixe === 'jlo') return 'jlo-d1';
  return prefixe && Object.hasOwn(CHAMPIONNATS, prefixe) ? prefixe : null;
}

module.exports = Object.freeze({ CHAMPIONNATS, REFERENCES, temperament, attrait, situation, origine, dernierClub, primeDescente, rabaisMontee, unite });
