'use strict';
// Ouverture du jeu (native/godot/intro/) : trois lancements du vrai jeu, sans carrière.
//   premier : 1er lancement, séquence complète sans passage possible, phrase mémorisée ;
//   second  : même profil, séquence complète, une touche passe chaque carte, autre phrase ;
//   ancien  : ancien profil portant encore intro=short : séquence complète quand même ;
//   court   : raccourci de test CD_GODOT_INTRO_MODE=courte, titre seul ;
//   qa      : profil de test sans CD_GODOT_INTRO, aucune introduction.
// Chaque phase vérifie aussi, image par image, qu'aucun texte de deux cartes n'est lisible à la fois.
// Rendu : headless par défaut ; CD_INTRO_GRAPHICS=1 pour un rendu fenêtré (captures avec CD_INTRO_CAPTURES).
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-intro : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-intro-'));
const profile = path.join(directory, 'profil');
fs.mkdirSync(profile, {recursive: true});
const graphics = process.env.CD_INTRO_GRAPHICS === '1';
for (const phase of ['premier', 'second', 'ancien', 'court', 'qa']) {
  if (phase === 'ancien') {
    fs.mkdirSync(path.join(profile, 'PrototypeGodot'), {recursive: true});
    fs.writeFileSync(path.join(profile, 'PrototypeGodot', 'interface.json'), JSON.stringify({version: 1, intro: 'short'}) + '\n');
  }
  const env = {...process.env, CD_GODOT_SELF_TEST: '0', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profile, CD_INTRO_PHASE: phase};
  if (phase === 'court') env.CD_GODOT_INTRO_MODE = 'courte';
  if (phase === 'qa') delete env.CD_GODOT_INTRO; else env.CD_GODOT_INTRO = '1';
  const result = spawnSync(godot, [...(graphics ? [] : ['--headless']), '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-intro.gd')], {env, encoding: 'utf8', windowsHide: true, timeout: 240000});
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(directory, phase + '.log'), output);
  console.log('--- ' + phase + '\n' + output.split('\n').filter(line => /INTRO|FAIL|ERROR/.test(line)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, phase + ' :\n' + output);
  assert.match(output, /INTRO \d+ contrôles, 0 échecs/, phase);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error|SHADER ERROR/, phase);
}
console.log('Journaux de l’ouverture : ' + directory);
