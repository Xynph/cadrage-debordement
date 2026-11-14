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
const REFERENCE = Object.freeze([[45, 16000], [60, 30000], [66, 52000], [70, 94000], [75, 186000], [80, 300000], [85, 400000], [90, 520000], [95, 620000], [99, 700000]]);
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

// Tous les championnats suivent la même règle (courbe, poste, politique, âge, histoire, espoirs).
// Hors des deux de référence, les salaires sont mis à l'échelle à la création pour que la masse
// moyenne des clubs rejoigne celle du championnat (economie = native/engine/league-economy.cjs).
// À chaque intersaison, l'échelle de chaque championnat est recalculée : le niveau des joueurs
// monte d'une saison à l'autre, pas l'argent du championnat.
const PLANCHER_MONDE = 8000;
const categorie = (division, economie) => economie?.CHAMPIONNATS?.[division]?.espoir ?? division;
const hebdo = (annuel, facteur) => Math.max(10, Math.round(Math.max(facteur === 1 ? 0 : PLANCHER_MONDE, annuel * facteur) / 52 / 10) * 10);
const masseDe = salaires => [...salaires.values()].reduce((somme, x) => somme + x.annuel, 0);
const moyenne = liste => liste.reduce((somme, x) => somme + x, 0) / liste.length;
const facteurValide = f => Number.isFinite(f) && f > 0 && f < 20;
const facteurDe = (state, division) => { const f = state.startingSalaries?.calage?.[division]; return facteurValide(f) ? f : 1; };
// Plus petit salaire hebdomadaire qu'un contrat peut porter dans ce championnat (14 000 € par an là où la règle n'est pas réduite).
const plancherHebdo = (state, division) => Math.round(Math.max(PLANCHER_MONDE, PLANCHER_ANNUEL * Math.min(1, facteurDe(state, division))) / 52 / 10) * 10;

function brut(state, forces, economie) {
  const politique = politiques(forces), division = new Map(forces.map(force => [force.id, force.division])), parClub = new Map();
  for (const equipe of state.clubs) {
    const p = politique.get(equipe.id);
    if (p) parClub.set(equipe.id, club(equipe.players ?? [], categorie(division.get(equipe.id), economie), p));
  }
  return { parClub, division };
}

// Clause de contrat d'un joueur quand son club change de division : multiplicateur de son salaire.
// sens < 0 : descente (trois joueurs sur dix n'ont pas de clause, les autres perdent 8 à 25 %) ;
// sens > 0 : montée (six sur dix ont une prime de 5 à 20 %).
function clause(joueurId, sens) {
  if (!sens) return 1;
  const tirage = unite('clause|' + joueurId), ampleur = unite('clause-ampleur|' + joueurId);
  if (sens < 0) return tirage < 0.3 ? 1 : Math.round((0.75 + 0.17 * ampleur) * 100) / 100;
  return tirage < 0.4 ? 1 : Math.round((1.05 + 0.15 * ampleur) * 100) / 100;
}

// limites : Map identifiant de club -> {limite} en euros par an (plafond de la ligue, part des recettes,
// budget). Un club dont la règle donnerait plus voit ses salaires ramenés à cette limite.
function borne(salaires, limite) {
  const masse = masseDe(salaires);
  return Number.isFinite(limite) && limite > 0 && masse > limite ? limite / masse : 1;
}

function apply(state, forces, economie = null, limites = null) {
  if (!state || state.startingSalaries !== undefined) return state;
  if (!(state.season === 1 && state.round === 0 && !state.live)) throw Error('Salaires de départ : réservé à la création.');
  const { parClub, division } = brut(state, forces, economie), calage = {};
  if (economie) {
    // Barème senior V2 (nouvelles carrières Monde) : les notes de la deuxième division française montent
    // d'environ deux points ; sa masse est donc recalée comme les autres. La première division reste la référence.
    const references = state.seniorCalibrationVersion === 2 ? economie.REFERENCES.filter(nom => nom === 'elite') : economie.REFERENCES;
    for (const [nom, regle] of Object.entries(economie.CHAMPIONNATS)) {
      if (references.includes(nom)) continue;
      const masses = [...parClub].filter(([id]) => division.get(id) === nom).map(([, salaires]) => masseDe(salaires));
      if (masses.length) calage[nom] = Math.round(regle.masse / moyenne(masses) * 1000) / 1000;
    }
  }
  for (const equipe of state.clubs) {
    const salaires = parClub.get(equipe.id);
    if (!salaires) continue;
    const facteur = calage[division.get(equipe.id)] ?? 1, retenue = borne(salaires, limites?.get(equipe.id)?.limite / facteur);
    // Le moteur compte les salaires à la semaine : l'année est répartie sur 52 semaines.
    for (const joueur of equipe.players ?? []) joueur.salary = retenue === 1 ? hebdo(salaires.get(joueur.id).annuel, facteur) : Math.max(10, Math.round(salaires.get(joueur.id).annuel * facteur * retenue / 52 / 10) * 10);
  }
  state.startingSalaries = { version: VERSION, semaines: 52, ...(Object.keys(calage).length ? { calage } : {}) };
  return state;
}

