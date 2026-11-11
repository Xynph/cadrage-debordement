'use strict';

// Direct en temps forts (CD_MATCH_TEMPS_FORTS=1), par le vrai moteur natif :
// projection `live.direct` minute par minute, sans effet sur le match.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
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

test('Sans la variable, rien ne change : pas de projection, pas de pas « minute »', () => {
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
