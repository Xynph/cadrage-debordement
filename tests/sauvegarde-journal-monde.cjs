'use strict';
// Journal d'actions et fréquence de la sauvegarde complète (carrière Monde `world-champ`) :
// docs/sauvegarde-journal-20261116.md, native/engine/action-journal.cjs.
//   1. le module du journal : ligne coupée, marque de publication, journal étranger ou abîmé, fréquences ;
//   2. une décision ne réécrit pas le profil (~23 Mo) : une ligne de journal synchronisée, rien après la réponse ;
//      la fermeture fait la sauvegarde complète et vide le journal ;
//   3. plantage simulé, ligne coupée, journal divergent : tests/sauvegarde-journal-plantage-monde.cjs (suite séparée
//      le 16/11/2026 pour rester sous le délai de 180 s du lanceur CI) ;
//   4. un ajout impossible refuse la décision avec sa raison ;
//   5. fréquences « Chaque jour », « Chaque semaine » (défaut, lue dans interface.json comme le fait Godot),
//      « Chaque mois ».
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

const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const dossier = dir => path.join(dir, 'PrototypeGodot');
const profil = dir => path.join(dossier(dir), 'donnees.json');
const journal = dir => path.join(dossier(dir), J.FILE);
const lignes = dir => fs.readFileSync(journal(dir), 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));

let racine, preparation, copies = 0;
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
  // Carrière en avant-saison (lundi 13 juillet 2026) : fréquences et décisions.
  preparation = path.join(racine, 'preparation');
  const jeu = ouvrir(preparation);
  try { M.creer(jeu); } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

