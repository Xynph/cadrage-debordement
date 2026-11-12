'use strict';
// Détection uniforme du SDK Godot pour les suites natives.
// Les suites lisent tantôt CD_GODOT_EXE, tantôt CD_GODOT_EXECUTABLE. Préchargé par
//   NODE_OPTIONS="--require=<dépôt>/ci/godot-env.cjs"
// ce module renseigne les deux variables dès que l'une est définie, pour que chaque
// suite voie le même exécutable. Avec CD_GODOT_REQUIRED=1 (jobs Godot de la CI,
// ci/run-godot-suites.sh), l'absence d'exécutable est une erreur au lieu d'un saut.
// Usage direct : node ci/godot-env.cjs [--check]  (affiche le chemin et la version).
const fs = require('node:fs');

function resolveGodot(env = process.env) {
  const exe = env.CD_GODOT_EXE || '', executable = env.CD_GODOT_EXECUTABLE || '';
  if (exe && executable && exe !== executable)
    throw Error('CD_GODOT_EXE et CD_GODOT_EXECUTABLE désignent deux exécutables différents');
  return exe || executable || null;
}
function usable(file) {
  try { fs.accessSync(file, fs.constants.X_OK); return fs.statSync(file).isFile(); } catch { return false; }
}
function applyGodotEnv(env = process.env) {
  const godot = resolveGodot(env);
  if (godot) env.CD_GODOT_EXE = env.CD_GODOT_EXECUTABLE = godot;
  if (env.CD_GODOT_REQUIRED === '1' && (!godot || !usable(godot)))
    throw Error('SDK Godot requis (CD_GODOT_REQUIRED=1) : CD_GODOT_EXE/CD_GODOT_EXECUTABLE ' +
      (godot ? 'désigne un fichier absent ou non exécutable : ' + godot : 'absent'));
  return godot;
}

if (require.main === module) {
  try {
    const godot = applyGodotEnv();
    if (!godot) { console.error('SDK Godot absent (CD_GODOT_EXE/CD_GODOT_EXECUTABLE)'); process.exit(1); }
    let version = '';
    if (process.argv.includes('--check')) {
      const run = require('node:child_process').spawnSync(godot, ['--headless', '--version'], { encoding: 'utf8', timeout: 60000 });
      version = String(run.stdout || '').trim().split('\n').pop();
      if (run.status !== 0 || !version) { console.error('Godot ne répond pas : ' + (run.stderr || run.error || run.status)); process.exit(1); }
    }
    console.log('Godot : ' + godot + (version ? ' (' + version + ')' : ''));
  } catch (error) { console.error(error.message); process.exit(1); }
} else {
  try { applyGodotEnv(); } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

module.exports = { resolveGodot, applyGodotEnv };