// Intersaison : les clubs gérés par le jeu remettent leurs contrats au niveau du marché.
// Sans cela, leurs prolongations et leurs recrues reviennent à l'ancien barème, cinq à dix fois plus cher.
//   saufClub   : club du manager, dont les contrats ne bougent pas ici ;
//   mouvements : Map club -> -1 (relégué) ou +1 (promu) : les clauses de contrat s'appliquent cette saison ;
//   limites    : Map club -> {limite}, comme à la création.
// L'échelle de chaque championnat est recalculée sur ses clubs restés en place.
function recaler(state, forces, economie = null, { saufClub = null, mouvements = null, limites = null } = {}) {
  if (!state || state.startingSalaries === undefined) return state;
  const { parClub, division } = brut(state, forces, economie);
  if (economie) {
    const calage = { ...(state.startingSalaries.calage ?? {}) };
    for (const [nom, regle] of Object.entries(economie.CHAMPIONNATS)) {
      const masses = [...parClub].filter(([id]) => division.get(id) === nom && id !== saufClub && !mouvements?.get(id)).map(([, salaires]) => masseDe(salaires));
      if (masses.length >= 3) calage[nom] = Math.round(regle.masse / moyenne(masses) * 1000) / 1000;
    }
    state.startingSalaries = { ...state.startingSalaries, calage };
  }
  for (const equipe of state.clubs) {
    const salaires = parClub.get(equipe.id);
    if (!salaires || equipe.id === saufClub) continue;
    const facteur = facteurDe(state, division.get(equipe.id)), sens = mouvements?.get(equipe.id) ?? 0;
    const annuels = new Map((equipe.players ?? []).map(joueur => [joueur.id, { annuel: salaires.get(joueur.id).annuel * facteur * clause(joueur.id, sens) }]));
    const retenue = borne(annuels, limites?.get(equipe.id)?.limite);
    for (const joueur of equipe.players ?? []) joueur.salary = Math.max(10, Math.round(Math.max(PLANCHER_MONDE, annuels.get(joueur.id).annuel * retenue) / 52 / 10) * 10);
  }
  return state;
}

// Club du manager qui change de division : les clauses de ses contrats jouent, une fois.
// Renvoie la masse annuelle avant et après, et le nombre de contrats touchés.
function clauses(state, clubId, sens) {
  const equipe = state?.clubs?.find(c => c.id === clubId), bilan = { avant: 0, apres: 0, touches: 0 };
  if (!equipe || !sens || state.startingSalaries === undefined) return bilan;
  for (const joueur of equipe.players ?? []) {
    const multiplicateur = clause(joueur.id, sens), nouveau = Math.max(10, Math.round(joueur.salary * multiplicateur / 10) * 10);
    bilan.avant += joueur.salary * 52; bilan.apres += nouveau * 52;
    if (nouveau !== joueur.salary) bilan.touches += 1;
    joueur.salary = nouveau;
  }
  return bilan;
}

// Salaire hebdomadaire qu'un joueur demande au club donné, selon la même règle que les salaires de départ.
function demande(state, forces, clubId, joueur, economie = null) {
  const equipe = state.clubs.find(c => c.id === clubId), force = forces.find(f => f.id === clubId), politique = politiques(forces).get(clubId);
  if (!equipe || !force || !politique) throw Error('Demande salariale : club inconnu.');
  const autres = (equipe.players ?? []).filter(x => x.id !== joueur.id);
  return hebdo(club([...autres, joueur], categorie(force.division, economie), politique).get(joueur.id).annuel, facteurDe(state, force.division));
}

// Valeur de marché hebdomadaire d'un joueur sans club, pour un club moyen de la référence.
const marche = joueur => hebdo(detail(joueur, 1).annuel, 1);

module.exports = Object.freeze({ VERSION, REFERENCE, POSTE, NOYAU, AGE_ESPOIR, PLANCHER_ANNUEL, reference, facteurAge, politiques, detail, espoir, club, clause, apply, recaler, clauses, demande, marche, plancherHebdo });
