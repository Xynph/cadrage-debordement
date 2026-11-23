'use strict';
// Économie et réputation de chaque championnat de la base.
//
// masse      : masse salariale moyenne des joueurs d'un club, par an, en euros.
// recettes   : recettes moyennes d'un club, par an, en euros.
// bas, haut  : écart entre le club le plus modeste et le plus riche, en part de la moyenne.
// parts      : d'où viennent les recettes (total 1).
// plafond    : plafond salarial de la ligue, en euros, ou null.
// ratio      : la ligue limite-t-elle les salaires à 52 % des recettes (règle française).
// encadrement: le contrôle de gestion encadre la masse salariale : un club ne prévoit que les pertes que son
//              propriétaire comblera, sans compter sur des économies de fonctionnement en cours de saison
//              (deuxième division française sous la DNACG de la LNR, troisième sous celle de la FFR ; voir
//              club-budget.cjs, limites).
// reserve    : réserve de trésorerie propre au championnat ({min, ecart} en part des recettes), sinon la règle générale.
// prudence   : part des recettes que la masse encadrée laisse aux dépenses de la saison non votées (recrues, jokers).
// gestion    : championnat encadré seulement : résultat que vise le budget de chaque club, selon son propriétaire.
//              association : excédent de min à min + ecart des recettes (le « bon élève » qui reconstitue ses fonds propres) ;
//              entreprise, mécène : part de l'enveloppe du propriétaire que le club s'autorise à perdre (min à min + ecart).
//              Propre à chaque club et stable d'une saison à l'autre (voir club-budget.cjs, cibleGestion).
// engagementMax : part des recettes qu'un club engage au plus par saison sur sa trésorerie au-delà de sa réserve
//              (investissements et dividende) ; le reste attend les saisons suivantes. Sinon, sans limite.
//
// Troisième division française (Nationale), repères réels (A2R, rapport statistiques 2023-2024, bilans 2022-2023,
// 14 clubs) : budget moyen 3,73 M€ (1,66 à 6,68 ; prévisionnel 2023-2024 : 3,85 M€) ; salaires bruts des joueurs
// 1,11 M€ en moyenne (0,33 à 1,93), soit 30 % des produits ; résultat moyen -0,36 M€, le meilleur à +0,02 M€ ;
// situation nette moyenne 0,54 M€ ; produits : partenariat 30 %, mécénat 27 %, subventions 17 %, autres 26 %
// (matchs, indemnités kilométriques de la FFR). Le jeu garde 30 % de salaires dans les recettes (1,4 / 4,6 M€,
// niveaux de 2026-2027). Encadrement et réserve (suite de #885) : sans eux, chaque club visait ~41 % de ses
// recettes en salaires et la trésorerie de départ (2,6 M€ partout, paramètre fictif : 43 à 115 % des recettes)
// était engagée d'un coup en deuxième saison ; 14 clubs sur 14 finissaient dans le rouge, caisse médiane à zéro
// en trois saisons (#889). Suite : trésorerie de départ ramenée à 12-30 % des recettes de chaque club (0,4 à
// 1,2 M€, world-nationale-extension.json ; situation nette réelle 0,54 M€ en moyenne) ; réserve de 30 à 45 % des
// recettes (une descente en Nationale 2 divise le budget par plus de deux) : un club de Nationale ne réinvestit
// pas une trésorerie qu'il n'a pas, et un relégué de Pro D2 (5 à 7 M€ de recettes, 2 à 3,6 M€ en caisse) garde son
// matelas ; marge de prudence de 2,5 % des recettes : la saison coûtait ~5 % de plus que le budget voté et
// presque aucun club ne finissait dans le vert (réel : le meilleur à +0,02 M€, le jeu en garde quelques-uns).
// aideRelegue : aide de la ligue à un club qui descend du championnat `depuis` : montant versé chaque saison suivant la
//              descente (versé avec la ligue, chaque semaine). Repère réel (LNR, redistribution 2025-2026, publiée le
//              25/08/2026) : le RC Vannes, relégué du Top 14, touche une part de solidarité de 2 M€ en Pro D2, quand le
//              socle des autres clubs est de 1,4 M€ en moyenne (1,4 à 1,7) : environ 0,6 M€ de plus la première saison.
//              La règle au-delà d'une saison n'est pas publiée : la deuxième saison (0,3 M€) est une estimation de jeu,
//              pour une aide dégressive qui laisse le temps aux contrats de l'élite d'arriver à échéance.
// billet     : prix du billet d'un club moyen de la division pour un match de saison régulière, en euros ; chaque club
//              l'ajuste à sa réputation (× 0,75 à × 1,3 ; club-budget.cjs, budgetPrixReference). Ordres de grandeur réels
//              (23/11/2026) : Pro D2 10 à 25 €, Top 14 20 à 60 €, abonnement = billet × 70 % × réceptions (Pro D2 ≈ 120 à
//              300 €, Top 14 ≈ 200 à 700 €), grosse affiche = billet × 1,5.
// public     : appétit du public occasionnel (places hors abonnés) : 1 en Top 14 et en Premiership (stades pleins à 85 %),
//              0,3 en Pro D2 et en Nationale (remplissage moyen ≈ 45 à 50 %, abonnés compris) ; × 0,8 à × 1,2 selon la
//              réputation du club. Avec ces réglages, la billetterie réelle d'une saison vaut 0,6 à 1,4 fois l'ancienne part
//              « billetterie » des recettes ; c'est elle qui compte dans les recettes prévues du club (club-budget.cjs, recettes).
// reputation : attrait sportif aux yeux des joueurs, 100 pour le championnat de référence.
// pays       : zone du championnat, pour les joueurs qui tiennent à rester chez eux.
// source     : 'relevé' quand le chiffre vient d'une publication, 'estimation' sinon
//              (détail et liens dans docs/salaires-par-niveau-20261111.md).
const parts = (partenaires, ligue, billetterie, boutique, divers) => Object.freeze({ partenaires, ligue, billetterie, boutique, divers });
const CHAMPIONNATS = Object.freeze({
  elite: Object.freeze({ libelle: 'Première division française', pays: 'france', reputation: 100, billet: 32, public: 1, masse: 9.9e6, recettes: 33e6, bas: 0.7, haut: 1.5, ...parts(0.45, 0.19, 0.16, 0.08, 0.12), plafond: 10.7e6, ratio: true, espoir: 'elite', source: 'relevé' }),
  prem: Object.freeze({ libelle: 'Première division anglaise', pays: 'angleterre', reputation: 92, billet: 40, public: 1, masse: 6.9e6, recettes: 23e6, bas: 0.75, haut: 1.35, ...parts(0.36, 0.24, 0.22, 0.08, 0.10), plafond: 7.5e6, ratio: false, espoir: 'elite', source: 'plafond relevé, masse et recettes estimées' }),
  urc: Object.freeze({ libelle: 'Championnat celte, italien et sud-africain', pays: 'celte', reputation: 90, billet: 25, public: 0.7, masse: 5.4e6, recettes: 18e6, bas: 0.5, haut: 1.9, ...parts(0.30, 0.40, 0.18, 0.05, 0.07), plafond: null, ratio: false, espoir: 'elite', source: 'estimation à partir de trois repères' }),
  srp: Object.freeze({ libelle: 'Championnat du Pacifique', pays: 'pacifique', reputation: 86, billet: 13, public: 0.3, masse: 2.3e6, recettes: 7.6e6, bas: 0.8, haut: 1.25, ...parts(0.28, 0.45, 0.15, 0.05, 0.07), plafond: 2.6e6, ratio: false, espoir: 'accession', source: 'plafond et salaire moyen relevés, recettes estimées' }),
  'jlo-d1': Object.freeze({ libelle: 'Première division japonaise', pays: 'japon', reputation: 78, billet: 20, public: 0.6, masse: 6.0e6, recettes: 20e6, bas: 0.7, haut: 1.5, ...parts(0.70, 0.08, 0.10, 0.04, 0.08), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
  accession: Object.freeze({ libelle: 'Deuxième division française', pays: 'france', reputation: 70, billet: 15, public: 0.3, masse: 3.2e6, recettes: 10.7e6, bas: 0.62, haut: 1.55, ...parts(0.48, 0.22, 0.08, 0.04, 0.18), plafond: null, ratio: true, encadrement: true, reserve: Object.freeze({ min: 0.2, ecart: 0.1 }),
    gestion: Object.freeze({ association: Object.freeze({ min: 0.02, ecart: 0.04 }), entreprise: Object.freeze({ min: 0, ecart: 0.6 }), mecene: Object.freeze({ min: 0.8, ecart: 0.2 }) }),
    engagementMax: 0.02, aideRelegue: Object.freeze({ depuis: 'elite', montants: Object.freeze([600000, 300000]) }), espoir: 'accession', source: 'relevé' }),
  guest: Object.freeze({ libelle: 'Clubs invités', pays: 'autre', reputation: 70, billet: 25, public: 0.7, masse: 4.0e6, recettes: 13e6, bas: 0.9, haut: 1.1, ...parts(0.40, 0.25, 0.18, 0.06, 0.11), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
  'jlo-d2': Object.freeze({ libelle: 'Deuxième division japonaise', pays: 'japon', reputation: 52, billet: 14, public: 0.4, masse: 2.0e6, recettes: 6.6e6, bas: 0.7, haut: 1.4, ...parts(0.72, 0.06, 0.08, 0.04, 0.10), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
  nationale: Object.freeze({ libelle: 'Troisième division française', pays: 'france', reputation: 50, billet: 10, public: 0.3, masse: 1.4e6, recettes: 4.6e6, bas: 0.6, haut: 1.6, ...parts(0.50, 0.10, 0.08, 0.04, 0.28), plafond: null, ratio: true, encadrement: true, reserve: Object.freeze({ min: 0.3, ecart: 0.15 }), prudence: 0.025, espoir: 'accession', source: 'relevé (A2R 2022-2023), niveaux 2026-2027 estimés' }),
  champ: Object.freeze({ libelle: 'Deuxième division anglaise', pays: 'angleterre', reputation: 48, billet: 18, public: 0.5, masse: 1.1e6, recettes: 3.6e6, bas: 0.7, haut: 1.5, ...parts(0.50, 0.06, 0.18, 0.10, 0.16), plafond: null, ratio: false, espoir: 'accession', source: 'salaire moyen relevé, recettes estimées' }),
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
// Prime pour quitter le championnat de référence (première division française) vers l'étranger :
// à salaire égal, environ un joueur sur quatre part en Angleterre, un sur cinq dans le championnat celte
// (décision de Léo du 12 novembre : partir doit être nettement plus rare que 82 à 88 sur 100).
const QUITTER_REFERENCE = 0.12;
// Rabais consenti pour monter : jusqu'à 10 %.
const rabaisMontee = ecart => Math.min(0.1, 0.1 * (ecart / 30) ** 1.2);

// Ce que l'attrait d'un championnat change au salaire qu'un joueur demande pour y signer.
// Renvoie un multiplicateur (1 = aucun effet) et ses raisons, sans rien dire du niveau du joueur.
//   origine : championnat que le joueur quitte (null si inconnu) ; destination : celui du club qui recrute ;
//   situation, tout ce que le club sait déjà du joueur :
//     sansClub     : saisons entières passées sans club (0 la saison qui suit sa libération) ;
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
    // Quitter le championnat de référence pour un championnat étranger moins réputé : premiers
    // salaires du monde, sélection nationale qui retient les joueurs du championnat, vie installée.
    // Le Japon garde sa propre règle d'âge, ci-dessous.
    if (vers.pays !== depuis.pays && vers.pays !== 'japon' && depuis.reputation >= 100 && ecart < 0) { taux += QUITTER_REFERENCE; raisons.push('quitter le meilleur championnat'); }
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
    // Libéré à la fin de la saison N, un joueur n'a passé aucune saison sans club pendant la saison N + 1.
    sansClub: Number.isInteger(depuis) && Number.isInteger(saison) && joueur?.population?.origin === 'released' ? Math.max(0, saison - depuis - 1) : 0,
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

module.exports = Object.freeze({ CHAMPIONNATS, REFERENCES, QUITTER_REFERENCE, temperament, attrait, situation, origine, dernierClub, primeDescente, rabaisMontee, unite });
