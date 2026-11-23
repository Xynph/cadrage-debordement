'use strict';
// Entrées dans les 22 mètres adverses (`live.direct.zone22`, écran 2D du match).
//
// Notion d'analyse, pas une loi du jeu (la ligne des 22 est la loi 1, Terrain). Lecture seule
// du journal normalisé (match-highlights.normaliser) : rien n'est écrit ni tiré, et l'appelant
// ne passe que les faits montrés (lignes avant la borne de l'entracte).
//
// Sens du terrain : l'équipe 0 attaque vers x = 100, l'équipe 1 vers x = 0 (distance à la ligne
// d'essai adverse = 100 - x pour l'équipe 0, x pour l'équipe 1, comme `_zone` côté Godot).
//
// Définitions retenues :
// - séquence : suite de faits d'une même équipe en possession ; elle s'arrête au changement de
//   possession, au coup d'envoi, à la mi-temps, à la fin, et après un essai ou un tir réussi ;
// - entrée : dans une séquence, un fait avec ballon en main dans les 22 adverses
//   (`dansLes22` du moteur : course, conquête, touche, mêlée, réception) alors que la séquence
//   a déjà été vue hors des 22 (point de départ ou d'arrivée d'un de ses faits à plus de 22 m).
//   Une seule entrée par séquence : sortir puis revenir sans perdre le ballon ne compte pas deux
//   fois ; une séquence commencée dans les 22 (ballon récupéré) n'est pas une entrée tant
//   qu'elle n'en est pas sortie ;
// - points : points marqués par cette équipe pendant une séquence qui a compté une entrée
//   (différence de `scoreApres`, transformation comprise) ;
// - secondes : temps de jeu, après l'entrée, des faits de la séquence placés dans les 22
//   adverses, ballon vivant (pas après un fait qui arrête le jeu).
//
// Approximation d'horloge : le journal ne date les faits qu'à la minute. Les faits d'une même
// minute sont répartis à intervalles égaux sur ses 60 secondes ; un fait dure jusqu'au fait
// daté suivant de la même période. Le dernier fait montré ne dure rien (rien au-delà de la borne).
const { dansLes22 } = require('./match-highlights.cjs');

const ZONE = 22;
const distance = (equipe, x) => equipe === 0 ? 100 - x : x;
const REPRISES = new Set(['kickoff', 'break', 'end']);
const MARQUES = new Set(['try', 'goal']);
// Fait après lequel le ballon est mort (pas de temps de jeu jusqu'au suivant).
const ARRETS = new Set(['touch', 'hand-fault', 'try', 'goal', 'miss', 'ingoal', 'penalty', 'break', 'end']);

// Instant approché (secondes) de chaque fait daté : la minute, plus sa place dans la minute.
function instants(lignes) {
  const dates = lignes.filter(l => !l.bandeau), groupes = new Map(), t = new Map();
  for (const l of dates) { const c = l.periode + ':' + l.minute; groupes.set(c, (groupes.get(c) || 0) + 1); }
  const rang = new Map();
  for (const l of dates) {
    const c = l.periode + ':' + l.minute, k = rang.get(c) || 0;
    rang.set(c, k + 1);
    t.set(l.i, l.minute * 60 + 60 * k / groupes.get(c));
  }
  const durees = new Map();
  for (let j = 0; j < dates.length; j++) {
    const l = dates[j], suivant = dates[j + 1];
    durees.set(l.i, suivant && suivant.periode === l.periode ? Math.max(0, t.get(suivant.i) - t.get(l.i)) : 0);
  }
  return durees;
}

// `options.liste` : joint aussi chaque entrée datée, [minute, équipe] dans l'ordre du match (rapport de l'analyste
// vidéo après le match, courbe cumulée des occasions).
function zone22(lignes, options = {}) {
  const entrees = [0, 0], points = [0, 0], secondes = [0, 0], liste = [];
  const rendu = () => options.liste ? { entrees, points, secondes: secondes.map(s => Math.round(s)), liste } : { entrees, points, secondes: secondes.map(s => Math.round(s)) };
  if (!Array.isArray(lignes)) return rendu();
  const durees = instants(lignes);
  let seq = null;
  for (const l of lignes) {
    if (l.bandeau) continue;
    // Points : attribués avant tout changement de séquence (le fait qui marque la ferme).
    if (seq && seq.entree && Array.isArray(l.scoreApres) && Array.isArray(l.scoreAvant)) {
      const marque = (l.scoreApres[seq.equipe] || 0) - (l.scoreAvant[seq.equipe] || 0);
      if (marque > 0) points[seq.equipe] += marque;
    }
    if (REPRISES.has(l.kind)) seq = null;
    if (l.possession === 0 || l.possession === 1) {
      const e = l.possession;
      if (!seq || seq.equipe !== e) seq = { equipe: e, dehors: false, entree: false };
      if (Number.isFinite(l.depuis) && distance(e, l.depuis) > ZONE) seq.dehors = true;
      if (!seq.entree && seq.dehors && dansLes22(l)) { seq.entree = true; entrees[e]++; liste.push([Math.max(0, Number(l.minute) || 0), e]); }
      if (seq.entree && Number.isFinite(l.x) && distance(e, l.x) <= ZONE && !ARRETS.has(l.kind)) secondes[e] += durees.get(l.i) || 0;
      if (Number.isFinite(l.x) && distance(e, l.x) > ZONE) seq.dehors = true;
    }
    if (MARQUES.has(l.kind) || l.kind === 'break' || l.kind === 'end') seq = null;
  }
  return rendu();
}

module.exports = Object.freeze({ ZONE, zone22 });
