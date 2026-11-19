'use strict';
// Préparation Steam : réglage d'export dédié, Steamworks inactif par défaut, modèles steamcmd
// sans identifiants ni mise en ligne automatique, crédits et mentions légales complets.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n');
const options = text => Object.fromEntries(text.split(/\r?\n/).filter(line => /^[a-z_/0-9]+=/.test(line))
  .map(line => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1)]));

// 1. Steamworks reste inactif tant que Léo ne l'a pas configuré.
const steam = JSON.parse(read('native/godot/steam/steam.json'));
assert.deepEqual(steam, { schema: 'rl27-steam-v1', enabled: false, app_id: 0, achievements: false, cloud_saves: false, workshop: false });
assert.ok(!fs.existsSync(path.join(root, 'native/godot/addons/godotsteam/godotsteam.gdextension')),
  'GodotSteam ne doit pas être installé avant la création de l’application Steam');
const service = read('native/godot/steam/steam_service.gd');
assert.match(service, /Engine\.has_singleton\("Steam"\)/);
assert.doesNotMatch(service, /^class_name /m, 'pas de classe globale : aucun cache d’import requis');
// Workshop : les packs abonnés passent par la validation normale du moteur (inspect), jamais chargés en direct.
assert.match(service, /static func workshop_packs\(\) -> Array:\n\tvar packs: Array = \[\]\n\tif not workshop_enabled\(\): return packs/);
assert.match(read('native/godot/pack_manager.gd'), /func workshop_packs\(\) -> Array:\n\treturn preload\("res:\/\/steam\/steam_service\.gd"\)\.workshop_packs\(\)/);
assert.match(read('native/godot/ui/pack_views.gd'), /app\.pack_manager\.inspect\.bind\(str\(workshop_pack\.path\)\)/);

// 2. Le réglage Steam reprend l'export Windows vérifié, avec identité de l'exécutable et sans fichiers de recette.
const windows = options(read('native/godot/windows-release.cfg'));
const steamPreset = options(read('native/godot/steam-release.cfg'));
for (const key of ['platform', 'export_filter', 'include_filter', 'script_export_mode', 'custom_template/release',
  'binary_format/embed_pck', 'binary_format/architecture', 'application/icon', 'application/product_name',
  'application/modify_resources', 'texture_format/s3tc_bptc'])
  assert.equal(steamPreset[key], windows[key], key);
assert.equal(steamPreset.exclude_filter, '"windows_qa/*"');
assert.equal(steamPreset['application/file_version'], '"{{VERSION}}.0"');
assert.equal(steamPreset['application/company_name'], '"{{COMPANY}}"');
assert.equal(steamPreset['codesign/enable'], 'false', 'la signature se fait après export, seulement si un certificat est fourni');

// 3. Modèles steamcmd : identifiants absents, build jamais publié automatiquement.
const app = read('tools/steam/app_build.vdf.template');
const depot = read('tools/steam/depot_build_windows.vdf.template');
assert.match(app, /"SetLive" ""/);
assert.match(app, /"AppID" "\{\{APP_ID\}\}"/);
assert.match(depot, /"DepotID" "\{\{DEPOT_ID\}\}"/);
assert.match(depot, /"FileExclusion" "steam_appid\.txt"/);
for (const text of [app, depot, read('scripts/build-steam.py')]) {
  assert.doesNotMatch(text, /password|passwd|mot_de_passe\s*=|ssfn|"\+login"\s*,/i, 'aucun identifiant ni connexion automatique');
}
const builder = read('scripts/build-steam.py');
assert.doesNotMatch(builder, /subprocess\.[a-z_]+\(\s*\[[^\]]*steamcmd/i, 'le script ne lance jamais steamcmd');
assert.match(builder, /preset="steam-release\.cfg"/);
assert.match(read('scripts/build-godot-prototype.py'), /getattr\(args, "preset", "windows-release\.cfg"\)/);

// 4. Crédits et mentions légales : chaque source distribuée est créditée, éditeur à compléter avant publication.
const credits = JSON.parse(read('native/godot/legal/credits.json'));
assert.equal(credits.schema, 'rl27-credits-v1');
assert.deepEqual(Object.keys(credits.editeur), ['nom', 'forme', 'adresse', 'contact', 'directeur_publication']);
const all = credits.sections.flatMap(section => [section.titre, ...section.lignes]).join('\n');
for (const needle of ['Godot', 'Node.js', 'SIL Open Font License', 'Quaternius', 'Kenney', 'flag-icons', 'ElevenLabs',
  'IA', 'affilié', 'Données personnelles', 'Valve'])
  assert.ok(all.includes(needle), 'crédit manquant : ' + needle);
assert.doesNotMatch(all, /fictif|montant fictif/i, 'immersion : pas de mention « fictif »');
assert.match(read('native/godot/main.gd'), /preload\("res:\/\/ui\/credits_view\.gd"\)\.fill\(d\)/);
console.log('Préparation Steam : réglage d’export, Steamworks inactif, modèles steamcmd et crédits vérifiés.');
