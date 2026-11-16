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
    // Domaines de la vie du club recalculés pendant l'axe de progression (support, carrière du manager), et calculs des
    // décisions du manager : compteurs posés sur les projections, en mode rapide seulement.
    const rapide = options.projectionSections !== false && !options.verifyProjection;
    if (rapide) jeu.bridge.vm.run("{globalThis.__domaines=0;for(const k of ['clubSupport','managerCareer']){const d=nativeSystems.domain(k),o=d.project;d.project=function(){__domaines++;return o.apply(this,arguments);};}}");
    const domaines = () => rapide ? jeu.bridge.vm.run('__domaines') : 0;
    const decisionsCalculees = () => rapide ? jeu.bridge.vm.run('nativeStateVersions.computed().decisions??0') : 0;
    const note = (etiquette, model) => { const textes = flat(model); textes.set('meta.dataDir', ''); etapes.push({ etiquette, textes, live: false, joint: !!model[TEXTS] }); return model; };
    const call = (command, payload) => { const model = jeu.call(command, payload); jeu.bridge.handle.flush(); return note(command, model); };
    let model = note('création', M.creer(jeu));
    model = call('set_player_load', { playerId: model.squad[4].id, mode: 'repos' });
    const avantDecisions = marche();
    model = call('set_player_load', { playerId: model.squad[4].id, mode: 'normal' });
    for (const [key, enabled] of [['lineup', true], ['training', true], ['training', false], ['lineup', false]]) model = call('set_delegation', { key, enabled });
    const decisionsMarche = marche() - avantDecisions;
    model = call('set_development_focus', { playerId: model.squad[6].id, focus: 'stamina' });
    // Second axe sur un joueur qui en a déjà un (#socle) : seuls l'axe et l'XP de l'axe changent.
    const avantAxe = domaines();
    model = call('set_development_focus', { playerId: model.squad[6].id, focus: 'equilibre' });
    const axeDomaines = domaines() - avantAxe;
    model = call('training_plan', { plan: model.clubLife.clubSupport.training.plans[0].key, context: model.clubLife.clubSupport.context });
    // Club du manager seulement (#socle) : prolongation, réunion du staff, observation ciblée.
    const renouvelable = model.squad.find(p => p.renewal.available);
    assert.ok(renouvelable, 'un contrat à prolonger');
    model = call('extend_contract', { playerId: renouvelable.id, salary: 100000, years: renouvelable.renewal.minYears, confirmed: true });
    model = call('staff_meeting', { context: model.clubLife.clubSupport.context, plan: model.clubLife.clubSupport.meeting.options[0].key });
    const cible = jeu.bridge.vm.run('S.clubs[29].players[0].id');
    model = call('observe_player', { playerId: cible, confirmed: true, context: { season: model.meta.season, week: model.meta.week, club: model.club.id } });
    // Consigne de jeu après tout cela : décisions du manager reprises (aucun recalcul).
    const avantTactique = decisionsCalculees();
    model = call('set_tactics', { attack: model.tactics.attacks.find(o => o.id !== model.tactics.attack).id, defense: model.tactics.defense });
    const tactiqueDecisions = decisionsCalculees() - avantTactique;
    note('instantané', jeu.call('snapshot'));
    jeu.bridge.handle.flush();
    const profil = sha(fs.readFileSync(path.join(DOSSIER, 'PrototypeGodot', 'donnees.json'), 'utf8'));
    return { etapes, profil, lecturesMarche: 0, decisionsMarche, axeDomaines, tactiqueDecisions };
  } finally { jeu.fermer(); fs.rmSync(DOSSIER, { recursive: true, force: true }); }
}

// Même processus enfant que parcoursIsole du parcours commun, avec ce fichier comme script.
function parcoursIsole(options) { return C.parcoursIsole(options, __filename); }
if (require.main === module && process.argv[2] === '--parcours') {
  C.ecrireParcours(decisions(JSON.parse(process.argv[3])), process.argv[4]);
  process.exit(0);
}

module.exports = { parcoursIsole, comparer: C.comparer };
