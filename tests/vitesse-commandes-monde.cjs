'use strict';
// Fluidité des commandes en carrière Monde (`world-champ`) : écriture différée des décisions courantes.
//
// Le jeu (worker stdio) répond d'abord à une décision qui n'avance pas le calendrier (consignes, composition,
// réunions…) puis la sérialise, la valide et l'écrit dès que le moteur est libre, au plus tard avant la commande
// suivante ou la fermeture. Les avances de calendrier restent écrites avant leur réponse. Ce fichier vérifie :
//   1. la réponse d'une décision courante ne sérialise ni n'écrit le profil (~25 Mio), l'écriture suit ;
//   2. les modèles renvoyés et le profil final sont identiques avec et sans écriture différée ;
//   3. une coupure brutale avant l'écriture ne perd que cette décision, le profil reste intact ;
//   4. un échec de l'écriture différée annule la décision et la commande suivante le dit (aucun échec silencieux) ;
//   5. des seuils de temps larges (machines de CI partagées) contre les régressions de fluidité ;
//   6. une avance du calendrier envoyée juste après une décision la reprend à son compte (validée et écrite avec
//      elle) au lieu d'attendre son écriture séparée ; refusée, elle laisse la décision en attente ;
//   7. le vrai worker stdio : jour envoyé aussitôt après une décision (regroupé), puis « shutdown » envoyé aussitôt
//      après une autre décision : réponse, décision écrite, sortie propre (recette Windows, run 43603330612).
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const readline = require('node:readline');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

// Seuils larges : la machine de mesure (2 cœurs partagés, chargée) donne ~2,5 s pour une décision et ~4 s pour un jour.
const SEUIL_DECISION_MS = Number(process.env.CD_SEUIL_DECISION_MS || 15000);
// Un seul pont Monde à la fois (machine de 8 Go) : les ponts successifs sont fermés avant le suivant.
const SEUIL_JOUR_MS = Number(process.env.CD_SEUIL_JOUR_MS || 40000);

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const fichier = dir => path.join(dir, 'PrototypeGodot', 'donnees.json');
const enregistre = dir => JSON.parse(fs.readFileSync(fichier(dir), 'utf8')).store['bdt-v1'];
const tactique = dir => /"tactic":"([^"]+)"/.exec(enregistre(dir))?.[1];
const mediane = xs => [...xs].sort((a, b) => a - b)[Math.floor((xs.length - 1) / 2)];

