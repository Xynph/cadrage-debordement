'use strict';
// Tour des écrans filmé : prépare une carrière Monde de test arrêtée le JOUR d'un match (avant le coup
// d'envoi), après `--matchs` rencontres jouées (défaut 1 : classement, calendrier, presse et finances ont
// du contenu). Export identique à « Exporter la carrière » du jeu ; aucune vraie carrière n'est lue ni
// écrite (dossier temporaire supprimé à la fin).
//
//   node tools/ecrans-filmes/preparer-carriere.cjs <export.json> [--club <n>] [--graine <n>] [--matchs <n>] [--reprises <n>]
//
// --reprises <n> : n titulaires blessés puis guéris juste avant la rencontre filmée (historique des blessures, tests
// physiques de reprise d'avant-match et message du médecin, native/engine/tests-physiques.cjs).
//
// Lancé par scripts/ecrans-filmes.ps1 quand -Export n'est pas donné.
const fs = require('node:fs');
const path = require('node:path');
const { ouvrir, creer, jouer, jusquAuMatch } = require('../../tests/helpers/carriere-monde.cjs');

function lireOptions(argv) {
  const options = { sortie: '', club: 102, graine: 4242, matchs: 1, reprises: 0 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--nu') options.nu = true;
    else if (arg === '--club' || arg === '--graine' || arg === '--matchs' || arg === '--reprises') {
      const valeur = Number(argv[++i]);
      if (!Number.isInteger(valeur) || valeur < 0) throw new Error(arg + ' attend un entier positif.');
      options[arg.slice(2)] = valeur;
    } else if (!options.sortie) options.sortie = arg;
    else throw new Error('Argument inconnu : ' + arg);
  }
  if (!options.sortie || !path.isAbsolute(options.sortie)) throw new Error('Chemin absolu de l’export attendu.');
  return options;
}

// Blessures de titulaires (types variés, débuts étalés), un jour de soins, puis guérison : le moteur les range dans
// l'historique et les teste avant la rencontre suivante. Rendez-vous médicaux de ces blessures posées à la main coupés.
const TYPES = ['ischios', 'cheville', 'epaule', 'mollet', 'genou', 'cotes'];
function reprises(jeu, model, n) {
  const vm = jeu.bridge.vm;
  const pas = () => { vm.run('delete S.clubMeetings'); const m = jeu.call('advance_day', { fromDate: vm.run('CDWorldCareer.calendarToday(S)') }); vm.run('delete S.clubMeetings'); return m; };
  vm.run(`{const d=CDWorldCareer.calendarToday(S),ids=S.lineup.filter(Boolean).slice(0,${n}),t=${JSON.stringify(TYPES)};
    ids.forEach((id,i)=>{const p=S.clubs[S.club].players.find(x=>x.id===id);if(!p)return;p.injury=1+i%4;p.injuryType=t[i%t.length];
      p.injuryDate=new Date(Date.parse(d+'T00:00:00Z')-86400000*(6+5*i)).toISOString().slice(0,10);p.injuryCause=i%3===1?'entrainement':'match';});}`);
  pas();
  vm.run(`for(const id of S.lineup.filter(Boolean).slice(0,${n})){const p=S.clubs[S.club].players.find(x=>x.id===id);if(p)p.injury=0;}`);
  pas();
  return jeu.regler(jeu.call('snapshot'));
}

function preparer(options) {
  const jeu = ouvrir({ seed: options.graine, ...(options.reprises > 0 ? { testVm: true } : {}) });
  try {
    let model = options.nu ? jeu.reglerSaufPresse(jeu.call('new_career', { mode: 'world-champ', club: options.club })) : creer(jeu, options.club);
    // --nu : carrière toute neuve, conférence d'arrivée encore ouverte (captures de la Presse).
    if (options.nu) { for (let j = 0; j < 120 && !model.clubLife?.press?.conference?.available; j++) { if (model.meta.calendarCadence?.canAdvance !== true) break; model = jeu.reglerSaufPresse(jeu.call('advance_day', { fromDate: model.meta.calendarToday })); }
      fs.mkdirSync(path.dirname(options.sortie), { recursive: true }); fs.writeFileSync(options.sortie, jeu.call('export').meta.exportText); return { club: model.club?.name || '', date: model.meta?.calendarToday || '', matchs: 0, jourDeMatch: false }; }
    if (options.matchs > 0) model = jouer(jeu, model, options.matchs);
    if (options.reprises > 0) model = reprises(jeu, model, options.reprises);
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
