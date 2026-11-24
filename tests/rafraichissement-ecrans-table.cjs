'use strict';
// Rafraîchissement par écran (native/godot/ui/screen_refresh.gd) : la table section → écrans
// (native/godot/ui/screen_refresh.json) reste à jour. Pour chaque section, les fichiers GDScript qui citent son nom
// sont exactement ceux notés dans « lecteurs » : un nouveau lecteur fait échouer ce test tant que la liste des
// écrans n'a pas été revue (sinon un écran pourrait garder une valeur périmée après une réponse du moteur).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { NESTED } = require('../native/engine/model-delta.cjs');

const godot = path.resolve(__dirname, '..', 'native', 'godot');
const table = JSON.parse(fs.readFileSync(path.join(godot, 'ui', 'screen_refresh.json'), 'utf8'));
const moduleGodot = fs.readFileSync(path.join(godot, 'ui', 'screen_refresh.gd'), 'utf8');
// Le module lit la table sans citer de section ; il est exclu du relevé.
const EXCLUS = new Set(['ui/screen_refresh.gd']);
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
  if (entry.name.startsWith('.')) return [];
  const full = path.join(dir, entry.name);
  return entry.isDirectory() ? walk(full) : entry.name.endsWith('.gd') ? [path.relative(godot, full).split(path.sep).join('/')] : [];
});
// La coque main.gd est découpée en modules statiques main_*.gd (même lecteur : la coque) ; ils comptent pour main.gd.
const COQUE = /^main_[a-z_]+\.gd$/;
const scripts = walk(godot).filter(file => !EXCLUS.has(file)).map(file => ({ file: COQUE.test(file) ? 'main.gd' : file, text: fs.readFileSync(path.join(godot, file), 'utf8') }));
const nested = (moduleGodot.match(/const NESTED := \[([^\]]*)\]/) || [])[1] || '';
const nestedGodot = [...nested.matchAll(/"([^"]+)"/g)].map(m => m[1]);

test('la table du rafraîchissement par écran se lit et nomme des écrans existants', () => {
  assert.ok(table.sections && typeof table.sections === 'object', 'sections');
  assert.ok(Array.isArray(table.toujours_complet), 'toujours_complet');
  const routes = ['main.gd', ...fs.readdirSync(godot).filter(f => COQUE.test(f)), 'ui/immersive08/shell.gd', 'ui/immersive08/club_sheet_canvas.gd'].map(f => fs.readFileSync(path.join(godot, f), 'utf8')).join('\n');
  const known = screen => screen === '*' || routes.includes('"' + screen + '"');
  for (const screen of table.toujours_complet) assert.ok(known(screen), 'écran inconnu : ' + screen);
  for (const [id, entry] of Object.entries(table.sections)) {
    assert.ok(Array.isArray(entry.ecrans) && Array.isArray(entry.lecteurs), id + ' : ecrans et lecteurs');
    for (const screen of entry.ecrans) assert.ok(known(screen), id + ' : écran inconnu ' + screen);
    const [head, name] = id.split('.');
    assert.ok(name === undefined ? !NESTED.has(head) : nestedGodot.includes(head), id + ' : découpage différent de celui du moteur (model-delta.cjs)');
  }
});

test('sous-sections du moteur connues du module Godot', () => {
  for (const key of NESTED) assert.ok(nestedGodot.includes(key), 'NESTED de screen_refresh.gd sans ' + key);
});

test('chaque section de la table a exactement les lecteurs notés (sinon revoir ses écrans)', () => {
  const drift = [];
  for (const [id, entry] of Object.entries(table.sections)) {
    const token = id.split('.').pop();
    const pattern = new RegExp('\\b' + token + '\\b');
    const found = [...new Set(scripts.filter(s => pattern.test(s.text)).map(s => s.file))].sort();
    const noted = [...entry.lecteurs].sort();
    if (JSON.stringify(found) !== JSON.stringify(noted)) drift.push(id + '\n  lu par : ' + found.join(', ') + '\n  noté   : ' + noted.join(', '));
  }
  assert.deepEqual(drift, [], 'Lecteurs changés : vérifier les écrans de ces sections dans native/godot/ui/screen_refresh.json\n' + drift.join('\n'));
});
