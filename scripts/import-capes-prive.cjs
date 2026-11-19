'use strict';
// Sélections senior (XV) manquantes des joueurs de Premiership, relevées le 19/11/2026 avec l'EQP (dépôt privé
// rugby-reel-donnees, data/eqp/premiership-eqp-20261119.json : `autreSelection` {nation, capes} et, pour les capés
// d'Angleterre, le nombre de capes écrit dans `note`). Ajoute seulement les joueurs SANS sélection déjà documentée :
// les sélections publiées par les fédérations (portée national-xv) priment sur ce relevé, plus ancien sur les nombres.
// Rien n'est déduit : sans nombre de capes lisible, le joueur est laissé tel quel (liste en sortie).
// Usage : node scripts/import-capes-prive.cjs <fichier privé> ; puis node scripts/build-player-real-facts.cjs
const fs = require('node:fs');
const path = require('node:path');

const SOURCE = 'caps-recherche-20261119';
const prive = JSON.parse(fs.readFileSync(process.argv[2] || '', 'utf8'));
const fichier = path.join(__dirname, '../data/player-real-facts/observations.json');
const preuves = JSON.parse(fs.readFileSync(fichier, 'utf8'));
preuves.sources[SOURCE] = { observedOn: '2026-11-19', publisher: 'Recherche Rugby Legacy (fiches des joueurs ; sources dans le dépôt privé)', scope: 'caps-research' };
preuves.observations = preuves.observations.filter(([, source]) => source !== SOURCE);
const dejaCape = new Set(preuves.observations.filter(([, , f]) => f.seniorCaps !== undefined).map(([id]) => id));
const code = /^[A-Z]{3}$/;
const ajoutes = [], laisses = [];
for (const club of prive.clubs) for (const j of club.joueurs) {
  if (dejaCape.has(j.id)) continue;
  let nation = null, capes = null;
  if (j.autreSelection && code.test(j.autreSelection.nation || '') && Number.isInteger(j.autreSelection.capes) && j.autreSelection.capes > 0) {
    nation = j.autreSelection.nation; capes = j.autreSelection.capes;
  } else if (j.voie === 'selection-angleterre') {
    const m = /(\d+)\s*(sélection|selection|cap|cape)/i.exec(j.note || '');
    if (m && +m[1] > 0) { nation = 'ENG'; capes = +m[1]; }
  }
  if (!nation) { if (j.voie === 'selection-angleterre' || j.autreSelection) laisses.push(j.nom); continue; }
  preuves.observations.push([j.id, SOURCE, { seniorCaps: capes, seniorNation: nation }]);
  ajoutes.push(`${j.nom} (${nation} ${capes})`);
}
const texte = `{"schemaVersion":${preuves.schemaVersion},"snapshot":${JSON.stringify(preuves.snapshot)},"sources":` +
  JSON.stringify(preuves.sources, null, 2) + ',"observations":[\n' + preuves.observations.map(o => JSON.stringify(o)).join(',\n') + '\n]}\n';
fs.writeFileSync(fichier, texte);
console.log(`Sélections ajoutées : ${ajoutes.length}\n${ajoutes.join(', ')}\nLaissés faute de nombre lisible : ${laisses.join(', ') || 'aucun'}`);
