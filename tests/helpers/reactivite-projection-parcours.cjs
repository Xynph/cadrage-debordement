'use strict';
// Parcours communs aux suites reactivite-projection-verification*.cjs et reactivite-projection-rapide*.cjs (ancienne
// suite unique reactivite-projection.cjs, au-delà des 180 s du lanceur) : un parcours Monde par processus, un segment
// par suite, comparaison par étapes. La suite reactivite-projection-decisions.cjs a son parcours dans
// reactivite-projection-decisions-parcours.cjs.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const M = require('./carriere-monde.cjs');
const { skipMatchTalk } = require('./scene-match-talks.cjs');
const { createEncoder, sectionTexts, TEXTS } = require('../../native/engine/model-delta.cjs');

const KEPT_LIVE = /^(clubLife\.(interclubMarket|managerCareer|regenScouting|clubSupport|staffCareer|coachNotebook|youthDevelopment|staffMentoring|clubWorld|performanceAnalysis|staffEmployment)|staff(\..*)?|international|decisions\.development|managerPlanning)$/;
const DOSSIER = path.join(os.tmpdir(), 'rl27-reactivite-' + process.pid);
const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');

// Textes du modèle par chemin (« clé » ou « clé.sous-clé » pour les clés découpées par l'encodeur).
function flat(model) {
  const s = sectionTexts(model), out = new Map();
  // Empreintes plutôt que textes : une trentaine de réponses de ~13 Mo par parcours.
  for (const key of s.keys) { const item = s.items.get(key); if (typeof item === 'string') out.set(key, sha(item)); else for (const name of item.keys) out.set(key + '.' + name, sha(item.texts.get(name))); }
  return out;
}

// Segments du parcours (16/11/2026, pour rester sous le délai de 180 s du lanceur CI) : chaque segment rejoue la même
// carrière, mêmes graines et mêmes appels dans le même ordre, mais ne relève et ne compare que ses propres réponses,
// puis s'arrête (les appels des segments précédents ne sont ni relevés ni hachés).
//   'consignes' : instantané, création, lectures, tactiques, composition, charge, adversaire, axe collectif, refus ;
//   'semaines'  : les semaines closes jusqu'au prochain match ;
//   'direct'    : coup d'envoi, pause, consigne, minutes, délégation, fin de semaine, après le match, sur une carrière
//                 ouverte la veille de la première rencontre (`start: 'veille'`, comme tests/sauvegarde-journal-plantage-monde.cjs) :
//                 sans elle, le direct rejouait deux mois de calendrier (4 semaines closes, déjà couvertes par 'semaines').
const SEGMENTS = ['consignes', 'semaines', 'direct'];

