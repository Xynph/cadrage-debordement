'use strict';
// Tour des écrans filmé (scripts/ecrans-filmes.ps1) : arguments de la préparation de carrière, liste des
// écrans alignée sur tests/small-window-geometry.gd, arguments transmis par le lanceur, scripts PowerShell
// lisibles, puis logique de l'outil Godot en --headless (tests/godot-ecrans-filmes.gd). Le tour lui-même
// demande un affichage réel : il se lance à la main (voir l'en-tête de scripts/ecrans-filmes.ps1).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const racine = path.resolve(__dirname, '..');
const lire = relatif => fs.readFileSync(path.join(racine, relatif), 'utf8');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const routesDe = (texte, nom) => {
  const bloc = texte.match(new RegExp('const ' + nom + '\\s*:?=\\s*\\[([^\\]]*)\\]'));
  assert.ok(bloc, nom + ' introuvable');
  return [...bloc[1].matchAll(/"([^"]*)"/g)].map(m => m[1]);
};

test('Écrans filmés : la préparation refuse un export relatif et lit club, graine et matchs', () => {
  const { lireOptions } = require('../tools/ecrans-filmes/preparer-carriere.cjs');
  const sortie = path.resolve('/tmp/ecrans/carriere.json');
  assert.deepEqual(lireOptions([sortie, '--club', '7', '--graine', '11', '--matchs', '0']), { sortie, club: 7, graine: 11, matchs: 0 });
  assert.deepEqual(lireOptions([sortie]), { sortie, club: 102, graine: 4242, matchs: 1 });
  assert.throws(() => lireOptions(['relatif.json']), /absolu/);
  assert.throws(() => lireOptions([sortie, '--matchs', 'deux']), /entier/);
  assert.throws(() => lireOptions([sortie, 'en-trop.json']), /inconnu/);
});

test('Écrans filmés : la copie des écrans suit tests/small-window-geometry.gd', () => {
  const geometrie = routesDe(lire('tests/small-window-geometry.gd'), 'ROUTES');
  const copie = routesDe(lire('tools/ecrans-filmes/visite.gd'), 'ROUTES_GEOMETRIE');
  assert.ok(geometrie.length >= 20);
  assert.deepEqual(copie, geometrie, 'mettre à jour ROUTES_GEOMETRIE dans tools/ecrans-filmes/visite.gd');
});

test('Écrans filmés : le lanceur ne passe que des arguments connus de visite.gd', () => {
  const lanceur = lire('scripts/ecrans-filmes.ps1');
  const outil = lire('tools/ecrans-filmes/visite.gd');
  const apres = lanceur.slice(lanceur.indexOf("'--ecrans-filmes'"));
  const passes = [...new Set([...apres.matchAll(/'(--[a-z-]+)'/g)].map(m => m[1]))];
  assert.ok(passes.includes('--sortie') && passes.includes('--tailles') && passes.includes('--ecrans'), passes.join(' '));
  for (const arg of passes) assert.ok(outil.includes('"' + arg + '"'), arg + ' inconnu de visite.gd');
  assert.match(lanceur, /bureau-cache\.ps1/);
  assert.match(lanceur, /'--audio-driver', 'Dummy'/);
  assert.match(lanceur, /tools\\ecrans-filmes\\visite\.gd/);
  // Le match filmé garde le même lanceur commun.
  assert.match(lire('scripts/match-filme.ps1'), /Invoke-GodotSurBureauCache/);
});

test('Écrans filmés : scripts PowerShell sans erreur de syntaxe (BOM pour PowerShell 5.1)', { skip: process.platform !== 'win32' && 'Windows seulement' }, () => {
  const fichiers = ['scripts/bureau-cache.ps1', 'scripts/ecrans-filmes.ps1', 'scripts/match-filme.ps1'].map(f => path.join(racine, f));
  for (const f of fichiers) assert.deepEqual([...fs.readFileSync(f).subarray(0, 3)], [0xef, 0xbb, 0xbf], f + ' : BOM UTF-8 attendu (accents sous PowerShell 5.1)');
  const commande = fichiers.map(f => `$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('${f.replace(/'/g, "''")}',[ref]$null,[ref]$e); if ($e.Count) { $e | ForEach-Object { Write-Output ('${path.basename(f)} : ' + $_.Message) } }`).join('; ');
  const run = spawnSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', commande], { encoding: 'utf8', windowsHide: true, timeout: 60000 });
  assert.ifError(run.error);
  assert.equal((run.stdout || '').trim(), '', run.stdout);
  assert.equal(run.status, 0, run.stderr);
});

test('Écrans filmés : arguments, liste des écrans, nommage et débordements de l’outil Godot', { skip: !godot && 'Godot SDK required' }, () => {
  const run = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.join(racine, 'native/godot'), '--script', path.join(__dirname, 'godot-ecrans-filmes.gd')], {
    encoding: 'utf8', windowsHide: true, timeout: 120000,
  });
  const output = `${run.stdout || ''}${run.stderr || ''}`;
  assert.ifError(run.error);
  assert.equal(run.status, 0, output);
  assert.match(output, /ECRANS_FILMES_CHECKS .*"failures":\[\]/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
