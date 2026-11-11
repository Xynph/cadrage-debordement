'use strict';
// Salaires de départ liés au niveau, à la création d'une carrière seulement.
//
// Avant : chaque salaire sortait d'une empreinte de l'identifiant du joueur,
// sans lien avec son niveau ni avec son club. Ici, chaque club reçoit une
// masse salariale annuelle selon sa division et sa force, répartie entre ses
// joueurs selon leur niveau.
//
// Repères (rapport 2026 sur l'économie des clubs professionnels, saison
// 2024-2025) : masse salariale joueurs moyenne de 9,9 M€ en première division
// (écart de 1 à 2,2 entre clubs) et de 3,2 M€ en deuxième (écart de 1 à 3,4).
// Ce sont des ordres de grandeur pour un monde fictif, pas les comptes d'un club.
const VERSION = 1;
const DIVISIONS = Object.freeze({
  elite: Object.freeze({ moyenne: 9.9e6, bas: 0.62, haut: 1.37 }),
  accession: Object.freeze({ moyenne: 3.2e6, bas: 0.5, haut: 1.7 }),
});
const PLANCHER_HEBDO = 250;

function empreinte(texte) {
  let h = 2166136261;
  for (let i = 0; i < texte.length; i += 1) { h ^= texte.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

function poids(joueur) {
  const niveau = Number.isFinite(joueur.rating) ? joueur.rating : 50;
  const variation = 0.94 + (empreinte(String(joueur.id)) % 13) / 100; // 0,94 à 1,06
  return Math.max(8, niveau - 42) ** 2 * variation;
}

// forces : [{id, division, base}] pour tous les clubs ; renvoie la masse annuelle visée par club.
function masses(forces) {
  const resultat = new Map();
  for (const [division, regle] of Object.entries(DIVISIONS)) {
    const groupe = forces.filter(club => club.division === division);
    if (!groupe.length) continue;
    const min = Math.min(...groupe.map(club => club.base)), max = Math.max(...groupe.map(club => club.base));
    const brut = groupe.map(club => regle.bas + (regle.haut - regle.bas) * (max === min ? 0.5 : (club.base - min) / (max - min)));
    const correction = groupe.length / brut.reduce((somme, valeur) => somme + valeur, 0); // la moyenne de la division reste exacte
    groupe.forEach((club, i) => resultat.set(club.id, regle.moyenne * brut[i] * correction));
  }
  return resultat;
}

function apply(state, forces, semainesPayees) {
  if (!state || state.startingSalaries !== undefined) return state;
  if (!(state.season === 1 && state.round === 0 && !state.live)) throw Error('Salaires de départ : réservé à la création.');
  if (!Number.isInteger(semainesPayees) || semainesPayees < 1) throw Error('Salaires de départ : nombre de semaines payées invalide.');
  const cibles = masses(forces);
  for (const club of state.clubs) {
    const cible = cibles.get(club.id);
    if (!cible || !club.players?.length) continue;
    const total = club.players.reduce((somme, joueur) => somme + poids(joueur), 0);
    const hebdo = cible / semainesPayees;
    for (const joueur of club.players) joueur.salary = Math.max(PLANCHER_HEBDO, Math.round(hebdo * poids(joueur) / total / 10) * 10);
  }
  state.startingSalaries = { version: VERSION, semainesPayees };
  return state;
}

module.exports = Object.freeze({ VERSION, DIVISIONS, masses, poids, apply });
