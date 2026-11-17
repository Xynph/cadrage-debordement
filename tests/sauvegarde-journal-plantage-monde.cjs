'use strict';
// Journal d'actions (carrière Monde `world-champ`) : docs/sauvegarde-journal-20261116.md,
// native/engine/action-journal.cjs. Séparé de tests/sauvegarde-journal-monde.cjs (mêmes assertions) pour rester
// sous le délai de 180 s du lanceur CI.
//   1. plantage simulé entre deux sauvegardes complètes (décisions et jours après un match validé ; le match lui-même
//      n'est jamais noté, voir tests/reprise-avant-match.cjs) : au chargement, le journal rejoué donne exactement la
//      même empreinte que la sauvegarde complète ;
//   2. une dernière ligne coupée est ignorée ; un journal divergent est repris jusqu'à la dernière action confirmée,
//      conservé sous un autre nom et signalé.
// Une seule carrière Monde ouverte à la fois (machine de 8 Go) : chaque pont est fermé avant le suivant, et le tas
// est plafonné comme dans le jeu (engine_bridge.gd) pour que les ponts fermés soient libérés au lieu de s'empiler.
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
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const dossier = dir => path.join(dir, 'PrototypeGodot');
const profil = dir => path.join(dossier(dir), 'donnees.json');
const journal = dir => path.join(dossier(dir), J.FILE);
const lignes = dir => fs.readFileSync(journal(dir), 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));
const empreinte = dir => { const p = JSON.parse(fs.readFileSync(profil(dir), 'utf8')); return { carriere: sha(p.store['bdt-v1']), seed: p.seed, clock: p.clock }; };

let racine, veille, copies = 0;
// Copie du disque d'un profil, comme après une coupure brutale (le verrou du processus disparu est retiré).
function copie(source) {
  const dir = path.join(racine, 'copie-' + (++copies));
  fs.cpSync(source, dir, { recursive: true });
  fs.rmSync(path.join(dossier(dir), 'profil.lock'), { force: true });
  return dir;
}
function ouvrir(dataDir, options = {}) { return M.ouvrir({ dataDir, journal: true, ...options }); }
function autreAttaque(model) { return model.tactics.attacks.find(o => o.id !== model.tactics.attack).id; }

before(() => {
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-journal-'));
  // Carrière ouverte la veille de la première rencontre : match et direct sans deux mois de calendrier.
  veille = path.join(racine, 'veille');
  const jeu = ouvrir(veille);
  try { jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' })); } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

test('Plantage simulé entre deux sauvegardes : le journal rejoué donne la même empreinte que la sauvegarde complète', { timeout: 1500000 }, () => {
  const A = copie(veille);
  let crash, jeu = ouvrir(A, { savePolicy: 'mois' });
  try {
    let model = jeu.call('snapshot');
    model = jeu.call('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense });
    model = M.jusquAuMatch(jeu, model);
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    assert.ok(model.live, 'rencontre en direct');
    for (let i = 0; i < 3; i++) jeu.call('tick', { steps: 2 });
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    assert.ok(model.live?.finished || !model.live, 'match délégué jusqu’au bout');
    // Reprise avant le match (16/11/2026) : le match n'est jamais noté au journal ; sa validation enregistre la
    // carrière en entier, puis les décisions et les jours suivants sont de nouveau notés.
    assert.ok(!lignes(A).slice(1).some(a => ['begin_match', 'tick', 'delegate'].includes(a.c)), 'match en cours jamais noté au journal');
    model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    assert.equal(lignes(A).length, 1, 'résultat validé : sauvegarde complète, journal vide');
    model = M.jusquALaSemaineSuivante(jeu, model);
    model = jeu.call('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense });
    const actions = lignes(A).slice(1);
    assert.ok(actions.length >= 3, 'décision et jours jusqu’à la clôture de la semaine notés : ' + actions.map(a => a.c).join(','));
    assert.ok(actions.some(a => a.s !== a.e), 'la clôture de la semaine consomme la graine : la vérification par graine est exercée');
    crash = copie(A);                               // disque au moment de la coupure
    jeu.call('save');                               // sauvegarde complète de référence
  } finally { jeu.bridge.close(); }
  const reference = empreinte(A);
  const C = copie(crash), D = copie(crash);
  jeu = ouvrir(crash, { savePolicy: 'mois' });
  try {
    const model = jeu.call('snapshot');
    const notice = model.meta.autosave.notice;
    assert.equal(notice.alert, false, notice.text);
    assert.equal(notice.replayed, notice.total);
    assert.ok(!model.live, 'carrière reprise après la clôture de la semaine du match');
    jeu.call('save');
  } finally { jeu.bridge.close(); }
  assert.deepEqual(empreinte(crash), reference, 'journal rejoué = sauvegarde complète, à l’octet près');

  // Coupure pendant l'ajout d'une ligne : ignorée, le reste est repris.
  fs.appendFileSync(journal(C), '{"c":"set_tactics","p":{"att');
  jeu = ouvrir(C, { savePolicy: 'mois' });
  try { assert.equal(jeu.call('snapshot').meta.autosave.notice.alert, false); jeu.call('save'); } finally { jeu.bridge.close(); }
  assert.deepEqual(empreinte(C), reference, 'ligne coupée ignorée');

  // Journal divergent (graine notée fausse sur l'avant-dernière action) : reprise jusqu'à l'action précédente,
  // journal d'origine conservé, joueur informé.
  const texte = fs.readFileSync(journal(D), 'utf8').split('\n').filter(Boolean);
  const fausse = texte.length - 2, ligne = JSON.parse(texte[fausse]);
  ligne.e = (ligne.e + 1) >>> 0; texte[fausse] = JSON.stringify(ligne);
  fs.writeFileSync(journal(D), texte.join('\n') + '\n');
  jeu = ouvrir(D, { savePolicy: 'mois' });
  try {
    const notice = jeu.call('snapshot').meta.autosave.notice;
    assert.equal(notice.alert, true);
    assert.equal(notice.replayed, fausse - 1);
    assert.match(notice.text, /journal conservé : journal-non-rejoue-/);
    assert.equal(lignes(D).length, fausse, 'le journal décrit la carrière reprise');
    assert.ok(fs.readdirSync(dossier(D)).some(f => f.startsWith('journal-non-rejoue-')), 'journal d’origine conservé');
  } finally { jeu.bridge.close(); }
});
