'use strict';
// Mode Monde uniquement (décision de Léo, 13/11/2026) : aucune suite de la CI ne tourne dans un ancien
// mode de carrière (France, fiction, compétition personnalisée, éditions partielles du Monde).
// Une suite qui en a encore besoin porte en tête CD_MODES_HERITES (drapeau qui ouvre les anciens
// modes au moteur) : elle est exclue de toute exécution (shards JS, suites Godot, sélection de
// développement, listes de workflows) jusqu'à sa migration vers world-champ ou sa suppression.
// Une suite est aussi exclue quand elle charge, directement ou non, un module de tests qui porte
// le drapeau (ex. tests/france-harness.cjs le pose dans process.env dès son chargement).
const fs = require('node:fs');
const path = require('node:path');

const MARKER = /CD_MODES_HERITES/;
const REQUIRE = /\brequire\(\s*(['"])(\.{1,2}\/[^'"]+)\1\s*\)/g;
// require(path.join(repo, 'tests', 'x.cjs')) : les littéraux sont lus depuis la racine du dépôt.
const REQUIRE_PATH = /\brequire\(\s*path\.(?:join|resolve)\(([^()]*)\)\s*\)/g;
const root = path.resolve(__dirname, '..');
// Hors de tests/, le drapeau ne compte que s'il est posé par le code (process.env.… = …) : les commentaires
// et les listes des outils de CI (ce fichier, ci/shard-tests.cjs…) ou du moteur (worker.cjs) ne rendent
// pas un module « hérité ».
const SETS_FLAG = /process\.env\.CD_MODES_HERITES\s*=(?!=)/;
const testsDir = () => path.join(root, 'tests');

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.isFile() && /\.c?js$/.test(entry.name)) out.push(full);
  }
  return out;
}
function resolveModule(from, spec) {
  const base = path.resolve(path.dirname(from), spec);
  for (const candidate of [base, base + '.cjs', base + '.js', path.join(base, 'index.cjs'), path.join(base, 'index.js')]) {
    if (candidate.startsWith(root + path.sep) && !candidate.includes(path.sep + 'node_modules' + path.sep) &&
        fs.statSync(candidate, { throwIfNoEntry: false })?.isFile()) return candidate;
  }
  return null;
}
// Renvoie Map « tests/x.cjs » → raison ('drapeau' ou 'via <module>') pour tous les fichiers de tests/.
// Les modules chargés hors de tests/ (ci/*.cjs, native/…) comptent aussi : un audit qui porte le drapeau
// exclut les suites qui le chargent.
function legacyFiles(dir = testsDir()) {
  const sources = new Map();
  const read = f => { if (!sources.has(f)) sources.set(f, fs.readFileSync(f, 'utf8')); return sources.get(f); };
  const requiresOf = new Map();
  const requires = f => {
    if (!requiresOf.has(f)) {
      const found = [];
      for (const match of read(f).matchAll(REQUIRE)) {
        const target = resolveModule(f, match[2]);
        if (target && /\.c?js$/.test(target)) found.push(target);
      }
      for (const match of read(f).matchAll(REQUIRE_PATH)) {
        const parts = [...match[1].matchAll(/(['"])([^'"]+)\1/g)].map(m => m[2]);
        const target = parts.length ? path.join(root, ...parts) : null;
        if (target && target.startsWith(root + path.sep) && /\.c?js$/.test(target) &&
            fs.statSync(target, { throwIfNoEntry: false })?.isFile()) found.push(target);
      }
      requiresOf.set(f, found);
    }
    return requiresOf.get(f);
  };
  const reason = new Map(), visiting = new Set();
  const visit = file => {
    if (reason.has(file)) return reason.get(file);
    const inTests = file.startsWith(testsDir() + path.sep);
    if ((inTests ? MARKER : SETS_FLAG).test(read(file))) { reason.set(file, 'drapeau'); return 'drapeau'; }
    if (visiting.has(file)) return null;
    visiting.add(file);
    let found = null;
    for (const target of requires(file)) {
      if (visit(target)) { found = 'via ' + path.relative(root, target).split(path.sep).join('/'); break; }
    }
    visiting.delete(file);
    reason.set(file, found);
    return found;
  };
  const out = [];
  for (const file of walk(dir)) {
    const why = visit(file);
    if (why) out.push([path.relative(root, file).split(path.sep).join('/'), why]);
  }
  return new Map(out.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
}
function legacySuites() { return new Set(legacyFiles().keys()); }
// Motifs qui créent une carrière hors Monde : interdits dans une suite exécutée (qui doit alors porter le drapeau).
const LEGACY_CREATION = [
  [/\blegacyModes\s*:\s*true\b/, 'legacyModes:true'],
  [/\bstart\(\s*\d+\s*,\s*['"](?:france|common|fiction|custom)['"]/, "start(n,'<ancien mode>')"],
  [/\bmode\s*:\s*['"](?:france|common|fiction|custom)['"]\s*,\s*(?:club|seed|initialSeed)\b/, "mode:'<ancien mode>'"],
  [/\bnew_career['"]?\s*,\s*\{[^}]*\bmode\s*:\s*['"](?!world-champ['"])[^'"]+['"]/, "new_career avec un mode autre que world-champ"],
  [/\b(?:club|initialSeed)\s*:\s*\d+\s*,\s*mode\s*:\s*['"](?:france|common|fiction|custom)['"]/, "mode:'<ancien mode>'"]
];
// Suite qui teste justement le refus des anciens modes : seule autorisée à en parler sans drapeau.
const REFUSAL_SUITES = new Set(['tests/mode-monde-unique.cjs']);
function legacyCreations(file, read = f => fs.readFileSync(path.join(root, f), 'utf8')) {
  if (REFUSAL_SUITES.has(file)) return [];
  const text = read(file);
  return LEGACY_CREATION.filter(([re]) => re.test(text)).map(([, label]) => label);
}
function filterLegacy(files, legacy = legacySuites()) {
  const kept = [], excluded = [];
  for (const file of files) (legacy.has(file) ? excluded : kept).push(file);
  return { kept, excluded };
}

module.exports = { MARKER, legacyFiles, legacySuites, legacyCreations, filterLegacy, REFUSAL_SUITES };

if (require.main === module) {
  const [, , command, list] = process.argv;
  if (command === 'filter' && list) {
    // Liste de suites (une par ligne) → suites non exclues sur la sortie standard, exclusions en avertissement.
    const lines = fs.readFileSync(list, 'utf8').split('\n').map(l => l.trim()).filter(Boolean);
    const { kept, excluded } = filterLegacy(lines);
    for (const file of excluded) console.error('::notice::Suite exclue (ancien mode de carrière, CD_MODES_HERITES) : ' + file);
    for (const file of kept) console.log(file);
  } else if (command === 'is' && list) {
    // Code de sortie 0 si la suite est exclue (ancien mode de carrière), 1 sinon.
    process.exitCode = legacySuites().has(list) ? 0 : 1;
  } else if (command === 'list') {
    for (const [file, why] of legacyFiles()) console.log(file + '\t' + why);
  } else {
    console.error('Usage : node ci/legacy-modes.cjs filter <liste> | is <suite> | list');
    process.exitCode = 2;
  }
}
