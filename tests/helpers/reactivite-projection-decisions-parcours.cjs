'use strict';
// Parcours de tests/reactivite-projection-decisions.cjs (retiré du parcours commun le 16/11/2026 : il ne sert qu'à
// cette suite). Un parcours Monde par processus ; les outils de comparaison sont ceux du parcours commun.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const C = require('./reactivite-projection-parcours.cjs');
const { DOSSIER, M, TEXTS, flat, sha } = C;

// Décisions sur un joueur du club et délégation (lot 20, #777) : seconde consigne de charge (champ déjà présent),
// délégations de la composition et de l'entraînement, axe de progression, plan de travail. Sans match : la suite
// reactivite-projection-decisions.cjs compare la projection d'avant, le mode vérification et la projection rapide.
function decisions(options) {
  fs.rmSync(DOSSIER, { recursive: true, force: true });
  const jeu = M.ouvrir({ hebdomadaire: true, deferredCommits: true, testVm: true, dataDir: DOSSIER, ...options });
  const etapes = [];
  try {
    if (options.projectionSections !== false) jeu.bridge.vm.run("{const d=nativeSystems.domain('interclubMarket'),o=d.project;globalThis.__marche=0;d.project=function(){__marche++;return o.apply(this,arguments);};}");
    const marche = () => options.projectionSections !== false ? jeu.bridge.vm.run('__marche') : 0;
    const note = (etiquette, model) => { const textes = flat(model); textes.set('meta.dataDir', ''); etapes.push({ etiquette, textes, live: false, joint: !!model[TEXTS] }); return model; };
    const call = (command, payload) => { const model = jeu.call(command, payload); jeu.bridge.handle.flush(); return note(command, model); };
    let model = note('création', M.creer(jeu));
    model = call('set_player_load', { playerId: model.squad[4].id, mode: 'repos' });
    const avantDecisions = marche();
    model = call('set_player_load', { playerId: model.squad[4].id, mode: 'normal' });
    for (const [key, enabled] of [['lineup', true], ['training', true], ['training', false], ['lineup', false]]) model = call('set_delegation', { key, enabled });
    const decisionsMarche = marche() - avantDecisions;
    model = call('set_development_focus', { playerId: model.squad[6].id, focus: 'stamina' });
    model = call('training_plan', { plan: model.clubLife.clubSupport.training.plans[0].key, context: model.clubLife.clubSupport.context });
    note('instantané', jeu.call('snapshot'));
    jeu.bridge.handle.flush();
    const profil = sha(fs.readFileSync(path.join(DOSSIER, 'PrototypeGodot', 'donnees.json'), 'utf8'));
    return { etapes, profil, lecturesMarche: 0, decisionsMarche };
  } finally { jeu.fermer(); fs.rmSync(DOSSIER, { recursive: true, force: true }); }
}

// Même processus enfant que parcoursIsole du parcours commun, avec ce fichier comme script.
function parcoursIsole(options) { return C.parcoursIsole(options, __filename); }
if (require.main === module && process.argv[2] === '--parcours') {
  C.ecrireParcours(decisions(JSON.parse(process.argv[3])), process.argv[4]);
  process.exit(0);
}

module.exports = { parcoursIsole, comparer: C.comparer };