test('Module du journal : ligne coupée, publication, journal étranger ou abîmé, fréquences', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-journal-module-'));
  try {
    const j = J.createJournal(dir);
    assert.equal(j.read('a').status, 'absent');
    j.reset('a');
    assert.equal(j.read('a').status, 'vide');
    const action = n => ({ c: 'set_tactics', p: { n }, k: 1, s: n, e: n + 1 });
    j.append(action(1)); j.append(action(2));
    assert.deepEqual(j.read('a').actions.map(a => a.p.n), [1, 2]);
    // Coupure pendant l'ajout : la ligne incomplète n'a jamais été confirmée.
    fs.appendFileSync(j.file, '{"c":"set_tac');
    const coupe = j.read('a');
    assert.equal(coupe.status, 'rejouer'); assert.equal(coupe.torn, true); assert.equal(coupe.actions.length, 2);
    j.reset('a', coupe.actions);
    // Marque de publication : profil « b » publié, journal pas encore remis à zéro ; seules les actions suivantes restent.
    j.markPublication('b'); j.append(action(3));
    assert.deepEqual(j.read('b').actions.map(a => a.p.n), [3]);
    assert.deepEqual(j.read('a').actions.map(a => a.p.n), [1, 2, 3], 'publication jamais aboutie : tout est repris');
    assert.equal(j.read('c').status, 'etranger');
    fs.writeFileSync(j.file, '{"journal":1,"base":"a"}\nabîmé\n{"c":"x","p":{},"k":1,"s":1,"e":1}\n');
    assert.deepEqual([j.read('a').status, j.read('a').line], ['illisible', 2]);
    const conserve = j.preserve('illisible');
    assert.ok(fs.existsSync(path.join(dir, conserve)) && !j.exists(), 'le journal est conservé sous un autre nom, jamais effacé');
    // Fréquences : la date de la carrière fait foi (lundi = début de semaine).
    const d = date => ({ date, season: 1, round: 0 });
    assert.equal(J.due('jour', d('2026-07-13'), d('2026-07-13')), false);
    assert.equal(J.due('jour', d('2026-07-13'), d('2026-07-14')), true);
    assert.equal(J.due('semaine', d('2026-07-13'), d('2026-07-19')), false);
    assert.equal(J.due('semaine', d('2026-07-19'), d('2026-07-20')), true);
    assert.equal(J.due('mois', d('2026-07-13'), d('2026-07-31')), false);
    assert.equal(J.due('mois', d('2026-07-31'), d('2026-08-01')), true);
    assert.equal(J.readPolicy(dir), 'semaine', 'défaut sans préférence');
    fs.writeFileSync(path.join(dir, 'interface.json'), JSON.stringify({ version: 1, autosave: 'mois' }));
    assert.equal(J.readPolicy(dir), 'mois');
    assert.equal(J.readPolicy(dir, 'jour'), 'jour');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Décision : profil intact, une ligne de journal, rien à écrire après la réponse ; fermeture = sauvegarde complète', { timeout: 900000 }, () => {
  const dir = copie(preparation);
  const avant = fs.readFileSync(profil(dir));
  const jeu = ouvrir(dir, { testVm: true });
  try {
    jeu.bridge.vm.run('{const o=save;globalThis.__saves=0;save=function(){__saves++;return o.apply(this,arguments);};}');
    let model = jeu.call('snapshot');
    for (let i = 1; i <= 3; i++) {
      jeu.bridge.vm.run('__saves=0');
      model = jeu.call('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense });
      assert.equal(jeu.bridge.vm.run('__saves'), 0, 'la décision ne sérialise pas la carrière');
      assert.equal(jeu.bridge.handle.pending(), null, 'aucune écriture en attente après la réponse');
      assert.ok(fs.readFileSync(profil(dir)).equals(avant), 'le profil complet n’est pas réécrit');
      assert.equal(lignes(dir).length, 1 + i, 'une ligne par décision');
      assert.deepEqual([model.meta.autosave.policy, model.meta.autosave.pending, model.meta.autosave.saved], ['semaine', i, false]);
    }
    assert.ok(fs.statSync(journal(dir)).size < 2000, 'quelques centaines d’octets par décision');
    jeu.call('snapshot');
    assert.equal(lignes(dir).length, 4, 'une lecture n’ajoute rien');
  } finally { jeu.bridge.close(); }
  assert.ok(!fs.readFileSync(profil(dir)).equals(avant), 'la fermeture écrit la carrière');
  assert.equal(lignes(dir).length, 1, 'journal remis à zéro après la sauvegarde complète');
  assert.equal(lignes(dir)[0].base, sha(fs.readFileSync(profil(dir))), 'le journal est lié au profil publié');
});

test('Journal impossible à compléter : la décision est refusée avec sa raison et annulée', { timeout: 900000 }, () => {
  const dir = copie(preparation);
  const jeu = ouvrir(dir);
  try {
    let model = jeu.call('snapshot');
    const attaque = model.tactics.attack;
    fs.rmSync(journal(dir)); fs.mkdirSync(journal(dir));
    const r = jeu.brut('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense });
    assert.equal(r.ok, false);
    assert.match(r.error, /Décision non notée dans le journal de sauvegarde/);
    assert.equal(r.model.tactics.attack, attaque, 'décision annulée en mémoire');
    fs.rmdirSync(journal(dir));
  } finally { jeu.bridge.close(); }
});

test('Fréquences : chaque jour, chaque semaine (défaut, Réglages), chaque mois', { timeout: 1500000 }, () => {
  // Continuer de la date courante jusqu'à `jours` jours ; renvoie [profil réécrit ?, lignes de journal].
  const avancer = (jeu, dir, jours) => {
    const avant = fs.readFileSync(profil(dir));
    let model = jeu.regler(jeu.call('snapshot'));
    model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, maxDays: jours });
    // Sauvegarde complète due : écrite juste après la réponse (jour différé, lot 36), comme la boucle stdio du jeu.
    jeu.bridge.handle.flush();
    return { ecrit: !fs.readFileSync(profil(dir)).equals(avant), lignes: lignes(dir).length - 1, date: model.meta.calendarToday, autosave: model.meta.autosave };
  };
  for (const [politique, attendu] of [['jour', [true, true]], ['semaine', [false, true]], ['mois', [false, false]]]) {
    const dir = copie(preparation);
    // Réglage tel que Godot l'enregistre (ui/user_preferences.gd) : le moteur le lit dans le même dossier.
    if (politique !== 'semaine') fs.writeFileSync(path.join(dossier(dir), 'interface.json'), JSON.stringify({ version: 1, volume: 75, reduced_motion: false, quality: 'balanced', camera: 'tv', autosave: politique }));
    const jeu = ouvrir(dir);
    try {
      const debut = jeu.call('snapshot').meta.calendarToday;
      assert.equal(debut, '2026-07-13', 'avant-saison du lundi 13 juillet');
      const jour = avancer(jeu, dir, 1);                     // mardi 14 : même semaine, même mois
      assert.equal(jour.autosave.policy, politique);
      assert.equal(jour.ecrit, attendu[0], politique + ' : un jour');
      assert.equal(jour.lignes, attendu[0] ? 0 : 1, politique + ' : jour noté au journal tant qu’il n’est pas sauvegardé');
      let semaine = avancer(jeu, dir, 7);                    // passage au lundi 20 juillet
      for (let i = 0; i < 6 && semaine.date < '2026-07-20'; i++) semaine = avancer(jeu, dir, 7);
      assert.ok(semaine.date >= '2026-07-20' && semaine.date < '2026-08-01', semaine.date);
      assert.equal(semaine.ecrit, attendu[1], politique + ' : changement de semaine');
      if (attendu[1]) assert.equal(semaine.autosave.lastSave, semaine.date);
    } finally { jeu.bridge.close(); }
    assert.equal(lignes(dir).length, 1, politique + ' : la fermeture sauvegarde tout');
  }
});
