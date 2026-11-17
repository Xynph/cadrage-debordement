'use strict';
// Reprise avant le match (décision de Léo, 16/11/2026) : une carrière n'est jamais reprise en plein match. Si le jeu
// est fermé (ou coupé) pendant une rencontre, la carrière repart de l'état d'avant le coup d'envoi, le match restant à
// jouer. Carrière Monde `world-champ`, mêmes options que le jeu (calendrier journalier, journal d'actions).
//   1. coupure en plein match (copie du disque) et fermeture normale en plein match : au rechargement, jour du match,
//      aucun direct, état identique à l'export d'avant le coup d'envoi ; le match se rejoue et se valide ;
//   2. export pendant le match : carrière d'avant le coup d'envoi ;
//   3. anciennes sauvegardes (format d'avant, produites avec matchResume:false) : journal contenant le coup d'envoi ->
//      reprise avant le match ; profil enregistré en plein match -> lu sans erreur, match repris en pause à la minute
//      enregistrée avec un avis explicite, puis validé normalement.
// Une seule carrière ouverte à la fois, tas plafonné comme dans le jeu.
if (!process.execArgv.some(a => a.startsWith('--max-old-space-size'))) {
  const r = require('node:child_process').spawnSync(process.execPath, ['--max-old-space-size=2048', ...process.execArgv, __filename, ...process.argv.slice(2)], { stdio: 'inherit' });
  process.exit(r.status ?? 1);
}
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const J = require('../native/engine/action-journal.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const dossier = dir => path.join(dir, 'PrototypeGodot');
const carriere = dir => JSON.parse(fs.readFileSync(path.join(dossier(dir), 'donnees.json'), 'utf8')).store['bdt-v1'];
const enDirect = dir => /"live":\{/.test(carriere(dir));
const lignes = dir => fs.readFileSync(path.join(dossier(dir), J.FILE), 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));

let racine, jourDeMatch, avantMatch, copies = 0;
function copie(source) {
  const dir = path.join(racine, 'copie-' + (++copies));
  fs.cpSync(source, dir, { recursive: true });
  fs.rmSync(path.join(dossier(dir), 'profil.lock'), { force: true });
  return dir;
}
function ouvrir(dataDir, options = {}) { return M.ouvrir({ dataDir, journal: true, deferredCommits: true, ...options }); }
// Empreinte SHA-256 du texte de l'état exporté (preuve du moteur, avant toute réduction) : pas de copie de ~22 Mo.
function exporter(jeu) { const p = jeu.call('export', { proof: true }).meta.exportRoundTripSha256; assert.match(p, /^[a-f0-9]{64}$/); return p; }
// Coup d'envoi et quelques minutes du direct (causerie d'avant-match passée).
function lancerLeMatch(jeu, model) {
  if (!model.selection.valid) model = jeu.call('auto_lineup');
  model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
  assert.ok(model.live && !model.live.finished, 'rencontre en direct');
  for (let i = 0; i < 3; i++) model = jeu.call('tick', { steps: 4 });
  assert.ok(model.live && !model.live.finished, 'rencontre toujours en cours');
  return model;
}
// Rechargement : jour du match, aucun direct, état identique à celui d'avant le coup d'envoi, puis match rejoué.
function verifierAvantMatch(dir, libelle) {
  const jeu = ouvrir(dir);
  try {
    let model = jeu.call('snapshot');
    assert.equal(model.meta.profileError, '', libelle + ' : profil lisible');
    assert.ok(!model.live, libelle + ' : aucun match en cours au chargement');
    assert.equal(model.meta.calendarToday, avantMatch.jour, libelle + ' : jour du match');
    assert.equal(model.meta.calendarCadence.matchReady, true, libelle + ' : coup d’envoi disponible');
    assert.equal(exporter(jeu), avantMatch.etat, libelle + ' : état identique à l’export d’avant le coup d’envoi');
    model = jeu.call('snapshot');
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    assert.ok(model.live?.finished, libelle + ' : match rejoué jusqu’au bout');
    model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    assert.equal(model.meta.calendarCadence.resultConfirmed, true, libelle + ' : résultat validé');
  } finally { jeu.bridge.close(); }
  assert.equal(enDirect(dir), true, libelle + ' : après validation, la carrière réelle (résultat compris) est enregistrée');
  const relu = ouvrir(dir);
  try { assert.equal(relu.call('snapshot').meta.calendarCadence.resultConfirmed, true, libelle + ' : résultat validé relu'); } finally { relu.bridge.close(); }
}

before(() => {
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-reprise-match-'));
  jourDeMatch = path.join(racine, 'jour-de-match');
  const jeu = ouvrir(jourDeMatch);
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    model = M.jusquAuMatch(jeu, model);
    assert.ok(!model.live, 'pas de match en cours avant le coup d’envoi');
    avantMatch = { jour: model.meta.calendarToday, etat: exporter(jeu) };
  } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

test('Coupure ou fermeture en plein match : la carrière reprend avant le coup d’envoi et le match se rejoue', { timeout: 1500000 }, () => {
  const A = copie(jourDeMatch);
  let coupure;
  const jeu = ouvrir(A);
  try {
    lancerLeMatch(jeu, jeu.call('snapshot'));
    coupure = copie(A);                        // disque au moment d'une coupure brutale
    assert.equal(enDirect(coupure), false, 'aucun direct écrit dans le profil');
    assert.ok(!lignes(coupure).some(l => l.c === 'begin_match' || l.c === 'tick'), 'le match n’est pas noté au journal');
    jeu.call('save');                          // « Sauvegarder » pendant le match : état d'avant le coup d'envoi
    assert.equal(enDirect(A), false, '« Sauvegarder » : aucun direct écrit');
  } finally { jeu.bridge.close(); }           // fermeture normale en plein match
  assert.equal(enDirect(A), false, 'fermeture : aucun direct écrit');
  verifierAvantMatch(coupure, 'coupure');
  verifierAvantMatch(A, 'fermeture');
});

test('Sans journal (écriture différée à chaque décision) : coupure en plein match, reprise avant le coup d’envoi', { timeout: 1500000 }, () => {
  const E = copie(jourDeMatch);
  let coupure;
  const jeu = ouvrir(E, { journal: false });
  try {
    lancerLeMatch(jeu, jeu.call('snapshot'));
    jeu.bridge.handle.flush();                 // décisions du direct écrites comme après chaque réponse du jeu
    coupure = copie(E);
    assert.equal(enDirect(coupure), false, 'aucun direct écrit dans le profil');
  } finally { jeu.bridge.close(); }
  assert.equal(enDirect(E), false, 'fermeture : aucun direct écrit');
  verifierAvantMatch(coupure, 'sans journal');
});

test('Export pendant le match : le fichier décrit la carrière d’avant le coup d’envoi', { timeout: 1500000 }, () => {
  const B = copie(jourDeMatch);
  const jeu = ouvrir(B);
  try {
    lancerLeMatch(jeu, jeu.call('snapshot'));
    assert.equal(exporter(jeu), avantMatch.etat);
    const model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    assert.ok(model.live?.finished, 'le match continue normalement après l’export');
  } finally { jeu.bridge.close(); }
});

test('Ancien format : journal contenant le coup d’envoi -> reprise avant le match', { timeout: 1500000 }, () => {
  const C = copie(jourDeMatch);
  let coupure;
  const ancien = ouvrir(C, { matchResume: false });
  try {
    lancerLeMatch(ancien, ancien.call('snapshot'));
    coupure = copie(C);
    assert.ok(lignes(coupure).some(l => l.c === 'begin_match'), 'ancien format : coup d’envoi noté au journal');
  } finally { ancien.bridge.close(); }
  const jeu = ouvrir(coupure);
  try {
    const model = jeu.call('snapshot');
    assert.ok(!model.live, 'aucun match en cours');
    assert.match(model.meta.matchResumeNotice?.text || '', /avant le coup d’envoi/);
    assert.equal(model.meta.autosave.notice.alert, false, 'reprise du journal sans alerte');
  } finally { jeu.bridge.close(); }
  assert.ok(fs.readdirSync(dossier(coupure)).some(f => f.startsWith('journal-avant-match-')), 'lignes du match interrompu conservées à part');
  verifierAvantMatch(coupure, 'ancien journal');
});

test('Ancien format : profil enregistré en plein match -> lu sans erreur, repris en pause avec un avis', { timeout: 1500000 }, () => {
  const D = copie(jourDeMatch);
  const ancien = ouvrir(D, { matchResume: false });
  let direct;
  try { direct = lancerLeMatch(ancien, ancien.call('snapshot')).live; } finally { ancien.bridge.close(); }
  assert.equal(enDirect(D), true, 'ancien format : direct écrit à la fermeture');
  const jeu = ouvrir(D);
  try {
    let model = jeu.call('snapshot');
    assert.equal(model.meta.profileError, '');
    assert.ok(model.live && !model.live.finished, 'match repris');
    assert.equal(model.live.paused, true, 'en pause');
    assert.deepEqual(model.live.score, direct.score, 'au score enregistré');
    assert.match(model.meta.matchResumeNotice?.text || '', /version précédente/);
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    assert.ok(model.live?.finished);
    model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    assert.equal(model.meta.calendarCadence.resultConfirmed, true);
    assert.equal(model.meta.matchResumeNotice, null, 'avis retiré une fois le match validé');
  } finally { jeu.bridge.close(); }
});
