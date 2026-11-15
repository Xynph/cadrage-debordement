'use strict';
// « Continuer » jusqu'au prochain événement (advance_until_event, native/engine/continuer.cjs), carrière Monde
// (`world-champ`) démarrée le lundi 13 juillet 2026 (« Reprise des premiers clubs »), comme dans le jeu.
//   1. Règle d'arrêt (pure) : liste des arrêts, obligatoires jamais ignorables, réglages messages et blessures.
//   2. Une seule commande avance du 13/07 au jour du premier match quand aucun événement n'arrête la carrière
//      (rendez-vous du club coupés ici, comme dans tests/monde-harness.cjs, pour isoler le calendrier).
//   3. Arrêt sur un rendez-vous obligatoire : la commande suivante est refusée tant qu'il n'est pas réglé, sans
//      rien changer ; une fois réglé, Continuer repart.
//   4. Même graine : l'état de carrière, la graine et le profil écrit sont identiques à N « Jour suivant »
//      successifs, y compris en tranches partielles (réponses sans modèle, puis arrêt demandé par le joueur).
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const C = require('../native/engine/continuer.cjs');

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const fichier = dir => path.join(dir, 'PrototypeGodot', 'donnees.json');
const enregistre = dir => JSON.parse(fs.readFileSync(fichier(dir), 'utf8')).store['bdt-v1'];
const FACULTATIFS = Object.keys(C.STOPS).filter(k => !C.STOPS[k].mandatory);

test('Règle d’arrêt : obligatoires jamais ignorés, réglages des messages et des blessures', () => {
  const base = { today: '2026-09-01', matchReady: false, canAdvance: true, ended: false, live: false, meeting: null, press: false, pressIds: [],
    sceneActive: null, sceneIds: [], serial: 3, inbox: [], national: [], nationalTitles: {}, fixtures: 'f', next: { date: '2026-09-05', opponent: 'Rivaux' },
    starters: ['t1'], injured: [], names: { t1: 'Titulaire', r1: 'Remplaçant' }, tired: [], squad: 't1,r1', window: null, preseason: false };
  const o = C.validate({ fromDate: '2026-09-01' });
  assert.equal(C.detect(base, { ...base, today: '2026-09-02' }, o), null, 'jour sans événement');
  assert.equal(C.detect(base, { ...base, matchReady: true }, C.validate({ fromDate: '2026-09-01', stops: { ignorer: FACULTATIFS } })).kind, 'match');
  assert.equal(C.detect(base, { ...base, meeting: { kind: 'medical', id: 'm' } }, o).kind, 'rendez_vous');
  assert.equal(C.detect(base, { ...base, press: true }, o).kind, 'conference');
  assert.equal(C.detect(base, { ...base, fixtures: 'g' }, o).kind, 'calendrier', 'une rencontre déplacée arrête toujours (courrier de calendrier)');
  for (const kind of Object.keys(C.STOPS).filter(k => C.STOPS[k].mandatory))
    assert.throws(() => C.validate({ fromDate: '2026-09-01', stops: { ignorer: [kind] } }), /obligatoire/, kind + ' ne peut pas être ignoré');
  // Blessures : titulaires par défaut, tout l'effectif sur réglage.
  assert.equal(C.detect(base, { ...base, injured: ['r1'] }, o), null);
  assert.equal(C.detect(base, { ...base, injured: ['r1'] }, C.validate({ fromDate: '2026-09-01', stops: { blessures: 'effectif' } })).kind, 'blessure');
  assert.match(C.detect(base, { ...base, injured: ['t1'] }, o).detail, /Titulaire blessé \(titulaire\)/);
  // Messages : la routine ne coupe pas l'avance en mode « importants ».
  const point = { ...base, serial: 4, inbox: [{ n: 4, title: 'Le point de la semaine', kind: 'club' }] };
  assert.equal(C.detect(base, point, o), null);
  assert.equal(C.detect(base, point, C.validate({ fromDate: '2026-09-01', stops: { messages: 'tous' } })).kind, 'message');
  const offre = { ...base, serial: 4, inbox: [{ n: 4, title: 'Offre pour votre ailier', kind: 'recruitment' }] };
  assert.equal(C.detect(base, offre, o).kind, 'message');
  assert.equal(C.detect(base, offre, C.validate({ fromDate: '2026-09-01', stops: { messages: 'aucun' } })), null);
  // Gabi : fatigue des titulaires seulement à l'approche d'un match.
  assert.equal(C.detect(base, { ...base, tired: ['t1'] }, o).kind, 'fatigue');
  assert.equal(C.detect(base, { ...base, tired: ['t1'], next: { date: '2026-10-30', opponent: 'X' } }, o), null);
  assert.throws(() => C.validate({ fromDate: '2026-09-01', maxDays: 0 }), /jours/);
  assert.throws(() => C.validate({ fromDate: '2026-09-01', inconnu: 1 }), /invalides/);
});

