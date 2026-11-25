'use strict';
// Même suite au rechargement (règle de Léo du 24/11/2026, anti-triche) : couper le jeu ne relance pas les dés ; seules des
// décisions différentes changent la suite. Les mémoires du budget (native/engine/club-budget.cjs, budget…Memo) gardaient
// des valeurs calculées plus tôt (éventail des réputations du premier appel de la saison, staff de la semaine, conseils de
// prix, limites de masse) qu'une sauvegarde rechargée, mémoires vides, recalculait autrement : charges et affluences
// divergeaient, et les comptes étaient faux pendant la partie même sans rechargement.
//   1. Partie d'une traite == partie fermée puis rouverte (sauvegarde complète du jeu, même graine, mêmes décisions) à
//      plusieurs moments : semaine de match avant le coup d'envoi (milieu de semaine), intersaison (saison close, avant
//      « Saison suivante »), début de la saison 2 (juste après), puis en saison 2. Empreinte de tout l'état (finances, affluences, classements, effectifs,
//      transferts, graine) identique à chaque point de comparaison et à la fin, sur 1,5 saison, graines 2026 et 7 (une suite par graine).
//   2. Dans la partie d'une traite, une valeur retrouvée sur 20 dans chaque mémoire du budget est recalculée : toujours
//      celle d'un calcul frais (budgetMemoVerifier), donc des comptes justes même sans rechargement.
// Une graine par suite (tests/budget-rechargement-2026.cjs, tests/budget-rechargement-7.cjs), donc par place de la CI : les deux
// parties d'une graine (d'une traite, rechargée) tournent dans des processus séparés, en même temps.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex').slice(0, 16);

// ---------------------------------------------------------------- partie jouée dans un processus enfant
// node tests/budget-rechargement.cjs --partie <graine> <traite|recharge> <sortie.json>
function partie(graine, mode, sortie) {
  const M = require('./carriere-monde.cjs');
  const verifie = mode === 'traite';
  // Cadence de la semaine (comme les autres tests Monde longs ; jour par jour, 1,5 saison prenait plus d'une heure sous
  // charge). Écritures différées, journal et sauvegarde complète à la fermeture, comme le jeu (worker.cjs).
  const options = { testVm: true, hebdomadaire: true, leanModel: true, deferredCommits: true, journal: true, savePolicy: 'mois', seed: graine };
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-recharge-'));
  let jeu = M.ouvrir({ ...options, dataDir });
  const points = [], recharges = [];
  const empreinte = () => {
    const cles = JSON.parse(jeu.bridge.vm.run('JSON.stringify(Object.keys(S))')), parCle = {};
    for (const k of cles) parCle[k] = sha(jeu.bridge.vm.run('JSON.stringify(S[' + JSON.stringify(k) + '])') ?? 'undefined');
    return { graine: jeu.bridge.vm.seed(), tout: sha(JSON.stringify(parCle)), parCle };
  };
  const noter = (nom, model) => { points.push({ nom, saison: model.meta.season, semaine: model.meta.week, ...empreinte() }); fs.writeFileSync(sortie, JSON.stringify({ points, recharges })); };
  const recharger = nom => {
    const avant = empreinte();
    jeu.fermer();
    jeu = M.ouvrir({ ...options, dataDir });
    const model = jeu.call('snapshot'), apres = empreinte();
    recharges.push({ nom, identique: avant.tout === apres.tout && avant.graine === apres.graine, ecarts: Object.keys(apres.parCle).filter(k => apres.parCle[k] !== avant.parCle[k]) });
    return model;
  };
  let model = M.creer(jeu);
  if (verifie) jeu.bridge.vm.run('budgetMemoVerifier=20');
  // Billetterie confiée au staff : les prix des réceptions suivent ses conseils (mémoire budgetConseilsMemo).
  model = jeu.call('club_ticket_delegate', { context: model.clubLife.clubStrategy.context, delegue: true });
  const fin = { saison: 2, matchs: 12 };
  let saison = model.meta.season, matchsSaison = 0, k = 0, intersaison = false;
  for (;;) {
    // Jusqu'à la semaine du match ; à l'intersaison (saison close), comparaison et rechargement avant « Saison suivante ».
    for (let j = 0; j < 150; j++) {
      model = jeu.regler(model);
      if (model.meta.phase === 'ended') {
        if (!intersaison) { intersaison = true; noter('intersaison', model); if (mode === 'recharge') model = jeu.regler(recharger('intersaison')); }
        model = jeu.regler(jeu.call('next_season', { confirmed: true }));
        // Début de la saison 2, juste après « Saison suivante » (budget de la saison voté, limites de masse fixées).
        if (model.meta.season === 2 && !points.some(x => x.nom === 'début de saison 2')) { noter('début de saison 2', model); if (mode === 'recharge') model = jeu.regler(recharger('début de saison 2')); }
        continue;
      }
      if (model.next) break;
      model = jeu.call('finish_round');
    }
    if (model.meta.season !== saison) { saison = model.meta.season; matchsSaison = 0; }
    k++; matchsSaison++;
    // Semaine de match, avant le coup d'envoi : milieu de semaine (mémoires de la semaine déjà remplies).
    if ([3, 14].includes(k) || (saison === 2 && matchsSaison === 4)) { noter('avant le match ' + k, model); if (mode === 'recharge') model = jeu.regler(recharger('avant le match ' + k)); }
    model = M.jouerLeMatch(jeu, model);
    if (k % 4 === 0) noter('après le match ' + k, model);
    if (saison > fin.saison || (saison === fin.saison && matchsSaison >= fin.matchs)) break;
  }
  noter('fin', model);
  const ecartsMemo = verifie ? JSON.parse(jeu.bridge.vm.run('typeof budgetMemoEcarts==="undefined"?"null":JSON.stringify({ecarts:budgetMemoEcarts,retrouvees:[...budgetMemoRetrouvees]})')) : null;
  fs.writeFileSync(sortie, JSON.stringify({ points, recharges, ecartsMemo, matchs: k, fini: true }));
  jeu.fermer();
  fs.rmSync(dataDir, { recursive: true, force: true });
}