let racine, origine;
before(() => {
  // Une seule carrière Monde créée (étape coûteuse), copiée pour chaque essai.
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-vitesse-'));
  origine = path.join(racine, 'origine');
  const jeu = M.ouvrir({ dataDir: origine });
  try { M.creer(jeu); jeu.call('save'); } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

let copies = 0;
function copie() {
  const dir = path.join(racine, 'copie-' + (++copies));
  fs.cpSync(origine, dir, { recursive: true });
  fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
  return dir;
}
function autreAttaque(model) { return model.tactics.attacks.find(o => o.id !== model.tactics.attack).id; }

test('Décision courante : réponse sans sérialisation ni écriture, profil écrit ensuite ; un jour est écrit avant sa réponse', { timeout: 1500000 }, () => {
  const dir = copie();
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true });
  try {
    const vm = jeu.bridge.vm;
    vm.run('{const o=save;globalThis.__saves=0;save=function(){__saves++;return o.apply(this,arguments);};}');
    let model = jeu.call('snapshot');
    const durees = [];
    for (let i = 0; i < 3; i++) {
      const avant = fs.readFileSync(fichier(dir)), attaque = autreAttaque(model);
      vm.run('__saves=0');
      const t = performance.now();
      model = jeu.call('set_tactics', { attack: attaque, defense: model.tactics.defense });
      durees.push(performance.now() - t);
      assert.equal(model.tactics.attack, attaque, 'la réponse montre la décision');
      assert.equal(vm.run('__saves'), 0, 'la réponse ne sérialise pas la carrière');
      assert.equal(jeu.bridge.handle.pending(), 'set_tactics', 'écriture en attente');
      assert.ok(fs.readFileSync(fichier(dir)).equals(avant), 'le profil n\'est pas réécrit avant la réponse');
      jeu.bridge.handle.flush();
      assert.equal(jeu.bridge.handle.pending(), null);
      assert.equal(tactique(dir), attaque, 'la décision est écrite après la réponse');
    }
    // Lecture seule : rien à écrire.
    jeu.call('snapshot');
    assert.equal(jeu.bridge.handle.pending(), null);
    // Avance du calendrier : écrite avant la réponse (sauvegarde garantie au changement de jour).
    model = jeu.regler(model);
    const jour = model.meta.calendarToday;
    const t = performance.now();
    model = jeu.call('advance_day', { fromDate: jour });
    const dureeJour = performance.now() - t;
    assert.equal(jeu.bridge.handle.pending(), null, 'un jour n\'est jamais différé');
    assert.notEqual(model.meta.calendarToday, jour);
    // Le profil écrit est exactement la carrière en mémoire (empreinte de l'export).
    assert.equal(jeu.call('export', { proof: true }).meta.exportRoundTripSha256, sha(enregistre(dir)));
    console.log('décision (médiane de 3) :', Math.round(mediane(durees)), 'ms · jour :', Math.round(dureeJour), 'ms');
    assert.ok(mediane(durees) < SEUIL_DECISION_MS, 'décision courante trop lente : ' + Math.round(mediane(durees)) + ' ms');
    assert.ok(dureeJour < SEUIL_JOUR_MS, 'passage d\'un jour trop lent : ' + Math.round(dureeJour) + ' ms');
  } finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Écriture différée : mêmes modèles et même profil final qu\'avec l\'écriture immédiate', { timeout: 1500000 }, () => {
  const parcours = differe => {
    const dir = copie();
    const jeu = M.ouvrir({ dataDir: dir, deferredCommits: differe });
    const empreintes = [];
    try {
      const garder = model => { const m = { ...model, meta: { ...model.meta } }; delete m.meta.profileSafety; empreintes.push(sha(JSON.stringify(m).split(dir).join('<profil>'))); return model; };
      let model = garder(jeu.call('snapshot'));
      model = garder(jeu.call('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense }));
      model = garder(jeu.call('auto_lineup'));
      model = jeu.regler(model);
      model = garder(jeu.call('advance_day', { fromDate: model.meta.calendarToday }));
      model = garder(jeu.call('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense }));
      model = garder(jeu.call('snapshot'));
    } finally { jeu.bridge.close(); }
    const final = sha(enregistre(dir));
    fs.rmSync(dir, { recursive: true, force: true });
    return { empreintes, final };
  };
  const immediat = parcours(false), differe = parcours(true);
  assert.deepEqual(differe.empreintes, immediat.empreintes, 'modèles renvoyés à l\'interface');
  assert.equal(differe.final, immediat.final, 'profil écrit à la fermeture');
});

test('Coupure brutale avant l\'écriture différée : profil intact, seule la dernière décision courante est perdue', { timeout: 1500000 }, () => {
  const dir = copie(), tactiqueAvant = tactique(dir), empreinteAvant = sha(enregistre(dir));
  // Processus enfant : une décision courante, puis arrêt brutal (SIGKILL) avant toute écriture.
  const script = `
    const M=require(${JSON.stringify(path.join(__dirname, 'helpers/carriere-monde.cjs'))});
    const jeu=M.ouvrir({dataDir:${JSON.stringify(dir)},deferredCommits:true});
    const m=jeu.call('snapshot');
    jeu.call('set_tactics',{attack:m.tactics.attacks.find(o=>o.id!==m.tactics.attack).id,defense:m.tactics.defense});
    if(jeu.bridge.handle.pending()!=='set_tactics')process.exit(3);
    process.kill(process.pid,'SIGKILL');`;
  const r = spawnSync(process.execPath, ['--max-old-space-size=1300', '-e', script], { encoding: 'utf8', timeout: 900000 });
  assert.equal(r.signal, 'SIGKILL', 'arrêt brutal attendu : ' + r.status + ' ' + (r.stderr || '').slice(-400));
  assert.equal(tactique(dir), tactiqueAvant, 'la décision non écrite est absente');
  assert.equal(sha(enregistre(dir)), empreinteAvant, 'profil inchangé');
  // Le profil se recharge (verrou d'un processus mort repris) et correspond exactement à l'état chargé.
  const jeu = M.ouvrir({ dataDir: dir });
  try { assert.equal(jeu.call('export', { proof: true }).meta.exportRoundTripSha256, empreinteAvant); }
  finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Échec de l\'écriture différée : décision annulée et signalée à la commande suivante', { timeout: 1500000 }, () => {
  const dir = copie(), tactiqueAvant = tactique(dir);
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true });
  const profil = fichier(dir), cache = profil + '.essai';
  try {
    let model = jeu.call('snapshot');
    model = jeu.call('set_tactics', { attack: autreAttaque(model), defense: model.tactics.defense });
    assert.notEqual(model.tactics.attack, tactiqueAvant);
    // Le profil devient illisible pour l'écriture (un dossier à sa place) : l'écriture différée échoue.
    fs.renameSync(profil, cache); fs.mkdirSync(profil);
    jeu.bridge.handle.flush();
    fs.rmdirSync(profil); fs.renameSync(cache, profil);
    const refus = jeu.brut('snapshot');
    assert.equal(refus.ok, false, 'la commande suivante signale l\'échec');
    assert.match(refus.error, /n’a pas pu être enregistrée ; elle est annulée et cette nouvelle action n’a pas été appliquée/);
    assert.equal(refus.model.tactics.attack, tactiqueAvant, 'la décision est annulée en mémoire');
    assert.equal(refus.model.meta.saveError, true, 'échec de sauvegarde visible');
    // Le jeu repart normalement : nouvelle décision, écrite.
    model = jeu.call('set_tactics', { attack: autreAttaque(refus.model), defense: refus.model.tactics.defense });
    jeu.bridge.handle.flush();
    assert.equal(tactique(dir), model.tactics.attack);
  } finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Avance du calendrier juste après une décision : décision regroupée, validée et écrite avec elle', { timeout: 1500000 }, () => {
  const dir = copie();
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, timing: true });
  try {
    const vm = jeu.bridge.vm;
    vm.run('{const o=nativeValidateSaved;globalThis.__validations=0;nativeValidateSaved=function(){__validations++;return o.apply(this,arguments);};}');
    let model = jeu.regler(jeu.call('snapshot'));
    // Refusée (date périmée) : la décision reste en mémoire et en attente, puis s'écrit normalement.
    const premiere = autreAttaque(model);
    model = jeu.call('set_tactics', { attack: premiere, defense: model.tactics.defense });
    assert.equal(jeu.bridge.handle.pending(), 'set_tactics');
    const refus = jeu.brut('advance_day', { fromDate: '1999-01-01' });
    assert.equal(refus.ok, false, 'date périmée refusée');
    assert.equal(refus.model.tactics.attack, premiere, 'la décision reste en mémoire');
    assert.equal(jeu.bridge.handle.pending(), 'set_tactics', 'et en attente d\'écriture');
    jeu.bridge.handle.flush();
    assert.equal(tactique(dir), premiere, 'puis écrite');
    // Acceptée : le jour reprend la décision (une seule validation, aucune écriture séparée avant le jour).
    const seconde = autreAttaque(model);
    model = jeu.call('set_tactics', { attack: seconde, defense: model.tactics.defense });
    assert.equal(jeu.bridge.handle.pending(), 'set_tactics');
    const jour = model.meta.calendarToday;
    vm.run('__validations=0');
    const r = jeu.brut('advance_day', { fromDate: jour });
    assert.equal(r.ok, true, r.error);
    assert.equal(r.timing.ecriture_regroupee, true, 'décision regroupée dans le jour');
    assert.equal(r.timing.ecriture_precedente, undefined, 'aucune écriture séparée avant le jour');
    assert.ok(vm.run('__validations') >= 1, 'la décision regroupée est validée');
    assert.equal(jeu.bridge.handle.pending(), null);
    assert.notEqual(r.model.meta.calendarToday, jour);
    assert.equal(tactique(dir), seconde, 'décision écrite avec le jour');
    assert.equal(jeu.call('export', { proof: true }).meta.exportRoundTripSha256, sha(enregistre(dir)), 'profil = carrière en mémoire');
  } finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Worker stdio réel : jour aussitôt après une décision, puis fermeture aussitôt après une décision', { timeout: 1500000 }, async () => {
  const dir = copie();
  const worker = path.join(__dirname, '..', 'native', 'engine', 'worker.cjs');
  const child = spawn(process.execPath, ['--max-old-space-size=1300', worker, '--data-dir', path.join(dir, 'PrototypeGodot')], { env: { ...process.env, CD_ENGINE_TIMING: '1', CD_ECRITURE_DIFFEREE: '1' }, stdio: ['pipe', 'pipe', 'inherit'] });
  const sortie = new Promise(resolve => child.once('exit', (code, signal) => resolve({ code, signal, at: performance.now() })));
  const lignes = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
  const attente = [];
  lignes.on('line', line => { const w = attente.shift(); if (w) w(JSON.parse(line)); });
  let id = 0;
  const envoyer = (command, payload = {}) => new Promise(resolve => { attente.push(resolve); child.stdin.write(JSON.stringify({ id: ++id, command, payload }) + '\n'); });
  try {
    let r = await envoyer('snapshot');
    assert.equal(r.ok, true, r.error);
    r = await envoyer('set_tactics', { attack: autreAttaque(r.model), defense: r.model.tactics.defense });
    assert.equal(r.ok, true, r.error);
    const jour = r.model.meta.calendarToday;
    // Comme l'interface : la commande suivante part dès la réponse reçue, pendant l'écriture différée.
    const t = performance.now();
    r = await envoyer('advance_day', { fromDate: jour });
    const dureeJour = performance.now() - t;
    assert.equal(r.ok, true, r.error);
    assert.notEqual(r.model.meta.calendarToday, jour);
    console.log('stdio : jour après décision', Math.round(dureeJour), 'ms ; phases', JSON.stringify(r.timing));
    assert.equal(r.timing.ecriture_regroupee, true, 'le jour reprend la décision au lieu d\'attendre son écriture');
    // Dernière décision puis fermeture immédiate : la réponse à shutdown suit l'écriture, puis le worker sort.
    r = await envoyer('set_tactics', { attack: autreAttaque(r.model), defense: r.model.tactics.defense });
    assert.equal(r.ok, true, r.error);
    const derniere = r.model.tactics.attack;
    const envoi = performance.now();
    r = await envoyer('shutdown');
    assert.equal(r.ok, true, r.error);
    const fin = await Promise.race([sortie, new Promise(resolve => setTimeout(() => resolve(null), 60000))]);
    assert.ok(fin, 'le worker sort de lui-même après shutdown');
    assert.equal(fin.code, 0, 'sortie propre');
    console.log('stdio : shutdown après décision, sortie en', Math.round(fin.at - envoi), 'ms');
    assert.equal(tactique(dir), derniere, 'la dernière décision est écrite avant la sortie');
    assert.ok(!fs.existsSync(path.join(dir, 'PrototypeGodot', 'profil.lock')), 'verrou rendu');
  } finally {
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    await sortie;
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
