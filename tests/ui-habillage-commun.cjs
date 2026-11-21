'use strict';
// Habillage commun du bureau du manager : une seule source de jetons (encre, or) et trois rayons d'angle.
// Contrôle statique des sources Godot, sans lancer le moteur.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ui = path.resolve(__dirname, '..', 'native', 'godot', 'ui');
const read = file => fs.readFileSync(path.join(ui, file), 'utf8');
const skins = {
  base: read('game_skin.gd'),
  carnet: read('carnet_skin.gd'),
  contextual: read(path.join('contextual', 'skin.gd'))
};

// 1. Jetons uniques : définis une fois dans game_skin.gd.
const constant = (source, name) => {
  const match = source.match(new RegExp('^const ' + name + '\\s*:?=\\s*(.+)$', 'm'));
  return match ? match[1].trim() : null;
};
// Charte finale (ui/charte.gd) : game_skin.gd ne redéfinit plus de couleur, il pointe sur les jetons.
assert.equal(constant(skins.base, 'INK'), 'Charte.IVOIRE', 'encre commune = Charte.IVOIRE');
assert.equal(constant(skins.base, 'GOLD'), 'Charte.OR', 'or commun = Charte.OR sur fond sombre');
assert.equal(constant(skins.base, 'PAPER_GOLD'), 'Charte.OR_ENCRE', 'or du papier = Charte.OR_ENCRE');
for (const name of ['BG', 'PANEL', 'LINE', 'MUTED', 'GOOD']) {
  assert.match(constant(skins.base, name) || '', /^Charte\.\w+$/, `${name} pointe sur un jeton de la charte`);
}
assert.ok(!/Color\("[0-9a-f]{6}"\)/i.test(skins.carnet), 'carnet : aucune couleur en dur (jetons de la charte)');
assert.equal(constant(skins.contextual, 'TEXT'), 'Charte.CREME', 'salles du club : encre crème de la charte');
assert.equal(constant(skins.contextual, 'GOLD'), 'Charte.DORE', 'salles du club : doré de la charte');
assert.equal(constant(skins.contextual, 'MUTED'), 'Charte.GRIS_VERT', 'salles du club : texte secondaire de la charte');
assert.equal(constant(skins.carnet, 'GOLD'), 'Base.PAPER_GOLD', 'carnet : or du papier repris');
assert.equal(constant(skins.carnet, 'WHITE'), 'Base.INK', 'carnet : encre claire reprise');
const forbidden = ['f5f4ec', 'ddbd80', '82592e', 'f1f0df', 'd8c183', 'c0c9b5', 'bca36a'];
for (const [name, source] of Object.entries({carnet: skins.carnet, contextual: skins.contextual})) {
  for (const hex of forbidden) assert.ok(!source.toLowerCase().includes(hex), `${name} : ${hex} redéfini hors de game_skin.gd`);
}
for (const file of [path.join('contextual', 'director.gd'), path.join('contextual', 'locker_view.gd')]) {
  for (const hex of ['f1f0df', 'd8c183']) assert.ok(!read(file).includes(hex), `${file} : ancien ${hex}`);
}

// 2. Trois rayons seulement, appliqués par la fonction commune.
const radii = skins.base.match(/^const RADII\s*:?=\s*\{([^}]*)\}/m);
assert.ok(radii, 'table RADII présente');
const values = {};
for (const [, key, value] of radii[1].matchAll(/"(\w+)":\s*(RADIUS_\w+)/g)) values[key] = constant(skins.base, value);
assert.deepEqual(values, {chip: 'Charte.RAYON_PETIT', control: 'Charte.RAYON_CARTE', panel: 'Charte.RAYON_PANNEAU'}, 'rayons de la charte (6, 12, 18)');
for (const [name, source] of Object.entries(skins)) {
  const direct = source.split('\n').filter(line => /\bT\.box\(/.test(line) && !/return T\.box\(color, radius\(kind\), border\)/.test(line));
  assert.deepEqual(direct, [], `${name} : rayon codé en dur via T.box`);
  for (const [, kind] of source.matchAll(/\bbox\([^\n]*?,\s*"(\w+)"/g)) {
    assert.ok(['chip', 'control', 'panel'].includes(kind), `${name} : rôle de rayon inconnu ${kind}`);
  }
}

// 3. Préparation : les trois charges en cartes avec leur effet, une seule barre d'onglets.
const preparation = read('preparation_view.gd');
for (const mode of ['repos', 'normal', 'intense']) {
  assert.match(preparation, new RegExp('\\["' + mode + '", "[^"]+", "[^"]{12,}"'), `charge ${mode} : titre et effet`);
}
assert.equal((preparation.match(/\.name = "PreparationTabs"/g) || []).length, 1, 'une seule barre d’onglets');
assert.match(preparation, /ChapterSubnavigation/, 'raccourcis du chapitre regroupés dans la barre');
assert.match(preparation, /PreparationBanner/, 'bannière pleine largeur');

// 4. « Dernières décisions » : masqué tant qu'aucune décision n'est prise.
assert.match(read('decision_feedback.gd'), /button\.visible = not _receipts\.is_empty\(\)/, 'bouton masqué quand vide');

console.log('ui-habillage-commun : jetons, rayons, Préparation et pied de page conformes.');
