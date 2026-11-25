'use strict';
// Niveau calculé (planche « notation façon FM », 24/11/2026) — branché à l'écran (player-knowledge.cjs, projection
// `niveauCalcule`) ; le moteur du match garde `rating` tant que la bascule n'est pas faite.
//
// Choix de Léo : deux vrais chiffres cachés, « Niveau » (aujourd'hui `rating` 15-99) et « Potentiel » (`dev.potential`).
// Le Niveau doit être CALCULÉ selon les qualités qui comptent au POSTE et au RÔLE (comme le CA de Football Manager),
// avec quelques qualités cachées, au lieu d'être une valeur posée à côté des qualités.
//
// Calcul (docs/notation-fm-20261124.md, § 1 ; révisé le 25/11 : le rôle compte, écart 4 du vérificateur) :
//   poste  = Σ poidsPoste(q) × q / Σ poidsPoste(q)   (36 qualités 20-97 ; défaut 0,5 lecture du jeu, 0,25 sinon)
//   note(rôle) = (2 × Σ clés + Σ utiles) / 12          (les 8 qualités du rôle, comme la fiche)
//   profil(rôle) = clamp(note(rôle) − moyenne des notes des rôles du poste − CENTRE_ROLE[rôle], ±5)
//   brut = 0,92 × (poste + 1,5 × profil(rôle)) + 0,04 × régularité + 0,04 × grandsMatchs   (hiddenTraitsV2)
//   Niveau = clamp(round(A × brut + B), 15, 99)   A, B : calage unique (tous postes) sur la base mondiale, pour garder
//            l'échelle actuelle de `rating` (moyenne et dispersion identiques sur les 116 clubs du Monde).
//   Niveau du joueur = meilleur rôle de son poste principal (le rôle choisi par le club quand il existera).
//
// Aucun tirage, aucune écriture : fonctions pures, lisibles depuis un outil (tools/notation/ecart-niveau.cjs).

const CLES = Object.freeze([
  'passing', 'receiving', 'offload', 'tackling', 'jackal', 'ruckClearout', 'ballCarry', 'evasion',
  'kickDistance', 'kickAccuracy', 'goalAccuracy', 'ballHandling', 'decisions', 'anticipation',
  'vision', 'positioning', 'composure', 'discipline', 'teamwork', 'leadership', 'workRate',
  'acceleration', 'topSpeed', 'agility', 'explosiveness', 'strength', 'endurance', 'jumping',
  'scrumTechnique', 'hooking', 'lineoutThrow', 'lineoutJump', 'lineoutLift', 'maul', 'kickChase', 'aerialAbility'
]); // même ordre que nativeAttributesV1 (player-attributes.cjs)

const LECTURE = new Set(['decisions', 'anticipation', 'vision', 'positioning', 'composure', 'discipline', 'teamwork', 'leadership', 'workRate']);
const DEFAUT_LECTURE = 0.5, DEFAUT = 0.25;

