'use strict';

// Match en temps forts, par le vrai moteur natif : projection `live.direct` minute par
// minute, sans effet sur le match. C'est le mode de base du moteur lancé par le jeu
// (repli : CD_MATCH_TEMPS_FORTS=0) ; `createBridge` ne projette que sur demande.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { spawnSync } = require('node:child_process');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const { context } = require('./harness.cjs');
const H = require('../native/engine/match-highlights.cjs');

function ouvrir(options) {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-direct-'));
  const bridge = createBridge({ dataDir, seed: 1000, now: 1700000000000, ...options });
  let id = 0;
  const brut = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  const call = (command, payload = {}) => { const r = brut(command, payload); assert.equal(r.ok, true, r.error); return r.model; };
  return { brut, call, fermer: () => { try { bridge.close?.(); } catch (error) { /* déjà fermé */ } fs.rmSync(dataDir, { recursive: true, force: true }); } };
}

function demarrer(jeu) {
  settleClubMeetings(jeu.call('new_career', { club: 0 }), jeu.call);
  return skipMatchTalk(jeu.call('begin_match'), jeu.call);
}

test('Sans l’option du pont, rien ne change : pas de projection, pas de pas « minute »', () => {
  const jeu = ouvrir({});
  try {
    const model = demarrer(jeu);
    assert.equal(model.live.direct, undefined);
    const refus = jeu.brut('tick', { minute: true, temps_forts: 'dynamique' });
    assert.equal(refus.ok, false);
    assert.match(refus.error, /Temps forts non activés/);
    assert.equal(jeu.call('tick').live.direct, undefined);
  } finally { jeu.fermer(); }
});

test('Avec la variable, le moteur projette chaque temps fort au moment où il est décidé', () => {
  assert.throws(() => createBridge({ dataDir: path.join(os.tmpdir(), 'oval-direct-refus'), matchHighlights: 'tout' }), /Niveau de temps forts inconnu/);
  const jeu = ouvrir({ matchHighlights: 'dynamique' });
  try {
    let model = demarrer(jeu);
    const vus = [];
    const observer = live => {
      const direct = live.direct;
      assert.equal(direct.version, 1);
      assert.equal(direct.niveau, 'dynamique');
      assert.equal(direct.niveaux.length, 6);
      assert.ok(direct.fil.length > 0 && direct.fil.every(l => typeof l.texte === 'string' && l.kind !== 'advantage'), 'fil sans messages d’avantage');
      assert.ok(direct.chiffres.length >= 5 && direct.chiffres.every(c => typeof c.home === 'string' && typeof c.away === 'string'));
      assert.ok(direct.zone.x >= 0 && direct.zone.x <= 100 && [0, 1].includes(direct.possession));
      const attendu = H.en_direct(live.events, { niveau: 'dynamique' }).courant;
      assert.equal(direct.tempsFort?.cle ?? null, attendu?.cle ?? null, 'la projection suit la sélection en direct');
      const tf = direct.tempsFort;
      if (!tf || vus.some(v => v.cle === tf.cle)) return;
      vus.push(tf);
      assert.ok(tf.fin < live.events.length, 'aucun plan du futur');
      assert.ok(tf.plans.length > 0 && tf.plans.length === attendu.plans.length);
      const cles = new Set();
      for (const plan of tf.plans) {
        assert.ok(plan.index >= tf.debut && plan.index <= tf.fin && plan.duree > 0 && typeof plan.texte === 'string');
        assert.ok(plan.scene.players.length > 20 && plan.scene.players.length <= 30, 'scène 3D complète');
        assert.ok(!cles.has(plan.scene.key), 'une scène par plan');
        cles.add(plan.scene.key);
        if (plan.kind === 'transformation') {
          const essai = live.events[plan.index].scene;
          assert.equal(plan.scene.kind, essai.conversion ? 'goal' : 'miss');
          assert.equal(plan.scene.players.filter(p => p.featured).length, 1, 'un buteur, face aux poteaux');
          assert.equal(Math.abs(plan.scene.origin.x - plan.scene.ball.x), 22);
          assert.deepEqual(plan.score, essai.score);
          assert.equal(plan.annonce, 'Transformation.');
        } else assert.equal(plan.scene.kind, live.events[plan.index].scene.kind);
        // La légende ne dit jamais le résultat avant l'image.
        if (plan.kind === 'try') assert.ok(!/transform|–/.test(plan.texte) && plan.texte.includes('Essai'), plan.texte);
        if (plan.kind === 'goal' || plan.kind === 'miss') assert.equal(plan.annonce, 'Tir au but.');
      }
      if (tf.depart) assert.ok(!tf.suite && !tf.plans[0].coupe && tf.depart.players.length > 20);
    };
    observer(model.live);
    assert.equal(model.live.direct.tempsFort?.type, 'coup_d_envoi', 'le coup d’envoi est le premier temps fort');
    for (let ticks = 0; ticks < 60 && model.live.minute < 36 && !model.live.finished; ticks++) {
      model = skipMatchTalk(model, jeu.call);
      if (model.live.paused) model = jeu.call('pause', { paused: false });
      const avant = model.live.events.length;
      model = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      assert.ok(model.live.events.length > avant, 'un pas simule une minute entière');
      observer(model.live);
    }
    assert.ok(vus.length >= 5, `au moins cinq temps forts en 35 minutes (${vus.length})`);
    assert.ok(vus.some(v => v.types.includes('essai')), 'un essai a été projeté');
    // Le niveau se change en cours de match, et un pas ordinaire reste refusé de travers.
    model = jeu.call('tick', { minute: true, temps_forts: 'aucun' });
    assert.equal(model.live.direct.niveau, 'aucun');
    assert.equal(model.live.direct.tempsFort, null);
    assert.equal(jeu.brut('tick', { minute: true, temps_forts: 'tout' }).ok, false);
    assert.equal(jeu.brut('tick', { minute: true, steps: 3 }).ok, false);
  } finally { jeu.fermer(); }
});