if (process.argv[2] === '--partie') {
  partie(Number(process.argv[3]), process.argv[4], process.argv[5]);
  process.exit(0);
}

// ---------------------------------------------------------------- comparaison
const { test } = require('node:test');
function suite(graine) {
const dossier = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-recharge-res-'));
// Parties en même temps : 2 au plus (d'une traite et rechargée d'une même graine), une seule sur une machine à un cœur
// (CD_RECHARGE_PARALLELE pour forcer).
const PARALLELE = Math.max(1, Math.min(2, Number(process.env.CD_RECHARGE_PARALLELE) || os.availableParallelism()));
let enCours = 0;
const attente = [];
const place = () => new Promise(resolve => { if (enCours < PARALLELE) { enCours++; resolve(); } else attente.push(resolve); });
const rendre = () => { const suivant = attente.shift(); if (suivant) suivant(); else enCours--; };
const lancer = (graine, mode) => place().then(() => new Promise(resolve => {
  const sortie = path.join(dossier, graine + '-' + mode + '.json');
  const enfant = spawn(process.execPath, ['--max-old-space-size=2048', __filename, '--partie', String(graine), mode, sortie], { stdio: ['ignore', 'ignore', 'pipe'] });
  let erreur = '';
  enfant.stderr.on('data', d => { erreur = (erreur + d).slice(-4000); });
  enfant.on('close', (code, signal) => { rendre(); let r = null; try { r = JSON.parse(fs.readFileSync(sortie, 'utf8')); } catch { /* rien écrit */ } resolve({ code, signal, erreur, r }); });
}));
const parties = Promise.all([lancer(graine, 'traite'), lancer(graine, 'recharge')]);

test('Graine ' + graine + ' : partie rechargée (milieu de semaine, intersaison, saison 2) == partie d’une traite', async () => {
    const [traite, recharge] = await parties;
    for (const x of [traite, recharge]) assert.ok(x.code === 0 && x.r?.fini, 'partie interrompue (code ' + x.code + ', signal ' + x.signal + ') : ' + x.erreur);
    assert.ok(recharge.r.recharges.length >= 5, 'au moins cinq rechargements : ' + recharge.r.recharges.map(x => x.nom));
    assert.ok(recharge.r.recharges.some(x => x.nom === 'intersaison'), 'rechargement à l’intersaison');
    for (const x of recharge.r.recharges) assert.ok(x.identique, x.nom + ' : la sauvegarde rechargée diffère de l’état sauvé (' + x.ecarts + ')');
    const fin = traite.r.points.at(-1);
    assert.equal(fin.saison, 2, 'partie jouée jusqu’en saison 2');
    assert.equal(traite.r.points.length, recharge.r.points.length, 'mêmes points de comparaison');
    for (const [n, a] of traite.r.points.entries()) {
      const b = recharge.r.points[n];
      assert.equal(b.nom, a.nom);
      const ecarts = Object.keys(a.parCle).filter(k => a.parCle[k] !== b.parCle[k]);
      assert.deepEqual({ point: b.nom, graine: b.graine, ecarts }, { point: a.nom, graine: a.graine, ecarts: [] }, 'saison ' + a.saison + ' semaine ' + a.semaine);
      assert.equal(b.tout, a.tout);
    }
    // Mémoires vérifiées pendant la partie d'une traite : aucune valeur périmée.
    const memo = traite.r.ecartsMemo;
    assert.ok(memo, 'vérification des mémoires du budget indisponible');
    const retrouvees = new Map(memo.retrouvees);
    for (const nom of ['limites', 'receptions', 'eventail', 'forcesDemande']) assert.ok(retrouvees.get(nom) > 20, 'mémoire ' + nom + ' mise à l’épreuve : ' + JSON.stringify(memo.retrouvees));
    assert.deepEqual(memo.ecarts, []);
});

process.on('exit', () => { try { fs.rmSync(dossier, { recursive: true, force: true }); } catch { /* déjà parti */ } });
}

module.exports = { suite };
