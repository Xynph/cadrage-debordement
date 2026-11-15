'use strict';
// Mémoire des projections par domaine (native-systems.cjs, projectText) en carrière Monde (`world-champ`).
//
// Le modèle de l'interface est reconstruit à chaque réponse ; les domaines lourds (marché entre clubs, carrière du
// manager, staff, repérage…) reprennent leur texte précédent quand les sections de la carrière qu'ils lisent n'ont
// pas changé. Ce fichier vérifie, sur la même graine :
//   1. modèles renvoyés et profil écrit identiques octet pour octet avec et sans mémoire (CD_MEMO_DOMAINES=0),
//      chaque domaine repris étant recalculé et comparé (verifyMemo) et les sections relues contrôlées (verifyCleanCopy) ;
//   2. la mémoire sert réellement : moins de calculs du marché entre clubs avec elle ;
//   3. des seuils larges de taille et de temps (machines de CI partagées) contre les régressions.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const SEUIL_DECISION_MS = Number(process.env.CD_SEUIL_DECISION_MS || 15000);
const SEUIL_JOUR_MS = Number(process.env.CD_SEUIL_JOUR_MS || 40000);
// Modèle d'une carrière Monde neuve : ~13 Mo mesurés ; une saison plus tard ~15 Mo.
const SEUIL_MODELE_OCTETS = Number(process.env.CD_SEUIL_MODELE_OCTETS || 24 * 1048576);
const SEUIL_PROFIL_OCTETS = Number(process.env.CD_SEUIL_PROFIL_OCTETS || 40 * 1048576);

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const fichier = dir => path.join(dir, 'PrototypeGodot', 'donnees.json');

// Même dossier pour chaque parcours : le modèle cite le dossier des données (meta.dataDir).
const DOSSIER = path.join(os.tmpdir(), 'rl27-memo-projection-' + process.pid);
function parcours(options) {
  fs.rmSync(DOSSIER, { recursive: true, force: true });
  const jeu = M.ouvrir({ deferredCommits: true, testVm: true, dataDir: DOSSIER, ...options });
  const traces = [], details = [], durees = { decision: [], jour: [] };
  try {
    jeu.bridge.vm.run("{const d=nativeSystems.domain('interclubMarket'),o=d.project;globalThis.__marche=0;d.project=function(){__marche++;return o.apply(this,arguments);};}");
    const note = (etiquette, model) => {
      const texte = JSON.stringify(model), parts = {};
      for (const [k, v] of Object.entries(model)) if ((k === 'clubLife' || k === 'meta') && v) { for (const [kk, vv] of Object.entries(v)) parts[k + '.' + kk] = sha(JSON.stringify(vv) ?? ''); } else parts[k] = sha(JSON.stringify(v) ?? '');
      traces.push([etiquette, sha(texte)]); details.push(parts); return texte.length;
    };
    // Sans carrière (premier écran du jeu, recette Windows) : la lecture répond, sans section à relire.
    note('sans carrière', jeu.call('snapshot'));
    let model = M.creer(jeu);
    note('création', model);
    note('snapshot', jeu.call('snapshot'));
    note('snapshot bis', jeu.call('snapshot'));
    for (let i = 0; i < 2; i++) {
      const attaque = model.tactics.attacks.find(o => o.id !== model.tactics.attack).id;
      const t = performance.now();
      model = jeu.call('set_tactics', { attack: attaque, defense: model.tactics.defense });
      durees.decision.push(performance.now() - t);
      note('consignes ' + i, model);
    }
    model = jeu.call('auto_lineup'); note('composition', model);
    note('fiche club', jeu.call('club_sheet', { club: 5 }));
    for (let j = 0; j < 3; j++) {
      model = jeu.regler(model);
      const t = performance.now();
      model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
      durees.jour.push(performance.now() - t);
      note('jour ' + j, model);
      const attaque = model.tactics.attacks.find(o => o.id !== model.tactics.attack).id;
      model = jeu.call('set_tactics', { attack: attaque, defense: model.tactics.defense });
      note('consignes après jour ' + j, model);
    }
    const taille = note('fin', jeu.call('snapshot'));
    jeu.bridge.handle.flush();
    const profil = fs.readFileSync(fichier(jeu.dataDir), 'utf8');
    return { traces, details, durees, taille, profil: sha(profil), tailleProfil: profil.length, marche: jeu.bridge.vm.run('__marche') };
  } finally { jeu.fermer(); fs.rmSync(DOSSIER, { recursive: true, force: true }); }
}

test('Mémoire des projections : mêmes modèles et même profil, moins de calculs, seuils larges', { timeout: 1800000 }, () => {
  // Un seul pont Monde à la fois (machine de 8 Go) : le second parcours commence après la fermeture du premier.
  const avec = parcours({ verifyMemo: true, verifyCleanCopy: true });
  const sans = parcours({ memoDomains: false });
  const ecarts = (a, b) => a.details.flatMap((d, i) => Object.keys({ ...d, ...b.details[i] }).filter(k => d[k] !== b.details[i]?.[k]).map(k => a.traces[i][0] + ' : ' + k)).slice(0, 12);
  assert.deepEqual(ecarts(avec, sans), [], 'modèles identiques avec et sans mémoire');
  assert.deepEqual(avec.traces, sans.traces, 'modèles identiques avec et sans mémoire');
  assert.equal(avec.profil, sans.profil, 'profil écrit identique');
  // En vérification, chaque reprise recalcule aussi le domaine : la mesure de réutilisation se fait sans vérification.
  const rapide = parcours({});
  assert.deepEqual(ecarts(rapide, sans), [], 'modèles identiques sans vérification');
  assert.deepEqual(rapide.traces, sans.traces, 'modèles identiques sans vérification');
  assert.ok(rapide.marche < sans.marche, 'marché entre clubs repris de la mémoire (' + rapide.marche + ' calculs contre ' + sans.marche + ')');
  assert.ok(rapide.taille < SEUIL_MODELE_OCTETS, 'modèle de ' + rapide.taille + ' octets');
  assert.ok(rapide.tailleProfil < SEUIL_PROFIL_OCTETS, 'profil de ' + rapide.tailleProfil + ' octets');
  for (const d of rapide.durees.decision) assert.ok(d < SEUIL_DECISION_MS, 'décision en ' + Math.round(d) + ' ms');
  for (const d of rapide.durees.jour) assert.ok(d < SEUIL_JOUR_MS, 'jour en ' + Math.round(d) + ' ms');
  console.log(JSON.stringify({ marche: { avec: rapide.marche, sans: sans.marche }, modele: rapide.taille, profil: rapide.tailleProfil,
    decisionMs: rapide.durees.decision.map(Math.round), decisionSansMs: sans.durees.decision.map(Math.round), jourMs: rapide.durees.jour.map(Math.round), jourSansMs: sans.durees.jour.map(Math.round) }));
});
