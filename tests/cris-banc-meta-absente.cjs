'use strict';
// Menu « Cris » du direct, sous-liste « À un joueur » (native/godot/ui/contextual/match_banc_fm.gd) : à chaque ouverture,
// les 45 ronds des cris (15 joueurs × 3) sont neufs et n'ont pas encore la méta « allume ». En Godot 4,
// `get_meta(cle, null)` sur une méta absente n'utilise pas le défaut : il écrit « The object does not have any 'meta'
// values with the key 'allume' » (45 erreurs par ouverture, 135 dans un journal de godot-cris-banc). La lecture doit
// passer par has_meta (ou un défaut non nul).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const fichier = path.resolve(__dirname, '..', 'native', 'godot', 'ui', 'contextual', 'match_banc_fm.gd');

test('les ronds des cris à un joueur ne lisent jamais une méta absente avec un défaut nul', () => {
  const lignes = fs.readFileSync(fichier, 'utf8').split(/\r?\n/);
  const fautives = lignes
    .map((ligne, i) => ({ ligne: ligne.trim(), numero: i + 1 }))
    .filter(({ ligne }) => !ligne.startsWith('#') && /\.get_meta\(\s*"[^"]+"\s*,\s*null\s*\)/.test(ligne));
  assert.deepEqual(fautives, [], 'get_meta(…, null) écrit une erreur Godot quand la méta manque');
});
