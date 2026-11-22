'use strict';
// Rubrique facultative `talents` des packs d'identités (carrières Monde) : niveau relevé hors du jeu de base, par
// identifiant seulement, comme le niveau réel compilé (world-niveaux-v2.json). Le jeu de base n'en porte aucune
// donnée : sans pack, ou avec un pack qui n'a pas la rubrique, rien ne change.
//
//   "talents": {
//     "potentials": { "<id de joueur>": [hausse, plafond] },
//     "added": [ { "id": "pack:<court>", "clubId": 0, "position": "Centre", "birthYear": 2007, "nation": "ESP",
//                  "statut": "jeune", "u20": 1, "potential": [hausse, plafond] } ]
//   }
//
// - potentials : à la création d'une carrière, le potentiel de départ calculé par le barème monte de `hausse`
//   points sans dépasser `plafond` (jamais de baisse, la note actuelle ne bouge pas). La variation de carrière
//   s'applique ensuite comme pour tous les joueurs.
// - added : joueurs créés dans l'effectif de départ de leur club. Le barème calcule leur note et leur potentiel
//   à partir du statut et du U20 donnés, comme pour un joueur de la base ; `potential` les relève ensuite.
//   Leur nom et leur portrait passent par la rubrique `players` du même pack (même identifiant) : la sauvegarde
//   ne garde qu'un nom inventé, le pack le présente.
const POSITIONS = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Troisième ligne', 'Numéro 8',
  'Demi de mêlée', 'Demi d’ouverture', 'Centre', 'Ailier', 'Arrière'];
const STATUTS = ['titulaire', 'rotation', 'reserviste', 'jeune'];
const ADDED_ID = /^pack:[a-z0-9][a-z0-9-]{0,39}$/;
const MAX_ADDED = 300, MAX_PER_CLUB = 12;
const object = v => v !== null && typeof v === 'object' && !Array.isArray(v);
function ensure(ok, message) { if (!ok) throw Error('Pack refusé : talents : ' + message); }
function keys(v, allowed, what) { ensure(object(v) && Object.keys(v).every(k => allowed.includes(k)), what + ' : champ non autorisé.'); }
function raise(v, what) {
  ensure(Array.isArray(v) && v.length === 2 && Number.isInteger(v[0]) && v[0] >= 0 && v[0] <= 10 &&
    Number.isInteger(v[1]) && v[1] >= 40 && v[1] <= 99, what + ' : hausse (0 à 10) et plafond (40 à 99) attendus.');
  return [v[0], v[1]];
}

// `database` : base de la carrière ; `known` : identifiants des joueurs de cette base.
function normalize(rubric, database, known) {
  keys(rubric, ['potentials', 'added'], 'rubrique');
  ensure(rubric.potentials !== undefined || rubric.added !== undefined, 'rubrique vide.');
  const clubs = new Set(database.clubs.map(c => c.id));
  const potentials = {}, added = [], perClub = new Map();
  if (rubric.potentials !== undefined) {
    ensure(object(rubric.potentials) && Object.keys(rubric.potentials).length <= known.size, 'potentiels invalides.');
    for (const [id, value] of Object.entries(rubric.potentials)) {
      ensure(known.has(id), 'joueur inconnu.');
      potentials[id] = raise(value, 'potentiel');
    }
  }
  if (rubric.added !== undefined) {
    ensure(Array.isArray(rubric.added) && rubric.added.length <= MAX_ADDED, 'joueurs ajoutés invalides.');
    const ids = new Set();
    for (const p of rubric.added) {
      keys(p, ['id', 'clubId', 'position', 'birthYear', 'nation', 'statut', 'u20', 'potential'], 'joueur ajouté');
      ensure(typeof p.id === 'string' && ADDED_ID.test(p.id) && !ids.has(p.id) && !known.has(p.id), 'identifiant de joueur ajouté invalide ou dupliqué.');
      ids.add(p.id);
      ensure(Number.isInteger(p.clubId) && clubs.has(p.clubId), 'club inconnu.');
      perClub.set(p.clubId, (perClub.get(p.clubId) || 0) + 1);
      ensure(perClub.get(p.clubId) <= MAX_PER_CLUB, 'trop de joueurs ajoutés dans un club.');
      ensure(POSITIONS.includes(p.position), 'poste inconnu.');
      ensure(Number.isInteger(p.birthYear) && p.birthYear >= 1986 && p.birthYear <= 2010, 'année de naissance invalide.');
      ensure(p.nation === undefined || typeof p.nation === 'string' && /^[A-Z]{3}$/.test(p.nation), 'nation invalide.');
      ensure(p.statut === undefined || STATUTS.includes(p.statut), 'statut invalide.');
      ensure(p.u20 === undefined || p.u20 === 0 || p.u20 === 1, 'indicateur U20 invalide.');
      const out = { id: p.id, clubId: p.clubId, position: p.position, birthYear: p.birthYear, statut: p.statut ?? 'jeune', u20: p.u20 ?? 0 };
      if (p.nation !== undefined) out.nation = p.nation;
      if (p.potential !== undefined) out.potential = raise(p.potential, 'potentiel du joueur ajouté');
      added.push(out);
    }
  }
  return { potentials, added };
}

function ingest(rubric, database, known) {
  const talents = normalize(rubric, database, known);
  return { talents, counts: { talentPotentials: Object.keys(talents.potentials).length, talentAdditions: talents.added.length } };
}
// Pack installé : même contrôle sur la forme normalisée.
function validateInstalled(talents, database, known) {
  const again = normalize(talents, database, known);
  ensure(JSON.stringify(again) === JSON.stringify(talents), 'rubrique installée modifiée.');
  return talents;
}
const addedIds = rubric => new Set(Array.isArray(rubric?.added) ? rubric.added.map(p => p?.id).filter(id => typeof id === 'string') : []);

module.exports = { ingest, validateInstalled, addedIds, POSITIONS, ADDED_ID };
