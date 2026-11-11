'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');

const GODOT = path.resolve(__dirname, '../native/godot');

// La pelouse moderne doit garder exactement la couleur réglée de la pelouse d'origine.
test('Pelouse moderne : bloc de couleur copie conforme du shader d’origine', () => {
  const original = fs.readFileSync(path.join(GODOT, 'shaders/stadium_surface.gdshader'), 'utf8').replace(/\r\n/g, '\n');
  const modern = fs.readFileSync(path.join(GODOT, 'shaders/stadium_surface_moderne.gdshader'), 'utf8').replace(/\r\n/g, '\n');
  const body = original.slice(original.indexOf('void fragment() {\n') + 'void fragment() {\n'.length);
  const albedo = body.slice(0, body.indexOf('\tROUGHNESS'));
  assert.match(albedo, /ALBEDO = grass \*/);
  assert.ok(modern.includes('// --- début copie conforme de stadium_surface.gdshader ---\n' + albedo + '\t// --- fin copie conforme ---'),
    'le bloc ALBEDO de stadium_surface_moderne.gdshader doit rester identique à stadium_surface.gdshader');
  const hash = original.match(/float hash21[\s\S]*?\n}\n/)[0];
  assert.ok(modern.includes(hash), 'hash21 identique');
  assert.match(modern, /uniform float micro_detail : hint_range\(0\.0, 0\.2\) = 0\.1;/);
});

test('Le projet reste en gl_compatibility par défaut', () => {
  const project = fs.readFileSync(path.join(GODOT, 'project.godot'), 'utf8');
  assert.match(project, /^renderer\/rendering_method="gl_compatibility"$/m);
});

test('Rendu moderne du match : inactif sous gl_compatibility, réglages par niveau sous Forward+ simulé', {
  skip: !process.env.CD_GODOT_EXE && 'Godot SDK required',
}, () => {
  const project = process.env.CD_MATCH_PROJECT || GODOT;
  const env = {...process.env};
  for (const name of ['CD_MATCH_RENDU', 'CD_MATCH_RENDU_TONEMAP', 'CD_MATCH_GESTES']) delete env[name];
  const run = spawnSync(process.env.CD_GODOT_EXE, ['--headless', '--path', project, '--script', path.resolve(__dirname, 'godot-match-rendu.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 120000, env,
  });
  const output = (run.stdout || '') + (run.stderr || '');
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.match(output, /MATCH_RENDU_CHECKS {"cascades_m":.*"failures":\[\],"method":"gl_compatibility"}/);
});
