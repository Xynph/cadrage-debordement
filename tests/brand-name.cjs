'use strict';
// Renommage « Rugby Legacy 27 » : le nom affiché et distribué change, les
// carrières existantes restent lisibles au même endroit, sans conversion.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const brand = require('../scripts/rename-brand.cjs');

// 1. Le périmètre renommé ne contient plus l'ancien nom et le script est idempotent.
const state = brand.run({ check: true });
assert.deepEqual(state.changed, [], 'Fichiers à renommer : relancer node scripts/rename-brand.cjs');
assert.deepEqual(state.leftovers, [], 'Ancien nom restant dans le périmètre');
assert.equal(brand.transform('tout l’univers d’Oval Legacy'), 'tout l’univers de Rugby Legacy');
assert.equal(brand.transform("d'Oval Legacy 27"), 'de Rugby Legacy 27');
assert.equal(brand.transform('OVAL LEGACY 27'), 'RUGBY LEGACY 27');
assert.equal(brand.transform('Oval Legacy 27 — Rugby Manager'), 'Rugby Legacy 27');
assert.equal(brand.transform('OvalLegacy27-PrototypeGodot-Windows-x64.zip'), 'RugbyLegacy27-Windows-x64.zip');
assert.equal(brand.transform(brand.transform('Oval Legacy')), 'Rugby Legacy');
// Les identifiants de compatibilité ne sont jamais réécrits.
for (const kept of ['oval-legacy-fictional-calendar', 'cadrage-debordement-save', 'CadrageDebordement/PrototypeGodot', 'Xynph/cadrage-debordement'])
  assert.equal(brand.transform(kept), kept);
for (const outside of ['native/engine/worker.cjs', 'dist/saves.js', 'DEVELOPPEMENT.md', 'native/godot/art/immersive08/PROVENANCE.txt', 'native/godot/guide/assets/voice/CREDITS.txt', 'scripts/build-native-sounds.cjs'])
  assert.equal(brand.inScope(outside), false, outside + ' doit rester hors périmètre');

// 2. Nom affiché, exécutable et identité.
const project = read('native/godot/project.godot');
assert.match(project, /^config\/name="Rugby Legacy 27"$/m);
assert.match(project, /^config\/icon="res:\/\/branding\/rugby-legacy-27-icon\.png"$/m);
for (const asset of ['rugby-legacy-27-logo.png', 'rugby-legacy-27-icon.png'])
  assert.ok(fs.statSync(path.join(root, 'native/godot/branding', asset)).size > 10000, asset);
const build = read('scripts/build-godot-prototype.py');
assert.match(build, /app \/ "RugbyLegacy27\.exe"/);
assert.match(build, /"RugbyLegacy27-Windows-x64\.zip"/);

// 3. Invariants de sauvegarde : même dossier de profil, mêmes formats.
assert.match(project, /^config\/use_custom_user_dir=true$/m);
assert.match(project, /^config\/custom_user_dir_name="CadrageDebordement\/PrototypeGodot"$/m,
  'Le profil Windows ne doit pas changer de dossier sans migration testée');
assert.match(read('native/engine/worker.cjs'), /'CadrageDebordement','PrototypeGodot'/);
assert.match(build, /%APPDATA%\/CadrageDebordement\/PrototypeGodot/);
assert.match(read('dist/saves.js'), /SAVE_FORMAT='cadrage-debordement-save'/);
assert.match(read('native/engine/custom-competition.cjs'), /'oval-legacy-fictional-calendar'/);

// 4. Une carrière créée dans l'ancien dossier de profil est relue telle quelle
//    par le moteur renommé : même club, même effectif, mêmes octets sur disque.
const worker = path.join(root, 'native/engine/worker.cjs');
const profile = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-profil-')), 'CadrageDebordement', 'PrototypeGodot');
fs.mkdirSync(profile, { recursive: true });
function session(commands) {
  const input = commands.map((command, index) => JSON.stringify({ id: index + 1, ...command })).join('\n') + '\n';
  const child = spawnSync(process.execPath, [worker, '--data-dir', profile],
    { input, encoding: 'utf8', timeout: 120000, maxBuffer: 256 * 1024 * 1024, env: { ...process.env, CD_GODOT_SEED: '27' } });
  assert.equal(child.status, 0, child.stderr);
  const replies = child.stdout.trim().split('\n').map(line => JSON.parse(line));
  for (const reply of replies) assert.equal(reply.ok, true, reply.error);
  return replies;
}
const digest = () => crypto.createHash('sha256').update(fs.readFileSync(path.join(profile, 'donnees.json'))).digest('hex');
const created = session([{ command: 'new_career', payload: { club: 29, mode: 'common' } }, { command: 'shutdown', payload: {} }])[0].model;
assert.ok(created.club?.name && created.squad.length >= 23, 'Carrière de référence créée');
const before = digest();
const reopened = session([{ command: 'snapshot', payload: {} }, { command: 'shutdown', payload: {} }])[0].model;
assert.equal(reopened.club.name, created.club.name, 'La carrière existante doit se rouvrir sur le même club');
assert.deepEqual(reopened.squad.map(player => player.id), created.squad.map(player => player.id));
assert.equal(digest(), before, 'Rouvrir une carrière ne doit pas réécrire le profil');
assert.deepEqual(fs.readdirSync(path.dirname(profile)), ['PrototypeGodot'], 'Aucun second profil ne doit apparaître');
fs.rmSync(path.dirname(path.dirname(profile)), { recursive: true, force: true });
console.log('brand-name : nom Rugby Legacy 27, exécutable RugbyLegacy27.exe, profil et formats de sauvegarde inchangés.');
