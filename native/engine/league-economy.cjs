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
  prem: Object.freeze({ libelle: 'Première division anglaise', pays: 'angleterre', reputation: 88, masse: 6.9e6, recettes: 23e6, bas: 0.75, haut: 1.35, ...parts(0.36, 0.24, 0.22, 0.08, 0.10), plafond: 7.5e6, ratio: false, espoir: 'elite', source: 'plafond relevé, masse et recettes estimées' }),
  urc: Object.freeze({ libelle: 'Championnat celte, italien et sud-africain', pays: 'celte', reputation: 84, masse: 5.4e6, recettes: 18e6, bas: 0.5, haut: 1.9, ...parts(0.30, 0.40, 0.18, 0.05, 0.07), plafond: null, ratio: false, espoir: 'elite', source: 'estimation à partir de trois repères' }),
  srp: Object.freeze({ libelle: 'Championnat du Pacifique', pays: 'pacifique', reputation: 82, masse: 2.3e6, recettes: 7.6e6, bas: 0.8, haut: 1.25, ...parts(0.28, 0.45, 0.15, 0.05, 0.07), plafond: 2.6e6, ratio: false, espoir: 'accession', source: 'plafond et salaire moyen relevés, recettes estimées' }),
  'jlo-d1': Object.freeze({ libelle: 'Première division japonaise', pays: 'japon', reputation: 76, masse: 6.0e6, recettes: 20e6, bas: 0.7, haut: 1.5, ...parts(0.70, 0.08, 0.10, 0.04, 0.08), plafond: null, ratio: false, espoir: 'accession', source: 'estimation' }),
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
function temperament(joueurId) {
  const tirage = unite('temperament|' + joueurId);
  return tirage < 0.25 ? 'casanier' : tirage < 0.4 ? 'voyageur' : tirage < 0.55 ? 'ambitieux' : 'neutre';
}

// Ce que l'attrait d'un championnat change au salaire qu'un joueur demande pour y signer.
// Renvoie un multiplicateur (1 = aucun effet) et ses raisons, sans rien dire du niveau du joueur.
//   origine : championnat que le joueur quitte (null si inconnu) ; destination : celui du club qui recrute.
function attrait({ origine = null, destination, joueurId, age }) {
  const vers = CHAMPIONNATS[destination], depuis = origine ? CHAMPIONNATS[origine] : null;
  if (!vers) throw Error('Attrait : championnat inconnu.');
  const profil = temperament(String(joueurId)), raisons = [];
  let taux = 0;
  if (depuis && depuis !== vers) {
    const ecart = vers.reputation - depuis.reputation, poids = profil === 'ambitieux' ? 1.5 : 1;
    if (ecart > 0) { taux -= Math.min(0.08, ecart * 0.003) * poids; raisons.push('championnat plus réputé'); }
    else if (ecart < 0) { taux += Math.min(0.18, -ecart * 0.006) * poids; raisons.push('championnat moins réputé'); }
    if (vers.pays !== depuis.pays) {
      if (profil === 'casanier') { taux += 0.08; raisons.push('attaché à son pays'); }
      else if (profil === 'voyageur') { taux -= 0.04; raisons.push('envie de découvrir un autre rugby'); }
    }
    // Le Japon séduit les joueurs en fin de carrière : calendrier plus court, vie confortable.
    if (vers.pays === 'japon' && depuis.pays !== 'japon' && Number.isFinite(age) && age >= 31) { taux = Math.min(taux, 0) - 0.06; raisons.push('fin de carrière au Japon'); }
  } else if (!depuis && vers.reputation >= 95 && profil === 'ambitieux') { taux -= 0.03; raisons.push('rêve du meilleur championnat'); }
  // Chaque joueur a son idée : trois points d'écart au plus, dans un sens ou dans l'autre.
  taux += (unite('humeur|' + joueurId + '|' + destination) - 0.5) * 0.06;
  return { multiplicateur: Math.max(0.85, Math.min(1.3, 1 + taux)), profil, raisons };
}

// Championnat d'origine d'un joueur du marché, d'après ce que la base sait de lui.
//   ligueDuClub : fonction (identifiant de club) -> championnat.
function origine(joueur, ligueDuClub) {
  const club = joueur?.population?.clubId;
  if (Number.isInteger(club)) return ligueDuClub(club) ?? null;
  const prefixe = /^world:([a-z]+)[:-]/.exec(String(joueur?.id ?? ''))?.[1];
  if (prefixe === 'jlo') return 'jlo-d1';
  return prefixe && Object.hasOwn(CHAMPIONNATS, prefixe) ? prefixe : null;
}

module.exports = Object.freeze({ CHAMPIONNATS, REFERENCES, temperament, attrait, origine, unite });