test('Le pas « minute » et la sélection ne changent ni le match ni le tirage', () => {
  const jouer = minute => {
    const { run } = context();
    run('start(3); beginMatch(); continueMatch();');
    let selections = 0;
    for (let i = 0; i < 900 && !run('S.live.finished'); i++) {
      if (!minute) { run('if (S.live.paused) continueMatch(); presentationTick(S.live);'); continue; }
      run('if (S.live.paused) continueMatch(); syncMatchPresentation(S.live); tick(); if (S.live) syncMatchPresentation(S.live);');
      selections += H.en_direct(JSON.parse(run('JSON.stringify(S.live.events)')), { niveau: 'dynamique' }).tempsForts.length;
    }
    assert.equal(run('S.live.finished'), true);
    return { carriere: run('JSON.stringify(S)'), tirage: run('Math.random()'), selections };
  };
  const ordinaire = jouer(false), direct = jouer(true);
  assert.ok(direct.selections > 0);
  assert.equal(direct.carriere, ordinaire.carriere, 'même carrière, journal et score compris');
  assert.equal(direct.tirage, ordinaire.tirage, 'même tirage suivant');
});

// Le moteur tel que le jeu le lance : un processus, des requêtes ligne par ligne.
function processus(env, requetes) {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-direct-processus-'));
  const propre = { ...process.env, ...env };
  for (const nom of ['CD_MATCH_TEMPS_FORTS', 'CD_MATCH_TEMPS_FORTS_NIVEAU']) if (!(nom in env)) delete propre[nom];
  try {
    const sortie = spawnSync(process.execPath, [path.resolve(__dirname, '../native/engine/worker.cjs'), '--data-dir', dataDir],
      { input: requetes.map((r, i) => JSON.stringify({ id: i + 1, ...r })).join('\n') + '\n', encoding: 'utf8', env: propre, timeout: 120000, maxBuffer: 256 * 1024 * 1024 });
    assert.equal(sortie.status, 0, sortie.stderr);
    return sortie.stdout.trim().split('\n').map(ligne => JSON.parse(ligne));
  } finally { fs.rmSync(dataDir, { recursive: true, force: true }); }
}

