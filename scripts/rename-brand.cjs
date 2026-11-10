'use strict';
// Renommage mécanique et rejouable « Oval Legacy 27 » → « Rugby Legacy 27 ».
//
//   node scripts/rename-brand.cjs           applique les remplacements
//   node scripts/rename-brand.cjs --check   échoue si un ancien nom subsiste dans le périmètre
//
// Rejouable : après avoir fusionné ou rebasé une branche qui réintroduit
// l'ancien nom, relancer la commande suffit. Aucune résolution manuelle.
//
// Invariants de compatibilité, volontairement HORS périmètre (voir
// docs/renommage-rugby-legacy-27.md) :
//   - profil Windows  %APPDATA%\CadrageDebordement\PrototypeGodot
//   - format d'export 'cadrage-debordement-save'
//   - format de calendrier 'oval-legacy-fictional-calendar'
//   - dépôt GitHub Xynph/cadrage-debordement
//   - provenance des illustrations, sons et voix (manifestes et empreintes)
//   - journal et rapports datés (DEVELOPPEMENT.md, docs/ sauf registre)
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const NEW = 'Rugby Legacy';

// Fichiers et dossiers suivis par Git qui portent le nom affiché ou distribué.
const INCLUDE = [
  /^native\/godot\/[^/]+\.(?:gd|godot)$/,
  /^native\/godot\/ui\/.+\.gd$/,
  /^native\/godot\/branding\/README\.md$/,
  /^scripts\/build-godot-prototype\.py$/,
  /^tests\/[^/]+\.(?:gd|cjs|mjs|py)$/,
  /^README\.md$/,
  /^AGENTS\.md$/,
  /^offline\/README\.md$/,
  /^docs\/ressources-utiles\.md$/,
  /^docs\/renommage-rugby-legacy-27\.md$/,
];
// Ce fichier, son test et le document du renommage citent l'ancien nom à dessein.
const SELF = new Set(['scripts/rename-brand.cjs', 'tests/brand-name.cjs', 'docs/renommage-rugby-legacy-27.md']);

// Ordre significatif : les formes les plus longues d'abord.
const RULES = [
  [/Oval Legacy 27 — Rugby Manager/g, NEW + ' 27'],
  [/OVAL LEGACY 27 — RUGBY MANAGER/g, NEW.toUpperCase() + ' 27'],
  [/d[’']Oval Legacy/g, 'de ' + NEW],
  [/OVAL LEGACY/g, NEW.toUpperCase()],
  [/Oval Legacy/g, NEW],
  [/OvalLegacy27-PrototypeGodot/g, 'RugbyLegacy27'],
  [/OvalLegacy27/g, 'RugbyLegacy27'],
  [/Oval-Legacy-27/g, 'Rugby-Legacy-27'],
  [/oval-legacy-27-(logo|icon)\.png/g, 'rugby-legacy-27-$1.png'],
  [/accueil-oval-legacy/g, 'accueil-rugby-legacy'],
];
// Ancien nom encore présent après remplacement = oubli. Restes autorisés dans
// le périmètre : l'identifiant de format de calendrier et les liens vers les
// rapports datés, dont le nom de fichier ne change pas.
const LEFTOVER = /oval[ -]?legacy(?!-fictional-calendar|-[a-z0-9-]+\.md)/i;

const RENAMES = [
  ['native/godot/branding/oval-legacy-27-logo.png', 'native/godot/branding/rugby-legacy-27-logo.png'],
  ['native/godot/branding/oval-legacy-27-icon.png', 'native/godot/branding/rugby-legacy-27-icon.png'],
];

function tracked() {
  return execFileSync('git', ['ls-files', '-z'], { cwd: ROOT, maxBuffer: 64 * 1024 * 1024 })
    .toString('utf8').split('\0').filter(Boolean);
}
function inScope(file) { return !SELF.has(file) && INCLUDE.some(rule => rule.test(file)); }
function transform(text) { return RULES.reduce((out, [from, to]) => out.replace(from, to), text); }

function run({ check = false, root = ROOT, files = tracked() } = {}) {
  const changed = [], leftovers = [];
  for (const file of files.filter(inScope)) {
    const full = path.join(root, file);
    if (!fs.existsSync(full)) continue;
    const before = fs.readFileSync(full, 'utf8');
    const after = transform(before);
    if (after !== before) { changed.push(file); if (!check) fs.writeFileSync(full, after); }
    after.split('\n').forEach((line, index) => {
      if (LEFTOVER.test(line)) leftovers.push(file + ':' + (index + 1) + ': ' + line.trim().slice(0, 120));
    });
  }
  for (const [from, to] of RENAMES) {
    if (!fs.existsSync(path.join(root, from))) continue;
    changed.push(from);
    if (!check) execFileSync('git', ['mv', '-k', from, to], { cwd: root });
  }
  return { changed, leftovers };
}

if (require.main === module) {
  const check = process.argv.includes('--check');
  const { changed, leftovers } = run({ check });
  for (const file of changed) console.log((check ? 'À renommer : ' : 'Renommé : ') + file);
  for (const line of leftovers) console.error('Ancien nom restant : ' + line);
  console.log(changed.length + ' fichier(s) ' + (check ? 'à traiter' : 'traité(s)') + ', ' + leftovers.length + ' reste(s).');
  process.exitCode = (check && changed.length) || leftovers.length ? 1 : 0;
}
module.exports = { run, transform, inScope, RULES, RENAMES };
