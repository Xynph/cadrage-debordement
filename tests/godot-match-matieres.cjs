'use strict';
// Matières du match 3D (option B de l'essai du 24/11/2026) : pelouse et tissu des tenues.
// Non-régression : la logique des couleurs des clubs dans athlete_kit.gdshader reste
// celle d'avant les matières (empreinte figée), le tissu ne touche qu'au relief et à la
// luminance ; textures importées (res://) avec mipmaps ; vérification dans Godot.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');

const GODOT = path.resolve(__dirname, '../native/godot');
const read = file => fs.readFileSync(path.join(GODOT, file), 'utf8').replace(/\r\n/g, '\n');

test('Tenues : logique des couleurs des clubs inchangée', () => {
  const shader = read('shaders/athlete_kit.gdshader');
  const body = shader.split('void fragment() {\n')[1];
  const end = body.indexOf('\t// --- fin de la logique des couleurs ---');
  assert.ok(end > 0, 'repère de fin de la logique des couleurs');
  const hash = crypto.createHash('sha256').update(body.slice(0, end)).digest('hex');
  assert.equal(hash, 'fc1abdc5c19a21e5a934395334b74c3cec3fe73d9aa603f38a5862dc65b8c2d1',
    'la logique des zones et couleurs des tenues ne doit pas changer');
  const after = body.slice(end);
  // Le tissu ne fait que moduler la luminance (multiplication par un scalaire).
  for (const line of after.split('\n').filter(l => /\bcolor\s*[*+-]?=/.test(l))) {
    assert.match(line, /^\s*color \*= 1\.0 [+-] /, 'modulation scalaire seulement : ' + line.trim());
  }
  for (const name of ['jersey_color', 'panel_color', 'trim_color', 'shorts_color', 'socks_color']) {
    assert.ok(!after.includes(name), name + ' non relu après la logique des couleurs');
  }
});

test('Matières : textures importées avec mipmaps, plus de variable d’essai', () => {
  for (const file of ['pelouse_hauteur.png', 'pelouse_normal.png', 'tissu_maille.png']) {
    const imp = read('art/matieres/' + file + '.import');
    assert.match(imp, /^mipmaps\/generate=true$/m, file + ' : mipmaps');
    assert.match(imp, /^compress\/mode=0$/m, file + ' : sans perte');
  }
  for (const file of ['match_matieres.gd', 'match_view.gd', 'match_vue_stade.gd', 'match_athlete.gd', 'shaders/stadium_surface.gdshader', 'shaders/athlete_kit.gdshader']) {
    assert.ok(!read(file).includes('CD_ESSAI_MATIERES'), file);
  }
});

test('Matières dans Godot : couleurs des clubs et textures branchées', {
  skip: !process.env.CD_GODOT_EXE && 'Godot SDK required',
}, () => {
  const project = process.env.CD_MATCH_PROJECT || GODOT;
  const run = spawnSync(process.env.CD_GODOT_EXE, ['--headless', '--path', project, '--script', path.resolve(__dirname, 'godot-match-matieres.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 120000,
  });
  const output = (run.stdout || '') + (run.stderr || '');
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
  assert.match(output, /MATCH_MATIERES_CHECKS {"checks":\d+,"failures":\[\]}/);
});
