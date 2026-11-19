'use strict';
// Importe le statut EQP (éligible à l'Angleterre ou non) recherché joueur par joueur pour la Premiership, depuis le dépôt
// privé rugby-reel-donnees (data/eqp/premiership-eqp-*.json : naissance, ascendance, résidence, sources). Seul le statut
// est publié : observation `eligibilityNations` de la source `eqp-recherche-20261119` dans
// data/player-real-facts/observations.json, pour les joueurs sans éligibilité déjà documentée (sélections publiées).
//   EQP oui  → ["ENG"] ; EQP non → [nation de la cape senior, sinon pays de naissance hors Angleterre] ; inconnu → rien.
// Usage : node scripts/import-eqp-prive.cjs <chemin du fichier privé> ; puis node scripts/build-player-real-facts.cjs
const fs = require('node:fs');
const path = require('node:path');

const SOURCE = 'eqp-recherche-20261119';
const prive = JSON.parse(fs.readFileSync(process.argv[2] || '', 'utf8'));
const fichier = path.join(__dirname, '../data/player-real-facts/observations.json');
const preuves = JSON.parse(fs.readFileSync(fichier, 'utf8'));
preuves.snapshot = '2026-11-19';
preuves.sources[SOURCE] = { observedOn: '2026-11-19', publisher: 'Recherche Rugby Legacy (sources par joueur dans le dépôt privé)', scope: 'eligibility-research' };
preuves.observations = preuves.observations.filter(([, source]) => source !== SOURCE);
const dejaDocumente = new Set(preuves.observations.filter(([, , f]) => f.eligibilityNations).map(([id]) => id));
const code = /^[A-Z]{3}$/;
let oui = 0, non = 0, ignores = 0;
for (const club of prive.clubs) {
  for (const j of club.joueurs) {
    if (dejaDocumente.has(j.id) || j.eqp === null || j.eqp === undefined) { ignores++; continue; }
    let nations;
    if (j.eqp === true) { nations = ['ENG']; oui++; }
    else {
      const n = j.autreSelection?.nation && code.test(j.autreSelection.nation) ? j.autreSelection.nation : (code.test(j.paysNaissance || '') && j.paysNaissance !== 'ENG' ? j.paysNaissance : null);
      if (!n || n === 'ENG') { ignores++; continue; }
      nations = [n]; non++;
    }
    preuves.observations.push([j.id, SOURCE, { eligibilityNations: nations }]);
  }
}
// Même mise en forme que le fichier d'origine : en-tête, sources indentées, une observation par ligne.
const texte = `{"schemaVersion":${preuves.schemaVersion},"snapshot":${JSON.stringify(preuves.snapshot)},"sources":` +
  JSON.stringify(preuves.sources, null, 2).replace(/\n\}$/, '\n}') + ',"observations":[\n' + preuves.observations.map(o => JSON.stringify(o)).join(',\n') + '\n]}\n';
fs.writeFileSync(fichier, texte);
console.log(`EQP importés : ${oui} oui, ${non} non, ${ignores} laissés aux tirages.`);
