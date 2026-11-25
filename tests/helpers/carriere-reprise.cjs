'use strict';
// Points de reprise des carrières Monde simulées (sondes, mesures d'économie) : la carrière d'une graine est jouée une
// fois, puis son état au début de chaque saison (après « Saison suivante », rendez-vous réglés) est gardé sur disque et
// repris par toutes les sondes suivantes. Clé : empreinte du code (dist/, native/engine/, tests/helpers/), graine,
// club, options de la carrière et du pont ; tout changement du moteur invalide donc les points déjà faits.
// Reprise = même carrière au bit près que la partie jouée d'une traite (vérifié par scripts/carriere-chrono.cjs).
//
//   const { ouvrirSaison, jouerSaison } = require('./carriere-reprise.cjs');
//   let { jeu, model } = ouvrirSaison({ graine: 7, saison: 2 });   // début de la saison 2 (saison 1 jouée ou reprise)
//   model = jouerSaison(jeu, model);                               // joue jusqu'à la fin de saison (phase 'ended')
//
// Dossier : CD_REPRISES (défaut : <tmp>/rl27-reprises) ; CD_REPRISES=0 coupe la mémoire (tout est rejoué).
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { ouvrir, jouerLeMatch } = require('./carriere-monde.cjs');

const RACINE = path.resolve(__dirname, '../..');
let cleCode = null;
function empreinteCode() {
  if (cleCode) return cleCode;
  const hash = createHash('sha256');
  const parcourir = dossier => {
    for (const nom of fs.readdirSync(dossier).sort()) {
      const chemin = path.join(dossier, nom), info = fs.statSync(chemin);
      if (info.isDirectory()) { if (nom !== 'assets' && nom !== 'node_modules') parcourir(chemin); continue; }
      if (!/\.(c?js|json)$/u.test(nom)) continue;
      hash.update(path.relative(RACINE, chemin)); hash.update(fs.readFileSync(chemin));
    }
  };
  for (const d of ['dist', 'native/engine', 'tests/helpers']) parcourir(path.join(RACINE, d));
  return (cleCode = hash.digest('hex').slice(0, 16));
}

function dossierReprises() {
  const d = process.env.CD_REPRISES;
  if (d === '0') return null;
  const dossier = d || path.join(os.tmpdir(), 'rl27-reprises');
  fs.mkdirSync(dossier, { recursive: true });
  return dossier;
}

// Joue la saison en cours jusqu'à sa fin (phase 'ended'), matchs délégués, comme les sondes d'économie.
function jouerSaison(jeu, model) {
  const run = src => jeu.bridge.vm.run(src);
  for (let g = 0; g < 200 && run('S.phase') !== 'ended'; g++) {
    model = jeu.regler(model);
    if (run('S.phase') === 'ended') break;
    model = model.next ? jouerLeMatch(jeu, model) : jeu.regler(jeu.call('finish_round'));
  }
  return model;
}

// Passe à la saison suivante (« Saison suivante », rendez-vous réglés).
function saisonSuivante(jeu) {
  return jeu.regler(jeu.call('next_season', { confirmed: true }));
}

// Ouvre la carrière de `graine` au début de `saison` (1 = juste créée). `carriere` : charge de new_career
// (défaut : Monde, club 29) ; `options` : options de ouvrir() (défaut : rapide, cadence hebdomadaire).
// `surSaison(jeu, model, n)` est appelé à chaque fin de saison n jouée ici (avant « Saison suivante »).
function ouvrirSaison({ graine, saison = 1, carriere = {}, options = {}, surSaison = null }) {
  const charge = { mode: 'world-champ', club: 29, ...carriere };
  const opts = { testVm: true, hebdomadaire: true, rapide: true, ...options, seed: graine };
  const jeu = ouvrir(opts);
  let model = jeu.regler(jeu.call('new_career', charge));
  const dossier = dossierReprises();
  const cle = n => createHash('sha256').update(JSON.stringify([empreinteCode(), graine, charge, opts, n])).digest('hex').slice(0, 20);
  const fichier = n => dossier && path.join(dossier, 'saison' + n + '-g' + graine + '-' + cle(n) + '.json');
  // Garde l'état courant comme point de reprise du début de la saison n (appelé juste après « Saison suivante »).
  const garder = n => {
    if (!dossier || fs.existsSync(fichier(n))) return;
    const temp = fichier(n) + '.' + process.pid + '.tmp';
    fs.writeFileSync(temp, JSON.stringify(jeu.bridge.vm.etat()));
    fs.renameSync(temp, fichier(n));
  };
  // Point de reprise le plus avancé déjà sur disque (≤ saison demandée).
  let depuis = 1;
  for (let n = saison; n > 1; n--) if (dossier && fs.existsSync(fichier(n))) { depuis = n; break; }
  if (depuis > 1) {
    jeu.bridge.vm.reprendre(JSON.parse(fs.readFileSync(fichier(depuis), 'utf8')));
    model = jeu.regler(jeu.call('snapshot'));
  }
  for (let n = depuis; n < saison; n++) {
    model = jouerSaison(jeu, model);
    if (surSaison) surSaison(jeu, model, n);
    model = saisonSuivante(jeu);
    garder(n + 1);
  }
  return { jeu, model, repriseDe: depuis, garder };
}

module.exports = { ouvrirSaison, jouerSaison, saisonSuivante, empreinteCode, dossierReprises };
