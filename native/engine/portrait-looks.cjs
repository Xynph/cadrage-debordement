'use strict';
// Portrait cohérent avec la carrure et l'origine d'un joueur (professionnel ou jeune), calculé à la projection :
// aucune donnée de sauvegarde n'est modifiée, le résultat ne dépend que de l'identifiant, du poste, des
// mensurations (documentées ou estimées) et de l'origine. Sans aucune inférence ni génération d'image.
const portraits = require('./portraits.cjs');
// Copie embarquée avec le moteur des étiquettes du catalogue de la banque v2 (le moteur peut tourner sans les images).
const bank = require('./portrait-bank-looks.json');
const TONES = Array.from(bank.tones), CARRURES = Array.from(bank.carrures, Number);
const CENTRES = [-.8, -.25, .35, .85], WINDOW = .55;
const EUROPE = [['L', 66], ['T', 27], ['B', 5], ['D', 2]], PACIFIC = [['T', 20], ['B', 45], ['D', 35]], ASIA = [['L', 62], ['T', 38]], AFRICA = [['T', 10], ['B', 45], ['D', 45]];
// Mêmes tables que YOUTH_LOOKS de dist/development.js, complétées par quelques nations d'Europe des pros.
const LOOKS = {
  FRA: EUROPE, ENG: EUROPE, SCO: EUROPE, WAL: EUROPE, IRE: EUROPE, ITA: EUROPE, POR: EUROPE, ROU: EUROPE,
  ESP: EUROPE, GER: EUROPE, NED: EUROPE, BEL: EUROPE, SUI: EUROPE, POL: EUROPE, SWE: EUROPE, RUS: EUROPE,
  GEO: [['L', 55], ['T', 40], ['B', 5]], ARG: [['L', 58], ['T', 37], ['B', 5]], RSA: [['L', 38], ['T', 14], ['B', 26], ['D', 22]],
  NAM: AFRICA, ZIM: AFRICA, KEN: AFRICA, NZL: [['L', 45], ['T', 25], ['B', 20], ['D', 10]], AUS: [['L', 58], ['T', 24], ['B', 12], ['D', 6]],
  FIJ: PACIFIC, TGA: PACIFIC, SAM: PACIFIC, JPN: ASIA, KOR: ASIA,
};
const POST_SCORES = [['pilier', .85], ['talonneur', .6], ['deuxi', .6], ['troisi', .5], ['num', .55], ['n°', .55], ['demi de m', -.6], ['mêlée', -.6],
  ['demi d', -.45], ['ouverture', -.45], ['ail', -.4], ['centre', 0], ['arri', -.4]];

function postScore(pos) {
  const p = String(pos ?? '').toLowerCase().replace('’', "'");
  for (const [prefix, score] of POST_SCORES) if (p.startsWith(prefix)) return score;
  return null;
}
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
// Carrure attendue de -1 (très fin) à 1 (très costaud) : mensurations documentées si elles existent
// (poids corrigé de la taille), sinon le poste (les mensurations estimées en dérivent déjà).
function expectedScore({ pos, heightCm, weightKg, dimensionsSource } = {}) {
  if (dimensionsSource === 'documented' && Number.isFinite(heightCm) && Number.isFinite(weightKg)) return clamp((weightKg - .65 * (heightCm - 185) - 97) / 22, -1, 1);
  return postScore(pos);
}
const fits = (score, cell) => score === null || Math.abs(CENTRES[CARRURES[cell] - 1] - score) <= WINDOW;
const far = (score, cell) => score !== null && Math.abs(CENTRES[CARRURES[cell] - 1] - score) > .9;

function wantedTone(id, nation) {
  const table = LOOKS[nation];
  if (!table) return null;
  let roll = portraits.hash(id + ':look') % 100;
  for (const [tone, weight] of table) { if (roll < weight) return tone; roll -= weight; }
  return table[table.length - 1][0];
}

// facts : player-facts.cjs (mensurations et nation). Renvoie le portrait à utiliser pour un joueur projeté.
function createLooks(facts) {
  const memo = new Map();
  function resolve(player) {
    const bank = player.appearanceBankVersion === 2 ? 2 : 1, cells = bank === 2 ? 160 : 32;
    const physical = facts.project(player.id, null, player), fromModel = player.playerFacts;
    const dims = fromModel && Number.isFinite(fromModel.heightCm) ? fromModel : physical;
    const score = expectedScore({ pos: player.pos, ...dims });
    const persisted = typeof player.appearanceId === 'string' && player.appearanceId.length > 0;
    const base = persisted ? player.appearanceId : player.id;
    // Un portrait déjà orienté à la création (jeune) garde sa teinte ; les autres reçoivent la teinte de leur origine.
    const want = persisted && /:look\d+$/.test(base) ? null : wantedTone(player.id, facts.origin(player.id));
    const cell = id => portraits.hash(id) % cells;
    let id = base;
    if (!(fits(score, cell(base)) && (want === null || TONES[cell(base)] === want))) {
      let found = null;
      for (const strict of [true, false]) {
        for (let k = 1; k <= 400 && found === null; k++) {
          const candidate = base + ':c' + k, c = cell(candidate);
          if (fits(score, c) && (!strict || want === null || TONES[c] === want)) found = candidate;
        }
        if (found !== null) break;
      }
      if (found !== null) id = found;
    }
    const c = cell(id);
    const build = score === null ? null : Math.round(clamp((score - CENTRES[CARRURES[c] - 1]) / WINDOW, -1, 1) * 100) / 100;
    return { appearanceId: id, appearanceBuild: build, cell: c, score, tone: TONES[c], want };
  }
  const isPlayer = o => o && typeof o === 'object' && typeof o.id === 'string' && typeof o.pos === 'string' && typeof o.name === 'string' && Number.isFinite(o.age) && typeof o.role !== 'string' && o.sourcePlayerId === undefined;
  function patch(player) {
    const key = [player.id, player.pos, player.age, player.appearanceId ?? '', player.appearanceBankVersion ?? 1, player.playerFacts?.weightKg ?? '', player.playerFacts?.heightCm ?? ''].join('|');
    let r = memo.get(key);
    if (!r) { r = resolve(player); if (memo.size > 50000) memo.clear(); memo.set(key, r); }
    if (r.appearanceId !== (player.appearanceId ?? player.id)) player.appearanceId = r.appearanceId;
    if (r.appearanceBuild !== null) player.appearanceBuild = r.appearanceBuild;
  }
  // Parcourt un modèle projeté (lecture seule de l'état : on ne modifie que la copie envoyée à l'interface).
  function apply(node, seen = new Set()) {
    if (!node || typeof node !== 'object' || seen.has(node)) return node;
    seen.add(node);
    if (Array.isArray(node)) { for (const x of node) apply(x, seen); return node; }
    if (isPlayer(node)) patch(node);
    for (const key of Object.keys(node)) { const v = node[key]; if (v && typeof v === 'object') apply(v, seen); }
    return node;
  }
  return { resolve, apply, patch };
}
module.exports = { createLooks, expectedScore, postScore, fits, far, wantedTone, TONES, CARRURES, CENTRES, WINDOW, LOOKS };