let racine, origine;
before(() => {
  // Une seule carrière Monde créée (étape coûteuse), copiée pour chaque essai.
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-continuer-'));
  origine = path.join(racine, 'origine');
  const jeu = M.ouvrir({ dataDir: origine });
  try {
    // Départ par défaut de l'écran de création : « Reprise des premiers clubs », lundi 13 juillet 2026.
    const m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs' }));
    assert.equal(m.meta.calendarToday, '2026-07-13');
    jeu.call('save');
  } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

let copies = 0;
function copie() {
  const dir = path.join(racine, 'copie-' + (++copies));
  fs.cpSync(origine, dir, { recursive: true });
  fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
  return dir;
}
const ouvrir = (dir, extra = {}) => M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, ...extra });

const avancer = (jeu, model, extra = {}) => jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, ...extra });

test('Une seule commande : du 13/07 au jour du premier match', { timeout: 1500000 }, () => {
  const dir = copie();
  // Presse non obligatoire (option du pont) et rendez-vous du club coupés (comme tests/monde-harness.cjs) : seul le
  // calendrier peut arrêter l'avance.
  const jeu = ouvrir(dir, { mandatoryPress: false });
  try {
    // Rendez-vous du club coupés (comme tests/monde-harness.cjs) : seul le calendrier peut arrêter l'avance.
    jeu.bridge.vm.run("{const d=nativeSystems.domain('clubMeetings');d.observe=()=>{};delete S.clubMeetings;}");
    let model = jeu.call('snapshot');
    assert.equal(model.meta.calendarToday, '2026-07-13');
    const t = performance.now();
    model = avancer(jeu, model, { stops: { messages: 'aucun', ignorer: FACULTATIFS } });
    const duree = performance.now() - t;
    const a = model.meta.advanceUntilEvent;
    console.log('13/07 → premier match en une commande :', a.days, 'jours,', Math.round(duree), 'ms ·', a.stop.detail);
    assert.equal(a.stop.kind, 'match', JSON.stringify(a));
    assert.equal(model.meta.calendarCadence.matchReady, true, 'le jour du match est atteint, jamais dépassé');
    assert.equal(model.next.date ?? model.meta.calendarToday, model.meta.calendarToday);
    assert.ok(a.days > 40, 'plusieurs semaines avancées en une commande');
    // Sauvegarde garantie à l'arrêt : le profil écrit est la carrière en mémoire.
    assert.equal(jeu.call('export', { proof: true }).meta.exportRoundTripSha256, sha(enregistre(dir)));
    // Le match ne peut pas être sauté : Continuer est refusé le jour du match, comme « Jour suivant ».
    const refus = jeu.brut('advance_until_event', { fromDate: model.meta.calendarToday });
    assert.equal(refus.ok, false);
    assert.match(refus.error, /rencontre/i);
  } finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Arrêt sur un rendez-vous obligatoire, refus tant qu’il n’est pas réglé', { timeout: 1500000 }, () => {
  const dir = copie();
  const jeu = ouvrir(dir);
  try {
    let model = jeu.call('snapshot');
    model = avancer(jeu, model, { stops: { messages: 'aucun', ignorer: FACULTATIFS } });
    const a = model.meta.advanceUntilEvent;
    assert.equal(a.stop.kind, 'rendez_vous', JSON.stringify(a));
    assert.ok(model.clubLife.clubMeetings.scene, 'le rendez-vous est là, en Réception');
    const date = model.meta.calendarToday, avant = enregistre(dir);
    const refus = jeu.brut('advance_until_event', { fromDate: date });
    assert.equal(refus.ok, false, 'un rendez-vous obligatoire n’est jamais sauté');
    assert.equal(refus.model.meta.calendarToday, date);
    assert.equal(enregistre(dir), avant, 'rien n’est écrit');
    model = jeu.regler(refus.model);
    model = avancer(jeu, model, { maxDays: 1 });
    assert.notEqual(model.meta.calendarToday, date, 'une fois réglé, Continuer repart');
  } finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Même graine : état et profil identiques à N « Jour suivant » successifs', { timeout: 2400000 }, () => {
  // Parcours A : Continuer en tranches partielles (budget minimal, réponses sans modèle), arrêts réels du jeu,
  // rendez-vous réglés à chaque arrêt ; puis « Arrêter » au milieu d'une avance.
  // Chaque parcours dans sa propre fonction : un seul pont Monde vivant à la fois (machine de 8 Go).
  const finalA = (() => {
  const dirA = copie(), A = ouvrir(dirA);
  const dates = [];
  try {
    let model = A.call('snapshot'), partielles = 0;
    for (let arret = 0; arret < 4; arret++) {
      model = A.regler(model);
      let r = A.brut('advance_until_event', { fromDate: model.meta.calendarToday, budgetMs: 1, partial: true });
      while (r.ok && !r.model) {
        partielles++;
        assert.ok(r.progress?.today > model.meta.calendarToday, 'la date défile');
        r = A.brut('advance_until_event', { fromDate: r.progress.today, budgetMs: 1, partial: true });
      }
      assert.equal(r.ok, true, r.error);
      model = r.model;
      dates.push([model.meta.calendarToday, model.meta.advanceUntilEvent.stop.kind]);
    }
    model = A.regler(model);
    // « Arrêter » après une tranche : les jours passés sont écrits.
    const r = A.brut('advance_until_event', { fromDate: model.meta.calendarToday, budgetMs: 1, partial: true });
    assert.equal(r.ok, true);
    if (!r.model) {
      model = A.call('advance_until_event', { fromDate: r.progress.today, stop: true });
      assert.equal(model.meta.advanceUntilEvent.stop.kind, 'arret');
    } else model = r.model;
    dates.push([model.meta.calendarToday, model.meta.advanceUntilEvent.stop.kind]);
    console.log('arrêts :', JSON.stringify(dates), '· tranches partielles :', partielles);
    assert.ok(partielles > 0, 'des réponses partielles ont été reçues');
    assert.equal(A.call('export', { proof: true }).meta.exportRoundTripSha256, sha(enregistre(dirA)), 'profil écrit à l’arrêt');
    return { etat: sha(A.bridge.vm.run('JSON.stringify(S)')), graine: A.bridge.vm.seed(), profil: sha(enregistre(dirA)), date: model.meta.calendarToday };
  } finally { A.bridge.close(); fs.rmSync(dirA, { recursive: true, force: true }); }
  })();
  // Parcours B : « Jour suivant » jour par jour, mêmes rendez-vous réglés aux mêmes jours.
  (() => {
  const dirB = copie(), B = ouvrir(dirB);
  try {
    let model = B.call('snapshot');
    for (let j = 0; j < 130 && model.meta.calendarToday !== finalA.date; j++) {
      model = B.regler(model);
      model = B.call('advance_day', { fromDate: model.meta.calendarToday });
    }
    assert.equal(model.meta.calendarToday, finalA.date);
    const etat = B.bridge.vm.run('JSON.stringify(S)');
    assert.equal(sha(etat), finalA.etat, 'état de carrière identique');
    assert.equal(B.bridge.vm.seed(), finalA.graine, 'graine identique');
    assert.equal(sha(enregistre(dirB)), finalA.profil, 'profil écrit identique');
  } finally { B.bridge.close(); fs.rmSync(dirB, { recursive: true, force: true }); }
  })();
});
