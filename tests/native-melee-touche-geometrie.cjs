'use strict';
// Mêlée et touche de la vue 3D, sans Godot (18/11/2026) : géométrie lue dans les constantes de
// native/godot/match_formations.gd (les mêmes calculs que Formations.calculer), câblage de la
// touche du direct sans gestes (match_gestes.gd réduit à la touche, utilisé par match_view.gd).
// Les mesures sur les os des modèles sont dans tests/godot-match-formations.gd (Godot requis).
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const godot = path.resolve(__dirname, '../native/godot');
const lire = name => fs.readFileSync(path.join(godot, name), 'utf8');
const formations = lire('match_formations.gd');

function constante(nom) {
  const m = formations.match(new RegExp(`^const ${nom} := (?:Vector2\\(([-\\d.]+), ([-\\d.]+)\\)|([-\\d.]+))`, 'm'));
  assert.ok(m, `constante ${nom} absente de match_formations.gd`);
  return m[3] !== undefined ? Number(m[3]) : {x: Number(m[1]), y: Number(m[2])};
}
function melee() {
  const bloc = formations.match(/^const MELEE: Array\[Vector2\] = \[([\s\S]*?)\]/m);
  assert.ok(bloc, 'tableau MELEE absent');
  return [...bloc[1].matchAll(/Vector2\(([-\d.]+), ([-\d.]+)\)/g)].map(m => ({x: Number(m[1]), y: Number(m[2])}));
}

const MELEE = melee();
const DECALAGE = constante('DECALAGE_TETES');
const RAYON = constante('TETE_RAYON');
const DEMI = constante('DEMI_INTRO');
const DEVANT = constante('BALLON_DEVANT');
const BAS_MIN = constante('BALLON_BAS_MIN');
const BAS_MAX = constante('BALLON_BAS_MAX');

// Places d'une mêlée au centre (0, 0), le camp 0 introduit (même formule que _melee).
function place(side, slot) {
  const s = side === 0 ? 1 : -1;
  const m = MELEE[slot];
  return {x: -s * m.x, y: s * (m.y - DECALAGE)};
}

test('Mêlée : têtes des premières lignes en alternance, jamais l\'une dans l\'autre', () => {
  assert.equal(MELEE.length, 8);
  const tetes = [];
  for (const side of [0, 1]) for (const slot of [0, 1, 2]) tetes.push({side, slot, ...place(side, slot)});
  tetes.sort((a, b) => a.y - b.y);
  for (let i = 1; i < tetes.length; i++) {
    assert.notEqual(tetes[i].side, tetes[i - 1].side, 'aucune tête à côté de celle d\'un partenaire (loi 19)');
    assert.ok(tetes[i].y - tetes[i - 1].y > 2 * RAYON, `têtes adverses voisines à ${(tetes[i].y - tetes[i - 1].y).toFixed(3)} m (> ${2 * RAYON} m)`);
  }
  // Pilier gauche à l'extérieur du pilier droit adverse.
  assert.ok(place(0, 0).y < place(1, 2).y && place(1, 0).y > place(0, 2).y);
  // Pieds des premières lignes de part et d'autre du ballon, 2,4 m d'écart (têtes à la ligne du ballon).
  for (const slot of [0, 1, 2]) assert.ok(Math.abs(place(1, slot).x - place(0, slot).x - 2.4) < 1e-9);
});

test('Mêlée : le demi accroupi tient le ballon bas, hors du paquet, à l\'entrée du tunnel', () => {
  const demi = {x: -DEMI.x, y: DEMI.y};
  const ballon = {x: demi.x, y: demi.y + DEVANT};  // tourné vers le tunnel (+y pour le camp 0)
  const pilier = place(0, 0);
  assert.ok(demi.y < 0, 'introduction du côté du pilier gauche');
  assert.ok(ballon.y < pilier.y - 0.3, `ballon hors du corps du pilier gauche (${ballon.y.toFixed(2)} contre ${pilier.y.toFixed(2)})`);
  assert.ok(Math.hypot(ballon.x, ballon.y) < 1.4, 'ballon à l\'entrée du tunnel');
  assert.ok(BAS_MIN >= 0.25 && BAS_MAX <= 0.65 && BAS_MIN < BAS_MAX, 'ballon à hauteur de genoux');
  const posture = formations.match(/"introduction": \[([-\d.]+), ([-\d.]+), ([-\d.]+)\]/);
  assert.ok(posture && Number(posture[2]) <= -0.25, 'demi accroupi (bassin abaissé de 25 cm au moins)');
  assert.match(formations, /func tient_ballon\(id: String\) -> bool:/);
  assert.match(lire('match_view.gd'), /_formations\.tient_ballon\(id\)/, 'la vue laisse le ballon au demi qui introduit');
});

test('Touche du direct sans gestes : lancer du talonneur et saut, par match_gestes.gd', () => {
  const gestes = lire('match_gestes.gd');
  const vue = lire('match_view.gd');
  assert.match(gestes, /func _init\(owner: Node3D, seulement_touche: bool = false\)/);
  assert.match(gestes, /touche_seule and kind not in \["lineout", "setpiece-win", "setpiece-loss"\]/, 'touche seule : rien d\'autre que la touche');
  assert.match(vue, /var _touche_directe: RefCounted = Gestes\.new\(self, true\)/);
  assert.match(vue, /return _gestes if _gestes != null else _touche_directe/);
  assert.match(vue, /mise_en_scene\(\)\.observe\(/);
  assert.match(vue, /mise_en_scene\(\)\.pose\(\)/);
  assert.match(vue, /mise_en_scene\(\)\.holding_tick\(\)/, 'le direct attend le lancer, comme une passe longue');
  // Le recadrage des gestes reste réservé aux gestes complets.
  assert.match(gestes, /if not FRAME_MIN\.has\(mode\) or touche_seule:/);
  // Plus aucun appel direct à _gestes pour mettre en scène dans le rendu image par image.
  assert.doesNotMatch(vue, /_gestes != null and _gestes\.stages/);
});
