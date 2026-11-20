'use strict';
// Tour des écrans filmé : prépare une carrière Monde de test arrêtée le JOUR d'un match (avant le coup
// d'envoi), après `--matchs` rencontres jouées (défaut 1 : classement, calendrier, presse et finances ont
// du contenu). Export identique à « Exporter la carrière » du jeu ; aucune vraie carrière n'est lue ni
// écrite (dossier temporaire supprimé à la fin).
//
//   node tools/ecrans-filmes/preparer-carriere.cjs <export.json> [--club <n>] [--graine <n>] [--matchs <n>]
//
// Lancé par scripts/ecrans-filmes.ps1 quand -Export n'est pas donné.
const fs = require('node:fs');
const path = require('node:path');
const { ouvrir, creer, jouer, jusquAuMatch } = require('../../tests/helpers/carriere-monde.cjs');

function lireOptions(argv) {
  const options = { sortie: '', club: 102, graine: 4242, matchs: 1 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--nu') options.nu = true;
    else if (arg === '--club' || arg === '--graine' || arg === '--matchs') {
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
    let model = options.nu ? jeu.reglerSaufPresse(jeu.call('new_career', { mode: 'world-champ', club: options.club })) : creer(jeu, options.club);
    // --nu : carrière toute neuve, conférence d'arrivée encore ouverte (captures de la Presse).
    if (options.nu) { for (let j = 0; j < 120 && !model.clubLife?.press?.conference?.available; j++) { if (model.meta.calendarCadence?.canAdvance !== true) break; model = jeu.reglerSaufPresse(jeu.call('advance_day', { fromDate: model.meta.calendarToday })); }
      fs.mkdirSync(path.dirname(options.sortie), { recursive: true }); fs.writeFileSync(options.sortie, jeu.call('export').meta.exportText); return { club: model.club?.name || '', date: model.meta?.calendarToday || '', matchs: 0, jourDeMatch: false }; }
    if (options.matchs > 0) model = jouer(jeu, model, options.matchs);
    // Jour du match suivant, feuille de match complète : le tour peut aussi filmer le direct et la fenêtre Équipe.
    model = jusquAuMatch(jeu, model);
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
    fs.mkdirSync(path.dirname(options.sortie), { recursive: true });
    fs.writeFileSync(options.sortie, jeu.call('export').meta.exportText);
    return { club: model.club?.name || '', date: model.meta?.calendarToday || '', matchs: options.matchs, jourDeMatch: Boolean(model.meta?.calendarCadence?.matchReady) };
  } finally {
    jeu.fermer();
  }
}

if (require.main === module) {
  const debut = Date.now();
  const options = lireOptions(process.argv.slice(2));
  const resume = preparer(options);
  console.log('ECRANS_FILMES_CARRIERE ' + JSON.stringify({ ...resume, export: options.sortie, secondes: Math.round((Date.now() - debut) / 1000) }));
}

module.exports = { lireOptions, preparer };
