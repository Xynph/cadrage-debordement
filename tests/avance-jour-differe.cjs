'use strict';
// Jour différé (lot 36, native/engine/worker.cjs, dayDeferral) : en mode journal (le jeu), un jour du calendrier est
// noté au journal avant sa réponse ; sa validation stricte (clôture de semaine) et la sauvegarde complète due suivent la
// réponse, et les jours de « Continuer » ne sont sérialisés qu'une fois, à l'arrêt. Carrière Monde (`world-champ`)
// préparée une fois jusqu'à la veille de la première clôture de semaine (fin de la semaine 0), puis copiée :
//   1. même graine, mêmes commandes (clôture, « Continuer », jour) : même carrière, même graine, même profil écrit
//      qu'avec le chemin d'avant (CD_JOUR_DIFFERE=0 / dayDeferral:false) ; la clôture ne valide pas avant sa réponse,
//      la validation suit ;
//   2. une validation qui échoue après la réponse annule la journée, raccourcit le journal et la commande suivante le
//      dit ; la carrière reprend ensuite normalement ;
//   3. « Continuer » : un jour qui échoue après avoir modifié la carrière (sans copie d'annulation) ramène au début de
//      l'avance, rejoue les jours déjà passés et s'arrête sur un blocage, avec la même carrière qu'en jouant ces jours
//      un par un.
// Une seule carrière Monde ouverte à la fois, tas plafonné comme dans le jeu (engine_bridge.gd).
if (!process.execArgv.some(a => a.startsWith('--max-old-space-size'))) {
  const r = require('node:child_process').spawnSync(process.execPath, ['--max-old-space-size=2048', ...process.execArgv, __filename, ...process.argv.slice(2)], { stdio: 'inherit' });
  process.exit(r.status ?? 1);
}
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const J = require('../native/engine/action-journal.cjs');

const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const profil = dir => path.join(dir, 'PrototypeGodot', 'donnees.json');
const lignes = dir => { try { return fs.readFileSync(path.join(dir, 'PrototypeGodot', J.FILE), 'utf8').split('\n').filter(Boolean).length; } catch { return 0; } };
// Veille de clôture : le prochain jour clôt la semaine (worker.cjs, advancesWithinWeek).
const veille = jeu => jeu.bridge.vm.run('!CDPreseason.pending(S)&&(nativeDailyStatus()?.day??6)>=6');
const etat = jeu => ({ carriere: sha(jeu.bridge.vm.run('JSON.stringify(S)')), graine: jeu.bridge.vm.seed() });

let racine, origine;
before(() => {
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-jour-differe-'));
  origine = path.join(racine, 'origine');
  const jeu = M.ouvrir({ dataDir: origine, journal: true, deferredCommits: true, testVm: true });
  try {
    let model = M.creer(jeu);
    // Avant-saison franchie par « Continuer » (arrêts réglés), puis jour par jour jusqu'à la veille de la clôture.
    for (let i = 0; i < 40 && model.meta.calendarToday < '2026-08-17'; i++) model = jeu.regler(jeu.call('advance_until_event', { fromDate: model.meta.calendarToday }));
    for (let i = 0; i < 10 && !veille(jeu); i++) model = jeu.regler(jeu.call('advance_day', { fromDate: model.meta.calendarToday }));
    assert.ok(veille(jeu), 'veille de clôture atteinte (' + model.meta.calendarToday + ')');
    jeu.call('save');
  } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

let copies = 0;
function ouvrir(options = {}) {
  const dir = path.join(racine, 'copie-' + (++copies));
  fs.cpSync(origine, dir, { recursive: true });
  fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
  return M.ouvrir({ dataDir: dir, journal: true, deferredCommits: true, lightErrors: true, testVm: true, ...options });
}
// Compte les validations strictes (appels de nativeValidateSaved).
const espionner = jeu => jeu.bridge.vm.run('{const o=nativeValidateSaved;globalThis.__validations=0;nativeValidateSaved=function(){__validations++;return o.apply(this,arguments);};}');
const validations = jeu => jeu.bridge.vm.run('__validations');
const jour = (jeu, model) => jeu.call('advance_day', { fromDate: jeu.regler(model).meta.calendarToday });

test('Même graine : même carrière et même profil écrit qu’avec le chemin d’avant ; la validation suit la réponse', { timeout: 900000 }, () => {
  const parcours = (options, observer) => {
    const jeu = ouvrir(options);
    try {
      espionner(jeu);
      let model = jeu.call('snapshot');
      assert.ok(veille(jeu));
      const etapes = [];
      model = jour(jeu, model);
      observer(jeu, 'clôture');
      etapes.push({ date: model.meta.calendarToday, semaine: model.meta.week, ...etat(jeu) });
      model = jeu.regler(model);
      jeu.bridge.handle.flush();
      jeu.bridge.vm.run('__validations=0');
      model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday });
      jeu.bridge.handle.flush();
      etapes.push({ date: model.meta.calendarToday, jours: model.meta.advanceUntilEvent.days, arret: model.meta.advanceUntilEvent.stop.kind, ...etat(jeu) });
      model = jour(jeu, model);
      jeu.bridge.handle.flush();
      etapes.push({ date: model.meta.calendarToday, ...etat(jeu) });
      jeu.call('shutdown');
      const p = JSON.parse(fs.readFileSync(profil(jeu.dataDir), 'utf8'));
      return { etapes, profil: { carriere: sha(p.store['bdt-v1']), seed: p.seed, clock: p.clock } };
    } finally { jeu.fermer(); }
  };
  const differe = parcours({}, jeu => {
    // Réponse de la clôture sans validation stricte ; elle suit la réponse (flush).
    assert.equal(validations(jeu), 0, 'aucune validation avant la réponse');
    assert.equal(jeu.bridge.handle.pending(), 'advance_day', 'validation en attente');
    jeu.bridge.handle.flush();
    assert.equal(validations(jeu), 1, 'validation faite après la réponse');
    assert.equal(jeu.bridge.handle.pending(), null);
  });
  const avant = parcours({ dayDeferral: false }, jeu => {
    assert.equal(validations(jeu), 1, 'chemin d’avant : validation avant la réponse');
    assert.equal(jeu.bridge.handle.pending(), null);
  });
  assert.notEqual(differe.etapes[0].semaine, undefined);
  assert.deepEqual(differe.etapes, avant.etapes, 'mêmes jours, même carrière, même graine à chaque étape');
  assert.deepEqual(differe.profil, avant.profil, 'même profil écrit à la fermeture');
});

