'use strict';
// Captures comparées du rendu du match 3D : rendu actuel (gl_compatibility, celui
// du jeu) puis rendu moderne (Forward+) à chaque niveau de qualité, sur la même
// séquence du moteur (touche, ballon porté, essai), gestes activés.
// Outil manuel pour un PC avec carte graphique ; non lancé par la CI (sans
// CD_MATCH_RENDU_CAPTURES il s'arrête aussitôt, sans rien faire).
//
// Windows (PowerShell), depuis la racine du dépôt :
//   $env:CD_GODOT_EXE = "C:\chemin\Godot_v4.7.2-stable_win64_console.exe"
//   $env:CD_MATCH_RENDU_CAPTURES = "C:\chemin\captures-rendu"
//   node tests/godot-match-rendu-capture.cjs
//
// Variables facultatives :
//   CD_MATCH_RENDU_PILOTE   vulkan (défaut) ou d3d12, pilote demandé pour Forward+
//   CD_MATCH_RENDU_PASSES   actuel,bas,moyen,eleve,moyen-filmique (défaut : toutes)
//   CD_MATCH_RENDU_TAILLES  1280x720,2560x1440 (défaut)
//   CD_MATCH_RENDU_CAMERAS  tv,action (défaut)
//   CD_MATCH_RENDU_AMBIANCES jour,soir (défaut)
//   CD_MATCH_RENDU_EVERY    une image toutes les N images simulées (3 : 10 images/s)
//   CD_MATCH_RENDU_MESURE   images de mesure sans capture en fin de passe (120)
//
// Tout est écrit dans CD_MATCH_RENDU_CAPTURES/<date-heure>/ : images, report.json
// par passe, journaux Godot, index.json. Le dossier utilisateur de Godot (journal,
// caches de shaders) est redirigé dans ce même dossier.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const PROJECT = path.join(ROOT, 'native', 'godot');
const SCRIPT = path.join(__dirname, 'godot-match-rendu-capture.gd');
const SEQUENCE = path.join(__dirname, 'fixtures', 'match-gestes-sequence.json');
const PASSES = {
  actuel: { quality: 'balanced', modern: false, label: 'rendu actuel du jeu (gl_compatibility, qualité Équilibré)' },
  bas: { quality: 'economy', modern: true, label: 'Forward+, niveau bas (Économie)' },
  moyen: { quality: 'balanced', modern: true, label: 'Forward+, niveau moyen (Équilibré)' },
  eleve: { quality: 'detail', modern: true, label: 'Forward+, niveau élevé (Détail)' },
  'moyen-filmique': { quality: 'balanced', modern: true, tonemap: 'filmique', label: 'Forward+, niveau moyen, courbe filmique (option)' },
};

function list(name, fallback) {
  return (process.env[name] || fallback).split(',').map(value => value.trim()).filter(Boolean);
}

function fail(message) {
  console.error('ÉCHEC : ' + message);
  process.exit(1);
}

