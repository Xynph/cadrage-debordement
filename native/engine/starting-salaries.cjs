'use strict';
// Salaires de départ, à la création d'une carrière seulement.
//
// Avant : chaque salaire sortait d'une empreinte de l'identifiant du joueur.
// Ici, un salaire part d'une valeur de référence selon le niveau, puis
// s'en écarte pour quatre raisons, comme sur un vrai marché :
//   - le poste (les deuxièmes lignes, numéros 8, ouvreurs et centres sont
//     mieux payés que les talonneurs et les ailiers) ;
//   - la politique du club (un club ambitieux paie plus cher pour attirer) ;
//   - l'âge (un jeune sous premier contrat est bon marché, un cadre coûte) ;
//   - l'histoire propre du joueur : bien ou mal négocié, signé avant de
//     progresser ou avant de décliner. C'est l'écart le plus large.
// Il y a donc des joueurs sous-payés et des joueurs surpayés dans chaque club.
//
// Repères 2023-2025 (ordres de grandeur, monde fictif) : 259 000 € brut par
// an en moyenne en première division, environ 48 000 € en deuxième ; masse
// salariale joueurs de 9,9 M€ et 3,2 M€ par club ; 190 000 à 280 000 € selon
// le poste ; une douzaine de joueurs vers 600 000 €.
const VERSION = 3;
const REFERENCE = Object.freeze([[45, 16000], [60, 30000], [66, 52000], [70, 94000], [75, 186000], [80, 300000], [85, 430000], [90, 570000], [95, 680000], [99, 740000]]);
const POSTE = Object.freeze([0.93, 0.84, 1.14, 1.0, 0.97, 1.1, 0.84, 1.1, 0.97]); // familles 0 à 8
const PLANCHER_ANNUEL = 14000;
const PLAFOND_ANNUEL = 800000;
// Les effectifs du jeu comptent les espoirs sous contrat (une vingtaine par club de
// première division). Hors des meilleurs du club, un joueur de 22 ans ou moins a un
// contrat espoir, pas un salaire de professionnel installé.
const NOYAU = 34;
const AGE_ESPOIR = 22;
const ESPOIR = Object.freeze({ elite: [18000, 46000], accession: [14000, 30000] });

function empreinte(texte) {
  let h = 2166136261;
  for (let i = 0; i < texte.length; i += 1) { h ^= texte.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
const unite = (cle) => (empreinte(cle) % 100000 + 0.5) / 100000; // ]0;1[
function normale(cle) { // loi normale centrée réduite, déterministe
  return Math.sqrt(-2 * Math.log(unite(cle + '|a'))) * Math.cos(2 * Math.PI * unite(cle + '|b'));
}

function reference(niveau) {
  const r = Math.max(REFERENCE[0][0], Math.min(REFERENCE[REFERENCE.length - 1][0], niveau));
  for (let i = 1; i < REFERENCE.length; i += 1) {
    if (r <= REFERENCE[i][0]) {
      const [r0, s0] = REFERENCE[i - 1], [r1, s1] = REFERENCE[i];
      return s0 * (s1 / s0) ** ((r - r0) / (r1 - r0));
    }
  }
  return REFERENCE[REFERENCE.length - 1][1];
}

function facteurAge(age) {
  if (!Number.isFinite(age)) return 1;
  return age <= 21 ? 0.62 : age <= 23 ? 0.8 : age <= 25 ? 0.93 : age <= 30 ? 1.04 : age <= 33 ? 1.12 : 1.02;
}

// forces : [{id, division, base}]. Un club fort de sa division paie plus ; chaque club a aussi son tempérament.
function politiques(forces) {
  const resultat = new Map();
  for (const division of new Set(forces.map(club => club.division))) {
    const groupe = forces.filter(club => club.division === division);
    const min = Math.min(...groupe.map(club => club.base)), max = Math.max(...groupe.map(club => club.base));
    for (const club of groupe) {
      const rang = max === min ? 0.5 : (club.base - min) / (max - min);
      resultat.set(club.id, (0.86 + 0.3 * rang) * (0.92 + 0.16 * unite('club|' + club.id)));
    }
  }
  return resultat;
}

// Renvoie le salaire annuel et ses facteurs, pour pouvoir l'expliquer et le tester.
function detail(joueur, politique) {
  const base = reference(Number.isFinite(joueur.rating) ? joueur.rating : 50);
  const poste = POSTE[joueur.fam] ?? 1;
  const age = facteurAge(joueur.age);
  const histoire = Math.exp(Math.max(-2.2, Math.min(2.2, normale('joueur|' + joueur.id))) * 0.27); // environ 0,55 à 1,8
  const annuel = Math.min(PLAFOND_ANNUEL, Math.max(PLANCHER_ANNUEL, Math.round(base * poste * politique * age * histoire / 1000) * 1000));
  return { reference: Math.round(base), poste, politique, age, histoire, annuel };
}

function espoir(joueur, division, politique) {
  const [bas, haut] = ESPOIR[division] ?? ESPOIR.accession;
  const niveau = Math.max(0, Math.min(1, ((Number.isFinite(joueur.rating) ? joueur.rating : 55) - 55) / 22));
  const annuel = (bas + (haut - bas) * niveau) * (0.85 + 0.3 * unite('espoir|' + joueur.id)) * Math.sqrt(politique);
  return Math.max(PLANCHER_ANNUEL, Math.round(annuel / 1000) * 1000);
}

// Renvoie, pour un club, le salaire annuel de chaque joueur : identifiant -> {annuel, espoir}.
function club(joueurs, division, politique) {
  const classes = [...joueurs].sort((a, b) => (b.rating - a.rating) || (String(a.id) < String(b.id) ? -1 : 1));
  const resultat = new Map();
  classes.forEach((joueur, rang) => {
    const contratEspoir = rang >= NOYAU && Number.isFinite(joueur.age) && joueur.age <= AGE_ESPOIR;
    resultat.set(joueur.id, { espoir: contratEspoir, annuel: contratEspoir ? espoir(joueur, division, politique) : detail(joueur, politique).annuel });
  });
  return resultat;
}

function apply(state, forces) {
  if (!state || state.startingSalaries !== undefined) return state;
  if (!(state.season === 1 && state.round === 0 && !state.live)) throw Error('Salaires de départ : réservé à la création.');
  const politique = politiques(forces), division = new Map(forces.map(force => [force.id, force.division]));
  for (const equipe of state.clubs) {
    const p = politique.get(equipe.id);
    if (!p) continue;
    const salaires = club(equipe.players ?? [], division.get(equipe.id), p);
    // Le moteur compte les salaires à la semaine : l'année est répartie sur 52 semaines.
    for (const joueur of equipe.players ?? []) joueur.salary = Math.max(10, Math.round(salaires.get(joueur.id).annuel / 52 / 10) * 10);
  }
  state.startingSalaries = { version: VERSION, semaines: 52 };
  return state;
}

module.exports = Object.freeze({ VERSION, REFERENCE, POSTE, NOYAU, AGE_ESPOIR, reference, facteurAge, politiques, detail, espoir, club, apply });