function parcours(options) {
  const { segment, ...reglages } = options;
  assert.ok(SEGMENTS.includes(segment), 'segment du parcours : ' + segment);
  let etape = 'consignes';
  const actif = () => etape === segment;
  fs.rmSync(DOSSIER, { recursive: true, force: true });
  const jeu = M.ouvrir({ hebdomadaire: true, deferredCommits: true, testVm: true, dataDir: DOSSIER, ...reglages });
  const etapes = [];
  try {
    if (reglages.projectionSections !== false) jeu.bridge.vm.run("{const d=nativeSystems.domain('interclubMarket'),o=d.project;globalThis.__marche=0;d.project=function(){__marche++;return o.apply(this,arguments);};}");
    const marche = () => reglages.projectionSections !== false ? jeu.bridge.vm.run('__marche') : 0;
    const note = (etiquette, model, live = false) => {
      if (actif()) { const textes = flat(model); textes.set('meta.dataDir', ''); etapes.push({ etiquette, textes, live, joint: !!model[TEXTS] }); }
      return model;
    };
    const call = (command, payload, live) => { const model = jeu.call(command, payload); jeu.bridge.handle.flush(); return note(command, model, live); };
    const fin = () => {
      jeu.bridge.handle.flush();
      return { etapes, profil: sha(fs.readFileSync(path.join(DOSSIER, 'PrototypeGodot', 'donnees.json'), 'utf8')), lecturesMarche };
    };
    let lecturesMarche = 0;
    // Direct : coup d'envoi, pause, consigne, minutes, délégation, fin.
    const direct = depart => {
      let model = depart;
      etape = 'direct';
      if (!model.selection.valid) model = call('auto_lineup');
      model = note('coup d’envoi', skipMatchTalk(jeu.call('begin_match'), jeu.call));
      model = call('pause', { paused: true }, true);
      model = call('set_tactics', { attack: model.tactics.attacks.find(o => o.id !== model.tactics.attack).id, defense: model.tactics.defense }, true);
      model = call('pause', { paused: false }, true);
      for (let q = 0; q < 6 && model.live && !model.live.finished; q++) model = call('tick', { steps: 10 }, true);
      model = note('délégation', skipMatchTalk(jeu.call('delegate'), jeu.call));
      if (model.live) model = note('fin de semaine', skipMatchTalk(jeu.call('finish_round'), jeu.call));
      note('après le match', jeu.call('snapshot'));
      return fin();
    };
    let model;
    if (segment === 'direct') {
      etape = 'direct';
      model = note('création', jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' })));
      return direct(model);
    }
    note('instantané', jeu.call('snapshot'));
    model = M.creer(jeu);
    note('création', model);
    const avantLectures = marche();
    call('snapshot'); call('club_sheet', { club: 5 }); call('club_sheet', { club: 9 });
    lecturesMarche = marche() - avantLectures;
    for (let i = 0; i < 2; i++) model = call('set_tactics', { attack: model.tactics.attacks.find(o => o.id !== model.tactics.attack).id, defense: model.tactics.defense });
    model = call('auto_lineup');
    model = call('set_player_load', { playerId: model.squad[4].id, mode: 'repos' });
    model = call('set_opponent_level', { level: 'decouverte' });
    model = call('set_collective_focus', { focus: 'conquete' });
    // Refus sans effet (rendez-vous inconnu) : modèle complet ici, comparé plus bas à la réponse légère.
    const refus = jeu.brut('club_meeting_ack', { meetingId: 'inconnu' });
    assert.equal(refus.ok, false);
    note('refus', refus.model);
    if (segment === 'consignes') return fin();
    etape = 'semaines';
    // Jusqu'au prochain match (semaines closes).
    for (let w = 0; w < 30 && !model.next; w++) { model = jeu.regler(model); if (model.next) break; model = call('finish_round'); }
    model = jeu.regler(model);
    return fin();
  } finally { jeu.fermer(); fs.rmSync(DOSSIER, { recursive: true, force: true }); }
}

// Chaque parcours dans son propre processus (tas plafonné) : deux carrières Monde de suite tiennent sur 8 Go.
// `script` : fichier qui reconnaît `--parcours` (par défaut ce module ; la suite des décisions a le sien).
function parcoursIsole(options, script = __filename) {
  const { spawnSync } = require('node:child_process');
  const sortie = path.join(os.tmpdir(), 'rl27-reactivite-parcours-' + process.pid + '.json');
  const child = spawnSync(process.execPath, ['--max-old-space-size=2048', script, '--parcours', JSON.stringify(options), sortie], { encoding: 'utf8', maxBuffer: 64 * 1048576, timeout: 1500000 });
  assert.equal(child.status, 0, 'parcours ' + JSON.stringify(options) + ' : ' + (child.stderr || '').slice(-2000));
  const out = JSON.parse(fs.readFileSync(sortie, 'utf8'));fs.rmSync(sortie, { force: true });
  out.etapes.forEach(e => { e.textes = new Map(e.textes); });
  return out;
}
// Sortie d'un processus enfant : résultat du parcours écrit en JSON (textes en tableaux).
function ecrireParcours(out, sortie) {
  out.etapes.forEach(e => { e.textes = [...e.textes]; });
  fs.writeFileSync(sortie, JSON.stringify(out));
}
if (require.main === module && process.argv[2] === '--parcours') {
  ecrireParcours(parcours(JSON.parse(process.argv[3])), process.argv[4]);
  process.exit(0);
}

function comparer(reference, autre, nom) {
  assert.equal(autre.etapes.length, reference.etapes.length, nom + ' : même nombre de réponses');
  let derniereComplete = null, gardees = 0;
  reference.etapes.forEach((a, i) => {
    const b = autre.etapes[i], ecarts = [];
    for (const key of new Set([...a.textes.keys(), ...b.textes.keys()])) {
      if (a.textes.get(key) === b.textes.get(key)) continue;
      // Direct : section gardée = celle de la dernière réponse complète.
      if (b.live && KEPT_LIVE.test(key) && derniereComplete && b.textes.get(key) === derniereComplete.textes.get(key)) { gardees++; continue; }
      ecarts.push(key);
    }
    assert.deepEqual(ecarts.slice(0, 8), [], nom + ' : ' + a.etiquette + ' (' + i + ')');
    if (!b.live) derniereComplete = b;
  });
  assert.equal(autre.profil, reference.profil, nom + ' : profil écrit identique');
  return gardees;
}

module.exports = { DOSSIER, M, TEXTS, createEncoder, flat, sha, parcoursIsole, ecrireParcours, comparer };