// Poids au poste : 4 = cœur du poste, 3 = essentielle, 2 = importante, 1,5 / 1 = utile ; absente = défaut.
const POIDS_POSTE = Object.freeze({
  pilier: { scrumTechnique: 4, strength: 3, maul: 2, lineoutLift: 2, ruckClearout: 2, tackling: 2, endurance: 2, workRate: 2, discipline: 1.5, ballCarry: 1, explosiveness: 1, teamwork: 1 },
  talonneur: { lineoutThrow: 4, hooking: 3, scrumTechnique: 3, strength: 2, tackling: 2, maul: 2, workRate: 2, endurance: 2, ballCarry: 1.5, jackal: 1.5, ruckClearout: 1.5, composure: 1 },
  deuxieme: { lineoutJump: 4, jumping: 3, strength: 3, lineoutLift: 2, scrumTechnique: 2, maul: 2, ruckClearout: 2, tackling: 2, workRate: 2, endurance: 2, aerialAbility: 2, ballCarry: 1 },
  aile: { tackling: 4, jackal: 3, workRate: 3, endurance: 3, ruckClearout: 2, ballCarry: 2, anticipation: 2, acceleration: 1.5, positioning: 1.5, strength: 1.5, explosiveness: 1.5, offload: 1, lineoutJump: 1 },
  huit: { ballCarry: 3, tackling: 3, strength: 2, workRate: 2, endurance: 2, ballHandling: 2, decisions: 2, offload: 2, explosiveness: 2, lineoutJump: 1.5, leadership: 1.5, scrumTechnique: 1, passing: 1 },
  demi: { passing: 4, decisions: 3, vision: 2, kickDistance: 2, kickAccuracy: 2, acceleration: 2, agility: 2, anticipation: 2, composure: 2, ballHandling: 2, teamwork: 1.5, evasion: 1.5, tackling: 1, leadership: 1 },
  ouvreur: { decisions: 4, passing: 3, vision: 3, kickDistance: 3, kickAccuracy: 3, composure: 3, goalAccuracy: 2, ballHandling: 2, evasion: 1.5, positioning: 1.5, leadership: 1.5, acceleration: 1, tackling: 1 },
  centre: { ballCarry: 3, tackling: 3, passing: 2, evasion: 2, strength: 2, acceleration: 2, explosiveness: 2, offload: 2, decisions: 2, positioning: 2, receiving: 1.5, vision: 1.5, topSpeed: 1.5, ballHandling: 1.5 },
  ailier: { topSpeed: 4, acceleration: 3, evasion: 3, agility: 2, receiving: 2, ballCarry: 2, aerialAbility: 2, kickChase: 2, tackling: 1.5, positioning: 1.5, offload: 1 },
  arriere: { positioning: 3, receiving: 3, aerialAbility: 3, kickDistance: 2, topSpeed: 2, acceleration: 2, evasion: 2, tackling: 2, vision: 2, decisions: 2, kickAccuracy: 1.5, composure: 1.5, agility: 1.5 }
});

