'use strict';
// Match filmé (scripts/match-filme.ps1) : logique de l'outil Godot (arguments, images noires,
// planche-contact) et arguments de la préparation de carrière. Le film lui-même demande un
// affichage réel : il se lance à la main (voir l'en-tête de scripts/match-filme.ps1).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { test } = require('node:test');

const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;

test('Match filmé : la préparation refuse un export relatif et lit club et graine', () => {
  const { lireOptions } = require('../tools/match-filme/preparer-carriere.cjs');
  const sortie = path.resolve('/tmp/film/carriere.json');
  assert.deepEqual(lireOptions([sortie, '--club', '7', '--graine', '11']), { sortie, club: 7, graine: 11 });
  assert.deepEqual(lireOptions([sortie]), { sortie, club: 102, graine: 4242 });
  assert.throws(() => lireOptions(['relatif.json']), /absolu/);
  assert.throws(() => lireOptions([sortie, '--club', '-1']), /entier/);
});

test('Match filmé : arguments, images noires et planche-contact de l’outil Godot', { skip: !godot && 'Godot SDK required' }, () => {
  const run = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.join(__dirname, 'godot-match-filme.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 120000,
  });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.match(output, /MATCH_FILME_CHECKS .*"failures":\[\]/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
