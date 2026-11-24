'use strict';
// Chaque club du monde porte une deuxième couleur (color2) valide, distincte de sa couleur principale,
// et identique à celle de la présentation Godot (ui/couleurs_clubs.json) : aucun écran ne change.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const lire = f => JSON.parse(fs.readFileSync(path.join(root, f), 'utf8'));
const HEX = /^#[0-9a-f]{6}$/i;
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const distance = (a, b) => Math.hypot(...rgb(a).map((v, i) => v - rgb(b)[i]));
const sidecar = lire('native/godot/ui/couleurs_clubs.json').couleurs;

const sources = {
  'catalogue.json': lire('data/world/catalogue.json').clubs,
  'registre compilé': lire('native/engine/world-registry.json').clubs,
  pacific: lire('native/engine/world-pacific-extension.json').clubs,
  japan: lire('native/engine/world-japan-extension.json').clubs,
  nationale: lire('native/engine/world-nationale-extension.json').clubs,
  champ: lire('native/engine/world-champ-extension.json').clubs,
};
assert.equal(sources['catalogue.json'].length, 58);
assert.equal(sources['registre compilé'].length, 58);

for (const [nom, clubs] of Object.entries(sources)) {
  for (const c of clubs) {
    const ou = `${nom} / ${c.slug}`;
    assert.match(c.color, HEX, `${ou} : couleur principale`);
    assert.match(c.color2 ?? '', HEX, `${ou} : deuxième couleur absente ou invalide`);
    assert.notEqual(c.color2.toLowerCase(), c.color.toLowerCase(), `${ou} : deuxième couleur identique à la principale`);
    assert.ok(distance(c.color, c.color2) >= 60, `${ou} : deuxième couleur trop proche de la principale`);
    assert.equal(c.color2.toLowerCase(), sidecar[c.slug].toLowerCase(), `${ou} : écart avec ui/couleurs_clubs.json`);
  }
}
const cat = sources['catalogue.json'], reg = new Map(sources['registre compilé'].map(c => [c.slug, c]));
for (const c of cat) assert.equal(reg.get(c.slug).color2, c.color2, `${c.slug} : registre non régénéré (node scripts/build-world-registry.cjs)`);
assert.equal(new Set(cat.map(c => c.color2)).size > 4, true, 'palette secondaire variée');
console.log('Deuxième couleur des clubs : OK (' + Object.values(sources).reduce((n, l) => n + l.length, 0) + ' lignes)');