// Rôles du poste : MÊME table que l'écran (native/godot/ui/immersive08/fiche_roles.gd, ROLES) — vérifiée par
// tests/niveau-calcule.cjs. [id, famille, nom, 4 qualités clés (+2), 4 utiles (+1)].
const ROLES = Object.freeze([
  ['pilier-conquerant', 'pilier', 'Conquérant', ['scrumTechnique', 'strength', 'maul', 'endurance'], ['lineoutLift', 'ruckClearout', 'tackling', 'discipline']],
  ['pilier-mobile', 'pilier', 'Mobile', ['ballCarry', 'workRate', 'tackling', 'endurance'], ['offload', 'ruckClearout', 'receiving', 'acceleration']],
  ['pilier-deblayeur', 'pilier', 'Déblayeur', ['ruckClearout', 'strength', 'tackling', 'workRate'], ['jackal', 'maul', 'explosiveness', 'discipline']],
  ['talon-lanceur', 'talonneur', 'Lanceur', ['lineoutThrow', 'hooking', 'scrumTechnique', 'composure'], ['maul', 'strength', 'discipline', 'decisions']],
  ['talon-gratteur', 'talonneur', 'Gratteur', ['jackal', 'tackling', 'ballCarry', 'workRate'], ['acceleration', 'offload', 'anticipation', 'ruckClearout']],
  ['talon-perforateur', 'talonneur', 'Perforateur', ['ballCarry', 'strength', 'explosiveness', 'offload'], ['hooking', 'lineoutThrow', 'endurance', 'evasion']],
  ['deux-sauteur', 'deuxieme', 'Sauteur', ['lineoutJump', 'jumping', 'aerialAbility', 'decisions'], ['lineoutLift', 'maul', 'receiving', 'anticipation']],
  ['deux-pousseur', 'deuxieme', 'Pousseur', ['scrumTechnique', 'strength', 'ruckClearout', 'maul'], ['tackling', 'endurance', 'lineoutLift', 'workRate']],
  ['deux-mobile', 'deuxieme', 'Mobile', ['workRate', 'ballCarry', 'tackling', 'endurance'], ['offload', 'passing', 'acceleration', 'lineoutJump']],
  ['aile-gratteur', 'aile', 'Gratteur', ['jackal', 'tackling', 'anticipation', 'workRate'], ['positioning', 'ruckClearout', 'acceleration', 'discipline']],
  ['aile-perforateur', 'aile', 'Perforateur', ['ballCarry', 'explosiveness', 'offload', 'strength'], ['lineoutJump', 'workRate', 'evasion', 'endurance']],
  ['aile-plaqueur', 'aile', 'Plaqueur', ['tackling', 'workRate', 'endurance', 'positioning'], ['anticipation', 'strength', 'ruckClearout', 'discipline']],
  ['huit-porteur', 'huit', 'Porteur', ['ballCarry', 'strength', 'offload', 'explosiveness'], ['scrumTechnique', 'ballHandling', 'endurance', 'evasion']],
  ['huit-liant', 'huit', 'Liant', ['ballHandling', 'decisions', 'passing', 'vision'], ['teamwork', 'lineoutJump', 'receiving', 'offload']],
  ['huit-meneur', 'huit', 'Meneur', ['leadership', 'decisions', 'tackling', 'lineoutJump'], ['discipline', 'composure', 'workRate', 'scrumTechnique']],
  ['demi-eclaireur', 'demi', 'Éclaireur', ['acceleration', 'evasion', 'anticipation', 'ballCarry'], ['passing', 'decisions', 'agility', 'receiving']],
  ['demi-animateur', 'demi', 'Animateur', ['passing', 'decisions', 'vision', 'teamwork'], ['kickAccuracy', 'leadership', 'composure', 'ballHandling']],
  ['demi-tacticien', 'demi', 'Tacticien', ['kickDistance', 'kickAccuracy', 'passing', 'decisions'], ['kickChase', 'composure', 'vision', 'positioning']],
  ['ouvreur-stratege', 'ouvreur', 'Stratège', ['kickDistance', 'kickAccuracy', 'decisions', 'vision'], ['goalAccuracy', 'composure', 'positioning', 'leadership']],
  ['ouvreur-attaquant', 'ouvreur', 'Attaquant', ['passing', 'vision', 'evasion', 'ballHandling'], ['acceleration', 'decisions', 'offload', 'agility']],
  ['ouvreur-buteur', 'ouvreur', 'Buteur', ['goalAccuracy', 'kickAccuracy', 'composure', 'kickDistance'], ['decisions', 'discipline', 'positioning', 'passing']],
  ['centre-perceur', 'centre', 'Perceur', ['ballCarry', 'strength', 'evasion', 'explosiveness'], ['offload', 'tackling', 'acceleration', 'receiving']],
  ['centre-distributeur', 'centre', 'Distributeur', ['passing', 'vision', 'ballHandling', 'decisions'], ['kickDistance', 'receiving', 'offload', 'tackling']],
  ['centre-verrou', 'centre', 'Verrou', ['tackling', 'positioning', 'anticipation', 'jackal'], ['workRate', 'strength', 'decisions', 'discipline']],
  ['ailier-finisseur', 'ailier', 'Finisseur', ['topSpeed', 'acceleration', 'evasion', 'agility'], ['receiving', 'ballCarry', 'composure', 'offload']],
  ['ailier-chasseur', 'ailier', 'Chasseur', ['kickChase', 'aerialAbility', 'tackling', 'topSpeed'], ['workRate', 'positioning', 'jumping', 'receiving']],
  ['ailier-perforateur', 'ailier', 'Perforateur', ['ballCarry', 'strength', 'explosiveness', 'evasion'], ['topSpeed', 'offload', 'receiving', 'tackling']],
  ['arriere-relanceur', 'arriere', 'Relanceur', ['evasion', 'topSpeed', 'receiving', 'vision'], ['passing', 'acceleration', 'agility', 'decisions']],
  ['arriere-rempart', 'arriere', 'Dernier rempart', ['aerialAbility', 'positioning', 'tackling', 'receiving'], ['kickDistance', 'composure', 'anticipation', 'jumping']],
  ['arriere-botteur', 'arriere', 'Botteur', ['kickDistance', 'kickAccuracy', 'aerialAbility', 'positioning'], ['goalAccuracy', 'decisions', 'composure', 'kickChase']]
].map(r => Object.freeze(r)));


// Note d'un rôle = moyenne de ses 8 qualités (clé × 2, utile × 1), comme la fiche.
const CLE_ROLE = 2, UTILE_ROLE = 1;
// Part du PROFIL au rôle (25/11, écart 4 du vérificateur) : le Niveau au rôle = Niveau au poste + PART_ROLE × écart de
// profil, l'écart de profil étant « note du rôle − moyenne des notes des rôles du poste », recentré sur la base
// mondiale (CENTRE_ROLE). Les qualités partagées par les rôles s'annulent ; seul compte ce qui distingue le joueur
// d'un joueur typique de son poste. Moyenne des rôles d'un joueur = Niveau au poste (aucune dérive par rôle).
const PART_ROLE = 1.5;
const PROFIL_MAX = 5;      // écart de profil borné à ± 5 (≈ ± 8 points de Niveau) : un rôle ne remplace pas le poste
const PART_CACHEES = 0.08; // 4 % régularité + 4 % grands matchs
const CACHEES = Object.freeze(['consistency', 'bigMatches']);
const CACHEE_DEFAUT = 61;  // médiane mondiale (jeunes et joueurs générés sans trait)