function main() {
  const base = process.env.CD_MATCH_RENDU_CAPTURES;
  if (!base) {
    console.log('godot-match-rendu-capture : CD_MATCH_RENDU_CAPTURES non défini, aucune capture (outil manuel).');
    return;
  }
  if (!path.isAbsolute(base)) fail('CD_MATCH_RENDU_CAPTURES doit être un chemin absolu.');
  const godot = process.env.CD_GODOT_EXE;
  if (!godot || !fs.existsSync(godot)) fail('CD_GODOT_EXE doit désigner l’exécutable Godot 4.7.2 (de préférence la version « console » sous Windows).');
  // Le projet doit déjà être préparé et importé : l'outil n'écrit rien hors du dossier de sortie.
  const model = path.join(PROJECT, 'assets', 'match3d', 'quaternius-rugby-athlete.glb');
  const imported = path.join(PROJECT, '.godot', 'imported');
  const ready = fs.existsSync(model) && fs.existsSync(imported) &&
    fs.readdirSync(imported).some(name => name.startsWith('quaternius-rugby-athlete.glb-'));
  if (!ready) {
    fail('projet Godot non préparé. Une fois, depuis la racine du dépôt :\n' +
      '  python scripts/build-godot-prototype.py --stage-only --node "<chemin de node.exe>"\n' +
      '  "<CD_GODOT_EXE>" --headless --path native/godot --import');
  }
  const passes = list('CD_MATCH_RENDU_PASSES', Object.keys(PASSES).join(','));
  for (const name of passes) if (!PASSES[name]) fail('passe inconnue : ' + name + ' (connues : ' + Object.keys(PASSES).join(', ') + ')');
  const sizes = list('CD_MATCH_RENDU_TAILLES', '1280x720,2560x1440');
  for (const size of sizes) if (!/^\d{3,5}x\d{3,5}$/.test(size)) fail('taille invalide : ' + size);
  const cameras = list('CD_MATCH_RENDU_CAMERAS', 'tv,action');
  for (const camera of cameras) if (!['tv', 'action', 'tactical'].includes(camera)) fail('caméra inconnue : ' + camera);
  const ambiances = list('CD_MATCH_RENDU_AMBIANCES', 'jour,soir');
  for (const ambiance of ambiances) if (!['jour', 'soir'].includes(ambiance)) fail('ambiance inconnue : ' + ambiance);
  const driver = (process.env.CD_MATCH_RENDU_PILOTE || 'vulkan').trim();
  if (!['vulkan', 'd3d12', 'metal'].includes(driver)) fail('pilote inconnu : ' + driver);

  const stamp = new Date().toISOString().replace(/[-:]/g, '').replace('T', '-').slice(0, 15);
  const out = path.join(base, stamp);
  fs.mkdirSync(out, { recursive: true });
  // Dossiers utilisateur et temporaires de Godot redirigés dans la sortie.
  const home = path.join(out, '_godot');
  for (const dir of ['appdata', 'localappdata', 'temp', 'xdg-data', 'xdg-cache', 'xdg-config', 'logs']) fs.mkdirSync(path.join(home, dir), { recursive: true });
  const isolated = {
    APPDATA: path.join(home, 'appdata'), LOCALAPPDATA: path.join(home, 'localappdata'),
    TEMP: path.join(home, 'temp'), TMP: path.join(home, 'temp'), TMPDIR: path.join(home, 'temp'),
    XDG_DATA_HOME: path.join(home, 'xdg-data'), XDG_CACHE_HOME: path.join(home, 'xdg-cache'), XDG_CONFIG_HOME: path.join(home, 'xdg-config'),
  };

  const index = { debut: new Date().toISOString(), godot, pilote_demande: driver, systeme: os.platform() + ' ' + os.release(), passes: [] };
  const failures = [];
  let forwardMissing = false;
  let run = 0;
  const total = ambiances.length * cameras.length * sizes.length * passes.length;
  for (const ambiance of ambiances) for (const camera of cameras) for (const size of sizes) for (const name of passes) {
    run += 1;
    const pass = PASSES[name];
    if (pass.modern && forwardMissing) continue;
    const group = `${ambiance}-${camera}-${size}`;
    const dir = path.join(out, group, name);
    fs.mkdirSync(dir, { recursive: true });
    const args = ['--windowed', '--resolution', '960x540', '--log-file', path.join(home, 'logs', `${group}-${name}.log`)];
    if (pass.modern) args.push('--rendering-method', 'forward_plus', '--rendering-driver', driver);
    args.push('--path', PROJECT, '--script', SCRIPT);
    const env = { ...process.env, ...isolated,
      CD_MATCH_RENDU_SORTIE: dir, CD_MATCH_RENDU_SEQUENCE: SEQUENCE, CD_MATCH_RENDU_PASSE: `${group}/${name}`,
      CD_MATCH_RENDU_ATTENDU: pass.modern ? 'forward_plus' : 'gl_compatibility',
      CD_MATCH_RENDU_TAILLE: size, CD_MATCH_RENDU_CAMERA: camera, CD_MATCH_RENDU_QUALITE: pass.quality,
      CD_MATCH_RENDU_AMBIANCE: ambiance, CD_MATCH_RENDU_EVERY: process.env.CD_MATCH_RENDU_EVERY || '3',
      CD_MATCH_RENDU_MESURE: process.env.CD_MATCH_RENDU_MESURE || '120', CD_MATCH_RENDU_CONTINU: '1',
      CD_MATCH_RENDU: pass.modern ? 'moderne' : 'actuel', CD_MATCH_RENDU_TONEMAP: pass.tonemap || '' };
    delete env.CD_MATCH_GESTES;
    process.stdout.write(`[${run}/${total}] ${group} ${name} : ${pass.label}… `);
    const started = Date.now();
    const result = spawnSync(godot, args, { cwd: ROOT, env, encoding: 'utf8', windowsHide: false, timeout: 15 * 60 * 1000, maxBuffer: 64 * 1024 * 1024 });
    fs.writeFileSync(path.join(home, 'logs', `${group}-${name}.sortie.txt`), (result.stdout || '') + (result.stderr || ''));
    const reportPath = path.join(dir, 'report.json');
    const report = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath, 'utf8')) : null;
    const summary = { groupe: group, passe: name, dossier: path.relative(out, dir), code: result.status, secondes: Math.round((Date.now() - started) / 100) / 10 };
    if (report) Object.assign(summary, { methode_rendu: report.methode_rendu, pilote: report.pilote, carte: report.carte,
      images: (report.images || []).length, rendu_moderne_actif: report.rendu_moderne_actif,
      gpu_ms_mediane: (report.rendu_gpu_ms_par_image || {}).mediane, gpu_ms_p95: (report.rendu_gpu_ms_par_image || {}).p95,
      gpu_ms_sans_capture: ((report.mesure_sans_capture || {}).gpu_ms || {}).mediane, erreur: report.erreur });
    index.passes.push(summary);
    let problem = '';
    if (result.error) problem = 'Godot n’a pas pu être lancé : ' + result.error.message;
    else if (!report) problem = 'aucun report.json (code ' + result.status + ')';
    else if (report.erreur) problem = report.erreur;
    else if (result.status !== 0) problem = 'code de sortie ' + result.status;
    else if (pass.modern && report.methode_rendu !== 'forward_plus') problem = 'Forward+ n’a pas pu s’activer (méthode ' + report.methode_rendu + ', pilote ' + report.pilote + ')';
    else if (pass.modern && !report.rendu_moderne_actif) problem = 'rendu moderne non installé';
    else if (!report.images.length) problem = 'aucune image';
    if (problem) {
      failures.push(`${group}/${name} : ${problem}`);
      console.log('ÉCHEC — ' + problem);
      // Forward+ indisponible : inutile d'enchaîner les autres passes modernes.
      if (/Forward\+/.test(problem)) forwardMissing = true;
    } else {
      console.log(`${report.images.length} images, ${report.methode_rendu}/${report.pilote}, GPU ${summary.gpu_ms_mediane ?? '?'} ms (médiane), ${summary.secondes} s`);
    }
  }
  index.fin = new Date().toISOString();
  index.echecs = failures;
  fs.writeFileSync(path.join(out, 'index.json'), JSON.stringify(index, null, 2));
  console.log('\nRésultats : ' + out);
  if (failures.length) {
    console.error('\n' + failures.length + ' passe(s) en échec :\n  ' + failures.join('\n  '));
    console.error('Forward+ indisponible ? Mettre à jour le pilote graphique, ou essayer CD_MATCH_RENDU_PILOTE=d3d12.');
    process.exit(1);
  }
}

main();
