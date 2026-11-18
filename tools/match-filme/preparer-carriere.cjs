'use strict';
// Match filmé : prépare une carrière Monde de test arrêtée au coup d'envoi de son premier match,
// sous forme d'export (le même fichier que « Exporter la carrière » du jeu). Aucune vraie carrière
// n'est lue ni écrite : la carrière vit dans un dossier temporaire supprimé à la fin.
//
//   node tools/match-filme/preparer-carriere.cjs <export.json> [--club <n>] [--graine <n>]
//
// Lancé par scripts/match-filme.ps1 ; utilisable seul pour rejouer le même match.
const fs = require('node:fs');
const path = require('node:path');
const { ouvrir, creer, jusquAuMatch } = require('../../tests/helpers/carriere-monde.cjs');

function lireOptions(argv) {
  const options = { sortie: '', club: 102, graine: 4242 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--club' || arg === '--graine') {
      const valeur = Number(argv[++i]);
      if (!Number.isInteger(valeur) || valeur < 0) throw new Error(arg + ' attend un entier positif.');
      options[arg.slice(2)] = valeur;
    } else if (!options.sortie) options.sortie = arg;
    else throw new Error('Argument inconnu : ' + arg);
  }
  if (!options.sortie || !path.isAbsolute(options.sortie)) throw new Error('Chemin absolu de l’export attendu.');
  return options;
}

function preparer(options) {
  const jeu = ouvrir({ seed: options.graine });
  try {
    let model = jusquAuMatch(jeu, creer(jeu, options.club));
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
    model = jeu.call('begin_match');
    if (!model.live) throw new Error('Le match ne s’est pas ouvert.');
    fs.mkdirSync(path.dirname(options.sortie), { recursive: true });
    fs.writeFileSync(options.sortie, jeu.call('export').meta.exportText);
    return { club: model.club?.name || '', rencontre: (model.live.teams || []).map(equipe => equipe?.name).filter(Boolean).join(' – '), date: model.meta?.calendarToday || '' };
  } finally {
    jeu.fermer();
  }
}

if (require.main === module) {
  const debut = Date.now();
  const options = lireOptions(process.argv.slice(2));
  const resume = preparer(options);
  console.log('MATCH_FILME_CARRIERE ' + JSON.stringify({ ...resume, export: options.sortie, secondes: Math.round((Date.now() - debut) / 1000) }));
}

module.exports = { lireOptions, preparer };