test('Validation en échec après la réponse : journée annulée, journal raccourci, commande suivante refusée avec la raison', { timeout: 600000 }, () => {
  const jeu = ouvrir();
  try {
    let model = jeu.call('snapshot');
    const avant = etat(jeu), date = model.meta.calendarToday, notees = lignes(jeu.dataDir);
    model = jeu.call('advance_day', { fromDate: date });
    assert.notEqual(model.meta.calendarToday, date, 'la réponse montre le jour suivant');
    assert.equal(lignes(jeu.dataDir), notees + 1, 'jour noté au journal avant la réponse');
    assert.equal(jeu.bridge.handle.pending(), 'advance_day');
    // La validation qui suit la réponse échoue.
    jeu.bridge.vm.run('{const o=nativeValidateSaved;globalThis.__restaurer=()=>{nativeValidateSaved=o;};nativeValidateSaved=function(){throw Error("contrôle simulé");};}');
    jeu.bridge.handle.flush();
    jeu.bridge.vm.run('__restaurer()');
    assert.deepEqual(etat(jeu), avant, 'carrière et graine d’avant la journée');
    assert.equal(lignes(jeu.dataDir), notees, 'ligne de la journée retirée du journal');
    const refus = jeu.brut('snapshot');
    assert.equal(refus.ok, false);
    assert.match(refus.error, /dernière journée n’a pas pu être enregistrée.*contrôle simulé/);
    assert.equal(refus.model.meta.calendarToday, date);
    model = jeu.call('advance_day', { fromDate: date });
    assert.notEqual(model.meta.calendarToday, date, 'la journée se rejoue ensuite');
    jeu.bridge.handle.flush();
    assert.equal(jeu.brut('snapshot').ok, true);
  } finally { jeu.fermer(); }
});

test('Continuer : un jour en échec après modification ramène au début de l’avance, rejoue les jours passés et s’arrête', { timeout: 900000 }, () => {
  // Référence (chemin d'avant) : clôture, rendez-vous réglés, puis deux jours un par un.
  const ref = ouvrir({ dayDeferral: false });
  let attendu, depart;
  try {
    let model = ref.regler(ref.call('advance_day', { fromDate: ref.call('snapshot').meta.calendarToday }));
    depart = model.meta.calendarToday;
    model = ref.call('advance_day', { fromDate: depart });
    model = ref.call('advance_day', { fromDate: model.meta.calendarToday });
    attendu = { date: model.meta.calendarToday, ...etat(ref) };
  } finally { ref.fermer(); }
  const jeu = ouvrir();
  try {
    let model = jeu.regler(jeu.call('advance_day', { fromDate: jeu.call('snapshot').meta.calendarToday }));
    jeu.bridge.handle.flush();
    assert.equal(model.meta.calendarToday, depart);
    // Troisième jour de l'avance : la carrière est modifiée (jour passé) puis le moteur échoue.
    jeu.bridge.vm.run(`{const o=nativeKnowledge.observe;let n=0;globalThis.__restaurer=()=>{nativeKnowledge.observe=o;};nativeKnowledge.observe=function(){const r=o.apply(this,arguments);if(nativeCommand==='advance_day'&&++n===3)throw Error("panne simulée");return r;};}`);
    const r = jeu.brut('advance_until_event', { fromDate: depart, maxDays: 10 });
    jeu.bridge.vm.run('__restaurer()');
    assert.equal(r.ok, true, r.error);
    const avance = r.model.meta.advanceUntilEvent;
    assert.equal(avance.stop.kind, 'blocage', JSON.stringify(avance.stop));
    assert.match(avance.stop.detail, /panne simulée/);
    assert.equal(avance.days, 2, 'deux jours passés et gardés');
    jeu.bridge.handle.flush();
    assert.deepEqual({ date: r.model.meta.calendarToday, ...etat(jeu) }, attendu, 'même carrière qu’en jouant les deux jours un par un');
    model = jeu.call('advance_day', { fromDate: r.model.meta.calendarToday });
    assert.ok(model.meta.calendarToday > attendu.date, 'la carrière continue');
  } finally { jeu.fermer(); }
});