// Calage (tools/notation/ecart-roles.cjs --caler, base mondiale des tests : monde-champ-102, 5 958 joueurs, 25/11/2026).
// A, B : brut → échelle de `rating` (même moyenne et même dispersion sur tout le Monde, tous postes).
// CENTRE_ROLE : écart de profil moyen de chaque rôle sur les joueurs de son poste (somme nulle par poste) ; sans lui,
// le rôle dont les qualités sont naturellement hautes au poste gagnerait toujours (92 % de « Plaqueur » avant).
const CALAGE = Object.freeze({ A: 1.1133, B: -6.49 });
const CENTRE_ROLE = Object.freeze({
  'pilier-conquerant': 4.33, 'pilier-mobile': -5.95, 'pilier-deblayeur': 1.62,
  'talon-lanceur': 4.46, 'talon-gratteur': -2.82, 'talon-perforateur': -1.64,
  'deux-sauteur': 1.29, 'deux-pousseur': 1.99, 'deux-mobile': -3.27,
  'aile-gratteur': 0.84, 'aile-perforateur': -2.6, 'aile-plaqueur': 1.76,
  'huit-porteur': 0.86, 'huit-liant': -2.08, 'huit-meneur': 1.22,
  'demi-eclaireur': -1.46, 'demi-animateur': 1.66, 'demi-tacticien': -0.2,
  'ouvreur-stratege': 1.2, 'ouvreur-attaquant': -1.91, 'ouvreur-buteur': 0.72,
  'centre-perceur': 1.73, 'centre-distributeur': -1.27, 'centre-verrou': -0.46,
  'ailier-finisseur': 2.9, 'ailier-chasseur': -1.12, 'ailier-perforateur': -1.78,
  'arriere-relanceur': 0.44, 'arriere-rempart': -0.24, 'arriere-botteur': -0.21
});

// Famille de jeu d'un joueur (gameplayPosition ou pos).
const FAMILLE_POSTE = Object.freeze({
  'Pilier gauche': 'pilier', 'Pilier droit': 'pilier', Talonneur: 'talonneur', 'Deuxième ligne': 'deuxieme',
  'Troisième ligne': 'aile', 'Troisième ligne aile': 'aile', 'Numéro 8': 'huit', 'Demi de mêlée': 'demi',
  'Demi d’ouverture': 'ouvreur', "Demi d'ouverture": 'ouvreur', Centre: 'centre', Ailier: 'ailier', 'Arrière': 'arriere'
});
const FAMILLES = Object.freeze(Object.keys(POIDS_POSTE));

const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
const nombre = v => typeof v === 'number' && Number.isFinite(v);

function familleDe(p) {
  return FAMILLE_POSTE[p?.gameplayPosition] || FAMILLE_POSTE[p?.pos] || null;
}

// 36 qualités du joueur : attributesV2 (base de référence) ou nativeAttributesV1 (72 chiffres, joueurs générés).
function qualites(p) {
  const a = p?.attributesV2;
  if (a && CLES.every(k => nombre(a[k]))) return a;
  const packed = p?.nativeAttributesV1;
  if (typeof packed === 'string' && /^\d{72}$/.test(packed)) {
    return Object.fromEntries(CLES.map((k, i) => [k, Number(packed.slice(2 * i, 2 * i + 2))]));
  }
  return null;
}

// Poids au poste des 36 qualités (défaut 0,5 pour la lecture du jeu, 0,25 sinon).
function poids(famille) {
  const base = POIDS_POSTE[famille] || {};
  const w = {};
  for (const k of CLES) w[k] = base[k] ?? (LECTURE.has(k) ? DEFAUT_LECTURE : DEFAUT);
  return w;
}

function rolesDe(famille) { return ROLES.filter(r => r[1] === famille); }

// Moyenne pondérée des 36 qualités au poste (famille).
function qualitesPonderees(q, famille) {
  const w = poids(famille);
  let total = 0, somme = 0;
  for (const k of CLES) { total += w[k] * q[k]; somme += w[k]; }
  return total / somme;
}