test('Sans aucune variable, le moteur du jeu projette les temps forts ; CD_MATCH_TEMPS_FORTS=0 rend le direct d’origine', () => {
  const source = context();
  source.run('start(0);beginMatch()');
  const texte = source.run('JSON.stringify(createSaveDocument())');
  const requetes = [{ command: 'import', payload: { text: texte } }, { command: 'pause', payload: { paused: false } },
    { command: 'tick', payload: { minute: true, temps_forts: 'dynamique' } }, { command: 'shutdown', payload: {} }];
  const defaut = processus({}, requetes);
  assert.equal(defaut[0].ok, true, defaut[0].error);
  assert.equal(defaut[0].model.live.directError, undefined, 'projection sans erreur');
  assert.equal(defaut[0].model.live.direct.niveau, 'dynamique', 'niveau par défaut');
  assert.equal(defaut[0].model.live.direct.tempsFort.type, 'coup_d_envoi');
  assert.equal(defaut[2].ok, true, defaut[2].error);
  assert.ok(defaut[2].model.live.minute >= 1 && defaut[2].model.live.direct, 'une minute simulée par requête');
  const complet = processus({ CD_MATCH_TEMPS_FORTS_NIVEAU: 'integral' }, requetes.slice(0, 1).concat(requetes.slice(-1)));
  assert.equal(complet[0].model.live.direct.niveau, 'integral', 'niveau imposé au lancement');
  const repli = processus({ CD_MATCH_TEMPS_FORTS: '0' }, requetes);
  assert.equal(repli[0].ok, true, repli[0].error);
  assert.equal(repli[0].model.live.direct, undefined, 'repli : aucune projection');
  assert.equal(repli[2].ok, false);
  assert.match(repli[2].error, /Temps forts non activés/);
  // Le pas d'origine reste servi dans les deux modes.
  for (const mode of [{}, { CD_MATCH_TEMPS_FORTS: '0' }]) {
    const pas = processus(mode, [requetes[0], requetes[1], { command: 'tick', payload: { steps: 4 } }, requetes[3]]);
    assert.equal(pas[2].ok, true, pas[2].error);
    assert.ok(pas[2].model.live.events.length > pas[0].model.live.events.length, 'le pas d’origine avance');
  }
});

test('Entracte 2D : déroulé des faits, domination, chiffres du rugby et notes, lus dans le journal', () => {
  const D = require('../native/engine/match-direct.cjs');
  const jeu = ouvrir({ matchHighlights: 'dynamique' });
  try {
    let model = demarrer(jeu);
    let deroules = 0;
    for (let k = 0; k < 26 && !model.live.finished; k++) {
      model = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      const live = model.live, direct = live.direct, events = live.events;
      // Déroulé : derniers faits jouables, dans l'ordre, jamais au-delà du journal.
      assert.ok(direct.deroule.length <= D.DEROULE_MAX);
      let avant = -1;
      for (const item of direct.deroule) {
        assert.ok(item.i > avant && item.i < events.length, 'ordre et journal');
        avant = item.i;
        const s = events[item.i].scene;
        assert.ok(s, 'chaque fait a sa scène dans le journal');
        assert.equal(item.kind, s.kind);
        assert.equal(item.scene.possession, s.possession, 'possession du moteur');
        assert.ok(item.scene.joueurs.length >= 26 && item.scene.joueurs.length <= 30, 'trente joueurs au plus');
        for (const [cote, poste, x, y] of item.scene.joueurs) assert.ok([0, 1].includes(cote) && poste >= 0 && poste <= 14 && x >= 0 && x <= 100 && y >= -1 && y <= 71);
        if (s.kind === 'carry') assert.ok(Math.abs(item.scene.ballon[0] - s.to.x) < 0.11 && Math.abs(item.scene.origine[0] - s.from.x) < 0.11, 'ballon au point du moteur');
        assert.deepEqual(item.score, H.normaliser(events)[item.i].scoreApres);
      }
      deroules += direct.deroule.length;
      // Domination : une valeur par minute jouée, bornée.
      const d = direct.domination;
      assert.ok(Array.isArray(d.minutes) && d.minutes.every(v => Number.isInteger(v) && v >= -100 && v <= 100));
      assert.deepEqual(d, D.domination(H.normaliser(events)));
      // Chiffres : possession sur 100, plaquages tirés des courses adverses.
      const t = Object.fromEntries(direct.tableau.map(r => [r.cle, r]));
      assert.equal(t.possession.valeurs[0] + t.possession.valeurs[1], 100);
      const lignes = H.normaliser(events);
      for (const cote of [0, 1]) {
        const courses = lignes.filter(l => l.kind === 'carry' && l.equipe === 1 - cote && Math.abs(l.x - l.depuis) < 22).length;
        const recup = lignes.filter(l => l.kind === 'turnover' && l.equipe === cote).length;
        assert.equal(t.plaquages.valeurs[cote], courses + recup, 'plaquages réussis = courses adverses stoppées + ballons récupérés');
        assert.equal(t.en_avant.valeurs[cote], lignes.filter(l => l.kind === 'hand-fault' && l.equipe === cote).length);
        assert.equal(t.melees.valeurs[cote], live.stats[cote].scrumsWon);
      }
      // Notes : joueurs du manager seulement, bornées.
      const camp = direct.camp, nous = new Set(events.flatMap(e => e.scene?.on?.[camp] || []).filter(Boolean).map(String));
      for (const [id, n] of Object.entries(direct.notes)) assert.ok(nous.has(id) && n.note >= 3 && n.note <= 9.9 && n.faits > 0, id);
    }
    assert.ok(deroules > 20, 'des faits à rejouer pendant les entractes : ' + deroules);
  } finally { jeu.fermer(); }
});