// Note d'un rôle (objet de ROLES) : ses 4 qualités clés × 2 et 4 utiles × 1.
function noteRole(q, role) {
  let total = 0;
  for (const k of role[3]) total += CLE_ROLE * q[k];
  for (const k of role[4]) total += UTILE_ROLE * q[k];
  return total / (4 * CLE_ROLE + 4 * UTILE_ROLE);
}

// Écart de profil de chaque rôle du poste (non recentré) : note du rôle − moyenne des notes des rôles du poste.
function profilsBruts(q, famille) {
  const roles = rolesDe(famille);
  const notes = roles.map(r => noteRole(q, r));
  const m = notes.reduce((s, v) => s + v, 0) / (notes.length || 1);
  return Object.fromEntries(roles.map((r, i) => [r[0], notes[i] - m]));
}

function cachees(p) {
  const h = p?.hiddenTraitsV2 || {};
  return CACHEES.map(k => nombre(h[k]) ? h[k] : CACHEE_DEFAUT);
}

const echelle = (b, calage = CALAGE) => clamp(Math.round(calage.A * b + calage.B), 15, 99);

// Niveau d'un joueur à un rôle donné (id de ROLES) ou au meilleur rôle de son poste principal.
// Retour : {niveau, brut, role, roleNom, famille, roles: [{id, nom, niveau}]} ou null si qualités/poste inconnus.
function niveauJoueur(p, { roleId = null, famille = null, calage = CALAGE, centres = CENTRE_ROLE } = {}) {
  const q = qualites(p);
  const f = famille || familleDe(p);
  if (!q || !f) return null;
  const [regularite, grandsMatchs] = cachees(p);
  const poste = qualitesPonderees(q, f);
  const profils = profilsBruts(q, f);
  const roles = rolesDe(f).map(r => {
    const profil = clamp(profils[r[0]] - (centres[r[0]] || 0), -PROFIL_MAX, PROFIL_MAX);
    return { id: r[0], nom: r[2], profil, brut: (1 - PART_CACHEES) * (poste + PART_ROLE * profil) + (PART_CACHEES / 2) * (regularite + grandsMatchs) };
  });
  roles.forEach(r => { r.niveau = echelle(r.brut, calage); });
  roles.sort((a, b) => b.brut - a.brut);
  const choisi = roleId ? roles.find(r => r.id === roleId) : roles[0];
  if (!choisi) return null;
  return { niveau: choisi.niveau, brut: choisi.brut, role: choisi.id, roleNom: choisi.nom, famille: f, roles: roles.map(({ id, nom, niveau }) => ({ id, nom, niveau })) };
}

// Calage d'une population (base mondiale) : 1) CENTRE_ROLE = écart de profil moyen de chaque rôle chez les joueurs de
// son poste ; 2) A, B (moyenne et écart-type) pour que le Niveau (meilleur rôle) ait la moyenne et la dispersion de
// `rating`.
function caler(joueurs) {
  const sommes = {}, comptes = {};
  for (const p of joueurs) {
    const q = qualites(p), f = familleDe(p);
    if (!q || !f) continue;
    for (const [id, v] of Object.entries(profilsBruts(q, f))) { sommes[id] = (sommes[id] || 0) + v; comptes[id] = (comptes[id] || 0) + 1; }
  }
  const centres = Object.fromEntries(Object.keys(sommes).map(id => [id, Math.round(100 * sommes[id] / comptes[id]) / 100]));
  const xs = [], ys = [];
  for (const p of joueurs) {
    const n = niveauJoueur(p, { calage: { A: 1, B: 0 }, centres });
    if (!n || !nombre(p.rating)) continue;
    xs.push(n.brut); ys.push(p.rating);
  }
  const m = a => a.reduce((s, v) => s + v, 0) / a.length;
  const mx = m(xs), my = m(ys);
  const sx = Math.sqrt(m(xs.map(v => (v - mx) ** 2))), sy = Math.sqrt(m(ys.map(v => (v - my) ** 2)));
  const A = sy / sx, B = my - A * mx;
  return { A: Math.round(A * 10000) / 10000, B: Math.round(B * 100) / 100, n: xs.length, centres };
}

module.exports = Object.freeze({ CLES, POIDS_POSTE, ROLES, FAMILLES, FAMILLE_POSTE, CALAGE, CENTRE_ROLE, PART_CACHEES, PART_ROLE, PROFIL_MAX, CLE_ROLE, UTILE_ROLE, familleDe, qualites, poids, qualitesPonderees, noteRole, niveauJoueur, caler });
